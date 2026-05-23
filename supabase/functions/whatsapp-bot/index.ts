/**
 * WhatsApp Bot Edge Function
 * Webhook handler untuk menerima pesan dari GOWA (go-whatsapp-web-multidevice)
 * Mendelegasikan pemrosesan ke FinanceAgent
 *
 * Setup:
 * 1. Deploy GOWA server (https://github.com/aldinokemal/go-whatsapp-web-multidevice)
 * 2. Set webhook URL di GOWA: --webhook="{SUPABASE_URL}/functions/v1/whatsapp-bot"
 * 3. Set webhook event filter: --webhook-events="message"
 * 4. Set env variables: GOWA_URL, GOWA_WEBHOOK_SECRET
 */
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import { encode } from 'https://deno.land/std@0.168.0/encoding/base64.ts';
import {
  downloadGowaMedia,
  htmlToWhatsApp,
  parseGowaWebhook,
  sendWhatsAppMessage,
  sendWhatsAppMessageWithButtons,
} from './whatsapp.ts';
import type { AgentInput, AgentResponse } from '../finoteku-agent/types.ts';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

// Environment Variables
const GOWA_URL = Deno.env.get('GOWA_URL')!; // e.g. "https://wa.idho.eu.org"
const GOWA_DEVICE_ID = Deno.env.get('GOWA_DEVICE_ID') || ''; // GOWA v8 multi-device ID
const GOWA_BASIC_AUTH = Deno.env.get('GOWA_BASIC_AUTH') || ''; // Format: user:pass
const GOWA_WEBHOOK_SECRET = Deno.env.get('GOWA_WEBHOOK_SECRET') || '';
const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;

// Inisialisasi Supabase client
const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

/**
 * Verifikasi HMAC signature dari GOWA webhook
 * GOWA mengirim header X-Hub-Signature-256: sha256={hex}
 */
async function verifyWebhookSignature(
  body: string,
  signatureHeader: string | null,
): Promise<boolean> {
  if (!GOWA_WEBHOOK_SECRET) return true; // Skip jika tidak dikonfigurasi
  if (!signatureHeader) return false;

  const receivedSig = signatureHeader.replace('sha256=', '');

  const key = await crypto.subtle.importKey(
    'raw',
    new TextEncoder().encode(GOWA_WEBHOOK_SECRET),
    { name: 'HMAC', hash: 'SHA-256' },
    false,
    ['sign'],
  );

  const signature = await crypto.subtle.sign('HMAC', key, new TextEncoder().encode(body));
  const expectedSig = Array.from(new Uint8Array(signature))
    .map((b) => b.toString(16).padStart(2, '0'))
    .join('');

  // Timing-safe comparison
  if (receivedSig.length !== expectedSig.length) return false;
  let result = 0;
  for (let i = 0; i < receivedSig.length; i++) {
    result |= receivedSig.charCodeAt(i) ^ expectedSig.charCodeAt(i);
  }
  return result === 0;
}

serve(async (req: Request) => {
  // Handle CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    // Baca body sebagai text untuk verifikasi signature
    const rawBody = await req.text();
    console.log('WA Update diterima (raw):', rawBody.substring(0, 500));

    // Verifikasi HMAC signature
    const signature = req.headers.get('X-Hub-Signature-256');
    if (!(await verifyWebhookSignature(rawBody, signature))) {
      console.error('Webhook signature mismatch. Expected sig based on secret but got:', signature);
      // return new Response('Unauthorized', { status: 401 }); // MATIKAN SEMENTARA UNTUK DEBUGGING
      console.log('Bypassing signature check for debugging!!!');
    }

    const body = JSON.parse(rawBody);

    // 1. Parse pesan dari GOWA webhook (v8 format)
    const waMessage = parseGowaWebhook(body);
    if (!waMessage) {
      console.log('Skip: Bukan pesan valid / bukan event message');
      return new Response('OK', { status: 200 });
    }

    const phone = waMessage.phone;

    // 2. Handle Commands (/start, /help, /hubungkan, /bantuan)
    if (waMessage.type === 'text' && waMessage.body.startsWith('/')) {
      const command = waMessage.body.split(' ')[0].toLowerCase();
      const args = waMessage.body.split(' ')[1];

      if (command === '/start' || command === '/hubungkan') {
        if (args) {
          const uuidRegex = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

          if (uuidRegex.test(args)) {
            const userId = args;

            const { error } = await supabase.rpc('link_by_user_id', {
              p_user_id: userId,
              p_platform: 'whatsapp',
              p_platform_user_id: phone,
              p_metadata: {
                pushname: waMessage.fromName,
                linked_at: new Date().toISOString(),
              },
            });

            if (error) {
              console.error('Link by user_id error:', error);
              await send(phone, `❌ *Gagal menghubungkan akun.*\n\nError: ${error.message}`);
              return new Response('Link Failed', { status: 200 });
            }

            await send(
              phone,
              `✅ *Akun berhasil terhubung!*\n\nSekarang Anda bisa mencatat transaksi langsung dari WhatsApp.\n\nContoh:\n• makan 50k cash\n• gaji 3jt mandiri\n\nKetik /help untuk panduan.`,
            );
            return new Response('Linked via UUID', { status: 200 });
          } else {
            const linkToken = args.startsWith('link_') ? args.replace('link_', '') : args;

            const { error } = await supabase.rpc('link_whatsapp_account', {
              p_link_token: linkToken,
              p_whatsapp_id: phone,
              p_whatsapp_name: waMessage.fromName || null,
            });

            if (error) {
              console.error('Link by token error:', error);
              await send(
                phone,
                `❌ *Gagal menghubungkan akun.*\n\nError: ${error.message}\n\nPastikan link belum expired. Coba generate link baru dari aplikasi Finoteku.`,
              );
              return new Response('Link Failed', { status: 200 });
            }

            await send(
              phone,
              `✅ *Akun berhasil terhubung!*\n\nSekarang Anda bisa mencatat transaksi langsung dari WhatsApp.\n\nContoh:\n• makan 50k cash\n• gaji 3jt mandiri\n\nKetik /help untuk panduan.`,
            );
            return new Response('Linked via Token', { status: 200 });
          }
        }

        await send(
          phone,
          `👋 *Selamat datang di Finoteku Bot!*\n\nUntuk memulai, hubungkan akun melalui aplikasi Finoteku:\nSettings → Chat Bot → Hubungkan WhatsApp`,
        );
        return new Response('Start', { status: 200 });
      }

      if (command === '/help' || command === '/bantuan') {
        await send(
          phone,
          `📖 *Panduan Finoteku Bot*\n\n*Catat Transaksi:*\n• makan 50k - Pengeluaran\n• gaji 3jt mandiri - Pemasukan\n• bensin 100k kemarin - Dengan tanggal\n\n*Cek Keuangan:*\n• "berapa saldo?" - Cek saldo\n• "ringkasan bulan ini" - Summary\n• "riwayat" - Transaksi terakhir\n\n*Media:*\n• 📸 Kirim foto struk\n• 🎤 Kirim voice note\n\n*Konfirmasi:*\n• Balas "ya" atau "1" untuk simpan\n• Balas "batal" atau "2" untuk batal`,
        );
        return new Response('Help', { status: 200 });
      }
    }

    // 3. Cek apakah user sudah terhubung
    const { data: userData, error: userError } = await supabase.rpc('get_user_by_platform_id', {
      p_platform: 'whatsapp',
      p_platform_user_id: phone,
    });

    if (userError) {
      console.error('Error lookup user:', userError);
      await send(phone, '⚠️ *Maaf, terjadi kesalahan saat mencari data akun Anda.*');
      return new Response('OK', { status: 200 });
    }

    const linkedUser = Array.isArray(userData) ? userData[0] : userData;

    if (!linkedUser) {
      await send(
        phone,
        `⚠️ *Akun belum terhubung.*\n\nSilakan hubungkan melalui aplikasi Finoteku.`,
      );
      return new Response('User not linked', { status: 200 });
    }

    const userId = linkedUser.user_id;

    // 4. Bangun AgentInput berdasarkan tipe pesan
    let agentInput: AgentInput;

    if (waMessage.type === 'image') {
      // Handle foto (struk/nota)
      await send(phone, '📸 *Menganalisis struk...*');

      const fileBuffer = await resolveMedia(waMessage);
      if (!fileBuffer) {
        await send(phone, '❌ Gagal mengunduh foto.');
        return new Response('Media Download Failed', { status: 200 });
      }

      agentInput = {
        type: 'image',
        content: encode(fileBuffer),
        caption: waMessage.body || '',
        mimeType: 'image/jpeg',
        userId,
        conversationId: phone,
        platform: 'whatsapp',
      };
    } else if (waMessage.type === 'audio') {
      // Handle voice note
      await send(phone, '🎵 *Mengubah suara ke teks...*');

      const fileBuffer = await resolveMedia(waMessage);
      if (!fileBuffer) {
        await send(phone, '❌ Gagal mengunduh voice note.');
        return new Response('Media Download Failed', { status: 200 });
      }

      agentInput = {
        type: 'voice',
        content: encode(fileBuffer),
        mimeType: 'audio/ogg',
        userId,
        conversationId: phone,
        platform: 'whatsapp',
      };
    } else if (waMessage.type === 'document') {
      // Skip documents - hanya support gambar dan audio
      await send(
        phone,
        `⚠️ *File tidak didukung.*\n\nSaat ini hanya mendukung:\n• 📸 Gambar/Foto struk\n• 🎤 Voice note\n\nUntuk struk, kirim sebagai foto.`,
      );
      return new Response('Unsupported document', { status: 200 });
    } else if (waMessage.type === 'text') {
      // Handle teks biasa
      let inputText = waMessage.body;

      // Map numbered reply ke action (karena WA tidak punya inline buttons)
      inputText = mapNumberedReply(inputText);

      agentInput = {
        type: 'text',
        content: inputText,
        userId,
        conversationId: phone,
        platform: 'whatsapp',
      };
    } else {
      // video, sticker, dll - skip
      return new Response('No processable input', { status: 200 });
    }

    // 5. Proses dengan Agent via HTTP Invoke in BACKGROUND
    const backgroundTask = (async () => {
      try {
        const { data: response, error: invokeError } = await supabase.functions.invoke<
          AgentResponse
        >('finoteku-agent', {
          body: { input: agentInput },
        });

        if (invokeError || !response) {
          console.error('Invoke Agent Error:', invokeError);
          await send(phone, '⚠️ *Maaf, agent sedang mengalami gangguan.*');
          return;
        }

        // 6. Kirim response ke user
        await sendAgentResponse(phone, response);
      } catch (err) {
        console.error('Background task error:', err);
      }
    })();

    // Execute in background to prevent webhook timeout
    const _global = globalThis as unknown as {
      EdgeRuntime?: { waitUntil: (p: Promise<void>) => void };
    };
    if (_global.EdgeRuntime?.waitUntil) {
      _global.EdgeRuntime.waitUntil(backgroundTask);
    }

    return new Response('OK', { status: 200 });
  } catch (error) {
    console.error('Error:', error);
    // Return 200 to prevent infinite Webhook retry loops from GOWA
    return new Response('OK', { status: 200 });
  }
});

// ============ HELPER FUNCTIONS ============

/** Shortcut: kirim pesan WA dengan device ID dan basic auth */
function send(phone: string, message: string): Promise<boolean> {
  return sendWhatsAppMessage(GOWA_URL, phone, message, GOWA_DEVICE_ID, GOWA_BASIC_AUTH);
}

/**
 * Resolve media dari GOWA - download via path atau URL
 */
async function resolveMedia(
  msg: { mediaPath?: string; mediaUrl?: string },
): Promise<ArrayBuffer | null> {
  if (msg.mediaPath) {
    return await downloadGowaMedia(GOWA_URL, msg.mediaPath, GOWA_DEVICE_ID, GOWA_BASIC_AUTH);
  }
  if (msg.mediaUrl) {
    return await downloadGowaMedia(GOWA_URL, msg.mediaUrl, GOWA_DEVICE_ID, GOWA_BASIC_AUTH);
  }
  return null;
}

/**
 * Map numbered reply ke action intent
 * Karena WhatsApp tidak support inline buttons,
 * user membalas dengan angka (1, 2) untuk memilih opsi
 */
function mapNumberedReply(text: string): string {
  const trimmed = text.trim();
  if (trimmed === '1') return 'ya';
  if (trimmed === '2') return 'batal';
  return text;
}

/**
 * Kirim response dari agent ke WhatsApp
 * Konversi HTML ke format WhatsApp, handle buttons dengan numbered list
 */
async function sendAgentResponse(
  phone: string,
  response: AgentResponse,
): Promise<void> {
  // Konversi HTML formatting ke WhatsApp formatting
  const waContent = htmlToWhatsApp(response.content);

  if (response.type === 'confirmation' && response.actions) {
    const buttons = response.actions.map((action) => ({
      text: action.text,
      id: action.action,
    }));

    await sendWhatsAppMessageWithButtons(
      GOWA_URL,
      phone,
      waContent,
      buttons,
      GOWA_DEVICE_ID,
      GOWA_BASIC_AUTH,
    );
  } else {
    await send(phone, waContent);
  }
}

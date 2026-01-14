/**
 * Telegram Bot Edge Function
 * Webhook handler untuk menerima update dari Telegram
 * Mendelegasikan pemrosesan ke FinanceAgent
 */
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import { encode } from 'https://deno.land/std@0.168.0/encoding/base64.ts';
import {
  answerCallbackQuery,
  downloadTelegramFile,
  getTelegramFileUrl,
  parseCallbackQuery,
  parseTelegramUpdate,
  removeMessageButtons,
  sendTelegramMessage,
  sendTelegramMessageWithButtons,
} from './telegram.ts';
import { FinanceAgent } from '../finoteku-agent/agent.ts';
import type { AgentInput, AgentResponse } from '../finoteku-agent/types.ts';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

// Environment Variables (otomatis tersedia di Supabase Edge Functions)
const TELEGRAM_BOT_TOKEN = Deno.env.get('TELEGRAM_BOT_TOKEN')!;
const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;

// Inisialisasi Supabase client
const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

// Inisialisasi Finance Agent
const agent = new FinanceAgent({
  supabase,
  defaultProvider: 'gemini',
});

serve(async (req: Request) => {
  // Handle CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const update = await req.json();
    console.log('Update diterima:', JSON.stringify(update).substring(0, 200));

    const callbackQuery = parseCallbackQuery(update);
    if (callbackQuery && callbackQuery.data && callbackQuery.message) {
      console.log('Memproses callback:', callbackQuery.data);

      const chatId = callbackQuery.message.chat.id;
      // Safeguard against missing 'from'
      if (!callbackQuery.from || !callbackQuery.from.id) {
        console.error('Callback query missing from.id');
        await answerCallbackQuery(TELEGRAM_BOT_TOKEN, callbackQuery.id);
        return new Response('Invalid Callback', { status: 200 });
      }
      const telegramId = callbackQuery.from.id;

      // Lookup user ID based on telegram ID
      const { data: userData } = await supabase.rpc('get_user_by_platform_id', {
        p_platform: 'telegram',
        p_platform_user_id: telegramId.toString(),
      });

      const linkedUser = Array.isArray(userData) ? userData[0] : userData;
      if (!linkedUser) {
        await answerCallbackQuery(TELEGRAM_BOT_TOKEN, callbackQuery.id, '⚠️ Akun tidak terhubung');
        return new Response('User not linked', { status: 200 });
      }

      // Map callback data to agent input text
      let inputText = '';
      if (callbackQuery.data === 'confirm_yes') inputText = 'ya';
      else if (callbackQuery.data === 'confirm_no') inputText = 'batal';
      else inputText = callbackQuery.data; // Fallback

      // Process with agent
      const agentInput: AgentInput = {
        type: 'text',
        content: inputText,
        userId: linkedUser.user_id,
        conversationId: chatId.toString(),
        platform: 'telegram',
      };

      // Answer callback and remove old buttons
      await answerCallbackQuery(TELEGRAM_BOT_TOKEN, callbackQuery.id);
      await removeMessageButtons(TELEGRAM_BOT_TOKEN, chatId, callbackQuery.message.message_id);

      const response = await agent.process(agentInput);
      await sendAgentResponse(TELEGRAM_BOT_TOKEN, chatId, response);

      return new Response('OK', { status: 200 });
    }

    // 2. Parse pesan dari update
    const message = parseTelegramUpdate(update);
    if (!message || (!message.text && !message.photo && !message.voice && !message.chat.id)) {
      console.log('Skip: Tidak ada pesan valid');
      return new Response('OK', { status: 200 });
    }

    const chatId = message.chat.id;
    const telegramId = message.from.id;
    const telegramUsername = message.from.username;

    // 3. Handle Commands (/start, /help, dll)
    if (message.text && message.text.startsWith('/')) {
      const command = message.text.split(' ')[0].toLowerCase();
      const args = message.text.split(' ')[1];

      if (command === '/start') {
        if (args) {
          console.log('Attempting to link with args:', args);

          // Cek apakah args adalah UUID (format: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx)
          const uuidRegex = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

          if (uuidRegex.test(args)) {
            // NEW FLOW: Link by UUID (Direct User ID)
            const userId = args;

            const { error } = await supabase.rpc('link_by_user_id', {
              p_user_id: userId,
              p_platform: 'telegram',
              p_platform_user_id: telegramId.toString(),
              p_metadata: {
                username: telegramUsername,
                chat_id: chatId.toString(),
                linked_at: new Date().toISOString(),
              },
            });

            if (error) {
              console.error('Link by user_id error:', error);
              await sendTelegramMessage(
                TELEGRAM_BOT_TOKEN,
                chatId,
                `❌ <b>Gagal menghubungkan akun.</b>\n\nError: ${error.message}`,
              );
              return new Response('Link Failed', { status: 200 });
            }

            await sendTelegramMessage(
              TELEGRAM_BOT_TOKEN,
              chatId,
              `✅ <b>Akun berhasil terhubung!</b>\n\nSekarang Anda bisa mencatat transaksi langsung dari Telegram.\n\nContoh:\n• <code>makan 50k cash</code>\n• <code>gaji 3jt mandiri</code>\n\nKetik /help untuk panduan.`,
            );
            return new Response('Linked via UUID', { status: 200 });
          } else {
            // LEGACY FLOW: Link by Token (Short token or legacy format)
            // Extract token - hapus prefix "link_" jika ada
            const linkToken = args.startsWith('link_') ? args.replace('link_', '') : args;

            const { error } = await supabase.rpc('link_telegram_account', {
              p_link_token: linkToken,
              p_telegram_id: telegramId.toString(),
              p_telegram_username: telegramUsername || null,
            });

            if (error) {
              console.error('Link by token error:', error);
              await sendTelegramMessage(
                TELEGRAM_BOT_TOKEN,
                chatId,
                `❌ <b>Gagal menghubungkan akun.</b>\n\nError: ${error.message}\n\nPastikan link belum expired. Coba generate link baru dari aplikasi Finoteku.`,
              );
              return new Response('Link Failed', { status: 200 });
            }

            await sendTelegramMessage(
              TELEGRAM_BOT_TOKEN,
              chatId,
              `✅ <b>Akun berhasil terhubung!</b>\n\nSekarang Anda bisa mencatat transaksi langsung dari Telegram.\n\nContoh:\n• <code>makan 50k cash</code>\n• <code>gaji 3jt mandiri</code>\n\nKetik /help untuk panduan.`,
            );
            return new Response('Linked via Token', { status: 200 });
          }
        }

        await sendTelegramMessage(
          TELEGRAM_BOT_TOKEN,
          chatId,
          `👋 <b>Selamat datang di Finoteku Bot!</b>\n\nUntuk memulai, hubungkan akun melalui aplikasi Finoteku:\nSettings → Chat Bot → Hubungkan Telegram`,
        );
        return new Response('Start', { status: 200 });
      }

      if (command === '/help') {
        await sendTelegramMessage(
          TELEGRAM_BOT_TOKEN,
          chatId,
          `📖 <b>Panduan Finoteku Bot</b>\n\n<b>Catat Transaksi:</b>\n• <code>makan 50k</code> - Pengeluaran\n• <code>gaji 3jt mandiri</code> - Pemasukan\n• <code>bensin 100k kemarin</code> - Dengan tanggal\n\n<b>Cek Keuangan:</b>\n• "berapa saldo?" - Cek saldo\n• "ringkasan bulan ini" - Summary\n• "riwayat" - Transaksi terakhir\n\n<b>Media:</b>\n• 📸 Kirim foto struk\n• 🎤 Kirim voice note`,
        );
        return new Response('Help', { status: 200 });
      }
    }

    // 4. Cek apakah user sudah terhubung (Improved Lookup)
    const { data: userData, error: userError } = await supabase.rpc('get_user_by_platform_id', {
      p_platform: 'telegram',
      p_platform_user_id: telegramId.toString(),
    });

    if (userError) {
      console.error('Error lookup user:', userError);
      return new Response('Error lookup', { status: 500 });
    }

    // Handle return type difference: old was array, new RPC might return single object or array
    // Checking schema notes: get_user_by_platform_id updated to return TABLE(user_id uuid, metadata jsonb)
    // So it returns an array of rows (likely 1 row)
    const linkedUser = Array.isArray(userData) ? userData[0] : userData;

    if (!linkedUser) {
      await sendTelegramMessage(
        TELEGRAM_BOT_TOKEN,
        chatId,
        `⚠️ <b>Akun belum terhubung.</b>\n\nSilakan hubungkan melalui aplikasi Finoteku.`,
      );
      return new Response('User not linked', { status: 200 });
    }

    const userId = linkedUser.user_id;

    // 5. Bangun AgentInput berdasarkan tipe pesan
    let agentInput: AgentInput;

    if (message.photo && message.photo.length > 0) {
      // Handle foto (struk/nota)
      await sendTelegramMessage(TELEGRAM_BOT_TOKEN, chatId, '📸 <b>Menganalisis struk...</b>');

      const photo = message.photo[message.photo.length - 1];
      const fileUrl = await getTelegramFileUrl(TELEGRAM_BOT_TOKEN, photo.file_id);
      if (!fileUrl) {
        await sendTelegramMessage(TELEGRAM_BOT_TOKEN, chatId, '❌ Gagal mengunduh foto.');
        return new Response('File URL Failed', { status: 200 });
      }

      const fileBuffer = await downloadTelegramFile(fileUrl);
      if (!fileBuffer) {
        await sendTelegramMessage(TELEGRAM_BOT_TOKEN, chatId, '❌ Gagal mengunduh foto.');
        return new Response('Download Failed', { status: 200 });
      }

      agentInput = {
        type: 'image',
        content: encode(fileBuffer),
        mimeType: 'image/jpeg',
        userId,
        conversationId: chatId.toString(),
        platform: 'telegram',
      };
    } else if (message.voice) {
      // Handle voice note
      await sendTelegramMessage(TELEGRAM_BOT_TOKEN, chatId, '🎵 <b>Mengubah suara ke teks...</b>');

      const fileUrl = await getTelegramFileUrl(TELEGRAM_BOT_TOKEN, message.voice.file_id);
      if (!fileUrl) {
        await sendTelegramMessage(TELEGRAM_BOT_TOKEN, chatId, '❌ Gagal mengunduh voice note.');
        return new Response('Voice URL Failed', { status: 200 });
      }

      const fileBuffer = await downloadTelegramFile(fileUrl);
      if (!fileBuffer) {
        await sendTelegramMessage(TELEGRAM_BOT_TOKEN, chatId, '❌ Gagal mengunduh voice note.');
        return new Response('Voice Download Failed', { status: 200 });
      }

      agentInput = {
        type: 'voice',
        content: encode(fileBuffer),
        mimeType: message.voice.mime_type || 'audio/ogg',
        userId,
        conversationId: chatId.toString(),
        platform: 'telegram',
      };
    } else if (message.document) {
      // Handle document files - check if it's image or audio
      const doc = message.document;
      const mimeType = doc.mime_type || '';

      if (mimeType.startsWith('image/')) {
        // Document is an image → Process as OCR
        await sendTelegramMessage(TELEGRAM_BOT_TOKEN, chatId, '📸 <b>Menganalisis gambar...</b>');

        const fileUrl = await getTelegramFileUrl(TELEGRAM_BOT_TOKEN, doc.file_id);
        if (!fileUrl) {
          await sendTelegramMessage(TELEGRAM_BOT_TOKEN, chatId, '❌ Gagal mengunduh file.');
          return new Response('File URL Failed', { status: 200 });
        }

        const fileBuffer = await downloadTelegramFile(fileUrl);
        if (!fileBuffer) {
          await sendTelegramMessage(TELEGRAM_BOT_TOKEN, chatId, '❌ Gagal mengunduh file.');
          return new Response('Download Failed', { status: 200 });
        }

        agentInput = {
          type: 'image',
          content: encode(fileBuffer),
          mimeType,
          userId,
          conversationId: chatId.toString(),
          platform: 'telegram',
        };
      } else if (mimeType.startsWith('audio/')) {
        // Document is audio → Process as STT
        await sendTelegramMessage(
          TELEGRAM_BOT_TOKEN,
          chatId,
          '🎵 <b>Mengubah audio ke teks...</b>',
        );

        const fileUrl = await getTelegramFileUrl(TELEGRAM_BOT_TOKEN, doc.file_id);
        if (!fileUrl) {
          await sendTelegramMessage(TELEGRAM_BOT_TOKEN, chatId, '❌ Gagal mengunduh file.');
          return new Response('File URL Failed', { status: 200 });
        }

        const fileBuffer = await downloadTelegramFile(fileUrl);
        if (!fileBuffer) {
          await sendTelegramMessage(TELEGRAM_BOT_TOKEN, chatId, '❌ Gagal mengunduh file.');
          return new Response('Download Failed', { status: 200 });
        }

        agentInput = {
          type: 'voice',
          content: encode(fileBuffer),
          mimeType,
          userId,
          conversationId: chatId.toString(),
          platform: 'telegram',
        };
      } else {
        // Other documents (pdf, doc, etc) - skip
        await sendTelegramMessage(
          TELEGRAM_BOT_TOKEN,
          chatId,
          '⚠️ <b>File tidak didukung.</b>\n\nSaat ini hanya mendukung:\n• 📸 Gambar (JPG, PNG, dll)\n• 🎤 Audio (MP3, OGG, dll)\n\nUntuk struk, kirim sebagai <b>foto</b> bukan dokumen.',
        );
        return new Response('Unsupported document', { status: 200 });
      }
    } else if (message.text) {
      // Handle teks biasa
      agentInput = {
        type: 'text',
        content: message.text,
        userId,
        conversationId: chatId.toString(),
        platform: 'telegram',
      };
    } else {
      return new Response('No processable input', { status: 200 });
    }

    // 6. Proses dengan Agent
    const response = await agent.process(agentInput);

    // 7. Kirim response ke user
    await sendAgentResponse(TELEGRAM_BOT_TOKEN, chatId, response);

    return new Response('OK', { status: 200 });
  } catch (error) {
    console.error('Error:', error);
    return new Response(JSON.stringify({ error: (error as Error).message }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 500,
    });
  }
});

/**
 * Kirim response dari agent ke Telegram
 * Jika ada actions, tampilkan sebagai inline buttons
 */
async function sendAgentResponse(
  token: string,
  chatId: number,
  response: AgentResponse,
): Promise<void> {
  if (response.type === 'confirmation' && response.actions) {
    // Kirim dengan inline buttons
    await sendTelegramMessageWithButtons(token, chatId, response.content, [
      response.actions.map((action) => ({
        text: action.text,
        callback_data: action.action,
      })),
    ]);
  } else {
    // Kirim pesan biasa
    await sendTelegramMessage(token, chatId, response.content);
  }
}

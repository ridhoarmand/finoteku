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

    // 1. Handle Callback Query (tombol inline)
    const callbackQuery = parseCallbackQuery(update);
    if (callbackQuery && callbackQuery.data && callbackQuery.message) {
      console.log('Memproses callback:', callbackQuery.data);
      // TODO: Implementasi handling callback via agent
      await answerCallbackQuery(TELEGRAM_BOT_TOKEN, callbackQuery.id);
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

    // 3. Handle Commands (/start, /help, dll)
    if (message.text && message.text.startsWith('/')) {
      const command = message.text.split(' ')[0].toLowerCase();

      if (command === '/start') {
        // Cek deep link untuk menghubungkan akun
        const args = message.text.split(' ')[1];
        if (args && args.startsWith('link_')) {
          const linkToken = args.replace('link_', '');
          const { error } = await supabase.rpc('link_telegram_account', {
            p_link_token: linkToken,
            p_telegram_id: telegramId.toString(),
            p_telegram_username: message.from.username || null,
          });

          if (!error) {
            await sendTelegramMessage(
              TELEGRAM_BOT_TOKEN,
              chatId,
              `✅ <b>Akun berhasil terhubung!</b>\n\nSekarang Anda bisa mencatat transaksi langsung dari Telegram.\n\nContoh:\n• <code>makan 50k cash</code>\n• <code>gaji 3jt mandiri</code>\n\nKetik /help untuk panduan.`,
            );
            return new Response('Linked', { status: 200 });
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

    // 4. Cek apakah user sudah terhubung
    const { data: userData } = await supabase.rpc('get_user_by_platform_id', {
      p_platform: 'telegram',
      p_platform_user_id: telegramId.toString(),
    });

    if (!userData || userData.length === 0) {
      await sendTelegramMessage(
        TELEGRAM_BOT_TOKEN,
        chatId,
        `⚠️ <b>Akun belum terhubung.</b>\n\nSilakan hubungkan melalui aplikasi Finoteku.`,
      );
      return new Response('User not linked', { status: 200 });
    }

    const userId = userData[0].user_id;

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

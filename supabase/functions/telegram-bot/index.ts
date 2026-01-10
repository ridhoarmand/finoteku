// Telegram Bot Edge Function
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import { encode } from 'https://deno.land/std@0.168.0/encoding/base64.ts';
import {
  downloadTelegramFile,
  getTelegramFileUrl,
  parseCallbackQuery,
  parseTelegramUpdate,
  sendTelegramMessage,
} from '../_shared/platforms/telegram.ts';
import { detectIntentSimple } from '../_shared/ai/intent.ts';
import { parseImageWithGemini } from '../_shared/parsers/gemini.ts';
import { transcribeWithGemini } from '../_shared/parsers/stt.ts';

// Handlers
import { handleCommand } from './handlers/commands.ts';
import { handleQuery } from './handlers/queries.ts';
import {
  handleNewTransaction,
  handlePendingTransaction,
  handleTransactionCallback,
} from './handlers/transactions.ts';

// Utils
import { getUserByTelegramId, getUserContext, getUserTransactionHistory } from './utils/context.ts';
import { parseMessage } from './utils/parser.ts';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

// Environment variables
const TELEGRAM_BOT_TOKEN = Deno.env.get('TELEGRAM_BOT_TOKEN')!;
const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;

// Server-side AI API key (Gemini only)
const SERVER_GEMINI_API_KEY = Deno.env.get('GEMINI_API_KEY');

// Initialize Supabase client
const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const update = await req.json();
    console.log('Received update:', JSON.stringify(update));

    // 1. Handle Callback Query (Inline Buttons)
    const callbackQuery = parseCallbackQuery(update);
    if (callbackQuery && callbackQuery.data && callbackQuery.message) {
      console.log('Handling callback query:', callbackQuery.data);
      return await handleTransactionCallback(supabase, TELEGRAM_BOT_TOKEN, {
        id: callbackQuery.id,
        data: callbackQuery.data,
        message: {
          chat: { id: callbackQuery.message.chat.id },
          message_id: callbackQuery.message.message_id,
          text: '',
        },
      });
    }

    // 2. Parse Message
    const message = parseTelegramUpdate(update);

    // Accept text, photo, or voice
    if (!message || (!message.text && !message.photo && !message.voice && !message.chat.id)) {
      console.log('Skipping update: No valid message found');
      return new Response('OK', { status: 200 });
    }

    const chatId = message.chat.id;
    const telegramId = message.from.id;
    const telegramUsername = message.from.username;

    // 3. Handle Commands (/start, /help) - Global (Only if text exists)
    if (message.text && message.text.startsWith('/')) {
      console.log('Step 3: Handle Command');
      const commandResponse = await handleCommand(
        supabase,
        TELEGRAM_BOT_TOKEN,
        chatId,
        message.text,
        telegramId,
        telegramUsername,
      );
      if (commandResponse) {
        return commandResponse;
      }
    }

    // 4. Get User Info
    console.log('Step 4: Get User Info');
    const user = await getUserByTelegramId(supabase, telegramId);

    if (!user) {
      console.log('User not linked, sending warning');
      await sendTelegramMessage(
        TELEGRAM_BOT_TOKEN,
        chatId,
        `⚠️ <b>Akun belum terhubung.</b>\n\nSilakan hubungkan akun Telegram Anda melalui aplikasi Finoteku.`,
      );
      return new Response('User not linked', { status: 200 });
    }

    // 5. Get User Context (Wallets, Categories)
    console.log('Step 5: Get User Context');
    const userContext = await getUserContext(supabase, user.userId);

    // 6. Handle Photo (Receipt Scanning)
    if (message.photo && message.photo.length > 0) {
      console.log('Step 6: Handle Photo (Vision AI)');
      await sendTelegramMessage(
        TELEGRAM_BOT_TOKEN,
        chatId,
        '📸 <b>Menganalisis struk...</b>\nMohon tunggu sebentar.',
      );

      try {
        // Get highest resolution photo (last item)
        const photo = message.photo[message.photo.length - 1];
        console.log('Photo file_id:', photo.file_id);

        const fileUrl = await getTelegramFileUrl(TELEGRAM_BOT_TOKEN, photo.file_id);
        console.log('File URL:', fileUrl);

        if (!fileUrl) {
          console.error('Failed to get file URL from Telegram');
          await sendTelegramMessage(
            TELEGRAM_BOT_TOKEN,
            chatId,
            '❌ <b>Gagal mengunduh foto.</b>\nSilakan coba lagi.',
          );
          return new Response('File URL Failed', { status: 200 });
        }

        const fileBuffer = await downloadTelegramFile(fileUrl);
        console.log('File buffer size:', fileBuffer?.byteLength || 0);

        if (!fileBuffer) {
          console.error('Failed to download file from Telegram');
          await sendTelegramMessage(
            TELEGRAM_BOT_TOKEN,
            chatId,
            '❌ <b>Gagal mengunduh foto.</b>\nSilakan coba lagi.',
          );
          return new Response('Download Failed', { status: 200 });
        }

        const base64 = encode(fileBuffer);
        console.log('Base64 length:', base64.length);

        // Prioritize User Key, fallback to Server Key
        // Note: Vision works best with Gemini 1.5/2.0 Flash
        const apiKey = user.aiApiKey || SERVER_GEMINI_API_KEY;

        if (!apiKey) {
          console.error('No API key available for vision parsing');
          await sendTelegramMessage(
            TELEGRAM_BOT_TOKEN,
            chatId,
            '❌ <b>Gagal: API Key Tidak Ditemukan.</b>\nMohon set API Key di aplikasi.',
          );
          return new Response('Missing API Key', { status: 200 });
        }

        console.log('Using API key (first 8 chars):', apiKey.substring(0, 8));

        // Data transformation for Gemini Context
        const geminiContext = {
          incomeCategories: userContext.categories.filter((c) => c.type === 'income').map((c) =>
            c.name
          ),
          expenseCategories: userContext.categories.filter((c) => c.type === 'expense').map((c) =>
            c.name
          ),
          walletNames: userContext.wallets.map((w) => w.name),
          incomeCategoriesWithParent: userContext.categories.filter((c) => c.type === 'income').map(
            (c) => ({ name: c.name, parent: c.parentName }),
          ),
          expenseCategoriesWithParent: userContext.categories.filter((c) => c.type === 'expense')
            .map((c) => ({ name: c.name, parent: c.parentName })),
        };

        console.log('Calling parseImageWithGemini...');
        const parsed = await parseImageWithGemini(base64, apiKey, geminiContext);
        console.log('ParseImage result:', parsed);

        if (parsed) {
          console.log('Vision Parse Success:', parsed);
          return await handleNewTransaction(
            supabase,
            TELEGRAM_BOT_TOKEN,
            chatId,
            user.userId,
            userContext,
            parsed,
          );
        }

        console.error('parseImageWithGemini returned null');
      } catch (err) {
        console.error('Vision handling error:', err);
      }

      await sendTelegramMessage(
        TELEGRAM_BOT_TOKEN,
        chatId,
        '❌ <b>Gagal membaca gambar.</b>\nPastikan foto jelas dan coba lagi.',
      );
      return new Response('Vision Failed', { status: 200 });
    }

    // 6b. Handle Voice Note (Speech-to-Text)
    if (message.voice) {
      console.log('Step 6b: Handle Voice Note (STT)');
      await sendTelegramMessage(
        TELEGRAM_BOT_TOKEN,
        chatId,
        '🎵 <b>Mengubah suara ke teks...</b>\nMohon tunggu sebentar.',
      );

      try {
        const voice = message.voice;
        console.log('Voice file_id:', voice.file_id, 'duration:', voice.duration);

        const fileUrl = await getTelegramFileUrl(TELEGRAM_BOT_TOKEN, voice.file_id);
        console.log('Voice File URL:', fileUrl);

        if (!fileUrl) {
          console.error('Failed to get voice file URL from Telegram');
          await sendTelegramMessage(
            TELEGRAM_BOT_TOKEN,
            chatId,
            '❌ <b>Gagal mengunduh voice note.</b>\nSilakan coba lagi.',
          );
          return new Response('Voice File URL Failed', { status: 200 });
        }

        const fileBuffer = await downloadTelegramFile(fileUrl);
        console.log('Voice file buffer size:', fileBuffer?.byteLength || 0);

        if (!fileBuffer) {
          console.error('Failed to download voice file from Telegram');
          await sendTelegramMessage(
            TELEGRAM_BOT_TOKEN,
            chatId,
            '❌ <b>Gagal mengunduh voice note.</b>\nSilakan coba lagi.',
          );
          return new Response('Voice Download Failed', { status: 200 });
        }

        const base64Audio = encode(fileBuffer);
        console.log('Voice Base64 length:', base64Audio.length);

        // Prioritize User Key, fallback to Server Key
        const apiKey = user.aiApiKey || SERVER_GEMINI_API_KEY;

        if (!apiKey) {
          console.error('No API key available for STT');
          await sendTelegramMessage(
            TELEGRAM_BOT_TOKEN,
            chatId,
            '❌ <b>Gagal: API Key Tidak Ditemukan.</b>\nMohon set API Key di aplikasi.',
          );
          return new Response('Missing API Key for STT', { status: 200 });
        }

        // Telegram voice notes are OGG format
        const mimeType = voice.mime_type || 'audio/ogg';
        console.log('Voice mime_type:', mimeType);

        const transcribedText = await transcribeWithGemini(base64Audio, apiKey, mimeType);
        console.log('STT Result:', transcribedText);

        if (transcribedText && transcribedText.trim().length > 0) {
          // Now parse the transcribed text as a transaction
          const history = user.parserMode !== 'regex'
            ? await getUserTransactionHistory(supabase, user.userId)
            : [];

          const parsed = await parseMessage(
            transcribedText,
            user.parserMode,
            user.aiApiKey,
            SERVER_GEMINI_API_KEY,
            userContext,
            history,
          );
          console.log('Parsed from STT:', parsed);

          if (parsed) {
            return await handleNewTransaction(
              supabase,
              TELEGRAM_BOT_TOKEN,
              chatId,
              user.userId,
              userContext,
              parsed,
            );
          } else {
            await sendTelegramMessage(
              TELEGRAM_BOT_TOKEN,
              chatId,
              `ℹ️ <b>Hasil transkripsi:</b>\n<i>"${transcribedText}"</i>\n\n❌ Tidak terdeteksi sebagai transaksi.\nCoba ucapkan dengan jelas, contoh: "Makan lima puluh ribu cash"`,
            );
            return new Response('STT parsed but not transaction', { status: 200 });
          }
        }

        console.error('STT returned empty text');
      } catch (err) {
        console.error('Voice handling error:', err);
      }

      await sendTelegramMessage(
        TELEGRAM_BOT_TOKEN,
        chatId,
        '❌ <b>Gagal mengubah suara ke teks.</b>\nPastikan suara jelas dan coba lagi.',
      );
      return new Response('STT Failed', { status: 200 });
    }

    // 7. Handle Text Message
    const originalText = message.text;
    if (!originalText) {
      return new Response('No text to process', { status: 200 });
    }

    // 8. Handle Pending Transactions (Text updates) - Pass AI key for natural language updates
    const aiKeyForUpdates = user.aiApiKey || SERVER_GEMINI_API_KEY;
    const pendingResponse = await handlePendingTransaction(
      supabase,
      TELEGRAM_BOT_TOKEN,
      chatId,
      originalText,
      userContext,
      aiKeyForUpdates,
    );
    if (pendingResponse) return pendingResponse;

    // 9. Detect Intent
    console.log('Step 9: Detect Intent');
    const intentResult = detectIntentSimple(originalText);
    console.log('Detected intent:', intentResult.intent);

    // 10. Handle Queries
    if (intentResult.intent.startsWith('query_')) {
      const queryResponse = await handleQuery(
        supabase,
        TELEGRAM_BOT_TOKEN,
        chatId,
        user.userId,
        intentResult.intent,
        originalText,
      );
      if (queryResponse) return queryResponse;
    }

    // 11. Parse Transaction (Text)
    console.log('Step 11: Parse Text Transaction');
    const history = user.parserMode !== 'regex'
      ? await getUserTransactionHistory(supabase, user.userId)
      : [];

    const parsed = await parseMessage(
      originalText,
      user.parserMode,
      user.aiApiKey,
      SERVER_GEMINI_API_KEY,
      userContext,
      history,
    );
    console.log('Parsed result:', parsed);

    if (parsed) {
      return await handleNewTransaction(
        supabase,
        TELEGRAM_BOT_TOKEN,
        chatId,
        user.userId,
        userContext,
        parsed,
      );
    } else {
      console.log('Parse failed, sending fallback message');
      await sendTelegramMessage(
        TELEGRAM_BOT_TOKEN,
        chatId,
        `❌ <b>Tidak dapat memahami pesan</b>\n\nFormat: <code>[kategori] [nominal] [wallet]</code>\nAtau kirim <b>Foto Struk</b> untuk scan otomatis! 📸`,
      );
      return new Response('Parse failed', { status: 200 });
    }
  } catch (error) {
    console.error('Error processing request:', error);
    return new Response(JSON.stringify({ error: (error as Error).message }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 500,
    });
  }
});

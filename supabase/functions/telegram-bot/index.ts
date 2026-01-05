// Telegram Bot Edge Function - Webhook Handler// Receives messages from Telegram, parses transactions, and stores in Supabase

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import { parseTelegramUpdate, sendTelegramMessage, formatCurrency } from '../_shared/platforms/telegram.ts';
import { parseTransaction, parseTransactionWithContext, ParsedTransaction } from '../_shared/parsers/regex.ts';
import { parseWithGemini } from '../_shared/parsers/gemini.ts';
import { parseWithOpenAI } from '../_shared/parsers/openai.ts';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

// Environment variables
const TELEGRAM_BOT_TOKEN = Deno.env.get('TELEGRAM_BOT_TOKEN')!;
const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;

// Initialize Supabase client with service role (bypass RLS)
const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

// Types for user data
interface UserCategory {
  id: string;
  name: string;
  type: 'income' | 'expense';
}

interface UserWallet {
  id: string;
  name: string;
}

interface UserContext {
  categories: UserCategory[];
  wallets: UserWallet[];
}

/**
 * Fetch user's categories and wallets for context
 */
async function getUserContext(userId: string): Promise<UserContext> {
  const [categoriesResult, walletsResult] = await Promise.all([
    supabase.from('categories').select('id, name, type').eq('user_id', userId).eq('is_hidden', false),
    supabase.from('wallets').select('id, name').eq('user_id', userId).eq('is_hidden', false),
  ]);

  return {
    categories: (categoriesResult.data || []) as UserCategory[],
    wallets: (walletsResult.data || []) as UserWallet[],
  };
}

/**
 * Link Telegram account to Finoteku user
 */
async function linkTelegramAccount(userId: string, telegramId: number, telegramUsername: string | undefined): Promise<boolean> {
  try {
    // Check if user exists
    const { data: userExists } = await supabase.from('users').select('id').eq('id', userId).single();

    if (!userExists) {
      console.error('User not found:', userId);
      return false;
    }

    // Check if telegram is already linked to another account
    const { data: existingLink } = await supabase.from('bot_links').select('user_id').eq('platform', 'telegram').eq('platform_user_id', telegramId.toString()).single();

    if (existingLink) {
      if (existingLink.user_id === userId) {
        return true; // Already linked to this user
      }
      return false; // Linked to different user
    }

    // Create new link
    const { error } = await supabase.from('bot_links').insert({
      user_id: userId,
      platform: 'telegram',
      platform_user_id: telegramId.toString(),
      platform_username: telegramUsername || null,
      is_active: true,
      ai_provider: 'none',
    });

    return !error;
  } catch (e) {
    console.error('Error linking account:', e);
    return false;
  }
}

/**
 * Get user info by Telegram ID
 */
async function getUserByTelegramId(telegramId: number): Promise<{
  userId: string;
  aiProvider: string;
  aiApiKey: string | null;
} | null> {
  const { data, error } = await supabase.rpc('get_user_by_platform_id', {
    p_platform: 'telegram',
    p_platform_user_id: telegramId.toString(),
  });

  if (error || !data || data.length === 0) {
    return null;
  }

  return {
    userId: data[0].user_id,
    aiProvider: data[0].ai_provider || 'none',
    aiApiKey: data[0].ai_api_key,
  };
}

/**
 * Find best matching category from user's categories
 */
function findBestCategory(hint: string, categories: UserCategory[], type: 'income' | 'expense'): string | null {
  const lowerHint = hint.toLowerCase();
  const typeCategories = categories.filter((c) => c.type === type);

  // Exact match
  const exact = typeCategories.find((c) => c.name.toLowerCase() === lowerHint);
  if (exact) return exact.id;

  // Contains match
  const contains = typeCategories.find((c) => c.name.toLowerCase().includes(lowerHint) || lowerHint.includes(c.name.toLowerCase()));
  if (contains) return contains.id;

  // Return first category of that type as default
  return typeCategories[0]?.id || null;
}

/**
 * Find best matching wallet from user's wallets
 */
function findBestWallet(hint: string | null, wallets: UserWallet[]): string | null {
  if (!hint || wallets.length === 0) {
    return wallets[0]?.id || null;
  }

  const lowerHint = hint.toLowerCase();

  // Exact match
  const exact = wallets.find((w) => w.name.toLowerCase() === lowerHint);
  if (exact) return exact.id;

  // Contains match
  const contains = wallets.find((w) => w.name.toLowerCase().includes(lowerHint) || lowerHint.includes(w.name.toLowerCase()));
  if (contains) return contains.id;

  // Return first wallet as default
  return wallets[0]?.id || null;
}

/**
 * Create transaction in database
 */
async function createTransaction(userId: string, walletId: string, categoryId: string, amount: number, notes: string): Promise<boolean> {
  const { error } = await supabase.from('transactions').insert({
    user_id: userId,
    wallet_id: walletId,
    category_id: categoryId,
    amount,
    notes,
    date: new Date().toISOString().split('T')[0],
  });

  return !error;
}

/**
 * Parse message using appropriate AI provider or fallback to RegEx
 * Now with user context for smarter category matching
 */
async function parseMessage(text: string, aiProvider: string, aiApiKey: string | null, userContext: UserContext): Promise<ParsedTransaction | null> {
  // Build category names for AI context
  const incomeCategories = userContext.categories.filter((c) => c.type === 'income').map((c) => c.name);
  const expenseCategories = userContext.categories.filter((c) => c.type === 'expense').map((c) => c.name);
  const walletNames = userContext.wallets.map((w) => w.name);

  // Try AI parsing if configured
  if (aiProvider !== 'none' && aiApiKey) {
    let aiResult: ParsedTransaction | null = null;

    if (aiProvider === 'gemini') {
      aiResult = await parseWithGemini(text, aiApiKey, {
        incomeCategories,
        expenseCategories,
        walletNames,
      });
    } else if (aiProvider === 'openai') {
      aiResult = await parseWithOpenAI(text, aiApiKey, {
        incomeCategories,
        expenseCategories,
        walletNames,
      });
    }

    if (aiResult) {
      return aiResult;
    }
  }

  // Fallback to RegEx parser with context
  return parseTransactionWithContext(text, {
    incomeCategories,
    expenseCategories,
    walletNames,
  });
}

/**
 * Handle /start command (with or without linking payload)
 */
function getStartMessage(): string {
  return `👋 <b>Selamat datang di Finoteku Bot!</b>

Saya bisa membantu Anda mencatat transaksi dengan cepat.

<b>Cara Pakai:</b>
Kirim pesan seperti:
• <code>gajian 3jt</code> → Pemasukan Rp3.000.000
• <code>jajan 50k alfamart</code> → Pengeluaran Rp50.000
• <code>bayar listrik 850k bca</code> → Pengeluaran dari BCA

<b>Tips:</b>
• Gunakan "k/rb" untuk ribuan (50k = Rp50.000)
• Gunakan "jt/m" untuk jutaan (1jt = Rp1.000.000)
• Sebutkan nama wallet untuk auto-select

⚙️ Untuk setting AI dan lainnya, buka aplikasi Finoteku.`;
}

function getLinkSuccessMessage(): string {
  return `✅ <b>Akun berhasil terhubung!</b>

Sekarang Anda bisa mencatat transaksi langsung dari Telegram.

<b>Contoh:</b>
• <code>makan 50k</code>
• <code>gajian 3jt mandiri</code>

Ketik /help untuk panduan lengkap.`;
}

function getLinkFailedMessage(): string {
  return `❌ <b>Gagal menghubungkan akun</b>

Kemungkinan penyebab:
• Link sudah kadaluarsa
• Akun Telegram sudah terhubung ke akun lain

Silakan coba lagi dari aplikasi Finoteku:
Settings → Chat Bot → Hubungkan Telegram`;
}

/**
 * Handle /help command
 */
function getHelpMessage(): string {
  return `📖 <b>Panduan Finoteku Bot</b>

<b>Format Pesan:</b>
<code>[deskripsi] [nominal] [wallet]</code>

<b>Contoh:</b>
• <code>gajian 3jt</code> → Pemasukan
• <code>makan siang 25rb</code> → Pengeluaran
• <code>bonus proyek 500k mandiri</code> → ke Mandiri
• <code>beli bensin 100k bca</code> → dari BCA

<b>Nominal:</b>
• 50k atau 50rb = Rp50.000
• 1jt atau 1m = Rp1.000.000
• 1.5jt = Rp1.500.000

<b>Perintah:</b>
/start - Pesan selamat datang
/help - Panduan ini`;
}

// Main handler
Deno.serve(async (req: Request) => {
  // Handle CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const body = await req.json();
    const message = parseTelegramUpdate(body);

    if (!message || !message.text) {
      return new Response('No message', { status: 200 });
    }

    const chatId = message.chat.id;
    const telegramId = message.from.id;
    const telegramUsername = message.from.username;
    const text = message.text.trim();

    // Handle /start with linking payload: /start <user_id>
    if (text.startsWith('/start')) {
      const parts = text.split(' ');

      if (parts.length > 1) {
        const userId = parts[1];
        const uuidRegex = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
        if (uuidRegex.test(userId)) {
          const success = await linkTelegramAccount(userId, telegramId, telegramUsername);

          if (success) {
            await sendTelegramMessage(TELEGRAM_BOT_TOKEN, chatId, getLinkSuccessMessage());
          } else {
            await sendTelegramMessage(TELEGRAM_BOT_TOKEN, chatId, getLinkFailedMessage());
          }
          return new Response('OK', { status: 200 });
        }
      }

      await sendTelegramMessage(TELEGRAM_BOT_TOKEN, chatId, getStartMessage());
      return new Response('OK', { status: 200 });
    }

    if (text === '/help') {
      await sendTelegramMessage(TELEGRAM_BOT_TOKEN, chatId, getHelpMessage());
      return new Response('OK', { status: 200 });
    }

    // Get user by Telegram ID
    const user = await getUserByTelegramId(telegramId);

    if (!user) {
      await sendTelegramMessage(
        TELEGRAM_BOT_TOKEN,
        chatId,
        `⚠️ <b>Akun belum terhubung</b>

Silakan hubungkan akun Telegram Anda di aplikasi Finoteku:
Settings → Chat Bot → Hubungkan Telegram`
      );
      return new Response('User not linked', { status: 200 });
    }

    // Fetch user's categories and wallets for context
    const userContext = await getUserContext(user.userId);

    if (userContext.categories.length === 0 || userContext.wallets.length === 0) {
      await sendTelegramMessage(
        TELEGRAM_BOT_TOKEN,
        chatId,
        `⚠️ <b>Belum ada kategori atau wallet</b>

Silakan buat kategori dan wallet terlebih dahulu di aplikasi Finoteku.`
      );
      return new Response('No categories or wallets', { status: 200 });
    }

    // Parse the message with user context
    const parsed = await parseMessage(text, user.aiProvider, user.aiApiKey, userContext);

    if (!parsed) {
      await sendTelegramMessage(
        TELEGRAM_BOT_TOKEN,
        chatId,
        `❌ <b>Tidak dapat memahami pesan</b>

Pastikan menyertakan nominal, contoh:
• <code>makan 50k</code>
• <code>gajian 3jt</code>`
      );
      return new Response('Parse failed', { status: 200 });
    }

    // Find matching wallet and category
    const walletId = findBestWallet(parsed.walletHint, userContext.wallets);
    const categoryId = findBestCategory(parsed.categoryHint, userContext.categories, parsed.type);

    if (!walletId) {
      await sendTelegramMessage(
        TELEGRAM_BOT_TOKEN,
        chatId,
        `❌ <b>Wallet tidak ditemukan</b>

Silakan buat wallet terlebih dahulu di aplikasi Finoteku.`
      );
      return new Response('No wallet', { status: 200 });
    }

    if (!categoryId) {
      await sendTelegramMessage(
        TELEGRAM_BOT_TOKEN,
        chatId,
        `❌ <b>Kategori tidak ditemukan</b>

Silakan buat kategori ${parsed.type === 'income' ? 'pemasukan' : 'pengeluaran'} terlebih dahulu di aplikasi Finoteku.`
      );
      return new Response('No category', { status: 200 });
    }

    // Create transaction
    const success = await createTransaction(user.userId, walletId, categoryId, parsed.amount, parsed.notes);

    if (success) {
      const typeEmoji = parsed.type === 'income' ? '💰' : '💸';
      const typeText = parsed.type === 'income' ? 'Pemasukan' : 'Pengeluaran';
      const walletName = userContext.wallets.find((w) => w.id === walletId)?.name || 'Unknown';
      const categoryName = userContext.categories.find((c) => c.id === categoryId)?.name || parsed.categoryHint;

      await sendTelegramMessage(
        TELEGRAM_BOT_TOKEN,
        chatId,
        `✅ <b>${typeText} dicatat!</b>

${typeEmoji} ${formatCurrency(parsed.amount)}
📁 ${categoryName}
💳 ${walletName}
📝 ${parsed.notes}`
      );
    } else {
      await sendTelegramMessage(
        TELEGRAM_BOT_TOKEN,
        chatId,
        `❌ <b>Gagal menyimpan</b>

Terjadi kesalahan saat menyimpan transaksi. Silakan coba lagi.`
      );
    }

    return new Response('OK', { status: 200 });
  } catch (error) {
    console.error('Error:', error);
    return new Response('Internal error', { status: 500 });
  }
});

import type { SupabaseClient } from 'https://esm.sh/@supabase/supabase-js@2';
import { sendTelegramMessage } from '../../_shared/platforms/telegram.ts';
import { linkTelegramAccount, getUserByTelegramId } from '../utils/context.ts';

function getStartMessage(): string {
  return `👋 <b>Selamat datang di Finoteku Bot!</b>

Saya adalah asisten virtual untuk mencatat keuangan Anda.

<b>Untuk memulai:</b>
Silakan hubungkan akun Telegram ini melalui aplikasi Finoteku.
Buka <b>Settings → Chat Bot → Hubungkan Telegram</b>.

Setelah terhubung, Anda bisa mencatat transaksi langsung dari sini!`;
}

function getLinkSuccessMessage(): string {
  return `✅ <b>Akun berhasil terhubung!</b>

Sekarang Anda bisa mencatat transaksi langsung dari Telegram.

<b>Contoh:</b>
• <code>makan 50k cash</code>
• <code>gaji 3jt mandiri</code>
• <code>transport 25k kemarin</code>

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

function getHelpMessage(): string {
  return `📖 <b>Panduan Finoteku Bot</b>

<b>📝 Input Transaksi:</b>
<code>[kategori] [nominal] [wallet] [waktu]</code>

<b>Contoh:</b>
• <code>makan 50k cash</code>
• <code>gaji 5jt mandiri</code>
• <code>transport 25k kemarin</code>

<b>💬 Tanya Bot (Mode AI):</b>
• <code>berapa saldo?</code> → lihat saldo
• <code>ringkasan bulan ini</code> → laporan bulanan
• <code>saldo bca</code> → lihat saldo spesifik

<b>⏰ Waktu:</b>
kemarin, besok, lusa

<b>⚙️ Setting Bot:</b>
Mode Regex: hanya terima input manual
Mode AI: bisa diajak ngobrol & tanya jawab

Ubah di App Finoteku → Settings → Chat Bot`;
}

export async function handleCommand(supabase: SupabaseClient, telegramToken: string, chatId: number, originalText: string, telegramId: number, telegramUsername?: string): Promise<Response | null> {
  // Handle /start with linking payload
  if (originalText.startsWith('/start')) {
    const parts = originalText.split(' ');

    if (parts.length > 1) {
      const userId = parts[1];
      const uuidRegex = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
      if (uuidRegex.test(userId)) {
        const success = await linkTelegramAccount(supabase, userId, telegramId, telegramUsername);

        if (success) {
          await sendTelegramMessage(telegramToken, chatId, getLinkSuccessMessage());
        } else {
          await sendTelegramMessage(telegramToken, chatId, getLinkFailedMessage());
        }
        return new Response('OK', { status: 200 });
      }
    }

    // Check if already linked - show personalized message
    const existingUser = await getUserByTelegramId(supabase, telegramId);
    if (existingUser) {
      const modeLabels: Record<string, string> = {
        regex: '📝 Mode: RegEx (Input saja)',
        server_key: '🤖 Mode: AI Server (Input + Tanya)',
        user_key: '🔑 Mode: AI Key Pribadi (Input + Tanya)',
      };
      const modeLabel = modeLabels[existingUser.parserMode] || '📝 Mode: RegEx';

      await sendTelegramMessage(
        telegramToken,
        chatId,
        `👋 <b>Hai! Bot sudah terhubung.</b>

${modeLabel}

<b>Input:</b> <code>makan 50k cash</code>
<b>Tanya:</b> <code>berapa saldo?</code> (AI mode)

Ketik /help untuk panduan lengkap.`
      );
    } else {
      await sendTelegramMessage(telegramToken, chatId, getStartMessage());
    }
    return new Response('OK', { status: 200 });
  }

  if (originalText === '/help') {
    await sendTelegramMessage(telegramToken, chatId, getHelpMessage());
    return new Response('OK', { status: 200 });
  }

  if (originalText === '/balance') {
    // Trigger balance query - return null to let it be handled by query handler
    return null;
  }

  if (originalText === '/history') {
    // Trigger history query - return null to let it be handled by query handler
    return null;
  }

  return null; // Not a command this handler processes (or return null to continue chain)
}

import { SupabaseClient } from 'https://esm.sh/@supabase/supabase-js@2';
import { sendTelegramMessage, sendTelegramMessageWithButtons, editTelegramMessage, answerCallbackQuery, formatCurrency } from '../../_shared/platforms/telegram.ts';
import { UserContext, getPendingTransaction, updatePendingTransaction, deletePendingTransaction, createTransaction, savePendingTransaction } from '../utils/context.ts';
import { findWalletByName, findCategoryByName, calculateTransactionDate, formatDateIndonesian, buildConfirmationMessage, findBestWallet, findBestCategory } from '../utils/helpers.ts';
import { parseDateOffset, ParsedTransaction } from '../../_shared/parsers/regex.ts';

/**
 * Handle updates to pending transactions (or confirmations via text)
 */
export async function handlePendingTransaction(supabase: SupabaseClient, telegramToken: string, chatId: number, userId: string, text: string, userContext: UserContext): Promise<Response | null> {
  const pending = await getPendingTransaction(supabase, chatId);
  if (!pending) return null; // No pending transaction

  // Check update logic
  let updated = false;
  let newWalletId = pending.wallet_id;
  let newCategoryId = pending.category_id;
  let newDate = pending.date;
  let dateOffset = 0;

  // Check for wallet update: "pakai cash", "pakai bca", etc.
  const walletMatch = text.match(/^pakai\s+(.+)$/i) || text.match(/^pake\s+(.+)$/i) || text.match(/^ganti\s+(.+)$/i);
  if (walletMatch) {
    const walletName = walletMatch[1].trim();
    const foundWallet = findWalletByName(walletName, userContext.wallets);
    if (foundWallet) {
      newWalletId = foundWallet;
      updated = true;
    }
  }

  // Check for date update: "kemarin", "besok", "lusa"
  const detectedDateOffset = parseDateOffset(text);
  if (detectedDateOffset !== 0) {
    newDate = calculateTransactionDate(detectedDateOffset);
    dateOffset = detectedDateOffset;
    updated = true;
  }

  // Check for category update (single word that matches a category)
  if (!walletMatch && detectedDateOffset === 0) {
    const foundCategory = findCategoryByName(text, userContext.categories, pending.type);
    if (foundCategory) {
      newCategoryId = foundCategory;
      updated = true;
    }
  }

  if (updated) {
    await updatePendingTransaction(supabase, pending.id, {
      wallet_id: newWalletId,
      category_id: newCategoryId,
      date: newDate,
    });

    // Get updated display names
    const walletName = userContext.wallets.find((w) => w.id === newWalletId)?.name || 'Unknown';
    const categoryName = userContext.categories.find((c) => c.id === newCategoryId)?.name || 'Unknown';
    const dateDisplay = formatDateIndonesian(newDate, dateOffset);

    const confirmMessage = buildConfirmationMessage(pending.type, pending.amount, categoryName, walletName, dateDisplay, pending.notes);

    await sendTelegramMessageWithButtons(telegramToken, chatId, confirmMessage, [
      [
        { text: '✅ Ya, Simpan', callback_data: 'confirm_yes' },
        { text: '❌ Tidak', callback_data: 'confirm_no' },
      ],
    ]);

    return new Response('OK', { status: 200 });
  }

  // Check for text confirmation
  if (text === 'ya' || text === 'y' || text === 'yes' || text === 'ok' || text === 'oke') {
    const success = await createTransaction(supabase, pending.user_id, pending.wallet_id, pending.category_id, pending.amount, pending.notes, pending.date);
    await deletePendingTransaction(supabase, pending.id);

    if (success) {
      await sendTelegramMessage(telegramToken, chatId, '✅ <b>Transaksi berhasil disimpan!</b>');
    } else {
      await sendTelegramMessage(telegramToken, chatId, '❌ <b>Gagal menyimpan. Silakan coba lagi.</b>');
    }
    return new Response('OK', { status: 200 });
  }

  if (text === 'tidak' || text === 'no' || text === 'n' || text === 'batal' || text === 'cancel') {
    await deletePendingTransaction(supabase, pending.id);
    await sendTelegramMessage(telegramToken, chatId, '❌ <b>Transaksi dibatalkan.</b>');
    return new Response('OK', { status: 200 });
  }

  // Fallback: If pending exists but unknown command, show help
  const walletName = userContext.wallets.find((w) => w.id === pending.wallet_id)?.name || 'Unknown';
  const categoryName = userContext.categories.find((c) => c.id === pending.category_id)?.name || 'Unknown';
  const dateDisplay = formatDateIndonesian(pending.date, 0);

  await sendTelegramMessage(
    telegramToken,
    chatId,
    `📝 <b>Masih ada transaksi menunggu konfirmasi:</b>

💸 ${formatCurrency(pending.amount)} - ${categoryName}
💳 ${walletName} | 📅 ${dateDisplay}

<b>Untuk update:</b>
• <code>pakai [wallet]</code> - ganti wallet
• <code>kemarin/besok</code> - ganti tanggal
• Ketik <b>nama kategori</b> - ganti kategori

<b>Untuk konfirmasi:</b>
• <code>ya</code> - simpan
• <code>tidak</code> - batalkan`
  );
  return new Response('OK', { status: 200 });
}

/**
 * Handle new parsed transaction processing
 */
export async function handleNewTransaction(supabase: SupabaseClient, telegramToken: string, chatId: number, userId: string, userContext: UserContext, parsed: ParsedTransaction): Promise<Response> {
  // Find matching wallet and category
  const walletId = findBestWallet(parsed.walletHint, userContext.wallets);
  const categoryId = findBestCategory(parsed.categoryHint, userContext.categories, parsed.type);

  if (!walletId) {
    await sendTelegramMessage(
      telegramToken,
      chatId,
      `❌ <b>Wallet tidak ditemukan</b>

Silakan buat wallet terlebih dahulu di aplikasi Finoteku.`
    );
    return new Response('No wallet', { status: 200 });
  }

  if (!categoryId) {
    await sendTelegramMessage(
      telegramToken,
      chatId,
      `❌ <b>Kategori tidak ditemukan</b>

Silakan buat kategori ${parsed.type === 'income' ? 'pemasukan' : 'pengeluaran'} terlebih dahulu di aplikasi Finoteku.`
    );
    return new Response('No category', { status: 200 });
  }

  // Calculate transaction date
  const transactionDate = calculateTransactionDate(parsed.dateOffset);

  // Get display names
  const walletName = userContext.wallets.find((w) => w.id === walletId)?.name || 'Unknown';
  const categoryName = userContext.categories.find((c) => c.id === categoryId)?.name || parsed.categoryHint;
  const dateDisplay = formatDateIndonesian(transactionDate, parsed.dateOffset);

  // Save pending transaction
  const pendingId = await savePendingTransaction(supabase, chatId, userId, walletId, categoryId, parsed.amount, parsed.notes, transactionDate, parsed.type);

  if (!pendingId) {
    await sendTelegramMessage(telegramToken, chatId, '❌ <b>Gagal menyimpan. Silakan coba lagi.</b>');
    return new Response('Failed to save pending', { status: 200 });
  }

  // Send confirmation with inline buttons
  const confirmMessage = buildConfirmationMessage(parsed.type, parsed.amount, categoryName, walletName, dateDisplay, parsed.notes);

  await sendTelegramMessageWithButtons(telegramToken, chatId, confirmMessage, [
    [
      { text: '✅ Ya, Simpan', callback_data: 'confirm_yes' },
      { text: '❌ Tidak', callback_data: 'confirm_no' },
    ],
  ]);

  return new Response('OK', { status: 200 });
}

/**
 * Handle callback queries (inline buttons)
 */
export async function handleTransactionCallback(supabase: SupabaseClient, telegramToken: string, callbackQuery: any): Promise<Response> {
  const { data, message } = callbackQuery;
  const chatId = message.chat.id;

  if (data === 'confirm_yes') {
    const pending = await getPendingTransaction(supabase, chatId);
    if (pending) {
      const success = await createTransaction(supabase, pending.user_id, pending.wallet_id, pending.category_id, pending.amount, pending.notes, pending.date);
      await deletePendingTransaction(supabase, pending.id);

      if (success) {
        await editTelegramMessage(telegramToken, chatId, message.message_id, `✅ <b>Transaksi berhasil disimpan!</b>\n\n${message.text.split('\n').slice(2, 6).join('\n')}`);
      } else {
        await sendTelegramMessage(telegramToken, chatId, '❌ <b>Gagal menyimpan. Silakan coba lagi.</b>');
      }
    } else {
      await sendTelegramMessage(telegramToken, chatId, '⚠️ <b>Transaksi sudah kadaluarsa atau tidak ditemukan.</b>');
    }
  } else if (data === 'confirm_no') {
    const pending = await getPendingTransaction(supabase, chatId);
    if (pending) {
      await deletePendingTransaction(supabase, pending.id);
    }
    await editTelegramMessage(telegramToken, chatId, message.message_id, '❌ <b>Transaksi dibatalkan.</b>');
  }

  // Always answer callback to stop loading spinner
  await answerCallbackQuery(telegramToken, callbackQuery.id);
  return new Response('OK', { status: 200 });
}

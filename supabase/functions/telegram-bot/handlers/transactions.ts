import { SupabaseClient } from 'https://esm.sh/@supabase/supabase-js@2';
import {
  answerCallbackQuery,
  editTelegramMessage,
  formatCurrency,
  sendTelegramMessage,
  sendTelegramMessageWithButtons,
} from '../../_shared/platforms/telegram.ts';
import {
  createTransaction,
  deletePendingTransaction,
  getPendingTransaction,
  savePendingTransaction,
  updatePendingTransaction,
  UserContext,
} from '../utils/context.ts';
import {
  buildConfirmationMessage,
  calculateTransactionDate,
  findBestCategory,
  findBestWallet,
  findCategoryByName,
  findWalletByName,
  formatDateIndonesian,
} from '../utils/helpers.ts';
import { parseDateOffset, ParsedTransaction } from '../../_shared/parsers/regex.ts';
import { GeminiUserContext, parseTransactionUpdate } from '../../_shared/parsers/gemini.ts';

/**
 * Handle updates to pending transactions (or confirmations via text)
 */
export async function handlePendingTransaction(
  supabase: SupabaseClient,
  telegramToken: string,
  chatId: number,
  text: string,
  userContext: UserContext,
  aiApiKey?: string | null,
): Promise<Response | null> {
  const pending = await getPendingTransaction(supabase, chatId);
  if (!pending) return null; // No pending transaction

  const textLower = text.toLowerCase().trim();

  // Check for text confirmation first
  if (['ya', 'y', 'yes', 'ok', 'oke', 'simpan', 'save'].includes(textLower)) {
    const success = await createTransaction(
      supabase,
      pending.user_id,
      pending.wallet_id,
      pending.category_id,
      pending.amount,
      pending.notes,
      pending.date,
    );
    await deletePendingTransaction(supabase, pending.id);

    if (success) {
      await sendTelegramMessage(telegramToken, chatId, '✅ <b>Transaksi berhasil disimpan!</b>');
    } else {
      await sendTelegramMessage(
        telegramToken,
        chatId,
        '❌ <b>Gagal menyimpan. Silakan coba lagi.</b>',
      );
    }
    return new Response('OK', { status: 200 });
  }

  if (['tidak', 'no', 'n', 'batal', 'cancel', 'batalkan'].includes(textLower)) {
    await deletePendingTransaction(supabase, pending.id);
    await sendTelegramMessage(telegramToken, chatId, '❌ <b>Transaksi dibatalkan.</b>');
    return new Response('OK', { status: 200 });
  }

  // Get current display values
  const currentWalletName = userContext.wallets.find((w) => w.id === pending.wallet_id)?.name ||
    'Unknown';
  const currentCategoryName =
    userContext.categories.find((c) => c.id === pending.category_id)?.name || 'Unknown';

  // Check update logic - simple patterns first
  let updated = false;
  let newWalletId = pending.wallet_id;
  let newCategoryId = pending.category_id;
  let newDate = pending.date;
  let newAmount = pending.amount;
  let newNotes = pending.notes;

  // Check for wallet update: "pakai cash", "pakai bca", etc.
  const walletMatch = text.match(/^pakai\s+(.+)$/i) || text.match(/^pake\s+(.+)$/i) ||
    text.match(/^wallet\s+(.+)$/i);
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

  // If no simple pattern matched and AI key available, use AI to parse complex updates
  if (!updated && aiApiKey) {
    console.log('Using AI to parse update request:', text);

    const geminiContext: GeminiUserContext = {
      incomeCategories: userContext.categories.filter((c) => c.type === 'income').map((c) =>
        c.name
      ),
      expenseCategories: userContext.categories.filter((c) => c.type === 'expense').map((c) =>
        c.name
      ),
      walletNames: userContext.wallets.map((w) => w.name),
      incomeCategoriesWithParent: userContext.categories.filter((c) => c.type === 'income').map((
        c,
      ) => ({ name: c.name, parent: c.parentName })),
      expenseCategoriesWithParent: userContext.categories.filter((c) => c.type === 'expense').map((
        c,
      ) => ({ name: c.name, parent: c.parentName })),
    };

    const parsedUpdate = await parseTransactionUpdate(
      text,
      aiApiKey,
      {
        amount: pending.amount,
        notes: pending.notes,
        category: currentCategoryName,
        wallet: currentWalletName,
        date: pending.date,
      },
      geminiContext,
    );

    if (parsedUpdate) {
      // Apply amount update
      if (parsedUpdate.amount && parsedUpdate.amount > 0) {
        newAmount = parsedUpdate.amount;
        updated = true;
      }

      // Apply notes update
      if (parsedUpdate.notes) {
        newNotes = parsedUpdate.notes;
        updated = true;
      }

      // Apply category update
      if (parsedUpdate.categoryHint) {
        const foundCategory = findCategoryByName(
          parsedUpdate.categoryHint,
          userContext.categories,
          pending.type,
        );
        if (foundCategory) {
          newCategoryId = foundCategory;
          updated = true;
        }
      }

      // Apply wallet update
      if (parsedUpdate.walletHint) {
        const foundWallet = findWalletByName(parsedUpdate.walletHint, userContext.wallets);
        if (foundWallet) {
          newWalletId = foundWallet;
          updated = true;
        }
      }

      // Apply date update
      if (parsedUpdate.dateOffset !== undefined && parsedUpdate.dateOffset !== null) {
        newDate = calculateTransactionDate(parsedUpdate.dateOffset);
        updated = true;
      }
    }
  }

  if (updated) {
    await updatePendingTransaction(supabase, pending.id, {
      wallet_id: newWalletId,
      category_id: newCategoryId,
      date: newDate,
      amount: newAmount,
      notes: newNotes,
    });

    // Get updated display names
    const walletName = userContext.wallets.find((w) => w.id === newWalletId)?.name || 'Unknown';
    const category = userContext.categories.find((c) => c.id === newCategoryId);
    const categoryName = category?.name || 'Unknown';
    const parentCategoryName = category?.parentName || null;
    const dateDisplay = formatDateIndonesian(newDate);

    const confirmMessage = buildConfirmationMessage(
      pending.type,
      newAmount,
      categoryName,
      walletName,
      dateDisplay,
      newNotes,
      parentCategoryName,
    );

    await sendTelegramMessageWithButtons(telegramToken, chatId, confirmMessage, [
      [
        { text: '✅ Ya, Simpan', callback_data: 'confirm_yes' },
        { text: '❌ Tidak', callback_data: 'confirm_no' },
      ],
    ]);

    return new Response('OK', { status: 200 });
  }

  // Fallback: If pending exists but unknown command, show help
  const walletName = userContext.wallets.find((w) => w.id === pending.wallet_id)?.name || 'Unknown';
  const categoryName = userContext.categories.find((c) => c.id === pending.category_id)?.name ||
    'Unknown';
  const dateDisplay = formatDateIndonesian(pending.date);

  await sendTelegramMessage(
    telegramToken,
    chatId,
    `📝 <b>Masih ada transaksi menunggu konfirmasi:</b>

💸 ${formatCurrency(pending.amount)} - ${categoryName}
💳 ${walletName} | 📅 ${dateDisplay}
📝 ${pending.notes}

<b>Untuk update (bisa pakai bahasa natural):</b>
• "nominal jadi 50k" atau "ganti 100rb"
• "catatan ganti Makan Siang"
• "pakai BCA" atau "wallet Cash"
• "kemarin" atau "besok"
• Kombinasi: "nominal 41k dan catatan jadi Es Krim"

<b>Untuk konfirmasi:</b>
• <code>ya</code> / <code>ok</code> - simpan
• <code>tidak</code> / <code>batal</code> - batalkan`,
  );
  return new Response('OK', { status: 200 });
}

/**
 * Handle new parsed transaction processing
 */
export async function handleNewTransaction(
  supabase: SupabaseClient,
  telegramToken: string,
  chatId: number,
  userId: string,
  userContext: UserContext,
  parsed: ParsedTransaction,
): Promise<Response> {
  // Find matching wallet and category
  const walletId = findBestWallet(parsed.walletHint, userContext.wallets);
  const categoryId = findBestCategory(parsed.categoryHint, userContext.categories, parsed.type);

  if (!walletId) {
    await sendTelegramMessage(
      telegramToken,
      chatId,
      `❌ <b>Wallet tidak ditemukan</b>

Silakan buat wallet terlebih dahulu di aplikasi Finoteku.`,
    );
    return new Response('No wallet', { status: 200 });
  }

  if (!categoryId) {
    await sendTelegramMessage(
      telegramToken,
      chatId,
      `❌ <b>Kategori tidak ditemukan</b>

Silakan buat kategori ${
        parsed.type === 'income' ? 'pemasukan' : 'pengeluaran'
      } terlebih dahulu di aplikasi Finoteku.`,
    );
    return new Response('No category', { status: 200 });
  }

  // Calculate transaction date
  const transactionDate = calculateTransactionDate(parsed.dateOffset);

  // Get display names
  const walletName = userContext.wallets.find((w) => w.id === walletId)?.name || 'Unknown';
  const category = userContext.categories.find((c) => c.id === categoryId);
  const categoryName = category?.name || parsed.categoryHint;
  const parentCategoryName = category?.parentName || null;
  const dateDisplay = formatDateIndonesian(transactionDate);

  // Save pending transaction
  const pendingId = await savePendingTransaction(
    supabase,
    chatId,
    userId,
    walletId,
    categoryId,
    parsed.amount,
    parsed.notes,
    transactionDate,
    parsed.type,
  );

  if (!pendingId) {
    await sendTelegramMessage(
      telegramToken,
      chatId,
      '❌ <b>Gagal menyimpan. Silakan coba lagi.</b>',
    );
    return new Response('Failed to save pending', { status: 200 });
  }

  // Send confirmation with inline buttons
  const confirmMessage = buildConfirmationMessage(
    parsed.type,
    parsed.amount,
    categoryName,
    walletName,
    dateDisplay,
    parsed.notes,
    parentCategoryName,
  );

  await sendTelegramMessageWithButtons(telegramToken, chatId, confirmMessage, [
    [
      { text: '✅ Ya, Simpan', callback_data: 'confirm_yes' },
      { text: '❌ Tidak', callback_data: 'confirm_no' },
    ],
  ]);

  return new Response('OK', { status: 200 });
}

interface CallbackQuery {
  id: string;
  data: string;
  message: {
    chat: { id: number };
    message_id: number;
    text: string;
  };
}

/**
 * Handle callback queries (inline buttons)
 */
export async function handleTransactionCallback(
  supabase: SupabaseClient,
  telegramToken: string,
  callbackQuery: CallbackQuery,
): Promise<Response> {
  const { data, message } = callbackQuery;
  const chatId = message.chat.id;

  if (data === 'confirm_yes') {
    const pending = await getPendingTransaction(supabase, chatId);
    if (pending) {
      const success = await createTransaction(
        supabase,
        pending.user_id,
        pending.wallet_id,
        pending.category_id,
        pending.amount,
        pending.notes,
        pending.date,
      );
      await deletePendingTransaction(supabase, pending.id);

      if (success) {
        await editTelegramMessage(
          telegramToken,
          chatId,
          message.message_id,
          `✅ <b>Transaksi berhasil disimpan!</b>\n\n${
            message.text.split('\n').slice(2, 6).join('\n')
          }`,
        );
      } else {
        await sendTelegramMessage(
          telegramToken,
          chatId,
          '❌ <b>Gagal menyimpan. Silakan coba lagi.</b>',
        );
      }
    } else {
      await sendTelegramMessage(
        telegramToken,
        chatId,
        '⚠️ <b>Transaksi sudah kadaluarsa atau tidak ditemukan.</b>',
      );
    }
  } else if (data === 'confirm_no') {
    const pending = await getPendingTransaction(supabase, chatId);
    if (pending) {
      await deletePendingTransaction(supabase, pending.id);
    }
    await editTelegramMessage(
      telegramToken,
      chatId,
      message.message_id,
      '❌ <b>Transaksi dibatalkan.</b>',
    );
  }

  // Always answer callback to stop loading spinner
  await answerCallbackQuery(telegramToken, callbackQuery.id);
  return new Response('OK', { status: 200 });
}

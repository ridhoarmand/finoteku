/**
 * Pending Handler Tool
 * Menangani konfirmasi, pembatalan, dan update transaksi pending
 * Optimized: generateJSON, compressed prompts, systemInstruction
 */
import type { SupabaseClient } from 'https://esm.sh/@supabase/supabase-js@2';
import { BaseTool, type ToolParams } from '../core/base.ts';
import type { ToolResult } from '../../types.ts';
import type { UserContext } from '../../data/users.ts';
import * as pendingData from '../../data/pending.ts';
import * as transactionData from '../../data/transactions.ts';
import { resolveWalletByHint } from '../../data/wallets.ts';
import type { AIProvider } from '../../providers/base.ts';

// System prompt statis — dikirim via systemInstruction
const UPDATE_SYSTEM_PROMPT =
  `You are a transaction update parser. Extract field changes from user input to update a pending transaction.
You must return a valid JSON object with ONLY the fields that are changed.

Valid keys: "amount" (number), "category" (string), "wallet" (string), "to_wallet" (string), "dateOffset" (number), "notes" (string).

EXAMPLES:
"keterangan Makanan Nasi Bakar" -> {"notes": "Makanan Nasi Bakar"}
"BCA dan Gopay" -> {"wallet": "BCA", "to_wallet": "Gopay"}
"update kemarin" -> {"dateOffset": -1}
"nominalnya 50rb aja" -> {"amount": 50000}
"Ubah kategori Makanan" -> {"category": "Makanan"}

Do NOT translate keys. Do NOT return markdown formatting. ONLY return raw JSON object.`;

interface UpdateParsed {
  amount?: number;
  category?: string;
  wallet?: string;
  to_wallet?: string;
  notes?: string;
  dateOffset?: number;
}

export class PendingHandlerTool extends BaseTool {
  name = 'pending_handler';
  description = 'Menangani konfirmasi, pembatalan, dan update transaksi pending';
  intents = ['confirm', 'cancel', 'update_pending'];

  constructor(
    private supabase: SupabaseClient,
    private ai?: AIProvider,
  ) {
    super();
  }

  async execute(params: ToolParams): Promise<ToolResult> {
    const userContext = params.userContext as UserContext;
    const action = params.action as string;
    const platform = (params.platform as pendingData.Platform) || 'telegram';

    if (!userContext) {
      return this.error('User context diperlukan');
    }

    // Ambil transaksi pending menggunakan user_id + platform
    const pending = await pendingData.get(this.supabase, userContext.userId, platform);

    if (!pending) {
      return this.error('Tidak ada transaksi yang menunggu konfirmasi.');
    }

    switch (action) {
      case 'confirm':
        return await this.confirmTransaction(pending, userContext);

      case 'cancel':
        return await this.cancelTransaction(userContext.userId, platform);

      case 'update_pending':
        return await this.updatePending(userContext, platform, params);

      default:
        return this.error('Action tidak dikenal');
    }
  }

  /**
   * Konfirmasi dan simpan transaksi
   */
  private async confirmTransaction(
    pending: pendingData.PendingTransaction,
    userContext: UserContext,
  ): Promise<ToolResult> {
    console.log('[PendingHandler] Confirming transaction:', {
      type: pending.type,
      category_id: pending.category_id,
      wallet_id: pending.wallet_id,
      to_wallet_id: pending.to_wallet_id,
      amount: pending.amount,
    });

    let error: Error | null = null;

    if (pending.type === 'transfer') {
      const result = await transactionData.createTransfer(this.supabase, pending.user_id, {
        amount: pending.amount,
        date: pending.date,
        notes: pending.notes,
        from_wallet_id: pending.wallet_id,
        to_wallet_id: pending.to_wallet_id!,
        expense_category_id: null,
        income_category_id: null,
      });
      error = result.error;
    } else {
      const result = await transactionData.create(this.supabase, pending.user_id, {
        amount: pending.amount,
        date: pending.date,
        notes: pending.notes,
        category_id: pending.category_id,
        wallet_id: pending.wallet_id,
      });
      error = result.error;
    }

    if (error) {
      return this.error('Gagal menyimpan transaksi: ' + error.message);
    }

    // Hapus pending transaction
    await pendingData.remove(this.supabase, pending.user_id, pending.platform);

    return this.success({ transactionId: pending.id }, `✅ <b>Transaksi berhasil disimpan.</b>`);
  }

  /**
   * Batalkan transaksi pending
   */
  private async cancelTransaction(
    userId: string,
    platform: pendingData.Platform,
  ): Promise<ToolResult> {
    await pendingData.remove(this.supabase, userId, platform);
    return this.success({}, '❌ Transaksi dibatalkan.');
  }

  /**
   * Smart Update - Use AI (generateJSON) to parse update request
   */
  private async updatePending(
    userContext: UserContext,
    platform: pendingData.Platform,
    params: ToolParams,
  ): Promise<ToolResult> {
    const text = params.text as string;
    console.log('[PendingHandler] Smart update request:', text);

    const current = await pendingData.get(this.supabase, userContext.userId, platform);
    if (!current) {
      return this.error('Tidak ada transaksi pending');
    }

    // AI-powered update parsing (generateJSON — no manual extraction)
    if (this.ai) {
      console.log('[PendingHandler] Using AI for smart update');

      const expenseCats = userContext.categories.filter((c) => c.type === 'expense').map((c) =>
        c.name
      );
      const incomeCats = userContext.categories.filter((c) => c.type === 'income').map((c) =>
        c.name
      );

      // User prompt — hanya data dinamis
      const prompt =
        `Current: type=${current.type}, amount=${current.amount}, category=${current.category_name}, wallet=${current.wallet_name}${
          current.to_wallet_name ? `, toWallet=${current.to_wallet_name}` : ''
        }, notes="${current.notes}"

Update: "${text}"

Expense Categories: ${expenseCats.join(', ')}
Income Categories: ${incomeCats.join(', ')}
Wallets: ${userContext.wallets.map((w) => w.name).join(', ')}`;

      try {
        const parsed = await this.ai.generateJSON<UpdateParsed>(prompt, {
          systemPrompt: UPDATE_SYSTEM_PROMPT,
          maxTokens: 150,
          temperature: 0.1,
        });

        const updates: Partial<pendingData.PendingTransactionInput> = {};

        if (parsed.amount) updates.amount = Number(parsed.amount);
        if (parsed.notes) updates.notes = parsed.notes;

        if (parsed.category) {
          let cat = userContext.categories.find((c) =>
            c.name.toLowerCase() === parsed.category!.toLowerCase() && c.type === current.type
          );
          if (!cat) {
            cat = userContext.categories.find((c) =>
              c.name.toLowerCase() === parsed.category!.toLowerCase()
            );
          }
          if (cat) updates.category_id = cat.id;
        }

        if (parsed.wallet) {
          const w = resolveWalletByHint(userContext.wallets, parsed.wallet);
          if (w) updates.wallet_id = w.id;
        }

        if (parsed.to_wallet) {
          const w = resolveWalletByHint(userContext.wallets, parsed.to_wallet);
          if (w) updates.to_wallet_id = w.id;
        }

        if (parsed.dateOffset !== undefined) {
          const newDate = new Date(current.date);
          newDate.setDate(newDate.getDate() + Number(parsed.dateOffset));
          updates.date = newDate.toISOString();
        }

        if (Object.keys(updates).length > 0) {
          console.log('[PendingHandler] Applying AI updates:', updates);
          await pendingData.update(this.supabase, userContext.userId, platform, updates);
          const updated = await pendingData.get(this.supabase, userContext.userId, platform);
          return this.success(
            { ...updated, needsConfirmation: true },
            this.formatPreview(updated!),
          );
        }
      } catch (err) {
        console.error('[PendingHandler] AI Update failed:', err);
      }
    }

    // Fallback to keyword matching
    const updates: Partial<pendingData.PendingTransactionInput> = {};
    const lowerText = text.toLowerCase();

    // Quick wallet detection
    for (const wallet of userContext.wallets) {
      if (lowerText.includes(wallet.name.toLowerCase())) {
        updates.wallet_id = wallet.id;
        break;
      }
    }

    // Quick amount detection
    const amountMatch = text.match(/(\d+)\s*(k|rb|ribu|jt|juta)?/i);
    if (amountMatch && !updates.wallet_id) {
      let amount = parseInt(amountMatch[1]);
      const suffix = amountMatch[2]?.toLowerCase();
      if (suffix === 'k' || suffix === 'rb' || suffix === 'ribu') amount *= 1000;
      if (suffix === 'jt' || suffix === 'juta') amount *= 1000000;
      updates.amount = amount;
    }

    if (Object.keys(updates).length > 0) {
      await pendingData.update(this.supabase, userContext.userId, platform, updates);
      const updated = await pendingData.get(this.supabase, userContext.userId, platform);
      return this.success({ ...updated, needsConfirmation: true }, this.formatPreview(updated!));
    }

    return this.error(
      'Tidak dapat memahami perubahan.\n\n' + 'Contoh:\n' +
        '• "Kategori Makanan, keterangan Nasi Bakar"\n' + '• "BCA", "Gopay"\n' +
        '• "update kemarin"',
    );
  }

  /**
   * Format preview message
   */
  private formatPreview(pending: pendingData.PendingTransaction): string {
    const isIncome = pending.type === 'income';
    const isTransfer = pending.type === 'transfer';
    const emoji = isTransfer ? '🔄' : isIncome ? '💰' : '💸';
    const typeLabel = isTransfer ? 'Transfer' : isIncome ? 'Pemasukan' : 'Pengeluaran';

    const amount = new Intl.NumberFormat('id-ID', {
      style: 'currency',
      currency: 'IDR',
      minimumFractionDigits: 0,
    }).format(pending.amount);

    const dateObj = new Date(pending.date);
    const dateStr = dateObj.toLocaleDateString('id-ID', {
      weekday: 'long',
      day: 'numeric',
      month: 'long',
      year: 'numeric',
    });

    let categoryDisplay = pending.category_name || 'Kategori';
    if (pending.category_parent) {
      categoryDisplay = `${pending.category_parent} > ${categoryDisplay}`;
    }

    let message = `${emoji} <b>${typeLabel} Diperbarui</b>\n\n`;
    message += `📅 ${dateStr}\n`;

    if (isTransfer) {
      message += `📤 Dari: ${pending.wallet_name || '?'}\n`;
      message += `📥 Ke: ${pending.to_wallet_name || '?'}\n`;
    } else {
      message += `💳 ${pending.wallet_name || '-'}\n`;
    }

    message += `💵 ${amount}\n`;

    if (!isTransfer) {
      message += `📁 ${categoryDisplay}\n`;
    }

    message += `📝 ${pending.notes}\n\n`;
    message += `<b>Simpan transaksi ini?</b>`;

    return message;
  }
}

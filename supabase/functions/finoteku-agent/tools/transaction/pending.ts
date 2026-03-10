/**
 * Pending Handler Tool
 * Menangani konfirmasi, pembatalan, dan update transaksi pending
 * Multi-platform support dengan smart entity matching
 */
import type { SupabaseClient } from 'https://esm.sh/@supabase/supabase-js@2';
import { BaseTool, type ToolParams } from '../core/base.ts';
import type { ToolResult } from '../../types.ts';
import type { UserContext } from '../../data/users.ts';
import * as pendingData from '../../data/pending.ts';
import * as transactionData from '../../data/transactions.ts';

export class PendingHandlerTool extends BaseTool {
  name = 'pending_handler';
  description = 'Menangani konfirmasi, pembatalan, dan update transaksi pending';
  intents = ['confirm', 'cancel', 'update_pending'];

  constructor(private supabase: SupabaseClient) {
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
  private async confirmTransaction(pending: pendingData.PendingTransaction, _userContext: UserContext): Promise<ToolResult> {
    console.log('[PendingHandler] Confirming transaction:', {
      category_id: pending.category_id,
      category_name: pending.category_name,
      wallet_id: pending.wallet_id,
      wallet_name: pending.wallet_name,
      amount: pending.amount,
      notes: pending.notes,
    });

    const { error } = await transactionData.create(this.supabase, pending.user_id, {
      amount: pending.amount,
      date: pending.date,
      notes: pending.notes,
      category_id: pending.category_id,
      wallet_id: pending.wallet_id,
    });

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
  private async cancelTransaction(userId: string, platform: pendingData.Platform): Promise<ToolResult> {
    await pendingData.remove(this.supabase, userId, platform);
    return this.success({}, '❌ Transaksi dibatalkan.');
  }

  /**
   * Smart Update - Use AI to parse update request
   * Mendukung: kategori, wallet, nominal, notes
   *
   * Contoh:
   * - "BCA" → Deteksi sebagai wallet
   * - "Kencan Jajan" → AI parse jadi category "Jajan"
   * - "50k" → Deteksi sebagai nominal
   */
  private async updatePending(userContext: UserContext, platform: pendingData.Platform, params: ToolParams): Promise<ToolResult> {
    const text = params.text as string;
    console.log('[PendingHandler] Update request:', text);

    // Get current pending transaction
    const current = await pendingData.get(this.supabase, userContext.userId, platform);
    if (!current) {
      return this.error('Tidak ada transaksi pending');
    }

    const updates: Partial<pendingData.PendingTransactionInput> = {};

    // Smart detection: Try simple keyword matching first for wallet/amount
    const lowerText = text.toLowerCase();

    // Quick wallet detection
    for (const wallet of userContext.wallets) {
      if (lowerText.includes(wallet.name.toLowerCase())) {
        updates.wallet_id = wallet.id;
        console.log(`[PendingHandler] Detected wallet: ${wallet.name}`);
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

      if (amount >= 100 && amount !== current.amount) {
        updates.amount = amount;
        console.log(`[PendingHandler] Detected amount: ${amount}`);
      }
    }

    // For category updates (especially complex ones like "Kencan Jajan")
    // Try to match category names - prioritize child categories
    let categoryDetected = false;

    // First try exact match with child categories
    for (const category of userContext.categories.filter((c) => c.parent_name)) {
      if (lowerText.includes(category.name.toLowerCase())) {
        updates.category_id = category.id;
        console.log(`[PendingHandler] Detected child category: ${category.name}`);
        categoryDetected = true;
        break;
      }
    }

    // Then try parent categories if no child match
    if (!categoryDetected) {
      for (const category of userContext.categories.filter((c) => !c.parent_name)) {
        if (lowerText.includes(category.name.toLowerCase())) {
          updates.category_id = category.id;
          console.log(`[PendingHandler] Detected parent category: ${category.name}`);
          categoryDetected = true;
          break;
        }
      }
    }

    // No updates detected
    if (Object.keys(updates).length === 0) {
      return this.error(
        'Tidak dapat memahami perubahan.\n\n' + 'Contoh:\n' + '• Ketik nama wallet: "BCA", "Gopay"\n' + '• Ketik kategori: "Jajan", "Kencan Jajan"\n' + '• Ketik nominal: "50k", "100rb"'
      );
    }

    console.log('[PendingHandler] Updates to apply:', updates);

    // Apply partial update
    const { success, error } = await pendingData.update(this.supabase, userContext.userId, platform, updates);

    if (!success) {
      return this.error('Gagal update: ' + (error?.message || 'Unknown error'));
    }

    // Fetch updated data with names from VIEW
    const updated = await pendingData.get(this.supabase, userContext.userId, platform);
    if (!updated) {
      return this.error('Transaksi pending tidak ditemukan setelah update');
    }

    return this.success({ ...updated, needsConfirmation: true }, this.formatPreview(updated));
  }

  /**
   * Format preview message
   */
  private formatPreview(pending: pendingData.PendingTransaction): string {
    const isIncome = pending.type === 'income';
    const emoji = isIncome ? '💰' : '💸';
    const typeLabel = isIncome ? 'Pemasukan' : 'Pengeluaran';

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

    // Build category display with parent if available (without type prefix)
    let categoryDisplay = pending.category_name || 'Kategori';
    if (pending.category_parent) {
      categoryDisplay = `${pending.category_parent}, ${categoryDisplay}`;
    }

    return (
      `${emoji} <b>${typeLabel} Diperbarui</b>\n\n` +
      `📅 ${dateStr}\n` +
      `💳 ${pending.wallet_name || '-'}\n` +
      `💵 ${amount}\n` +
      `📁 ${categoryDisplay}\n` +
      `📝 ${pending.notes}\n\n` +
      `<b>Simpan transaksi ini?</b>`
    );
  }
}

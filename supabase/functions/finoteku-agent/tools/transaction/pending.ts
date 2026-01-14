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
import { PreferenceLearner } from '../../memory/learning.ts';

export class PendingHandlerTool extends BaseTool {
  name = 'pending_handler';
  description = 'Menangani konfirmasi, pembatalan, dan update transaksi pending';
  intents = ['confirm', 'cancel', 'update_pending'];

  private learner: PreferenceLearner;

  constructor(private supabase: SupabaseClient) {
    super();
    this.learner = new PreferenceLearner(supabase);
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
    _userContext: UserContext,
  ): Promise<ToolResult> {
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

    // Adaptive Learning
    if (pending.original_input) {
      await this.learner.learnFromTransaction(
        pending.user_id,
        pending.original_input,
        pending.category_id,
        pending.category_name || '',
        pending.wallet_id,
        pending.wallet_name || '',
      );
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
   * Smart Update - Deteksi entity dari text dan update field yang sesuai
   * Mendukung: kategori, wallet, nominal, notes
   *
   * Contoh:
   * - "BCA" → Deteksi sebagai wallet jika cocok dengan user's wallets
   * - "Makanan" → Deteksi sebagai kategori jika cocok
   * - "50k" → Deteksi sebagai nominal
   * - "Catatan Nasi Goreng" → Eksplisit update notes
   */
  private async updatePending(
    userContext: UserContext,
    platform: pendingData.Platform,
    params: ToolParams,
  ): Promise<ToolResult> {
    const text = params.text as string;
    const updates: Partial<pendingData.PendingTransactionInput> = {};
    const lowerText = text.toLowerCase();

    // 1. IMPLICIT ENTITY DETECTION - Scan for wallet/category names
    const { wallets, categories } = userContext;

    // Check if text matches a wallet name
    for (const wallet of wallets) {
      if (lowerText.includes(wallet.name.toLowerCase())) {
        updates.wallet_id = wallet.id;
        console.log(`[PendingHandler] Detected wallet: ${wallet.name}`);
        break;
      }
    }

    // Check if text matches a category name
    for (const category of categories) {
      if (lowerText.includes(category.name.toLowerCase())) {
        updates.category_id = category.id;
        console.log(`[PendingHandler] Detected category: ${category.name}`);
        break;
      }
    }

    // 2. EXPLICIT KEYWORD DETECTION

    // Explicit kategori update: "kategorinya Makanan"
    if (lowerText.includes('kategori')) {
      const match = text.match(/kategori(?:nya)?\s+(.+)/i);
      if (match) {
        const catName = match[1].trim().toLowerCase();
        const cat = categories.find((c: { name: string; id: string }) =>
          c.name.toLowerCase() === catName
        );
        if (cat) {
          updates.category_id = cat.id;
        }
      }
    }

    // Explicit wallet update: "walletnya BCA"
    if (lowerText.includes('wallet') || lowerText.includes('dompet')) {
      const match = text.match(/(?:wallet|dompet)(?:nya)?\s+(.+)/i);
      if (match) {
        const walletName = match[1].trim().toLowerCase();
        const wallet = wallets.find((w: { name: string; id: string }) =>
          w.name.toLowerCase() === walletName
        );
        if (wallet) {
          updates.wallet_id = wallet.id;
        }
      }
    }

    // 3. AMOUNT DETECTION
    const amountMatch = text.match(/(\d+)\s*(k|rb|ribu|jt|juta)?/i);
    if (amountMatch) {
      // Check if it's explicitly about amount OR if no other entity detected
      const isExplicitAmount = lowerText.includes('nominal') || lowerText.includes('harga') ||
        lowerText.includes('jumlah');
      const noOtherEntity = !updates.wallet_id && !updates.category_id;

      if (isExplicitAmount || noOtherEntity) {
        let amount = parseInt(amountMatch[1]);
        const suffix = amountMatch[2]?.toLowerCase();
        if (suffix === 'k' || suffix === 'rb' || suffix === 'ribu') amount *= 1000;
        if (suffix === 'jt' || suffix === 'juta') amount *= 1000000;

        // Only set if it's a reasonable transaction amount
        if (amount >= 100) {
          updates.amount = amount;
          console.log(`[PendingHandler] Detected amount: ${amount}`);
        }
      }
    }

    // 4. NOTES DETECTION - Explicit only
    if (
      lowerText.includes('catatan') || lowerText.includes('note') ||
      lowerText.includes('keterangan') || lowerText.includes('deskripsi')
    ) {
      const match = text.match(
        /(?:catatan|note|keterangan|deskripsi)(?:nya)?\s*(?:[:=]|jadi)?\s+(.+)/i,
      );
      if (match) {
        updates.notes = match[1].trim();
        console.log(`[PendingHandler] Detected notes: ${updates.notes}`);
      }
    }

    // No updates detected
    if (Object.keys(updates).length === 0) {
      return this.error(
        'Tidak dapat memahami perubahan. Coba: "kategorinya [nama]" atau "walletnya [nama]" atau ketik nama wallet/kategori langsung.',
      );
    }

    // Apply partial update
    const { success, error } = await pendingData.update(
      this.supabase,
      userContext.userId,
      platform,
      updates,
    );

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

/** * Pending Handler Tool
 * Menangani konfirmasi, pembatalan, dan update transaksi pending
 * Terintegrasi dengan PreferenceLearner untuk adaptive learning
 */
import type { SupabaseClient } from 'https://esm.sh/@supabase/supabase-js@2';
import { BaseTool, type ToolParams } from './base.ts';
import type { ToolResult } from '../types.ts';
import type { UserContext } from '../data/users.ts';
import * as pendingData from '../data/pending.ts';
import * as transactionData from '../data/transactions.ts';
import { PreferenceLearner } from '../memory/learning.ts';

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
    const conversationId = params.conversationId as string;

    if (!userContext || !conversationId) {
      return this.error('User context dan conversation ID diperlukan');
    }

    // Ambil transaksi pending
    const pending = await pendingData.get(this.supabase, conversationId);

    if (!pending) {
      return this.error('Tidak ada transaksi yang menunggu konfirmasi.');
    }

    switch (action) {
      case 'confirm':
        return await this.confirmTransaction(pending, userContext);

      case 'cancel':
        return await this.cancelTransaction(conversationId);

      case 'update_pending':
        return await this.updatePending(conversationId, params);

      default:
        return this.error('Action tidak dikenal');
    }
  }

  /**
   * Konfirmasi dan simpan transaksi
   * Sekaligus melakukan learning dari preferensi user
   */
  private async confirmTransaction(
    pending: pendingData.PendingTransaction,
    _userContext: UserContext,
  ): Promise<ToolResult> {
    // 1. Simpan transaksi ke database
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

    // 2. Adaptive Learning - belajar dari transaksi ini
    // Agent akan mengingat mapping keyword → category/wallet
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

    // 3. Hapus pending transaction
    await pendingData.remove(this.supabase, pending.conversation_id || pending.id);

    return this.success({ transactionId: pending.id }, `✅ <b>Transaksi berhasil disimpan.</b>`);
  }

  /**
   * Batalkan transaksi pending
   */
  private async cancelTransaction(conversationId: string): Promise<ToolResult> {
    await pendingData.remove(this.supabase, conversationId);
    return this.success({}, '❌ Transaksi dibatalkan.');
  }

  /**
   * Update field tertentu di transaksi pending
   * Mendukung: kategori, wallet, nominal
   *
   * Contoh input:
   * - "kategorinya makanan"
   * - "walletnya bca"
   * - "nominalnya 20k"
   */
  private async updatePending(conversationId: string, params: ToolParams): Promise<ToolResult> {
    const text = params.text as string;
    const updates: Partial<pendingData.PendingTransactionInput> = {};
    const lowerText = text.toLowerCase();

    // Deteksi update kategori
    if (lowerText.includes('kategori')) {
      const match = text.match(/kategori(?:nya)?\s+(.+)/i);
      if (match) {
        updates.category_name = match[1].trim();
        // TODO: Match ke category_id yang sebenarnya
      }
    }

    // Deteksi update wallet
    if (lowerText.includes('wallet') || lowerText.includes('dompet')) {
      const match = text.match(/(?:wallet|dompet)(?:nya)?\s+(.+)/i);
      if (match) {
        updates.wallet_name = match[1].trim();
      }
    }

    // Deteksi update nominal
    const amountMatch = text.match(/(\d+)\s*(k|rb|ribu|jt|juta)?/i);
    if (
      amountMatch &&
      (lowerText.includes('nominal') || lowerText.includes('harga') || lowerText.includes('jumlah'))
    ) {
      let amount = parseInt(amountMatch[1]);
      const suffix = amountMatch[2]?.toLowerCase();
      if (suffix === 'k' || suffix === 'rb' || suffix === 'ribu') amount *= 1000;
      if (suffix === 'jt' || suffix === 'juta') amount *= 1000000;
      updates.amount = amount;
    }

    // Deteksi update notes
    // Contoh: "Catatan Nasi Goreng", "Note beli minum", "Ubah catatan jadi..."
    if (
      lowerText.includes('catatan') || lowerText.includes('note') ||
      lowerText.includes('keterangan') || lowerText.includes('deskripsi')
    ) {
      // Match pattern: "catatan [isi catatan]" or "catatan: [isi catatan]"
      const match = text.match(
        /(?:catatan|note|keterangan|deskripsi)(?:nya)?\s*(?:[:=]|jadi)?\s+(.+)/i,
      );
      if (match) {
        updates.notes = match[1].trim();
      }
    }

    if (Object.keys(updates).length === 0) {
      return this.error(
        'Tidak dapat memahami perubahan. Coba: "kategorinya [nama]" atau "walletnya [nama]"',
      );
    }

    const { success, error } = await pendingData.update(this.supabase, conversationId, updates);

    if (!success) {
      return this.error('Gagal update: ' + (error?.message || 'Unknown error'));
    }

    // Ambil pending yang sudah diupdate untuk ditampilkan
    const updated = await pendingData.get(this.supabase, conversationId);
    if (!updated) {
      return this.error('Transaksi pending tidak ditemukan setelah update');
    }

    const emoji = updated.type === 'income' ? '💰' : '💸';
    const amount = new Intl.NumberFormat('id-ID', {
      style: 'currency',
      currency: 'IDR',
      minimumFractionDigits: 0,
    }).format(updated.amount);

    // Format tanggal
    const dateObj = new Date(updated.date);
    const dateStr = dateObj.toLocaleDateString('id-ID', {
      weekday: 'long',
      day: 'numeric',
      month: 'long',
      year: 'numeric',
    });

    return this.success(
      { ...updated, needsConfirmation: true },
      `${emoji} <b>Transaksi Diperbarui</b>\n\n` +
        `📅 ${dateStr}\n` +
        `💳 ${updated.wallet_name || '-'}\n` +
        `💵 ${amount}\n` +
        `📁 ${updated.category_name || 'Kategori'}\n` +
        `📝 ${updated.notes}\n\n` +
        `<b>Simpan transaksi ini?</b>`,
    );
  }
}

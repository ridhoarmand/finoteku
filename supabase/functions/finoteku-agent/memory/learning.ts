/**
 * Preference Learner
 * Sistem adaptive learning untuk mempelajari preferensi user
 * Menyimpan mapping: keyword → category/wallet
 *
 * Contoh:
 * - "kopi" → kategori "Minuman"
 * - "bensin" → kategori "Transport"
 */

import type { SupabaseClient } from 'https://esm.sh/@supabase/supabase-js@2';

export interface LearnedPreference {
  keyword: string;
  preferenceType: 'category' | 'wallet';
  valueId: string;
  valueName: string;
  confidence: number;
}

// Konstanta untuk confidence scoring
const MIN_CONFIDENCE = 0.6; // Minimal confidence untuk digunakan
const CONFIDENCE_INCREMENT = 0.15; // Kenaikan confidence per konfirmasi
const MAX_CONFIDENCE = 0.95; // Maksimal confidence

export class PreferenceLearner {
  constructor(private supabase: SupabaseClient) {}

  /**
   * Ambil preferensi yang sudah dipelajari berdasarkan input text
   * @param userId - ID user
   * @param text - Input text dari user
   * @returns Suggested category dan wallet berdasarkan learned preferences
   */
  async getPreferences(
    userId: string,
    text: string,
  ): Promise<{
    category?: { id: string; name: string; confidence: number };
    wallet?: { id: string; name: string; confidence: number };
  }> {
    const keywords = this.extractKeywords(text);
    if (keywords.length === 0) return {};

    // Query preferensi yang match dengan keywords
    const { data } = await this.supabase.from('user_preferences').select('*').eq('user_id', userId)
      .in('keyword', keywords).gte('confidence', MIN_CONFIDENCE).order('confidence', {
        ascending: false,
      });

    if (!data || data.length === 0) return {};

    const result: {
      category?: { id: string; name: string; confidence: number };
      wallet?: { id: string; name: string; confidence: number };
    } = {};

    // Ambil preference dengan confidence tertinggi untuk setiap type
    for (const pref of data) {
      if (pref.preference_type === 'category' && !result.category) {
        result.category = {
          id: pref.value_id,
          name: pref.value_name,
          confidence: pref.confidence,
        };
      }
      if (pref.preference_type === 'wallet' && !result.wallet) {
        result.wallet = {
          id: pref.value_id,
          name: pref.value_name,
          confidence: pref.confidence,
        };
      }
    }

    return result;
  }

  /**
   * Belajar dari transaksi yang dikonfirmasi user
   * Dipanggil saat user menekan "Ya, Simpan"
   *
   * @param userId - ID user
   * @param originalInput - Input asli dari user (misal: "beli kopi 15k")
   * @param categoryId - ID kategori yang dipilih
   * @param categoryName - Nama kategori
   * @param walletId - ID wallet (optional)
   * @param walletName - Nama wallet (optional)
   */
  async learnFromTransaction(
    userId: string,
    originalInput: string,
    categoryId: string,
    categoryName: string,
    walletId?: string,
    walletName?: string,
  ): Promise<void> {
    const keywords = this.extractKeywords(originalInput);

    for (const keyword of keywords) {
      // Belajar mapping keyword → category
      await this.updatePreference(userId, keyword, 'category', categoryId, categoryName);

      // Belajar mapping keyword → wallet (jika ada)
      if (walletId && walletName) {
        await this.updatePreference(userId, keyword, 'wallet', walletId, walletName);
      }
    }
  }

  /**
   * Update atau create preference dengan logika confidence
   * - Jika value sama: confidence naik
   * - Jika value beda dan confidence rendah: replace
   * - Jika value beda dan confidence tinggi: turunkan confidence
   */
  private async updatePreference(
    userId: string,
    keyword: string,
    preferenceType: 'category' | 'wallet',
    valueId: string,
    valueName: string,
  ): Promise<void> {
    // Cek apakah preference sudah ada
    const { data: existing } = await this.supabase
      .from('user_preferences')
      .select('id, confidence, usage_count, value_id')
      .eq('user_id', userId)
      .eq('keyword', keyword)
      .eq('preference_type', preferenceType)
      .single();

    if (existing) {
      if (existing.value_id === valueId) {
        // Value sama dengan sebelumnya → naikkan confidence
        const newConfidence = Math.min(existing.confidence + CONFIDENCE_INCREMENT, MAX_CONFIDENCE);
        await this.supabase
          .from('user_preferences')
          .update({
            confidence: newConfidence,
            usage_count: existing.usage_count + 1,
          })
          .eq('id', existing.id);
      } else {
        // Value berbeda (user koreksi)
        if (existing.confidence < 0.5) {
          // Confidence rendah → ganti dengan value baru
          await this.supabase
            .from('user_preferences')
            .update({
              value_id: valueId,
              value_name: valueName,
              confidence: 0.5,
              usage_count: 1,
            })
            .eq('id', existing.id);
        } else {
          // Confidence tinggi → turunkan saja
          await this.supabase
            .from('user_preferences')
            .update({ confidence: existing.confidence - CONFIDENCE_INCREMENT * 2 })
            .eq('id', existing.id);
        }
      }
    } else {
      // Preference baru
      await this.supabase.from('user_preferences').insert({
        user_id: userId,
        keyword,
        preference_type: preferenceType,
        value_id: valueId,
        value_name: valueName,
        confidence: 0.5,
      });
    }
  }

  /**
   * Ekstrak keyword bermakna dari text
   * Menghapus: nominal, kata hubung, kata kerja umum
   * @returns Array of keywords (max 3)
   */
  private extractKeywords(text: string): string[] {
    const cleanText = text
      .toLowerCase()
      // Hapus nominal (15k, 50rb, 1jt, dll)
      .replace(/\d+\s*(k|rb|ribu|jt|juta|m)?/gi, '')
      // Hapus kata-kata umum yang tidak bermakna
      .replace(
        /\b(beli|bayar|buat|untuk|di|ke|dari|yang|dan|atau|dengan|kemarin|besok|tadi|nanti)\b/gi,
        '',
      )
      .trim();

    return cleanText
      .split(/\s+/)
      .filter((word) => word.length >= 3) // Minimal 3 karakter
      .slice(0, 3); // Maksimal 3 keyword
  }
}

/** * Agent Executor * Menjalankan loop Plan → Execute → Evaluate
 * Mendukung tool chaining (contoh: STT → Parser)
 */

import { ReasoningEngine } from './reasoning.ts';
import { ToolRegistry } from './tools/core/index.ts';
import type { AgentInput, AgentResponse } from './types.ts';
import type { UserContext } from './data/users.ts';
import { resolveCashWallet, resolveWalletByHint } from './data/wallets.ts';
import * as pendingData from './data/pending.ts';
import type { SupabaseClient } from 'https://esm.sh/@supabase/supabase-js@2';

export class AgentExecutor {
  constructor(
    private reasoning: ReasoningEngine,
    private tools: ToolRegistry,
    private supabase: SupabaseClient,
  ) {}

  /**
   * Eksekusi utama agent
   * @param input - Input dari user
   * @param userContext - Context user (kategori, wallet, preferensi)
   * @param hasPending - Apakah ada transaksi pending
   */
  async execute(input: AgentInput, userContext: UserContext, hasPending?: boolean): Promise<AgentResponse> {
    try {
      // 1. PLAN - Tentukan intent dan tool yang digunakan
      console.log('[Executor] Planning:', input.type, input.content.substring(0, 50));
      const plan = this.reasoning.plan(input, hasPending);
      console.log('[Executor] Plan:', plan.intent, '->', plan.tool);

      // 2. Handle media input (memerlukan chaining)
      if (input.type === 'voice') {
        return await this.handleVoiceInput(input, userContext, hasPending);
      }

      if (input.type === 'image') {
        return await this.handleImageInput(input, userContext, hasPending);
      }

      // 3. EXECUTE - Jalankan tool yang sesuai
      const tool = this.tools.getForIntent(plan.intent) || this.tools.get(plan.tool);

      if (!tool) {
        console.log('[Executor] Tool tidak ditemukan:', plan.tool);
        return {
          type: 'error',
          content: '❌ Tidak dapat memproses perintah.',
        };
      }

      console.log('[Executor] Menjalankan tool:', tool.name);
      const result = await tool.execute({
        ...plan.params,
        userContext,
        platform: input.platform,
        conversationId: input.conversationId,
      });

      // 4. EVALUATE - Evaluasi hasil
      const evaluation = this.reasoning.evaluate(result);
      console.log('[Executor] Evaluasi:', evaluation.success);

      // Format response berdasarkan hasil
      if (result.success) {
        // deno-lint-ignore no-explicit-any
        const data = result.data as any;

        if (data && typeof data === 'object' && 'needsConfirmation' in data) {
          // Check if pending already exists (from previous update)
          const platform = (input.platform as pendingData.Platform) || 'telegram';
          const existingPending = await pendingData.get(this.supabase, userContext.userId, platform);

          if (existingPending) {
            // Pending updated - just show confirmation, don't re-parse
            console.log('[Executor] Pending already exists, skipping save');
            return {
              type: 'confirmation',
              content: result.message,
              data: result.data,
              actions: [
                { text: '✅ Ya, Simpan', action: 'confirm_yes' },
                { text: '❌ Tidak', action: 'confirm_no' },
              ],
            };
          }

          // CRITICAL FIX: Persist pending transaction to DB
          const pendingDataPayload = data;

          // Resolve IDs using UserContext - exact match only (parser already validated)
          const categoryHint = (pendingDataPayload.categoryHint || '').toLowerCase();
          const walletHint = (pendingDataPayload.walletHint || '').toLowerCase();
          const toWalletHint = (pendingDataPayload.toWalletHint || '').toLowerCase();

          // Exact match prioritizing type match
          let category = userContext.categories.find((c) => c.name.toLowerCase() === categoryHint && c.type === pendingDataPayload.type);
          if (!category) {
            category = userContext.categories.find((c) => c.name.toLowerCase() === categoryHint);
          }

          // Wallets
          let wallet = resolveWalletByHint(userContext.wallets, walletHint);
          let toWallet = toWalletHint ? resolveWalletByHint(userContext.wallets, toWalletHint) : null;

          // CRITICAL: Category MUST exist for non-transfers
          if (!category && pendingDataPayload.type !== 'transfer') {
            console.error(`[Executor] Category not found: "${categoryHint}"`);
            const categoryList = userContext.categories
              .filter((c) => c.type === pendingDataPayload.type)
              .map((c) => (c.parent_name ? `• ${c.parent_name} > ${c.name}` : `• ${c.name}`))
              .join('\n');

            return {
              type: 'error',
              content: `❌ <b>Kategori tidak ditemukan</b>\n\nKategori "${categoryHint}" tidak ada di akun Anda.\n\nGunakan salah satu kategori berikut:\n${categoryList}`,
            };
          }

          // Wallet fallback
          if (!wallet) {
            if (pendingDataPayload.type === 'transfer') {
              return {
                type: 'error',
                content: `❌ Dompet sumber "${pendingDataPayload.walletHint || '-'}" tidak ditemukan.\n\nDompet tersedia:\n${userContext.wallets.map((w) => `• ${w.name}`).join('\n')}`,
              };
            }
            wallet = userContext.wallets[0];
          }

          if (pendingDataPayload.type === 'transfer' && !toWallet) {
            toWallet = resolveCashWallet(userContext.wallets);
          }

          if (pendingDataPayload.type === 'transfer' && !toWallet) {
            return {
              type: 'error',
              content: '❌ Dompet tujuan transfer tidak ditemukan. Tambahkan wallet Cash/Tunai terlebih dahulu.',
            };
          }

          // Determine date
          const date = new Date();
          date.setDate(date.getDate() + (pendingDataPayload.dateOffset || 0));

          const saveResult = await pendingData.save(this.supabase, userContext.userId, platform, input.conversationId, {
            type: pendingDataPayload.type,
            amount: pendingDataPayload.amount,
            category_id: category?.id || '', // Transfers might not specify category initially
            wallet_id: wallet.id,
            to_wallet_id: toWallet?.id,
            notes: pendingDataPayload.notes,
            date: date.toISOString(),
            original_input: input.content,
          });

          if (saveResult.error) {
            console.error('[Executor] Failed to save pending transaction:', saveResult.error);
            return {
              type: 'error',
              content: `❌ Gagal menyimpan transaksi sementara.\nError: ${saveResult.error.message}`,
            };
          }

          return {
            type: 'confirmation',
            content: result.message,
            data: result.data,
            actions: [
              { text: '✅ Ya, Simpan', action: 'confirm_yes' },
              { text: '❌ Tidak', action: 'confirm_no' },
            ],
          };
        }

        return {
          type: 'message',
          content: result.message,
          data: result.data,
        };
      } else {
        return {
          type: 'error',
          content: result.message || '❌ Terjadi kesalahan.',
        };
      }
    } catch (error) {
      console.error('[Executor] Error:', error);
      return {
        type: 'error',
        content: `❌ Error: ${(error as Error).message}`,
      };
    }
  }

  /**
   * Handle voice input dengan chaining: STT → Text Parser
   */
  private async handleVoiceInput(input: AgentInput, userContext: UserContext, hasPending?: boolean): Promise<AgentResponse> {
    // Step 1: Konversi suara ke teks
    const sttTool = this.tools.get('speech_to_text');
    if (!sttTool) {
      return { type: 'error', content: '❌ Speech-to-text tidak tersedia.' };
    }

    const sttResult = await sttTool.execute({
      audio: input.content,
      mimeType: input.mimeType,
    });

    if (!sttResult.success) {
      return { type: 'error', content: sttResult.message };
    }

    // Step 2: Parse teks hasil transkripsi
    // deno-lint-ignore no-explicit-any
    const text = (sttResult.data as any).text;
    const textInput: AgentInput = {
      ...input,
      type: 'text',
      content: text,
    };

    return this.execute(textInput, userContext, hasPending);
  }

  /**
   * Handle image input dengan chaining: OCR → Text Parser
   */
  private async handleImageInput(input: AgentInput, userContext: UserContext, hasPending?: boolean): Promise<AgentResponse> {
    // Step 1: Extract text from image (OCR)
    const scannerTool = this.tools.get('image_scanner');
    if (!scannerTool) {
      return { type: 'error', content: '❌ OCR scanner tidak tersedia.' };
    }

    const scanResult = await scannerTool.execute({
      image: input.content,
      userContext,
    });

    if (!scanResult.success) {
      return { type: 'error', content: scanResult.message };
    }

    // Step 2: Parse extracted text (same as text/voice input)
    // deno-lint-ignore no-explicit-any
    const text = (scanResult.data as any).text;
    const finalContent = input.caption ? `${text}\n[Catatan Tambahan User: ${input.caption}]` : text;

    const textInput: AgentInput = {
      ...input,
      type: 'text',
      content: finalContent,
    };

    return this.execute(textInput, userContext, hasPending);
  }
}

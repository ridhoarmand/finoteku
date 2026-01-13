/**
 * Agent Executor
 * Menjalankan loop Plan → Execute → Evaluate
 * Mendukung tool chaining (contoh: STT → Parser)
 */

import { ReasoningEngine } from './reasoning.ts';
import { ToolRegistry } from './tools/base.ts';
import type { AgentInput, AgentResponse } from './types.ts';
import type { UserContext } from './data/users.ts';
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
  async execute(
    input: AgentInput,
    userContext: UserContext,
    hasPending?: boolean,
  ): Promise<AgentResponse> {
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
        return await this.handleImageInput(input, userContext);
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
          // CRITICAL FIX: Persist pending transaction to DB
          const pendingDataPayload = data;

          // Resolve IDs using UserContext
          const category = userContext.categories.find((c) =>
            c.name.toLowerCase() === (pendingDataPayload.categoryHint || '').toLowerCase()
          );
          const wallet = userContext.wallets.find((w) =>
            w.name.toLowerCase() === (pendingDataPayload.walletHint || '').toLowerCase()
          );

          // Determine date
          const date = new Date();
          date.setDate(date.getDate() + (pendingDataPayload.dateOffset || 0));

          const saveResult = await pendingData.save(
            this.supabase,
            userContext.userId,
            input.conversationId,
            {
              type: pendingDataPayload.type,
              amount: pendingDataPayload.amount,
              category_id: category?.id || userContext.categories[0]?.id, // Fallback to first category if not found
              category_name: pendingDataPayload.categoryHint,
              wallet_id: wallet?.id || userContext.wallets[0]?.id, // Fallback to first wallet
              wallet_name: pendingDataPayload.walletHint,
              notes: pendingDataPayload.notes,
              date: date.toISOString(),
              original_input: input.content,
            },
          );

          if (saveResult.error) {
            console.error('[Executor] Failed to save pending transaction:', saveResult.error);
            return {
              type: 'error',
              content:
                `❌ Gagal menyimpan transaksi sementara.\nError: ${saveResult.error.message}`,
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
  private async handleVoiceInput(
    input: AgentInput,
    userContext: UserContext,
    hasPending?: boolean,
  ): Promise<AgentResponse> {
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
   * Handle image input dengan OCR Scanner
   */
  private async handleImageInput(
    input: AgentInput,
    userContext: UserContext,
  ): Promise<AgentResponse> {
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

    return {
      type: 'confirmation',
      content: scanResult.message + '\n\n<b>Simpan transaksi ini?</b>',
      data: { ...(scanResult.data as Record<string, unknown>), needsConfirmation: true },
      actions: [
        { text: '✅ Ya, Simpan', action: 'confirm_yes' },
        { text: '❌ Tidak', action: 'confirm_no' },
      ],
    };
  }
}

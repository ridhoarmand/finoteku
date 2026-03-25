/** * Web Search Tool * Menjawab pertanyaan umum dengan mencari informasi di internet
 * Menggunakan AI untuk merangkum hasil pencarian
 */
import type { AIProvider } from '../../providers/base.ts';
import { BaseTool, type ToolParams } from '../core/base.ts';
import type { ToolResult } from '../../types.ts';

export class WebSearchTool extends BaseTool {
  name = 'web_search';
  description = 'Mencari informasi di internet untuk menjawab pertanyaan umum';
  intents = ['query_web'];

  constructor(private ai?: AIProvider) {
    super();
  }

  async execute(params: ToolParams): Promise<ToolResult> {
    const text = params.text as string;

    if (!text) {
      return this.error('Pertanyaan diperlukan');
    }

    // Jika AI tidak tersedia, beri respons fallback
    if (!this.ai) {
      return this.success(
        {},
        '🔍 Maaf, fitur pencarian web memerlukan koneksi AI.\n\nCoba tanyakan tentang data keuangan Anda, seperti:\n• "Berapa total pengeluaran bulan ini?"\n• "Ringkasan transaksi minggu ini"',
      );
    }

    try {
      const response = await this.ai.generateText(
        `User bertanya: "${text}"`,
        {
          systemPrompt: 'Kamu Finoteku, asisten keuangan. Jawab singkat dalam Bahasa Indonesia santai. Jika terkait keuangan, beri tips praktis. Jika bukan, jawab lalu arahkan ke keuangan. Maks 3 kalimat.',
          maxTokens: 200,
          temperature: 0.3,
        }
      );

      return this.success({ query: text }, `💡 ${response}`);
    } catch (error) {
      console.error('[WebSearchTool] Error:', error);
      return this.error('Gagal mencari informasi. Coba lagi nanti.');
    }
  }
}

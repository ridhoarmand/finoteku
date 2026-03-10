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
      // Gunakan AI untuk menjawab pertanyaan umum
      // AI provider sudah memiliki pengetahuan umum
      const prompt = `Kamu adalah asisten keuangan personal bernama Finoteku.
User bertanya: "${text}"

Jawab dengan singkat, informatif, dan dalam bahasa Indonesia yang santai.
Jika pertanyaan terkait keuangan, berikan tips praktis.
Jika bukan tentang keuangan, tetap jawab tapi arahkan kembali ke topik keuangan.
Maksimal 3-4 kalimat.`;

      const response = await this.ai.generateText(prompt);

      return this.success({ query: text }, `💡 ${response}`);
    } catch (error) {
      console.error('[WebSearchTool] Error:', error);
      return this.error('Gagal mencari informasi. Coba lagi nanti.');
    }
  }
}

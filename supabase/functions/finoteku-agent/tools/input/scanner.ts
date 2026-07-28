/**
 * Image Scanner Tool (OCR) - Text Extraction Only
 *
 * Architecture: Same as STT (Speech-to-Text)
 * - STT: Audio → Text
 * - OCR: Image → Text
 *
 * Parsing is done by Text Parser (tokenizer + classifier)
 *
 * Flow: Image → Extract text → Return text → Executor chains to Text Parser
 */
import type { AIProvider } from '../../providers/base.ts';
import { BaseTool, type ToolParams } from '../core/base.ts';
import type { ToolResult } from '../../types.ts';
import type { UserContext } from '../../data/users.ts';

export interface ScanResult {
  text: string;
  confidence: number;
}

export class ImageScannerTool extends BaseTool {
  name = 'image_scanner';
  description = 'Extract text from receipt image using OCR';
  intents = ['scan_receipt'];

  constructor(private ai: AIProvider) {
    super();
  }

  async execute(params: ToolParams): Promise<ToolResult> {
    const image = params.image as string;
    const userContext = params.userContext as UserContext;

    if (!image) {
      return this.error('Image data required');
    }

    try {
      console.log('[Scanner] Extracting text from image...');

      // Extract text from receipt using OCR
      const extractedText = await this.extractTextFromReceipt(image, userContext);

      if (
        !extractedText ||
        extractedText.trim().length === 0 ||
        extractedText.toLowerCase().includes('tanpa dukungan vision') ||
        extractedText.toLowerCase().includes('tidak bisa diproses')
      ) {
        return this.error(
          '📸 <b>Model AI Server saat ini belum mendukung analisis foto struk.</b>\n\n' +
            'Silakan catat transaksi menggunakan:\n' +
            '• 💬 Pesan teks (contoh: "makan sate 25k cash")\n' +
            '• 🎤 Voice note WhatsApp',
        );
      }

      console.log('[Scanner] Extracted text:', extractedText);

      // Return text - Executor will chain to Text Parser
      return this.success(
        {
          text: extractedText,
          confidence: 0.9,
        },
        `📸 <b>Teks berhasil di-scan:</b>\n"${extractedText}"\n\n🔄 <b>Memproses transaksi...</b>`,
      );
    } catch (error) {
      console.error('[Scanner] OCR failed:', error);
      return this.error(
        '📸 <b>Fitur analisis foto struk saat ini belum didukung oleh model AI server.</b>\n\n' +
          'Silakan gunakan input teks atau voice note.',
        (error as Error).message,
      );
    }
  }

  /**
   * Extract text from receipt image
   * Returns simple text summary for text parser
   */
  private async extractTextFromReceipt(image: string, userContext: UserContext): Promise<string> {
    const categories = userContext.categories
      .filter((c) => c.type === 'expense')
      .map((c) => c.name)
      .join(', ');

    const prompt = `OCR struk belanja: Ekstrak HANYA data transaksi inti dalam 1 baris ringkas:
Format: [Tanggal] [Perusahaan/Toko] Rp[Total Bayar] [Metode Pembayaran jika ada]

Contoh:
"25-07-2026 Amanda Brownies Rp109.000 BNI"
"Indomaret Rp25.000 Cash"

Aturan: Abaikan semua detail barang/pajak/kembalian/kasir. HANYA keluarkan 1 baris murni tanpa teks pembuka.`;

    const response = await this.ai.parseImage(image, prompt);

    // Handle JSON array response
    let text = response.trim();
    try {
      const parsed = JSON.parse(text);
      if (Array.isArray(parsed) && parsed.length > 0) {
        text = parsed[0];
      }
    } catch {
      // Not JSON, use as-is
    }

    return text.trim();
  }
}

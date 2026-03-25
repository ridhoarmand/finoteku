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

      if (!extractedText || extractedText.trim().length === 0) {
        return this.error('Tidak dapat membaca struk. Pastikan foto jelas dan teks terlihat.');
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
      return this.error('Gagal membaca struk. Pastikan foto jelas.', (error as Error).message);
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

    const prompt = `OCR struk belanja Indonesia. Baca dan ubah jadi SATU BARIS teks transaksi.

Format: [tanggal] [kategori] [nominal] [wallet jika ada], [merchant - item]
Contoh: "Jan 14 Jajan Beng-beng 10k" atau "260114 Makanan Nasi Ayam Rp10.000 BCA"

Kategori relevan: ${categories || 'Makanan, Belanja, Transportasi, Tagihan'}

Aturan: Cari TOTAL pembayaran. Tulis natural/casual. Notes Title Case. Output SATU BARIS saja.`;

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

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

    const prompt = `Kamu adalah OCR untuk struk belanja Indonesia.

TUGAS: Baca struk dan ubah menjadi TEXT sederhana seperti orang menulis transaksi.

FORMAT OUTPUT (satu baris):
[tanggal/waktu transaksi (pasti ada)] [kata kerja/kategori] [nominal] [wallet jika ada], [merchant - item, item...]

CONTOH OUTPUT:
Jan 14, 2026 Jajan Beng-beng di Indomaret 10k
260114 Makanan Nasi Ayam Rp. 10.000 BCA
09-12-2025 Belanja Pakaian Pribadi Rp.257.000 BCA, Toko Shinta - Celana Jeans

KATEGORI RELEVAN: ${categories || 'Makanan, Belanja, Transportasi, Tagihan'}

ATURAN:
1. Cari TOTAL PEMBAYARAN (bukan subtotal atau item individual)
2. Format seperti orang chatting, natural
3. Jika ada tanggal di struk, tulis relatif (kemarin, 4 hari lalu, dll) atau absolut (12 Jan)
4. Jika ada wallet/bank yang terdeteksi, sebutkan
5. Output SATU BARIS TEXT saja, tanpa penjelasan
6. Notes/Catatan dibuat Title Case
7. Gunakan bahasa Indonesia casual

OUTPUT:`;

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

/**
 * Image Scanner Tool (OCR)
 * Scan struk/nota dan ekstrak data transaksi
 */
import type { AIProvider } from '../providers/base.ts';
import { BaseTool, type ToolParams } from './base.ts';
import type { ToolResult } from '../types.ts';
import type { UserContext } from '../data/users.ts';

export interface ScanResult {
  type: 'expense';
  amount: number;
  categoryHint: string;
  notes: string;
  date: string | null;
  dateOffset: number;
  merchant: string | null;
}

export class ImageScannerTool extends BaseTool {
  name = 'image_scanner';
  description = 'Scan receipt image and extract transaction data';
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

    const prompt = this.buildPrompt(userContext);

    try {
      const rawResult = await this.ai.parseImage(image, prompt);
      const jsonStr = rawResult.replace(/```json\n?|\n?```/g, '').trim();
      let parsed = JSON.parse(jsonStr);
      if (Array.isArray(parsed)) parsed = parsed[0];

      // Calculate dateOffset from date if available
      let dateOffset = 0;
      if (parsed.date) {
        const today = new Date();
        const transDate = new Date(parsed.date);
        today.setHours(0, 0, 0, 0);
        transDate.setHours(0, 0, 0, 0);
        dateOffset = Math.round((transDate.getTime() - today.getTime()) / (1000 * 60 * 60 * 24));
      }

      const result: ScanResult = {
        type: 'expense',
        amount: Number(parsed.amount) || 0,
        categoryHint: parsed.categoryHint || parsed.category || 'Pengeluaran',
        notes: parsed.notes || parsed.merchant || 'Scan Struk',
        date: parsed.date || null,
        dateOffset,
        merchant: parsed.merchant || null,
      };

      return this.success(result, `📸 Struk berhasil di-scan: ${result.notes}`);
    } catch (error) {
      console.error('OCR failed:', error);
      return this.error('Gagal membaca struk. Pastikan foto jelas.', (error as Error).message);
    }
  }

  private buildPrompt(userContext: UserContext): string {
    const categories = userContext.categories
      .filter((c) => c.type === 'expense')
      .map((c) => c.name)
      .join(', ');

    return `Kamu adalah parser struk belanja (receipt scanner).
Analisis gambar struk dan ekstrak dalam format JSON:
{
  "amount": number (total belanjaan),
  "categoryHint": "kategori yang paling cocok",
  "notes": "Nama Merchant - item utama",
  "date": "YYYY-MM-DD" atau null,
  "merchant": "nama toko/merchant"
}

KATEGORI TERSEDIA: ${categories || 'Makanan, Belanja, Transportasi, Tagihan'}
HANYA RETURN JSON VALID, tanpa penjelasan.`;
  }
}

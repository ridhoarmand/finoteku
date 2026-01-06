// Gemini AI-powered transaction parser with few-shot learning
export interface ParsedTransaction {
  type: 'income' | 'expense';
  amount: number;
  categoryHint: string;
  walletHint: string | null;
  notes: string;
  confidence: number;
  dateOffset: number;
}

const GEMINI_API_URL = 'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent';

export interface GeminiUserContext {
  incomeCategories: string[];
  expenseCategories: string[];
  walletNames: string[];
}

interface TransactionExample {
  notes: string;
  category: string;
  wallet: string;
  amount: number;
  type: 'income' | 'expense';
}

interface NoteStyle {
  capitalization: 'lowercase' | 'uppercase' | 'titlecase' | 'mixed';
  avgLength: number;
  isDetailed: boolean;
}

function buildSystemPrompt(context: GeminiUserContext, examples: TransactionExample[] = [], noteStyle?: NoteStyle): string {
  let prompt = `Kamu adalah parser transaksi keuangan PERSONAL untuk user ini.

TUGAS: Parse pesan user menjadi format JSON:
{
  "type": "income" atau "expense",
  "amount": number (tanpa format, contoh: 50000),
  "categoryHint": "nama kategori yang cocok",
  "walletHint": "nama wallet/bank jika disebutkan, null jika tidak",
  "notes": "catatan/deskripsi transaksi",
  "dateOffset": number (0=hari ini, -1=kemarin, 1=besok, 2=lusa)
}`;

  // Add user's transaction examples for few-shot learning
  if (examples.length > 0) {
    prompt += `

PELAJARI PATTERN USER INI dari transaksi sebelumnya:
${examples
  .filter((e) => e.notes && e.notes.trim().length > 0)
  .slice(0, 12)
  .map((e) => `• "${e.notes}" → ${e.category}, ${e.wallet}, Rp${e.amount.toLocaleString('id-ID')}`)
  .join('\n')}

PENTING: Ikuti pattern user ini! Jika user sering pakai kata tertentu untuk kategori/wallet tertentu, gunakan pattern yang sama.`;
  }

  // Add note style guidance
  if (noteStyle) {
    let styleGuide = '';
    if (noteStyle.capitalization === 'uppercase') {
      styleGuide = 'User suka notes HURUF KAPITAL SEMUA.';
    } else if (noteStyle.capitalization === 'titlecase') {
      styleGuide = 'User suka notes Huruf Kapital Di Setiap Kata.';
    } else if (noteStyle.capitalization === 'lowercase') {
      styleGuide = 'User suka notes huruf kecil semua.';
    }
    if (noteStyle.isDetailed) {
      styleGuide += ' User suka notes detail dan lengkap.';
    }
    if (styleGuide) {
      prompt += `\n\nSTYLE NOTES: ${styleGuide}`;
    }
  }

  prompt += `

ATURAN PARSING:
1. Deteksi: kategori, nominal (50k/1jt), wallet, tanggal relatif
2. Jika ada koma (,), text setelah koma adalah notes
3. Gunakan pattern dari contoh transaksi di atas jika cocok

TANGGAL RELATIF:
- "kemarin/kemaren" = dateOffset: -1
- "besok/besuk" = dateOffset: 1
- "lusa/besok lusa" = dateOffset: 2
- Tidak disebutkan = dateOffset: 0

TYPE:
- INCOME: gaji, bonus, dapat, terima, cashback, refund
- EXPENSE: beli, bayar, jajan, makan, bensin, parkir, tagihan

NOMINAL: k/rb = ribuan, jt/m = jutaan

KATEGORI USER:
- Pemasukan: ${context.incomeCategories.join(', ') || 'Tidak ada'}
- Pengeluaran: ${context.expenseCategories.join(', ') || 'Tidak ada'}
- Wallet: ${context.walletNames.join(', ') || 'Tidak ada'}

HANYA RETURN JSON VALID TANPA MARKDOWN.`;

  return prompt;
}

/**
 * Build prompt for Vision AI receipt parsing
 */
function buildVisionPrompt(context: GeminiUserContext): string {
  return `Kamu adalah parser struk belanja (receipt scanner).

TUGAS: Analisis gambar struk ini dan ekstrak informasi berikut dalam format JSON:
{
  "type": "expense" (selalu expense untuk struk belanja),
  "amount": number (total belanjaan),
  "categoryHint": "tebak kategori berdasarkan merchant/item (contoh: Makanan, Belanja Bulanan)",
  "walletHint": null,
  "notes": "Nama Merchant - ringkasan item (maksimal 5 kata)",
  "dateOffset": number (hitung selisih hari dari tanggal di struk ke HARI INI. Jika sama = 0, kemarin = -1. Jika tidak ada tanggal = 0),
  "confidence": 0.9
}

KATEGORI YANG TERSEDIA:
${context.expenseCategories.join(', ') || 'Umum'}

PENTING:
1. Cari TOTAL AMOUNT yang harus dibayar.
2. Notes harus singkat: "NamaToko - Item1, Item2".
3. DateOffset sangat penting. Coba cari tanggal di struk. Asumsikan hari ini adalah saat ini.
4. HANYA RETURN JSON VALID.`;
}

export async function parseWithGemini(text: string, apiKey: string, context: GeminiUserContext, examples: TransactionExample[] = [], noteStyle?: NoteStyle): Promise<ParsedTransaction | null> {
  const systemPrompt = buildSystemPrompt(context, examples, noteStyle);

  try {
    const response = await fetch(`${GEMINI_API_URL}?key=${apiKey}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        contents: [
          {
            parts: [{ text: systemPrompt }, { text: `INPUT TEXT: "${text}"` }],
          },
        ],
        generationConfig: {
          temperature: 0.1,
          responseMimeType: 'application/json',
        },
      }),
    });

    const data = await response.json();
    if (!data.candidates || data.candidates.length === 0) return null;

    const rawText = data.candidates[0].content.parts[0].text;
    const jsonStr = rawText.replace(/```json\n?|\n?```/g, '').trim();
    const result = JSON.parse(jsonStr);

    return {
      type: result.type || 'expense',
      amount: Number(result.amount) || 0,
      categoryHint: result.categoryHint || '',
      walletHint: result.walletHint || null,
      notes: result.notes || text,
      confidence: 1.0, // High confidence for custom API
      dateOffset: Number(result.dateOffset) || 0,
    };
  } catch (error) {
    console.error('Gemini API error:', error);
    return null;
  }
}

/**
 * Parse image (receipt) with Gemini Vision
 */
export async function parseImageWithGemini(base64Image: string, apiKey: string, context: GeminiUserContext): Promise<ParsedTransaction | null> {
  const prompt = buildVisionPrompt(context);

  try {
    const response = await fetch(`${GEMINI_API_URL}?key=${apiKey}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        contents: [
          {
            parts: [
              { text: prompt },
              {
                inline_data: {
                  mime_type: 'image/jpeg', // Assume converted to jpeg or generic handling
                  data: base64Image,
                },
              },
            ],
          },
        ],
        generationConfig: {
          temperature: 0.1,
          responseMimeType: 'application/json',
        },
      }),
    });

    const data = await response.json();
    if (!data.candidates || data.candidates.length === 0) {
      console.error('No candidates from Gemini Vision', data);
      return null;
    }

    const rawText = data.candidates[0].content.parts[0].text;
    const jsonStr = rawText.replace(/```json\n?|\n?```/g, '').trim();
    const result = JSON.parse(jsonStr);

    return {
      type: 'expense',
      amount: Number(result.amount) || 0,
      categoryHint: result.categoryHint || 'Pengeluaran',
      walletHint: null,
      notes: result.notes || 'Scan Struk',
      confidence: 0.9,
      dateOffset: Number(result.dateOffset) || 0,
    };
  } catch (error) {
    console.error('Gemini Vision API error:', error);
    return null;
  }
}

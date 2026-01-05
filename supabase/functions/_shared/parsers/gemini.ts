// Gemini AI-powered transaction parser
// Type definition (shared with regex.ts)
export interface ParsedTransaction {
  type: 'income' | 'expense';
  amount: number;
  categoryHint: string;
  walletHint: string | null;
  notes: string;
  confidence: number;
}

const GEMINI_API_URL = 'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent';

interface UserContext {
  incomeCategories: string[];
  expenseCategories: string[];
  walletNames: string[];
}

function buildSystemPrompt(context: UserContext): string {
  return `Kamu adalah parser transaksi keuangan. Ekstrak informasi dari pesan user dalam format JSON:
{
  "type": "income" atau "expense",
  "amount": number (tanpa format, contoh: 50000),
  "categoryHint": "nama kategori yang cocok",
  "walletHint": "nama wallet/bank jika disebutkan, null jika tidak",
  "notes": "catatan/deskripsi transaksi"
}

ATURAN PARSING:
1. Deteksi: kategori, nominal (50k/1jt), dan wallet (BCA/Mandiri/dll)
2. Jika ada tanda koma (,), semua text setelah koma adalah notes
3. Jika tidak ada koma, text sisa setelah kategori+nominal+wallet adalah notes
4. Notes adalah deskripsi detail, contoh: "beli nasi padang", "transfer ke teman"

CONTOH:
- "makan 50k bca, beli nasi padang" → category=makan, amount=50000, wallet=bca, notes="beli nasi padang"
- "jajan 25rb alfamart beli snack" → category=jajan, amount=25000, wallet=null, notes="alfamart beli snack"
- "gaji 5jt mandiri" → category=gaji, amount=5000000, wallet=mandiri, notes=""

TYPE:
- INCOME: gaji, bonus, dapat, terima, cashback, refund
- EXPENSE: beli, bayar, jajan, makan, bensin, parkir, tagihan

NOMINAL INDONESIA:
- "k/rb" = ribuan (50k = 50000)
- "jt/m" = jutaan (1jt = 1000000)

KATEGORI USER:
- Pemasukan: ${context.incomeCategories.join(', ') || 'Tidak ada'}
- Pengeluaran: ${context.expenseCategories.join(', ') || 'Tidak ada'}
- Wallet: ${context.walletNames.join(', ') || 'Tidak ada'}

Untuk categoryHint HARUS pilih dari kategori user di atas.
Jawab dengan JSON saja, tanpa markdown.`;
}

export async function parseWithGemini(text: string, apiKey: string, context: UserContext = { incomeCategories: [], expenseCategories: [], walletNames: [] }): Promise<ParsedTransaction | null> {
  try {
    const systemPrompt = buildSystemPrompt(context);

    const response = await fetch(`${GEMINI_API_URL}?key=${apiKey}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        contents: [
          { role: 'user', parts: [{ text: systemPrompt }] },
          { role: 'model', parts: [{ text: 'Siap parsing transaksi.' }] },
          { role: 'user', parts: [{ text }] },
        ],
        generationConfig: { temperature: 0.1, maxOutputTokens: 256 },
      }),
    });

    if (!response.ok) {
      console.error('Gemini API error:', response.status);
      return null;
    }

    const data = await response.json();
    const textResponse = data.candidates?.[0]?.content?.parts?.[0]?.text;

    if (!textResponse) return null;

    let jsonStr = textResponse.trim();
    if (jsonStr.startsWith('```')) {
      jsonStr = jsonStr
        .replace(/```json?\n?/g, '')
        .replace(/```/g, '')
        .trim();
    }

    const parsed = JSON.parse(jsonStr);

    return {
      type: parsed.type === 'income' ? 'income' : 'expense',
      amount: Number(parsed.amount),
      categoryHint: parsed.categoryHint || 'Lainnya',
      walletHint: parsed.walletHint || null,
      notes: parsed.notes || '',
      confidence: 0.95,
    };
  } catch (error) {
    console.error('Error parsing with Gemini:', error);
    return null;
  }
}

// OpenAI-powered transaction parser
// Type definition (shared with regex.ts)
export interface ParsedTransaction {
  type: 'income' | 'expense';
  amount: number;
  categoryHint: string;
  walletHint: string | null;
  notes: string;
  confidence: number;
}

interface UserContext {
  incomeCategories: string[];
  expenseCategories: string[];
  walletNames: string[];
}

function buildSystemPrompt(context: UserContext): string {
  return `Kamu adalah parser transaksi keuangan. Ekstrak informasi dalam format JSON:
{
  "type": "income" atau "expense",
  "amount": number (tanpa format),
  "categoryHint": "nama kategori",
  "walletHint": "nama wallet atau null",
  "notes": "catatan transaksi"
}

ATURAN:
1. Deteksi: kategori, nominal, wallet
2. Jika ada koma (,), text setelah koma adalah notes
3. Jika tidak ada koma, text sisa setelah elemen utama adalah notes

CONTOH:
- "makan 50k bca, beli nasi" → notes="beli nasi"
- "jajan 25rb alfamart snack" → notes="alfamart snack"

TYPE: INCOME (gaji,bonus,dapat) atau EXPENSE (beli,bayar,jajan)
NOMINAL: k/rb=ribuan, jt/m=jutaan

KATEGORI USER:
- Pemasukan: ${context.incomeCategories.join(', ') || '-'}
- Pengeluaran: ${context.expenseCategories.join(', ') || '-'}
- Wallet: ${context.walletNames.join(', ') || '-'}

Jawab JSON saja.`;
}

export async function parseWithOpenAI(text: string, apiKey: string, context: UserContext = { incomeCategories: [], expenseCategories: [], walletNames: [] }): Promise<ParsedTransaction | null> {
  try {
    const response = await fetch('https://api.openai.com/v1/chat/completions', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${apiKey}`,
      },
      body: JSON.stringify({
        model: 'gpt-4o-mini',
        messages: [
          { role: 'system', content: buildSystemPrompt(context) },
          { role: 'user', content: text },
        ],
        temperature: 0.1,
        max_tokens: 256,
      }),
    });

    if (!response.ok) {
      console.error('OpenAI API error:', response.status);
      return null;
    }

    const data = await response.json();
    const textResponse = data.choices?.[0]?.message?.content;

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
    console.error('Error parsing with OpenAI:', error);
    return null;
  }
}

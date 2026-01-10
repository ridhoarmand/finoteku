// OpenAI-powered transaction parser with few-shot learning// Type definition (shared with regex.ts)
export interface ParsedTransaction {
  type: 'income' | 'expense';
  amount: number;
  categoryHint: string;
  walletHint: string | null;
  notes: string;
  confidence: number;
  dateOffset: number; // 0 = today, -1 = yesterday, +1 = tomorrow, +2 = lusa
}

interface UserContext {
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

function buildSystemPrompt(
  context: UserContext,
  examples: TransactionExample[] = [],
  noteStyle?: NoteStyle,
): string {
  let prompt = `Kamu adalah parser transaksi keuangan PERSONAL untuk user ini.

TUGAS: Parse pesan user menjadi format JSON:
{
  "type": "income" atau "expense",
  "amount": number (tanpa format),
  "categoryHint": "nama kategori",
  "walletHint": "nama wallet atau null",
  "notes": "catatan transaksi",
  "dateOffset": number (0=hari ini, -1=kemarin, 1=besok, 2=lusa)
}`;

  // Add user's transaction examples for few-shot learning
  if (examples.length > 0) {
    prompt += `

PATTERN USER dari transaksi sebelumnya:
${
      examples
        .filter((e) => e.notes && e.notes.trim().length > 0)
        .slice(0, 12)
        .map((e) =>
          `• "${e.notes}" → ${e.category}, ${e.wallet}, Rp${e.amount.toLocaleString('id-ID')}`
        )
        .join('\n')
    }

PENTING: Ikuti pattern user ini!`;
  }

  // Add note style guidance
  if (noteStyle) {
    let styleGuide = '';
    if (noteStyle.capitalization === 'uppercase') {
      styleGuide = 'User suka notes HURUF KAPITAL.';
    } else if (noteStyle.capitalization === 'titlecase') {
      styleGuide = 'User suka notes Title Case.';
    } else if (noteStyle.capitalization === 'lowercase') {
      styleGuide = 'User suka notes huruf kecil.';
    }
    if (styleGuide) {
      prompt += `\n\nSTYLE: ${styleGuide}`;
    }
  }

  prompt += `

ATURAN:
1. Deteksi: kategori, nominal, wallet, tanggal relatif
2. Jika ada koma (,), text setelah koma adalah notes
3. Gunakan pattern dari contoh jika cocok

TANGGAL: kemarin=-1, besok=1, lusa=2, default=0
TYPE: INCOME (gaji,bonus,dapat) | EXPENSE (beli,bayar,jajan)
NOMINAL: k/rb=ribuan, jt/m=jutaan

KATEGORI USER:
- Pemasukan: ${context.incomeCategories.join(', ') || '-'}
- Pengeluaran: ${context.expenseCategories.join(', ') || '-'}
- Wallet: ${context.walletNames.join(', ') || '-'}

Jawab JSON saja.`;

  return prompt;
}

/**
 * Parse with OpenAI - supports few-shot learning from user's history
 */
export async function parseWithOpenAI(
  text: string,
  apiKey: string,
  context: UserContext = { incomeCategories: [], expenseCategories: [], walletNames: [] },
  examples: TransactionExample[] = [],
  noteStyle?: NoteStyle,
): Promise<ParsedTransaction | null> {
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
          { role: 'system', content: buildSystemPrompt(context, examples, noteStyle) },
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
      dateOffset: Number(parsed.dateOffset) || 0,
    };
  } catch (error) {
    console.error('Error parsing with OpenAI:', error);
    return null;
  }
}

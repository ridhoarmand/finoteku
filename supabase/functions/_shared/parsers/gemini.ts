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

const GEMINI_API_URL =
  'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent';

/**
 * Log token usage from Gemini API response
 */
// deno-lint-ignore no-explicit-any
function logTokenUsage(data: any, caller: string): void {
  if (data?.usageMetadata) {
    const { promptTokenCount, candidatesTokenCount, totalTokenCount } = data.usageMetadata;
    console.log(
      `[Gemini ${caller}] Tokens - Prompt: ${promptTokenCount}, Response: ${candidatesTokenCount}, Total: ${totalTokenCount}`,
    );
  }
}

export interface GeminiUserContext {
  incomeCategories: string[];
  expenseCategories: string[];
  walletNames: string[];
  // Categories with parent info for better matching
  incomeCategoriesWithParent?: Array<{ name: string; parent: string | null }>;
  expenseCategoriesWithParent?: Array<{ name: string; parent: string | null }>;
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
  context: GeminiUserContext,
  examples: TransactionExample[] = [],
  noteStyle?: NoteStyle,
): string {
  let prompt = `Kamu adalah parser transaksi keuangan PERSONAL untuk user Indonesia.

TUGAS: Parse pesan user menjadi format JSON:
{
  "type": "income" atau "expense",
  "amount": number (tanpa format, contoh: 50000),
  "categoryHint": "nama kategori yang paling cocok",
  "walletHint": "nama wallet/bank jika disebutkan, null jika tidak",
  "notes": "catatan/deskripsi transaksi (bersih, tanpa nominal/wallet)",
  "dateOffset": number (0=hari ini, -1=kemarin, 1=besok, 2=lusa)
}`;

  // Add user's transaction examples for few-shot learning (increased to 25)
  if (examples.length > 0) {
    // Deduplicate notes to get diverse patterns
    const seenNotes = new Set<string>();
    const uniqueExamples = examples
      .filter((e) => {
        if (!e.notes || e.notes.trim().length === 0) return false;
        const key = e.notes.toLowerCase().trim();
        if (seenNotes.has(key)) return false;
        seenNotes.add(key);
        return true;
      })
      .slice(0, 25);

    if (uniqueExamples.length > 0) {
      prompt += `

PELAJARI PATTERN USER INI dari ${uniqueExamples.length} transaksi sebelumnya:
${
        uniqueExamples.map((e) =>
          `• "${e.notes}" → ${e.type === 'income' ? '📈' : '📉'} ${e.category}, ${e.wallet}, Rp${
            e.amount.toLocaleString('id-ID')
          }`
        ).join('\n')
      }

PENTING: Ikuti pattern user ini! Jika user sering pakai kata tertentu untuk kategori/wallet tertentu, gunakan pattern yang sama.`;
    }
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

  // Format categories with parent info if available
  let incomeCatDisplay = context.incomeCategories.join(', ') || 'Gaji, Bonus, Lainnya';
  let expenseCatDisplay = context.expenseCategories.join(', ') || 'Makanan, Transport, Belanja';

  if (context.incomeCategoriesWithParent && context.incomeCategoriesWithParent.length > 0) {
    incomeCatDisplay = context.incomeCategoriesWithParent.map((
      c,
    ) => (c.parent ? `${c.parent} › ${c.name}` : c.name)).join(', ');
  }
  if (context.expenseCategoriesWithParent && context.expenseCategoriesWithParent.length > 0) {
    expenseCatDisplay = context.expenseCategoriesWithParent.map((
      c,
    ) => (c.parent ? `${c.parent} › ${c.name}` : c.name)).join(', ');
  }

  prompt += `

ATURAN PARSING KETAT:
1. NOMINAL WAJIB: k/K/rb = ×1000, jt/JT/juta/m = ×1000000
   Contoh: 50k = 50000, 1.5jt = 1500000, 25rb = 25000
2. NOTES: Ambil deskripsi transaksi, hapus nominal dan wallet dari notes
   Contoh: "makan siang 50k bca" → notes: "makan siang"
3. KOMA: Text setelah koma (,) adalah notes tambahan
   Contoh: "transport 10k, naik gojek" → notes: "transport, naik gojek"
4. MATCHING: Cocokkan dengan kategori & wallet user yang tersedia
5. KATEGORI PARENT: Jika kategori punya parent (format: Parent › Child), return nama CHILD saja di categoryHint

TANGGAL RELATIF:
- kemarin/kemaren/yesterday = -1
- besok/besuk/tomorrow = +1
- lusa = +2
- Default (tidak disebutkan) = 0

TYPE DETECTION:
📈 INCOME: gaji, gajian, bonus, thr, dapat, terima, transfer masuk, cashback, refund
📉 EXPENSE: beli, bayar, jajan, makan, minum, bensin, parkir, tagihan, langganan

KATEGORI USER (COCOKKAN PALING TEPAT):
- Pemasukan: ${incomeCatDisplay}
- Pengeluaran: ${expenseCatDisplay}

WALLET USER: ${context.walletNames.join(', ') || 'Cash, BCA, Mandiri'}

HANYA RETURN JSON VALID. TANPA MARKDOWN, TANPA PENJELASAN.`;

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
  "notes": "Nama Merchant - ringkasan item (tulis item yang relevan)",
  "date": "YYYY-MM-DD" (tanggal transaksi di struk),
  "dateOffset": number (fallback, hitung selisih hari jika tanggal sulit dibaca)
}

KATEGORI YANG TERSEDIA:
${context.expenseCategories.join(', ') || 'Umum'}

PENTING:
1. Cari TOTAL AMOUNT.
2. Notes: "NamaToko - Item1, Item2...".
3. Cari TANGGAL di struk. Format YYYY-MM-DD.
4. HANYA RETURN JSON VALID.`;
}

/**
 * Interface for transaction update parsed by AI
 */
export interface ParsedTransactionUpdate {
  amount?: number;
  notes?: string;
  categoryHint?: string;
  walletHint?: string;
  dateOffset?: number;
}

/**
 * Build prompt for parsing transaction update requests
 */
function buildUpdatePrompt(
  currentTransaction: {
    amount: number;
    notes: string;
    category: string;
    wallet: string;
    date: string;
  },
  context: GeminiUserContext,
): string {
  return `Kamu adalah parser untuk UPDATE transaksi keuangan.

TRANSAKSI SAAT INI:
- Nominal: Rp${currentTransaction.amount.toLocaleString('id-ID')}
- Catatan: "${currentTransaction.notes}"
- Kategori: ${currentTransaction.category}
- Wallet: ${currentTransaction.wallet}
- Tanggal: ${currentTransaction.date}

TUGAS: Parse permintaan user untuk mengubah transaksi ini.
Return JSON dengan field yang ingin diubah saja:
{
  "amount": number atau null (jika tidak berubah),
  "notes": string atau null (jika tidak berubah),
  "categoryHint": string atau null (jika tidak berubah),
  "walletHint": string atau null (jika tidak berubah),
  "dateOffset": number atau null (0=hari ini, -1=kemarin, 1=besok)
}

CONTOH INPUT & OUTPUT:
- "nominal jadi 50k" → {"amount": 50000}
- "ganti jadi 100rb" → {"amount": 100000}
- "catatan ganti Makan Siang" → {"notes": "Makan Siang"}
- "WLS ganti Es Krim Walls" → {"notes": "${
    currentTransaction.notes.replace(/WLS/gi, 'Es Krim Walls')
  }"}
- "pengeluaran jadi 41k dan WLS ganti Es Krim Walls" → {"amount": 41000, "notes": "${
    currentTransaction.notes.replace(/WLS/gi, 'Es Krim Walls')
  }"}
- "pakai BCA" → {"walletHint": "BCA"}
- "kategori Makanan" → {"categoryHint": "Makanan"}
- "kemarin" → {"dateOffset": -1}

ATURAN:
1. NOMINAL: k/rb = ribuan, jt/m = jutaan
2. NOTES: Jika user minta ganti sebagian text, modifikasi notes yang ada
3. Hanya return field yang berubah, sisanya null atau tidak disertakan

KATEGORI TERSEDIA: ${
    [...context.incomeCategories, ...context.expenseCategories].join(', ') || 'Umum'
  }
WALLET TERSEDIA: ${context.walletNames.join(', ') || 'Cash'}

HANYA RETURN JSON VALID.`;
}

/**
 * Parse transaction update request using Gemini AI
 */
export async function parseTransactionUpdate(
  text: string,
  apiKey: string,
  currentTransaction: {
    amount: number;
    notes: string;
    category: string;
    wallet: string;
    date: string;
  },
  context: GeminiUserContext,
): Promise<ParsedTransactionUpdate | null> {
  const prompt = buildUpdatePrompt(currentTransaction, context);

  try {
    const response = await fetch(`${GEMINI_API_URL}?key=${apiKey}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        contents: [
          {
            parts: [{ text: prompt }, { text: `PERMINTAAN UPDATE: "${text}"` }],
          },
        ],
        generationConfig: {
          temperature: 0.1,
          response_mime_type: 'application/json',
        },
      }),
    });

    const data = await response.json();
    logTokenUsage(data, 'Update');
    if (!data.candidates || data.candidates.length === 0) {
      console.error('No candidates from Gemini for update parsing');
      return null;
    }

    const rawText = data.candidates[0].content.parts[0].text;
    const jsonStr = rawText.replace(/```json\n?|\n?```/g, '').trim();
    const result = JSON.parse(jsonStr);

    console.log('Parsed update result:', result);

    return {
      amount: result.amount ? Number(result.amount) : undefined,
      notes: result.notes || undefined,
      categoryHint: result.categoryHint || undefined,
      walletHint: result.walletHint || undefined,
      dateOffset: result.dateOffset !== null && result.dateOffset !== undefined
        ? Number(result.dateOffset)
        : undefined,
    };
  } catch (error) {
    console.error('Gemini update parse error:', error);
    return null;
  }
}

export async function parseWithGemini(
  text: string,
  apiKey: string,
  context: GeminiUserContext,
  examples: TransactionExample[] = [],
  noteStyle?: NoteStyle,
): Promise<ParsedTransaction | null> {
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
          response_mime_type: 'application/json',
        },
      }),
    });

    const data = await response.json();
    logTokenUsage(data, 'Parse');
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
      confidence: 1.0,
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
export async function parseImageWithGemini(
  base64Image: string,
  apiKey: string,
  context: GeminiUserContext,
): Promise<ParsedTransaction | null> {
  const prompt = buildVisionPrompt(context);
  console.log('parseImageWithGemini start, img length:', base64Image.length);

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
                  mime_type: 'image/jpeg',
                  data: base64Image,
                },
              },
            ],
          },
        ],
        generationConfig: {
          temperature: 0.1,
          response_mime_type: 'application/json',
        },
      }),
    });

    console.log('Gemini Vision status:', response.status);
    const rawBody = await response.text();
    if (!response.ok) {
      console.error('Gemini Vision error body:', rawBody);
      return null;
    }

    let data: unknown;
    try {
      data = JSON.parse(rawBody);
    } catch (err) {
      console.error('Failed to parse Gemini Vision JSON:', err, 'body:', rawBody);
      return null;
    }

    const visionData = data as {
      candidates?: Array<{ content?: { parts?: Array<{ text?: string }> } }>;
      error?: unknown;
    };

    if (!visionData.candidates || visionData.candidates.length === 0) {
      console.error('No candidates from Gemini Vision', visionData);
      return null;
    }

    const rawText = visionData.candidates[0]?.content?.parts?.[0]?.text;
    logTokenUsage(data, 'Vision');

    // DEBUG: Log raw OCR output for debugging
    console.log('=== GEMINI VISION RAW OUTPUT START ===');
    console.log(rawText);
    console.log('=== GEMINI VISION RAW OUTPUT END ===');

    const jsonStr = (rawText || '').replace(/```json\n?|\n?```/g, '').trim();
    let result = JSON.parse(jsonStr);

    // Handle case where AI returns an array
    if (Array.isArray(result)) {
      result = result[0];
    }

    // Manual Date Offset Calculation (More robust than AI)
    let dateOffset = 0;
    if (result.date) {
      try {
        const today = new Date();
        const transDate = new Date(result.date);

        // Reset time part to ensure day-only comparison
        today.setHours(0, 0, 0, 0);
        transDate.setHours(0, 0, 0, 0);

        // Difference in milliseconds
        const diffMs = transDate.getTime() - today.getTime();
        // Convert to days (round to handle DST etc)
        dateOffset = Math.round(diffMs / (1000 * 60 * 60 * 24));

        console.log(`Date calc: ${result.date} -> offset ${dateOffset}`);
      } catch (e) {
        console.error('Date parse error:', e);
        // Fallback to AI's offset if date parse fails
        dateOffset = Number(result.dateOffset) || 0;
      }
    } else {
      dateOffset = Number(result.dateOffset) || 0;
    }

    return {
      type: 'expense',
      amount: Number(result.amount) || 0,
      categoryHint: result.categoryHint || 'Pengeluaran',
      walletHint: null,
      notes: result.notes || 'Scan Struk',
      confidence: 0.9,
      dateOffset: dateOffset,
    };
  } catch (error) {
    console.error('Gemini Vision API error:', error);
    return null;
  }
}

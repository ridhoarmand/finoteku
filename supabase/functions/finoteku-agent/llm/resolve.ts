/**
 * The only places agent v2 calls an LLM for transactions, and only after the local
 * parser is unsure. Prompts carry the few candidates the parser already narrowed
 * down, never the user's whole category list (except the rare no-amount fallback).
 */
import type { AIProvider } from '../providers/base.ts';
import type { Cat, Wal } from '../nlu/match.ts';

export interface Unsure {
  i: number;
  text: string;
  type: 'income' | 'expense';
  candidates: Cat[];
}

/** Picks one category per unsure item, in a single call. Returns item index → category. */
/** The user's own rules from the app (Chat Bot → Pelatihan), kept short to save tokens. */
const withRules = (system: string, rules?: string[]) =>
  rules?.length ? `${system}\nAturan user: ${rules.join(' | ').slice(0, 400)}` : system;

/** OpenAI-style JSON mode returns an object; accept {key: [...]} or a bare array. */
function list<T>(out: unknown, key: string): T[] {
  if (Array.isArray(out)) return out as T[];
  const v = (out as Record<string, unknown> | null)?.[key];
  return Array.isArray(v) ? (v as T[]) : [];
}

export async function pickCategories(ai: AIProvider, items: Unsure[], all: Cat[], rules?: string[]): Promise<Map<number, Cat>> {
  const lines = items.map((it) => {
    const opts = (it.candidates.length ? it.candidates : all.filter((c) => c.type === it.type)).map((c) => c.name);
    return `${it.i}. "${it.text}" → ${opts.join(' | ')}`;
  });
  const out = await ai.generateJSON<unknown>(lines.join('\n'), {
    systemPrompt: withRules('Pilih satu kategori dari opsi untuk tiap transaksi. Salin nama kategori persis. JSON: {"items":[{"i":0,"c":"Nama"}]}', rules),
    maxTokens: 30 + items.length * 20,
    temperature: 0,
  });
  const picked = new Map<number, Cat>();
  for (const { i, c } of list<{ i: number; c: string }>(out, 'items')) {
    const item = items.find((x) => x.i === i);
    const cat = all.find((x) => x.name.toLowerCase() === String(c).toLowerCase() && (!item || x.type === item.type)) ??
      all.find((x) => x.name.toLowerCase() === String(c).toLowerCase());
    if (cat) picked.set(i, cat); // anything not in the user's list is dropped, never invented
  }
  return picked;
}

export interface LlmTx {
  type: 'income' | 'expense' | 'transfer';
  amount: number;
  category?: string;
  wallet?: string;
  to_wallet?: string;
  day_offset?: number;
  notes?: string;
}

/** Full parse, used only when no amount could be read locally (e.g. "dua puluh ribu"). */
export async function parseFallback(ai: AIProvider, text: string, categories: Cat[], wallets: Wal[], rules?: string[]): Promise<LlmTx[]> {
  const names = (t: string) => categories.filter((c) => c.type === t).map((c) => c.name).join('|');
  const prompt = `"${text}"\nexpense: ${names('expense')}\nincome: ${names('income')}\nwallet: ${wallets.map((w) => w.name).join('|')}`;
  const out = await ai.generateJSON<unknown>(prompt, {
    systemPrompt: withRules(
      'Ubah teks keuangan Indonesia jadi transaksi. JSON: {"transactions":[{"type":"expense|income|transfer","amount":20000,"category":"","wallet":"","to_wallet":"","day_offset":0,"notes":""}]}. amount angka rupiah. category/wallet salin persis dari daftar. day_offset: 0 hari ini, -1 kemarin. notes singkat tanpa nominal. Bukan transaksi → {"transactions":[]}.',
      rules,
    ),
    maxTokens: 200,
    temperature: 0,
  });
  return list<LlmTx>(out, 'transactions').filter((t) => Number(t.amount) > 0);
}

export interface LlmEdit {
  item?: number;
  amount?: number;
  category?: string;
  wallet?: string;
  to_wallet?: string;
  day_offset?: number;
  notes?: string;
}

/** Reads an edit request the local rules did not understand ("ubah jadi buat makan malam"). */
export async function parseEdit(ai: AIProvider, text: string, summary: string): Promise<LlmEdit> {
  const out = await ai.generateJSON<LlmEdit>(`Pending:\n${summary}\nUbah: "${text}"`, {
    systemPrompt:
      'User mengubah transaksi pending. JSON berisi hanya field yang berubah: item (nomor 1-based bila disebut), amount, category, wallet, to_wallet, day_offset (relatif hari ini), notes.',
    maxTokens: 80,
    temperature: 0,
  });
  return out ?? {};
}

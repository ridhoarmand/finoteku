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
export async function pickCategories(ai: AIProvider, items: Unsure[], all: Cat[]): Promise<Map<number, Cat>> {
  const lines = items.map((it) => {
    const opts = (it.candidates.length ? it.candidates : all.filter((c) => c.type === it.type)).map((c) => c.name);
    return `${it.i}. "${it.text}" → ${opts.join(' | ')}`;
  });
  const out = await ai.generateJSON<{ i: number; c: string }[]>(lines.join('\n'), {
    systemPrompt: 'Pilih satu kategori dari opsi untuk tiap transaksi. Salin nama kategori persis.',
    maxTokens: 20 + items.length * 20,
    temperature: 0,
    schema: {
      type: 'ARRAY',
      items: { type: 'OBJECT', properties: { i: { type: 'INTEGER' }, c: { type: 'STRING' } }, required: ['i', 'c'] },
    },
  });
  const picked = new Map<number, Cat>();
  for (const { i, c } of Array.isArray(out) ? out : []) {
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
export async function parseFallback(ai: AIProvider, text: string, categories: Cat[], wallets: Wal[]): Promise<LlmTx[]> {
  const names = (t: string) => categories.filter((c) => c.type === t).map((c) => c.name).join('|');
  const prompt = `"${text}"\nexpense: ${names('expense')}\nincome: ${names('income')}\nwallet: ${wallets.map((w) => w.name).join('|')}`;
  const out = await ai.generateJSON<LlmTx[]>(prompt, {
    systemPrompt:
      'Ubah teks keuangan Indonesia jadi daftar transaksi. amount dalam rupiah (angka). category/wallet salin persis dari daftar. day_offset: 0 hari ini, -1 kemarin. notes singkat tanpa nominal. Teks bukan transaksi → [].',
    maxTokens: 160,
    temperature: 0,
    schema: {
      type: 'ARRAY',
      items: {
        type: 'OBJECT',
        properties: {
          type: { type: 'STRING', enum: ['income', 'expense', 'transfer'] },
          amount: { type: 'NUMBER' },
          category: { type: 'STRING' },
          wallet: { type: 'STRING' },
          to_wallet: { type: 'STRING' },
          day_offset: { type: 'INTEGER' },
          notes: { type: 'STRING' },
        },
        required: ['type', 'amount'],
      },
    },
  });
  return (Array.isArray(out) ? out : []).filter((t) => Number(t.amount) > 0);
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
      'User mengubah transaksi pending. Kembalikan hanya field yang berubah. item = nomor transaksi (1-based) bila disebut. day_offset relatif hari ini.',
    maxTokens: 60,
    temperature: 0,
    schema: {
      type: 'OBJECT',
      properties: {
        item: { type: 'INTEGER' }, amount: { type: 'NUMBER' }, category: { type: 'STRING' }, wallet: { type: 'STRING' },
        to_wallet: { type: 'STRING' }, day_offset: { type: 'INTEGER' }, notes: { type: 'STRING' },
      },
    },
  });
  return out ?? {};
}

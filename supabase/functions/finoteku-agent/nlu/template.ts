/**
 * Structured messages, e.g. a confirmation the user copied and edited:
 *   💸 Pengeluaran / 📅 Jumat, 6 November 2026 / 💳 Gopay / 💵 Rp 25.000 / 📁 Makanan / 📝 Makan Siang
 * Fields are read line by line from their marker (emoji or "Kategori:" style label).
 */
import { findAmounts } from './amount.ts';
import { parseDate } from './date.ts';
import { type Cat, findWallet, type Wal } from './match.ts';
import { normalize } from './text.ts';

const MARKERS = {
  category: /^(?:📁|kategori\s*:)/i,
  wallet: /^(?:💳|dompet\s*:|wallet\s*:)/i,
  amount: /^(?:💵|nominal\s*:|jumlah\s*:)/i,
  notes: /^(?:📝|catatan\s*:|notes?\s*:|keterangan\s*:)/i,
  date: /^(?:📅|tanggal\s*:|tgl\s*:)/i,
};

const MONTHS = ['januari', 'februari', 'maret', 'april', 'mei', 'juni', 'juli', 'agustus', 'september', 'oktober', 'november', 'desember'];

export interface TemplateFields {
  type?: 'income' | 'expense';
  amount?: number;
  category?: Cat;
  wallet?: Wal;
  notes?: string;
  date?: string;
}

/** Returns the fields when [text] looks like a template (≥2 marked lines), else null. */
export function readTemplate(text: string, categories: Cat[], wallets: Wal[], today: string): TemplateFields | null {
  const lines = text.split('\n').map((l) => l.trim()).filter(Boolean);
  const marked = lines.filter((l) => Object.values(MARKERS).some((m) => m.test(l)));
  if (marked.length < 2) return null;

  const out: TemplateFields = {};
  if (/💸|\bpengeluaran\b/i.test(text)) out.type = 'expense';
  if (/💰|\bpemasukan\b/i.test(text)) out.type = 'income';
  const value = (l: string, m: RegExp) => l.replace(m, '').replace(/^[\s:]+/, '').trim();

  for (const line of lines) {
    if (MARKERS.category.test(line)) {
      // "Transportasi › Bensin" / "Transportasi > Bensin" → the child is the category
      const name = normalize(value(line, MARKERS.category).split(/›|>|\//).pop() ?? '').replace(/\s*❓$/, '');
      out.category = categories.find((c) => normalize(c.name) === name && (!out.type || c.type === out.type)) ??
        categories.find((c) => normalize(c.name) === name);
    } else if (MARKERS.wallet.test(line)) {
      const v = value(line, MARKERS.wallet);
      out.wallet = wallets.find((w) => normalize(w.name) === normalize(v)) ?? findWallet(v, wallets)?.wallet;
    } else if (MARKERS.amount.test(line)) {
      out.amount = findAmounts(value(line, MARKERS.amount))[0]?.amount;
    } else if (MARKERS.notes.test(line)) {
      out.notes = value(line, MARKERS.notes);
    } else if (MARKERS.date.test(line)) {
      const v = value(line, MARKERS.date).toLowerCase();
      const m = v.match(/(\d{1,2})\s+([a-z]+)\s+(\d{4})/);
      const month = m ? MONTHS.indexOf(m[2]) + 1 : 0;
      out.date = month
        ? `${m![3]}-${String(month).padStart(2, '0')}-${m![1].padStart(2, '0')}`
        : parseDate(v, today)?.date;
    }
  }
  return out;
}

/** Local transaction parser: chat text → transactions, with per-field confidence. No LLM. */
import { findAmounts } from './amount.ts';
import { parseDate } from './date.ts';
import {
  type Cat, type CatScore, cashWallet, findWallet, findWallets, type HistoryRow, isIncomeText,
  isTransferText, scoreCategories, type Wal, walletFromHistory,
} from './match.ts';
import { FILLER, normalize, titleCase } from './text.ts';

export interface ParseContext {
  categories: Cat[];
  wallets: Wal[];
  history: HistoryRow[];
  today: string; // YYYY-MM-DD in the user's zone
}

export interface ParsedTx {
  type: 'income' | 'expense' | 'transfer';
  amount: number;
  date: string;
  wallet: Wal | null;
  toWallet: Wal | null;
  category: Cat | null;
  notes: string;
  /** Best categories for the user/LLM to choose from when [categorySure] is false. */
  candidates: Cat[];
  categorySure: boolean;
  /** Part of the message this transaction came from. */
  source: string;
}

/** Score must be this high, and this far ahead of the runner-up, to skip asking. */
const SURE_SCORE = 2.5;
const SURE_GAP = 1.0;

/**
 * Splits "makan 20k, kopi 15k gopay" into one segment per amount.
 * Commas/newlines/"dan"/"+" separate items only when both sides carry an amount.
 */
export function splitItems(text: string): string[] {
  const parts = text.split(/\n|;|,(?!\d)|\s\+\s|\s(?:dan|sama|terus|trus|lalu)\s/i).map((p) => p.trim()).filter(Boolean);
  const withAmount = parts.filter((p) => findAmounts(p).length > 0);
  if (withAmount.length <= 1) return [text.trim()];
  // glue amount-less parts (e.g. trailing "pakai gopay") to the previous item
  const out: string[] = [];
  for (const p of parts) {
    if (findAmounts(p).length || out.length === 0) out.push(p);
    else out[out.length - 1] += ` ${p}`;
  }
  return out;
}

function cleanNotes(text: string, strip: string[]): string {
  let t = ` ${text.toLowerCase()} `;
  for (const s of strip.filter(Boolean).sort((a, b) => b.length - a.length)) {
    t = t.replace(s.toLowerCase(), ' ');
  }
  const words = t.replace(/[^a-z0-9 ]/g, ' ').split(/\s+/)
    .filter((w) => w && !FILLER.has(w) && !/^\d+$/.test(w));
  return titleCase(words.join(' ')).slice(0, 80);
}

export function parseTransactions(text: string, ctx: ParseContext): ParsedTx[] {
  const items = splitItems(text);
  // A wallet/date named once applies to every item ("makan 20k, kopi 15k pakai gopay kemarin")
  const sharedWallet = items.length > 1 ? findWallet(text, ctx.wallets) : null;
  const sharedDate = items.length > 1 ? parseDate(text, ctx.today) : null;
  return items.map((item) => parseOne(item, ctx, sharedWallet, sharedDate)).filter((t): t is ParsedTx => t !== null);
}

function parseOne(
  text: string,
  ctx: ParseContext,
  sharedWallet: ReturnType<typeof findWallet>,
  sharedDate: ReturnType<typeof parseDate>,
): ParsedTx | null {
  const dateM = parseDate(text, ctx.today) ?? sharedDate;
  // read the amount after removing the date phrase, so "05/11/2026" is not Rp 2.026
  const noDate = dateM ? text.replace(dateM.raw, ' ') : text;
  const amountM = findAmounts(noDate)[0];
  if (!amountM) return null;

  const transferWord = isTransferText(text);
  const strip: string[] = [amountM.raw, dateM?.raw ?? '', transferWord ?? ''];

  if (transferWord) {
    // "tf bca ke gopay 100k", "topup gopay 100k dari bca", "tarik tunai bca 500rb" (→ Cash)
    // drop the transfer word first: "tarik tunai" must not read as the Cash wallet
    const body = noDate.replace(new RegExp(transferWord, 'i'), ' ');
    const hits = findWallets(body, ctx.wallets);
    // same normalization as findWallets, so indexes are comparable
    const norm = ` ${normalize(body).replace(/[^a-z0-9 ]/g, ' ')} `;
    const after = (word: string) => {
      const i = norm.indexOf(` ${word} `);
      return i < 0 ? null : hits.find((h) => h.index > i) ?? null;
    };
    let from = after('dari');
    let to = after('ke') ?? after('to');
    const rest = hits.filter((h) => h !== from && h !== to);
    if (/top ?up|isi saldo|setor/.test(transferWord)) to ??= rest.shift() ?? null;
    from ??= rest.shift() ?? null;
    to ??= rest.shift() ?? null;
    if (/setor/.test(transferWord)) from ??= { wallet: cashWallet(ctx.wallets)!, raw: '', index: -1 };
    const toCash = /tarik/.test(transferWord) ? cashWallet(ctx.wallets) : null;
    strip.push(from?.raw ?? '', to?.raw ?? '', 'tunai');
    return {
      type: 'transfer', amount: amountM.amount, date: dateM?.date ?? ctx.today,
      wallet: from?.wallet ?? null, toWallet: to?.wallet ?? toCash,
      category: null, candidates: [], categorySure: true,
      notes: cleanNotes(noDate, strip) || 'Transfer', source: text,
    };
  }

  const walletM = findWallet(text, ctx.wallets) ?? sharedWallet;
  if (walletM) strip.push(walletM.raw);
  const notes = cleanNotes(noDate, strip);

  const incomeWord = isIncomeText(text);
  const scored: CatScore[] = scoreCategories(notes || text, ctx.categories, ctx.history);
  // the type word ("gaji", "terima") decides the side; otherwise the best category does
  const type: 'income' | 'expense' = incomeWord ? 'income' : (scored[0]?.category.type ?? 'expense');
  const sameType = scored.filter((s) => s.category.type === type);
  const top = sameType[0];
  // a parent and its own child are not rivals: the more specific child is fine
  const related = (a: Cat, b: Cat) => a.parent_name === b.name || b.parent_name === a.name;
  const second = sameType.slice(1).find((s) => !related(s.category, top.category));
  const categorySure = !!top && top.score >= SURE_SCORE && top.score - (second?.score ?? 0) >= SURE_GAP;
  const candidates = sameType.slice(0, 6).map((s) => s.category);

  return {
    type,
    amount: amountM.amount,
    date: dateM?.date ?? ctx.today,
    wallet: walletM?.wallet ?? walletFromHistory(notes, ctx.wallets, ctx.history) ?? cashWallet(ctx.wallets),
    toWallet: null,
    category: top?.category ?? null,
    candidates,
    categorySure,
    notes: notes || top?.category.name || 'Transaksi',
    source: text,
  };
}

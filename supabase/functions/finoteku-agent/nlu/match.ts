/** Wallet and category matching without an LLM. */
import { FILLER, normalize, tokens } from './text.ts';

export interface Cat {
  id: string;
  name: string;
  type: 'income' | 'expense';
  parent_name: string | null;
}
export interface Wal {
  id: string;
  name: string;
}
/** One past transaction: what the user wrote and where it went. */
export interface HistoryRow {
  notes: string | null;
  category_id: string | null;
  wallet_id: string | null;
}

// Common ways people name a wallet in chat → canonical key compared with wallet names.
const WALLET_ALIASES: Record<string, string[]> = {
  cash: ['cash', 'tunai', 'kas', 'dompet', 'uang tunai', 'cash on hand'],
  bca: ['bca', 'klikbca', 'mbca', 'm-bca', 'bca mobile', 'blu', 'blu bca'],
  mandiri: ['mandiri', 'livin', 'livin mandiri'],
  bri: ['bri', 'brimo'],
  bni: ['bni', 'wondr'],
  bsi: ['bsi', 'syariah indonesia'],
  cimb: ['cimb', 'cimb niaga', 'octo'],
  jago: ['jago', 'bank jago'],
  seabank: ['seabank', 'sea bank'],
  gopay: ['gopay', 'go pay', 'gojek'],
  ovo: ['ovo'],
  dana: ['dana'],
  shopeepay: ['shopeepay', 'shopee pay', 'spay'],
  linkaja: ['linkaja', 'link aja'],
  flip: ['flip'],
  jenius: ['jenius'],
  superbank: ['superbank'],
  neo: ['neo', 'neobank'],
  kredit: ['kartu kredit', 'cc', 'credit card'],
};

function walletNames(w: Wal): Set<string> {
  const wn = normalize(w.name);
  const names = new Set([wn]);
  for (const [key, aliases] of Object.entries(WALLET_ALIASES)) {
    if (wn.includes(key) || aliases.includes(wn)) aliases.forEach((a) => names.add(a)), names.add(key);
  }
  return names;
}

export interface WalletHit {
  wallet: Wal;
  raw: string;
  index: number;
}

/** Every wallet named in [text], in order of appearance. Longest alias wins per spot. */
export function findWallets(text: string, wallets: Wal[]): WalletHit[] {
  const t = ` ${normalize(text).replace(/[^a-z0-9 ]/g, ' ')} `;
  const hits: WalletHit[] = [];
  for (const w of wallets) {
    for (const n of walletNames(w)) {
      if (n.length < 2) continue;
      const i = t.indexOf(` ${n} `);
      if (i >= 0) hits.push({ wallet: w, raw: n, index: i });
    }
  }
  hits.sort((a, b) => a.index - b.index || b.raw.length - a.raw.length);
  // drop shorter hits inside a longer one ("bca" inside "bca mobile") and repeats of a wallet
  return hits.filter((h, i) =>
    !hits.some((o, j) => j !== i && o.index <= h.index && o.index + o.raw.length >= h.index + h.raw.length && o.raw.length > h.raw.length) &&
    hits.findIndex((o) => o.wallet.id === h.wallet.id) === i
  );
}

export function findWallet(text: string, wallets: Wal[]): WalletHit | null {
  return findWallets(text, wallets)[0] ?? null;
}

export function cashWallet(wallets: Wal[]): Wal | null {
  return wallets.find((w) => WALLET_ALIASES.cash.some((a) => normalize(w.name).includes(a))) ?? wallets[0] ?? null;
}

// Everyday words → category-name stems they usually belong to. Matched against
// the user's own category names, so it works with any naming ("Makan", "Food & Drink").
const SYNONYMS: Array<[string[], string[]]> = [
  [['makan', 'nasi', 'ayam', 'bakso', 'mie', 'soto', 'sate', 'warteg', 'padang', 'sarapan', 'lunch', 'dinner', 'gofood', 'grabfood', 'shopeefood', 'pecel', 'geprek', 'martabak', 'roti', 'snack', 'jajan', 'cemilan', 'gorengan', 'pizza', 'burger', 'kfc', 'mcd', 'resto', 'restoran'],
    ['makan', 'food', 'kuliner', 'jajan', 'konsumsi']],
  [['kopi', 'coffee', 'teh', 'es', 'jus', 'boba', 'minum', 'starbucks', 'janji jiwa', 'kenangan', 'chatime', 'susu', 'air', 'aqua'],
    ['minum', 'kopi', 'drink', 'jajan', 'makan']],
  [['bensin', 'pertalite', 'pertamax', 'solar', 'bbm', 'spbu', 'isi bensin'], ['bensin', 'bbm', 'transport', 'kendaraan', 'fuel']],
  [['parkir', 'tol', 'etoll', 'e-toll', 'gojek', 'grab', 'ojek', 'ojol', 'taksi', 'taxi', 'krl', 'mrt', 'busway', 'transjakarta', 'kereta', 'angkot', 'bus', 'tiket'],
    ['transport', 'perjalanan', 'kendaraan', 'travel']],
  [['service', 'servis', 'oli', 'ban', 'bengkel', 'cuci motor', 'cuci mobil'], ['kendaraan', 'transport', 'perawatan']],
  [['listrik', 'pln', 'token', 'air', 'pdam', 'wifi', 'internet', 'indihome', 'biznet', 'gas', 'iuran', 'ipl', 'bpjs', 'tagihan', 'cicilan', 'kos', 'kost', 'sewa', 'kontrakan'],
    ['tagihan', 'bill', 'utilitas', 'rumah', 'cicilan', 'sewa', 'kos']],
  [['pulsa', 'kuota', 'paket data', 'data'], ['pulsa', 'kuota', 'internet', 'tagihan', 'komunikasi']],
  [['belanja', 'indomaret', 'alfamart', 'supermarket', 'sayur', 'beras', 'minyak', 'telur', 'sabun', 'shampo', 'tisu', 'galon', 'pasar', 'bulanan', 'groceries'],
    ['belanja', 'kebutuhan', 'groceries', 'rumah tangga', 'dapur']],
  [['baju', 'celana', 'sepatu', 'kaos', 'jaket', 'tas', 'shopee', 'tokopedia', 'lazada', 'tiktok shop', 'online'],
    ['belanja', 'fashion', 'pakaian', 'shopping']],
  [['obat', 'dokter', 'apotek', 'klinik', 'rs', 'rumah sakit', 'vitamin', 'periksa'], ['kesehatan', 'health', 'medis', 'obat']],
  [['netflix', 'spotify', 'youtube', 'bioskop', 'film', 'game', 'nonton', 'karaoke', 'liburan', 'wisata', 'hotel'],
    ['hiburan', 'entertainment', 'langganan', 'rekreasi', 'liburan']],
  [['sekolah', 'kuliah', 'spp', 'buku', 'kursus', 'les', 'ukt', 'seminar'], ['pendidikan', 'education', 'sekolah']],
  [['zakat', 'infaq', 'infak', 'sedekah', 'donasi', 'kondangan', 'sumbangan', 'kado', 'hadiah', 'amal'],
    ['sedekah', 'donasi', 'sosial', 'amal', 'hadiah', 'zakat']],
  [['potong rambut', 'cukur', 'salon', 'skincare', 'kosmetik', 'laundry'], ['perawatan', 'pribadi', 'personal', 'kecantikan', 'laundry']],
  [['admin', 'biaya admin', 'fee', 'potongan'], ['admin', 'biaya', 'fee']],
  // income
  [['gaji', 'gajian', 'salary', 'payroll'], ['gaji', 'salary', 'pendapatan', 'penghasilan']],
  [['bonus', 'thr', 'insentif', 'komisi', 'tunjangan'], ['bonus', 'thr', 'gaji', 'pendapatan']],
  [['freelance', 'proyek', 'project', 'job', 'fee jasa', 'honor', 'klien', 'client'], ['freelance', 'proyek', 'usaha', 'pendapatan', 'sampingan']],
  [['jual', 'jualan', 'penjualan', 'dagang', 'omzet'], ['usaha', 'penjualan', 'bisnis', 'jualan']],
  [['bunga', 'dividen', 'investasi', 'saham', 'reksadana', 'cashback', 'refund'], ['investasi', 'bunga', 'cashback', 'lain']],
];

const INCOME_WORDS = ['gaji', 'gajian', 'terima', 'diterima', 'masuk', 'dapat', 'dapet', 'pemasukan', 'bonus', 'thr', 'income', 'cair', 'dikasih', 'dikirimin', 'jual', 'dijual', 'terjual', 'laku', 'transferan', 'cashback', 'refund'];
const TRANSFER_WORDS = ['transfer', 'tf', 'pindah', 'pindahin', 'mutasi', 'tarik tunai', 'tarik', 'topup', 'top up', 'isi saldo', 'setor tunai', 'setor'];

export function hasWord(text: string, words: string[]): string | null {
  const t = ` ${normalize(text).replace(/[^a-z0-9 ]/g, ' ')} `;
  return words.find((w) => t.includes(` ${w} `)) ?? null;
}
export const isIncomeText = (t: string) => hasWord(t, INCOME_WORDS);
export const isTransferText = (t: string) => hasWord(t, TRANSFER_WORDS);

export interface CatScore {
  category: Cat;
  score: number;
}

/**
 * Scores categories for [text].
 * - history: words the user wrote before → the category they saved it under (learns from corrections)
 * - name: the word is (part of) the category or parent name
 * - synonyms: everyday words → category stems
 */
export function scoreCategories(text: string, categories: Cat[], history: HistoryRow[]): CatScore[] {
  const words = tokens(text).filter((w) => !FILLER.has(w) && !/^\d/.test(w));
  const phrase = ` ${words.join(' ')} `;
  const scores = new Map<string, number>();
  const add = (id: string, s: number) => scores.set(id, (scores.get(id) ?? 0) + s);
  const byId = new Map(categories.map((c) => [c.id, c]));

  // history: exact notes match counts most, shared words less; recent rows first
  history.forEach((h, i) => {
    if (!h.notes || !h.category_id || !byId.has(h.category_id)) return;
    const recency = 1 - i / (history.length + 1) * 0.5;
    const hw = tokens(h.notes).filter((w) => !FILLER.has(w) && !/^\d/.test(w));
    if (hw.length && hw.join(' ') === words.join(' ')) add(h.category_id, 6 * recency);
    const shared = hw.filter((w) => words.includes(w)).length;
    if (shared) add(h.category_id, (2 * shared / Math.max(hw.length, 1)) * recency);
  });

  for (const c of categories) {
    const own = normalize(c.name), parent = normalize(c.parent_name ?? '');
    for (const w of words) {
      if (w.length < 3) continue;
      if (own === w) add(c.id, 5);
      else if (own.split(/\W+/).includes(w)) add(c.id, 3);
      else if (parent && parent.split(/\W+/).includes(w)) add(c.id, 1);
    }
    for (const [keys, stems] of SYNONYMS) {
      if (!keys.some((k) => phrase.includes(` ${k} `))) continue;
      const idx = stems.findIndex((s) => own.includes(s) || (parent && parent.includes(s)));
      if (idx >= 0) add(c.id, 2.5 - idx * 0.5 + (stems.some((s) => own.includes(s)) ? 0.5 : 0));
    }
  }
  return [...scores.entries()]
    .map(([id, score]) => ({ category: byId.get(id)!, score }))
    .sort((a, b) => b.score - a.score);
}

/** Most-used wallet for these words in history (e.g. "kopi" usually paid with Gopay). */
export function walletFromHistory(text: string, wallets: Wal[], history: HistoryRow[]): Wal | null {
  const words = tokens(text).filter((w) => !FILLER.has(w) && !/^\d/.test(w));
  const count = new Map<string, number>();
  for (const h of history) {
    if (!h.notes || !h.wallet_id) continue;
    if (tokens(h.notes).some((w) => words.includes(w))) count.set(h.wallet_id, (count.get(h.wallet_id) ?? 0) + 1);
  }
  const top = [...count.entries()].sort((a, b) => b[1] - a[1])[0];
  return top && top[1] >= 2 ? wallets.find((w) => w.id === top[0]) ?? null : null;
}

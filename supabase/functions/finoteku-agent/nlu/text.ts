/** Text helpers shared by the local (no-LLM) parser. Pure functions, no Deno APIs. */

export function normalize(text: string): string {
  return text.toLowerCase().replace(/\s+/g, ' ').trim();
}

/** Word tokens (letters/digits), lowercase. */
export function tokens(text: string): string[] {
  return normalize(text).split(/[^a-z0-9]+/).filter(Boolean);
}

/** Words that carry no meaning for category/wallet matching or notes. */
export const FILLER = new Set([
  'pake', 'pakai', 'via', 'dari', 'ke', 'di', 'buat', 'untuk', 'utk', 'u', 'yg', 'yang',
  'dan', 'sama', 'tadi', 'aja', 'saja', 'nya', 'rp', 'idr', 'harga', 'total', 'sebesar',
  'beli', 'bayar', 'byr', 'keluar', 'masuk', 'terima', 'dapat', 'dapet', 'pengeluaran',
  'pemasukan', 'catat', 'tolong', 'pakek', 'lewat', 'dgn', 'dengan', 'senilai', 'seharga',
]);

export function titleCase(text: string): string {
  return text.replace(/\S+/g, (w) => w[0].toUpperCase() + w.slice(1));
}

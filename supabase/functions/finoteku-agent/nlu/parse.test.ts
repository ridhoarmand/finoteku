// Run: bun test supabase/functions/finoteku-agent/nlu   (no Deno APIs in nlu/)
import { describe, expect, test } from 'bun:test';
import { findAmounts } from './amount.ts';
import { monthRange, parseDate, todayIn } from './date.ts';
import { parseTransactions, splitItems } from './parse.ts';
import type { Cat, HistoryRow, Wal } from './match.ts';

const c = (id: string, name: string, type: 'income' | 'expense', parent: string | null = null): Cat => ({ id, name, type, parent_name: parent });
const CATS: Cat[] = [
  c('makan', 'Makanan', 'expense'), c('minum', 'Minuman', 'expense'), c('trans', 'Transportasi', 'expense'),
  c('bensin', 'Bensin', 'expense', 'Transportasi'), c('belanja', 'Belanja', 'expense'), c('tagihan', 'Tagihan', 'expense'),
  c('listrik', 'Listrik', 'expense', 'Tagihan'), c('pulsa', 'Pulsa & Internet', 'expense'), c('sehat', 'Kesehatan', 'expense'),
  c('hibur', 'Hiburan', 'expense'), c('didik', 'Pendidikan', 'expense'), c('sedekah', 'Sedekah', 'expense'),
  c('gaji', 'Gaji', 'income'), c('bonus', 'Bonus', 'income'), c('free', 'Freelance', 'income'), c('jual', 'Penjualan', 'income'),
];
const w = (id: string, name: string): Wal => ({ id, name });
const WALLETS = [w('cash', 'Cash'), w('bca', 'BCA'), w('gopay', 'Gopay'), w('ovo', 'OVO'), w('mandiri', 'Mandiri')];
const TODAY = '2026-11-06'; // Friday

function one(text: string, history: HistoryRow[] = []) {
  const r = parseTransactions(text, { categories: CATS, wallets: WALLETS, history, today: TODAY });
  expect(r.length).toBe(1);
  return r[0];
}

describe('amount', () => {
  const cases: Array<[string, number]> = [
    ['25rb', 25000], ['25k', 25000], ['25 ribu', 25000], ['25.000', 25000], ['1.250.000', 1250000],
    ['1,5jt', 1500000], ['1.5 juta', 1500000], ['2jt500', 2500000], ['2jt 500rb', 2500000], ['rp 50.000', 50000],
    ['Rp50.000,00', 50000], ['15000', 15000], ['goceng', 5000], ['ceban', 10000], ['gocap', 50000], ['sejuta', 1000000],
    ['3M', 3000000000],
  ];
  for (const [text, want] of cases) test(text, () => expect(findAmounts(`beli ${text} x`)[0]?.amount).toBe(want));
  test('small bare numbers are not money', () => expect(findAmounts('tgl 5 beli 2 porsi')).toEqual([]));
  test('trailing quantity keeps the amount', () => expect(findAmounts('nasi 25rb 2 porsi')[0].amount).toBe(25000));
});

describe('date', () => {
  const cases: Array<[string, string | null]> = [
    ['makan', null], ['kemarin', '2026-11-05'], ['kmrn', '2026-11-05'], ['kemarin lusa', '2026-11-04'],
    ['besok', '2026-11-07'], ['lusa', '2026-11-08'], ['3 hari lalu', '2026-11-03'], ['tadi pagi', TODAY],
    ['senin', '2026-11-02'], ['jumat', TODAY], ['jumat lalu', '2026-10-30'], ['tgl 3', '2026-11-03'],
    ['tgl 20', '2026-10-20'], ['5/11', '2026-11-05'], ['25/12', '2025-12-25'], ['05-11-2026', '2026-11-05'],
    ['minggu lalu', null],
  ];
  for (const [text, want] of cases) test(text, () => expect(parseDate(text, TODAY)?.date ?? null).toBe(want));
  test('todayIn uses the user zone, not UTC', () => {
    // 2026-11-05 23:30 UTC = 2026-11-06 06:30 WIB
    expect(todayIn('Asia/Jakarta', new Date('2026-11-05T23:30:00Z'))).toBe('2026-11-06');
  });
  test('monthRange ends on the real last day', () => {
    expect(monthRange(2026, 11).end).toBe('2026-11-30');
    expect(monthRange(2028, 2).end).toBe('2028-02-29');
    expect(monthRange(2026, 12).end).toBe('2026-12-31');
  });
});

describe('split', () => {
  test('comma list', () => expect(splitItems('makan 20k, kopi 15k')).toEqual(['makan 20k', 'kopi 15k']));
  test('dan between amounts', () => expect(splitItems('bensin 30rb dan parkir 5rb')).toEqual(['bensin 30rb', 'parkir 5rb']));
  test('dan inside one item stays', () => expect(splitItems('nasi dan teh 25k')).toEqual(['nasi dan teh 25k']));
  test('decimal comma is not a split', () => expect(splitItems('gaji 7,5jt')).toEqual(['gaji 7,5jt']));
  test('newlines', () => expect(splitItems('makan 20k\ngrab 15k')).toEqual(['makan 20k', 'grab 15k']));
});

// [input, type, amount, categoryId|null, walletId, notes?]
const CORPUS: Array<[string, string, number, string | null, string, string?]> = [
  ['makan siang 25rb', 'expense', 25000, 'makan', 'cash', 'Makan Siang'],
  ['nasi padang 20k', 'expense', 20000, 'makan', 'cash', 'Nasi Padang'],
  ['beli kopi 15k gopay', 'expense', 15000, 'minum', 'gopay', 'Kopi'],
  ['es teh 5rb', 'expense', 5000, 'minum', 'cash'],
  ['bensin 30rb', 'expense', 30000, 'bensin', 'cash'],
  ['isi pertalite 50rb', 'expense', 50000, 'bensin', 'cash'],
  ['parkir 2rb', 'expense', 2000, 'trans', 'cash'],
  ['grab ke kantor 25k ovo', 'expense', 25000, 'trans', 'ovo'],
  ['token listrik 200rb bca', 'expense', 200000, 'listrik', 'bca'],
  ['bayar wifi 350rb', 'expense', 350000, 'tagihan', 'cash'],
  ['pulsa 50rb', 'expense', 50000, 'pulsa', 'cash'],
  ['kuota 100k gopay', 'expense', 100000, 'pulsa', 'gopay'],
  ['belanja indomaret 87.500', 'expense', 87500, 'belanja', 'cash'],
  ['beras 5kg 75rb', 'expense', 75000, 'belanja', 'cash'],
  ['obat batuk 35rb', 'expense', 35000, 'sehat', 'cash'],
  ['netflix 54rb bca', 'expense', 54000, 'hibur', 'bca'],
  ['bayar spp 500rb mandiri', 'expense', 500000, 'didik', 'mandiri'],
  ['sedekah jumat 20rb', 'expense', 20000, 'sedekah', 'cash'],
  ['gaji 7,5jt bca', 'income', 7500000, 'gaji', 'bca'],
  ['gajian 8jt mandiri', 'income', 8000000, 'gaji', 'mandiri'],
  ['terima bonus 1jt', 'income', 1000000, 'bonus', 'cash'],
  ['thr 5jt bca', 'income', 5000000, 'bonus', 'bca'],
  ['dapat fee freelance 2jt', 'income', 2000000, 'free', 'cash'],
  ['jual baju bekas 150rb', 'income', 150000, 'jual', 'cash'],
  ['transferan dari klien 3,5jt bca', 'income', 3500000, 'free', 'bca'],
  ['Makanan 25000', 'expense', 25000, 'makan', 'cash'],
];

describe('corpus (no LLM)', () => {
  for (const [text, type, amount, cat, wallet, notes] of CORPUS) {
    test(text, () => {
      const t = one(text);
      expect([t.type, t.amount, t.category?.id ?? null, t.wallet?.id]).toEqual([type, amount, cat, wallet]);
      expect(t.categorySure).toBe(true);
      if (notes) expect(t.notes).toBe(notes);
    });
  }

  test('unknown words are not guessed as sure', () => {
    const t = one('xyzabc 40rb');
    expect(t.categorySure).toBe(false);
    expect(t.amount).toBe(40000);
  });

  test('history teaches: "seblak" was saved as Makanan before', () => {
    const history: HistoryRow[] = [
      { notes: 'Seblak', category_id: 'makan', wallet_id: 'gopay' },
      { notes: 'Seblak Ceker', category_id: 'makan', wallet_id: 'gopay' },
    ];
    const t = one('seblak 18rb', history);
    expect([t.category?.id, t.categorySure, t.wallet?.id]).toEqual(['makan', true, 'gopay']);
  });

  test('history beats synonyms after a correction (kopi → Makanan for this user)', () => {
    const history: HistoryRow[] = Array(3).fill({ notes: 'Kopi', category_id: 'makan', wallet_id: 'cash' });
    expect(one('kopi 15k', history).category?.id).toBe('makan');
  });

  test('date words are stripped from notes', () => {
    const t = one('makan kemarin 25rb');
    expect([t.date, t.notes]).toEqual(['2026-11-05', 'Makan']);
  });
});

describe('transfer', () => {
  const cases: Array<[string, string | null, string | null, number]> = [
    ['tf bca ke gopay 100k', 'bca', 'gopay', 100000],
    ['transfer dari mandiri ke bca 1jt', 'mandiri', 'bca', 1000000],
    ['tarik tunai bca 500rb', 'bca', 'cash', 500000],
    ['topup gopay 100k dari bca', 'bca', 'gopay', 100000],
    ['isi saldo ovo 50rb pakai mandiri', 'mandiri', 'ovo', 50000],
    ['setor tunai 1jt ke bca', 'cash', 'bca', 1000000],
    ['tf ke ovo 50rb', null, 'ovo', 50000],
  ];
  for (const [text, from, to, amount] of cases) {
    test(text, () => {
      const t = one(text);
      expect([t.type, t.wallet?.id ?? null, t.toWallet?.id ?? null, t.amount]).toEqual(['transfer', from, to, amount]);
    });
  }
});

describe('multi', () => {
  test('shared wallet and date', () => {
    const r = parseTransactions('makan 20k, kopi 15k pakai gopay kemarin', { categories: CATS, wallets: WALLETS, history: [], today: TODAY });
    expect(r.map((t) => [t.amount, t.category?.id, t.wallet?.id, t.date])).toEqual([
      [20000, 'makan', 'gopay', '2026-11-05'],
      [15000, 'minum', 'gopay', '2026-11-05'],
    ]);
  });
  test('no amount → nothing parsed', () => {
    expect(parseTransactions('halo bot', { categories: CATS, wallets: WALLETS, history: [], today: TODAY })).toEqual([]);
  });
});

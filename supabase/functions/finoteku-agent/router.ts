/** Decides what a text message is, with rules only (no LLM). */
import { findAmounts } from './nlu/amount.ts';
import { hasWord, isTransferText } from './nlu/match.ts';
import type { Pending } from './data/pending.ts';

export type QueryIntent =
  | 'query_balance' | 'query_summary' | 'query_transactions' | 'query_trend' | 'query_tips' | 'query_data' | 'query_web';

export type Route =
  | { kind: 'confirm' }
  | { kind: 'cancel' }
  | { kind: 'pick'; field: 'category' | 'wallet'; id: string }
  | { kind: 'edit'; text: string }
  | { kind: 'transaction'; text: string }
  | { kind: 'query'; intent: QueryIntent; text: string }
  | { kind: 'help' }
  | { kind: 'unknown'; text: string };

const CONFIRM = ['ya', 'y', 'yes', 'ok', 'oke', 'okay', 'simpan', 'save', 'sip', 'betul', 'benar', 'lanjut', 'confirm_yes'];
const CANCEL = ['tidak', 'gak', 'ga', 'no', 'n', 'batal', 'cancel', 'batalkan', 'hapus', 'confirm_no'];

const Q = {
  balance: ['saldo', 'balance', 'sisa uang', 'uangku', 'dompet', 'rekening'],
  summary: ['ringkasan', 'summary', 'laporan', 'rekap', 'statistik'],
  history: ['riwayat', 'history', 'histori', 'transaksi terakhir', 'mutasi terakhir'],
  trend: ['tren', 'trend', 'perbandingan', 'bandingkan', 'naik', 'turun'],
  tips: ['hemat', 'saran', 'tips', 'rekomendasi', 'boros'],
  data: ['pengeluaran', 'pemasukan', 'kategori', 'total', 'rata', 'tertinggi', 'terbesar', 'terbanyak', 'habis', 'bulan', 'minggu'],
};
const QUESTION = ['?', 'berapa', 'brp', 'apa', 'gimana', 'bagaimana', 'kenapa', 'mengapa', 'kapan', 'mana', 'apakah', 'cek', 'lihat', 'liat', 'tampilkan'];

const has = (t: string, words: string[]) => words.some((w) => t.includes(w));
const EDIT_WORDS = ['jadi', 'ubah', 'ganti', 'nominal', 'nominalnya', 'harusnya', 'seharusnya'];
// "yang kedua", "no 2", "nomor terakhir": points at an item of the pending batch
const ITEM_REF = /\b(?:yang|no|nomor|item)\.?\s*(?:ke-?\s*)?(?:\d\b|pertama|kedua|ketiga|keempat|kelima|terakhir)/;

export function route(raw: string, pending: Pending | null): Route {
  const text = raw.trim();
  const t = text.toLowerCase();

  if (t === '/help' || t === '/start' || t === 'help' || t === 'bantuan' || t === '/bantuan') return { kind: 'help' };
  if (t === '/balance' || t === '/saldo') return { kind: 'query', intent: 'query_balance', text };
  if (t === '/history' || t === '/riwayat') return { kind: 'query', intent: 'query_transactions', text };
  if (t === '/summary' || t === '/ringkasan') return { kind: 'query', intent: 'query_summary', text };

  if (pending) {
    // WhatsApp has no buttons: "2" means the second offered choice
    if (/^\d$/.test(t)) {
      const action = pending.choices[Number(t) - 1];
      if (action) return route(action, pending);
    }
    const pick = t.match(/^pick_(cat|wallet):(\S+)$/);
    if (pick) return { kind: 'pick', field: pick[1] === 'cat' ? 'category' : 'wallet', id: pick[2] };
  }
  if (CONFIRM.includes(t)) return { kind: 'confirm' };
  if (CANCEL.includes(t)) return { kind: 'cancel' };

  const hasAmount = findAmounts(text).length > 0;
  const isQuestion = has(t, QUESTION);
  // "yang kedua 25rb", "nominalnya 30rb" change the pending one instead of starting a new one
  if (pending && hasAmount && (hasWord(t, EDIT_WORDS) || ITEM_REF.test(t))) return { kind: 'edit', text };

  if (hasAmount && !isQuestion) return { kind: 'transaction', text };
  if (hasAmount && isTransferText(t)) return { kind: 'transaction', text };

  if (!hasAmount || isQuestion) {
    if (has(t, Q.tips)) return { kind: 'query', intent: 'query_tips', text };
    if (has(t, Q.trend) && !pending) return { kind: 'query', intent: 'query_trend', text };
    if (has(t, Q.summary)) return { kind: 'query', intent: 'query_summary', text };
    if (has(t, Q.history)) return { kind: 'query', intent: 'query_transactions', text };
    if (has(t, Q.balance) && !has(t, Q.data)) return { kind: 'query', intent: 'query_balance', text };
    if (isQuestion && (has(t, Q.data) || has(t, Q.balance))) return { kind: 'query', intent: 'query_data', text };
  }

  // no amount while something is pending → it is a change to that ("kategorinya minuman", "pakai bca")
  if (pending && !hasAmount) return { kind: 'edit', text };
  if (hasAmount) return { kind: 'transaction', text };
  if (isQuestion) return { kind: 'query', intent: 'query_web', text };
  return { kind: 'unknown', text };
}

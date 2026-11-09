/** Rupiah amounts written the way people type them in chat. */

const SLANG: Record<string, number> = {
  gocap: 50_000,
  goceng: 5_000,
  ceban: 10_000,
  cepek: 100_000,
  gopek: 500,
  seceng: 1_000,
  seribu: 1_000,
  sejuta: 1_000_000,
  setengah_juta: 500_000,
};

const UNIT: Record<string, number> = {
  k: 1e3, rb: 1e3, ribu: 1e3, rbu: 1e3, ebu: 1e3,
  jt: 1e6, juta: 1e6, jeti: 1e6, m: 1e6,
  M: 1e9, miliar: 1e9, milyar: 1e9,
};

// 25rb | 1,5jt | 1.5 jt | 2jt500 | 2jt 500rb | 1.250.000 | 25000 | rp 50.000,00
const AMOUNT_RE =
  /(?:rp\.?\s*)?(\d+(?:[.,]\d+)*)\s*(k|rb|rbu|ribu|ebu|jt|juta|jeti|miliar|milyar|m)?(?![a-z])(?:\s*(\d{1,3})(?:\s*(?:rb|ribu|k))?\b)?/gi;

export interface AmountMatch {
  amount: number;
  /** Exact substring that was read as the amount (to strip it from notes). */
  raw: string;
  index: number;
}

function toNumber(digits: string, hasUnit: boolean): number | null {
  // "1.250.000" / "1,250,000" → thousands groups; "1,5" / "1.5" with a unit → decimal
  if (/^\d{1,3}([.,]\d{3})+$/.test(digits) && !hasUnit) return Number(digits.replace(/[.,]/g, ''));
  if (/^\d{1,3}([.,]\d{3})+,\d{1,2}$/.test(digits)) {
    return Number(digits.replace(/\.(?=\d{3})/g, '').replace(',', '.'));
  }
  const n = Number(digits.replace(',', '.'));
  return Number.isFinite(n) ? n : null;
}

/** All amounts in [text], left to right. */
export function findAmounts(text: string): AmountMatch[] {
  const out: AmountMatch[] = [];
  for (const m of text.matchAll(AMOUNT_RE)) {
    const [full, digits, unitRaw, tail] = m;
    // Uppercase "M" = miliar; lowercase "m" is ambiguous (meter?) so it is no unit
    const unit = unitRaw === 'M' ? 'M' : unitRaw === 'm' ? undefined : unitRaw?.toLowerCase();
    const base = toNumber(digits, !!unit);
    if (base === null) continue;
    let amount = unit ? base * UNIT[unit] : base;
    let raw = full;
    if (tail && unit && UNIT[unit] >= 1e6) {
      amount += Number(tail) * 1e3; // "2jt500" / "2jt 500rb" → 2.500.000
    } else if (tail) {
      // the trailing number belongs to the next words ("25rb 2 porsi"), not to this amount
      const cut = unitRaw ? full.toLowerCase().indexOf(unitRaw.toLowerCase(), digits.length) + unitRaw.length : full.indexOf(digits) + digits.length;
      raw = full.slice(0, cut);
    }
    // Bare small numbers without unit are dates/quantities ("tgl 5", "2 porsi"), not money
    if (!unit && amount < 100) continue;
    out.push({ amount: Math.round(amount), raw: raw.trim(), index: m.index ?? 0 });
  }
  const lower = text.toLowerCase();
  for (const [word, value] of Object.entries(SLANG)) {
    const w = word.replace('_', ' ');
    const i = lower.search(new RegExp(`\\b${w}\\b`));
    if (i >= 0) out.push({ amount: value, raw: text.slice(i, i + w.length), index: i });
  }
  return out.sort((a, b) => a.index - b.index);
}

export function parseAmount(text: string): AmountMatch | null {
  return findAmounts(text)[0] ?? null;
}

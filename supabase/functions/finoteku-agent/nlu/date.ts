/** Dates as plain 'YYYY-MM-DD' strings in the user's time zone (the DB column is `date`). */

export function todayIn(timeZone: string, now: Date = new Date()): string {
  // en-CA formats as YYYY-MM-DD
  return new Intl.DateTimeFormat('en-CA', { timeZone, year: 'numeric', month: '2-digit', day: '2-digit' })
    .format(now);
}

export function addDays(date: string, days: number): string {
  const d = new Date(`${date}T00:00:00Z`);
  d.setUTCDate(d.getUTCDate() + days);
  return d.toISOString().slice(0, 10);
}

/** First and last day of a month (month 1-12). */
export function monthRange(year: number, month: number): { start: string; end: string } {
  const last = new Date(Date.UTC(year, month, 0)).getUTCDate();
  const mm = String(month).padStart(2, '0');
  return { start: `${year}-${mm}-01`, end: `${year}-${mm}-${String(last).padStart(2, '0')}` };
}

const WEEKDAYS: Record<string, number> = {
  minggu: 0, ahad: 0, senin: 1, selasa: 2, rabu: 3, kamis: 4, jumat: 5, "jum'at": 5, sabtu: 6,
};

export interface DateMatch {
  date: string;
  raw: string;
}

/** Reads a date phrase relative to [today]. Returns null when none is mentioned. */
export function parseDate(text: string, today: string): DateMatch | null {
  const t = text.toLowerCase();
  const found = (date: string, m: RegExpMatchArray) => ({ date, raw: m[0].trim() });
  let m: RegExpMatchArray | null;

  if ((m = t.match(/\b(\d+)\s*hari\s*(?:yang\s*)?(?:lalu|lalu|yg lalu|kemarin)\b/))) {
    return found(addDays(today, -Number(m[1])), m);
  }
  if ((m = t.match(/\b(kemarin\s*lusa|kmrn\s*lusa)\b/))) return found(addDays(today, -2), m);
  if ((m = t.match(/\b(kemarin|kemaren|kmrn|kmarin|kmren)\b/))) return found(addDays(today, -1), m);
  if ((m = t.match(/\b(besok|bsk)\b/))) return found(addDays(today, 1), m);
  if ((m = t.match(/\blusa\b/))) return found(addDays(today, 2), m);
  if ((m = t.match(/\b(hari ini|hr ini|td|tadi(?: pagi| siang| sore| malam)?)\b/))) return found(today, m);

  // 05-11-2026, 5/11/26, 5/11
  if ((m = t.match(/\b(\d{1,2})[/-](\d{1,2})(?:[/-](\d{2,4}))?\b/))) {
    const [y0, mo0] = today.split('-').map(Number);
    const day = Number(m[1]), mon = Number(m[2]);
    let year = m[3] ? Number(m[3].length === 2 ? `20${m[3]}` : m[3]) : y0;
    if (!m[3] && (mon > mo0)) year -= 1; // "25/12" in January means last December
    if (day >= 1 && day <= 31 && mon >= 1 && mon <= 12) {
      const max = Number(monthRange(year, mon).end.slice(8));
      return found(`${year}-${String(mon).padStart(2, '0')}-${String(Math.min(day, max)).padStart(2, '0')}`, m);
    }
  }

  // tgl 5 / tanggal 5 → that day this month (last month if still in the future)
  if ((m = t.match(/\b(?:tgl|tanggal)\.?\s*(\d{1,2})\b/))) {
    const [y, mo, d] = today.split('-').map(Number);
    const day = Number(m[1]);
    let year = y, mon = mo;
    if (day > d) { mon -= 1; if (mon === 0) { mon = 12; year -= 1; } }
    const max = Number(monthRange(year, mon).end.slice(8));
    return found(`${year}-${String(mon).padStart(2, '0')}-${String(Math.min(day, max)).padStart(2, '0')}`, m);
  }

  // senin / senin lalu / hari senin → most recent such day (today counts)
  if ((m = t.match(/\b(?:hari\s*)?(minggu|ahad|senin|selasa|rabu|kamis|jumat|jum'at|sabtu)(\s*(?:lalu|kemarin|kmrn))?\b/))) {
    // "minggu lalu" = last week, not Sunday
    if (!(m[1] === 'minggu' && m[2])) {
      const target = WEEKDAYS[m[1]];
      const dow = new Date(`${today}T00:00:00Z`).getUTCDay();
      let back = (dow - target + 7) % 7;
      if (m[2] && back === 0) back = 7;
      return found(addDays(today, -back), m);
    }
  }
  return null;
}

/** * Smart Tokenizer
 * Memecah input text menjadi segment-segment yang meaningful
 *
 * Output: { amount, date, wallet, category, notes }
 * Setiap segment berisi raw text + posisi, akan di-classify kemudian
 */

export interface TokenSegment {
  raw: string; // Raw text dari segment
  type: 'amount' | 'date' | 'wallet' | 'category' | 'notes' | 'unknown';
  confidence: number; // Seberapa yakin ini adalah segment type tersebut
  start: number; // Posisi awal di original text
  end: number; // Posisi akhir
}

export interface TokenizedInput {
  original: string;
  segments: TokenSegment[];
  // Extracted values (setelah tokenization)
  amount?: { value: number; raw: string };
  date?: { offset: number; raw: string };
  notes?: string;
  remainingText: string; // Text yang belum ter-classify
}

// Amount patterns - match full numbers first
const AMOUNT_PATTERN = /(?:rp\.?\s*)?(\d+(?:[.,]\d+)?)\s*(k|rb|ribu|jt|juta)?/gi;

// Date patterns
const DATE_PATTERNS = {
  relative: /(\d+)\s*(hari|minggu|bulan)\s*(?:yang\s*)?lalu/gi,
  keywords: /(kemarin|kemaren|besok|lusa|hari\s*ini)/gi,
  absolute:
    /(\d{1,2})\s*(jan|feb|mar|apr|mei|jun|jul|agu|sep|okt|nov|des)(?:uari|ruari|et|il|i|ni|li|ustus|tember|ober|ember)?(?:\s*\d{4})?/gi,
};

/**
 * Extract amount from text
 */
function extractAmount(
  text: string,
): { value: number; raw: string; start: number; end: number } | null {
  AMOUNT_PATTERN.lastIndex = 0;

  // Find all matches and pick the best one (largest amount, not a date)
  let bestMatch = null;
  let bestAmount = 0;

  let match;
  while ((match = AMOUNT_PATTERN.exec(text)) !== null) {
    const numStr = match[1].replace(/[.,]/g, '');
    let value = parseInt(numStr);
    const suffix = match[2]?.toLowerCase();

    if (suffix === 'k' || suffix === 'rb' || suffix === 'ribu') value *= 1000;
    if (suffix === 'jt' || suffix === 'juta') value *= 1000000;

    // Skip if too small (likely a date) or if it's part of "X hari lalu"
    if (value < 100) continue;

    // Check if this number is followed by "hari" or "minggu" (skip date numbers)
    const afterMatch = text.substring(match.index + match[0].length).trim();
    if (/^(hari|minggu|bulan)/i.test(afterMatch)) continue;

    // Pick largest amount
    if (value > bestAmount) {
      bestAmount = value;
      bestMatch = {
        value,
        raw: match[0],
        start: match.index,
        end: match.index + match[0].length,
      };
    }
  }

  return bestMatch;
}

/**
 * Extract date offset from text
 */
function extractDate(
  text: string,
): { offset: number; raw: string; start: number; end: number } | null {
  const lowerText = text.toLowerCase();

  // Check relative dates first (X hari lalu)
  DATE_PATTERNS.relative.lastIndex = 0;
  const relMatch = DATE_PATTERNS.relative.exec(lowerText);
  if (relMatch) {
    const num = parseInt(relMatch[1]);
    const unit = relMatch[2];
    let offset = -num;
    if (unit === 'minggu') offset *= 7;
    if (unit === 'bulan') offset *= 30;

    return {
      offset,
      raw: relMatch[0],
      start: relMatch.index,
      end: relMatch.index + relMatch[0].length,
    };
  }

  // Check keywords
  DATE_PATTERNS.keywords.lastIndex = 0;
  const kwMatch = DATE_PATTERNS.keywords.exec(lowerText);
  if (kwMatch) {
    const kw = kwMatch[1].replace(/\s+/g, '');
    let offset = 0;
    if (kw === 'kemarin' || kw === 'kemaren') offset = -1;
    else if (kw === 'besok') offset = 1;
    else if (kw === 'lusa') offset = 2;

    return {
      offset,
      raw: kwMatch[0],
      start: kwMatch.index,
      end: kwMatch.index + kwMatch[0].length,
    };
  }

  // Check absolute dates (10 Jan)
  DATE_PATTERNS.absolute.lastIndex = 0;
  const absMatch = DATE_PATTERNS.absolute.exec(lowerText);
  if (absMatch) {
    const day = parseInt(absMatch[1]);
    const monthStr = absMatch[2].substring(0, 3);
    const months = [
      'jan',
      'feb',
      'mar',
      'apr',
      'mei',
      'jun',
      'jul',
      'agu',
      'sep',
      'okt',
      'nov',
      'des',
    ];
    const monthIndex = months.indexOf(monthStr);

    if (monthIndex !== -1 && day >= 1 && day <= 31) {
      const today = new Date();
      const targetDate = new Date(today.getFullYear(), monthIndex, day);

      // If target is in future, assume last year
      if (targetDate > today) {
        targetDate.setFullYear(targetDate.getFullYear() - 1);
      }

      const diffTime = targetDate.getTime() - today.getTime();
      const offset = Math.round(diffTime / (1000 * 60 * 60 * 24));

      return {
        offset,
        raw: absMatch[0],
        start: absMatch.index,
        end: absMatch.index + absMatch[0].length,
      };
    }
  }

  return null;
}

/**
 * Remove segment from text (replace with spaces to preserve positions)
 */
function removeSegment(text: string, start: number, end: number): string {
  return text.substring(0, start) + ' '.repeat(end - start) + text.substring(end);
}

/**
 * Main tokenizer function
 * Segments input into: Amount, Date, Notes (after comma), and remaining text
 */
export function tokenize(text: string): TokenizedInput {
  const result: TokenizedInput = {
    original: text,
    segments: [],
    remainingText: text,
  };

  // 1. NOTES: Everything after comma is notes
  const commaIndex = text.indexOf(',');
  if (commaIndex !== -1) {
    result.notes = text.substring(commaIndex + 1).trim();
    result.segments.push({
      raw: result.notes,
      type: 'notes',
      confidence: 1.0,
      start: commaIndex + 1,
      end: text.length,
    });
    // Work with text before comma
    result.remainingText = text.substring(0, commaIndex);
  }

  // 2. AMOUNT: Extract monetary value
  const amount = extractAmount(result.remainingText);
  if (amount) {
    result.amount = { value: amount.value, raw: amount.raw };
    result.segments.push({
      raw: amount.raw,
      type: 'amount',
      confidence: 0.95,
      start: amount.start,
      end: amount.end,
    });
    result.remainingText = removeSegment(result.remainingText, amount.start, amount.end);
  }

  // 3. DATE: Extract date offset
  const date = extractDate(result.remainingText);
  if (date) {
    result.date = { offset: date.offset, raw: date.raw };
    result.segments.push({
      raw: date.raw,
      type: 'date',
      confidence: 0.9,
      start: date.start,
      end: date.end,
    });
    result.remainingText = removeSegment(result.remainingText, date.start, date.end);
  }

  // 4. Clean remaining text
  result.remainingText = result.remainingText
    .replace(/\brp\b/gi, '')
    .replace(/\s+/g, ' ')
    .trim();

  return result;
}

import { formatCurrency } from '../../_shared/platforms/telegram.ts';
import { UserCategory, UserWallet } from './context.ts';

/**
 * Find best matching category from user's categories
 */
export function findBestCategory(hint: string, categories: UserCategory[], type: 'income' | 'expense'): string | null {
  const lowerHint = hint.toLowerCase();
  const typeCategories = categories.filter((c) => c.type === type);

  const exact = typeCategories.find((c) => c.name.toLowerCase() === lowerHint);
  if (exact) return exact.id;

  const contains = typeCategories.find((c) => c.name.toLowerCase().includes(lowerHint) || lowerHint.includes(c.name.toLowerCase()));
  if (contains) return contains.id;

  return typeCategories[0]?.id || null;
}

/**
 * Find wallet by hint or default to cash/tunai
 */
export function findBestWallet(hint: string | null, wallets: UserWallet[]): string | null {
  if (wallets.length === 0) return null;

  if (hint) {
    const lowerHint = hint.toLowerCase();

    const exact = wallets.find((w) => w.name.toLowerCase() === lowerHint);
    if (exact) return exact.id;

    const contains = wallets.find((w) => w.name.toLowerCase().includes(lowerHint) || lowerHint.includes(w.name.toLowerCase()));
    if (contains) return contains.id;
  }

  // Default: try to find cash/tunai wallet
  const cashWallet = wallets.find((w) => {
    const name = w.name.toLowerCase();
    return name.includes('cash') || name.includes('tunai') || name.includes('uang');
  });
  if (cashWallet) return cashWallet.id;

  return wallets[0]?.id || null;
}

/**
 * Find wallet by name for update flow
 */
export function findWalletByName(name: string, wallets: UserWallet[]): string | null {
  const lowerName = name.toLowerCase();

  const exact = wallets.find((w) => w.name.toLowerCase() === lowerName);
  if (exact) return exact.id;

  const contains = wallets.find((w) => w.name.toLowerCase().includes(lowerName) || lowerName.includes(w.name.toLowerCase()));
  if (contains) return contains.id;

  return null;
}

/**
 * Find category by name for update flow
 */
export function findCategoryByName(name: string, categories: UserCategory[], type: 'income' | 'expense'): string | null {
  const lowerName = name.toLowerCase();
  const typeCategories = categories.filter((c) => c.type === type);

  const exact = typeCategories.find((c) => c.name.toLowerCase() === lowerName);
  if (exact) return exact.id;

  const contains = typeCategories.find((c) => c.name.toLowerCase().includes(lowerName) || lowerName.includes(c.name.toLowerCase()));
  if (contains) return contains.id;

  return null;
}

/**
 * Calculate transaction date from dateOffset
 */
export function calculateTransactionDate(dateOffset: number): string {
  const date = new Date();
  const jakartaOffset = 7 * 60;
  const localOffset = date.getTimezoneOffset();
  date.setMinutes(date.getMinutes() + localOffset + jakartaOffset);
  date.setDate(date.getDate() + dateOffset);
  return date.toISOString().split('T')[0];
}

/**
 * Format date for display in Indonesian
 */
export function formatDateIndonesian(dateStr: string, dateOffset: number): string {
  const date = new Date(dateStr);
  const options: Intl.DateTimeFormatOptions = { day: 'numeric', month: 'short', year: 'numeric' };
  const formatted = date.toLocaleDateString('id-ID', options);

  if (dateOffset === 0) return `${formatted} (hari ini)`;
  if (dateOffset === -1) return `${formatted} (kemarin)`;
  if (dateOffset === 1) return `${formatted} (besok)`;
  if (dateOffset === 2) return `${formatted} (lusa)`;
  return formatted;
}

/**
 * Build confirmation message with transaction details
 */
export function buildConfirmationMessage(type: 'income' | 'expense', amount: number, categoryName: string, walletName: string, dateDisplay: string, notes: string): string {
  const typeEmoji = type === 'income' ? '💰' : '💸';
  const typeText = type === 'income' ? 'Pemasukan' : 'Pengeluaran';

  return `📝 <b>Konfirmasi Transaksi</b>

${typeEmoji} <b>${typeText}</b> ${formatCurrency(amount)}
📁 ${categoryName}
💳 ${walletName}
📅 ${dateDisplay}
📝 ${notes || '-'}

<i>💡 Update: ketik "pakai [wallet]", "[kategori]", atau "kemarin/besok"</i>`;
}

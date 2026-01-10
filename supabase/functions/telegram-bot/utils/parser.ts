import { detectNoteStyle, TransactionExample, UserContext } from './context.ts';
import { ParsedTransaction, parseTransactionWithContext } from '../../_shared/parsers/regex.ts';
import { GeminiUserContext, parseWithGemini } from '../../_shared/parsers/gemini.ts';

/**
 * Parse message using appropriate parser mode with few-shot learning (Gemini only)
 */
export async function parseMessage(
  text: string,
  parserMode: string,
  aiApiKey: string | null,
  serverGeminiKey: string | undefined,
  userContext: UserContext,
  transactionHistory: TransactionExample[] = [],
): Promise<ParsedTransaction | null> {
  const incomeCategories = userContext.categories.filter((c) => c.type === 'income').map((c) =>
    c.name
  );
  const expenseCategories = userContext.categories.filter((c) => c.type === 'expense').map((c) =>
    c.name
  );
  const walletNames = userContext.wallets.map((w) => w.name);

  // Include parent category info for better AI matching
  const incomeCategoriesWithParent = userContext.categories.filter((c) => c.type === 'income').map((
    c,
  ) => ({ name: c.name, parent: c.parentName }));
  const expenseCategoriesWithParent = userContext.categories.filter((c) => c.type === 'expense')
    .map((c) => ({ name: c.name, parent: c.parentName }));

  const context: GeminiUserContext = {
    incomeCategories,
    expenseCategories,
    walletNames,
    incomeCategoriesWithParent,
    expenseCategoriesWithParent,
  };

  // Detect user's note style from history
  const noteStyle = transactionHistory.length > 0 ? detectNoteStyle(transactionHistory) : undefined;

  // AI mode with few-shot learning (server key)
  if (parserMode === 'server_key' && serverGeminiKey) {
    const result = await parseWithGemini(
      text,
      serverGeminiKey,
      context,
      transactionHistory,
      noteStyle,
    );
    if (result) return result;
    // Fallback to regex if Gemini fails
    return parseTransactionWithContext(text, context);
  }

  // AI mode with user's personal API key
  if (parserMode === 'user_key' && aiApiKey) {
    const result = await parseWithGemini(text, aiApiKey, context, transactionHistory, noteStyle);
    if (result) return result;
  }

  // Regex mode - no history needed
  return parseTransactionWithContext(text, context);
}

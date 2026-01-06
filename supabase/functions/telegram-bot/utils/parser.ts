import { UserContext, TransactionExample, detectNoteStyle } from './context.ts';
import { parseTransactionWithContext, ParsedTransaction } from '../../_shared/parsers/regex.ts';
import { parseWithGemini, GeminiUserContext } from '../../_shared/parsers/gemini.ts';
import { parseWithOpenAI } from '../../_shared/parsers/openai.ts';

/**
 * Parse message using appropriate parser mode with few-shot learning
 */
export async function parseMessage(
  text: string,
  parserMode: string,
  aiProvider: string,
  aiApiKey: string | null,
  serverGeminiKey: string | undefined,
  serverOpenAIKey: string | undefined,
  userContext: UserContext,
  transactionHistory: TransactionExample[] = []
): Promise<ParsedTransaction | null> {
  const incomeCategories = userContext.categories.filter((c) => c.type === 'income').map((c) => c.name);
  const expenseCategories = userContext.categories.filter((c) => c.type === 'expense').map((c) => c.name);
  const walletNames = userContext.wallets.map((w) => w.name);

  const context: GeminiUserContext = { incomeCategories, expenseCategories, walletNames };

  // Detect user's note style from history
  const noteStyle = transactionHistory.length > 0 ? detectNoteStyle(transactionHistory) : undefined;

  // AI mode with few-shot learning
  if (parserMode === 'server_key') {
    if (serverGeminiKey) {
      const result = await parseWithGemini(text, serverGeminiKey, context, transactionHistory, noteStyle);
      if (result) return result;
    }
    if (serverOpenAIKey) {
      const result = await parseWithOpenAI(text, serverOpenAIKey, context, transactionHistory, noteStyle);
      if (result) return result;
    }
    // Fallback to regex if server keys fail
    return parseTransactionWithContext(text, context);
  }

  if (parserMode === 'user_key' && aiApiKey) {
    let aiResult: ParsedTransaction | null = null;

    if (aiProvider === 'gemini') {
      aiResult = await parseWithGemini(text, aiApiKey, context, transactionHistory, noteStyle);
    } else if (aiProvider === 'openai') {
      aiResult = await parseWithOpenAI(text, aiApiKey, context, transactionHistory, noteStyle);
    }

    if (aiResult) return aiResult;
  }

  // Regex mode - no history needed
  return parseTransactionWithContext(text, context);
}

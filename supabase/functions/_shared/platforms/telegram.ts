// Telegram platform adapter// Handles incoming messages and sending replies via Telegram API

export interface TelegramMessage {
  message_id: number;
  from: {
    id: number;
    username?: string;
    first_name?: string;
  };
  chat: {
    id: number;
    type: string;
  };
  text?: string;
  date: number;
}

export interface TelegramUpdate {
  update_id: number;
  message?: TelegramMessage;
}

/**
 * Parse incoming Telegram webhook request
 */
export function parseTelegramUpdate(body: unknown): TelegramMessage | null {
  const update = body as TelegramUpdate;

  if (!update?.message?.text || !update?.message?.from?.id) {
    return null;
  }

  return update.message;
}

/**
 * Send a text message reply via Telegram API
 */
export async function sendTelegramMessage(botToken: string, chatId: number, text: string, parseMode: 'HTML' | 'Markdown' = 'HTML'): Promise<boolean> {
  try {
    const response = await fetch(`https://api.telegram.org/bot${botToken}/sendMessage`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        chat_id: chatId,
        text,
        parse_mode: parseMode,
      }),
    });

    if (!response.ok) {
      console.error('Telegram API error:', await response.text());
      return false;
    }

    return true;
  } catch (error) {
    console.error('Error sending Telegram message:', error);
    return false;
  }
}

/**
 * Format currency for display
 */
export function formatCurrency(amount: number): string {
  return new Intl.NumberFormat('id-ID', {
    style: 'currency',
    currency: 'IDR',
    minimumFractionDigits: 0,
    maximumFractionDigits: 0,
  }).format(amount);
}

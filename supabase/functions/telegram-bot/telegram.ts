/**
 * Telegram Platform Adapter
 * Utilitas untuk mengirim/menerima pesan via Telegram API
 */

export interface TelegramPhoto {
  file_id: string;
  file_unique_id: string;
  width: number;
  height: number;
  file_size?: number;
}

export interface TelegramVoice {
  file_id: string;
  file_unique_id: string;
  duration: number;
  mime_type?: string;
  file_size?: number;
}

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
  photo?: TelegramPhoto[];
  voice?: TelegramVoice;
  caption?: string;
  date: number;
}

export interface TelegramCallbackQuery {
  id: string;
  from: {
    id: number;
    username?: string;
  };
  message?: {
    message_id: number;
    chat: {
      id: number;
    };
  };
  data?: string;
}

export interface TelegramUpdate {
  update_id: number;
  message?: TelegramMessage;
  callback_query?: TelegramCallbackQuery;
}

export interface InlineKeyboardButton {
  text: string;
  callback_data: string;
}

/**
 * Parse incoming Telegram webhook request
 */
export function parseTelegramUpdate(body: unknown): TelegramMessage | null {
  const update = body as TelegramUpdate;
  const msg = update?.message;

  if (!msg || !msg.from?.id) {
    return null;
  }

  // Accept if it has text OR photo OR voice OR caption
  if (!msg.text && !msg.photo && !msg.voice && !msg.caption) {
    return null;
  }

  return msg;
}

/**
 * Parse callback query from inline keyboard
 */
export function parseCallbackQuery(body: unknown): TelegramCallbackQuery | null {
  const update = body as TelegramUpdate;

  if (!update?.callback_query?.data || !update?.callback_query?.from?.id) {
    return null;
  }

  return update.callback_query;
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
 * Send a message with inline keyboard buttons
 */
export async function sendTelegramMessageWithButtons(botToken: string, chatId: number, text: string, buttons: InlineKeyboardButton[][], parseMode: 'HTML' | 'Markdown' = 'HTML'): Promise<boolean> {
  try {
    const response = await fetch(`https://api.telegram.org/bot${botToken}/sendMessage`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        chat_id: chatId,
        text,
        parse_mode: parseMode,
        reply_markup: {
          inline_keyboard: buttons,
        },
      }),
    });

    if (!response.ok) {
      console.error('Telegram API error:', await response.text());
      return false;
    }

    return true;
  } catch (error) {
    console.error('Error sending Telegram message with buttons:', error);
    return false;
  }
}

/**
 * Answer callback query (acknowledge button press)
 */
export async function answerCallbackQuery(botToken: string, callbackQueryId: string, text?: string): Promise<boolean> {
  try {
    const response = await fetch(`https://api.telegram.org/bot${botToken}/answerCallbackQuery`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        callback_query_id: callbackQueryId,
        text,
      }),
    });

    return response.ok;
  } catch (error) {
    console.error('Error answering callback query:', error);
    return false;
  }
}

/**
 * Edit message text (for updating after button press)
 */
export async function editTelegramMessage(botToken: string, chatId: number, messageId: number, text: string, parseMode: 'HTML' | 'Markdown' = 'HTML'): Promise<boolean> {
  try {
    const response = await fetch(`https://api.telegram.org/bot${botToken}/editMessageText`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        chat_id: chatId,
        message_id: messageId,
        text,
        parse_mode: parseMode,
      }),
    });

    return response.ok;
  } catch (error) {
    console.error('Error editing Telegram message:', error);
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

/**
 * Get file download URL from Telegram
 */
export async function getTelegramFileUrl(botToken: string, fileId: string): Promise<string | null> {
  try {
    const response = await fetch(`https://api.telegram.org/bot${botToken}/getFile?file_id=${fileId}`);
    const data = await response.json();

    if (!data.ok || !data.result?.file_path) {
      console.error('Error getting file path:', data);
      return null;
    }

    return `https://api.telegram.org/file/bot${botToken}/${data.result.file_path}`;
  } catch (error) {
    console.error('Error in getTelegramFileUrl:', error);
    return null;
  }
}

/**
 * Download file as ArrayBuffer
 */
export async function downloadTelegramFile(url: string): Promise<ArrayBuffer | null> {
  try {
    const response = await fetch(url);
    if (!response.ok) return null;
    return await response.arrayBuffer();
  } catch (error) {
    console.error('Error downloading file:', error);
    return null;
  }
}

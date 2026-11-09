/**
 * WhatsApp Platform Adapter
 * Utilitas untuk mengirim/menerima pesan via GOWA (go-whatsapp-web-multidevice) REST API
 *
 * GOWA Server: https://github.com/aldinokemal/go-whatsapp-web-multidevice
 * Kompatibel dengan GOWA v8+ webhook format:
 *   { "event": "message", "device_id": "628xxx@s.whatsapp.net", "payload": { ... } }
 *
 * Pastikan GOWA server sudah terkonfigurasi dan webhook URL mengarah ke edge function ini.
 */

// ============ GOWA WEBHOOK TYPES (v8 format) ============

/**
 * Top-level wrapper dari GOWA webhook
 * Setiap webhook event dibungkus dalam struktur ini
 */
export interface GowaWebhookEvent {
  event: string; // "message", "message.ack", "message.reaction", dll
  device_id: string; // JID device, e.g. "628xxx@s.whatsapp.net"
  timestamp?: string; // RFC3339
  payload: GowaMessagePayload;
}

/**
 * Payload pesan dari GOWA webhook (event = "message")
 */
export interface GowaMessagePayload {
  id: string; // Message ID
  chat_id: string; // Chat JID (e.g. "628987654321@s.whatsapp.net")
  from: string; // Sender JID (e.g. "628123456789@s.whatsapp.net")
  from_lid?: string; // Linked ID
  from_name: string; // Display name (pushname)
  timestamp: string; // RFC3339
  is_from_me: boolean;
  body?: string; // Isi pesan teks
  // Media: bisa string (path) atau object (path+caption / url+caption)
  image?: string | { path?: string; url?: string; caption?: string };
  audio?: string; // Path ke file audio
  video?: string | { path?: string; url?: string; caption?: string };
  document?: { path?: string; url?: string; filename?: string; caption?: string };
  sticker?: string;
  // Reply context
  replied_to_id?: string;
  quoted_body?: string;
  // Flags
  view_once?: boolean;
  forwarded?: boolean;
}

/**
 * Parsed message hasil normalisasi dari GOWA webhook
 */
export interface ParsedGowaMessage {
  phone: string; // Nomor pengirim (tanpa @s.whatsapp.net)
  chatId: string; // Chat JID lengkap (untuk kirim balik)
  messageId: string;
  fromName: string;
  body: string; // Isi teks pesan / caption
  type: 'text' | 'image' | 'audio' | 'document' | 'video' | 'sticker';
  mediaPath?: string; // Path file di GOWA server (jika auto-download enabled)
  mediaUrl?: string; // URL file (jika auto-download disabled)
  isFromMe: boolean;
}

// ============ PARSER ============

/**
 * Normalisasi JID ke nomor telepon
 * "628123456789@s.whatsapp.net" → "628123456789"
 */
export function normalizePhone(jid: string): string {
  return jid.replace(/@s\.whatsapp\.net$/, '').replace(/@g\.us$/, '');
}

/**
 * Cek apakah pesan dari grup
 */
export function isGroupMessage(chatId: string): boolean {
  return chatId.includes('@g.us');
}

/**
 * Parse incoming GOWA v8 webhook event
 * Hanya memproses event "message" dari private chat
 */
export function parseGowaWebhook(body: unknown): ParsedGowaMessage | null {
  const event = body as GowaWebhookEvent;
  if (!event || !event.event || !event.payload) return null;

  // Hanya proses event "message"
  if (event.event !== 'message') return null;

  const p = event.payload;
  if (!p.from || !p.chat_id) return null;

  // Skip pesan dari diri sendiri
  if (p.is_from_me) return null;

  // Skip pesan grup
  if (isGroupMessage(p.chat_id)) return null;

  // Deteksi tipe dan extract media info
  const { type, body: msgBody, mediaPath, mediaUrl } = extractContent(p);

  return {
    phone: normalizePhone(p.from),
    chatId: p.chat_id,
    messageId: p.id,
    fromName: p.from_name || '',
    body: msgBody,
    type,
    mediaPath,
    mediaUrl,
    isFromMe: p.is_from_me,
  };
}

function extractContent(p: GowaMessagePayload): {
  type: ParsedGowaMessage['type'];
  body: string;
  mediaPath?: string;
  mediaUrl?: string;
} {
  // Image
  if (p.image) {
    if (typeof p.image === 'string') {
      return { type: 'image', body: p.body || '', mediaPath: p.image };
    }
    return {
      type: 'image',
      body: p.image.caption || p.body || '',
      mediaPath: p.image.path,
      mediaUrl: p.image.url,
    };
  }

  // Audio
  if (p.audio) {
    return { type: 'audio', body: p.body || '', mediaPath: p.audio };
  }

  // Video
  if (p.video) {
    if (typeof p.video === 'string') {
      return { type: 'video', body: p.body || '', mediaPath: p.video };
    }
    return {
      type: 'video',
      body: p.video.caption || p.body || '',
      mediaPath: p.video.path,
      mediaUrl: p.video.url,
    };
  }

  // Document
  if (p.document) {
    return {
      type: 'document',
      body: p.document.caption || p.body || '',
      mediaPath: p.document.path,
      mediaUrl: p.document.url,
    };
  }

  // Sticker
  if (p.sticker) {
    return { type: 'sticker', body: '', mediaPath: p.sticker };
  }

  // Text
  return { type: 'text', body: p.body || '' };
}

// ============ GOWA REST API (Sending Messages) ============

/**
 * Kirim pesan teks via GOWA REST API
 * Endpoint: POST /send/message
 * GOWA v8: requires X-Device-Id header for multi-device
 */
export async function sendWhatsAppMessage(
  gowaUrl: string,
  phone: string,
  message: string,
  deviceId?: string,
  basicAuth?: string,
): Promise<boolean> {
  try {
    const headers: Record<string, string> = { 'Content-Type': 'application/json' };
    if (deviceId) headers['X-Device-Id'] = deviceId;
    if (basicAuth) headers['Authorization'] = `Basic ${btoa(basicAuth)}`;

    const response = await fetch(`${gowaUrl}/send/message`, {
      method: 'POST',
      headers,
      body: JSON.stringify({ phone, message }),
    });

    if (!response.ok) {
      console.error('GOWA send error:', await response.text());
      return false;
    }

    return true;
  } catch (error) {
    console.error('Error sending WhatsApp message:', error);
    return false;
  }
}

/**
 * Kirim pesan dengan tombol pilihan
 * WhatsApp tidak support inline buttons seperti Telegram,
 * jadi kita kirim sebagai numbered list
 */
export async function sendWhatsAppMessageWithButtons(
  gowaUrl: string,
  phone: string,
  message: string,
  buttons: Array<{ text: string; id: string }>,
  deviceId?: string,
  basicAuth?: string,
): Promise<boolean> {
  const buttonText = buttons
    .map((b, i) => `${i + 1}. ${b.text}`)
    .join('\n');
  const fullMessage = `${message}\n\n${buttonText}\n\n_Balas dengan angka untuk memilih._`;

  return await sendWhatsAppMessage(gowaUrl, phone, fullMessage, deviceId, basicAuth);
}

/**
 * Download media dari GOWA server (statics path)
 * Jika auto-download enabled, media tersimpan di GOWA server sebagai path relatif
 * URL lengkap: {GOWA_URL}/{mediaPath}
 */
export async function downloadGowaMedia(
  gowaUrl: string,
  mediaPath: string,
  deviceId?: string,
  basicAuth?: string,
): Promise<ArrayBuffer | null> {
  try {
    // mediaPath bisa berupa path relatif (statics/media/...) atau URL lengkap
    const url = mediaPath.startsWith('http') ? mediaPath : `${gowaUrl}/${mediaPath}`;
    const headers: Record<string, string> = {};
    if (deviceId) headers['X-Device-Id'] = deviceId;
    if (basicAuth) headers['Authorization'] = `Basic ${btoa(basicAuth)}`;

    const response = await fetch(url, { headers });
    if (!response.ok) return null;
    return await response.arrayBuffer();
  } catch (error) {
    console.error('Error downloading media from GOWA:', error);
    return null;
  }
}

/**
 * Konversi format HTML (dari agent response) ke plain text WhatsApp
 * WhatsApp menggunakan format: *bold*, _italic_, ~strikethrough~, ```monospace```
 */
export function htmlToWhatsApp(html: string): string {
  return html
    .replace(/<b>(.*?)<\/b>/gi, '*$1*')
    .replace(/<strong>(.*?)<\/strong>/gi, '*$1*')
    .replace(/<i>(.*?)<\/i>/gi, '_$1_')
    .replace(/<em>(.*?)<\/em>/gi, '_$1_')
    .replace(/<code>(.*?)<\/code>/gi, '```$1```')
    .replace(/<pre>(.*?)<\/pre>/gi, '```$1```')
    .replace(/<s>(.*?)<\/s>/gi, '~$1~')
    .replace(/<br\s*\/?>/gi, '\n')
    .replace(/<[^>]*>/g, ''); // Strip remaining HTML tags
}

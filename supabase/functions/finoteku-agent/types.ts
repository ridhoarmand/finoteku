/**
 * Core Agent Types
 * Definisi interface untuk sistem AI Agent
 */

// ============ TIPE INPUT/OUTPUT ============

export type MessageType = 'text' | 'image' | 'voice';
export type Platform = 'telegram' | 'discord' | 'whatsapp' | 'flutter' | 'api';

/**
 * Input dari user ke agent
 */
export interface AgentInput {
  type: MessageType;
  content: string; // Text content atau base64 untuk media
  caption?: string; // Caption jika tipe image/voice
  mimeType?: string; // Untuk media (image/jpeg, audio/ogg, dll)
  userId: string;
  conversationId: string;
  platform: Platform;
  metadata?: Record<string, unknown>;
}

/**
 * Response dari agent ke user
 */
export interface AgentResponse {
  type: 'message' | 'confirmation' | 'error';
  content: string;
  data?: unknown;
  actions?: ActionButton[];
}

/**
 * Tombol aksi untuk inline keyboard
 */
export interface ActionButton {
  text: string;
  action: string; // Callback data
}

// ============ TIPE TOOL ============

/**
 * Hasil eksekusi tool
 */
export interface ToolResult {
  success: boolean;
  data?: unknown;
  message: string;
  error?: string;
}

// ============ CONFIG TYPES ============

/**
 * Konfigurasi agent
 */
export interface AgentConfig {
  supabase: unknown; // SupabaseClient
  defaultProvider?: string;
}

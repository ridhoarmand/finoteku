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

// ============ TIPE REASONING ============

/**
 * Intent yang terdeteksi dari input user
 */
export type Intent =
  | 'transaction' // Input transaksi baru
  | 'query_balance' // Tanya saldo
  | 'query_summary' // Tanya ringkasan
  | 'query_transactions' // Tanya riwayat
  | 'query_trend' // Tanya tren
  | 'query_tips' // Minta tips hemat
  | 'query_data' // Pertanyaan tentang data keuangan user (NEW)
  | 'query_web' // Pertanyaan umum yang perlu cari di web (NEW)
  | 'update_pending' // Update transaksi pending
  | 'confirm' // Konfirmasi transaksi
  | 'cancel' // Batalkan transaksi
  | 'help' // Minta bantuan
  | 'unknown'; // Tidak terdeteksi

/**
 * Rencana aksi agent
 */
export interface AgentPlan {
  intent: Intent;
  tool: string;
  params: Record<string, unknown>;
  confidence: number;
}

/**
 * Hasil evaluasi eksekusi tool
 */
export interface AgentEvaluation {
  success: boolean;
  needsFollowUp: boolean;
  message?: string;
}

// ============ TIPE TOOL ============

export interface ToolInput {
  [key: string]: unknown;
}

/**
 * Hasil eksekusi tool
 */
export interface ToolResult {
  success: boolean;
  data?: unknown;
  message: string;
  error?: string;
}

// ============ USER CONTEXT ============

/**
 * Kategori milik user
 */
export interface UserCategory {
  id: string;
  name: string;
  type: 'income' | 'expense';
  parentName: string | null;
  parent_name?: string | null; // Support DB field naming
}

/**
 * Wallet milik user
 */
export interface UserWallet {
  id: string;
  name: string;
}

/**
 * Context user untuk parsing dan query
 */
export interface UserContext {
  userId: string;
  categories: UserCategory[];
  wallets: UserWallet[];
  parserMode: 'regex' | 'server_key' | 'user_key';
  aiApiKey?: string | null;
}

// ============ PARSED TRANSACTION ============

/**
 * Hasil parsing transaksi
 */
export interface ParsedTransaction {
  type: 'income' | 'expense' | 'transfer';
  amount: number;
  categoryHint: string;
  walletHint: string | null;
  toWalletHint?: string | null;
  notes: string;
  confidence: number;
  dateOffset: number; // 0 = hari ini, -1 = kemarin, +1 = besok
  originalInput?: string; // Untuk preference learning
}

// ============ CONFIG TYPES ============

/**
 * Konfigurasi agent
 */
export interface AgentConfig {
  supabase: unknown; // SupabaseClient
  defaultProvider?: string;
}

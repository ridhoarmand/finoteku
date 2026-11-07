/**
 * AI Provider Base Interface
 * Interface abstrak untuk berbagai AI provider (Gemini, OpenAI, dll)
 */

export interface GenerateOptions {
  temperature?: number;
  maxTokens?: number;
  systemPrompt?: string;
  /** JSON schema for the answer (Gemini `response_schema`); keeps output short and parseable. */
  schema?: Record<string, unknown>;
}

export interface AIProvider {
  readonly name: string;

  /**
   * Generate response teks dari prompt
   */
  generateText(prompt: string, options?: GenerateOptions): Promise<string>;

  /**
   * Generate response JSON terstruktur
   */
  generateJSON<T>(prompt: string, options?: GenerateOptions): Promise<T>;

  /**
   * Parse image dan ekstrak informasi
   */
  parseImage(base64Image: string, prompt: string): Promise<string>;

  /**
   * Transkripsi audio ke teks
   */
  transcribeAudio(base64Audio: string, mimeType: string): Promise<string>;
}

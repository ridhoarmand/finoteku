/**
 * AI Provider Base Interface
 * Defined interface options and signatures for 9Router provider
 */

export interface GenerateOptions {
  temperature?: number;
  maxTokens?: number;
  systemPrompt?: string;
}

export interface AIProvider {
  readonly name: string;

  /**
   * Generate text response from prompt
   */
  generateText(prompt: string, options?: GenerateOptions): Promise<string>;

  /**
   * Generate structured JSON response from prompt
   */
  generateJSON<T>(prompt: string, options?: GenerateOptions): Promise<T>;

  /**
   * Parse image using Vision OCR
   */
  parseImage(base64Image: string, prompt: string): Promise<string>;

  /**
   * Transcribe audio to text (STT)
   */
  transcribeAudio(base64Audio: string, mimeType: string): Promise<string>;
}

/**
 * AI Provider Base Interface
 * Interface abstrak untuk berbagai AI provider (Gemini, OpenAI, dll)
 */

export interface GenerateOptions {
  temperature?: number;
  maxTokens?: number;
  systemPrompt?: string;
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

/**
 * AI Provider Registry
 * Mengelola multiple AI provider dan memungkinkan switching
 */
export class AIProviderRegistry {
  private providers: Map<string, AIProvider> = new Map();
  private defaultProviderName: string = 'gemini';

  register(provider: AIProvider): void {
    this.providers.set(provider.name, provider);
    console.log(`AI provider terdaftar: ${provider.name}`);
  }

  get(name?: string): AIProvider {
    const providerName = name || this.defaultProviderName;
    const provider = this.providers.get(providerName);

    if (!provider) {
      throw new Error(`AI Provider tidak ditemukan: ${providerName}`);
    }

    return provider;
  }

  setDefault(name: string): void {
    if (!this.providers.has(name)) {
      throw new Error(`Tidak dapat set default: Provider ${name} belum terdaftar`);
    }
    this.defaultProviderName = name;
  }

  list(): string[] {
    return Array.from(this.providers.keys());
  }
}

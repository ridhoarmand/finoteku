/**
 * Dynamic AI Provider
 * Memungkinkan pengalihan AI provider dan API key secara dinamis
 * berdasarkan preferensi user (UserContext)
 */

import type { AIProvider, GenerateOptions } from './base.ts';
import { GeminiProvider } from './gemini.ts';
import { OpenRouterProvider } from './openrouter.ts';
import type { UserContext } from '../data/users.ts';

export class DynamicAIProvider implements AIProvider {
  readonly name = 'dynamic';
  private currentUserContext?: UserContext;

  constructor(
    private defaultProvider: AIProvider,
  ) {}

  /**
   * Set context user untuk request saat ini
   */
  setUserContext(context?: UserContext): void {
    this.currentUserContext = context;
  }

  /**
   * Mendapatkan provider yang sesuai berdasarkan UserContext saat ini
   */
  private getProvider(): AIProvider {
    if (
      this.currentUserContext &&
      this.currentUserContext.parserMode === 'user_key' &&
      this.currentUserContext.aiApiKey
    ) {
      const providerType = this.currentUserContext.aiProvider || 'gemini';
      const apiKey = this.currentUserContext.aiApiKey;

      console.log(`[DynamicAIProvider] Merutekan ke ${providerType} dengan API Key user`);

      if (providerType === 'openrouter') {
        return new OpenRouterProvider(apiKey);
      } else if (providerType === 'gemini') {
        return new GeminiProvider(apiKey);
      }
    }

    console.log(
      `[DynamicAIProvider] Menggunakan server default provider (${this.defaultProvider.name})`,
    );
    return this.defaultProvider;
  }

  async generateText(prompt: string, options?: GenerateOptions): Promise<string> {
    return await this.getProvider().generateText(prompt, options);
  }

  async generateJSON<T>(prompt: string, options?: GenerateOptions): Promise<T> {
    return await this.getProvider().generateJSON<T>(prompt, options);
  }

  async parseImage(base64Image: string, prompt: string): Promise<string> {
    return await this.getProvider().parseImage(base64Image, prompt);
  }

  async transcribeAudio(base64Audio: string, mimeType: string): Promise<string> {
    return await this.getProvider().transcribeAudio(base64Audio, mimeType);
  }
}

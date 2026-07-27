/**
 * OpenRouter AI Provider
 * Implementasi AIProvider menggunakan OpenRouter API
 * Kompatibel dengan format OpenAI API
 */

import type { AIProvider, GenerateOptions } from './base.ts';

const OPENROUTER_API_URL = 'https://openrouter.ai/api/v1/chat/completions';
const DEFAULT_MODEL = 'google/gemini-2.5-flash:free';

export class OpenRouterProvider implements AIProvider {
  readonly name = 'openrouter';
  private apiKey: string;
  private model: string;

  constructor(apiKey: string, model: string = DEFAULT_MODEL) {
    this.apiKey = apiKey;
    this.model = model;
  }

  private getHeaders() {
    return {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${this.apiKey}`,
      'HTTP-Referer': 'https://finoteku.com',
      'X-Title': 'Finoteku',
    };
  }

  async generateText(prompt: string, options?: GenerateOptions): Promise<string> {
    console.log(`[OpenRouter] generateText using model: ${this.model}`);

    // deno-lint-ignore no-explicit-any
    const messages: any[] = [];
    if (options?.systemPrompt) {
      messages.push({ role: 'system', content: options.systemPrompt });
    }
    messages.push({ role: 'user', content: prompt });

    const response = await fetch(OPENROUTER_API_URL, {
      method: 'POST',
      headers: this.getHeaders(),
      body: JSON.stringify({
        model: this.model,
        messages,
        temperature: options?.temperature ?? 0.1,
        max_tokens: options?.maxTokens ?? 512,
      }),
    });

    const data = await response.json();
    if (!response.ok) {
      console.error('[OpenRouter Error]', JSON.stringify(data, null, 2));
      throw new Error(`OpenRouter Error: ${data.error?.message || response.statusText}`);
    }

    return data.choices?.[0]?.message?.content || '';
  }

  async generateJSON<T>(prompt: string, options?: GenerateOptions): Promise<T> {
    console.log(`[OpenRouter] generateJSON using model: ${this.model}`);

    // deno-lint-ignore no-explicit-any
    const messages: any[] = [];
    if (options?.systemPrompt) {
      messages.push({ role: 'system', content: options.systemPrompt });
    }
    messages.push({ role: 'user', content: prompt });

    const response = await fetch(OPENROUTER_API_URL, {
      method: 'POST',
      headers: this.getHeaders(),
      body: JSON.stringify({
        model: this.model,
        messages,
        temperature: options?.temperature ?? 0.1,
        max_tokens: options?.maxTokens ?? 256,
        response_format: { type: 'json_object' },
      }),
    });

    const data = await response.json();
    if (!response.ok) {
      console.error('[OpenRouter JSON Error]', JSON.stringify(data, null, 2));
      throw new Error(`OpenRouter Error: ${data.error?.message || response.statusText}`);
    }

    const rawText = data.choices?.[0]?.message?.content || '';
    const jsonStr = rawText.replace(/```json\n?|\n?```/g, '').trim();
    return JSON.parse(jsonStr) as T;
  }

  async parseImage(base64Image: string, prompt: string): Promise<string> {
    console.log(`[OpenRouter] parseImage using model: ${this.model}`);

    const response = await fetch(OPENROUTER_API_URL, {
      method: 'POST',
      headers: this.getHeaders(),
      body: JSON.stringify({
        model: this.model,
        messages: [
          {
            role: 'user',
            content: [
              { type: 'text', text: prompt },
              {
                type: 'image_url',
                image_url: {
                  url: `data:image/jpeg;base64,${base64Image}`,
                },
              },
            ],
          },
        ],
        temperature: 0.1,
        max_tokens: 256,
        response_format: { type: 'json_object' },
      }),
    });

    const data = await response.json();
    if (!response.ok) {
      console.error('[OpenRouter Image Error]', JSON.stringify(data, null, 2));
      throw new Error(`OpenRouter Error: ${data.error?.message || response.statusText}`);
    }

    return data.choices?.[0]?.message?.content || '';
  }

  transcribeAudio(_base64Audio: string, _mimeType: string): Promise<string> {
    return Promise.reject(
      new Error('Audio transcription is not supported by OpenRouter provider.'),
    );
  }
}

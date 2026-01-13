/**
 * Gemini AI Provider
 * Implementasi AIProvider menggunakan Google Gemini API
 */

import type { AIProvider, GenerateOptions } from './base.ts';

const GEMINI_API_URL =
  'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent';

export class GeminiProvider implements AIProvider {
  readonly name = 'gemini';
  private apiKey: string;

  constructor(apiKey: string) {
    this.apiKey = apiKey;
  }

  /**
   * Log penggunaan token untuk monitoring
   */
  // deno-lint-ignore no-explicit-any
  private logTokenUsage(data: any, caller: string): void {
    if (data?.usageMetadata) {
      const { promptTokenCount, candidatesTokenCount, totalTokenCount } = data.usageMetadata;
      console.log(
        `[Gemini ${caller}] Token - Prompt: ${promptTokenCount}, Response: ${candidatesTokenCount}, Total: ${totalTokenCount}`,
      );
    }
  }

  /**
   * Generate teks dari prompt
   */
  async generateText(prompt: string, options?: GenerateOptions): Promise<string> {
    const response = await fetch(`${GEMINI_API_URL}?key=${this.apiKey}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        contents: [
          {
            parts: [
              ...(options?.systemPrompt ? [{ text: options.systemPrompt }] : []),
              {
                text: prompt,
              },
            ],
          },
        ],
        generationConfig: {
          temperature: options?.temperature ?? 0.1,
        },
      }),
    });

    const data = await response.json();
    this.logTokenUsage(data, 'Text');

    if (!data.candidates || data.candidates.length === 0) {
      throw new Error('Tidak ada response dari Gemini');
    }

    return data.candidates[0].content.parts[0].text;
  }

  /**
   * Generate JSON terstruktur dari prompt
   */
  async generateJSON<T>(prompt: string, options?: GenerateOptions): Promise<T> {
    const response = await fetch(`${GEMINI_API_URL}?key=${this.apiKey}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        contents: [
          {
            parts: [
              ...(options?.systemPrompt ? [{ text: options.systemPrompt }] : []),
              {
                text: prompt,
              },
            ],
          },
        ],
        generationConfig: {
          temperature: options?.temperature ?? 0.1,
          response_mime_type: 'application/json',
        },
      }),
    });

    const data = await response.json();
    this.logTokenUsage(data, 'JSON');

    if (!data.candidates || data.candidates.length === 0) {
      throw new Error('Tidak ada response dari Gemini');
    }

    const rawText = data.candidates[0].content.parts[0].text;
    const jsonStr = rawText.replace(/```json\n?|\n?```/g, '').trim();
    return JSON.parse(jsonStr) as T;
  }

  /**
   * Parse gambar dan ekstrak informasi (OCR struk)
   */
  async parseImage(base64Image: string, prompt: string): Promise<string> {
    console.log('parseImage dimulai, panjang gambar:', base64Image.length);

    const response = await fetch(`${GEMINI_API_URL}?key=${this.apiKey}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        contents: [
          {
            parts: [
              { text: prompt },
              {
                inline_data: {
                  mime_type: 'image/jpeg',
                  data: base64Image,
                },
              },
            ],
          },
        ],
        generationConfig: {
          temperature: 0.1,
          response_mime_type: 'application/json',
        },
      }),
    });

    if (!response.ok) {
      const error = await response.text();
      console.error('Gemini Vision error:', error);
      throw new Error('Vision API gagal');
    }

    const data = await response.json();
    this.logTokenUsage(data, 'Vision');

    if (!data.candidates || data.candidates.length === 0) {
      throw new Error('Tidak ada response dari Vision API');
    }

    return data.candidates[0].content.parts[0].text;
  }

  /**
   * Transkripsi audio ke teks (Speech-to-Text)
   */
  async transcribeAudio(base64Audio: string, mimeType: string): Promise<string> {
    console.log('transcribeAudio dimulai, panjang audio:', base64Audio.length);

    const response = await fetch(`${GEMINI_API_URL}?key=${this.apiKey}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        contents: [
          {
            parts: [
              {
                text: `Transkripsi audio berikut ke teks Bahasa Indonesia. 
Output HANYA teks hasil transkripsi, tanpa penjelasan tambahan.
Jika ada angka nominal uang, tulis dalam format yang jelas (contoh: "lima puluh ribu" -> "50000" atau "50k").`,
              },
              {
                inline_data: {
                  mime_type: mimeType,
                  data: base64Audio,
                },
              },
            ],
          },
        ],
        generationConfig: {
          temperature: 0.1,
        },
      }),
    });

    if (!response.ok) {
      const error = await response.text();
      console.error('Gemini STT error:', error);
      throw new Error('STT API gagal');
    }

    const data = await response.json();
    this.logTokenUsage(data, 'STT');

    if (!data.candidates || data.candidates.length === 0) {
      throw new Error('Tidak ada response dari STT API');
    }

    return data.candidates[0].content.parts[0].text.trim();
  }
}

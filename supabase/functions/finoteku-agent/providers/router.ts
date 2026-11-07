/**
 * 9Router / OpenAI-Compatible AI Provider
 * Implementasi AIProvider menggunakan 9Router API (https://9router.idho.eu.org/v1)
 * Supports standard JSON responses & SSE streaming chunks (data: {...})
 */

import type { AIProvider, GenerateOptions } from './base.ts';

export class RouterAIProvider implements AIProvider {
  readonly name = '9router';
  private baseUrl: string;
  private apiKey: string;
  private model: string;

  constructor(
    baseUrl: string,
    apiKey: string, // from the AI_API_KEY secret; never hard-code it here
    model: string = 'my-combo',
  ) {
    this.baseUrl = baseUrl.replace(/\/$/, '');
    this.apiKey = apiKey;
    this.model = model;
  }

  /**
   * Universal parser for 9router: Handles single JSON responses, reasoning content,
   * and SSE stream chunks (data: {"choices": [{"delta": {"content": "..."}}]})
   */
  private parseResponseText(text: string): string {
    // 1. Check if response is SSE Stream (multiple lines starting with 'data: ')
    if (text.includes('data: {') || text.includes('data:')) {
      const lines = text.split('\n');
      let combinedContent = '';

      for (const line of lines) {
        const trimmed = line.trim();
        if (!trimmed || trimmed.startsWith('data: [DONE]')) continue;
        if (trimmed.startsWith('data: ')) {
          try {
            const chunk = JSON.parse(trimmed.substring(6));
            const deltaContent =
              chunk.choices?.[0]?.delta?.content ||
              chunk.choices?.[0]?.message?.content ||
              chunk.choices?.[0]?.delta?.reasoning_content;
            if (deltaContent) {
              combinedContent += deltaContent;
            }
          } catch {
            // Ignore malformed chunk lines
          }
        }
      }

      if (combinedContent.trim().length > 0) {
        return combinedContent.trim();
      }
    }

    // 2. Standard single JSON response parsing
    try {
      const firstBrace = text.indexOf('{');
      const lastBrace = text.lastIndexOf('}');
      let jsonText = text.trim();
      if (firstBrace !== -1 && lastBrace > firstBrace) {
        jsonText = text.substring(firstBrace, lastBrace + 1);
      }
      const data = JSON.parse(jsonText);
      const message = data.choices?.[0]?.message;
      const content = message?.content || message?.reasoning_content || data.choices?.[0]?.text;
      if (content !== undefined && content !== null) {
        return String(content).trim();
      }
    } catch (e) {
      console.warn('[9Router] Non-JSON response text:', text.substring(0, 100));
    }

    return text.trim();
  }

  /**
   * Execute POST request to OpenAI chat completion endpoint
   */
  private async chatCompletions(body: Record<string, unknown>): Promise<string> {
    const url = `${this.baseUrl}/chat/completions`;
    const res = await fetch(url, {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${this.apiKey}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        model: this.model,
        ...body,
      }),
    });

    const rawText = await res.text();

    if (!res.ok) {
      console.error(`[9Router] API Error (${res.status}):`, rawText);
      throw new Error(`9Router API Error (${res.status}): ${rawText}`);
    }

    return this.parseResponseText(rawText);
  }

  /**
   * Generate text response from prompt
   */
  async generateText(prompt: string, options?: GenerateOptions): Promise<string> {
    const messages: Array<{ role: string; content: string }> = [];
    if (options?.systemPrompt) {
      messages.push({ role: 'system', content: options.systemPrompt });
    }
    messages.push({ role: 'user', content: prompt });

    const content = await this.chatCompletions({
      messages,
      temperature: options?.temperature ?? 0.1,
      max_tokens: options?.maxTokens ?? 512,
    });

    if (!content) {
      throw new Error('Tidak ada respons dari 9Router provider');
    }
    return content;
  }

  /**
   * Generate structured JSON from prompt
   */
  async generateJSON<T>(prompt: string, options?: GenerateOptions): Promise<T> {
    const messages: Array<{ role: string; content: string }> = [];
    if (options?.systemPrompt) {
      messages.push({ role: 'system', content: options.systemPrompt });
    }
    messages.push({ role: 'user', content: prompt });

    const content = await this.chatCompletions({
      messages,
      temperature: options?.temperature ?? 0.1,
      max_tokens: options?.maxTokens ?? 1024,
      response_format: { type: 'json_object' },
    });

    if (!content) {
      throw new Error('Tidak ada respons JSON dari 9Router provider');
    }

    return cleanAndFixJson<T>(content);
  }

  /**
   * Parse image using Vision capability (OCR struk/nota)
   */
  async parseImage(base64Image: string, prompt: string): Promise<string> {
    const imageUrl = base64Image.startsWith('data:')
      ? base64Image
      : `data:image/jpeg;base64,${base64Image}`;

    const messages = [
      {
        role: 'user',
        content: [
          { type: 'text', text: prompt },
          {
            type: 'image_url',
            image_url: { url: imageUrl },
          },
        ],
      },
    ];

    const content = await this.chatCompletions({
      messages,
      temperature: 0.1,
      max_tokens: 1024,
    });

    if (!content || content.toLowerCase().includes('tanpa dukungan vision') || content.toLowerCase().includes('tidak bisa diproses')) {
      throw new Error('Model AI Server (9Router) saat ini belum mendukung analisis gambar (vision).');
    }
    return content;
  }

  /**
   * Transcribe audio to text
   */
  async transcribeAudio(base64Audio: string, mimeType: string): Promise<string> {
    try {
      const binaryString = atob(base64Audio);
      const bytes = new Uint8Array(binaryString.length);
      for (let i = 0; i < binaryString.length; i++) {
        bytes[i] = binaryString.charCodeAt(i);
      }
      const formData = new FormData();
      const ext = mimeType.includes('mp3') ? 'mp3' : mimeType.includes('wav') ? 'wav' : 'm4a';
      const file = new File([bytes], `audio.${ext}`, { type: mimeType });
      formData.append('file', file);
      formData.append('model', this.model);

      const res = await fetch(`${this.baseUrl}/audio/transcriptions`, {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${this.apiKey}`,
        },
        body: formData,
      });

      if (res.ok) {
        const rawText = await res.text();
        const content = this.parseResponseText(rawText);
        if (content) return content.trim();
      }
    } catch (err) {
      console.warn('[9Router] Audio transcription endpoint error:', err);
    }

    return this.generateText(
      'Transkripsikan pesan suara pengguna untuk pencatatan transaksi.'
    );
  }
}

/**
 * Robust JSON Sanitizer & Auto-Repairer
 * Fixes common JSON anomalies outputted by LLMs:
 * 1. Strips markdown fences (```json ... ```)
 * 2. Extracts substring between first '{' and last '}'
 * 3. Removes trailing commas before closing braces/brackets
 * 4. Fixes single quotes to double quotes for keys/strings if needed
 * 5. Removes single-line or multi-line JS comments
 * 6. Auto-closes unclosed quotes/braces if truncated
 */
export function cleanAndFixJson<T>(content: string): T {
  let jsonString = content;

  // Extract JSON object if CoT or preamble surrounds it
  const firstBrace = jsonString.indexOf('{');
  const lastBrace = jsonString.lastIndexOf('}');

  if (firstBrace !== -1 && lastBrace > firstBrace) {
    jsonString = jsonString.substring(firstBrace, lastBrace + 1);
  } else if (firstBrace !== -1) {
    jsonString = jsonString.substring(firstBrace);
  } else {
    // Fallback: If no '{' is found, try extracting key-value pairs from reasoning CoT text
    const extractedObj: Record<string, any> = {};
    const amountMatch = content.match(/amount["'\s:]+(\d[\d._]*)/i);
    if (amountMatch) {
      extractedObj.amount = parseInt(amountMatch[1].replace(/[._]/g, ''), 10);
    }
    const catMatch = content.match(/category["'\s:]+([^\n,.]+)/i);
    if (catMatch) extractedObj.category = catMatch[1].trim();

    const walletMatch = content.match(/wallet["'\s:]+([^\n,.]+)/i);
    if (walletMatch) extractedObj.wallet = walletMatch[1].trim();

    const notesMatch = content.match(/notes["'\s:]+([^\n,.]+)/i);
    if (notesMatch) extractedObj.notes = notesMatch[1].trim();

    const typeMatch = content.match(/type["'\s:]+(expense|income|transfer)/i);
    if (typeMatch) extractedObj.type = typeMatch[1].toLowerCase();

    if (extractedObj.amount && (extractedObj.wallet || extractedObj.category)) {
      console.log('[cleanAndFixJson] Extracted structured data from CoT reasoning text:', extractedObj);
      return extractedObj as T;
    }

    throw new Error(`Output AI tidak mengandung JSON valid: "${content.substring(0, 120)}..."`);
  }

  // Strip markdown code fences
  jsonString = jsonString.replace(/```json\s*|\s*```/gi, '').trim();

  // Strip JavaScript comments (// ... and /* ... */)
  jsonString = jsonString.replace(/\/\*[\s\S]*?\*\/|\/\/.*/g, '');

  // Remove trailing commas before } or ]
  jsonString = jsonString.replace(/,\s*([}\]])/g, '$1');

  // Auto-close unclosed quote if truncated
  const quoteCount = (jsonString.match(/"/g) || []).length;
  if (quoteCount % 2 !== 0) {
    jsonString += '"';
  }

  // Auto-close unclosed brace if truncated
  if (!jsonString.trim().endsWith('}')) {
    jsonString += '}';
  }

  try {
    return JSON.parse(jsonString) as T;
  } catch (_e) {
    // Fallback: try replacing unquoted keys or single quotes
    let repaired = jsonString
      .replace(/'/g, '"')
      .replace(/([{,]\s*)([a-zA-Z0-9_]+)\s*:/g, '$1"$2":')
      .replace(/,\s*([}\]])/g, '$1');
    return JSON.parse(repaired) as T;
  }
}

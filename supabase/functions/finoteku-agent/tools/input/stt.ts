/**
 * Speech To Text Tool
 * Transkripsi voice message ke teks
 */
import type { AIProvider } from '../../providers/base.ts';
import { BaseTool, type ToolParams } from '../core/base.ts';
import type { ToolResult } from '../../types.ts';

export interface TranscribeResult {
  text: string;
  confidence: number;
}

export class SpeechToTextTool extends BaseTool {
  name = 'speech_to_text';
  description = 'Transcribe voice message to text';
  intents = ['transcribe'];

  constructor(private ai: AIProvider) {
    super();
  }

  async execute(params: ToolParams): Promise<ToolResult> {
    const audio = params.audio as string;
    const mimeType = (params.mimeType as string) || 'audio/ogg';

    if (!audio) {
      return this.error('Audio data required');
    }

    try {
      const text = await this.ai.transcribeAudio(audio, mimeType);

      if (!text || text.trim().length === 0) {
        return this.error('Tidak dapat mengenali ucapan. Coba lagi.');
      }

      const result: TranscribeResult = {
        text: text.trim(),
        confidence: 0.9,
      };

      return this.success(result, `🎵 Terdeteksi: "${result.text}"`);
    } catch (error) {
      console.error('STT failed:', error);
      return this.error('Gagal mengubah suara ke teks.', (error as Error).message);
    }
  }
}

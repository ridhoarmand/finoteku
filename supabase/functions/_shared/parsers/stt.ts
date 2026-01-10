// Speech-to-Text parser using Gemini AI// Transcribes audio from voice notes to text

const GEMINI_API_URL =
  'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent';

/**
 * Transcribe audio using Gemini AI
 * @param base64Audio - Base64 encoded audio data
 * @param apiKey - Gemini API key
 * @param mimeType - Audio MIME type (default: audio/ogg for Telegram voice)
 * @returns Transcribed text or null if failed
 */
export async function transcribeWithGemini(
  base64Audio: string,
  apiKey: string,
  mimeType: string = 'audio/ogg',
): Promise<string | null> {
  const prompt = `Transkripsikan audio ini ke dalam teks Bahasa Indonesia.
ATURAN:
1. Tulis persis apa yang diucapkan
2. Jangan tambahkan penjelasan atau keterangan
3. Jika ada angka, tulis dalam format teks (misal: "lima puluh ribu" tulis sebagai "50000" atau "50k")
4. Langsung output teksnya saja tanpa tanda kutip

HANYA OUTPUT TEKS TRANSKRIPSI.`;

  try {
    const response = await fetch(`${GEMINI_API_URL}?key=${apiKey}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        contents: [
          {
            parts: [
              { text: prompt },
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
          maxOutputTokens: 500,
        },
      }),
    });

    console.log('Gemini STT status:', response.status);

    if (!response.ok) {
      const errorText = await response.text();
      console.error('Gemini STT error:', errorText);
      return null;
    }

    const data = await response.json();

    // Log token usage
    if (data?.usageMetadata) {
      const { promptTokenCount, candidatesTokenCount, totalTokenCount } = data.usageMetadata;
      console.log(
        `[Gemini STT] Tokens - Prompt: ${promptTokenCount}, Response: ${candidatesTokenCount}, Total: ${totalTokenCount}`,
      );
    }

    if (!data.candidates || data.candidates.length === 0) {
      console.error('No candidates from Gemini STT');
      return null;
    }

    const transcribedText = data.candidates[0]?.content?.parts?.[0]?.text;

    if (!transcribedText) {
      console.error('Empty transcription from Gemini');
      return null;
    }

    // Clean up the output
    const cleaned = transcribedText
      .trim()
      .replace(/^["']|["']$/g, '') // Remove quotes
      .replace(/^Transkripsi:\s*/i, '') // Remove "Transkripsi:" prefix if any
      .trim();

    console.log('STT Result:', cleaned);
    return cleaned;
  } catch (error) {
    console.error('Gemini STT error:', error);
    return null;
  }
}

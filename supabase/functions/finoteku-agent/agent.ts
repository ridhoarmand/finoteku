/**
 * Finance Agent
 * Orchestrator utama yang menghubungkan semua komponen
 * Mengelola AI providers, tools, dan data layer
 */

import type { SupabaseClient } from 'https://esm.sh/@supabase/supabase-js@2';
import { ReasoningEngine } from './reasoning.ts';
import { AgentExecutor } from './executor.ts';
import { AIProviderRegistry } from './providers/base.ts';
import { GeminiProvider } from './providers/gemini.ts';
import { ToolRegistry } from './tools/core/index.ts';

// Parser Tools
import { DataEnrichmentTool } from './tools/parser/enrichment.ts';
import { ImageScannerTool, SpeechToTextTool } from './tools/input/index.ts';

// Analytics Tools
import { BalanceTool, HistoryTool, SummaryTool, TrendTool } from './tools/analytics/index.ts';

// AI-Powered Features
import { DataQueryTool, TipsTool, WebSearchTool } from './tools/ai-features/index.ts';

// Transaction Management
import { PendingHandlerTool } from './tools/transaction/index.ts';

// Data Layer
import * as userData from './data/users.ts';
import * as pendingData from './data/pending.ts';
import * as patternData from './data/patterns.ts';

import type { AgentConfig, AgentInput, AgentResponse } from './types.ts';

export class FinanceAgent {
  private executor: AgentExecutor;
  private supabase: SupabaseClient;
  private providers: AIProviderRegistry;

  constructor(config: AgentConfig) {
    this.supabase = config.supabase as SupabaseClient;

    // Inisialisasi AI Providers
    this.providers = new AIProviderRegistry();
    const geminiKey = Deno.env.get('GEMINI_API_KEY');
    if (geminiKey) {
      this.providers.register(new GeminiProvider(geminiKey));
    }

    // Ambil default AI provider
    const ai = geminiKey ? this.providers.get('gemini') : undefined;

    // Inisialisasi Tools
    const tools = new ToolRegistry();

    // NEW: Data Enrichment Tool (smart all-in-one parser)
    tools.register(new DataEnrichmentTool(this.supabase, ai));

    // Input processing
    tools.register(new ImageScannerTool(ai!));
    tools.register(new SpeechToTextTool(ai!));

    // Query tools - untuk menjawab pertanyaan keuangan
    tools.register(new BalanceTool(this.supabase));
    tools.register(new SummaryTool(this.supabase));
    tools.register(new TrendTool(this.supabase));
    tools.register(new TipsTool(this.supabase));
    tools.register(new HistoryTool(this.supabase));

    // Smart Q&A tools - untuk pertanyaan flexibel dengan AI
    tools.register(new DataQueryTool(this.supabase, ai));
    tools.register(new WebSearchTool(ai));

    // Handler untuk konfirmasi, pembatalan, dan update transaksi
    tools.register(new PendingHandlerTool(this.supabase));

    // Setup Reasoning Engine dan Executor
    const reasoning = new ReasoningEngine(ai!);
    this.executor = new AgentExecutor(reasoning, tools, this.supabase);
  }

  /**
   * Memproses input dari platform manapun (Telegram, API, dll)
   * @param input - Input dari user (text, voice, atau image)
   * @param userContextInput - Optional: context user yang sudah ada
   */
  async process(input: AgentInput, userContextInput?: unknown): Promise<AgentResponse> {
    console.log('[FinanceAgent] Memproses:', input.type, input.platform);

    // Ambil user context dari input atau fetch dari database
    const userContext = (userContextInput as userData.UserContext) ||
      (await userData.getContext(this.supabase, input.userId));

    if (!userContext) {
      return {
        type: 'error',
        content: '⚠️ Akun belum terhubung. Silakan hubungkan melalui aplikasi.',
      };
    }

    // NEW: Load user patterns untuk smart parsing
    console.log('[FinanceAgent] Loading user patterns...');
    const patterns = await patternData.buildUserPatterns(this.supabase, userContext.userId);

    // Cek apakah ada transaksi pending yang menunggu konfirmasi
    const platform = (input.platform as pendingData.Platform) || 'telegram';
    const hasPending = await pendingData.exists(this.supabase, userContext.userId, platform);

    // Jalankan agent loop: Plan → Execute → Evaluate (dengan patterns!)
    const response = await this.executor.execute(input, userContext, patterns, hasPending);

    return response;
  }
}

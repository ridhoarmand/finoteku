import type { SupabaseClient } from 'https://esm.sh/@supabase/supabase-js@2';
import { ReasoningEngine } from './reasoning.ts';
import { AgentExecutor } from './executor.ts';
import { AIProviderRegistry } from './providers/base.ts';
import { RouterAIProvider } from './providers/router.ts';
import { GeminiProvider } from './providers/gemini.ts';
import { DynamicAIProvider } from './providers/dynamic.ts';
import { ToolRegistry } from './tools/core/index.ts';

// Parser Tools
import { TransactionParserTool } from './tools/parser/parser.ts';
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

import type { AgentConfig, AgentInput, AgentResponse } from './types.ts';

export class FinanceAgent {
  private executor: AgentExecutor;
  private supabase: SupabaseClient;
  private providers: AIProviderRegistry;
  private ai: DynamicAIProvider;

  constructor(config: AgentConfig) {
    this.supabase = config.supabase as SupabaseClient;

    // Inisialisasi AI Providers
    this.providers = new AIProviderRegistry();

    // Register 9Router AI Provider (Server AI)
    const routerBaseUrl = Deno.env.get('AI_BASE_URL') || 'https://9router.idho.eu.org/v1';
    const routerApiKey = Deno.env.get('AI_API_KEY') || 'sk-a13d362cb2cdd8ca-m70jyx-556be01a';
    const routerModel = Deno.env.get('AI_MODEL') || 'my-combo';

    const routerProvider = new RouterAIProvider(routerBaseUrl, routerApiKey, routerModel);
    this.providers.register(routerProvider);
    this.providers.setDefault('9router');

    // Setup Dynamic AI Provider with 9Router as default
    this.ai = new DynamicAIProvider(routerProvider);

    // Inisialisasi Tools
    const tools = new ToolRegistry();

    // Transaction Parser Tool (AI-first)
    tools.register(new TransactionParserTool(this.supabase, this.ai));

    // Input processing
    tools.register(new ImageScannerTool(this.ai));
    tools.register(new SpeechToTextTool(this.ai));

    // Query tools - untuk menjawab pertanyaan keuangan
    tools.register(new BalanceTool(this.supabase));
    tools.register(new SummaryTool(this.supabase));
    tools.register(new TrendTool(this.supabase));
    tools.register(new TipsTool(this.supabase));
    tools.register(new HistoryTool(this.supabase));

    // Smart Q&A tools - untuk pertanyaan flexibel dengan AI
    tools.register(new DataQueryTool(this.supabase, this.ai));
    tools.register(new WebSearchTool(this.ai));

    // Handler untuk konfirmasi, pembatalan, dan update transaksi
    tools.register(new PendingHandlerTool(this.supabase, this.ai));

    // Setup Reasoning Engine dan Executor
    const reasoning = new ReasoningEngine(this.ai);
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

    // Atur context user di dynamic provider sebelum eksekusi
    this.ai.setUserContext(userContext);

    // Cek apakah ada transaksi pending yang menunggu konfirmasi
    const platform = (input.platform as pendingData.Platform) || 'telegram';
    const hasPending = await pendingData.exists(this.supabase, userContext.userId, platform);

    // Jalankan agent loop: Plan → Execute → Evaluate
    const response = await this.executor.execute(input, userContext, hasPending);

    return response;
  }
}

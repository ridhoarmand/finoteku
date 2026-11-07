/**
 * Finoteku agent v2: rules first, LLM as a fallback.
 * text → route (rules) → query tool | pending reply | local parse (+ LLM only for unsure fields)
 */
import type { SupabaseClient } from 'https://esm.sh/@supabase/supabase-js@2';
import type { AIProvider } from './providers/base.ts';
import { GeminiProvider } from './providers/gemini.ts';
import { OpenRouterProvider } from './providers/openrouter.ts';
import { BalanceTool, HistoryTool, SummaryTool, TrendTool } from './tools/analytics/index.ts';
import { DataQueryTool, TipsTool, WebSearchTool } from './tools/ai-features/index.ts';
import type { BaseTool } from './tools/core/index.ts';
import * as userData from './data/users.ts';
import * as pendingData from './data/pending.ts';
import * as flow from './flow/transaction.ts';
import { route } from './router.ts';
import type { AgentConfig, AgentInput, AgentResponse } from './types.ts';

const HELP = `👋 <b>Finoteku Bot</b>

<b>Catat transaksi</b>
• <code>makan siang 25rb</code>
• <code>kopi 15k gopay kemarin</code>
• <code>makan 20k, parkir 5rb</code> (beberapa sekaligus)
• <code>gaji 7,5jt bca</code>
• <code>tf bca ke gopay 100k</code>, <code>tarik tunai bca 500rb</code>
• Foto struk atau voice note (perlu mode AI)

<b>Tanya</b>
• <code>saldo</code>, <code>ringkasan</code>, <code>riwayat</code>, <code>tren</code>, <code>tips hemat</code>
• <code>pengeluaran terbesar bulan ini?</code>

Setelah konfirmasi muncul, balas <code>ya</code>/<code>batal</code>, atau ubah: <code>kategorinya Minuman</code>, <code>pakai BCA</code>, <code>nominalnya 30rb</code>.`;

/** The LLM for this user, or null: regex mode never uses one. */
export function providerFor(ctx: userData.UserContext): AIProvider | null {
  if (ctx.parserMode === 'regex') return null;
  if (ctx.parserMode === 'user_key' && ctx.aiApiKey) {
    return ctx.aiProvider === 'openrouter' ? new OpenRouterProvider(ctx.aiApiKey) : new GeminiProvider(ctx.aiApiKey);
  }
  const serverKey = Deno.env.get('GEMINI_API_KEY');
  return serverKey ? new GeminiProvider(serverKey) : null;
}

export class FinanceAgent {
  private supabase: SupabaseClient;

  constructor(config: AgentConfig) {
    this.supabase = config.supabase as SupabaseClient;
  }

  async process(input: AgentInput, userContextInput?: unknown): Promise<AgentResponse> {
    const ctx = (userContextInput as userData.UserContext) || (await userData.getContext(this.supabase, input.userId));
    if (!ctx) return { type: 'error', content: '⚠️ Akun belum terhubung. Silakan hubungkan melalui aplikasi.' };

    const ai = providerFor(ctx);
    const platform = (input.platform as pendingData.Platform) || 'telegram';
    const deps: flow.FlowDeps = { supabase: this.supabase, ai, ctx, platform, conversationId: input.conversationId };

    let text = input.content;
    if (input.type !== 'text') {
      if (!ai) {
        return { type: 'error', content: '📝 Foto dan voice note perlu mode AI (atur di aplikasi: Chat Bot → Mode Parser). Untuk sekarang, ketik saja, mis. <code>makan 25rb</code>.' };
      }
      try {
        text = input.type === 'voice'
          ? await ai.transcribeAudio(input.content, input.mimeType || 'audio/ogg')
          : await ai.parseImage(input.content, 'Baca struk/bukti bayar ini. Balas SATU baris: nama toko atau barang lalu TOTAL bayar dalam angka, mis. "Indomaret belanja 87500". Tanpa penjelasan.');
      } catch (e) {
        console.error('[agent] media to text failed:', e);
        return { type: 'error', content: '❌ Gagal membaca media. Coba kirim ulang atau ketik transaksinya.' };
      }
      text = text.trim();
      if (input.caption) text = `${input.caption} ${text}`; // the user's own words win for category/wallet
      if (!text) return { type: 'error', content: '❌ Tidak ada teks yang terbaca.' };
    }

    try {
      const pending = await pendingData.get(this.supabase, ctx.userId, platform);
      const r = route(text, pending);
      console.log('[agent] route:', r.kind, 'mode:', ctx.parserMode, 'llm:', !!ai);

      switch (r.kind) {
        case 'confirm':
          return pending ? await flow.confirm(pending, deps) : { type: 'message', content: 'Tidak ada transaksi yang menunggu.' };
        case 'cancel':
          return await flow.cancel(deps);
        case 'pick':
          return await flow.pick(r.field, r.id, pending!, deps);
        case 'edit':
          return await flow.edit(r.text, pending!, deps);
        case 'transaction':
          return await flow.record(r.text, deps);
        case 'query': {
          const res = await this.tool(r.intent, ai).execute({ text: r.text, userContext: ctx, platform });
          return { type: res.success ? 'message' : 'error', content: res.message, data: res.data };
        }
        case 'help':
          return { type: 'message', content: HELP };
        default:
          return { type: 'message', content: `🤔 Belum paham maksudnya.\n\n${HELP}` };
      }
    } catch (e) {
      console.error('[agent] error:', e);
      return { type: 'error', content: `❌ Terjadi kesalahan: ${(e as Error).message}` };
    }
  }

  private tool(intent: string, ai: AIProvider | null): BaseTool {
    const s = this.supabase;
    switch (intent) {
      case 'query_balance': return new BalanceTool(s);
      case 'query_summary': return new SummaryTool(s);
      case 'query_transactions': return new HistoryTool(s);
      case 'query_trend': return new TrendTool(s);
      case 'query_tips': return new TipsTool(s);
      case 'query_web': return new WebSearchTool(ai ?? undefined);
      default: return new DataQueryTool(s, ai);
    }
  }
}

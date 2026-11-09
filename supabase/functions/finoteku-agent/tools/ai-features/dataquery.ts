/**
 * Data Query Tool: free-form questions about the user's own money.
 * Data is aggregated here, so the LLM (when used) only sees a few compact
 * numbers instead of raw transaction rows; without an LLM it answers from them.
 */
import type { SupabaseClient } from 'https://esm.sh/@supabase/supabase-js@2';
import type { AIProvider } from '../../providers/base.ts';
import { BaseTool, type ToolParams } from '../core/base.ts';
import type { ToolResult } from '../../types.ts';
import { monthRange } from '../../nlu/date.ts';
import type { UserContext } from '../../data/users.ts';
import * as walletData from '../../data/wallets.ts';
import * as transactionData from '../../data/transactions.ts';

const rp = (n: number) => `Rp ${Math.round(n).toLocaleString('id-ID')}`;

interface Facts {
  saldo?: { total: number; per_wallet: Record<string, number> };
  bulan_ini?: { masuk: number; keluar: number; per_kategori: Record<string, number> };
  terakhir?: string[];
}

export class DataQueryTool extends BaseTool {
  name = 'data_query';
  description = 'Menjawab pertanyaan tentang data keuangan user';
  intents = ['query_data'];

  constructor(private supabase: SupabaseClient, private ai?: AIProvider | null) {
    super();
  }

  async execute(params: ToolParams): Promise<ToolResult> {
    const userContext = params.userContext as UserContext;
    const text = (params.text as string) || '';
    if (!userContext) return this.error('User context required');
    if (!text) return this.error('Pertanyaan diperlukan');

    try {
      const facts = await this.gather(userContext, text);
      if (!this.ai || userContext.parserMode === 'regex') return this.success(facts, this.plain(facts));
      return this.success(facts, await this.answer(text, facts));
    } catch (error) {
      console.error('[DataQueryTool] Error:', error);
      return this.error('Gagal mengambil data. Coba lagi nanti.');
    }
  }

  private async gather(ctx: UserContext, question: string): Promise<Facts> {
    const q = question.toLowerCase();
    const facts: Facts = {};
    const wants = (...w: string[]) => w.some((x) => q.includes(x));

    if (wants('saldo', 'wallet', 'dompet', 'uang', 'tabungan')) {
      const { data } = await walletData.getBalances(this.supabase, ctx.userId);
      const per: Record<string, number> = {};
      for (const w of data ?? []) per[w.name] = w.balance;
      facts.saldo = { total: Object.values(per).reduce((a, b) => a + b, 0), per_wallet: per };
    }

    if (wants('pengeluaran', 'pemasukan', 'bulan', 'total', 'kategori', 'tertinggi', 'terbesar', 'terbanyak', 'boros', 'habis')) {
      const [y, m] = ctx.today.split('-').map(Number);
      const { start, end } = monthRange(y, m);
      const { data } = await transactionData.getByDateRange(this.supabase, ctx.userId, start, end);
      const month = { masuk: 0, keluar: 0, per_kategori: {} as Record<string, number> };
      for (const t of data ?? []) {
        const amount = Math.abs(Number(t.amount));
        if (t.category_type === 'income') month.masuk += amount;
        else {
          month.keluar += amount;
          const k = t.category_name ?? 'Lainnya';
          month.per_kategori[k] = (month.per_kategori[k] ?? 0) + amount;
        }
      }
      // top 5 only: enough to answer "kategori terbesar" without sending every category
      month.per_kategori = Object.fromEntries(Object.entries(month.per_kategori).sort((a, b) => b[1] - a[1]).slice(0, 5));
      facts.bulan_ini = month;
    }

    if (wants('terakhir', 'terbaru', 'riwayat', 'histori', 'transaksi')) {
      const { data } = await transactionData.getRecent(this.supabase, ctx.userId, 5);
      // deno-lint-ignore no-explicit-any
      facts.terakhir = (data ?? []).map((t: any) => `${t.date} ${t.category_name ?? t.kind} ${Math.abs(Number(t.amount))} ${t.notes ?? ''}`.trim());
    }
    return facts;
  }

  private async answer(question: string, facts: Facts): Promise<string> {
    if (!Object.keys(facts).length) return this.plain(facts);
    return await this.ai!.generateText(`Q: ${question}\nData: ${JSON.stringify(facts)}`, {
      systemPrompt: 'Kamu Finoteku. Jawab pertanyaan dari Data saja, Bahasa Indonesia santai, format Rupiah, maks 3 kalimat.',
      maxTokens: 160,
      temperature: 0.3,
    });
  }

  /** Answer without an LLM, straight from the numbers. */
  private plain(facts: Facts): string {
    const lines = ['📊 <b>Data Keuangan</b>\n'];
    if (facts.saldo) {
      lines.push(`💰 Total saldo: ${rp(facts.saldo.total)}`);
      for (const [n, b] of Object.entries(facts.saldo.per_wallet)) lines.push(`   • ${n}: ${rp(b)}`);
    }
    if (facts.bulan_ini) {
      lines.push(`📈 Pemasukan bulan ini: ${rp(facts.bulan_ini.masuk)}`);
      lines.push(`📉 Pengeluaran bulan ini: ${rp(facts.bulan_ini.keluar)}`);
      const top = Object.entries(facts.bulan_ini.per_kategori);
      if (top.length) lines.push(`🏷️ Terbesar: ${top.map(([k, v]) => `${k} ${rp(v)}`).join(', ')}`);
    }
    if (facts.terakhir?.length) lines.push(`🧾 Terakhir:\n${facts.terakhir.map((t) => `   • ${t}`).join('\n')}`);
    if (lines.length === 1) lines.push('Coba tanya soal saldo, pengeluaran bulan ini, atau transaksi terakhir.');
    return lines.join('\n');
  }
}

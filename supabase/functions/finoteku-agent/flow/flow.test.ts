// End-to-end agent scenarios against an in-memory Supabase fake. Run: bun test supabase/functions/finoteku-agent
import { beforeEach, describe, expect, test } from 'bun:test';
import type { AIProvider, GenerateOptions } from '../providers/base.ts';
import type { UserContext } from '../data/users.ts';

(globalThis as unknown as { Deno: unknown }).Deno = { env: { get: () => undefined } };
const { FinanceAgent } = await import('../agent.ts');
const flow = await import('./transaction.ts');

// ---- minimal fake of the supabase-js calls the flow uses ----
type Row = Record<string, unknown>;
function fakeSupabase() {
  const tables: Record<string, Row[]> = { pending_bot_transactions: [], transactions: [] };
  const rpcCalls: Array<{ fn: string; args: Row }> = [];
  function query(table: string) {
    const filters: Array<(r: Row) => boolean> = [];
    let op: 'select' | 'delete' | 'insert' | 'upsert' = 'select';
    let payload: Row | null = null;
    let limit = Infinity;
    const run = () => {
      const rows = (tables[table] ??= []);
      if (op === 'insert') { const r = { id: crypto.randomUUID(), ...payload }; rows.push(r); return { data: r, error: null }; }
      if (op === 'upsert') {
        const i = rows.findIndex((r) => r.user_id === payload!.user_id && r.platform === payload!.platform);
        if (i >= 0) rows[i] = { ...rows[i], ...payload }; else rows.push({ ...payload });
        return { data: null, error: null };
      }
      const hit = rows.filter((r) => filters.every((f) => f(r)));
      if (op === 'delete') { tables[table] = rows.filter((r) => !hit.includes(r)); return { data: null, error: null }; }
      return { data: hit.slice(0, limit), error: null };
    };
    const b: Row = {
      select: () => b, order: () => b,
      eq: (k: string, v: unknown) => (filters.push((r) => r[k] === v), b),
      gt: (k: string, v: string) => (filters.push((r) => String(r[k]) > v), b),
      not: (k: string) => (filters.push((r) => r[k] != null), b),
      limit: (n: number) => ((limit = n), b),
      delete: () => ((op = 'delete'), b),
      insert: (p: Row) => ((op = 'insert'), (payload = p), b),
      upsert: (p: Row) => ((op = 'upsert'), (payload = p), b),
      maybeSingle: () => Promise.resolve({ data: run().data?.[0 as never] ?? (run().data as Row[])?.[0] ?? null, error: null }),
      single: () => Promise.resolve(op === 'insert' ? run() : { data: (run().data as Row[])[0], error: null }),
      then: (res: (v: unknown) => unknown) => Promise.resolve(run()).then(res),
    };
    return b;
  }
  return {
    tables, rpcCalls,
    from: (t: string) => query(t),
    rpc: (fn: string, args: Row) => { rpcCalls.push({ fn, args }); return Promise.resolve({ data: 'tr-1', error: null }); },
  };
}

const CATS = [
  { id: 'makan', name: 'Makanan', type: 'expense' as const, parent_name: null },
  { id: 'minum', name: 'Minuman', type: 'expense' as const, parent_name: null },
  { id: 'belanja', name: 'Belanja', type: 'expense' as const, parent_name: null },
  { id: 'gaji', name: 'Gaji', type: 'income' as const, parent_name: null },
];
const WALLETS = [{ id: 'cash', name: 'Cash', balance: 0 }, { id: 'bca', name: 'BCA', balance: 0 }, { id: 'ovo', name: 'OVO', balance: 0 }];
const ctx = (mode: UserContext['parserMode'] = 'regex'): UserContext => ({
  userId: 'u1', categories: CATS, wallets: WALLETS, parserMode: mode, aiProvider: 'gemini', aiApiKey: 'k',
  timezone: 'Asia/Jakarta', today: '2026-11-06',
});

let sb: ReturnType<typeof fakeSupabase>;
let agent: InstanceType<typeof FinanceAgent>;
const say = (text: string, c = ctx()) =>
  agent.process({ type: 'text', content: text, userId: 'u1', conversationId: 'chat', platform: 'whatsapp' }, c);

beforeEach(() => {
  sb = fakeSupabase();
  agent = new FinanceAgent({ supabase: sb });
});

describe('agent v2 (regex mode, no LLM)', () => {
  test('record → ya saves with the user-zone date', async () => {
    const r = await say('makan siang 25rb');
    expect(r.type).toBe('confirmation');
    expect(r.content).toContain('Rp 25.000');
    expect((await say('ya')).content).toContain('disimpan');
    expect(sb.tables.transactions).toMatchObject([{ amount: 25000, category_id: 'makan', wallet_id: 'cash', date: '2026-11-06', notes: 'Makan Siang' }]);
    expect(sb.tables.pending_bot_transactions).toEqual([]);
  });

  test('bug fix: a new transaction replaces the pending one', async () => {
    await say('makan 20k');
    await say('es teh 15k');
    await say('ya');
    expect(sb.tables.transactions.map((t) => t.amount)).toEqual([15000]);
  });

  test('batch + edit by number + save all', async () => {
    const r = await say('makan 20k, es teh 5rb pakai ovo kemarin');
    expect(r.content).toContain('2 transaksi');
    await say('yang kedua 8rb');
    expect((await say('ya')).content).toContain('2 transaksi disimpan');
    expect(sb.tables.transactions.map((t) => [t.amount, t.wallet_id, t.date])).toEqual([
      [20000, 'ovo', '2026-11-05'], [8000, 'ovo', '2026-11-05'],
    ]);
  });

  test('edits: category, wallet, date, notes', async () => {
    await say('makan 20k');
    await say('kategorinya Belanja');
    await say('pakai bca');
    await say('kemarin');
    await say('catatan galon');
    await say('ya');
    expect(sb.tables.transactions).toMatchObject([{ category_id: 'belanja', wallet_id: 'bca', date: '2026-11-05', notes: 'galon' }]);
  });

  test('unknown word → category buttons; WhatsApp "1" picks, then save', async () => {
    const r = await say('xyzabc 40rb');
    expect(r.actions!.some((a) => a.action.startsWith('pick_cat:'))).toBe(true);
    const firstPick = r.actions!.findIndex((a) => a.action.startsWith('pick_cat:'));
    const pickedId = r.actions![firstPick].action.split(':')[1];
    await say(String(firstPick + 1));
    await say('ya');
    expect(sb.tables.transactions[0].category_id).toBe(pickedId);
  });

  test('transfer without source asks for the wallet, then uses the RPC', async () => {
    const r = await say('tf ke ovo 50rb');
    expect(r.actions!.some((a) => a.action === 'confirm_yes')).toBe(false);
    expect(r.content).toContain('Dari wallet mana');
    await say('pick_wallet:bca');
    await say('ya');
    expect(sb.rpcCalls[0]).toMatchObject({ fn: 'create_wallet_transfer', args: { p_from_wallet_id: 'bca', p_to_wallet_id: 'ovo', p_amount: 50000, p_date: '2026-11-06' } });
  });

  test('voice in regex mode explains instead of crashing', async () => {
    const r = await agent.process({ type: 'voice', content: 'AAAA', userId: 'u1', conversationId: 'c', platform: 'telegram' }, ctx());
    expect(r.content).toContain('mode AI');
  });

  test('batal clears the pending', async () => {
    await say('makan 20k');
    await say('batal');
    expect(await say('ya')).toMatchObject({ content: 'Tidak ada transaksi yang menunggu.' });
  });
});

describe('LLM fallback (AI mode)', () => {
  const calls: Array<{ prompt: string; opts?: GenerateOptions }> = [];
  const fakeAI = (answer: unknown): AIProvider => ({
    name: 'fake',
    generateText: () => Promise.resolve(''),
    generateJSON: <T>(prompt: string, opts?: GenerateOptions) => (calls.push({ prompt, opts }), Promise.resolve(answer as T)),
    parseImage: () => Promise.resolve(''),
    transcribeAudio: () => Promise.resolve(''),
  });

  test('sure items never call the LLM', async () => {
    calls.length = 0;
    const deps = { supabase: sb as never, ai: fakeAI([]), ctx: ctx('server_key'), platform: 'telegram' as const, conversationId: 'c' };
    await flow.record('makan 20k', deps);
    expect(calls.length).toBe(0);
  });

  test('unsure item: one small call, answer validated against real categories', async () => {
    calls.length = 0;
    const deps = { supabase: sb as never, ai: fakeAI([{ i: 0, c: 'Belanja' }]), ctx: ctx('server_key'), platform: 'telegram' as const, conversationId: 'c' };
    const r = await flow.record('xyzabc 40rb', deps);
    expect(calls.length).toBe(1);
    expect(calls[0].prompt.length).toBeLessThan(200);
    expect(r.content).toContain('Belanja');
    expect(r.content).not.toContain('❓');
  });

  test('LLM inventing a category is ignored (user is asked instead)', async () => {
    const deps = { supabase: sb as never, ai: fakeAI([{ i: 0, c: 'Crypto' }]), ctx: ctx('server_key'), platform: 'telegram' as const, conversationId: 'c' };
    const r = await flow.record('xyzabc 40rb', deps);
    expect(r.actions!.some((a) => a.action.startsWith('pick_cat:'))).toBe(true);
  });

  test('no amount locally → LLM fallback parse', async () => {
    const deps = { supabase: sb as never, ai: fakeAI([{ type: 'expense', amount: 20000, category: 'Makanan', wallet: 'Cash', notes: 'Bakso' }]), ctx: ctx('server_key'), platform: 'telegram' as const, conversationId: 'c' };
    const r = await flow.record('bakso dua puluh ribu', deps);
    expect(r.content).toContain('Rp 20.000');
    expect(r.content).toContain('Makanan');
  });
});

describe('router', async () => {
  const { route } = await import('../router.ts');
  const pending = { items: [], choices: ['pick_cat:a', 'confirm_yes', 'confirm_no'] };
  const cases: Array<[string, typeof pending | null, string]> = [
    ['makan 20k', null, 'transaction'],
    ['nasi yang pedas 20k', pending, 'transaction'],
    ['yang kedua 25rb', pending, 'edit'],
    ['nominalnya 30rb', pending, 'edit'],
    ['kategorinya minuman', pending, 'edit'],
    ['2', pending, 'confirm'],
    ['1', pending, 'pick'],
    ['saldo', null, 'query'],
    ['berapa pengeluaran bulan ini?', null, 'query'],
    ['ringkasan bulan lalu', null, 'query'],
    ['tips hemat dong', null, 'query'],
    ['halo', null, 'unknown'],
    ['ya', null, 'confirm'],
  ];
  for (const [text, p, kind] of cases) test(text, () => expect(route(text, p).kind).toBe(kind));
});

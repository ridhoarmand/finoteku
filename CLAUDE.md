# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

Supabase backend of Finoteku: database schema/migrations and three Deno edge functions. The Flutter app lives in the sibling repo `../../Flutter/finoteku`. Comments and bot copy are Indonesian.

## Commands

```bash
bun test supabase/functions/finoteku-agent        # parser corpus + agent scenarios (fake Supabase)
```

No Deno on this machine; `nlu/` is pure TypeScript so bun runs it. For a strict type check, use any installed `tsc` with stub declarations for the `https://` imports.

## Layout

- `supabase/schema.sql`: dump of the live schema. Changes go in **new** files in `supabase/migrations/` (timestamped, idempotent), never by editing the dump.
- `supabase/functions/finoteku-agent`: the agent. Rules first, LLM only as fallback: `router.ts` (intent) → `nlu/` (amount, date, wallet, category from the user's history, `agent_training` examples and synonyms; emoji templates) → `llm/resolve.ts` (9Router, only for unsure fields, ≤6 candidates) → `flow/transaction.ts` (pending confirmation in `pending_bot_transactions.payload`, edits, save). `users.parser_mode = 'regex'` means no LLM at all.
- `supabase/functions/telegram-bot`, `whatsapp-bot`: webhooks that call the agent with the service key.
- `supabase/tests/balance_triggers.sql`: psql script checking the wallet-balance triggers (rolled back).

## Deploy: the only correct order

Pushing to `master` with changes under `supabase/functions/**` **deploys all three functions immediately** (`.github/workflows/deploy.yml`, `supabase functions deploy … --yes`). So everything the new code needs must exist first:

1. **SQL first.** Run every new file in `supabase/migrations/`, in name order, in the Supabase SQL editor (or `supabase db push`). Code that calls a new table/column/RPC breaks if this is skipped.
2. **Secrets** (Supabase → Edge Functions → Secrets), before code that reads them:
   - `TELEGRAM_WEBHOOK_SECRET`: telegram-bot rejects every request without it (401).
   - `GOWA_WEBHOOK_SECRET`: whatsapp-bot rejects unsigned webhooks.
   - `AI_API_KEY` (+ optional `AI_BASE_URL`, `AI_MODEL`): 9Router. Without it every user runs without LLM (still works). Never hard-code a key in source.
   - `TELEGRAM_BOT_TOKEN`, `GOWA_*` as before.
3. **Telegram webhook** after changing the secret: `setWebhook` with `"secret_token": "<TELEGRAM_WEBHOOK_SECRET>"`.
4. **Push `master`** and watch: `gh run watch <id> --exit-status`. A change that only touches the workflow does not trigger it; run `gh workflow run deploy.yml --ref master`.
5. **Check from outside** (no credentials): each must answer 401.
   ```bash
   for f in finoteku-agent telegram-bot whatsapp-bot; do
     curl -s -o /dev/null -w "$f %{http_code}\n" -X POST "$SUPABASE_URL/functions/v1/$f" -d '{}'
   done
   ```
6. If the app must change at the same time (e.g. a new RPC it calls), deploy the backend **before** releasing the app (see the app's CLAUDE.md "Release").

Rules:
- `finoteku-agent` trusts `input.userId`, so it only accepts the service key; never deploy it without that check.
- SECURITY DEFINER functions that take a user id must call `assert_acting_user`; bot-only RPCs are granted to `service_role` only (the anon key ships in the app).
- Pull before pushing (`git fetch && git status`): this repo is also edited from another machine.
- No `Co-Authored-By: Claude` (or any AI attribution) in commits.

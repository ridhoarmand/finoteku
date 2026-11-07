# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

Finoteku is a personal finance app (Flutter + Supabase) for Android, Linux, Windows and Web. Comments, commit messages and many identifiers are in Indonesian.

## Commands

```bash
flutter pub get
flutter run --dart-define-from-file=.env      # .env is required; copy from .env.example
flutter analyze
flutter test                                  # single file: flutter test test/money_test.dart
./release.sh [--android|--linux|--all] [--install] [--no-tree-shake-icons]
```

- UI review: `integration_test/screenshot_tour_test.dart` logs in with a test account and saves PNGs of the main screens (light/dark); the exact command is in its header. Run it with a throwaway `XDG_DATA_HOME`, because it writes app prefs and a session.
- The bot agent (sibling repo) has its own tests: `bun test supabase/functions/finoteku-agent`.

- Supabase credentials are **compile-time** values (`String.fromEnvironment` in `lib/utils/environment.dart`). Every `flutter run`/`build` needs `--dart-define-from-file=.env`, or the app starts with placeholder credentials. `.vscode/launch.json` already passes it.
- `release.sh` bumps the build number in `pubspec.yaml` (`x.y.z+N` → `+N+1`) and restores the original version if the build fails. Android builds are obfuscated with split debug info in `build/debug-info/`. `--install` runs `install_linux.sh` on the Linux bundle.
- Providers are written by hand (no code generation).

## Backend lives in another repo

The database schema, RLS policies, RPCs, triggers and edge functions live in the sibling repo **finoteku-agent** (`../../JavaScript/finoteku-agent`, `supabase/schema.sql`), together with the Telegram/WhatsApp bots that also write transactions. This repo's `supabase/` folder holds only CLI state. Check `schema.sql` and `supabase/migrations/` there before you change any query. SQL changes go in a new migration file; `supabase/tests/balance_triggers.sql` checks the balance triggers.

- **Wallet balances are maintained by DB triggers** on `transactions` and `transfers` (`update_wallet_balance`, `handle_transfer_amount_only`). The app must not adjust `wallets.balance` itself when it creates, edits or deletes a transaction.
- RPCs that take `p_user_id` must check it against `auth.uid()` (`assert_acting_user`), and bot-only RPCs are granted to `service_role` only: the anon key ships in the app.
- Transfers go through RPCs (`create_wallet_transfer`, `update_wallet_transfer`, `delete_wallet_transfer`). Other features use RPCs too: bot linking (`get_bot_link`, `link_by_user_id`, `unlink_platform`) and account deletion (`delete_user_account_complete`, `get_user_data_summary`).
- Categories: `prevent_category_delete` and `prevent_category_type_change` triggers reject some operations, so the app gets those as errors.

## Architecture

`lib/features/<feature>/` holds `screens/`, `widgets/`, `providers/`, `services/`, `models/` and `i18n/`. Shared models live in `lib/models/`, and cross-cutting code lives in `lib/core/`, `lib/services/`, `lib/theme/` and `lib/utils/`.

- **Row cap:** PostgREST returns at most 1000 rows per request without any error. Unbounded list queries go through `fetchAllRows` (`lib/services/supabase_service.dart`) with a unique final `.order(...)`.
- **Hidden wallets/categories:** anything that shows or classifies *existing* transactions uses `walletsProvider` / `categoriesAllProvider` (these include hidden items), not the active-only lists.
- **Data flow:** a service class wraps `SupabaseClient` (e.g. `WalletService`), is exposed through a `Provider`, and is read by `FutureProvider.family` providers keyed by `userId`. Services log through `AppLogger` and rethrow via `mapException` (`lib/core/errors/failure.dart`), which maps errors to the sealed `Failure` types.
- **Refreshing data:** each feature has a `RefreshToken` notifier (`lib/core/state/refresh_token.dart`, e.g. `walletRefreshTriggerProvider`, `transactionRefreshTriggerProvider`, `categoryRefreshProvider`). List providers `ref.watch` it; after a mutation, call `.notifier.bump()` so every list reloads. Because balances change in the DB, a transaction mutation usually has to refresh wallets as well.
- **Routing:** `lib/routes/app_routes.dart` defines `routerProvider` (GoRouter, kept alive). It watches the auth, language-preference and onboarding providers, and its `redirect` controls the flow splash → language → onboarding → auth → shell. The password-recovery auth event redirects before any other rule. `rootNavigatorKey` is shared with `NotificationService` so tapping a notification can navigate.
- **Startup (`main.dart`):** sets the timezone to `Asia/Jakarta` and initializes Supabase. On non-web platforms it then starts notifications and connectivity in the background. Initialization errors are logged and the app keeps running. Desktop window setup uses a conditional import (`desktop_window.dart` / `desktop_window_stub.dart` for web).
- **i18n is custom, not ARB:** each feature has `i18n/strings.dart` with `xxxStringsEn` / `xxxStringsId` maps. `lib/core/localization/app_localizations.dart` merges them into one flat map, so keys must be unique across features. A new feature's maps must be added to that merge. Look up strings with `ref.tr(context, 'key')`. A missing key falls back to English, then to the raw key.
- Money defaults to IDR (`lib/core/value_objects/money.dart`, formatters in `lib/utils/`).

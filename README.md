# Finoteku

<img width="160" height="160" alt="Finoteku" src="https://github.com/user-attachments/assets/b93bf38a-b4ff-4ab9-8178-58f080446742" />

Aplikasi keuangan pribadi untuk Android, Linux, Windows dan Web, ditambah bot Telegram/WhatsApp
untuk mencatat transaksi lewat chat. Aplikasi (Flutter) dan backend (Supabase: database, RPC,
edge function bot) ada di repo ini.

## Fitur

- **Dompet**: banyak dompet (tunai, bank, e-wallet) dengan logo bank/e-wallet Indonesia, saldo
  dijaga oleh trigger database.
- **Transaksi dan transfer**: pemasukan, pengeluaran, transfer antar dompet (dengan biaya), filter
  periode/jenis/kategori/dompet.
- **Kategori bertingkat**: kategori dan subkategori, masing-masing dengan warna sendiri.
- **Laporan**: total per periode (minggu/bulan/tahun), perbandingan dengan periode lalu, donut per
  kategori, filter per dompet.
- **Anggaran**: batas bulanan per kategori pengeluaran dan batas total, peringatan di 80% dan 100%.
- **Bot Telegram/WhatsApp**: `kopi 15k`, `gaji 5jt mandiri`, `makan 20k, parkir 5k kemarin`, foto
  struk dan voice note. Dibaca dengan aturan dan riwayat user; LLM hanya dipakai untuk bagian yang
  ragu, dan bisa dimatikan (mode RegEx).
- **Update di dalam aplikasi** (Android), tema terang/gelap, Bahasa Indonesia dan Inggris.

## Teknologi

- Flutter 3, Riverpod 3, GoRouter
- Supabase: PostgreSQL dengan RLS, Auth, Storage
- Edge function Deno (bot), LLM lewat API OpenAI-compatible (opsional)

## Menjalankan aplikasi

```bash
flutter pub get
cp .env.example .env        # isi SUPABASE_URL dan SUPABASE_PUBLISHABLE_KEY
flutter run --dart-define-from-file=.env
```

Kredensial dibaca saat kompilasi, jadi setiap `flutter run`/`build` butuh
`--dart-define-from-file=.env`.

Tes: `flutter test` (aplikasi) dan `bun test supabase/functions/finoteku-agent` (parser dan
skenario bot).

## Menyiapkan Supabase

1. Buat project di [supabase.com](https://supabase.com).
2. Di SQL Editor, jalankan `supabase/schema.sql`, lalu semua file `supabase/migrations/*.sql`
   berurutan sesuai nama.
3. Bot (opsional):
   ```bash
   supabase link --project-ref <PROJECT_REF>
   supabase secrets set TELEGRAM_BOT_TOKEN=<token BotFather> TELEGRAM_WEBHOOK_SECRET=$(openssl rand -hex 32)
   supabase secrets set AI_API_KEY=<key>          # opsional; tanpa ini bot jalan tanpa LLM
   supabase functions deploy finoteku-agent --no-verify-jwt
   supabase functions deploy telegram-bot --no-verify-jwt
   supabase functions deploy whatsapp-bot --no-verify-jwt   # butuh GOWA_WEBHOOK_SECRET
   curl -X POST "https://api.telegram.org/bot<TOKEN>/setWebhook" -H "Content-Type: application/json" \
     -d '{"url":"https://<PROJECT_REF>.supabase.co/functions/v1/telegram-bot","secret_token":"<TELEGRAM_WEBHOOK_SECRET>"}'
   ```
   `SUPABASE_URL` dan `SUPABASE_SERVICE_ROLE_KEY` sudah tersedia otomatis di edge function.

| Secret edge function | Fungsi |
| --- | --- |
| `TELEGRAM_BOT_TOKEN` | Token bot dari BotFather |
| `TELEGRAM_WEBHOOK_SECRET` | Harus sama dengan `secret_token` di setWebhook; request lain ditolak |
| `GOWA_WEBHOOK_SECRET` | Secret HMAC webhook GOWA (WhatsApp) |
| `AI_API_KEY`, `AI_BASE_URL`, `AI_MODEL` | LLM OpenAI-compatible, opsional |

## Struktur

```
lib/                     aplikasi Flutter (lib/features/<fitur>/{screens,widgets,providers,services,models,i18n})
assets/                  ikon, logo bank/e-wallet (assets/finlogos), gambar onboarding
integration_test/        screenshot tour untuk review UI
supabase/schema.sql      dump schema (tabel, RLS, RPC, trigger)
supabase/migrations/     perubahan schema setelah dump, jalankan berurutan
supabase/tests/          tes SQL (psql, di-rollback)
supabase/functions/      bot: finoteku-agent, telegram-bot, whatsapp-bot
.github/workflows/       release.yml (APK dari tag v*), deploy.yml (edge function dari master)
```

## Rilis dan deploy

- **Aplikasi Android**: naikkan `version` di `pubspec.yaml`, push, lalu push tag `vX.Y.Z`. GitHub
  Actions membangun APK bertanda tangan, membuat GitHub Release, dan mengisi tabel `app_versions`
  untuk update di dalam aplikasi.
- **Bot**: push ke `master` yang mengubah `supabase/functions/**` langsung men-deploy ketiga
  function. Jalankan migration SQL dulu.

Urutan lengkap dan aturannya ada di [CLAUDE.md](CLAUDE.md).

## Lisensi

Kode: MIT, lihat [LICENSE](LICENSE).

Logo bank dan e-wallet di `assets/finlogos` berasal dari
[idn-finlogos](https://github.com/hafidznoor/idn-finlogos) dengan lisensi
[CC BY-NC 4.0](assets/finlogos/LICENSE-ASSETS): hanya untuk penggunaan non-komersial, dengan atribusi.
Merek dagang milik pemiliknya masing-masing.

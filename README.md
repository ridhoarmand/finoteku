# Finoteku

<img width="160" height="160" alt="Finoteku" src="https://github.com/user-attachments/assets/b93bf38a-b4ff-4ab9-8178-58f080446742" />

Aplikasi keuangan pribadi untuk Android, Linux, Windows dan Web, ditambah bot Telegram/WhatsApp
untuk mencatat transaksi lewat chat. Aplikasi (Flutter) dan backend (Supabase: database, RPC,
edge function bot) ada di repo ini.

## Fitur

- **Dompet**: tunai, bank, e-wallet, dengan logo bank/e-wallet Indonesia. Saldo dijaga oleh trigger
  database, jadi selalu cocok dengan transaksinya.
- **Transaksi dan transfer**: pemasukan, pengeluaran, transfer antar dompet (dengan biaya), filter
  periode/jenis/kategori/dompet.
- **Kategori bertingkat** dengan warna per kategori.
- **Laporan** per minggu/bulan/tahun: total, perbandingan dengan periode lalu, donut per kategori,
  filter per dompet.
- **Anggaran** bulanan per kategori dan batas total, dengan peringatan di 80% dan 100%.
- **Bot Telegram/WhatsApp**: `kopi 15k`, `gaji 5jt mandiri`, `makan 20k, parkir 5k kemarin`, foto
  struk, voice note. Dibaca dengan aturan dan riwayat user; LLM hanya untuk bagian yang ragu dan
  bisa dimatikan.
- Update di dalam aplikasi (Android) dari GitHub Releases, tema terang/gelap, Bahasa Indonesia dan
  Inggris.

## Teknologi

Flutter 3 · Riverpod 3 · GoRouter · Supabase (PostgreSQL dengan RLS, Auth, Storage) · edge function
Deno · LLM lewat API OpenAI-compatible (opsional).

## Setup

### 1. Database (Supabase)

1. Buat project di [supabase.com](https://supabase.com).
2. Buka **SQL Editor**, tempel seluruh isi [`supabase/schema.sql`](supabase/schema.sql), lalu
   **Run**. File ini membuat semua tabel, RLS, RPC, trigger saldo, trigger pendaftaran user, serta
   bucket dan policy Storage.
3. Di **Settings → API Keys**, salin *Project URL* dan *publishable key*.

### 2. Aplikasi

Butuh [Flutter](https://docs.flutter.dev/get-started/install) 3.x.

```bash
flutter pub get
cp .env.example .env            # isi SUPABASE_URL dan SUPABASE_PUBLISHABLE_KEY
flutter run --dart-define-from-file=.env
```

Konfigurasi dibaca saat kompilasi, jadi setiap `flutter run` / `flutter build` butuh
`--dart-define-from-file=.env`. Tanpa itu aplikasi jalan dengan alamat contoh dan login gagal.

Tes: `flutter analyze` dan `flutter test`.

### 3. Bot (opsional)

Butuh [Supabase CLI](https://supabase.com/docs/guides/cli). Tes bot: `bun test supabase/functions/finoteku-agent`.

```bash
supabase link --project-ref <PROJECT_REF>
supabase secrets set TELEGRAM_BOT_TOKEN=<token dari @BotFather> TELEGRAM_WEBHOOK_SECRET=$(openssl rand -hex 32)
supabase functions deploy finoteku-agent --no-verify-jwt
supabase functions deploy telegram-bot --no-verify-jwt
curl -X POST "https://api.telegram.org/bot<TOKEN>/setWebhook" -H "Content-Type: application/json" \
  -d '{"url":"https://<PROJECT_REF>.supabase.co/functions/v1/telegram-bot","secret_token":"<TELEGRAM_WEBHOOK_SECRET>"}'
```

Lalu set `TELEGRAM_BOT_USERNAME` (dan `WA_BOT_NUMBER` untuk WhatsApp) di `.env` aplikasi, supaya
tombol "hubungkan bot" membuka bot milikmu.

| Secret edge function | Fungsi |
| --- | --- |
| `TELEGRAM_BOT_TOKEN` | Token bot dari @BotFather |
| `TELEGRAM_WEBHOOK_SECRET` | Harus sama dengan `secret_token` di setWebhook; request lain ditolak |
| `GOWA_URL`, `GOWA_WEBHOOK_SECRET` | WhatsApp lewat [GOWA](https://github.com/aldinokemal/go-whatsapp-web-multidevice) (`whatsapp-bot`) |
| `AI_API_KEY`, `AI_BASE_URL`, `AI_MODEL` | LLM OpenAI-compatible, opsional; tanpa ini bot tetap jalan dengan aturan saja |

`SUPABASE_URL` dan `SUPABASE_SERVICE_ROLE_KEY` sudah tersedia otomatis di edge function.
`finoteku-agent` hanya menerima service key, karena ia mempercayai `userId` dari pemanggil.

## Mengubah database

Ubah database (SQL Editor), lalu perbarui `supabase/schema.sql` dari database itu:

```bash
SUPABASE_DB_URL='postgresql://postgres.<ref>:<db-password>@<pooler-host>:5432/postgres' ./supabase/dump_schema.sh
```

Connection string ada di dashboard → **Connect → Session pooler**. Skrip menjalankan `pg_dump` 17 di
container (podman atau docker). `supabase/tests/*.sql` berisi tes SQL (jalankan dengan `psql` ke
database dev, semuanya di-rollback).

Aturan yang dipegang schema:
- Saldo dompet diubah hanya oleh trigger di `transactions` dan `transfers`; aplikasi dan bot tidak
  pernah menulis `wallets.balance` sendiri.
- RPC yang menerima `p_user_id` memeriksanya terhadap `auth.uid()` (`assert_acting_user`). RPC khusus
  bot hanya diberikan ke `service_role`, karena publishable key ada di dalam aplikasi.

## Rilis

**Android**: naikkan `version` di `pubspec.yaml` (nama **dan** angka build, misal `0.5.4+13` →
`0.5.5+14`), push ke `master`, lalu:

```bash
git tag -a v0.5.5 -m "Finoteku v0.5.5" && git push origin v0.5.5
```

[`release.yml`](.github/workflows/release.yml) menolak tag yang tidak sama dengan versi pubspec atau
tidak lebih tinggi dari rilis sebelumnya, membangun APK yang ditandatangani, memeriksa sertifikat dan
alamat Supabase di dalamnya, lalu menerbitkan GitHub Release. Aplikasi yang terpasang menemukan
rilis itu lewat GitHub API dan mengunduh APK universal. Jangan memindahkan tag yang sudah dirilis;
buat versi baru.

Secret GitHub: `SUPABASE_URL`, `SUPABASE_PUBLISHABLE_KEY`, `ANDROID_KEYSTORE_BASE64`,
`ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD`. Keystore yang sama harus
dipakai selamanya; tanpa itu update tidak bisa menimpa aplikasi yang sudah terpasang.

**Bot**: push ke `master` yang mengubah `supabase/functions/**` langsung men-deploy ketiga function
lewat [`deploy.yml`](.github/workflows/deploy.yml) (secret `SUPABASE_ACCESS_TOKEN`,
`SUPABASE_PROJECT_ID`). Ubah database dan set secret function **sebelum** push. Setelah deploy,
ketiga endpoint harus menjawab 401 tanpa kredensial:

```bash
for f in finoteku-agent telegram-bot whatsapp-bot; do
  curl -s -o /dev/null -w "$f %{http_code}\n" -X POST "$SUPABASE_URL/functions/v1/$f" -d '{}'
done
```

**Linux** (lokal): `./release.sh --linux --install`.

## Struktur

```
lib/                     aplikasi: lib/features/<fitur>/{screens,widgets,providers,services,models,i18n}
assets/                  ikon, logo bank/e-wallet (assets/finlogos), gambar onboarding
test/                    unit test
supabase/schema.sql      schema lengkap (hasil dump_schema.sh)
supabase/tests/          tes SQL
supabase/functions/      bot: finoteku-agent, telegram-bot, whatsapp-bot
.github/workflows/       release.yml (APK dari tag v*), deploy.yml (edge function dari master)
```

## Lisensi

Kode: MIT, lihat [LICENSE](LICENSE).

Logo bank dan e-wallet di `assets/finlogos` berasal dari
[idn-finlogos](https://github.com/hafidznoor/idn-finlogos) dengan lisensi
[CC BY-NC 4.0](assets/finlogos/LICENSE-ASSETS): hanya untuk penggunaan non-komersial, dengan atribusi.
Merek dagang milik pemiliknya masing-masing.

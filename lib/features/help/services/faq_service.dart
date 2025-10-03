import '../../../models/faq_models.dart';

class FAQService {
  const FAQService();

  List<FAQSection> getAllFAQs() {
    return [
      _getGettingStartedFAQs(),
      _getTransactionFAQs(),
      _getCategoryFAQs(),
      _getWalletFAQs(),
      _getReportsFAQs(),
      _getTransferFAQs(),
      _getNotificationFAQs(),
      _getSettingsFAQs(),
      _getTroubleshootingFAQs(),
    ];
  }

  FAQSection _getGettingStartedFAQs() {
    return FAQSection(
      category: FAQCategory.gettingStarted,
      items: [
        const FAQItem(
          id: 'gs_001',
          question: 'Bagaimana cara memulai menggunakan Finoteku?',
          answer:
              'Setelah membuat akun, ikuti langkah-langkah berikut:\n\n'
              '1. Buat dompet pertama Anda (contoh: "Kas", "Bank BCA")\n'
              '2. Tambahkan kategori-kategori transaksi yang sesuai dengan kebutuhan\n'
              '3. Mulai mencatat transaksi harian Anda\n'
              '4. Gunakan fitur laporan untuk memonitor keuangan\n\n'
              'Tips: Mulai dengan mencatat transaksi kecil terlebih dahulu untuk membiasakan diri.',
          category: FAQCategory.gettingStarted,
          keywords: ['mulai', 'awal', 'pertama kali', 'setup'],
          priority: 10,
        ),
        const FAQItem(
          id: 'gs_002',
          question: 'Apa saja fitur utama Finoteku?',
          answer:
              'Finoteku memiliki fitur-fitur berikut:\n\n'
              '• 📝 Pencatatan transaksi (pemasukan & pengeluaran)\n'
              '• 📂 Manajemen kategori dan sub-kategori\n'
              '• 💰 Manajemen multiple dompet/akun\n'
              '• 🔄 Transfer antar dompet\n'
              '• 📊 Laporan keuangan visual dengan grafik\n'
              '• 🔔 Notifikasi pengingat\n'
              '• 🌙 Mode gelap & terang\n'
              '• 📱 Sinkronisasi cloud\n'
              '• 🔒 Keamanan data dengan enkripsi',
          category: FAQCategory.gettingStarted,
          keywords: ['fitur', 'fungsi', 'kemampuan'],
          priority: 9,
        ),
        const FAQItem(
          id: 'gs_003',
          question: 'Apakah data saya aman di Finoteku?',
          answer:
              'Ya, keamanan data adalah prioritas utama kami:\n\n'
              '• Semua data dienkripsi menggunakan standar industri\n'
              '• Menggunakan Supabase dengan keamanan enterprise-grade\n'
              '• Data hanya dapat diakses dengan akun Anda\n'
              '• Backup otomatis ke cloud\n'
              '• Tidak ada pihak ketiga yang dapat mengakses data pribadi Anda\n\n'
              'Kami tidak menyimpan informasi finansial sensitif seperti nomor rekening atau PIN.',
          category: FAQCategory.gettingStarted,
          keywords: ['aman', 'keamanan', 'privasi', 'enkripsi'],
          priority: 8,
        ),
      ],
    );
  }

  FAQSection _getTransactionFAQs() {
    return FAQSection(
      category: FAQCategory.transactions,
      items: [
        const FAQItem(
          id: 'tr_001',
          question: 'Bagaimana cara menambah transaksi baru?',
          answer:
              'Untuk menambah transaksi:\n\n'
              '1. Tap tombol "+" di halaman utama atau transaksi\n'
              '2. Pilih jenis transaksi (Pemasukan/Pengeluaran)\n'
              '3. Pilih dompet sumber\n'
              '4. Pilih kategori yang sesuai\n'
              '5. Masukkan jumlah uang\n'
              '6. Atur tanggal (default hari ini)\n'
              '7. Tambahkan catatan jika diperlukan\n'
              '8. Tap "Simpan"\n\n'
              'Tips: Gunakan catatan untuk detail tambahan seperti tempat pembelian.',
          category: FAQCategory.transactions,
          keywords: ['tambah', 'buat', 'catat', 'input'],
          priority: 10,
        ),
        const FAQItem(
          id: 'tr_002',
          question: 'Bagaimana cara mengedit atau menghapus transaksi?',
          answer:
              'Untuk mengedit transaksi:\n\n'
              '1. Buka halaman transaksi atau home\n'
              '2. Tap pada transaksi yang ingin diedit\n'
              '3. Pilih "Edit" dari menu\n'
              '4. Ubah informasi yang diperlukan\n'
              '5. Tap "Simpan"\n\n'
              'Untuk menghapus:\n'
              '1. Buka detail transaksi\n'
              '2. Tap ikon "Hapus" (🗑️)\n'
              '3. Konfirmasi penghapusan\n\n'
              '⚠️ Hati-hati: Transaksi yang dihapus tidak dapat dikembalikan.',
          category: FAQCategory.transactions,
          keywords: ['edit', 'ubah', 'hapus', 'delete'],
          priority: 8,
        ),
        const FAQItem(
          id: 'tr_003',
          question: 'Apa perbedaan antara pemasukan dan pengeluaran?',
          answer:
              'Perbedaan utama:\n\n'
              '💰 **Pemasukan (Income):**\n'
              '• Uang yang masuk ke dompet Anda\n'
              '• Menambah saldo dompet\n'
              '• Contoh: gaji, bonus, hadiah, penjualan\n'
              '• Ditampilkan dengan warna hijau\n\n'
              '💸 **Pengeluaran (Expense):**\n'
              '• Uang yang keluar dari dompet\n'
              '• Mengurangi saldo dompet\n'
              '• Contoh: belanja, makan, transport, tagihan\n'
              '• Ditampilkan dengan warna merah\n\n'
              'Pastikan memilih jenis yang tepat agar laporan akurat.',
          category: FAQCategory.transactions,
          keywords: ['pemasukan', 'pengeluaran', 'income', 'expense'],
          priority: 7,
        ),
        const FAQItem(
          id: 'tr_004',
          question: 'Bisakah saya menambah transaksi dengan tanggal masa lalu?',
          answer:
              'Ya, Anda bisa menambah transaksi dengan tanggal masa lalu:\n\n'
              '1. Saat menambah transaksi, tap bagian tanggal\n'
              '2. Pilih tanggal yang diinginkan dari kalender\n'
              '3. Lanjutkan mengisi detail transaksi\n'
              '4. Simpan transaksi\n\n'
              'Fitur ini berguna untuk:\n'
              '• Mencatat transaksi yang terlupa\n'
              '• Input data historis\n'
              '• Koreksi tanggal yang salah\n\n'
              'Laporan akan otomatis terupdate sesuai tanggal transaksi.',
          category: FAQCategory.transactions,
          keywords: ['tanggal', 'masa lalu', 'mundur', 'kemarin'],
          priority: 6,
        ),
      ],
    );
  }

  FAQSection _getCategoryFAQs() {
    return FAQSection(
      category: FAQCategory.categories,
      items: [
        const FAQItem(
          id: 'cat_001',
          question: 'Bagaimana cara membuat kategori baru?',
          answer:
              'Untuk membuat kategori baru:\n\n'
              '1. Buka menu "Akun" > "Kelola Kategori"\n'
              '2. Tap tombol "+" di pojok kanan atas\n'
              '3. Pilih jenis kategori (Pemasukan/Pengeluaran)\n'
              '4. Masukkan nama kategori\n'
              '5. Pilih ikon yang sesuai\n'
              '6. Pilih kategori induk jika ingin membuat sub-kategori\n'
              '7. Tap "Simpan"\n\n'
              'Tips: Gunakan nama yang jelas dan spesifik untuk memudahkan pencarian.',
          category: FAQCategory.categories,
          keywords: ['buat', 'tambah', 'kategori', 'baru'],
          priority: 9,
        ),
        const FAQItem(
          id: 'cat_002',
          question: 'Apa itu sub-kategori dan bagaimana cara menggunakannya?',
          answer:
              'Sub-kategori adalah kategori yang berada di bawah kategori utama:\n\n'
              '**Contoh struktur:**\n'
              '📂 Makanan (kategori utama)\n'
              '  ├── 🍽️ Makan di rumah\n'
              '  ├── 🍕 Makan di luar\n'
              '  └── ☕ Minuman\n\n'
              '**Keuntungan:**\n'
              '• Organisasi yang lebih detail\n'
              '• Laporan lebih spesifik\n'
              '• Analisis pengeluaran lebih mendalam\n\n'
              'Untuk membuat sub-kategori, pilih "Kategori Induk" saat membuat kategori baru.',
          category: FAQCategory.categories,
          keywords: ['sub', 'induk', 'hierarki', 'struktur'],
          priority: 7,
        ),
        const FAQItem(
          id: 'cat_003',
          question:
              'Bisakah saya mengubah atau menghapus kategori yang sudah ada?',
          answer:
              'Ya, Anda bisa mengubah kategori:\n\n'
              '**Mengubah kategori:**\n'
              '1. Buka "Kelola Kategori"\n'
              '2. Tap kategori yang ingin diubah\n'
              '3. Edit nama, ikon, atau kategori induk\n'
              '4. Simpan perubahan\n\n'
              '**Menghapus kategori:**\n'
              '• Kategori dengan transaksi: tidak bisa dihapus langsung\n'
              '• Solusi: sembunyikan kategori atau pindahkan transaksi ke kategori lain\n'
              '• Kategori kosong: bisa dihapus langsung\n\n'
              '⚠️ Hati-hati saat mengubah kategori yang sudah memiliki banyak transaksi.',
          category: FAQCategory.categories,
          keywords: ['ubah', 'edit', 'hapus', 'sembunyikan'],
          priority: 6,
        ),
        const FAQItem(
          id: 'cat_004',
          question: 'Apa saja contoh kategori yang baik untuk pengeluaran?',
          answer:
              'Berikut contoh kategori pengeluaran yang umum digunakan:\n\n'
              '🍽️ **Makanan & Minuman**\n'
              '  • Groceries, Makan di luar, Minuman\n\n'
              '🚗 **Transportasi**\n'
              '  • Bensin, Parkir, Ojek online, Tol\n\n'
              '🏠 **Rumah Tangga**\n'
              '  • Listrik, Air, Internet, Kebersihan\n\n'
              '👕 **Fashion & Kecantikan**\n'
              '  • Pakaian, Kosmetik, Salon\n\n'
              '💊 **Kesehatan**\n'
              '  • Obat, Dokter, Rumah sakit\n\n'
              '🎬 **Hiburan**\n'
              '  • Bioskop, Game, Streaming\n\n'
              'Sesuaikan dengan gaya hidup dan kebutuhan pribadi Anda.',
          category: FAQCategory.categories,
          keywords: ['contoh', 'template', 'ide', 'pengeluaran'],
          priority: 5,
        ),
      ],
    );
  }

  FAQSection _getWalletFAQs() {
    return FAQSection(
      category: FAQCategory.wallets,
      items: [
        const FAQItem(
          id: 'wal_001',
          question: 'Bagaimana cara menambah dompet baru?',
          answer:
              'Untuk menambah dompet baru:\n\n'
              '1. Buka menu "Akun" > "Kelola Dompet"\n'
              '2. Tap tombol "+" di pojok kanan atas\n'
              '3. Masukkan nama dompet (contoh: "BCA", "Dana", "Kas")\n'
              '4. Pilih jenis dompet (Bank, E-wallet, Tunai)\n'
              '5. Masukkan saldo awal\n'
              '6. Pilih ikon yang sesuai\n'
              '7. Tap "Simpan"\n\n'
              'Tips: Gunakan nama yang mudah dikenali dan sesuaikan dengan akun finansial nyata Anda.',
          category: FAQCategory.wallets,
          keywords: ['tambah', 'buat', 'dompet', 'baru'],
          priority: 9,
        ),
        const FAQItem(
          id: 'wal_002',
          question: 'Apa perbedaan jenis dompet (Bank, E-wallet, Tunai)?',
          answer:
              'Perbedaan jenis dompet:\n\n'
              '🏦 **Bank**\n'
              '• Rekening bank konvensional\n'
              '• Contoh: BCA, Mandiri, BRI, BNI\n'
              '• Biasanya untuk transaksi besar\n\n'
              '📱 **E-wallet**\n'
              '• Dompet digital\n'
              '• Contoh: GoPay, OVO, Dana, ShopeePay\n'
              '• Untuk transaksi online dan cashless\n\n'
              '💵 **Tunai**\n'
              '• Uang fisik\n'
              '• Dompet, kas kecil, tabungan rumah\n'
              '• Untuk transaksi sehari-hari\n\n'
              'Perbedaan ini hanya untuk organisasi, tidak mempengaruhi fungsi pencatatan.',
          category: FAQCategory.wallets,
          keywords: ['jenis', 'bank', 'ewallet', 'tunai'],
          priority: 7,
        ),
        const FAQItem(
          id: 'wal_003',
          question: 'Bagaimana cara mengatur saldo awal dompet?',
          answer:
              'Saldo awal dompet dapat diatur saat:\n\n'
              '**Membuat dompet baru:**\n'
              '• Masukkan saldo aktual saat ini\n'
              '• Pastikan sesuai dengan saldo real\n\n'
              '**Mengubah saldo yang sudah ada:**\n'
              '1. Buka "Kelola Dompet"\n'
              '2. Tap dompet yang ingin diubah\n'
              '3. Edit saldo awal\n'
              '4. Simpan perubahan\n\n'
              '⚠️ **Penting:** Perubahan saldo awal akan mempengaruhi semua laporan dan perhitungan. Gunakan dengan hati-hati.\n\n'
              'Tips: Lakukan sinkronisasi berkala dengan saldo real untuk akurasi data.',
          category: FAQCategory.wallets,
          keywords: ['saldo', 'awal', 'balance', 'ubah'],
          priority: 8,
        ),
        const FAQItem(
          id: 'wal_004',
          question: 'Bisakah saya menyembunyikan atau menghapus dompet?',
          answer:
              'Ya, Anda bisa menyembunyikan atau menghapus dompet:\n\n'
              '**Menyembunyikan dompet:**\n'
              '• Dompet tidak tampil di daftar aktif\n'
              '• Data transaksi tetap tersimpan\n'
              '• Bisa dimunculkan kembali kapan saja\n'
              '• Cocok untuk dompet yang tidak aktif\n\n'
              '**Menghapus dompet:**\n'
              '• Hanya bisa jika tidak ada transaksi\n'
              '• Data akan hilang permanen\n'
              '• Untuk dompet yang baru dibuat atau salah\n\n'
              'Cara: Buka "Kelola Dompet" > Tap dompet > Pilih "Sembunyikan" atau "Hapus"',
          category: FAQCategory.wallets,
          keywords: ['sembunyikan', 'hapus', 'hide', 'delete'],
          priority: 5,
        ),
      ],
    );
  }

  FAQSection _getReportsFAQs() {
    return FAQSection(
      category: FAQCategory.reports,
      items: [
        const FAQItem(
          id: 'rep_001',
          question: 'Bagaimana cara melihat laporan keuangan?',
          answer:
              'Untuk melihat laporan keuangan:\n\n'
              '1. Tap tab "Laporan" di menu bawah\n'
              '2. Pilih jenis laporan (Pengeluaran/Pemasukan)\n'
              '3. Pilih periode (Mingguan/Bulanan/Tahunan)\n'
              '4. Gunakan panah untuk navigasi periode\n\n'
              '**Yang bisa Anda lihat:**\n'
              '• 📊 Grafik pie untuk proporsi kategori\n'
              '• 📈 Perbandingan dengan periode sebelumnya\n'
              '• 📋 Detail per kategori\n'
              '• 🔢 Total amount dan jumlah transaksi\n\n'
              'Tap kategori "Lainnya" untuk melihat detail kategori minor.',
          category: FAQCategory.reports,
          keywords: ['laporan', 'report', 'analisis', 'grafik'],
          priority: 9,
        ),
        const FAQItem(
          id: 'rep_002',
          question: 'Apa arti warna-warna di grafik laporan?',
          answer:
              'Penjelasan warna di grafik laporan:\n\n'
              '🔵 **Biru - Makanan**: Transaksi terkait konsumsi\n'
              '🟠 **Orange - Transportasi**: Perjalanan dan kendaraan\n'
              '🟡 **Kuning - Hiburan**: Rekreasi dan hobi\n'
              '🟢 **Hijau - Kesehatan**: Medical dan wellness\n'
              '🟣 **Ungu - Belanja**: Shopping dan retail\n'
              '🔴 **Merah - Tagihan**: Utilities dan pembayaran rutin\n'
              '⚫ **Abu-abu - Lainnya**: Kategori dengan jumlah kecil\n\n'
              'Warna disesuaikan otomatis berdasarkan kategori yang paling banyak digunakan.\n\n'
              'Tips: Semakin besar bagian warna, semakin besar pengeluaran di kategori tersebut.',
          category: FAQCategory.reports,
          keywords: ['warna', 'grafik', 'pie chart', 'kategori'],
          priority: 6,
        ),
        const FAQItem(
          id: 'rep_003',
          question: 'Bagaimana cara menganalisis tren pengeluaran saya?',
          answer:
              'Untuk menganalisis tren pengeluaran:\n\n'
              '**1. Bandingkan periode:**\n'
              '• Lihat persentase perubahan vs bulan lalu\n'
              '• Hijau = menurun, Merah = meningkat\n\n'
              '**2. Analisis per kategori:**\n'
              '• Kategori mana yang mendominasi?\n'
              '• Apakah proporsional dengan kebutuhan?\n\n'
              '**3. Track konsistensi:**\n'
              '• Navigasi antar bulan untuk melihat pola\n'
              '• Identifikasi pengeluaran musiman\n\n'
              '**4. Set target:**\n'
              '• Gunakan data bulan sebelumnya sebagai benchmark\n'
              '• Fokus kurangi kategori yang tidak prioritas\n\n'
              'Tips: Review laporan secara rutin untuk kontrol keuangan yang lebih baik.',
          category: FAQCategory.reports,
          keywords: ['analisis', 'tren', 'pattern', 'kontrol'],
          priority: 7,
        ),
      ],
    );
  }

  FAQSection _getTransferFAQs() {
    return FAQSection(
      category: FAQCategory.transfers,
      items: [
        const FAQItem(
          id: 'trf_001',
          question: 'Bagaimana cara melakukan transfer antar dompet?',
          answer:
              'Untuk transfer antar dompet:\n\n'
              '1. Tap tombol "+" di halaman utama\n'
              '2. Pilih "Transfer Antar Dompet"\n'
              '3. Pilih dompet sumber (asal uang)\n'
              '4. Pilih dompet tujuan (tempat uang dipindah)\n'
              '5. Masukkan jumlah yang akan ditransfer\n'
              '6. Tambahkan biaya admin jika ada\n'
              '7. Atur tanggal transfer\n'
              '8. Tambahkan catatan (opsional)\n'
              '9. Tap "Transfer"\n\n'
              'Transfer akan otomatis membuat 2 transaksi: pengeluaran di dompet sumber dan pemasukan di dompet tujuan.',
          category: FAQCategory.transfers,
          keywords: ['transfer', 'pindah', 'antar dompet'],
          priority: 8,
        ),
        const FAQItem(
          id: 'trf_002',
          question: 'Apa itu biaya admin dalam transfer dan kapan digunakan?',
          answer:
              'Biaya admin adalah biaya tambahan saat transfer:\n\n'
              '**Kapan digunakan:**\n'
              '• Transfer antar bank (biaya admin bank)\n'
              '• Top up e-wallet dengan kartu kredit\n'
              '• Tarik tunai dari ATM berbeda bank\n'
              '• Transfer internasional\n\n'
              '**Cara kerja:**\n'
              '• Dicatat sebagai pengeluaran terpisah\n'
              '• Dikurangi dari dompet sumber\n'
              '• Tidak masuk ke dompet tujuan\n\n'
              '**Contoh:**\n'
              'Transfer Rp 100.000 + admin Rp 2.500\n'
              '• Dompet sumber: -Rp 102.500\n'
              '• Dompet tujuan: +Rp 100.000\n'
              '• Biaya admin: Rp 2.500 (pengeluaran)',
          category: FAQCategory.transfers,
          keywords: ['biaya', 'admin', 'fee', 'ongkos'],
          priority: 6,
        ),
        const FAQItem(
          id: 'trf_003',
          question: 'Bisakah saya mengedit atau membatalkan transfer?',
          answer:
              'Ya, Anda bisa mengedit atau membatalkan transfer:\n\n'
              '**Mengedit transfer:**\n'
              '1. Buka halaman transaksi\n'
              '2. Cari transaksi transfer (ditandai ikon ↔️)\n'
              '3. Tap untuk membuka detail\n'
              '4. Pilih "Edit Transfer"\n'
              '5. Ubah informasi yang diperlukan\n'
              '6. Simpan perubahan\n\n'
              '**Membatalkan transfer:**\n'
              '1. Buka detail transfer\n'
              '2. Tap "Batalkan Transfer"\n'
              '3. Konfirmasi pembatalan\n\n'
              '⚠️ Hati-hati: Perubahan akan mempengaruhi saldo kedua dompet yang terlibat.',
          category: FAQCategory.transfers,
          keywords: ['edit', 'batal', 'ubah', 'cancel'],
          priority: 5,
        ),
      ],
    );
  }

  FAQSection _getNotificationFAQs() {
    return FAQSection(
      category: FAQCategory.notifications,
      items: [
        const FAQItem(
          id: 'not_001',
          question: 'Bagaimana cara mengatur notifikasi pengingat?',
          answer:
              'Untuk mengatur notifikasi pengingat:\n\n'
              '1. Buka menu "Akun" > "Notifikasi"\n'
              '2. Aktifkan toggle "Notifikasi Pengingat"\n'
              '3. Atur waktu notifikasi pagi (default 12:00)\n'
              '4. Atur waktu notifikasi sore (default 19:00)\n'
              '5. Customize pesan pengingat jika diinginkan\n'
              '6. Simpan pengaturan\n\n'
              '**Jenis pengingat:**\n'
              '• Pengingat mencatat transaksi\n'
              '• Reminder review keuangan\n'
              '• Notifikasi target budget (coming soon)\n\n'
              'Pastikan notifikasi diizinkan di pengaturan sistem.',
          category: FAQCategory.notifications,
          keywords: ['notifikasi', 'pengingat', 'reminder', 'alert'],
          priority: 7,
        ),
        const FAQItem(
          id: 'not_002',
          question: 'Mengapa saya tidak menerima notifikasi?',
          answer:
              'Beberapa kemungkinan penyebab:\n\n'
              '**Periksa pengaturan aplikasi:**\n'
              '• Pastikan notifikasi diaktifkan di menu Akun\n'
              '• Cek waktu pengingat sudah sesuai\n\n'
              '**Periksa pengaturan sistem:**\n'
              '• Buka Settings > Apps > Finoteku > Notifications\n'
              '• Pastikan "Allow notifications" aktif\n'
              '• Periksa "Do Not Disturb" tidak aktif\n\n'
              '**Periksa kondisi khusus:**\n'
              '• Aplikasi tidak dibuka dalam waktu lama\n'
              '• Mode hemat baterai terlalu agresif\n'
              '• Storage penuh atau RAM rendah\n\n'
              'Solusi: Restart aplikasi dan coba atur ulang notifikasi.',
          category: FAQCategory.notifications,
          keywords: ['tidak', 'masalah', 'troubleshoot', 'setting'],
          priority: 6,
        ),
        const FAQItem(
          id: 'not_003',
          question: 'Bisakah saya mengubah pesan notifikasi?',
          answer:
              'Ya, Anda bisa mengcustomize pesan notifikasi:\n\n'
              '1. Buka menu "Akun" > "Notifikasi"\n'
              '2. Scroll ke bagian "Pesan Kustom"\n'
              '3. Edit pesan notifikasi pagi\n'
              '4. Edit pesan notifikasi sore\n'
              '5. Simpan perubahan\n\n'
              '**Tips pesan yang efektif:**\n'
              '• Gunakan kalimat motivasi\n'
              '• Singkat dan jelas\n'
              '• Sesuaikan dengan gaya personal\n'
              '• Tambahkan emoji untuk visual menarik\n\n'
              '**Contoh pesan:**\n'
              '• "Jangan lupa catat pengeluaran hari ini! 💰"\n'
              '• "Review keuangan yuk! 📊"\n'
              '• "Budget masih aman? Cek sekarang! ✅"',
          category: FAQCategory.notifications,
          keywords: ['pesan', 'custom', 'ubah', 'edit'],
          priority: 4,
        ),
      ],
    );
  }

  FAQSection _getSettingsFAQs() {
    return FAQSection(
      category: FAQCategory.settings,
      items: [
        const FAQItem(
          id: 'set_001',
          question: 'Bagaimana cara mengubah tema aplikasi?',
          answer:
              'Untuk mengubah tema aplikasi:\n\n'
              '1. Buka menu "Akun" di tab bawah\n'
              '2. Scroll ke bagian "Tampilan"\n'
              '3. Tap "Tema Aplikasi"\n'
              '4. Pilih salah satu:\n'
              '   • Terang (Light mode)\n'
              '   • Gelap (Dark mode)\n'
              '   • Ikuti sistem (Auto)\n\n'
              '**Keuntungan mode gelap:**\n'
              '• Hemat baterai pada layar OLED\n'
              '• Lebih nyaman di mata saat malam\n'
              '• Tampilan modern dan elegan\n\n'
              'Pengaturan akan otomatis tersimpan dan diterapkan.',
          category: FAQCategory.settings,
          keywords: ['tema', 'dark mode', 'light mode', 'tampilan'],
          priority: 8,
        ),
        const FAQItem(
          id: 'set_002',
          question: 'Bagaimana cara backup dan restore data?',
          answer:
              'Finoteku menggunakan sinkronisasi cloud otomatis:\n\n'
              '**Backup otomatis:**\n'
              '• Data tersimpan real-time ke cloud\n'
              '• Menggunakan akun login Anda\n'
              '• Tidak perlu backup manual\n'
              '• Enkripsi end-to-end\n\n'
              '**Restore data:**\n'
              '• Login dengan akun yang sama\n'
              '• Data akan otomatis sinkron\n'
              '• Berlaku lintas device\n\n'
              '**Tips keamanan:**\n'
              '• Jangan lupa password akun\n'
              '• Pastikan koneksi internet stabil\n'
              '• Logout dari device yang tidak digunakan\n\n'
              'Data aman tersimpan selama akun aktif.',
          category: FAQCategory.settings,
          keywords: ['backup', 'restore', 'sinkron', 'cloud'],
          priority: 9,
        ),
        const FAQItem(
          id: 'set_003',
          question: 'Bagaimana cara keluar dari akun atau mengganti akun?',
          answer:
              'Untuk logout atau ganti akun:\n\n'
              '**Logout dari akun:**\n'
              '1. Buka menu "Akun"\n'
              '2. Scroll ke bawah\n'
              '3. Tap "Keluar dari Akun"\n'
              '4. Konfirmasi logout\n\n'
              '**Ganti akun:**\n'
              '1. Logout dari akun saat ini\n'
              '2. Di halaman login, masukkan kredensial akun baru\n'
              '3. Login dengan akun yang diinginkan\n\n'
              '⚠️ **Penting:**\n'
              '• Data tidak akan hilang saat logout\n'
              '• Login kembali akan memulihkan semua data\n'
              '• Pastikan ingat password sebelum logout\n\n'
              'Data masing-masing akun tersimpan terpisah dan aman.',
          category: FAQCategory.settings,
          keywords: ['logout', 'keluar', 'ganti', 'akun'],
          priority: 6,
        ),
      ],
    );
  }

  FAQSection _getTroubleshootingFAQs() {
    return FAQSection(
      category: FAQCategory.troubleshooting,
      items: [
        const FAQItem(
          id: 'tbs_001',
          question:
              'Data saya hilang atau tidak sinkron, bagaimana cara mengatasinya?',
          answer:
              'Jika data hilang atau tidak sinkron:\n\n'
              '**Langkah pemecahan:**\n'
              '1. Periksa koneksi internet\n'
              '2. Logout dan login kembali\n'
              '3. Restart aplikasi\n'
              '4. Clear cache aplikasi\n'
              '5. Update aplikasi ke versi terbaru\n\n'
              '**Pencegahan:**\n'
              '• Pastikan koneksi stabil saat input\n'
              '• Jangan force close aplikasi saat sinkron\n'
              '• Update aplikasi secara berkala\n'
              '• Login konsisten dengan akun yang sama\n\n'
              '⚠️ Jika masih bermasalah, hubungi support dengan detail:\n'
              '• Versi aplikasi\n'
              '• Waktu kejadian\n'
              '• Langkah yang dilakukan',
          category: FAQCategory.troubleshooting,
          keywords: ['hilang', 'sinkron', 'data', 'masalah'],
          priority: 10,
        ),
        const FAQItem(
          id: 'tbs_002',
          question: 'Aplikasi sering crash atau force close, apa solusinya?',
          answer:
              'Solusi untuk aplikasi yang sering crash:\n\n'
              '**Solusi umum:**\n'
              '1. Restart aplikasi\n'
              '2. Restart device\n'
              '3. Update aplikasi\n'
              '4. Clear cache dan data aplikasi\n'
              '5. Reinstall aplikasi\n\n'
              '**Penyebab umum:**\n'
              '• RAM device terlalu penuh\n'
              '• Storage hampir penuh\n'
              '• Versi Android terlalu lama\n'
              '• Konflik dengan aplikasi lain\n\n'
              '**Pencegahan:**\n'
              '• Tutup aplikasi lain yang tidak perlu\n'
              '• Bersihkan storage secara berkala\n'
              '• Update OS Android\n'
              '• Gunakan device dengan RAM minimal 3GB\n\n'
              'Jika masih crash, laporkan ke developer dengan detail device.',
          category: FAQCategory.troubleshooting,
          keywords: ['crash', 'force close', 'error', 'bug'],
          priority: 8,
        ),
        const FAQItem(
          id: 'tbs_003',
          question:
              'Saldo dompet tidak sesuai dengan transaksi, bagaimana cara memperbaikinya?',
          answer:
              'Jika saldo tidak sesuai dengan transaksi:\n\n'
              '**Langkah diagnosis:**\n'
              '1. Cek semua transaksi di dompet tersebut\n'
              '2. Pastikan tidak ada transaksi ganda\n'
              '3. Periksa transaksi transfer keluar/masuk\n'
              '4. Verifikasi saldo awal dompet\n\n'
              '**Kemungkinan penyebab:**\n'
              '• Saldo awal salah saat setup\n'
              '• Transfer tidak tercatat lengkap\n'
              '• Edit transaksi yang tidak disadari\n'
              '• Bug sinkronisasi data\n\n'
              '**Solusi:**\n'
              '• Koreksi saldo awal jika perlu\n'
              '• Hapus dan input ulang transaksi bermasalah\n'
              '• Lakukan recalculation dengan logout-login\n\n'
              '💡 Tips: Bandingkan dengan saldo real untuk memastikan akurasi.',
          category: FAQCategory.troubleshooting,
          keywords: ['saldo', 'salah', 'tidak sesuai', 'balance'],
          priority: 9,
        ),
        const FAQItem(
          id: 'tbs_004',
          question: 'Bagaimana cara menghubungi support jika ada masalah?',
          answer:
              'Untuk menghubungi support:\n\n'
              '**Melalui aplikasi:**\n'
              '1. Buka menu "Akun" > "Bantuan & FAQ"\n'
              '2. Jika tidak menemukan solusi, tap "Hubungi Support"\n'
              '3. Isi form dengan detail masalah\n'
              '4. Lampirkan screenshot jika perlu\n\n'
              '**Melalui email:**\n'
              '• Email: support@finoteku.com\n'
              '• Subject: [Bug Report] atau [Feature Request]\n\n'
              '**Melalui GitHub:**\n'
              '• Repository: github.com/ridhoarmand/finoteku\n'
              '• Buat issue dengan template yang disediakan\n\n'
              '**Info yang perlu disertakan:**\n'
              '• Versi aplikasi\n'
              '• Model device dan OS\n'
              '• Langkah reproduksi masalah\n'
              '• Screenshot/video jika memungkinkan',
          category: FAQCategory.troubleshooting,
          keywords: ['support', 'bantuan', 'kontak', 'help'],
          priority: 7,
        ),
      ],
    );
  }
}

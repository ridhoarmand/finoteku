import 'package:finoteku/models/category.dart';

/// Daftar saran kategori umum (global) untuk memudahkan pengguna.
/// Ini hanya referensi (tidak tersimpan di database) dan dapat digunakan
/// sebagai quick-pick saat membuat kategori baru.
class CategorySuggestions {
  static const List<String> income = [
    'Gaji',
    'Bonus',
    'Freelance',
    'Investasi',
    'Bunga',
    'Hadiah',
    'Penjualan',
    'Lainnya',
  ];

  static const List<String> expense = [
    'Makan & Minum',
    'Belanja Harian',
    'Transportasi',
    'Bensin',
    'Parkir & Tol',
    'Sewa/KPR',
    'Listrik',
    'Air',
    'Internet & Pulsa',
    'Langganan',
    'Kesehatan',
    'Obat-obatan',
    'Asuransi',
    'Pendidikan',
    'Hiburan',
    'Hobi',
    'Hadiah',
    'Donasi',
    'Perawatan Rumah',
    'Perawatan Pribadi',
    'Hewan Peliharaan',
    'Pajak & Biaya Bank',
    'Liburan',
    'Lainnya',
  ];

  /// Saran sub-kategori umum berdasarkan parent (untuk UX cepat)
  /// Key dicocokkan case-insensitive terhadap nama parent.
  static const Map<String, List<String>> expenseChildren = {
    'Makan & Minum': [
      'Sarapan',
      'Makan Siang',
      'Makan Malam',
      'Kopi',
      'Camilan',
      'Pesan Antar',
    ],
    'Belanja Harian': [
      'Sayur',
      'Buah',
      'Susu & Telur',
      'Kebutuhan Rumah',
      'Alat Kebersihan',
    ],
    'Transportasi': [
      'Bensin',
      'Parkir & Tol',
      'Bus/Kereta',
      'Ojek Online',
      'Perawatan Kendaraan',
    ],
    'Perawatan Rumah': [
      'Perbaikan',
      'Peralatan',
      'Kebersihan',
    ],
    'Kesehatan': [
      'Obat-obatan',
      'Dokter',
      'Vitamin',
      'Asuransi Kesehatan',
    ],
    'Pendidikan': [
      'Buku',
      'Kursus',
      'Uang Sekolah',
    ],
    'Hiburan': [
      'Bioskop',
      'Game',
      'Musik',
      'Event',
    ],
    'Perawatan Pribadi': [
      'Skincare',
      'Haircut',
      'Salon',
      'Gym',
    ],
    'Hewan Peliharaan': [
      'Makanan',
      'Grooming',
      'Vaksin',
    ],
    'Pajak & Biaya Bank': [
      'Biaya Admin',
      'Pajak',
      'Biaya Transfer',
    ],
    'Liburan': [
      'Tiket',
      'Hotel',
      'Oleh-oleh',
    ],
    'Langganan': [
      'Netflix',
      'Spotify',
      'iCloud',
      'YouTube',
    ],
  };

  static const Map<String, List<String>> incomeChildren = {
    'Gaji': [
      'Tunjangan',
      'Bonus',
      'Lembur',
    ],
    'Investasi': [
      'Dividen',
      'Bunga',
      'Capital Gain',
      'Sewa Aset',
    ],
    'Freelance': [
      'Project',
      'Retainer',
      'Tip',
    ],
    'Penjualan': [
      'Barang Bekas',
      'Produk Digital',
    ],
  };

  /// Ambil saran berdasarkan tipe kategori
  static List<String> forType(CategoryType type) {
    return switch (type) {
      CategoryType.income => income,
      CategoryType.expense => expense,
    };
  }

  /// Sub-saran berdasarkan parent (nama lengkap). Jika tidak ada kecocokan, kembalikan []
  static List<String> childrenForParentName(CategoryType type, String parentName) {
    final key = parentName.trim().toLowerCase();
    final source = type == CategoryType.expense ? expenseChildren : incomeChildren;
    for (final entry in source.entries) {
      if (entry.key.toLowerCase() == key) return entry.value;
    }
    return const [];
  }
}

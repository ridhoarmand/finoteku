typedef StrMap = Map<String, String>;

final StrMap transactionStringsEn = {
  'transactions_title': 'Transactions',
  'search_transactions': 'Search transactions...',
  'transactions_empty_title': 'No Transactions Yet',
  'transactions_empty_sub': 'Start by adding your first transaction',
  'error_loading_transactions': 'Error loading transactions: {error}',
  'transaction_details_title': 'Transaction Details',
  'transaction_not_found': 'Transaction not found',
  'delete_transaction_title': 'Delete Transaction',
  'delete_transaction_confirm':
      'Are you sure you want to delete this transaction? This action cannot be undone.',
  'transaction_deleted_successfully': 'Transaction deleted successfully',
  'error_deleting_transaction': 'Error deleting transaction: {error}',
  'wallet_label': 'Wallet',
  // Add transaction form
  'add_transaction_login_required':
      'You must be logged in to add a transaction',
  'add_transaction_title': 'Add Transaction',
  'edit_transaction_title': 'Edit Transaction',
  'add_transaction_save': 'Save Transaction',
  'add_transaction_subtitle': 'Record your income or expense',
  'add_transfer_subtitle': 'Move money between wallets',
  'transaction_saved_success': 'Transaction saved successfully',
  'transaction_updated_success': 'Transaction updated successfully',
  'transfer_saved_success': 'Transfer saved successfully',
  'transfer_updated_success': 'Transfer updated successfully',
  'error_saving_transaction': 'Error saving transaction',
  'select_category_first': 'Please select a category first',
  'select_category': 'Select Category',
  // Additional transaction related
  'home_transactions_empty': 'No transactions yet',
  'home_transactions_empty_sub': 'Start by adding your first transaction',
  'add_transaction': 'Add Transaction',
  'error_loading_balance': 'Error loading balance',
  'wallet_all_wallets': 'All Wallets',
  'wallet_all_short': 'All',
  'update_transaction_button': 'Update Transaction',
  'add_transaction_button': 'Add Transaction',
  'transfer_internal_title': 'Transfer between my wallets',
  'transfer_internal_subtitle':
      'Move balance between wallets (optional admin fee)',
  'source_destination_same_error':
      'Source and destination wallet cannot be the same',
  'please_select_wallet': 'Please select a wallet',
  'please_select_destination_wallet': 'Please select destination wallet',
  'please_select_category': 'Please select a category',
  'choose_transaction_category': 'Choose transaction category',
  'select_category_title': 'Select Category',
  // Date section
  'transaction_date_title': 'Transaction Date',
  'date_today': 'Today',
  'date_yesterday': 'Yesterday',
  // Amount section
  'amount_title': 'Amount',
  'amount_hint': '0',
  'amount_validation_empty': 'Please enter an amount',
  'amount_validation_invalid': 'Please enter a valid amount',
  // Notes section
  'notes_title': 'Notes (Optional)',
  'notes_hint': 'Add transaction details...',
  // Transfer fee section
  'fee_title': 'Admin Fee (optional)',
  'fee_hint': '0.00',
  'fee_category_title': 'Fee Category (Expense)',
  'fee_category_subtitle': 'Required if fee > 0',
  'fee_category_required_error': 'Fee category (Expense) required if fee > 0',
  // Wallet section
  'select_wallet_title': 'Select Wallet',
  'choose_wallet_subtitle': 'Choose wallet for transaction',
  'wallet_balance_prefix': 'Balance: ',
};

final StrMap transactionStringsId = {
  'transactions_title': 'Transaksi',
  'search_transactions': 'Cari transaksi...',
  'transactions_empty_title': 'Belum Ada Transaksi',
  'transactions_empty_sub': 'Mulai dengan menambahkan transaksi pertama Anda',
  'error_loading_transactions': 'Gagal memuat transaksi: {error}',
  'transaction_details_title': 'Detail Transaksi',
  'transaction_not_found': 'Transaksi tidak ditemukan',
  'delete_transaction_title': 'Hapus Transaksi',
  'delete_transaction_confirm':
      'Yakin ingin menghapus transaksi ini? Tindakan ini tidak dapat dibatalkan.',
  'transaction_deleted_successfully': 'Transaksi berhasil dihapus',
  'error_deleting_transaction': 'Gagal menghapus transaksi: {error}',
  'wallet_label': 'Dompet',
  // Add transaction form
  'add_transaction_login_required':
      'Anda harus login untuk menambahkan transaksi',
  'add_transaction_title': 'Tambah Transaksi',
  'edit_transaction_title': 'Edit Transaksi',
  'add_transaction_save': 'Simpan Transaksi',
  'add_transaction_subtitle': 'Catat pemasukan atau pengeluaran Anda',
  'add_transfer_subtitle': 'Pindahkan uang antar dompet',
  'transaction_saved_success': 'Transaksi berhasil disimpan',
  'transaction_updated_success': 'Transaksi berhasil diperbarui',
  'transfer_saved_success': 'Transfer berhasil disimpan',
  'transfer_updated_success': 'Transfer berhasil diperbarui',
  'error_saving_transaction': 'Gagal menyimpan transaksi',
  'select_category_first': 'Silakan pilih kategori terlebih dahulu',
  'select_category': 'Pilih Kategori',
  // Additional transaction related
  'home_transactions_empty': 'Belum ada transaksi',
  'home_transactions_empty_sub':
      'Mulai dengan menambahkan transaksi pertama Anda',
  'add_transaction': 'Tambah Transaksi',
  'error_loading_balance': 'Gagal memuat saldo',
  'wallet_all_wallets': 'Semua Dompet',
  'wallet_all_short': 'Semua',
  'update_transaction_button': 'Perbarui Transaksi',
  'add_transaction_button': 'Tambah Transaksi',
  'transfer_internal_title': 'Transfer antar wallet saya',
  'transfer_internal_subtitle':
      'Pindahkan saldo antar wallet (opsional biaya admin)',
  'source_destination_same_error': 'Wallet sumber dan tujuan tidak boleh sama',
  'please_select_wallet': 'Silakan pilih wallet',
  'please_select_destination_wallet': 'Pilih wallet tujuan',
  'please_select_category': 'Silakan pilih kategori',
  'choose_transaction_category': 'Pilih kategori transaksi',
  'select_category_title': 'Pilih Kategori',
  // Date section
  'transaction_date_title': 'Tanggal Transaksi',
  'date_today': 'Hari Ini',
  'date_yesterday': 'Kemarin',
  // Amount section
  'amount_title': 'Nominal',
  'amount_hint': '0',
  'amount_validation_empty': 'Silakan masukkan nominal',
  'amount_validation_invalid': 'Silakan masukkan nominal yang valid',
  // Notes section
  'notes_title': 'Catatan (Opsional)',
  'notes_hint': 'Tambahkan detail transaksi...',
  // Transfer fee section
  'fee_title': 'Biaya Admin (opsional)',
  'fee_hint': '0.00',
  'fee_category_title': 'Kategori Biaya (Expense)',
  'fee_category_subtitle': 'Diperlukan jika biaya > 0',
  'fee_category_required_error':
      'Kategori biaya (Expense) diperlukan jika biaya > 0',
  // Wallet section
  'select_wallet_title': 'Pilih Wallet',
  'choose_wallet_subtitle': 'Pilih wallet untuk transaksi',
  'wallet_balance_prefix': 'Saldo: ',
};

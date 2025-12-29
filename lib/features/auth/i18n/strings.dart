// Auth feature i18n strings
// English translations
const Map<String, String> authStringsEn = {
  // Login screen
  'login_title': 'Login',
  'email_label': 'Email',
  'password_label': 'Password',
  'login_button': 'Login',
  'forgot_password': 'Forgot Password?',
  'create_new_account': 'Create New Account',
  'exit_app_title': 'Exit App',
  'exit_app_message': 'Are you sure you want to exit the app?',
  'cancel': 'Cancel',
  'exit': 'Exit',
  'dismiss': 'Dismiss',

  // Register screen
  'register_title': 'Create Account',
  'register_header_title': 'Join Finoteku',
  'register_header_subtitle':
      'Create your account to start managing your finances',
  'full_name_label': 'Full Name',
  'confirm_password_label': 'Confirm Password',
  'create_account_button': 'Create Account',
  'already_have_account': 'Already have an account? ',
  'sign_in': 'Sign In',
  'registration_failed': 'Registration failed',
  'registration_success':
      'Registration successful! Please check your email to verify your account.',

  // Forgot password screen
  'reset_password_title': 'Reset Password',
  'reset_password_description':
      'Enter your email address and we\'ll send you a link to reset your password.',
  'send_reset_link': 'Send Reset Link',
  'resend_email': 'Resend Email',
  'back_to_login': 'Back to Login',
  'reset_email_sent': 'Reset email sent successfully!',
  'failed_to_send_reset_email': 'Failed to send reset email',

  // Validation messages
  'email_required': 'Email is required',
  'email_invalid': 'Please enter a valid email',
  'password_required': 'Password is required',
  'password_min_length': 'Password must be at least 6 characters',
  'full_name_required': 'Full name is required',
  'confirm_password_required': 'Please confirm your password',
  'passwords_do_not_match': 'Passwords do not match',

  // Error messages
  'invalid_email_password': 'Invalid email or password',
  'user_not_found': 'User not found',
  'wrong_password': 'Wrong password',
  'email_already_in_use': 'Email is already in use',
  'weak_password': 'Password is too weak',
  'network_error': 'Network error. Please check your connection.',
  'unknown_error': 'An unknown error occurred',
};

// Indonesian translations
const Map<String, String> authStringsId = {
  // Login screen
  'login_title': 'Masuk',
  'email_label': 'Email',
  'password_label': 'Kata Sandi',
  'login_button': 'Masuk',
  'forgot_password': 'Lupa Kata Sandi?',
  'create_new_account': 'Buat Akun Baru',
  'exit_app_title': 'Keluar Aplikasi',
  'exit_app_message': 'Apakah Anda yakin ingin keluar dari aplikasi?',
  'cancel': 'Batal',
  'exit': 'Keluar',
  'dismiss': 'Tutup',

  // Register screen
  'register_title': 'Buat Akun',
  'register_header_title': 'Bergabung dengan Finoteku',
  'register_header_subtitle': 'Buat akun Anda untuk mulai mengelola keuangan',
  'full_name_label': 'Nama Lengkap',
  'confirm_password_label': 'Konfirmasi Kata Sandi',
  'create_account_button': 'Buat Akun',
  'already_have_account': 'Sudah punya akun? ',
  'sign_in': 'Masuk',
  'registration_failed': 'Pendaftaran gagal',
  'registration_success':
      'Pendaftaran berhasil! Periksa email Anda untuk verifikasi akun.',

  // Forgot password screen
  'reset_password_title': 'Reset Kata Sandi',
  'reset_password_description':
      'Masukkan alamat email Anda dan kami akan mengirimkan link untuk mereset kata sandi.',
  'send_reset_link': 'Kirim Link Reset',
  'resend_email': 'Kirim Ulang Email',
  'back_to_login': 'Kembali ke Login',
  'reset_email_sent': 'Email reset berhasil dikirim!',
  'failed_to_send_reset_email': 'Gagal mengirim email reset',

  // Validation messages
  'email_required': 'Email harus diisi',
  'email_invalid': 'Silakan masukkan email yang valid',
  'password_required': 'Kata sandi harus diisi',
  'password_min_length': 'Kata sandi minimal 6 karakter',
  'full_name_required': 'Nama lengkap harus diisi',
  'confirm_password_required': 'Silakan konfirmasi kata sandi Anda',
  'passwords_do_not_match': 'Kata sandi tidak cocok',

  // Error messages
  'invalid_email_password': 'Email atau kata sandi tidak valid',
  'user_not_found': 'Pengguna tidak ditemukan',
  'wrong_password': 'Kata sandi salah',
  'email_already_in_use': 'Email sudah digunakan',
  'weak_password': 'Kata sandi terlalu lemah',
  'network_error': 'Kesalahan jaringan. Silakan periksa koneksi Anda.',
  'unknown_error': 'Terjadi kesalahan yang tidak diketahui',
};

// Export language maps
const Map<String, Map<String, String>> strings = {
  'en': authStringsEn,
  'id': authStringsId,
};

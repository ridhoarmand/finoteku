import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Stub sederhana karena fitur offline & auto sync sudah dihapus.
/// TODO: Hapus seluruh file & referensi provider setelah UI tidak lagi memakainya.
final connectivityServiceProvider = Provider<ConnectivityService>((ref) => ConnectivityService());
final connectionStatusProvider = StreamProvider<bool>((ref) async* { yield true; });

class ConnectivityService {
  Stream<bool> get connectionStream async* { yield true; }
  Future<bool> get isConnected async => true; // Selalu dianggap online
  Future<void> refreshConnectivity() async {}
  Future<String> getConnectionType() async => 'AlwaysOnline';
  void dispose() {}
}

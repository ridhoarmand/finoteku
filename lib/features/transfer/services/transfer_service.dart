import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/errors/failure.dart';
import 'supabase_transfer_service.dart';
import '../models/transfer_models.dart';

final transferServiceProvider = Provider<TransferService>((ref) {
  final supa = ref.watch(supabaseTransferServiceProvider);
  return TransferService(supa);
});

class TransferService {
  final SupabaseTransferService _remote;
  TransferService(this._remote);

  Future<String> transferBetweenWallets(String userId, CreateWalletTransferRequest req) async {
    if (req.fromWalletId == req.toWalletId) {
      throw ValidationFailure('Wallet sumber dan tujuan tidak boleh sama');
    }
    if (req.amount <= 0) {
      throw ValidationFailure('Jumlah transfer harus lebih dari 0');
    }
    final id = await _remote.createWalletTransfer(userId, req);
    return id;
  }
}

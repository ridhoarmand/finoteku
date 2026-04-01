import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/errors/failure.dart';
import 'supabase_transfer_service.dart';
import '../models/transfer_models.dart';
import '../models/transfer.dart';

final transferServiceProvider = Provider<TransferService>((ref) {
  final supa = ref.watch(supabaseTransferServiceProvider);
  return TransferService(supa);
});

class TransferService {
  final SupabaseTransferService _remote;
  TransferService(this._remote);

  Future<String> transferBetweenWallets(
    String userId,
    CreateWalletTransferRequest req,
  ) async {
    if (req.fromWalletId == req.toWalletId) {
      throw ValidationFailure('Wallet sumber dan tujuan tidak boleh sama');
    }
    if (req.amount <= 0) {
      throw ValidationFailure('Jumlah transfer harus lebih dari 0');
    }
    final id = await _remote.createWalletTransfer(userId, req);
    return id;
  }

  Future<Transfer?> getById(String userId, String transferId) =>
      _remote.getTransferById(userId, transferId);

  Future<void> delete(String userId, String transferId) async {
    await _remote.deleteTransfer(userId, transferId);
  }

  Future<Transfer> update(
    String userId,
    String transferId, {
    String? fromWalletId,
    String? toWalletId,
    double? amount,
    String? notes,
    DateTime? date,
  }) async {
    if (fromWalletId != null &&
        toWalletId != null &&
        fromWalletId == toWalletId) {
      throw ValidationFailure('Wallet sumber dan tujuan tidak boleh sama');
    }
    if (amount != null && amount <= 0) {
      throw ValidationFailure('Jumlah transfer harus lebih dari 0');
    }
    return _remote.updateTransfer(
      userId,
      transferId,
      fromWalletId: fromWalletId,
      toWalletId: toWalletId,
      amount: amount,
      notes: notes,
      date: date,
    );
  }
}

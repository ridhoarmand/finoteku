import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/wallet.dart';
import '../../../services/supabase_service.dart';

// Provider untuk SupabaseWalletService
final supabaseWalletServiceProvider = Provider<SupabaseWalletService>((ref) {
  final supabase = ref.watch(supabaseProvider);
  return SupabaseWalletService(supabase);
});

class SupabaseWalletService {
  final SupabaseClient _supabase;

  SupabaseWalletService(this._supabase);

    // Ambil semua wallet user dari server
  Future<List<Wallet>> getWallets(String userId) async {
    try {
      final response = await _supabase
          .from('wallets')
          .select('*')
          .eq('user_id', userId);

      // Handle empty result
      if (response.isEmpty) {
        print('ℹ️ No wallets found in server for user: $userId');
        return [];
      }

      return (response as List)
          .map((item) => Wallet.fromJson(_convertFromSupabase(item)))
          .toList();
    } catch (e) {
      print('❌ Error fetching wallets from server: $e');
      throw Exception('Failed to fetch wallets: $e');
    }
  }

  // Ambil wallet by ID dari server
  Future<Wallet?> getWallet(String walletId, String userId) async {
    try {
      final response = await _supabase
          .from('wallets')
          .select('*')
          .eq('id', walletId)
          .eq('user_id', userId)
          .single();

      return Wallet.fromJson(_convertFromSupabase(response));
    } catch (e) {
      if (e.toString().contains('No rows found') || 
          e.toString().contains('multiple (or no) rows returned') ||
          e.toString().contains('0 rows')) {
        print('ℹ️ Wallet not found in server: $walletId');
        return null;
      }
      print('❌ Error fetching wallet from server: $e');
      throw Exception('Failed to fetch wallet: $e');
    }
  }

  // Buat wallet baru di server
  Future<Wallet> createWallet(String userId, CreateWalletRequest request) async {
    try {
      final data = {
        'user_id': userId,
        'name': request.name,
        'balance': request.initialBalance,
        'currency': request.currency,
        'is_active': true,
      };

      final response = await _supabase
          .from('wallets')
          .insert(data)
          .select()
          .single();

      return Wallet.fromJson(_convertFromSupabase(response));
    } catch (e) {
      throw Exception('Failed to create wallet: $e');
    }
  }

  // Update wallet di server
  Future<Wallet> updateWallet(String walletId, String userId, UpdateWalletRequest request) async {
    try {
      final data = <String, dynamic>{};
      if (request.name != null) data['name'] = request.name;
      if (request.balance != null) data['balance'] = request.balance;
      if (request.currency != null) data['currency'] = request.currency;
      if (request.isActive != null) data['is_active'] = request.isActive;

      if (data.isEmpty) {
        throw Exception('No data to update');
      }

      final response = await _supabase
          .from('wallets')
          .update(data)
          .eq('id', walletId)
          .eq('user_id', userId)
          .select()
          .single();

      return Wallet.fromJson(_convertFromSupabase(response));
    } catch (e) {
      throw Exception('Failed to update wallet: $e');
    }
  }

  // Hapus wallet di server
  Future<void> deleteWallet(String walletId, String userId) async {
    try {
      await _supabase
          .from('wallets')
          .delete()
          .eq('id', walletId)
          .eq('user_id', userId);
    } catch (e) {
      throw Exception('Failed to delete wallet: $e');
    }
  }

  // Sync wallet ke server
  Future<Wallet> syncWallet(Wallet wallet) async {
    try {
      print('🔄 Syncing wallet: ${wallet.id} for user: ${wallet.userId}');
      
      // Cek apakah wallet sudah ada di server (tanpa menggunakan .single())
      final checkResponse = await _supabase
          .from('wallets')
          .select('*')
          .eq('id', wallet.id)
          .eq('user_id', wallet.userId);

      if (checkResponse.isEmpty) {
        // Buat baru di server
        print('📝 Creating new wallet in server: ${wallet.id}');
        final data = {
          'id': wallet.id, // Gunakan ID yang sama dari local
          'user_id': wallet.userId,
          'name': wallet.name,
          'balance': wallet.balance,
          'currency': wallet.currency,
          'is_active': wallet.isActive,
          'created_at': wallet.createdAt.toIso8601String(),
        };

        final response = await _supabase
            .from('wallets')
            .insert(data)
            .select()
            .single();

        print('✅ Wallet created successfully in server');
        return Wallet.fromJson(_convertFromSupabase(response));
      } else {
        // Update yang sudah ada
        print('🔄 Updating existing wallet in server: ${wallet.id}');
        final updateRequest = UpdateWalletRequest(
          name: wallet.name,
          balance: wallet.balance,
          currency: wallet.currency,
          isActive: wallet.isActive,
        );
        final updatedWallet = await updateWallet(wallet.id, wallet.userId, updateRequest);
        print('✅ Wallet updated successfully in server');
        return updatedWallet;
      }
    } catch (e) {
      print('❌ Failed to sync wallet ${wallet.id}: $e');
      throw Exception('Failed to sync wallet: $e');
    }
  }

  // Sync penghapusan wallet
  Future<void> syncWalletDeletion(String walletId, String userId) async {
    try {
      await deleteWallet(walletId, userId);
    } catch (e) {
      // Jika wallet tidak ditemukan di server, anggap sudah dihapus
      if (!e.toString().contains('No rows found')) {
        throw Exception('Failed to sync wallet deletion: $e');
      }
    }
  }

  // Convert dari format Supabase ke format aplikasi
  Map<String, dynamic> _convertFromSupabase(Map<String, dynamic> data) {
    return {
      'id': data['id'],
      'user_id': data['user_id'],
      'name': data['name'],
      'balance': data['balance'],
      'currency': data['currency'],
      'is_active': data['is_active'],
      'created_at': data['created_at'],
      'updated_at': data['updated_at'],
      'is_deleted': false, // Supabase tidak menyimpan soft delete
      'needs_sync': false, // Data dari server sudah ter-sync
    };
  }
}

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/agent_training_model.dart';
import '../services/supabase_service.dart';

/// Service for managing Agent Training (Instructions & Few-Shot Examples)
class AgentTrainingService {
  final SupabaseClient _supabase;

  AgentTrainingService(this._supabase);

  /// Fetch all active & inactive training records for current user
  Future<List<AgentTraining>> getTrainingData() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return [];

      final response = await _supabase
          .from('agent_training')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      return (response as List)
          .map((json) => AgentTraining.fromJson(json as Map<String, dynamic>))
          .toList();
    } on PostgrestException catch (e) {
      throw Exception('Database error: ${e.message}');
    } catch (e) {
      throw Exception('Unexpected error fetching agent training data: $e');
    }
  }

  /// Add custom system instruction
  Future<AgentTraining> addSystemInstruction(String instructionText) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('User not authenticated');

    final data = {
      'user_id': userId,
      'training_type': 'system_instruction',
      'instruction_text': instructionText,
      'is_active': true,
    };

    final response = await _supabase
        .from('agent_training')
        .insert(data)
        .select()
        .single();

    return AgentTraining.fromJson(response);
  }

  /// Add few-shot chat example
  Future<AgentTraining> addFewShotExample({
    required String sampleInput,
    required Map<String, dynamic> expectedOutput,
  }) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('User not authenticated');

    final data = {
      'user_id': userId,
      'training_type': 'few_shot_example',
      'sample_input': sampleInput,
      'expected_output': expectedOutput,
      'is_active': true,
    };

    final response = await _supabase
        .from('agent_training')
        .insert(data)
        .select()
        .single();

    return AgentTraining.fromJson(response);
  }

  /// Toggle active state of a training item
  Future<void> toggleActive(String id, bool isActive) async {
    await _supabase
        .from('agent_training')
        .update({'is_active': isActive, 'updated_at': DateTime.now().toIso8601String()})
        .eq('id', id);
  }

  /// Delete a training item
  Future<void> deleteTrainingItem(String id) async {
    await _supabase.from('agent_training').delete().eq('id', id);
  }
}

/// Provider for AgentTrainingService
final agentTrainingServiceProvider = Provider<AgentTrainingService>((ref) {
  final supabase = ref.watch(supabaseProvider);
  return AgentTrainingService(supabase);
});

/// FutureProvider to load AgentTraining list
final agentTrainingListProvider = FutureProvider<List<AgentTraining>>((ref) async {
  final service = ref.watch(agentTrainingServiceProvider);
  return await service.getTrainingData();
});

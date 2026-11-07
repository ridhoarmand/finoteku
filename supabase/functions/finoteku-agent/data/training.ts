/**
 * Agent Training Data Access Layer
 * Mengambil data instruksi khusus & contoh few-shot buatan user dari Supabase
 */
import type { SupabaseClient } from 'https://esm.sh/@supabase/supabase-js@2';

export interface FewShotExample {
  id: string;
  sampleInput: string;
  expectedOutput: Record<string, unknown>;
  isActive: boolean;
}

export interface AgentTrainingContext {
  systemInstructions: string[];
  fewShotExamples: FewShotExample[];
}

/**
  * Ambil data pelatihan agent aktif milik user
  */
export async function getAgentTraining(
  supabase: SupabaseClient,
  userId: string,
): Promise<AgentTrainingContext> {
  try {
    const { data, error } = await supabase
      .from('agent_training')
      .select('id, training_type, sample_input, expected_output, instruction_text, is_active')
      .eq('user_id', userId)
      .eq('is_active', true)
      .order('created_at', { ascending: false });

    if (error || !data) {
      console.warn('[TrainingData] Gagal mengambil agent_training:', error?.message);
      return { systemInstructions: [], fewShotExamples: [] };
    }

    const systemInstructions: string[] = [];
    const fewShotExamples: FewShotExample[] = [];

    for (const item of data) {
      if (item.training_type === 'system_instruction' && item.instruction_text) {
        systemInstructions.push(item.instruction_text.trim());
      } else if (item.training_type === 'few_shot_example' && item.sample_input && item.expected_output) {
        fewShotExamples.push({
          id: item.id,
          sampleInput: item.sample_input,
          expectedOutput: item.expected_output as Record<string, unknown>,
          isActive: item.is_active ?? true,
        });
      }
    }

    return { systemInstructions, fewShotExamples };
  } catch (err) {
    console.error('[TrainingData] Error fetching training context:', err);
    return { systemInstructions: [], fewShotExamples: [] };
  }
}

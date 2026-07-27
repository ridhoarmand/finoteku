/// Model for Agent Training (Instructions & Few-Shot Examples)
class AgentTraining {
  final String id;
  final String userId;
  final String trainingType; // 'system_instruction' or 'few_shot_example'
  final String? sampleInput;
  final Map<String, dynamic>? expectedOutput;
  final String? instructionText;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  const AgentTraining({
    required this.id,
    required this.userId,
    required this.trainingType,
    this.sampleInput,
    this.expectedOutput,
    this.instructionText,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  factory AgentTraining.fromJson(Map<String, dynamic> json) {
    return AgentTraining(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      trainingType: json['training_type'] as String,
      sampleInput: json['sample_input'] as String?,
      expectedOutput: json['expected_output'] != null
          ? Map<String, dynamic>.from(json['expected_output'] as Map)
          : null,
      instructionText: json['instruction_text'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'training_type': trainingType,
      'sample_input': sampleInput,
      'expected_output': expectedOutput,
      'instruction_text': instructionText,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  bool get isInstruction => trainingType == 'system_instruction';
  bool get isFewShot => trainingType == 'few_shot_example';

  AgentTraining copyWith({
    String? id,
    String? userId,
    String? trainingType,
    String? sampleInput,
    Map<String, dynamic>? expectedOutput,
    String? instructionText,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AgentTraining(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      trainingType: trainingType ?? this.trainingType,
      sampleInput: sampleInput ?? this.sampleInput,
      expectedOutput: expectedOutput ?? this.expectedOutput,
      instructionText: instructionText ?? this.instructionText,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

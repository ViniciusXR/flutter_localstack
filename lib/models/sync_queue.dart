class SyncQueue {
  final int? id;
  final int? taskId; 
  final String operation;
  final String data; 
  final DateTime createdAt;
  final int retryCount;
  final String? error;

  SyncQueue({
    this.id,
    this.taskId,
    required this.operation,
    required this.data,
    DateTime? createdAt,
    this.retryCount = 0,
    this.error,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'taskId': taskId,
      'operation': operation,
      'data': data,
      'createdAt': createdAt.toIso8601String(),
      'retryCount': retryCount,
      'error': error,
    };
  }

  factory SyncQueue.fromMap(Map<String, dynamic> map) {
    return SyncQueue(
      id: map['id'] as int?,
      taskId: map['taskId'] as int?,
      operation: map['operation'] as String,
      data: map['data'] as String,
      createdAt: DateTime.parse(map['createdAt'] as String),
      retryCount: map['retryCount'] as int? ?? 0,
      error: map['error'] as String?,
    );
  }

  SyncQueue copyWith({
    int? id,
    int? taskId,
    String? operation,
    String? data,
    DateTime? createdAt,
    int? retryCount,
    String? error,
  }) {
    return SyncQueue(
      id: id ?? this.id,
      taskId: taskId ?? this.taskId,
      operation: operation ?? this.operation,
      data: data ?? this.data,
      createdAt: createdAt ?? this.createdAt,
      retryCount: retryCount ?? this.retryCount,
      error: error ?? this.error,
    );
  }
}

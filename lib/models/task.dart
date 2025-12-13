class Task {
  final int? id;
  final String title;
  final String description;
  final String priority;
  final bool completed;
  final DateTime createdAt;
  
  // MÚLTIPLAS FOTOS
  final List<String> photoPaths;  // Lista de caminhos das fotos
  
  // SENSORES
  final DateTime? completedAt;
  final String? completedBy;      // 'manual', 'shake'
  
  // GPS
  final double? latitude;
  final double? longitude;
  final String? locationName;

  // OFFLINE-FIRST
  final DateTime lastModified;    // Para Last-Write-Wins
  final int syncStatus;           // 0 = synced, 1 = pending

  Task({
    this.id,
    required this.title,
    this.description = '',  // Valor padrão vazio
    required this.priority,
    this.completed = false,
    DateTime? createdAt,
    List<String>? photoPaths,  // Agora aceita lista de fotos
    this.completedAt,
    this.completedBy,
    this.latitude,
    this.longitude,
    this.locationName,
    DateTime? lastModified,
    this.syncStatus = 0,  // Default: synced
  }) : createdAt = createdAt ?? DateTime.now(),
       photoPaths = photoPaths ?? [],  // Lista vazia por padrão
       lastModified = lastModified ?? DateTime.now();

  // Getters auxiliares
  bool get hasPhotos => photoPaths.isNotEmpty;
  int get photosCount => photoPaths.length;
  bool get hasLocation => latitude != null && longitude != null;
  bool get wasCompletedByShake => completedBy == 'shake';
  bool get isSynced => syncStatus == 0;
  bool get isPending => syncStatus == 1;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'priority': priority,
      'completed': completed ? 1 : 0,
      'createdAt': createdAt.toIso8601String(),
      'photoPaths': photoPaths.join('|'),  // Salvar como string separada por |
      'completedAt': completedAt?.toIso8601String(),
      'completedBy': completedBy,
      'latitude': latitude,
      'longitude': longitude,
      'locationName': locationName,
      'lastModified': lastModified.toIso8601String(),
      'syncStatus': syncStatus,
    };
  }

  factory Task.fromMap(Map<String, dynamic> map) {
    // Converter string separada por | de volta para lista
    final photoPathsString = map['photoPaths'] as String?;
    final photoPaths = photoPathsString != null && photoPathsString.isNotEmpty
        ? photoPathsString.split('|')
        : <String>[];

    return Task(
      id: map['id'] as int?,
      title: map['title'] as String,
      description: (map['description'] as String?) ?? '',
      priority: map['priority'] as String,
      completed: (map['completed'] as int) == 1,
      createdAt: DateTime.parse(map['createdAt'] as String),
      photoPaths: photoPaths,
      completedAt: map['completedAt'] != null 
          ? DateTime.parse(map['completedAt'] as String)
          : null,
      completedBy: map['completedBy'] as String?,
      latitude: map['latitude'] as double?,
      longitude: map['longitude'] as double?,
      locationName: map['locationName'] as String?,
      lastModified: map['lastModified'] != null
          ? DateTime.parse(map['lastModified'] as String)
          : DateTime.now(),
      syncStatus: map['syncStatus'] as int? ?? 0,
    );
  }

  Task copyWith({
    int? id,
    String? title,
    String? description,
    String? priority,
    bool? completed,
    DateTime? createdAt,
    List<String>? photoPaths,  // Agora recebe lista
    DateTime? completedAt,
    String? completedBy,
    double? latitude,
    double? longitude,
    String? locationName,
    DateTime? lastModified,
    int? syncStatus,
  }) {
    return Task(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      priority: priority ?? this.priority,
      completed: completed ?? this.completed,
      createdAt: createdAt ?? this.createdAt,
      photoPaths: photoPaths ?? this.photoPaths,
      completedAt: completedAt ?? this.completedAt,
      completedBy: completedBy ?? this.completedBy,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      locationName: locationName ?? this.locationName,
      lastModified: lastModified ?? DateTime.now(),  // Sempre atualiza ao copiar
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }
}
import 'dart:async';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../models/task.dart';
import '../models/sync_queue.dart';

class DatabaseService {
  static final DatabaseService instance = DatabaseService._init();
  static Database? _database;

  DatabaseService._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('tasks.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 7,  // ATUALIZADO: sync_queue para offline-first
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    const idType = 'INTEGER PRIMARY KEY AUTOINCREMENT';
    const textType = 'TEXT NOT NULL';
    const intType = 'INTEGER NOT NULL';

    await db.execute('''
      CREATE TABLE tasks (
        id $idType,
        title $textType,
        description TEXT,
        priority $textType,
        completed $intType,
        createdAt $textType,
        photoPaths TEXT,
        completedAt TEXT,
        completedBy TEXT,
        latitude REAL,
        longitude REAL,
        locationName TEXT,
        lastModified $textType,
        syncStatus $intType DEFAULT 0
      )
    ''');

    // Tabela de fila de sincronização
    await db.execute('''
      CREATE TABLE sync_queue (
        id $idType,
        taskId INTEGER,
        operation $textType,
        data TEXT,
        createdAt $textType,
        retryCount $intType DEFAULT 0,
        error TEXT
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Migração incremental para cada versão
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE tasks ADD COLUMN photoPath TEXT');
    }
    if (oldVersion < 3) {
      await db.execute('ALTER TABLE tasks ADD COLUMN completedAt TEXT');
      await db.execute('ALTER TABLE tasks ADD COLUMN completedBy TEXT');
    }
    if (oldVersion < 4) {
      await db.execute('ALTER TABLE tasks ADD COLUMN latitude REAL');
      await db.execute('ALTER TABLE tasks ADD COLUMN longitude REAL');
      await db.execute('ALTER TABLE tasks ADD COLUMN locationName TEXT');
    }
    if (oldVersion < 5) {
      // Recriar tabela para permitir description opcional
      await db.execute('''
        CREATE TABLE tasks_new (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          title TEXT NOT NULL,
          description TEXT,
          priority TEXT NOT NULL,
          completed INTEGER NOT NULL,
          createdAt TEXT NOT NULL,
          photoPath TEXT,
          completedAt TEXT,
          completedBy TEXT,
          latitude REAL,
          longitude REAL,
          locationName TEXT
        )
      ''');
      
      await db.execute('''
        INSERT INTO tasks_new 
        SELECT id, title, description, priority, completed, createdAt,
               photoPath, completedAt, completedBy, latitude, longitude, locationName
        FROM tasks
      ''');
      
      await db.execute('DROP TABLE tasks');
      await db.execute('ALTER TABLE tasks_new RENAME TO tasks');
      
      print('✅ Tabela recriada - description agora é opcional');
    }
    if (oldVersion < 6) {
      // Migrar de photoPath (único) para photoPaths (múltiplos)
      await db.execute('ALTER TABLE tasks ADD COLUMN photoPaths TEXT');
      
      // Copiar photoPath antigo para photoPaths
      await db.execute('''
        UPDATE tasks 
        SET photoPaths = photoPath 
        WHERE photoPath IS NOT NULL AND photoPath != ''
      ''');
      
      print('✅ Migração v6 - suporte a múltiplas fotos adicionado');
    }
    if (oldVersion < 7) {
      // Adicionar campos para offline-first
      await db.execute('ALTER TABLE tasks ADD COLUMN lastModified TEXT');
      await db.execute('ALTER TABLE tasks ADD COLUMN syncStatus INTEGER DEFAULT 0');
      
      // Definir lastModified para tasks existentes
      await db.execute('''
        UPDATE tasks 
        SET lastModified = createdAt
        WHERE lastModified IS NULL
      ''');
      
      // Criar tabela sync_queue
      await db.execute('''
        CREATE TABLE sync_queue (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          taskId INTEGER,
          operation TEXT NOT NULL,
          data TEXT,
          createdAt TEXT NOT NULL,
          retryCount INTEGER NOT NULL DEFAULT 0,
          error TEXT
        )
      ''');
      
      print('✅ Migração v7 - offline-first com sync_queue adicionado');
    }
    print('✅ Banco migrado de v$oldVersion para v$newVersion');
  }

  // CRUD Methods
  Future<Task> create(Task task) async {
    final db = await instance.database;
    final id = await db.insert('tasks', task.toMap());
    return task.copyWith(id: id);
  }

  Future<Task?> read(int id) async {
    final db = await instance.database;
    final maps = await db.query(
      'tasks',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isNotEmpty) {
      return Task.fromMap(maps.first);
    }
    return null;
  }

  Future<List<Task>> readAll() async {
    final db = await instance.database;
    const orderBy = 'createdAt DESC';
    final result = await db.query('tasks', orderBy: orderBy);
    return result.map((json) => Task.fromMap(json)).toList();
  }

  Future<int> update(Task task) async {
    final db = await instance.database;
    return db.update(
      'tasks',
      task.toMap(),
      where: 'id = ?',
      whereArgs: [task.id],
    );
  }

  Future<int> delete(int id) async {
    final db = await instance.database;
    return await db.delete(
      'tasks',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Método especial: buscar tarefas por proximidade
  Future<List<Task>> getTasksNearLocation({
    required double latitude,
    required double longitude,
    double radiusInMeters = 1000,
  }) async {
    final allTasks = await readAll();
    
    return allTasks.where((task) {
      if (!task.hasLocation) return false;
      
      // Cálculo de distância usando fórmula de Haversine (simplificada)
      final latDiff = (task.latitude! - latitude).abs();
      final lonDiff = (task.longitude! - longitude).abs();
      final distance = ((latDiff * 111000) + (lonDiff * 111000)) / 2;
      
      return distance <= radiusInMeters;
    }).toList();
  }

  Future close() async {
    final db = await instance.database;
    db.close();
  }

  // ==================== SYNC QUEUE METHODS ====================
  
  Future<SyncQueue> createSyncQueue(SyncQueue syncQueue) async {
    final db = await instance.database;
    final id = await db.insert('sync_queue', syncQueue.toMap());
    return syncQueue.copyWith(id: id);
  }

  Future<List<SyncQueue>> readAllSyncQueue() async {
    final db = await instance.database;
    const orderBy = 'createdAt ASC';
    final result = await db.query('sync_queue', orderBy: orderBy);
    return result.map((json) => SyncQueue.fromMap(json)).toList();
  }

  Future<int> updateSyncQueue(SyncQueue syncQueue) async {
    final db = await instance.database;
    return db.update(
      'sync_queue',
      syncQueue.toMap(),
      where: 'id = ?',
      whereArgs: [syncQueue.id],
    );
  }

  Future<int> deleteSyncQueue(int id) async {
    final db = await instance.database;
    return await db.delete(
      'sync_queue',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> clearSyncQueue() async {
    final db = await instance.database;
    return await db.delete('sync_queue');
  }
}
import 'dart:async';
import 'dart:convert';
import '../models/task.dart';
import '../models/sync_queue.dart';
import 'database_service.dart';
import 'api_service.dart';
import 'connectivity_service.dart';

class SyncService {
  static final SyncService instance = SyncService._init();
  
  SyncService._init();

  bool _isSyncing = false;
  final StreamController<String> _syncStatusController = StreamController<String>.broadcast();
  
  Stream<String> get syncStatusStream => _syncStatusController.stream;

  // Inicializar sincronização automática
  Future<void> initialize() async {
    // Ouvir mudanças de conectividade
    ConnectivityService.instance.connectionStream.listen((isOnline) {
      if (isOnline) {
        print('Conexão restaurada - iniciando sincronização...');
        syncAll();
      }
    });
  }

  // Sincronizar todas as operações pendentes
  Future<void> syncAll() async {
    if (_isSyncing) {
      print('Sincronização já em andamento...');
      return;
    }

    if (!ConnectivityService.instance.isOnline) {
      print('Offline - sincronização adiada');
      return;
    }

    _isSyncing = true;
    _syncStatusController.add('syncing');

    try {
      final queue = await DatabaseService.instance.readAllSyncQueue();
      print('📋 ${queue.length} operação(ões) na fila');

      int successCount = 0;
      int errorCount = 0;

      for (final item in queue) {
        try {
          await _processSyncItem(item);
          await DatabaseService.instance.deleteSyncQueue(item.id!);
          successCount++;
        } catch (e) {
          print('Erro ao sincronizar item ${item.id}: $e');
          
          // Incrementar contador de tentativas
          final updated = item.copyWith(
            retryCount: item.retryCount + 1,
            error: e.toString(),
          );
          await DatabaseService.instance.updateSyncQueue(updated);
          errorCount++;
        }
      }

      if (successCount > 0 || errorCount > 0) {
        print('Sincronização concluída: $successCount sucesso(s), $errorCount erro(s)');
      }
      
      if (ApiService.instance.testMode && successCount > 0) {
        print('MODO TESTE ATIVO: Operações simuladas com sucesso');
      }
      
      _syncStatusController.add('completed');
    } catch (e) {
      print('Erro geral na sincronização: $e');
      _syncStatusController.add('error');
    } finally {
      _isSyncing = false;
    }
  }

  // Processar um item da fila
  Future<void> _processSyncItem(SyncQueue item) async {
    switch (item.operation) {
      case 'CREATE':
        await _syncCreate(item);
        break;
      case 'UPDATE':
        await _syncUpdate(item);
        break;
      case 'DELETE':
        await _syncDelete(item);
        break;
      default:
        throw Exception('Operação desconhecida: ${item.operation}');
    }
  }

  // Sincronizar criação
  Future<void> _syncCreate(SyncQueue item) async {
    final taskData = jsonDecode(item.data);
    final task = Task.fromMap(taskData);
    
    print('📤 CREATE: ${task.title}');
    
    // Enviar para API
    final createdTask = await ApiService.instance.createTask(task);
    
    // Atualizar local com ID do servidor
    if (task.id != null) {
      final updated = createdTask.copyWith(
        id: task.id,  // Manter ID local
        syncStatus: 0,  // Marcar como sincronizado
      );
      await DatabaseService.instance.update(updated);
    }
  }

  // Sincronizar atualização com resolução de conflitos (LWW)
  Future<void> _syncUpdate(SyncQueue item) async {
    final taskData = jsonDecode(item.data);
    final localTask = Task.fromMap(taskData);
    
    print('📤 UPDATE: ${localTask.title}');
    
    try {
      // Buscar versão do servidor
      final serverTask = await ApiService.instance.fetchTask(localTask.id!);
      
      // Last-Write-Wins: comparar timestamps
      if (serverTask.lastModified.isAfter(localTask.lastModified)) {
        // Servidor mais recente - sobrescrever local
        print('⬇️ Servidor mais recente - atualizando local');
        final updated = serverTask.copyWith(syncStatus: 0);
        await DatabaseService.instance.update(updated);
      } else {
        // Local mais recente - enviar para servidor
        print('⬆️ Local mais recente - atualizando servidor');
        await ApiService.instance.updateTask(localTask);
        
        // Marcar como sincronizado
        final updated = localTask.copyWith(syncStatus: 0);
        await DatabaseService.instance.update(updated);
      }
    } catch (e) {
      // Se não existir no servidor, criar
      if (e.toString().contains('404') || e.toString().contains('não encontrada')) {
        print('🆕 Tarefa não existe no servidor - criando...');
        await ApiService.instance.createTask(localTask);
        
        final updated = localTask.copyWith(syncStatus: 0);
        await DatabaseService.instance.update(updated);
      } else {
        rethrow;
      }
    }
  }

  // Sincronizar deleção
  Future<void> _syncDelete(SyncQueue item) async {
    print('📤 DELETE: Task ID ${item.taskId}');
    
    try {
      await ApiService.instance.deleteTask(item.taskId!);
    } catch (e) {
      // Se não existir no servidor, ignorar erro
      if (e.toString().contains('404') || e.toString().contains('não encontrada')) {
        print('ℹ️ Tarefa já deletada no servidor');
      } else {
        rethrow;
      }
    }
  }

  // Adicionar operação à fila de sincronização
  Future<void> queueOperation({
    required String operation,
    required Task task,
  }) async {
    final syncQueue = SyncQueue(
      taskId: task.id,
      operation: operation,
      data: jsonEncode(task.toMap()),
    );

    await DatabaseService.instance.createSyncQueue(syncQueue);
    print('➕ Operação $operation adicionada à fila (Task: ${task.title})');

    // Marcar task como pendente de sincronização
    final updated = task.copyWith(syncStatus: 1);
    await DatabaseService.instance.update(updated);

    // Tentar sincronizar imediatamente se estiver online
    if (ConnectivityService.instance.isOnline) {
      syncAll();
    }
  }

  // Limpar fila de sincronização (usar com cuidado!)
  Future<void> clearQueue() async {
    await DatabaseService.instance.clearSyncQueue();
    print('🗑️ Fila de sincronização limpa');
  }

  void dispose() {
    _syncStatusController.close();
  }
}

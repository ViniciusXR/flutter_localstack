import 'package:flutter/material.dart';
import '../models/task.dart';
import '../services/database_service.dart';
import '../services/sensor_service.dart';
import '../services/location_service.dart';
import '../services/camera_service.dart';
import '../services/connectivity_service.dart';
import '../services/sync_service.dart';
import '../services/cloud_service.dart';
import '../screens/task_form_screen.dart';
import '../screens/cloud_upload_example.dart';
import '../widgets/task_card.dart';
import 'dart:async';

class TaskListScreen extends StatefulWidget {
  const TaskListScreen({super.key});

  @override
  State<TaskListScreen> createState() => _TaskListScreenState();
}

class _TaskListScreenState extends State<TaskListScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  // Tarefas locais (SQLite)
  List<Task> _tasks = [];
  
  // Tarefas na nuvem (LocalStack/DynamoDB)
  List<dynamic> _cloudTasks = [];
  
  String _filter = 'all';
  bool _isLoading = true;
  bool _isLoadingCloud = false;
  bool _isOnline = true;
  StreamSubscription<bool>? _connectivitySubscription;
  StreamSubscription<String>? _syncSubscription;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (_tabController.index == 1 && _cloudTasks.isEmpty) {
        _loadCloudTasks();
      }
    });
    _initializeServices();
    _loadTasks();
    _setupShakeDetection(); // INICIAR SHAKE
  }

  Future<void> _initializeServices() async {
    // Inicializar ConnectivityService
    await ConnectivityService.instance.initialize();
    _isOnline = ConnectivityService.instance.isOnline;
    
    // Inicializar SyncService
    await SyncService.instance.initialize();
    
    // Ouvir mudanças de conectividade
    _connectivitySubscription = ConnectivityService.instance.connectionStream.listen((isOnline) {
      if (mounted) {
        setState(() {
          _isOnline = isOnline;
        });
        
        if (isOnline) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('🟢 ONLINE - Sincronizando...'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('🔴 OFFLINE - Dados salvos localmente'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    });
    
    // Ouvir status de sincronização
    _syncSubscription = SyncService.instance.syncStatusStream.listen((status) {
      if (mounted && status == 'completed') {
        _loadTasks(); // Recarregar após sincronização
        
        // Mostrar feedback de sincronização bem-sucedida
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Sincronização concluída com sucesso'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    SensorService.instance.stop(); // PARAR SHAKE
    _connectivitySubscription?.cancel();
    _syncSubscription?.cancel();
    super.dispose();
  }

  // SHAKE DETECTION
  void _setupShakeDetection() {
    SensorService.instance.startShakeDetection(() {
      _showShakeDialog();
    });
  }

  void _showShakeDialog() {
    final pendingTasks = _tasks.where((t) => !t.completed).toList();
    
    if (pendingTasks.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🎉 Nenhuma tarefa pendente!'),
          backgroundColor: Colors.green,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: const [
            Icon(Icons.vibration, color: Colors.blue),
            SizedBox(width: 8),
            Expanded(child: Text('Shake detectado!')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Selecione uma tarefa para completar:'),
            const SizedBox(height: 16),
            ...pendingTasks.take(3).map((task) => ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                task.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: IconButton(
                icon: const Icon(Icons.check_circle, color: Colors.green),
                onPressed: () => _completeTaskByShake(task),
              ),
            )),
            if (pendingTasks.length > 3)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '+ ${pendingTasks.length - 3} outras',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
        ],
      ),
    );
  }

  Future<void> _completeTaskByShake(Task task) async {
    try {
      final updated = task.copyWith(
        completed: true,
        completedAt: DateTime.now(),
        completedBy: 'shake',
        syncStatus: 1,  // Marcar como pendente
      );

      await DatabaseService.instance.update(updated);
      
      // Adicionar à fila de sincronização
      await SyncService.instance.queueOperation(
        operation: 'UPDATE',
        task: updated,
      );
      
      Navigator.pop(context);
      await _loadTasks();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ "${task.title}" completa via shake!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      Navigator.pop(context);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _loadTasks() async {
    setState(() => _isLoading = true);

    try {
      final tasks = await DatabaseService.instance.readAll();
      
      if (mounted) {
        setState(() {
          _tasks = tasks;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao carregar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _loadCloudTasks() async {
    setState(() => _isLoadingCloud = true);

    try {
      final tasks = await CloudService.getTasks();
      
      if (mounted) {
        setState(() {
          _cloudTasks = tasks;
          _isLoadingCloud = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingCloud = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao carregar tarefas da nuvem: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  List<Task> get _filteredTasks {
    switch (_filter) {
      case 'pending':
        return _tasks.where((t) => !t.completed).toList();
      case 'completed':
        return _tasks.where((t) => t.completed).toList();
      case 'nearby':
        // Implementar filtro de proximidade
        return _tasks;
      default:
        return _tasks;
    }
  }

  Map<String, int> get _statistics {
    final total = _tasks.length;
    final completed = _tasks.where((t) => t.completed).length;
    final pending = total - completed;
    final completionRate = total > 0 ? ((completed / total) * 100).round() : 0;
    
    return {
      'total': total,
      'completed': completed,
      'pending': pending,
      'completionRate': completionRate,
    };
  }

  Future<void> _filterByNearby() async {
    final position = await LocationService.instance.getCurrentLocation();
    
    if (position == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ Não foi possível obter localização'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    final nearbyTasks = await DatabaseService.instance.getTasksNearLocation(
      latitude: position.latitude,
      longitude: position.longitude,
      radiusInMeters: 1000,
    );

    setState(() {
      _tasks = nearbyTasks;
      _filter = 'nearby';
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('📍 ${nearbyTasks.length} tarefa(s) próxima(s)'),
          backgroundColor: Colors.blue,
        ),
      );
    }
  }

  Future<void> _deleteTask(Task task) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar exclusão'),
        content: Text('Deseja deletar "${task.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Deletar'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        // Deletar todas as fotos da tarefa
        if (task.hasPhotos) {
          for (var photoPath in task.photoPaths) {
            await CameraService.instance.deletePhoto(photoPath);
          }
        }
        
        // Adicionar à fila de sincronização ANTES de deletar localmente
        await SyncService.instance.queueOperation(
          operation: 'DELETE',
          task: task,
        );
        
        // Deletar localmente
        await DatabaseService.instance.delete(task.id!);
        await _loadTasks();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('🗑️ Tarefa deletada e aguardando sincronização'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erro: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _toggleComplete(Task task) async {
    try {
      final updated = task.copyWith(
        completed: !task.completed,
        completedAt: !task.completed ? DateTime.now() : null,
        completedBy: !task.completed ? 'manual' : null,
        syncStatus: 1,  // Marcar como pendente
      );

      await DatabaseService.instance.update(updated);
      
      // Adicionar à fila de sincronização
      await SyncService.instance.queueOperation(
        operation: 'UPDATE',
        task: updated,
      );
      
      await _loadTasks();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final stats = _statistics;
    final filteredTasks = _filteredTasks;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Text('Minhas Tarefas'),
            const SizedBox(width: 12),
            // Indicador de conectividade
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _isOnline ? Colors.green : Colors.red,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _isOnline ? Icons.cloud_done : Icons.cloud_off,
                    size: 16,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _isOnline ? 'Online' : 'Offline',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(
              icon: Icon(Icons.phone_android),
              text: 'SQLite (Local)',
            ),
            Tab(
              icon: Icon(Icons.cloud),
              text: 'LocalStack (Nuvem)',
            ),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list),
            onSelected: (value) {
              if (value == 'nearby') {
                _filterByNearby();
              } else {
                setState(() {
                  _filter = value;
                  if (value != 'nearby') _loadTasks();
                });
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'all',
                child: Row(
                  children: [
                    Icon(Icons.list_alt),
                    SizedBox(width: 8),
                    Text('Todas'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'pending',
                child: Row(
                  children: [
                    Icon(Icons.pending_outlined),
                    SizedBox(width: 8),
                    Text('Pendentes'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'completed',
                child: Row(
                  children: [
                    Icon(Icons.check_circle_outline),
                    SizedBox(width: 8),
                    Text('Concluídas'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'nearby',
                child: Row(
                  children: [
                    Icon(Icons.near_me),
                    SizedBox(width: 8),
                    Text('Próximas'),
                  ],
                ),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('💡 Dicas'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text('• Toque no card para editar'),
                      SizedBox(height: 8),
                      Text('• Marque como completa com checkbox'),
                      SizedBox(height: 8),
                      Text('• Sacuda o celular para completar rápido!'),
                      SizedBox(height: 8),
                      Text('• Use filtros para organizar'),
                      SizedBox(height: 8),
                      Text('• Adicione fotos e localização'),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Entendi'),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // ABA 1: TAREFAS LOCAIS (SQLite)
          _buildLocalTasksTab(),
          
          // ABA 2: TAREFAS NA NUVEM (LocalStack)
          _buildCloudTasksTab(),
        ],
      ),
      floatingActionButton: Stack(
        children: [
          // Botão LocalStack (canto inferior esquerdo)
          Positioned(
            left: 30,
            bottom: 0,
            child: FloatingActionButton(
              heroTag: 'localstack',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const CloudUploadExample(),
                  ),
                );
              },
              backgroundColor: Colors.orange,
              child: const Icon(Icons.cloud_upload),
              tooltip: 'LocalStack Upload',
            ),
          ),
          // Botão Nova Tarefa (canto inferior direito)
          Positioned(
            right: 0,
            bottom: 0,
            child: FloatingActionButton.extended(
              heroTag: 'newTask',
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const TaskFormScreen(),
                  ),
                );
                if (result == true) _loadTasks();
              },
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add),
              label: const Text('Nova Tarefa'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    String message;
    IconData icon;

    switch (_filter) {
      case 'pending':
        message = '🎉 Nenhuma tarefa pendente!';
        icon = Icons.check_circle_outline;
        break;
      case 'completed':
        message = '📋 Nenhuma tarefa concluída ainda';
        icon = Icons.pending_outlined;
        break;
      case 'nearby':
        message = '📍 Nenhuma tarefa próxima';
        icon = Icons.near_me;
        break;
      default:
        message = '📝 Nenhuma tarefa ainda.\nToque em + para criar!';
        icon = Icons.add_task;
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  // ABA DE TAREFAS LOCAIS (SQLite)
  Widget _buildLocalTasksTab() {
    final stats = _statistics;
    final filteredTasks = _filteredTasks;

    return RefreshIndicator(
      onRefresh: _loadTasks,
      child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // CARD DE ESTATÍSTICAS
                Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.blue.shade400, Colors.blue.shade700],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blue.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _StatItem(
                        label: 'Total',
                        value: stats['total'].toString(),
                        icon: Icons.list_alt,
                      ),
                      Container(
                        width: 1,
                        height: 40,
                        color: Colors.white.withOpacity(0.3),
                      ),
                      _StatItem(
                        label: 'Concluídas',
                        value: stats['completed'].toString(),
                        icon: Icons.check_circle,
                      ),
                      Container(
                        width: 1,
                        height: 40,
                        color: Colors.white.withOpacity(0.3),
                      ),
                      _StatItem(
                        label: 'Taxa',
                        value: '${stats['completionRate']}%',
                        icon: Icons.trending_up,
                      ),
                    ],
                  ),
                ),

                // LISTA DE TAREFAS
                Expanded(
                  child: filteredTasks.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: filteredTasks.length,
                          itemBuilder: (context, index) {
                            final task = filteredTasks[index];
                            return TaskCard(
                              task: task,
                              onTap: () async {
                                final result = await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => TaskFormScreen(task: task),
                                  ),
                                );
                                if (result == true) _loadTasks();
                              },
                              onDelete: () => _deleteTask(task),
                              onCheckboxChanged: (value) => _toggleComplete(task),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }

  // ABA DE TAREFAS NA NUVEM (LocalStack/DynamoDB)
  Widget _buildCloudTasksTab() {
    // Estatísticas das tarefas na nuvem
    final total = _cloudTasks.length;
    final completed = _cloudTasks.where((t) => t['completed'] == true).length;
    final pending = total - completed;
    final completionRate = total > 0 ? ((completed / total) * 100).round() : 0;

    return RefreshIndicator(
      onRefresh: _loadCloudTasks,
      child: _isLoadingCloud
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // CARD DE ESTATÍSTICAS
                Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.orange.shade400, Colors.orange.shade700],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.orange.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _StatItem(
                        label: 'Total',
                        value: total.toString(),
                        icon: Icons.cloud,
                      ),
                      Container(
                        width: 1,
                        height: 40,
                        color: Colors.white.withOpacity(0.3),
                      ),
                      _StatItem(
                        label: 'Concluídas',
                        value: completed.toString(),
                        icon: Icons.check_circle,
                      ),
                      Container(
                        width: 1,
                        height: 40,
                        color: Colors.white.withOpacity(0.3),
                      ),
                      _StatItem(
                        label: 'Taxa',
                        value: '$completionRate%',
                        icon: Icons.trending_up,
                      ),
                    ],
                  ),
                ),

                // LISTA DE TAREFAS
                Expanded(
                  child: _cloudTasks.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.cloud_off,
                                size: 80,
                                color: Colors.grey[300],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                '☁️ Nenhuma tarefa na nuvem\n\nCrie uma nova e escolha\n"LocalStack" como destino',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _cloudTasks.length,
                          itemBuilder: (context, index) {
                            final task = _cloudTasks[index];
                            return _buildCloudTaskCard(task);
                          },
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildCloudTaskCard(dynamic task) {
    final bool isCompleted = task['completed'] == true;
    final String title = task['title'] ?? 'Sem título';
    final String description = task['description'] ?? '';
    final String? imageUrl = task['imageUrl'];
    
    // Location pode ser Map ou String
    String? locationText;
    if (task['location'] != null) {
      if (task['location'] is Map) {
        final loc = task['location'] as Map;
        final lat = loc['latitude'];
        final lon = loc['longitude'];
        if (lat != null && lon != null) {
          locationText = 'Lat: ${lat.toStringAsFixed(4)}, Lon: ${lon.toStringAsFixed(4)}';
        }
      } else if (task['location'] is String) {
        locationText = task['location'] as String;
      }
    }
    
    final int createdAt = task['createdAt'] ?? DateTime.now().millisecondsSinceEpoch;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isCompleted ? Colors.green : Colors.orange,
          width: 2,
        ),
      ),
      child: InkWell(
        onTap: () {
          // Mostrar detalhes em dialog
          _showCloudTaskDetails(task);
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isCompleted ? Colors.green.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      isCompleted ? Icons.check_circle : Icons.cloud,
                      color: isCompleted ? Colors.green : Colors.orange,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            decoration: isCompleted ? TextDecoration.lineThrough : null,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (description.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            description,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              if (locationText != null || imageUrl != null) ...[
                const SizedBox(height: 12),
                if (locationText != null)
                  Row(
                    children: [
                      Icon(Icons.location_on, size: 16, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          locationText,
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                if (imageUrl != null) ...[
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      imageUrl,
                      height: 150,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          height: 150,
                          color: Colors.grey[200],
                          child: const Center(
                            child: Icon(Icons.error_outline, size: 40, color: Colors.grey),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ],
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.access_time, size: 14, color: Colors.grey[500]),
                  const SizedBox(width: 4),
                  Text(
                    DateTime.fromMillisecondsSinceEpoch(createdAt).toString().split('.')[0],
                    style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCloudTaskDetails(dynamic task) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.cloud, color: Colors.orange),
            const SizedBox(width: 8),
            Expanded(child: Text(task['title'] ?? 'Detalhes')),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (task['description'] != null) ...[
                const Text('Descrição:', style: TextStyle(fontWeight: FontWeight.bold)),
                Text(task['description']),
                const SizedBox(height: 12),
              ],
              if (task['imageUrl'] != null) ...[
                const Text('Imagem:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    task['imageUrl'],
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        height: 200,
                        color: Colors.grey[200],
                        child: const Center(
                          child: Icon(Icons.error_outline, size: 40),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),
              ],
              const Text('ID:', style: TextStyle(fontWeight: FontWeight.bold)),
              Text(task['id'] ?? 'N/A', style: const TextStyle(fontSize: 12)),
              const SizedBox(height: 8),
              if (task['location'] != null) ...[
                const Text('Localização:', style: TextStyle(fontWeight: FontWeight.bold)),
                Builder(
                  builder: (context) {
                    String locationText = 'N/A';
                    if (task['location'] is Map) {
                      final loc = task['location'] as Map;
                      final lat = loc['latitude'];
                      final lon = loc['longitude'];
                      if (lat != null && lon != null) {
                        locationText = 'Lat: ${lat.toStringAsFixed(4)}, Lon: ${lon.toStringAsFixed(4)}';
                      }
                    } else if (task['location'] is String) {
                      locationText = task['location'] as String;
                    }
                    return Text(locationText);
                  },
                ),
                const SizedBox(height: 8),
              ],
              const Text('Criado em:', style: TextStyle(fontWeight: FontWeight.bold)),
              Text(DateTime.fromMillisecondsSinceEpoch(task['createdAt']).toString().split('.')[0]),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fechar'),
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _StatItem({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 28),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.9),
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}
import 'dart:io';
import 'package:flutter/material.dart';
import '../models/task.dart';
import '../services/database_service.dart';
import '../services/camera_service.dart';
import '../services/location_service.dart';
import '../services/sync_service.dart';
import '../widgets/location_picker.dart';

class TaskFormScreen extends StatefulWidget {
  final Task? task;

  const TaskFormScreen({super.key, this.task});

  @override
  State<TaskFormScreen> createState() => _TaskFormScreenState();
}

class _TaskFormScreenState extends State<TaskFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  
  String _priority = 'medium';
  bool _completed = false;
  bool _isLoading = false;
  
  // MÚLTIPLAS FOTOS
  List<String> _photoPaths = [];
  
  // GPS
  double? _latitude;
  double? _longitude;
  String? _locationName;

  @override
  void initState() {
    super.initState();
    
    if (widget.task != null) {
      _titleController.text = widget.task!.title;
      _descriptionController.text = widget.task!.description;
      _priority = widget.task!.priority;
      _completed = widget.task!.completed;
      _photoPaths = List.from(widget.task!.photoPaths);  // Copiar lista de fotos
      _latitude = widget.task!.latitude;
      _longitude = widget.task!.longitude;
      _locationName = widget.task!.locationName;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  // FOTO METHODS
  Future<void> _addPhotos() async {
    // Usar o novo diálogo que permite escolher múltiplas fotos
    final photoPaths = await CameraService.instance.showMultipleImageSourceDialog(context);
    
    if (photoPaths != null && photoPaths.isNotEmpty && mounted) {
      setState(() {
        _photoPaths.addAll(photoPaths);
      });
    }
  }

  void _removePhoto(int index) {
    setState(() {
      _photoPaths.removeAt(index);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('🗑️ Foto removida')),
    );
  }

  void _viewPhotoGallery(int initialIndex) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _PhotoGalleryScreen(
          photoPaths: _photoPaths,
          initialIndex: initialIndex,
          onDelete: (index) {
            setState(() {
              _photoPaths.removeAt(index);
            });
          },
        ),
      ),
    );
  }

  // GPS METHODS
  void _showLocationPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SingleChildScrollView(
          child: LocationPicker(
            initialLatitude: _latitude,
            initialLongitude: _longitude,
            initialAddress: _locationName,
            onLocationSelected: (lat, lon, address) {
              setState(() {
                _latitude = lat;
                _longitude = lon;
                _locationName = address;
              });
              Navigator.pop(context);
            },
          ),
        ),
      ),
    );
  }

  void _removeLocation() {
    setState(() {
      _latitude = null;
      _longitude = null;
      _locationName = null;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('📍 Localização removida')),
    );
  }

  Future<void> _saveTask() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      if (widget.task == null) {
        // CRIAR
        final newTask = Task(
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim(),
          priority: _priority,
          completed: _completed,
          photoPaths: _photoPaths,  // Lista de fotos
          latitude: _latitude,
          longitude: _longitude,
          locationName: _locationName,
          syncStatus: 1,  // Marcar como pendente até sincronizar
        );
        final created = await DatabaseService.instance.create(newTask);
        
        // Adicionar à fila de sincronização
        await SyncService.instance.queueOperation(
          operation: 'CREATE',
          task: created,
        );
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✓ Tarefa criada e aguardando sincronização'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        // ATUALIZAR
        final updatedTask = widget.task!.copyWith(
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim(),
          priority: _priority,
          completed: _completed,
          photoPaths: _photoPaths,  // Lista de fotos
          latitude: _latitude,
          longitude: _longitude,
          locationName: _locationName,
          syncStatus: 1,  // Marcar como pendente
        );
        await DatabaseService.instance.update(updatedTask);
        
        // Adicionar à fila de sincronização
        await SyncService.instance.queueOperation(
          operation: 'UPDATE',
          task: updatedTask,
        );
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✓ Tarefa atualizada e aguardando sincronização'),
              backgroundColor: Colors.blue,
            ),
          );
        }
      }

      if (mounted) Navigator.pop(context, true);
      
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.task != null;
    
    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Editar Tarefa' : 'Nova Tarefa'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // TÍTULO
                    TextFormField(
                      controller: _titleController,
                      decoration: const InputDecoration(
                        labelText: 'Título *',
                        hintText: 'Ex: Estudar Flutter',
                        prefixIcon: Icon(Icons.title),
                        border: OutlineInputBorder(),
                      ),
                      textCapitalization: TextCapitalization.sentences,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Digite um título';
                        }
                        if (value.trim().length < 3) {
                          return 'Mínimo 3 caracteres';
                        }
                        return null;
                      },
                      maxLength: 100,
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // DESCRIÇÃO
                    TextFormField(
                      controller: _descriptionController,
                      decoration: const InputDecoration(
                        labelText: 'Descrição',
                        hintText: 'Detalhes...',
                        prefixIcon: Icon(Icons.description),
                        border: OutlineInputBorder(),
                        alignLabelWithHint: true,
                      ),
                      maxLines: 4,
                      maxLength: 500,
                      textCapitalization: TextCapitalization.sentences,
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // PRIORIDADE
                    DropdownButtonFormField<String>(
                      value: _priority,
                      decoration: const InputDecoration(
                        labelText: 'Prioridade',
                        prefixIcon: Icon(Icons.flag),
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'low', child: Text('🟢 Baixa')),
                        DropdownMenuItem(value: 'medium', child: Text('🟡 Média')),
                        DropdownMenuItem(value: 'high', child: Text('🟠 Alta')),
                        DropdownMenuItem(value: 'urgent', child: Text('🔴 Urgente')),
                      ],
                      onChanged: (value) {
                        if (value != null) setState(() => _priority = value);
                      },
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // SWITCH COMPLETA
                    SwitchListTile(
                      title: const Text('Tarefa Completa'),
                      subtitle: Text(_completed ? 'Sim' : 'Não'),
                      value: _completed,
                      onChanged: (value) => setState(() => _completed = value),
                      activeColor: Colors.green,
                      secondary: Icon(
                        _completed ? Icons.check_circle : Icons.radio_button_unchecked,
                        color: _completed ? Colors.green : Colors.grey,
                      ),
                    ),
                    
                    const Divider(height: 32),
                    
                    // SEÇÃO FOTOS (MÚLTIPLAS)
                    Row(
                      children: [
                        const Icon(Icons.photo_library, color: Colors.blue),
                        const SizedBox(width: 8),
                        Text(
                          'Fotos ${_photoPaths.isNotEmpty ? "(${_photoPaths.length})" : ""}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        if (_photoPaths.isNotEmpty)
                          TextButton.icon(
                            onPressed: () {
                              setState(() => _photoPaths.clear());
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('🗑️ Todas as fotos removidas')),
                              );
                            },
                            icon: const Icon(Icons.delete_sweep, size: 18),
                            label: const Text('Limpar'),
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.red,
                            ),
                          ),
                      ],
                    ),
                    
                    const SizedBox(height: 12),
                    
                    // Grid de fotos
                    if (_photoPaths.isNotEmpty)
                      SizedBox(
                        height: 120,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: _photoPaths.length + 1, // +1 para o botão de adicionar
                          itemBuilder: (context, index) {
                            if (index == _photoPaths.length) {
                              // Botão de adicionar mais fotos
                              return GestureDetector(
                                onTap: _addPhotos,
                                child: Container(
                                  width: 120,
                                  margin: const EdgeInsets.only(right: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.grey[200],
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Colors.blue,
                                      width: 2,
                                      style: BorderStyle.solid,
                                    ),
                                  ),
                                  child: const Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.add_photo_alternate, 
                                        color: Colors.blue, 
                                        size: 40,
                                      ),
                                      SizedBox(height: 8),
                                      Text(
                                        'Adicionar',
                                        style: TextStyle(
                                          color: Colors.blue,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }
                            
                            // Miniatura da foto
                            return GestureDetector(
                              onTap: () => _viewPhotoGallery(index),
                              child: Stack(
                                children: [
                                  Container(
                                    width: 120,
                                    margin: const EdgeInsets.only(right: 8),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(12),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.1),
                                          blurRadius: 8,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: Image.file(
                                        File(_photoPaths[index]),
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  ),
                                  // Botão de remover
                                  Positioned(
                                    top: 4,
                                    right: 12,
                                    child: GestureDetector(
                                      onTap: () => _removePhoto(index),
                                      child: Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: const BoxDecoration(
                                          color: Colors.red,
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.close,
                                          color: Colors.white,
                                          size: 16,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      )
                    else
                      OutlinedButton.icon(
                        onPressed: _addPhotos,
                        icon: const Icon(Icons.add_photo_alternate),
                        label: const Text('Adicionar Fotos'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.all(16),
                        ),
                      ),
                    
                    const Divider(height: 32),
                    
                    // SEÇÃO LOCALIZAÇÃO
                    Row(
                      children: [
                        const Icon(Icons.location_on, color: Colors.blue),
                        const SizedBox(width: 8),
                        const Text(
                          'Localização',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        if (_latitude != null)
                          TextButton.icon(
                            onPressed: _removeLocation,
                            icon: const Icon(Icons.delete_outline, size: 18),
                            label: const Text('Remover'),
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.red,
                            ),
                          ),
                      ],
                    ),
                    
                    const SizedBox(height: 12),
                    
                    if (_latitude != null && _longitude != null)
                      Card(
                        child: ListTile(
                          leading: const Icon(Icons.location_on, color: Colors.blue),
                          title: Text(_locationName ?? 'Localização salva'),
                          subtitle: Text(
                            LocationService.instance.formatCoordinates(
                              _latitude!,
                              _longitude!,
                            ),
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.edit),
                            onPressed: _showLocationPicker,
                          ),
                        ),
                      )
                    else
                      OutlinedButton.icon(
                        onPressed: _showLocationPicker,
                        icon: const Icon(Icons.add_location),
                        label: const Text('Adicionar Localização'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.all(16),
                        ),
                      ),
                    
                    const SizedBox(height: 32),
                    
                    // BOTÃO SALVAR
                    ElevatedButton.icon(
                      onPressed: _isLoading ? null : _saveTask,
                      icon: const Icon(Icons.save),
                      label: Text(isEditing ? 'Atualizar' : 'Criar Tarefa'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.all(16),
                        textStyle: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

// Widget para visualizar galeria de fotos com swipe
class _PhotoGalleryScreen extends StatefulWidget {
  final List<String> photoPaths;
  final int initialIndex;
  final Function(int) onDelete;

  const _PhotoGalleryScreen({
    required this.photoPaths,
    required this.initialIndex,
    required this.onDelete,
  });

  @override
  State<_PhotoGalleryScreen> createState() => _PhotoGalleryScreenState();
}

class _PhotoGalleryScreenState extends State<_PhotoGalleryScreen> {
  late PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          '${_currentIndex + 1} / ${widget.photoPaths.length}',
          style: const TextStyle(color: Colors.white),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.red),
            tooltip: 'Excluir foto',
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Excluir foto?'),
                  content: const Text('Esta ação não pode ser desfeita.'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancelar'),
                    ),
                    TextButton(
                      onPressed: () {
                        widget.onDelete(_currentIndex);
                        Navigator.pop(context); // Fechar diálogo
                        Navigator.pop(context); // Voltar para formulário
                      },
                      style: TextButton.styleFrom(foregroundColor: Colors.red),
                      child: const Text('Excluir'),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: PageView.builder(
        controller: _pageController,
        itemCount: widget.photoPaths.length,
        onPageChanged: (index) {
          setState(() => _currentIndex = index);
        },
        itemBuilder: (context, index) {
          return Center(
            child: InteractiveViewer(
              child: Image.file(
                File(widget.photoPaths[index]),
                fit: BoxFit.contain,
              ),
            ),
          );
        },
      ),
    );
  }
}
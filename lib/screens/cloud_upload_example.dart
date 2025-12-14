import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import '../services/cloud_service.dart';
import 'localstack_viewer_screen.dart';

class CloudUploadExample extends StatefulWidget {
  const CloudUploadExample({Key? key}) : super(key: key);

  @override
  State<CloudUploadExample> createState() => _CloudUploadExampleState();
}

class _CloudUploadExampleState extends State<CloudUploadExample> {
  final ImagePicker _picker = ImagePicker();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  
  File? _imageFile;
  bool _isUploading = false;
  bool _isOnline = false;
  String? _uploadResult;

  @override
  void initState() {
    super.initState();
    _checkBackendHealth();
  }

  Future<void> _checkBackendHealth() async {
    final isHealthy = await CloudService.checkHealth();
    setState(() {
      _isOnline = isHealthy;
    });
  }

  Future<void> _takePicture() async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80,
      );

      if (photo != null) {
        setState(() {
          _imageFile = File(photo.path);
          _uploadResult = null;
        });
      }
    } catch (e) {
      _showError('Erro ao tirar foto: $e');
    }
  }

  Future<void> _pickFromGallery() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );

      if (image != null) {
        setState(() {
          _imageFile = File(image.path);
          _uploadResult = null;
        });
      }
    } catch (e) {
      _showError('Erro ao selecionar imagem: $e');
    }
  }

  Future<void> _saveTaskWithImage() async {
    if (_imageFile == null) {
      _showError('Selecione uma imagem primeiro');
      return;
    }

    if (_titleController.text.isEmpty) {
      _showError('Digite um título');
      return;
    }

    if (!_isOnline) {
      _showError('Backend não está acessível. Verifique se o servidor está rodando.');
      return;
    }

    setState(() {
      _isUploading = true;
      _uploadResult = null;
    });

    try {
      // Converter imagem para Base64
      final imageBase64 = await CloudService.fileToBase64(_imageFile!);

      // Gerar ID único para a tarefa
      final taskId = const Uuid().v4();

      // Salvar tarefa completa (upload S3 + DynamoDB + SQS + SNS)
      final result = await CloudService.saveTask(
        id: taskId,
        title: _titleController.text,
        description: _descriptionController.text,
        imageBase64: imageBase64,
        location: {
          'latitude': -23.550520,
          'longitude': -46.633308,
        },
      );

      setState(() {
        _uploadResult = 'Tarefa salva com sucesso!\n'
            'ID: $taskId\n'
            'Imagem: ${result['task']['imageUrl']}';
      });

      _showSuccess('Tarefa salva na nuvem local!');

      // Limpar formulário
      _titleController.clear();
      _descriptionController.clear();
      setState(() {
        _imageFile = null;
      });

    } catch (e) {
      _showError('Erro ao salvar tarefa: $e');
    } finally {
      setState(() {
        _isUploading = false;
      });
    }
  }

  Future<void> _uploadImageOnly() async {
    if (_imageFile == null) {
      _showError('Selecione uma imagem primeiro');
      return;
    }

    if (!_isOnline) {
      _showError('Backend não está acessível');
      return;
    }

    setState(() {
      _isUploading = true;
      _uploadResult = null;
    });

    try {
      final taskId = const Uuid().v4();

      // Opção 1: Upload via Base64
      final imageBase64 = await CloudService.fileToBase64(_imageFile!);
      final result = await CloudService.uploadImageBase64(
        imageBase64: imageBase64,
        taskId: taskId,
        fileName: 'product.jpg',
      );

      // Opção 2: Upload via Multipart (descomente para usar)
      // final result = await CloudService.uploadImageMultipart(
      //   imageFile: _imageFile!,
      //   taskId: taskId,
      // );

      setState(() {
        _uploadResult = 'Upload realizado!\n'
            'URL: ${result['imageUrl']}\n'
            'Key: ${result['key']}';
      });

      _showSuccess('Imagem enviada para S3!');

    } catch (e) {
      _showError('Erro ao fazer upload: $e');
    } finally {
      setState(() {
        _isUploading = false;
      });
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Upload para LocalStack'),
        actions: [
          IconButton(
            icon: const Icon(Icons.visibility),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const LocalStackViewerScreen(),
                ),
              );
            },
            tooltip: 'Ver dados LocalStack',
          ),
          IconButton(
            icon: Icon(
              _isOnline ? Icons.cloud_done : Icons.cloud_off,
              color: _isOnline ? Colors.green : Colors.red,
            ),
            onPressed: _checkBackendHealth,
            tooltip: _isOnline ? 'Online' : 'Offline',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Status do backend
            Card(
              color: _isOnline ? Colors.green[50] : Colors.red[50],
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(
                      _isOnline ? Icons.check_circle : Icons.error,
                      color: _isOnline ? Colors.green : Colors.red,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _isOnline ? 'Backend conectado' : 'Backend offline',
                      style: TextStyle(
                        color: _isOnline ? Colors.green[900] : Colors.red[900],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Botões para capturar imagem
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isUploading ? null : _takePicture,
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Tirar Foto'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isUploading ? null : _pickFromGallery,
                    icon: const Icon(Icons.photo_library),
                    label: const Text('Galeria'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Visualização da imagem
            if (_imageFile != null)
              Container(
                height: 200,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(
                    _imageFile!,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            const SizedBox(height: 16),

            // Campos do formulário
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Título',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.title),
              ),
            ),
            const SizedBox(height: 12),

            TextField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Descrição',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.description),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 16),

            // Botões de ação
            ElevatedButton.icon(
              onPressed: (_isUploading || _imageFile == null || !_isOnline)
                  ? null
                  : _saveTaskWithImage,
              icon: _isUploading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.cloud_upload),
              label: Text(_isUploading
                  ? 'Salvando...'
                  : 'Salvar Tarefa (S3 + DynamoDB + SQS + SNS)'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.all(16),
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 8),

            OutlinedButton.icon(
              onPressed: (_isUploading || _imageFile == null || !_isOnline)
                  ? null
                  : _uploadImageOnly,
              icon: const Icon(Icons.upload),
              label: const Text('Upload apenas imagem (S3)'),
            ),
            const SizedBox(height: 16),

            // Resultado do upload
            if (_uploadResult != null)
              Card(
                color: Colors.green[50],
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.check_circle, color: Colors.green),
                          SizedBox(width: 8),
                          Text(
                            'Resultado:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _uploadResult!,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }
}

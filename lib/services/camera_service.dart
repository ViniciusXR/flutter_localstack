import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import '../screens/camera_screen.dart';

class CameraService {
  static final CameraService instance = CameraService._init();
  CameraService._init();

  List<CameraDescription>? _cameras;
  final ImagePicker _picker = ImagePicker();

  Future<void> initialize() async {
    try {
      _cameras = await availableCameras();
      print('✅ CameraService: ${_cameras?.length ?? 0} câmera(s) encontrada(s)');
    } catch (e) {
      print('⚠️ Erro ao inicializar câmera: $e');
      _cameras = [];
    }
  }

  bool get hasCameras => _cameras != null && _cameras!.isNotEmpty;

  // GALERIA - Selecionar múltiplas fotos
  Future<List<String>> pickMultipleFromGallery(BuildContext context) async {
    try {
      final List<XFile> images = await _picker.pickMultiImage(
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (images.isEmpty) return [];

      // Salvar todas as imagens selecionadas
      final List<String> savedPaths = [];
      for (var image in images) {
        final savedPath = await savePicture(image);
        savedPaths.add(savedPath);
      }
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('🖼️ ${savedPaths.length} foto(s) adicionada(s)!'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
      
      return savedPaths;
    } catch (e) {
      print('❌ Erro ao selecionar múltiplas fotos: $e');
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao selecionar fotos: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      
      return [];
    }
  }

  // GALERIA - Selecionar foto existente (única)
  Future<String?> pickFromGallery(BuildContext context) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (image == null) return null;

      // Salvar a imagem selecionada no diretório do app
      final savedPath = await savePicture(image);
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🖼️ Foto selecionada da galeria!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
      
      return savedPath;
    } catch (e) {
      print('❌ Erro ao selecionar da galeria: $e');
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao selecionar foto: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      
      return null;
    }
  }

  // CÂMERA - Tirar nova foto
  Future<String?> takePicture(BuildContext context) async {
    if (!hasCameras) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ Nenhuma câmera disponível'),
          backgroundColor: Colors.red,
        ),
      );
      return null;
    }

    final camera = _cameras!.first;
    final controller = CameraController(
      camera,
      ResolutionPreset.high,
      enableAudio: false,
    );

    try {
      await controller.initialize();

      if (!context.mounted) {
        controller.dispose();
        return null;
      }
      
      final imagePath = await Navigator.push<String>(
        context,
        MaterialPageRoute(
          builder: (context) => CameraScreen(controller: controller),
          fullscreenDialog: true,
        ),
      );

      // Descartar controller APÓS o Navigator retornar
      controller.dispose();
      
      return imagePath;
    } catch (e) {
      print('❌ Erro ao abrir câmera: $e');
      
      // Descartar controller em caso de erro
      controller.dispose();
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao abrir câmera: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      
      return null;
    }
  }

  // Mostrar diálogo para escolher entre câmera ou galeria (múltiplas fotos)
  Future<List<String>?> showMultipleImageSourceDialog(BuildContext context) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Adicionar Fotos',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.camera_alt, color: Colors.blue),
                  title: const Text('Tirar Foto'),
                  subtitle: const Text('Usar a câmera'),
                  onTap: () => Navigator.pop(context, 'camera'),
                ),
                ListTile(
                  leading: const Icon(Icons.photo_library, color: Colors.green),
                  title: const Text('Galeria (Múltiplas)'),
                  subtitle: const Text('Escolher várias fotos'),
                  onTap: () => Navigator.pop(context, 'gallery_multiple'),
                ),
                ListTile(
                  leading: const Icon(Icons.photo, color: Colors.orange),
                  title: const Text('Galeria (Única)'),
                  subtitle: const Text('Escolher uma foto'),
                  onTap: () => Navigator.pop(context, 'gallery_single'),
                ),
                ListTile(
                  leading: const Icon(Icons.close, color: Colors.red),
                  title: const Text('Cancelar'),
                  onTap: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (choice == null || !context.mounted) return null;

    // Executar a ação escolhida
    switch (choice) {
      case 'camera':
        final photoPath = await takePicture(context);
        return photoPath != null ? [photoPath] : null;
      
      case 'gallery_multiple':
        final photoPaths = await pickMultipleFromGallery(context);
        return photoPaths.isNotEmpty ? photoPaths : null;
      
      case 'gallery_single':
        final photoPath = await pickFromGallery(context);
        return photoPath != null ? [photoPath] : null;
      
      default:
        return null;
    }
  }

  // Mostrar diálogo para escolher entre câmera ou galeria (foto única - compatibilidade)
  Future<String?> showImageSourceDialog(BuildContext context) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Escolher Foto',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.camera_alt, color: Colors.blue),
                  title: const Text('Tirar Foto'),
                  subtitle: const Text('Usar a câmera'),
                  onTap: () => Navigator.pop(context, 'camera'),
                ),
                ListTile(
                  leading: const Icon(Icons.photo_library, color: Colors.green),
                  title: const Text('Galeria'),
                  subtitle: const Text('Escolher da galeria'),
                  onTap: () => Navigator.pop(context, 'gallery'),
                ),
                ListTile(
                  leading: const Icon(Icons.close, color: Colors.red),
                  title: const Text('Cancelar'),
                  onTap: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (choice == null || !context.mounted) return null;

    // Executar a ação escolhida
    switch (choice) {
      case 'camera':
        return await takePicture(context);
      
      case 'gallery':
        return await pickFromGallery(context);
      
      default:
        return null;
    }
  }

  Future<String> savePicture(XFile image) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final fileName = 'task_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final savePath = path.join(appDir.path, 'images', fileName);
      
      final imageDir = Directory(path.join(appDir.path, 'images'));
      if (!await imageDir.exists()) {
        await imageDir.create(recursive: true);
      }
      
      final savedImage = await File(image.path).copy(savePath);
      print('✅ Foto salva: ${savedImage.path}');
      return savedImage.path;
    } catch (e) {
      print('❌ Erro ao salvar foto: $e');
      rethrow;
    }
  }

  Future<bool> deletePhoto(String photoPath) async {
    try {
      final file = File(photoPath);
      if (await file.exists()) {
        await file.delete();
        return true;
      }
      return false;
    } catch (e) {
      print('❌ Erro ao deletar foto: $e');
      return false;
    }
  }
}
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class CloudService {

  static const String baseUrl = 'http://10.0.2.2:3000'; // Android Emulator


  /// Upload de imagem em Base64
  static Future<Map<String, dynamic>> uploadImageBase64({
    required String imageBase64,
    required String taskId,
    String? fileName,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/upload/base64'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'imageBase64': imageBase64,
          'taskId': taskId,
          'fileName': fileName ?? 'image.jpg',
        }),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to upload image: ${response.body}');
      }
    } catch (e) {
      print('Error uploading image: $e');
      rethrow;
    }
  }

  /// Upload de imagem como Multipart
  static Future<Map<String, dynamic>> uploadImageMultipart({
    required File imageFile,
    required String taskId,
  }) async {
    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/api/upload/multipart'),
      );

      request.fields['taskId'] = taskId;
      request.files.add(
        await http.MultipartFile.fromPath(
          'image',
          imageFile.path,
        ),
      );

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to upload image: ${response.body}');
      }
    } catch (e) {
      print('Error uploading image: $e');
      rethrow;
    }
  }

  /// Salvar tarefa completa (com imagem, SQS, SNS e DynamoDB)
  static Future<Map<String, dynamic>> saveTask({
    required String id,
    required String title,
    required String description,
    String? imageBase64,
    Map<String, double>? location,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/tasks'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'id': id,
          'title': title,
          'description': description,
          'imageBase64': imageBase64,
          'location': location,
          'createdAt': DateTime.now().millisecondsSinceEpoch,
        }),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to save task: ${response.body}');
      }
    } catch (e) {
      print('Error saving task: $e');
      rethrow;
    }
  }

  /// Listar todas as tarefas do DynamoDB
  static Future<List<dynamic>> getTasks() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/tasks'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['tasks'] ?? [];
      } else {
        throw Exception('Failed to fetch tasks: ${response.body}');
      }
    } catch (e) {
      print('Error fetching tasks: $e');
      rethrow;
    }
  }

  /// Listar todas as imagens do S3
  static Future<List<dynamic>> getImages() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/images'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['images'] ?? [];
      } else {
        throw Exception('Failed to fetch images: ${response.body}');
      }
    } catch (e) {
      print('Error fetching images: $e');
      rethrow;
    }
  }

  /// Verificar se o backend está acessível
  static Future<bool> checkHealth() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/health'),
      ).timeout(const Duration(seconds: 5));

      return response.statusCode == 200;
    } catch (e) {
      print('Backend is not accessible: $e');
      return false;
    }
  }

  /// Converter arquivo de imagem para Base64
  static Future<String> fileToBase64(File file) async {
    try {
      final bytes = await file.readAsBytes();
      return 'data:image/jpeg;base64,${base64Encode(bytes)}';
    } catch (e) {
      print('Error converting file to base64: $e');
      rethrow;
    }
  }
}

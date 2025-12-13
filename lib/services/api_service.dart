import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/task.dart';

class ApiService {
  static final ApiService instance = ApiService._init();
  
  ApiService._init();

  // IMPORTANTE: Altere para o endpoint do seu backend
  // Para emulador Android: http://10.0.2.2:3000
  // Para dispositivo físico: http://SEU_IP_LOCAL:3000
  // Para produção: https://sua-api.com
  final String baseUrl = 'http://10.0.2.2:3000/api/tasks';
  
  final Duration timeout = const Duration(seconds: 10);
  
  // MODO TESTE: Se true, simula sucesso sem chamar API real
  // Útil para testar offline-first sem backend rodando
  bool testMode = true;  // Mude para false quando tiver backend real

  // Headers padrão
  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  // GET - Buscar todas as tarefas
  Future<List<Task>> fetchTasks() async {
    if (testMode) {
      print('🧪 MODO TESTE: Simulando fetchTasks');
      await Future.delayed(const Duration(milliseconds: 500));
      return [];
    }
    
    try {
      final response = await http
          .get(Uri.parse(baseUrl), headers: _headers)
          .timeout(timeout);

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => Task.fromMap(json)).toList();
      } else {
        throw Exception('Falha ao carregar tarefas: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Erro de rede: $e');
    }
  }

  // GET - Buscar tarefa por ID
  Future<Task> fetchTask(int id) async {
    if (testMode) {
      print('🧪 MODO TESTE: Simulando fetchTask($id) - não encontrado');
      await Future.delayed(const Duration(milliseconds: 500));
      throw Exception('Tarefa não encontrada: 404');
    }
    
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/$id'), headers: _headers)
          .timeout(timeout);

      if (response.statusCode == 200) {
        return Task.fromMap(jsonDecode(response.body));
      } else {
        throw Exception('Tarefa não encontrada: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Erro de rede: $e');
    }
  }

  // POST - Criar nova tarefa
  Future<Task> createTask(Task task) async {
    if (testMode) {
      print('🧪 MODO TESTE: Simulando createTask - ${task.title}');
      await Future.delayed(const Duration(milliseconds: 500));
      return task; // Retorna a mesma task como se tivesse sido criada
    }
    
    try {
      final response = await http
          .post(
            Uri.parse(baseUrl),
            headers: _headers,
            body: jsonEncode(task.toMap()),
          )
          .timeout(timeout);

      if (response.statusCode == 201 || response.statusCode == 200) {
        return Task.fromMap(jsonDecode(response.body));
      } else {
        throw Exception('Falha ao criar tarefa: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Erro de rede: $e');
    }
  }

  // PUT - Atualizar tarefa existente
  Future<Task> updateTask(Task task) async {
    if (testMode) {
      print('🧪 MODO TESTE: Simulando updateTask - ${task.title}');
      await Future.delayed(const Duration(milliseconds: 500));
      return task; // Retorna a mesma task como se tivesse sido atualizada
    }
    
    try {
      final response = await http
          .put(
            Uri.parse('$baseUrl/${task.id}'),
            headers: _headers,
            body: jsonEncode(task.toMap()),
          )
          .timeout(timeout);

      if (response.statusCode == 200) {
        return Task.fromMap(jsonDecode(response.body));
      } else {
        throw Exception('Falha ao atualizar tarefa: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Erro de rede: $e');
    }
  }

  // DELETE - Deletar tarefa
  Future<void> deleteTask(int id) async {
    if (testMode) {
      print('🧪 MODO TESTE: Simulando deleteTask($id)');
      await Future.delayed(const Duration(milliseconds: 500));
      return; // Simula sucesso
    }
    
    try {
      final response = await http
          .delete(Uri.parse('$baseUrl/$id'), headers: _headers)
          .timeout(timeout);

      if (response.statusCode != 200 && response.statusCode != 204) {
        throw Exception('Falha ao deletar tarefa: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Erro de rede: $e');
    }
  }

  // Verificar se API está disponível
  Future<bool> checkApiHealth() async {
    try {
      final response = await http
          .get(Uri.parse(baseUrl.replaceAll('/tasks', '/health')))
          .timeout(const Duration(seconds: 5));
      
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}

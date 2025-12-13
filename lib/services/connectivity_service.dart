import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';

class ConnectivityService {
  static final ConnectivityService instance = ConnectivityService._init();
  
  ConnectivityService._init();

  final Connectivity _connectivity = Connectivity();
  final StreamController<bool> _connectionController = StreamController<bool>.broadcast();
  
  bool _isOnline = true;
  StreamSubscription<List<ConnectivityResult>>? _subscription;

  // Stream para ouvir mudanças de conectividade
  Stream<bool> get connectionStream => _connectionController.stream;
  
  // Status atual
  bool get isOnline => _isOnline;

  // Inicializar monitoramento
  Future<void> initialize() async {
    // Verificar estado inicial
    await checkConnection();
    
    // Monitorar mudanças
    _subscription = _connectivity.onConnectivityChanged.listen((List<ConnectivityResult> results) {
      _updateConnectionStatus(results);
    });
  }

  // Verificar conectividade atual
  Future<bool> checkConnection() async {
    try {
      final results = await _connectivity.checkConnectivity();
      _updateConnectionStatus(results);
      return _isOnline;
    } catch (e) {
      print('❌ Erro ao verificar conectividade: $e');
      _isOnline = false;
      _connectionController.add(false);
      return false;
    }
  }

  // Atualizar status baseado nos resultados
  void _updateConnectionStatus(List<ConnectivityResult> results) {
    // Considera online se houver qualquer conexão (WiFi, mobile, ethernet, etc)
    final wasOnline = _isOnline;
    _isOnline = results.isNotEmpty && 
                !results.every((r) => r == ConnectivityResult.none);
    
    // Notificar mudança apenas se status mudou
    if (wasOnline != _isOnline) {
      print(_isOnline ? '🟢 ONLINE' : '🔴 OFFLINE');
      _connectionController.add(_isOnline);
    }
  }

  // Limpar recursos
  void dispose() {
    _subscription?.cancel();
    _connectionController.close();
  }
}

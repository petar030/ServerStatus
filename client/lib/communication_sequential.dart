import 'dart:async';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:async/async.dart'; // Paket za StreamQueue
import 'main.dart';
import 'authorization.dart';

class WebSocketClient {
  final String uri;
  WebSocketChannel? _channel;
  bool _isRunning = false;

  /// Stream to main
  final StreamController<String> _controller = StreamController<String>.broadcast();
  Stream<String> get stream => _controller.stream;

  /// Singleton instance
  static WebSocketClient? _instance;
  WebSocketClient._internal(this.uri);

  factory WebSocketClient({required String uri}) {
    _instance ??= WebSocketClient._internal(uri);
    return _instance!;
  }

  /// Client blocker
  Completer<void>? _blocker;
  Completer<void>? _completer;

  static void reset(String uri) {
    _instance?.dispose();
    _instance = WebSocketClient._internal(uri);
  }

  Future<bool> _connect() async {
    try {
      final wsUrl = Uri.parse(uri);
      _channel = WebSocketChannel.connect(wsUrl);
      await _channel?.ready;
      return true;
    } catch (e) {
      print('Connection error: $e');
      return false;
    }
  }

  Future<void> _communicate() async {
    if(_channel == null){
        return;
    }
    final queue = StreamQueue(_channel!.stream); // Kreiramo red za poruke
    _completer = Completer<void>();
    String msgWithStatus;

    String? accessToken = await AuthorizationClient.get_access_token();
    if(accessToken == null){
      if (!_completer!.isCompleted) _completer!.complete();
          await _channel?.sink.close(1000);
    }
    
    try{
      //AUTHORIZATION

      //Send access token
      _channel!.sink.add(accessToken);
      //Receive answer
      if (_channel!.closeCode != null) {
          print('Connection is closed. Close code: ${_channel!.closeCode}');
          if (!_completer!.isCompleted) _completer!.complete();

        }
      var answer = await queue.next;
      //If answer isn't 'SUCCESSFUL' send login page request 
      if (answer != 'SUCCESSFUL') {
          if (!_completer!.isCompleted) _completer!.complete();
          await _channel?.sink.close(1000);
          String authorizationError = '{"online": false, "login": true}';
          _controller.add(authorizationError); // Emituje poruku u stream

          
      }
      





      //COMMUNICATION
      while (!_completer!.isCompleted) {
        print("TRENUTNA RUTA: ${routeObserver.getCurrentRoute()}");
        String requestMsg = 'GET_HOME';
        if(routeObserver.getCurrentRoute() == '/cpuPage'){
          requestMsg = 'GET_CPU';
        }

        if (_completer != null && _completer!.isCompleted) break;
        _channel!.sink.add(requestMsg);

        if (_channel!.closeCode != null) {
          print('Connection is closed. Close code: ${_channel!.closeCode}');
          break; 
        }
        if (_completer != null && _completer!.isCompleted) break;
        var message = await queue.next;

      
        msgWithStatus = '{"online": true, "data": $message}';
        _controller.add(msgWithStatus); // Emituje poruku u stream
        await Future.delayed(Duration(milliseconds: 200));
      }
    }
    catch(error){
      print('Communication error: $error');
    }
    

    if (!_completer!.isCompleted) _completer!.complete();
    await _channel?.sink.close(1000);
    return;
  }

  Future<void> _initConnection() async {
    if (await _connect()) {
      print('Connected to server.');
      await _communicate();
      print('Session ended.');
    } else {
      print('Connection failed.');
    }
  }

  Future<void> startClient() async {
    if (_isRunning) {
      print("Client is already running");
      return;
    }
    _isRunning = true;

    String offlineMessage = '{"online": false, "login": false}';
    _blocker = Completer<void>();


    while (!_blocker!.isCompleted) {
      await _initConnection();
      print('Retrying in 5 seconds...');
      if(!_controller.isClosed) _controller.add(offlineMessage);
      if (_blocker!.isCompleted) break;
      await Future.delayed(Duration(seconds: 5));
    }

    _isRunning = false;
  }

  void block() {
    if (_blocker != null && !_blocker!.isCompleted) {
      _blocker!.complete();
      if (_completer != null && !_completer!.isCompleted) _completer!.complete();
      _channel?.sink.close(1000);
    }
  }

  void dispose() {
    _channel?.sink.close(1000);
    _controller.close();
    _isRunning = false;
  }
}

void main() {
  WebSocketClient client = WebSocketClient(uri: 'ws://192.168.1.7:8080/ws');
  client.startClient();
}

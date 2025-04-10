import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:server_status/firebase_options.dart';
import 'communication_sequential.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'authorization.dart';
import 'firebase_msg.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  //Notification service
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  await FirebaseMsg().initFCM();

  //App
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Namer App',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color.fromARGB(255, 26, 148, 109),
        ),
      ),
      home: LoginPage(),
    );
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _passwordController = TextEditingController();
  final _uriController = TextEditingController();
  final _nameController = TextEditingController();
  final _portController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _checkTokens();
  }

  Future<void> _checkTokens() async {
    setState(() {
      _isLoading = true;
    });


    //If notification token is updated, do a logout
    String? oldFcmToken = await AuthorizationClient.get_fcm_token();
    String? currFcmToken = await FirebaseMsg().getToken();

    print(currFcmToken);


    if(oldFcmToken != null && oldFcmToken != currFcmToken){
      await AuthorizationClient.logout();
      setState(() {
      _isLoading = false;
      });
      return;

    }


    String? uri = await AuthorizationClient.get_uri();
    String? name = await AuthorizationClient.get_name();

    bool areTokensValid = await AuthorizationClient.verify_tokens()
        .timeout(Duration(seconds: 10), onTimeout: () {
      return false;
    });

    if (!mounted) return;

    setState(() {
      _isLoading = false;
    });

    if (areTokensValid && uri != null && name != null) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
            builder: (context) => MyHomePage(uri: uri, name: name)),
      );
    }
  }

  Future<void> _login() async {
    setState(() {
      _isLoading = true;
    });

    String uri = _uriController.text.trim();
    String name = _nameController.text;
    String port = _portController.text;
    if (port == "") {
      if (uri.startsWith("http://")) port = '8080';
      if (uri.startsWith("https://")) port = '443';
    }

    uri = '$uri:$port';

    if (name == "") name = uri;

    bool isValid = await AuthorizationClient.verify_password(
        uri, _passwordController.text, name);

    if (uri == "" || port == "") isValid = false;

    if (!mounted) return;

    setState(() {
      _isLoading = false;
    });

    if (isValid) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
            builder: (context) => MyHomePage(uri: uri, name: name)),
      );
    } else {
      _showErrorDialog();
    }
  }

  void _showErrorDialog() {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text('Login Failed'),
          content: Text('Invalid password. Please try again.'),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              child: Text('OK'),
            ),
          ],
        );
      },
    );
  }

  // Future<void> _showToken() async{
  //   String token = await FirebaseMsg().getToken();
  //   Clipboard.setData(ClipboardData(text: token));

  //   ScaffoldMessenger.of(context).showSnackBar(SnackBar(
  //     content: Text('FCM Token: $token'),
  //     duration: Duration(seconds: 5),
  //   ));
  // }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Login')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'Connection name (optional)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Flexible(
                  flex: 3, // 3/4 širine
                  child: TextField(
                    controller: _uriController,
                    decoration: InputDecoration(
                      labelText: 'Server URI',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Flexible(
                  flex: 1, // 1/4 širine
                  child: TextField(
                    controller: _portController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Port (optional  )',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'Password',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            _isLoading
                ? CircularProgressIndicator()
                : ElevatedButton(
                    onPressed: _login,
                    child: Text('Login'),
                  ),
          ],
        ),
      ),
    );
  }
}

class MyHomePage extends StatelessWidget {
  final String uri;
  final String name;
  const MyHomePage({super.key, required this.uri, required this.name});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) =>
          MyAppState(uri: uri, logoutCallback: () => logout(context)),
      child: Builder(
        builder: (context) {
          var appState = context.watch<MyAppState>();

          Color statusDotColor = appState.online ? Colors.green : Colors.red;
          String statusText =
              appState.online ? "Server is online" : "Server is offline";

          return Scaffold(
            appBar: AppBar(
              title: Text(name),
              actions: [
                Row(
                  children: [
                    Text(statusText),
                    SizedBox(width: 5),
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: statusDotColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    SizedBox(width: 10),
                  ],
                ),
              ],
            ),
            body: Padding(
              padding: const EdgeInsets.all(20),
              child: PopScope(
                canPop: false,
                onPopInvokedWithResult: ((didPop, result) {
                  if (didPop) return;
                  _showExitDialog(context, appState);
                }),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CPUCard(appState: appState),
                      const SizedBox(height: 20),
                      MemoryCard(appState: appState),
                      const SizedBox(height: 20),
                      // ElevatedButton(
                      //   onPressed: () {
                      //     appState.pauseClient();
                      //   },
                      //   child: Text('Block'),
                      // ),
                      // ElevatedButton(
                      //   onPressed: () {
                      //     appState.unpauseClient();
                      //   },
                      //   child: Text('Start'),
                      // ),
                      ElevatedButton(
                        onPressed: () {
                          AuthorizationClient.logout();
                          appState.disposeClient();
                          logout(context);
                        },
                        child: Text('Log out'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void logout(BuildContext context) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => LoginPage()),
    );
  }
}

class MyAppState extends ChangeNotifier with WidgetsBindingObserver {
  bool online = false;
  var cpuTemp = 0;
  var cpuLoad = 0.0;
  var memUsed = 0.0;
  var memTotal = 0.0;
  late WebSocketClient client;
  late String uri;
  late Function logoutCallback; // Callback funkcija za logout

  MyAppState({required this.uri, required this.logoutCallback}) {
    uri = _modifyUri(uri);

    initClient();
    WidgetsBinding.instance.addObserver(this);
  }

  String _modifyUri(String uri) {
    if (uri.startsWith('http://')) {
      uri = 'ws://${uri.substring(7)}'; // Remove 'http://' and add 'ws://'
    } else if (uri.startsWith('https://')) {
      uri = 'wss://${uri.substring(8)}'; // Remove 'https://' and add 'wss://'
    }
    if (!uri.endsWith('/ws')) {
      uri = '$uri/ws';
    }

    return uri;
  }

  void initClient() {
    WebSocketClient.reset(uri);
    client = WebSocketClient(uri: uri);

    client.stream.listen((jsonString) {
      try {
        var jsonParsed = json.decode(jsonString);

        if (jsonParsed['online'] == true) {
          var jsonData = jsonParsed['data'];
          cpuTemp = (jsonData['cpu_temp'] as num?)?.toInt() ?? cpuTemp;
          cpuLoad = (jsonData['cpu_usage'] as num?)?.toDouble() ?? cpuLoad;
          memUsed = (jsonData['mem_used'] as num?)?.toDouble() ?? memUsed;
          memTotal = (jsonData['mem_total'] as num?)?.toDouble() ?? memTotal;
          online = true;
        } else {
          online = false;
          if (jsonParsed['login'] == true) {
            disposeClient();
            logoutCallback();
          }
        }

        notifyListeners();
      } catch (e) {
        print("JSON parsing error: $e");
      }
    });

    client.startClient();
  }

  void pauseClient() {
    client.block();
  }

  void unpauseClient() {
    client.startClient();
  }

  void disposeClient() {
    client.block();
    client.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      pauseClient();
    } else if (state == AppLifecycleState.resumed) {
      unpauseClient();
    } else if (state == AppLifecycleState.detached) {
      disposeClient();
    }
  }

  @override
  void dispose() {
    disposeClient();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}

void _showExitDialog(BuildContext context, MyAppState appState) {
  showDialog(
    context: context,
    builder: (BuildContext dialogContext) {
      return AlertDialog(
        title: Text('Exit confirmation'),
        content: Text('Do you want to exit this app?'),
        actions: <Widget>[
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
            },
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              appState.disposeClient();
              Navigator.of(dialogContext).pop();
              SystemNavigator.pop();
            },
            child: Text('Exit'),
          ),
        ],
      );
    },
  );
}

class CPUCard extends StatelessWidget {
  const CPUCard({super.key, required this.appState});
  final MyAppState appState;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final titleStyle = theme.textTheme.headlineSmall!.copyWith(
      color: theme.colorScheme.onSecondaryContainer,
      fontWeight: FontWeight.bold,
      fontSize: 24,
    );
    final itemStyle = theme.textTheme.bodyLarge!.copyWith(
      color: theme.colorScheme.onSecondaryContainer,
      fontSize: 18,
    );

    return Card(
      color: theme.colorScheme.secondaryContainer,
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("CPU", style: titleStyle),
            const SizedBox(height: 15),
            ListTile(
              title: Text("Temperature:", style: itemStyle),
              subtitle: Text("${appState.cpuTemp}°C", style: itemStyle),
            ),
            ListTile(
              title: Text("Load:", style: itemStyle),
              subtitle: Text("${appState.cpuLoad}%", style: itemStyle),
            ),
          ],
        ),
      ),
    );
  }
}

class MemoryCard extends StatelessWidget {
  const MemoryCard({super.key, required this.appState});
  final MyAppState appState;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final titleStyle = theme.textTheme.headlineSmall!.copyWith(
      color: theme.colorScheme.onSecondaryContainer,
      fontWeight: FontWeight.bold,
      fontSize: 24,
    );
    final itemStyle = theme.textTheme.bodyLarge!.copyWith(
      color: theme.colorScheme.onSecondaryContainer,
      fontSize: 18,
    );

    return Card(
      color: theme.colorScheme.secondaryContainer,
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Memory", style: titleStyle),
            const SizedBox(height: 15),
            ListTile(
              title: Text("Used Memory:", style: itemStyle),
              subtitle: Text("${appState.memUsed.toStringAsFixed(1)} %",
                  style: itemStyle),
            ),
            ListTile(
              title: Text("Total Memory:", style: itemStyle),
              subtitle: Text("${appState.memTotal.toStringAsFixed(1)} GB",
                  style: itemStyle),
            ),
          ],
        ),
      ),
    );
  }
}

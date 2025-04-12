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
      title: 'ServerStatus App',
      theme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.dark(
          surface: Colors.grey.shade900,
          primary: Colors.grey.shade800,
          secondary: Colors.grey.shade700,
          onPrimary: Colors.white70,
          onSecondary: Colors.white70,
          outline: const Color.fromARGB(255, 42, 72, 124),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.grey.shade800, // Boja pozadine
            foregroundColor: Colors.white70, // Boja teksta
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8.0), // Zakrivljenost ivica
            ),
            padding: EdgeInsets.symmetric(
                vertical: 12.0, horizontal: 16.0), // Padding
            elevation: 4, // Elevacija dugmeta (sjenka)
          ),
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

    String? oldFcmToken = await AuthorizationClient.get_fcm_token();
    String? currFcmToken = await FirebaseMsg().getToken();

    String? uri = await AuthorizationClient.get_uri();
    String? name = await AuthorizationClient.get_name();

    if (uri == null) {
      setState(() {
        _isLoading = false;
      });
      return;
    }

    bool available = await AuthorizationClient.ping(uri);
    if (!available) {
      autoConnectNotification(context, name);
      setState(() {
        _isLoading = false;
      });
      return;
    }

    //If notification token is updated, do a logout
    if (oldFcmToken != null && oldFcmToken != currFcmToken) {
      await AuthorizationClient.logout()
          .timeout(Duration(seconds: 10), onTimeout: () {});
      setState(() {
        _isLoading = false;
      });
      return;
    }

    bool areTokensValid = await AuthorizationClient.verify_tokens()
        .timeout(Duration(seconds: 10), onTimeout: () {
      return false;
    });

    if (!mounted) return;

    setState(() {
      _isLoading = false;
    });

    if (areTokensValid && name != null) {
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

  Future<void> _refresh() async {
    setState(() {
      _passwordController.clear();
      _uriController.clear();
      _nameController.clear();
      _portController.clear();
      _isLoading = false;
    });
    _checkTokens();
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

  void autoConnectNotification(BuildContext context, String? name) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text('Auto Connect Failed',
              style: TextStyle(fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.warning, color: Colors.redAccent),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "$name may be offline",
                      style: TextStyle(
                        fontWeight: FontWeight.bold, // Bold name
                        color: Theme.of(context).colorScheme.onSurface,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  GestureDetector(
                    onTap: () {
                      _refresh();
                      Navigator.of(dialogContext).pop(); // Close the dialog
                    },
                    child: Container(
                      padding:
                          EdgeInsets.symmetric(vertical: 12, horizontal: 20),
                      decoration: BoxDecoration(
                        color:
                            Theme.of(context).primaryColor, // Using theme color
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Try Again',
                        style: TextStyle(
                          color: Theme.of(context)
                              .colorScheme
                              .onPrimary, // Text color from theme
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 10), // Space between buttons
                  GestureDetector(
                    onTap: () {
                      Navigator.of(dialogContext).pop(); // Close the dialog
                    },
                    child: Container(
                      padding:
                          EdgeInsets.symmetric(vertical: 12, horizontal: 20),
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .secondary, // Using theme color
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          color: Theme.of(context)
                              .colorScheme
                              .onSecondary, // Text color from theme
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Login'),
        titleTextStyle:
            TextStyle(color: Theme.of(context).colorScheme.onPrimary),
      ),
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

  String formatUptime(int uptimeInSeconds) {
  int hours = uptimeInSeconds ~/ 3600;
  int minutes = (uptimeInSeconds % 3600) ~/ 60;
  int seconds = uptimeInSeconds % 60;

  return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
}

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) =>
          MyAppState(uri: uri, logoutCallback: () => logout(context)),
      child: Builder(
        builder: (context) {
          var appState = context.watch<MyAppState>();

          return Scaffold(
            appBar: AppBar(
              leading: IconButton(
                icon: Icon(Icons.exit_to_app, size: 24.0),
                onPressed: () {
                  AuthorizationClient.logout();
                  appState.disposeClient();
                  logout(context);
                },
              ),
              title: Center(
                child: Text(
                  name,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.bold,
                    fontSize: 24,
                  ),
                ),
              ),
              titleTextStyle: TextStyle(
                color: Theme.of(context).colorScheme.onPrimary,
                fontSize: 19,
              ),
              actions: [
                Row(
                  children: [
                    Icon(
                      appState.online ? Icons.wifi : Icons.signal_wifi_off,
                      size: 24.0,
                      color: appState.online ? Colors.green : Colors.red,
                    ),
                    SizedBox(width: 10),
                  ],
                ),
              ],
            ),
            body: Padding(
              padding: const EdgeInsets.only(
                top: 10.0,
                left: 20.0,
                right: 20.0,
                bottom: 20.0,
              ),
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
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => SecondPage(appState: appState),
                            ),
                          );
                        },
                        child: CPUCard(appState: appState),
                      ),
                      const SizedBox(height: 20),
                      MemoryCard(appState: appState),
                      const SizedBox(height: 20),
                      NetworkCard(appState: appState),
                      const SizedBox(
                        height: 20,
                      ),
                      Text(
                        "Up time: ${formatUptime(appState.upTime)}",
                        style: Theme.of(context).textTheme.bodyLarge!.copyWith(
                              color: Theme.of(context).colorScheme.onPrimary,
                              fontSize: 22, 
                            ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            floatingActionButton: Align(
              alignment: Alignment.bottomCenter,
              child: AnimatedOpacity(
                opacity: appState.online ? 0.0 : 1.0, // Ovisno o statusu mreže
                duration: Duration(
                    milliseconds: 1500), // Vreme za koje se indikator povlači
                child: Container(
                  width: 250.0, // Postavite širinu na fiksnu vrednost
                  height: 60.0, // Visina dugmeta
                  decoration: BoxDecoration(
                    color: appState.online
                        ? Colors.green
                        : Colors.red, // Zeleni za online, crveni za offline
                    borderRadius: BorderRadius.circular(15), // Zaobljeni ivici
                  ),
                  child: Center(
                    child: Text(
                      appState.online
                          ? 'Connection established' // Poruka kada je online
                          : 'Server not connected', // Poruka kada je offline
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
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
  var interfaceName = "";
  var downSpeed = 0.0;
  var upSpeed = 0.0;
  var upTime = 0;
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
          interfaceName =
              jsonData['interface_name']?.toString() ?? interfaceName;
          upSpeed = (jsonData['up_speed'] as num?)?.toDouble() ?? upSpeed;
          downSpeed = (jsonData['down_speed'] as num?)?.toDouble() ?? downSpeed;
          upTime = (jsonData['uptime'] as num?)?.toInt() ?? upTime;
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
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: Text(
          'Exit confirmation',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onPrimaryContainer,
          ),
        ),
        content: Text(
          'Do you want to exit this app?',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onPrimaryContainer,
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
            },
            child: Text(
              'Cancel',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              appState.disposeClient();
              Navigator.of(dialogContext).pop();
              SystemNavigator.pop();
            },
            child: Text(
              'Exit',
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
              ),
            ),
          ),
        ],
      );
    },
  );
}

Color getGradientColor(double value) {
  value = value.clamp(0.0, 100.0);

  Color startColor = Colors.green;
  Color endColor = Colors.red;

  return Color.lerp(startColor, endColor, value / 100)!;
}

class CPUCard extends StatelessWidget {
  const CPUCard({super.key, required this.appState});
  final MyAppState appState;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final titleStyle = theme.textTheme.headlineSmall!.copyWith(
      color: theme.colorScheme.onPrimaryContainer,
      fontWeight: FontWeight.bold,
      fontSize: 28, // Povećano za bolji izgled
    );
    final itemStyle = theme.textTheme.bodyLarge!.copyWith(
      color: theme.colorScheme.onPrimaryContainer,
      fontSize: 20, // Povećano za bolji izgled
    );

    return Card(
      color: theme.colorScheme.primaryContainer,
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "CPU",
              style: titleStyle,
            ),
            const SizedBox(height: 15),
            ListTile(
              leading: Icon(
                Icons.memory,
                color: theme.colorScheme.secondary,
                size: 28, // Povećana veličina ikone
              ),
              title: Text("Load:", style: itemStyle),
              subtitle: Row(
                children: [
                  Expanded(
                    child: LinearProgressIndicator(
                      value: appState.cpuLoad / 100,
                      minHeight: 10,
                      borderRadius: BorderRadius.circular(15),
                      color: getGradientColor(appState.cpuLoad),
                      backgroundColor:
                          theme.colorScheme.onPrimaryContainer.withAlpha(38),
                    ),
                  ),
                  SizedBox(width: 10),
                  Text("${appState.cpuLoad}%",
                      style: itemStyle,
                      key: ValueKey<double>(appState.cpuLoad)),
                ],
              ),
            ),
            ListTile(
              leading: Icon(
                Icons.thermostat,
                color: getGradientColor(appState.cpuTemp.toDouble()),
                size: 28, // Povećana veličina ikone
              ),
              title: Text("Temperature:", style: itemStyle),
              subtitle: Row(
                children: [
                  Text(
                    "${appState.cpuTemp}°C",
                    style: itemStyle,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class MemoryUsagePainter extends CustomPainter {
  final double usage;
  final Color backgroundColor;

  MemoryUsagePainter({
    required this.usage,
    required this.backgroundColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final center = rect.center;
    final radius = size.width / 2;

    final backgroundPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 16;

    final usagePaint = Paint()
      ..color = getGradientColor(usage * 100)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 16;

    final startAngle = -3.14; // levo
    final sweepAngle = 3.14 * usage;

    // Crtaj pozadinski luk (pun polukrug)
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      3.14,
      false,
      backgroundPaint,
    );

    // Crtaj zauzeće
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      usagePaint,
    );
  }

  @override
  bool shouldRepaint(covariant MemoryUsagePainter oldDelegate) {
    return oldDelegate.usage != usage;
  }
}

class MemoryCard extends StatelessWidget {
  const MemoryCard({super.key, required this.appState});
  final MyAppState appState;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final titleStyle = theme.textTheme.headlineSmall!.copyWith(
      color: theme.colorScheme.onPrimaryContainer,
      fontWeight: FontWeight.bold,
      fontSize: 28, // Jednako kao u CPUCard
    );
    final itemStyle = theme.textTheme.bodyLarge!.copyWith(
      color: theme.colorScheme.onPrimaryContainer,
      fontSize: 20,
    );

    final memUsedPercent = appState.memUsed / 100;

    return Card(
      color: theme.colorScheme.primaryContainer,
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: SizedBox(
          width: double.infinity,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Naslov "Memory"
              Text("Memory", style: titleStyle),

              // Veći razmak između naslova i kružnog prikaza
              const SizedBox(height: 50),

              // Kružni prikaz zauzeća memorije
              Center(
                child: SizedBox(
                  width: 180,
                  height: 120,
                  child: CustomPaint(
                    painter: MemoryUsagePainter(
                      usage: memUsedPercent,
                      backgroundColor:
                          theme.colorScheme.onPrimaryContainer.withAlpha(38),
                    ),
                    child: Center(
                      child: Text(
                        "${appState.memUsed.toStringAsFixed(1)} %",
                        style: titleStyle.copyWith(fontSize: 22),
                      ),
                    ),
                  ),
                ),
              ),
              // Max Memory info
              ListTile(
                leading: Icon(
                  Icons.storage_outlined,
                  color: theme.colorScheme.secondary,
                  size: 28,
                ),
                title: Text("Max Memory:", style: itemStyle),
                subtitle: Text(
                  "${appState.memTotal.toStringAsFixed(1)} GB",
                  style: itemStyle,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class NetworkCard extends StatelessWidget {
  const NetworkCard({super.key, required this.appState});
  final MyAppState appState;

  String formatSpeed(double speedInBytes) {
    if (speedInBytes < 1024) {
      return "${speedInBytes.toStringAsFixed(2)} B/s";
    } else if (speedInBytes < 1024 * 1024) {
      return "${(speedInBytes / 1024).toStringAsFixed(2)} KB/s";
    } else {
      return "${(speedInBytes / (1024 * 1024)).toStringAsFixed(2)} MB/s";
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final titleStyle = theme.textTheme.headlineSmall!.copyWith(
      color: theme.colorScheme.onPrimaryContainer,
      fontWeight: FontWeight.bold,
      fontSize: 28,
    );
    final itemStyle = theme.textTheme.bodyLarge!.copyWith(
      color: theme.colorScheme.onPrimaryContainer,
      fontSize: 20,
    );

    return Card(
      color: theme.colorScheme.primaryContainer,
      elevation: 12,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Network",
              style: titleStyle.copyWith(
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 15),
            ListTile(
              leading: Icon(
                Icons.network_cell,
                color: theme.colorScheme.onPrimaryContainer,
                size: 28,
              ),
              title: Text("Interface Name", style: itemStyle),
              subtitle: Text(
                appState.interfaceName,
                style: itemStyle.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildSpeedColumn(
                  icon: Icons.upload_outlined,
                  speed: appState.upSpeed,
                  color: Colors.green,
                ),
                _buildSpeedColumn(
                  icon: Icons.download_outlined,
                  speed: appState.downSpeed,
                  color: Colors.red,
                ),
              ],
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Widget _buildSpeedColumn({
    required IconData icon,
    required double speed,
    required Color color,
  }) {
    return Column(
      children: [
        Icon(
          icon,
          color: color,
          size: 40, // Povećane ikone za upload i download
        ),
        const SizedBox(height: 5),
        Text(
          formatSpeed(speed),
          style: TextStyle(
            fontSize: 24, // Povećan font za brzine
            color: color,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

class SecondPage extends StatelessWidget {
  final MyAppState appState;

  const SecondPage({super.key, required this.appState});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: appState,
      child: Scaffold(
        appBar: AppBar(
          title: Text('Second Page'),
        ),
        body: Consumer<MyAppState>(
          builder: (context, appState, child) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('CPU Temperature: ${appState.cpuTemp}°C'),
                  Text('CPU Load: ${appState.cpuLoad}%'),
                  Text('Memory Used: ${appState.memUsed}%'),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:server_status/authorization.dart';
import 'package:server_status/communication_sequential.dart';
import 'package:server_status/cpu_page.dart';
import 'package:server_status/login_page.dart';

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
                                builder: (_) => CpuPage(
                                      appState: appState,
                                    ),
                                settings: RouteSettings(name: '/cpuPage')),
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
                opacity: appState.online ? 0.0 : 1.0,
                duration: Duration(milliseconds: 1500),
                child: Container(
                  width: 250.0,
                  height: 60.0,
                  decoration: BoxDecoration(
                    color: appState.online ? Colors.green : Colors.red,
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Center(
                    child: Text(
                      appState.online
                          ? 'Connection established'
                          : 'Server not connected',
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
            floatingActionButtonLocation:
                FloatingActionButtonLocation.centerFloat,
          );
        },
      ),
    );
  }

  void logout(BuildContext context) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
          builder: (context) => LoginPage(),
          settings: RouteSettings(name: '/loginPage')),
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
  List<double> cpuCoreLoads = [];

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
        print(jsonString);

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
          cpuCoreLoads = List<double>.from(
              jsonData['cpu_core_loads'].map((item) => item.toDouble()));

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
      fontSize: 25,
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
                  Text(
                    "${appState.cpuLoad.toStringAsFixed(1)}%",
                    style: itemStyle,
                  ),
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
      fontSize: 25, // Jednako kao u CPUCard
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
      fontSize: 25,
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
            Text("Network", style: titleStyle),
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
            fontSize: 19, // Povećan font za brzine
            color: color,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

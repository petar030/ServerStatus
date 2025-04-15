import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:server_status/home_page.dart';

class CpuPage extends StatelessWidget {
  final MyAppState appState;

  const CpuPage({super.key, required this.appState});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: appState,
      child: Scaffold(
        appBar: AppBar(
          title: Text('CPU '),
          titleTextStyle: TextStyle(
            color: Theme.of(context).colorScheme.onPrimary,
            fontSize: 24,
          ),
          actions: [
            Consumer<MyAppState>(
              builder: (context, appState, _) => Row(
                children: [
                  Icon(
                    appState.online ? Icons.wifi : Icons.signal_wifi_off,
                    size: 24.0,
                    color: appState.online ? Colors.green : Colors.red,
                  ),
                  SizedBox(width: 10),
                ],
              ),
            ),
          ],
        ),
        body: Consumer<MyAppState>(
          builder: (context, appState, child) {
            return SingleChildScrollView(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    children: [
                      Container(
                        padding: EdgeInsets.all(20.0),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Theme.of(context).colorScheme.shadow,
                              spreadRadius: 1,
                              blurRadius: 4,
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Details",
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineSmall!
                                  .copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onPrimaryContainer,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 25,
                                  ),
                            ),
                            SizedBox(height: 20),
                            Text.rich(
                              TextSpan(
                                children: [
                                  TextSpan(
                                    text: "Temperature: ",
                                    style: TextStyle(
                                        color: Colors.white, fontSize: 18),
                                  ),
                                  TextSpan(
                                    text: "${appState.cpuTemp} °C",
                                    style: TextStyle(
                                      color: getGradientColor(
                                          appState.cpuTemp.toDouble()),
                                      fontSize: 18,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text.rich(
                              TextSpan(
                                children: [
                                  TextSpan(
                                    text: "Load: ",
                                    style: TextStyle(
                                        color: Colors.white, fontSize: 18),
                                  ),
                                  TextSpan(
                                    text:
                                        "${appState.cpuLoad.toStringAsFixed(2)} %",
                                    style: TextStyle(
                                      color: getGradientColor(appState.cpuLoad),
                                      fontSize: 18,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              "Physical Cores: ${appState.cpuPhysicalCores}",
                              style: TextStyle(fontSize: 18),
                            ),
                            Text(
                              "Logical Cores: ${appState.cpuLogicalCores}",
                              style: TextStyle(fontSize: 18),
                            ),
                            Text(
                              "Frequency: ${appState.cpuFrequency.toStringAsFixed(2)} GHz",
                              style: TextStyle(fontSize: 18),
                            ),
                            Text(
                              "Process Count: ${appState.cpuProcessNum}",
                              style: TextStyle(fontSize: 18),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 20),
                      Container(
                        padding: EdgeInsets.all(20.0),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Theme.of(context).colorScheme.shadow,
                              spreadRadius: 1,
                              blurRadius: 4,
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            Text(
                              "Cores",
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineSmall!
                                  .copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onPrimaryContainer,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 25,
                                  ),
                            ),
                            SizedBox(height: 20),
                            CpuCoreLoadGrid(appState: appState),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
        floatingActionButton: Consumer<MyAppState>(
          builder: (context, appState, _) => Align(
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
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      ),
    );
  }
}

class CpuCoreLoadGrid extends StatelessWidget {
  final MyAppState appState;

  CpuCoreLoadGrid({required this.appState});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      physics: NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10.0,
        mainAxisSpacing: 10.0,
        childAspectRatio: 2.0,
      ),
      itemCount: appState.cpuCoreLoads.length,
      itemBuilder: (context, index) {
        double coreLoad = appState.cpuCoreLoads[index];
        return CpuCoreLoadWidget(index: index, coreLoad: coreLoad);
      },
    );
  }
}

class CpuCoreLoadWidget extends StatelessWidget {
  final int index;
  final double coreLoad;

  const CpuCoreLoadWidget({
    Key? key,
    required this.index,
    required this.coreLoad,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: double.infinity,
          height: 100,
          child: Stack(
            alignment: Alignment.bottomCenter,
            children: [
              Container(
                color: Theme.of(context).colorScheme.primaryContainer,
              ),
              FractionallySizedBox(
                widthFactor: 1.0,
                heightFactor: (coreLoad / 100).clamp(0.01, 1.0),
                child: Container(
                  color: getGradientColor(coreLoad),
                ),
              ),
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Core ${index + 1}',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                    ),
                    SizedBox(height: 10),
                    Text(
                      'Load: ${coreLoad.toStringAsFixed(1)}%',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

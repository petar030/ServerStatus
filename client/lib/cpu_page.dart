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
          title: Text('CPU Core Loads'),
        ),
        body: Consumer<MyAppState>(
          builder: (context, appState, child) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  //mainAxisAlignment: MainAxisAlignment.center,
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
                        children: [
                          Text(
                      "CPU Cores",
                      style:
                          Theme.of(context).textTheme.headlineSmall!.copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onPrimaryContainer,
                                fontWeight: FontWeight.bold,
                                fontSize: 25,
                              ),
                    ), SizedBox(height: 20),
                          SingleChildScrollView(
                            child: SizedBox(
                              height: 500,
                              child: CpuCoreLoadGrid(appState: appState),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
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

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:server_status/firebase_options.dart';
import 'package:server_status/login_page.dart';
import 'firebase_msg.dart';


final RouteObserverCustom routeObserver = RouteObserverCustom();

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

class RouteObserverCustom extends NavigatorObserver {
  String? currentRoute;

  @override
  void didPush(Route<dynamic> route, Route? previousRoute) {
    currentRoute = route.settings.name;
  }

  @override
  void didPop(Route<dynamic> route, Route? previousRoute) {
    currentRoute = previousRoute?.settings.name;
  }

  @override
  void didPopNext(Route<dynamic> route) {
    currentRoute = route.settings.name;
  }

  String? getCurrentRoute() {
    return currentRoute;
  }
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
      navigatorObservers: [routeObserver], 
      initialRoute: '/homePage',
     routes: {
       '/homePage': (context) => LoginPage(),
    },
    );
  }
}


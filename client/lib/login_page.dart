import 'package:flutter/material.dart';
import 'package:server_status/authorization.dart';
import 'package:server_status/firebase_msg.dart';
import 'package:server_status/home_page.dart';

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
            builder: (context) => MyHomePage(uri: uri, name: name),
            settings: RouteSettings(name: '/homePage')),
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
            builder: (context) => MyHomePage(uri: uri, name: name),
            settings: RouteSettings(name: '/homePage')
),
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
                      Navigator.of(dialogContext).pop(); 
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


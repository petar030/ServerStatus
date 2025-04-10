import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:server_status/firebase_msg.dart';



class AuthorizationClient {

  static final _storage = FlutterSecureStorage();

  static Future<void> _set_access_token(String token) async {
    await _storage.write(key: 'access_token', value: token);
  }

  static Future<String?> get_access_token() async {
    return await _storage.read(key: 'access_token');
  }

  static Future<void> _set_refresh_token(String token) async {
    await _storage.write(key: 'refresh_token', value: token);
  }

  static Future<String?> get_refresh_token() async {
    return await _storage.read(key: 'refresh_token');
  }

  static Future<void> _set_fcm_token(String fcm_token) async {
    await _storage.write(key: 'fcm_token', value: fcm_token);
  }

  static Future<String?> get_fcm_token() async {
    return await _storage.read(key: 'fcm_token');
  }


  static Future<void> _set_uri(String uri) async {
    await _storage.write(key: 'uri', value: uri);
  }

  static Future<String?> get_uri() async {
    return await _storage.read(key: 'uri');
  }

  static Future<void> set_name(String name) async{
    await _storage.write(key: 'name', value: name);
  }

   static Future<String?> get_name() async {
    return await _storage.read(key: 'name');
  }

  static Future<bool> _verify_token(String uri, String token) async {
    try {
      final url = Uri.parse(uri);

      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        try {
          final responseBody = jsonDecode(response.body);
          if (responseBody.containsKey('access_token') &&
              responseBody.containsKey('refresh_token')) {
               _set_access_token(responseBody['access_token']);
              _set_refresh_token(responseBody['refresh_token']); 
          } 
        } catch (e) {
          print('Valid access token');
        }
        return true;
      } else {
        print('Invalid or expired token');
        return false;
      }
    } catch (e) {
      print('Error sending request: $e');
      return false;
    }
  }
  
  static Future<bool> verify_password(String uri, String password, String name) async {
  try {
    String loginUri = '$uri/login';
    String fcm_token = await FirebaseMsg().getToken();
    final response = await http.post(
      Uri.parse(loginUri),
      body: {
        'password': password,
        'fcm_token': fcm_token
      },

    );

    if (response.statusCode == 200) {
      var jsonResponse = jsonDecode(response.body);
      _set_access_token(jsonResponse['access_token']);
      _set_refresh_token(jsonResponse['refresh_token']);
      _set_fcm_token(fcm_token);
      _set_uri(uri);
      set_name(name);
      return true;
    } else {
      return false;
    }
  } catch (e) {
    print("Greška prilikom slanja zahteva: $e");
    return false;
  }
}

  static Future<bool> verify_tokens() async{
    String? uri = await get_uri();
    String? access_token = await get_access_token();
    String? refresh_token = await get_refresh_token();
    if(uri == null || access_token == null || refresh_token == null) return false;
    String authUri = '$uri/auth';

    bool isValid = await _verify_token(authUri, access_token);
    if(isValid) return true;

    isValid = await _verify_token(authUri, refresh_token);

    return isValid;


  }

  static Future<void> logout() async {


      String? uri = await get_uri();


      await _storage.delete(key: 'access_token');
      await _storage.delete(key: 'refresh_token');
      await _storage.delete(key: 'uri');
      
      String? fcm_token = await get_fcm_token();
      if(uri == null || fcm_token == null) return;
      
      String logoutUri = '$uri/logout';
      await http.post(
      Uri.parse(logoutUri),
      body: {'fcm_token': fcm_token},
      );

    
      
    }

  static Future<void> test() async{
    // await _set_access_token('--');
    // await _set_refresh_token('eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ0b2tlbl90eXBlIjoicmVmcmVzaCIsImV4cCI6MTc0NDQ2MjUwNCwiaWF0IjoxNzQzODU3NzA0fQ.nRQ7fPyhruPnS0uxOniBrxfy4FJNfLN_iYMMvVxtnqc');
    // await verify_tokens('http://192.168.1.7:8080/auth');
    String? tmp = await get_access_token();
    print(tmp);
  }

  
}



void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // bool isValid = await AuthorizationClient.verify_password('http://192.168.1.7:8080/login', 'pirot2003');

  // if (isValid) {
  //   print('Log in successful!');
  // } else {
  //   print('Log in unsuccessful!');
  // }

  await AuthorizationClient.test();


}

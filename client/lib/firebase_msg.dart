import 'package:firebase_messaging/firebase_messaging.dart';

class FirebaseMsg {
  final msgService = FirebaseMessaging.instance;

  initFCM() async {
    await msgService.requestPermission();
    FirebaseMessaging.onBackgroundMessage(handlerNotificatoin);
    FirebaseMessaging.onMessage.listen(handlerNotificatoin);
  }

  Future<String> getToken() async{
    String? token = await msgService.getToken();
    if(token == null ) {
      return " ";
    } else {
      return token;
    }
  }

  Future<void> deleteToken() async{
    await msgService.deleteToken();
  }
}


Future<void> handlerNotificatoin(RemoteMessage msg) async{
}
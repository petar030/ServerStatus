import 'package:firebase_messaging/firebase_messaging.dart';

class FirebaseMsg {
  final msgService = FirebaseMessaging.instance;

  initFCM() async {
    await msgService.requestPermission();
    var token = await msgService.getToken();
    print("Token: $token");
    FirebaseMessaging.onBackgroundMessage(handlerNotificatoin);
    FirebaseMessaging.onMessage.listen(handlerNotificatoin);
  }
}


Future<void> handlerNotificatoin(RemoteMessage msg) async{
}
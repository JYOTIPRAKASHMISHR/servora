import 'package:firebase_database/firebase_database.dart';


class NotificationHelper {


static final DatabaseReference ref =
FirebaseDatabase.instance.ref("notifications");



static Future<void> createNotification({

required String userId,
required String serviceId,
required String message,
required String type,

}) async {


await ref.push().set({

"userId":userId,

"serviceId":serviceId,

"message":message,

"type":type,

"createdAt":
DateTime.now().toString(),

});


}


}
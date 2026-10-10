import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

import 'notification_service.dart';


class NotificationListenerService {


static StreamSubscription? subscription;



static void startListening(){


User? user =
FirebaseAuth.instance.currentUser;


if(user == null){
return;
}



subscription =
FirebaseDatabase.instance
.ref("notifications")
.child(user.uid)
.onChildAdded
.listen((event){



if(event.snapshot.value == null){
return;
}



Map notification =
Map<String,dynamic>.from(
event.snapshot.value as Map
);



if(notification["receiverId"] == user.uid){



NotificationService.showDatabaseNotification(

"Servora",

notification["message"],

);



}



});



}




static void stopListening(){


subscription?.cancel();


}


}
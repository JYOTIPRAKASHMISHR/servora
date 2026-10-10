import 'package:firebase_database/firebase_database.dart';



class ChatService {


final DatabaseReference chatRef =
FirebaseDatabase.instance.ref("chats");





// Generate same chat room for customer and worker

String getChatId(

String serviceId,

String customerId,

String workerId,

){

return "${serviceId}_${customerId}_$workerId";

}








// SEND MESSAGE

Future<void> sendMessage({

required String serviceId,

required String customerId,

required String workerId,

required String senderId,

required String message,

String type="text",

double? amount,

//required double customerBudget,

}) async{





// PRICE VALIDATION

if(type=="price"){


if(amount==null){

throw Exception(
"Invalid price"
);

}



if(type=="price"){

  

}


}







String chatId =
getChatId(

serviceId,

customerId,

workerId,

);







DatabaseReference messageRef =

chatRef

.child(chatId)

.child("messages")

.push();









await messageRef.set({



"message":
message,



"senderId":
senderId,



"time":
DateTime.now().toString(),



"type":
type,



"amount":
amount,



});



}









// GET MESSAGE STREAM


Stream<DatabaseEvent> getMessages({


required String serviceId,


required String customerId,


required String workerId,


}){


String chatId =

getChatId(

serviceId,

customerId,

workerId,

);





return chatRef

.child(chatId)

.child("messages")

.orderByChild("time")

.onValue;



}









// CREATE CHAT ROOM


Future<void> createChatRoom({


required String serviceId,


required String customerId,


required String workerId,


}) async{



String chatId =

getChatId(

serviceId,

customerId,

workerId,

);





await chatRef

.child(chatId)

.update({



"serviceId":
serviceId,



"customerId":
customerId,



"workerId":
workerId,



"createdAt":
DateTime.now().toString(),



});



}





// ACCEPT PRICE

Future<void> acceptPrice({

  required String serviceId,

  required String customerId,

  required String workerId,

  required String applicationId,

  required double finalPrice,

  required String acceptedBy,

}) async {

  String chatId =
      getChatId(
        serviceId,
        customerId,
        workerId,
      );

  // Update Chat
  await chatRef.child(chatId).update({

    "priceAccepted": true,

    "acceptedPrice": finalPrice,

    "acceptedBy": acceptedBy,

    "acceptedAt": DateTime.now().toString(),

  });

  // Update Service
  await FirebaseDatabase.instance
      .ref("services")
      .child(serviceId)
      .update({

    "status": "assigned",

    "assignedWorkerId": workerId,

    "acceptedApplicationId": applicationId,

    "finalPrice": finalPrice,

    "acceptedAt": DateTime.now().toString(),

  });

  // Accept selected application
  await FirebaseDatabase.instance
      .ref("applications")
      .child(applicationId)
      .update({

    "status": "accepted",

  });

  // Reject remaining applications
  DatabaseEvent event =
      await FirebaseDatabase.instance
          .ref("applications")
          .once();

  if (event.snapshot.exists) {

    Map apps =
        Map.from(event.snapshot.value as Map);

    for (var item in apps.entries) {

      Map app = Map.from(item.value);

      if (app["serviceId"] == serviceId &&
          item.key != applicationId) {

        await FirebaseDatabase.instance
            .ref("applications")
            .child(item.key)
            .update({

          "status": "rejected",

        });

      }

    }

  }

}




// REJECT PRICE

Future<void> rejectPrice({

  required String serviceId,

  required String customerId,

  required String workerId,

}) async {

  String chatId =
      getChatId(
        serviceId,
        customerId,
        workerId,
      );

  await chatRef
      .child(chatId)
      .update({

    "priceAccepted": false,

    "rejectedAt": DateTime.now().toString(),

  });

}

Stream<DatabaseEvent> getChatRoom({

  required String serviceId,

  required String customerId,

  required String workerId,

}) {

  String chatId =
      getChatId(
        serviceId,
        customerId,
        workerId,
      );

  return chatRef
      .child(chatId)
      .onValue;

}


}
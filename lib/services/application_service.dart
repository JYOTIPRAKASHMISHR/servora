import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';


class ApplicationService{


final DatabaseReference ref =
FirebaseDatabase.instance.ref("applications");



Future<void> applyJob({

required String serviceId,

required String customerId,

required String price,

required String message,


})async{


String workerId =
FirebaseAuth.instance.currentUser!.uid;



DatabaseReference applicationRef =
ref.push();



await applicationRef.set({

"applicationId":
applicationRef.key,


"serviceId":
serviceId,


"customerId":
customerId,


"workerId":
workerId,


"price":
price,


"message":
message,


"status":
"pending",


"createdAt":
DateTime.now().toString(),


});


}



}
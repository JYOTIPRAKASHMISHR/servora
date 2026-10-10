import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

class AuthService {

final FirebaseAuth auth =
FirebaseAuth.instance;

final DatabaseReference database =
FirebaseDatabase.instance.ref();

Future registerUser({
required String name,
required String email,
required String phone,
required String job,
required String password,
}) async {
try{
// Create Firebase Authentication User
UserCredential userCredential =
await auth.createUserWithEmailAndPassword(
email: email,
password: password,
);
String uid =
userCredential.user!.uid;
// Store data in Realtime Database

await database
.child("users")
.child(uid)
.set({
"name":name,
"email":email,
"phone":phone,
"job":job,
"uid":uid,
"createdAt":
DateTime.now().toString(),
});

return true;
}

catch(e){

print(e.toString());

return false;
}
}


Future<User?> loginUser({

required String email,

required String password,


}) async {


try{


UserCredential credential =
await auth.signInWithEmailAndPassword(

email: email,

password: password,

);


return credential.user;


}

catch(e){

print(e.toString());

return null;

}


}

}
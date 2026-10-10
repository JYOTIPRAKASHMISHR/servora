import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';



class WorkerIdentityVerification extends StatefulWidget {

  const WorkerIdentityVerification({
    super.key,
  });


  @override
  State<WorkerIdentityVerification> createState() =>
      _WorkerIdentityVerificationState();

}



class _WorkerIdentityVerificationState
extends State<WorkerIdentityVerification>{



final FirebaseAuth auth =
FirebaseAuth.instance;



final DatabaseReference database =
FirebaseDatabase.instance.ref();



String selectedIdType =
"Aadhaar Card";



File? idFront;

File? idBack;

File? selfie;



bool uploading=false;



final List<String> idTypes=[

"Aadhaar Card",

"PAN Card",

"Driving License"

];




Future<File?> pickImage() async{


final picker =
ImagePicker();


XFile? image =
await picker.pickImage(

source:ImageSource.gallery,

imageQuality:80,

);


if(image==null){

return null;

}


return File(image.path);


}






Future<void> uploadImages() async{


setState((){

uploading=true;

});



try{


User? user =
auth.currentUser;


if(user==null){

return;

}

String uid =user.uid;
Future<String> uploadFile(
File file,
String name
) async {

return "";
}

String? frontUrl;


String? backUrl;


String? selfieUrl;




if(idFront!=null){

frontUrl =
await uploadToStorage(
idFront!,
"$uid/id_front"
);

}



if(idBack!=null){

backUrl =
await uploadToStorage(
idBack!,
"$uid/id_back"
);

}



if(selfie!=null){

selfieUrl =
await uploadToStorage(
selfie!,
"$uid/selfie"
);

}

await database
.child("workers")
.child(uid)
.child("verification")
.set({

"level":0,


"identityVerification":{

"idType":
selectedIdType,


"idFront":
frontUrl ?? "",


"idBack":
backUrl ?? "",


"selfie":
selfieUrl ?? "",


"status":
"pending"

}


});



ScaffoldMessenger.of(context)
.showSnackBar(

const SnackBar(

content:
Text(
"Verification submitted successfully"
),

),

);



Navigator.pop(context);

}

catch(e){


ScaffoldMessenger.of(context)
.showSnackBar(

SnackBar(

content:
Text(
e.toString()
),

),

);


}


setState((){

uploading=false;

});


}

Future<String> uploadToStorage(
File file,
String path
) async{

Reference ref =
FirebaseStorage.instance
.ref()
.child(
"worker_verification/$path"
);

UploadTask upload =
ref.putFile(file);

TaskSnapshot snapshot =
await upload;

return await snapshot.ref.getDownloadURL();

}

@override
Widget build(BuildContext context){
return Scaffold(
backgroundColor:
const Color(0xffF8FAFC),
appBar:AppBar(
backgroundColor:
Colors.white,

foregroundColor:
Colors.black,

title:
const Text(

"Identity Verification",

style:TextStyle(
fontWeight:
FontWeight.bold
),

),

),




body:
SingleChildScrollView(

padding:
const EdgeInsets.all(20),


child:Column(

crossAxisAlignment:
CrossAxisAlignment.start,


children:[




verificationHeader(),



const SizedBox(height:25),




const Text(

"Select Government ID",

style:TextStyle(

fontSize:20,

fontWeight:
FontWeight.bold

),

),



const SizedBox(height:15),




Container(

padding:
const EdgeInsets.symmetric(
horizontal:15
),


decoration:
BoxDecoration(

color:Colors.white,

borderRadius:
BorderRadius.circular(18)

),


child:
DropdownButtonHideUnderline(

child:
DropdownButton<String>(


value:selectedIdType,


isExpanded:true,


items:idTypes.map((e){


return DropdownMenuItem(

value:e,

child:Text(e),

);


}).toList(),



onChanged:(value){


setState((){

selectedIdType=value!;

});


},


),


),


),




const SizedBox(height:25),



uploadCard(

title:"Upload ID Front",

file:idFront,

onTap:()async{

idFront =
await pickImage();

setState((){});

},

),



const SizedBox(height:15),



uploadCard(

title:"Upload ID Back",

file:idBack,

onTap:()async{

idBack =
await pickImage();

setState((){});

},

),




const SizedBox(height:15),



uploadCard(

title:"Upload Selfie",

file:selfie,

onTap:()async{

selfie =
await pickImage();

setState((){});

},

),




const SizedBox(height:30),



SizedBox(

width:double.infinity,

height:55,


child:
ElevatedButton(


style:
ElevatedButton.styleFrom(

backgroundColor:
const Color(0xff2563EB),

),


onPressed:
uploading
?
null
:
uploadImages,


child:

uploading

?

const CircularProgressIndicator(
color:Colors.white
)

:

const Text(

"Submit Verification",

style:
TextStyle(

color:Colors.white,

fontSize:17

),

),



),

)




],


),


),


);


}







Widget verificationHeader(){


return Container(

padding:
const EdgeInsets.all(20),


decoration:
BoxDecoration(

gradient:
const LinearGradient(

colors:[

Color(0xff2563EB),

Color(0xff38BDF8)

]

),


borderRadius:
BorderRadius.circular(25)

),



child:
const Column(

crossAxisAlignment:
CrossAxisAlignment.start,


children:[


Text(

"🔵 Level 1",

style:
TextStyle(

color:Colors.white,

fontSize:24,

fontWeight:
FontWeight.bold

),

),


SizedBox(height:8),


Text(

"Identity Verification",

style:
TextStyle(

color:Colors.white,

fontSize:18

),

),



SizedBox(height:8),


Text(

"Verify your identity to gain customer trust",

style:
TextStyle(

color:Colors.white70

),

)



],

),

);

}







Widget uploadCard({

required String title,

required File? file,

required VoidCallback onTap,

}){


return GestureDetector(

onTap:onTap,


child:Container(

padding:
const EdgeInsets.all(18),


decoration:
BoxDecoration(

color:Colors.white,

borderRadius:
BorderRadius.circular(20)

),



child:Row(

children:[


const Icon(

Icons.upload_file,

color:
Color(0xff2563EB),

),


const SizedBox(width:15),


Expanded(

child:Text(title),

),



Icon(

file==null

?

Icons.add_photo_alternate

:

Icons.check_circle,

color:
file==null

?
Colors.grey

:
Colors.green,

)


],

),


),


);

}



}
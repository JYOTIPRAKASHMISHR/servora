import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:animate_do/animate_do.dart';

import '../widgets/servora_logo.dart';
import 'login_screen.dart';
import 'role_screen.dart';


class SplashScreen extends StatefulWidget{

const SplashScreen({super.key});

@override
State<SplashScreen> createState()=>_SplashScreenState();

}


class _SplashScreenState extends State<SplashScreen>{


@override
void initState(){

super.initState();

checkUser();

}



void checkUser()async{

await Future.delayed(
const Duration(seconds:3)
);


User? user =
FirebaseAuth.instance.currentUser;


if(user!=null){

Navigator.pushReplacement(
context,
MaterialPageRoute(
builder:(context)=>const RoleScreen()
)
);

}

else{

Navigator.pushReplacement(
context,
MaterialPageRoute(
builder:(context)=>const LoginScreen()
)
);

}


}



@override
Widget build(BuildContext context){


return Scaffold(

body:Container(

decoration:const BoxDecoration(

gradient:LinearGradient(

colors:[

Color(0xff020617),
Color(0xff003B9B)

],

begin:Alignment.topCenter,
end:Alignment.bottomCenter

)

),

child:Center(

child:Column(

mainAxisAlignment:
MainAxisAlignment.center,


children:[


ZoomIn(

duration:
const Duration(seconds:2),

child:const ServoraLogo(
size:130
),

),


const SizedBox(height:30),


FadeInUp(

duration:
const Duration(seconds:2),

child:const Text(

"SERVORA",

style:TextStyle(

fontSize:42,
fontWeight:FontWeight.bold,
letterSpacing:4,
color:Colors.white

),

),

),


const SizedBox(height:10),


const Text(

"Service & Repair Simplified",

style:TextStyle(

fontSize:16,
color:Colors.white70

),

),


const SizedBox(height:60),


const CircularProgressIndicator(

color:Colors.white

)


]

)

)

)

);

}


}
import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';

import '../widgets/servora_logo.dart';

// import 'profile_screen.dart';
// import 'history_screen.dart';


class HomeScreen extends StatefulWidget {

  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() =>
      _HomeScreenState();

}



class _HomeScreenState extends State<HomeScreen> {


int currentIndex = 0;


final List<String> services = [

  "AC Repair",
  "Electrician",
  "Plumbing",
  "Car Repair",

];



void changeBottomMenu(int index){

  setState((){

    currentIndex = index;

  });

}



@override
Widget build(BuildContext context){


return Scaffold(

backgroundColor:
const Color(0xffF8FAFC),



body:

SafeArea(

child:

SingleChildScrollView(

padding:

const EdgeInsets.all(20),



child:

Column(

crossAxisAlignment:
CrossAxisAlignment.start,


children:[



buildHeader(),


const SizedBox(height:25),



buildWelcome(),


const SizedBox(height:25),



buildUserCards(),


const SizedBox(height:30),



buildServiceTitle(),


const SizedBox(height:15),



buildServices(),


const SizedBox(height:30),



buildEmergencyCard(),



],


),


),


),




bottomNavigationBar:

buildBottomNavigation(),


);


}







Widget buildHeader(){


return Row(

mainAxisAlignment:
MainAxisAlignment.spaceBetween,


children:[


const ServoraLogo(

size:70,

),



Container(

padding:
const EdgeInsets.all(12),


decoration:

BoxDecoration(

color:
const Color(0xffE0F2FE),

borderRadius:
BorderRadius.circular(15),

),



child:

const Icon(

Icons.notifications_none,

color:
Color(0xff2563EB),

),


),



],


);


}







Widget buildWelcome(){


return FadeInDown(

child:

Column(

crossAxisAlignment:
CrossAxisAlignment.start,


children:[


const Text(

"Welcome to Servora 👋",

style:

TextStyle(

fontSize:28,

fontWeight:
FontWeight.bold,

color:
Color(0xff0F172A),

),

),



const SizedBox(height:8),



const Text(

"Service & Repair made simple",

style:

TextStyle(

fontSize:16,

color:
Colors.grey,

),

),


],


),


);


}







Widget buildUserCards(){


return Row(

children:[


Expanded(

child:

buildServiceCard(

title:"Customer",

subtitle:"Book Services",

icon:
Icons.person_outline,

color:
const Color(0xff2563EB),

),


),



const SizedBox(width:15),



Expanded(

child:

buildServiceCard(

title:"Worker",

subtitle:"Provide Services",

icon:
Icons.handyman_outlined,

color:
const Color(0xff0EA5E9),

),


),



],


);


}







Widget buildServiceCard({

required String title,

required String subtitle,

required IconData icon,

required Color color,

}){


return Container(

height:140,


padding:

const EdgeInsets.all(18),



decoration:

BoxDecoration(

color:
Colors.white,


borderRadius:

BorderRadius.circular(25),



boxShadow:[

BoxShadow(

color:

Colors.black.withOpacity(.08),

blurRadius:15,

offset:
const Offset(0,5),

)

]


),



child:

Column(

crossAxisAlignment:

CrossAxisAlignment.start,


children:[



Container(

height:45,

width:45,


decoration:

BoxDecoration(

color:
color.withOpacity(.15),

borderRadius:

BorderRadius.circular(15),

),



child:

Icon(

icon,

color:
color,

),

),




const Spacer(),




Text(

title,

style:

const TextStyle(

fontSize:18,

fontWeight:
FontWeight.bold,

),

),



const SizedBox(height:4),



Text(

subtitle,

style:

const TextStyle(

color:
Colors.grey,

),

),



],


),


);


}








Widget buildServiceTitle(){


return const Text(

"Popular Services",

style:

TextStyle(

fontSize:22,

fontWeight:
FontWeight.bold,

),

);


}







Widget buildServices(){


return SizedBox(

height:100,


child:

ListView.builder(

scrollDirection:
Axis.horizontal,


itemCount:
services.length,


itemBuilder:(context,index){


return Container(

width:130,


margin:

const EdgeInsets.only(
right:12,
),



decoration:

BoxDecoration(

color:
Colors.white,

borderRadius:

BorderRadius.circular(20),


boxShadow:[

BoxShadow(

color:
Colors.black12,

blurRadius:10,

)

]


),



child:

Column(

mainAxisAlignment:

MainAxisAlignment.center,


children:[


const Icon(

Icons.build_circle_outlined,

size:35,

color:
Color(0xff2563EB),

),



const SizedBox(height:8),



Text(

services[index],

style:

const TextStyle(

fontWeight:
FontWeight.w600,

),

),



],


),



);


},


),


);


}








Widget buildEmergencyCard(){


return FadeInUp(

child:

Container(

padding:

const EdgeInsets.all(20),


width:
double.infinity,



decoration:

BoxDecoration(

gradient:

const LinearGradient(

colors:[

Color(0xff2563EB),

Color(0xff38BDF8),

],

),



borderRadius:

BorderRadius.circular(25),

),



child:

Row(

children:[


const Icon(

Icons.flash_on,

color:
Colors.white,

size:40,

),



const SizedBox(width:15),



const Column(

crossAxisAlignment:

CrossAxisAlignment.start,


children:[


Text(

"Emergency Repair",

style:

TextStyle(

fontSize:18,

fontWeight:
FontWeight.bold,

color:
Colors.white,

),

),



Text(

"Quick service at your location",

style:

TextStyle(

color:
Colors.white70,

),

),


],


),



],


),


),


);


}







Widget buildBottomNavigation(){


return BottomNavigationBar(

currentIndex:
currentIndex,


onTap:
changeBottomMenu,


selectedItemColor:

const Color(0xff2563EB),


items:[


const BottomNavigationBarItem(

icon:
Icon(Icons.home),

label:"Home",

),



const BottomNavigationBarItem(

icon:
Icon(Icons.history),

label:"History",

),



const BottomNavigationBarItem(

icon:
Icon(Icons.person),

label:"Profile",

),



],


);


}


}
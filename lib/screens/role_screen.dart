import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';

import '../widgets/servora_logo.dart';

import 'customer/customer_home.dart';
import 'workers/worker_home.dart';



class RoleScreen extends StatefulWidget{

const RoleScreen({super.key});


@override
State<RoleScreen> createState()=>_RoleScreenState();

}



class _RoleScreenState extends State<RoleScreen>{


String selectedRole="Customer";



@override
Widget build(BuildContext context){


return Scaffold(

body:Container(

height:double.infinity,

width:double.infinity,


decoration:const BoxDecoration(

gradient:LinearGradient(

colors:[

Color(0xff020617),

Color(0xff003B8F)

],

begin:Alignment.topCenter,

end:Alignment.bottomCenter

)

),



child: SafeArea(
  child: Padding(
    padding: const EdgeInsets.symmetric(horizontal: 25),
    child: SingleChildScrollView(
      child: Column(
        children: [

          const SizedBox(height:25),

          ZoomIn(
            duration: const Duration(seconds:1),
            child: const ServoraLogo(
              size:90,
            ),
          ),

          const SizedBox(height:25),

          FadeInDown(
            child: const Text(
              "Select Your Role",
              style: TextStyle(
                color: Colors.white,
                fontSize:32,
                fontWeight:FontWeight.bold,
              ),
            ),
          ),

          const SizedBox(height:8),

          const Text(
            "Choose how you want to continue with Servora",
            textAlign:TextAlign.center,
            style:TextStyle(
              color:Colors.white70,
              fontSize:15,
            ),
          ),

          const SizedBox(height:40),

          buildRoleCard(
            title:"Customer",
            subtitle:"Book services for your home",
            icon:Icons.person_outline,
          ),

          const SizedBox(height:20),

          buildRoleCard(
            title:"Worker",
            subtitle:"Provide services and earn money",
            icon:Icons.engineering_outlined,
          ),

          // DON'T USE Spacer() HERE
          const SizedBox(height:40),

          buildContinueButton(),

          const SizedBox(height:25),
        ],
      ),
    ),
  ),
),
),);



}




Widget buildRoleCard({

  required String title,

  required String subtitle,

  required IconData icon,

}) {


  bool selected = selectedRole == title;



  return GestureDetector(

    onTap: () {

      setState(() {

        selectedRole = title;

      });

    },


    child: AnimatedContainer(

      duration: const Duration(milliseconds:300),

      height:115,

      padding: const EdgeInsets.all(15),


      decoration: BoxDecoration(

        color: selected

            ? const Color(0xff2563EB).withOpacity(0.35)

            : Colors.white.withOpacity(0.10),


        borderRadius: BorderRadius.circular(25),


        border: Border.all(

          width:2,

          color: selected

              ? const Color(0xff38BDF8)

              : Colors.white24,

        ),

      ),



      child: Row(

        crossAxisAlignment: CrossAxisAlignment.center,

        children: [



          Container(

            height:60,

            width:60,


            decoration: BoxDecoration(

              color:Colors.white,

              borderRadius:
              BorderRadius.circular(18),

            ),



            child: Icon(

              icon,

              size:35,

              color:
              const Color(0xff2563EB),

            ),

          ),



          const SizedBox(width:15),



        Expanded(

child:Column(

mainAxisAlignment:
MainAxisAlignment.center,


crossAxisAlignment:
CrossAxisAlignment.start,


mainAxisSize:
MainAxisSize.min,


children:[


Text(

title,

maxLines:1,

overflow:
TextOverflow.ellipsis,


style:const TextStyle(

color:Colors.white,

fontSize:20,

fontWeight:
FontWeight.bold,

),

),



Text(

subtitle,

maxLines:1,

overflow:
TextOverflow.ellipsis,


style:const TextStyle(

color:Colors.white70,

fontSize:13,

),

),


]


),

),

          const SizedBox(width:10),



          AnimatedContainer(

            duration:
            const Duration(milliseconds:300),


            height:22,

            width:22,


            decoration: BoxDecoration(

              shape:BoxShape.circle,


              color:selected

                  ? Colors.white

                  : Colors.transparent,


              border:Border.all(

                width:2,

                color:selected

                    ? Colors.white

                    : Colors.white54,

              ),

            ),



            child:selected

                ? const Icon(

              Icons.check,

              size:14,

              color:
              Color(0xff2563EB),

            )

                : null,


          ),



        ],

      ),


    ),

  );


}



Widget buildContinueButton(){


return SizedBox(

width:double.infinity,

height:55,


child:ElevatedButton(

style:ElevatedButton.styleFrom(

backgroundColor:
const Color(0xff2563EB),


shape:

RoundedRectangleBorder(

borderRadius:
BorderRadius.circular(18)

)

),



onPressed:(){



if(selectedRole=="Customer"){


Navigator.pushReplacement(

context,

MaterialPageRoute(

builder:(context)=>

const CustomerHome()

)

);


}

else{


Navigator.pushReplacement(

context,

MaterialPageRoute(

builder:(context)=>

const WorkerHome()

)

);


}


},



child:const Text(

"Continue",

style:TextStyle(

fontSize:18,

fontWeight:FontWeight.bold,

color:Colors.white

),

),



),

);


}


}
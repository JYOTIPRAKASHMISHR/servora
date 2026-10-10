import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'package:servora/services/chat_service.dart';



class ChatScreen extends StatefulWidget {
  final String serviceId;
  final String customerId;
  final String workerId;
  final String applicationId;

  const ChatScreen({
    super.key,
    required this.serviceId,
    required this.customerId,
    required this.workerId,
    required this.applicationId,
  });

  @override
  State<ChatScreen> createState() => 
      _ChatScreenState();

}

class _ChatScreenState extends State<ChatScreen>{

  final ChatService chatService = 
      ChatService();

  final TextEditingController messageController =
      TextEditingController();

  final ScrollController scrollController =
      ScrollController();

  final User? currentUser =
      FirebaseAuth.instance.currentUser;
  bool sending = false;

  double customerBudget = 0;
  double? latestOffer;
  bool priceAccepted = false;
  double? acceptedPrice;
  bool serviceCompleted = false;
  @override
  void initState(){
    super.initState();
    loadCustomerBudget();
  }
  @override
  void dispose(){

    messageController.dispose();


    scrollController.dispose();


    super.dispose();


  }

  // LOAD CUSTOMER SERVICE BUDGET

  Future<void> loadCustomerBudget() async {


    DatabaseEvent event =

    await FirebaseDatabase.instance

    .ref("services")

    .child(widget.serviceId)

    .once();

    if(event.snapshot.exists){


      Map service =

      Map.from(

        event.snapshot.value as Map

      );

      setState((){


        customerBudget =

        double.parse(

          service["budget"].toString()

        );


      });



    }


  }
  // SEND MESSAGE


  Future<void> sendMessage() async {



    String message =

    messageController.text.trim();



    if(message.isEmpty ||
       currentUser == null){

      return;

    }
    setState((){

      sending = true;

    });


    double? price;



    RegExp regex =

    RegExp(r'\d+');



    Match? match =

    regex.firstMatch(message);






    if(match != null){



      price =

      double.parse(

        match.group(0)!

      );





      if(price < customerBudget){


        _showMessage(

          "Price cannot be less than customer budget ₹$customerBudget"

        );



        setState((){

          sending=false;

        });


        return;


      }


    }


    await chatService.sendMessage(



      serviceId:

      widget.serviceId,



      customerId:

      widget.customerId,



      workerId:

      widget.workerId,



      senderId:

      currentUser!.uid,



      message:

      message,



      type:

      price != null

      ?

      "price"

      :

      "text",



      amount:

      price,



    );






    messageController.clear();




    setState((){


      sending=false;


    });




    scrollToBottom();



  }








  void scrollToBottom(){



    Future.delayed(

      const Duration(milliseconds:300),

          (){


        if(scrollController.hasClients){



          scrollController.animateTo(

            scrollController.position.maxScrollExtent,


            duration:

            const Duration(milliseconds:300),



            curve:

            Curves.easeOut,


          );


        }



      },

    );



  }








  void _showMessage(String text){



    ScaffoldMessenger.of(context)

        .showSnackBar(


      SnackBar(

        content:

        Text(text),


        behavior:

        SnackBarBehavior.floating,


      ),


    );


  }
  @override
Widget build(BuildContext context){


return Scaffold(


backgroundColor:
const Color(0xffF8FAFC),



appBar:
_buildAppBar(),



body:
Column(

children:[



Expanded(

child:
_buildMessages(),

),






if(!priceAccepted)

_buildInputBox()

else

Container(

padding:
const EdgeInsets.all(15),

color:
Colors.green.shade50,


child:
const Center(

child:
Text(

"Negotiation completed. Chat is locked.",

style:

TextStyle(

fontWeight:
FontWeight.bold,

color:
Colors.green,

),

),

),

),



],


),



);



}








PreferredSizeWidget _buildAppBar(){


return AppBar(


backgroundColor:
Colors.white,


foregroundColor:
Colors.black,


elevation:
0,



title:

Column(

crossAxisAlignment:
CrossAxisAlignment.start,


children:[



const Text(

"Service Chat",

style:

TextStyle(

fontSize:18,

fontWeight:
FontWeight.bold,

),

),





Text(

"Discuss price and service details",

style:

TextStyle(

fontSize:12,

color:
Colors.grey,

),

),



],


),



);



}









Widget _buildMessages(){



return StreamBuilder<DatabaseEvent>(


stream:

chatService.getMessages(

serviceId:
widget.serviceId,


customerId:
widget.customerId,


workerId:
widget.workerId,


),



builder:(context,snapshot){



if(!snapshot.hasData){


return const Center(

child:
CircularProgressIndicator(),

);


}





DatabaseEvent event =
snapshot.data!;





if(event.snapshot.value==null){


return _emptyChat();


}







Map data =

Map.from(

event.snapshot.value as Map

);





List<Map> messages=[];





data.forEach((key,value){



messages.add(

Map<String,dynamic>.from(value)

);


});







messages.sort((a,b){


return a["time"]

.toString()

.compareTo(

b["time"].toString()

);


});









// FIND LATEST PRICE OFFER


latestOffer=null;



for(var msg in messages){


if(

msg["type"]=="price"

&&

msg["amount"]!=null

){


latestOffer=

double.parse(

msg["amount"].toString()

);



}


}







return FutureBuilder<DataSnapshot>(


future:

FirebaseDatabase.instance

.ref("services")

.child(widget.serviceId)

.get(),



builder:(context,serviceSnapshot){



if(serviceSnapshot.hasData &&

serviceSnapshot.data!.value!=null){



Map service =

Map.from(

serviceSnapshot.data!.value as Map

);





if(service["status"]=="assigned"){


priceAccepted=true;


}





if(service["finalPrice"]!=null){


acceptedPrice=

double.parse(

service["finalPrice"].toString()

);


}



}







return Column(



children:[






if(priceAccepted)


Container(


margin:
const EdgeInsets.all(12),


padding:
const EdgeInsets.all(15),




decoration:

BoxDecoration(

color:
Colors.green.shade100,


borderRadius:

BorderRadius.circular(15),

),





child:

Row(

children:[



const Icon(

Icons.check_circle,

color:
Colors.green,

),




const SizedBox(width:10),





Expanded(

child:

Text(

"Final Price Accepted ₹${acceptedPrice?.toStringAsFixed(0) ?? ""}",



style:

const TextStyle(

fontWeight:
FontWeight.bold,


color:
Colors.green,

),



),

),



],


),



),







Expanded(



child:

ListView.builder(



controller:

scrollController,



padding:

const EdgeInsets.all(15),




itemCount:

messages.length,





itemBuilder:(context,index){



Map msg =
messages[index];





bool isMe =

msg["senderId"]

==

currentUser!.uid;





return _messageBubble(

msg,

isMe,

);



},



),



),



],



);



},



);



},



);



}
Widget _messageBubble(
Map data,
bool isMe,
){


return Align(

alignment:

isMe

? Alignment.centerRight

: Alignment.centerLeft,



child:

Container(


margin:

const EdgeInsets.only(

bottom:12,

),




padding:

const EdgeInsets.all(14),





constraints:

const BoxConstraints(

maxWidth:300,

),





decoration:

BoxDecoration(


color:

isMe

? const Color(0xff2563EB)

: Colors.white,




borderRadius:

BorderRadius.only(


topLeft:

const Radius.circular(20),


topRight:

const Radius.circular(20),



bottomLeft:

isMe

? const Radius.circular(20)

: const Radius.circular(5),




bottomRight:

isMe

? const Radius.circular(5)

: const Radius.circular(20),



),





boxShadow:[


const BoxShadow(

color:Colors.black12,

blurRadius:6,

offset:Offset(0,3),

),


],


),






child:

Column(



crossAxisAlignment:

isMe

? CrossAxisAlignment.end

: CrossAxisAlignment.start,



children:[





Text(


data["message"] ?? "",



style:

TextStyle(


color:

isMe

? Colors.white

: Colors.black,


fontSize:15,


),

),






if(data["type"]=="price")

_priceOfferCard(

data,

isMe,

),






const SizedBox(height:8),






Text(


_formatTime(

data["time"]

),



style:

TextStyle(


fontSize:11,


color:

isMe

? Colors.white70

: Colors.grey,


),


),




],


),



),

)

.animate()

.fade(

duration:

400.ms,

)

.slideX(

begin:

isMe ? 0.2 : -0.2,

);



}











// PRICE OFFER CARD


Widget _priceOfferCard(

Map data,

bool isMe,

){



double amount =

double.parse(

data["amount"].toString()

);





return Container(


margin:

const EdgeInsets.only(

top:10,

),





padding:

const EdgeInsets.all(12),





decoration:

BoxDecoration(



color:

isMe

? Colors.white24

: Colors.green.shade50,




borderRadius:

BorderRadius.circular(15),



),






child:

Column(



crossAxisAlignment:

CrossAxisAlignment.start,



children:[





Text(

"💰 Price Offer",

style:

TextStyle(

color:

isMe

? Colors.white

: Colors.green,


fontWeight:

FontWeight.bold,


),


),






const SizedBox(height:5),






Text(

"₹${amount.toStringAsFixed(0)}",


style:

TextStyle(


fontSize:18,


fontWeight:

FontWeight.bold,



color:

isMe

? Colors.white

: Colors.black,


),


),








// SHOW ACCEPTED PRICE


if(priceAccepted &&

acceptedPrice==amount)


const Padding(

padding:

EdgeInsets.only(top:8),


child:

Text(

"✅ Accepted Final Price",

style:

TextStyle(

color:Colors.green,

fontWeight:

FontWeight.bold,

),

),

),







// CUSTOMER ACCEPT BUTTON


if(!isMe && !priceAccepted)

const SizedBox(height:10),







if(!isMe && !priceAccepted)


Row(

children:[





Expanded(

child:

ElevatedButton(


style:

ElevatedButton.styleFrom(

backgroundColor:

Colors.green,

),



onPressed:

(){

acceptPrice(amount);

},



child:

const Text(

"Accept",

style:

TextStyle(

color:

Colors.white,

),

),


),

),





const SizedBox(width:8),






Expanded(

child:

OutlinedButton(


onPressed:

(){

rejectPrice();

},



child:

const Text(

"Reject",

),



),


),



],

),

],



),



);



}











// ACCEPT FINAL PRICE


Future<void> acceptPrice(double amount) async {

try{
// UPDATE APPLICATION


await FirebaseDatabase.instance

.ref("applications")

.child(widget.applicationId)

.update({
"status":"accepted",


"currentOffer":

amount,


"finalPrice":

amount,



"status":

"accepted",



"priceAccepted":

true,



"acceptedAt":

DateTime.now().toString(),



});








// UPDATE SERVICE


await FirebaseDatabase.instance

.ref("services")

.child(widget.serviceId)

.update({



"status":

"assigned",




"assignedWorkerId":

widget.workerId,





"acceptedApplicationId":

widget.applicationId,





"finalPrice":

amount,





"acceptedAt":

DateTime.now().toString(),



});








setState((){


priceAccepted=true;


acceptedPrice=amount;


});






_showMessage(

"Price accepted successfully"

);





}

catch(e){


_showMessage(

e.toString()

);


}



}











// REJECT PRICE


Future<void> rejectPrice() async {



try{





await chatService.rejectPrice(



serviceId:

widget.serviceId,



customerId:

widget.customerId,



workerId:

widget.workerId,



);





_showMessage(

"Offer rejected"

);




}

catch(e){



_showMessage(

e.toString()

);



}



}
// EMPTY CHAT

Widget _emptyChat() {

  return Center(

    child: Column(

      mainAxisAlignment:
      MainAxisAlignment.center,


      children: [


        Container(

          padding:
          const EdgeInsets.all(25),


          decoration:
          const BoxDecoration(

            color:
            Color(0xffDBEAFE),

            shape:
            BoxShape.circle,

          ),


          child:
          const Icon(

            Icons.chat_bubble_outline,

            size:60,

            color:
            Color(0xff2563EB),

          ),

        ),



        const SizedBox(height:20),



        const Text(

          "Start Conversation",

          style:
          TextStyle(

            fontSize:20,

            fontWeight:
            FontWeight.bold,

          ),

        ),




        const SizedBox(height:8),




        const Text(

          "Discuss service details and price",

          style:
          TextStyle(

            color:
            Colors.grey,

          ),

        ),


      ],

    ),

  );

}






// TIME FORMAT


String _formatTime(String time){


  try{


    DateTime date =
    DateTime.parse(time);



    return

      "${date.hour}:${date.minute.toString().padLeft(2,'0')}";


  }

  catch(e){


    return "";

  }


}







// INPUT BOX


Widget _buildInputBox(){


  return Container(


    padding:
    const EdgeInsets.all(12),



    decoration:
    const BoxDecoration(


      color:
      Colors.white,


      boxShadow:[


        BoxShadow(

          color:
          Colors.black12,

          blurRadius:
          8,

        )


      ]


    ),




    child:
    Row(

      children:[



        Expanded(


          child:
          TextField(


            controller:
            messageController,



            decoration:
            InputDecoration(


              hintText:
              "Type message...",



              filled:true,



              fillColor:
              const Color(0xffF1F5F9),



              border:
              OutlineInputBorder(


                borderRadius:
                BorderRadius.circular(30),



                borderSide:
                BorderSide.none,


              ),


            ),



          ),


        ),





        const SizedBox(width:10),





        GestureDetector(



          onTap:

          sending

          ?

          null

          :

          sendMessage,





          child:
          CircleAvatar(


            radius:
            25,



            backgroundColor:
            const Color(0xff2563EB),





            child:

            sending


            ?


            const CircularProgressIndicator(

              color:
              Colors.white,

              strokeWidth:
              2,

            )



            :


            const Icon(

              Icons.send,

              color:
              Colors.white,

            ),



          ),



        ),



      ],


    ),


  );


}



}
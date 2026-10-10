import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:http/http.dart' as http;

import 'package:servora/screens/customer/location_picker_screen.dart';



class UrgentHelpScreen extends StatefulWidget {

  const UrgentHelpScreen({
    super.key,
  });


  @override
  State<UrgentHelpScreen> createState() =>
      _UrgentHelpScreenState();

}




class _UrgentHelpScreenState 
    extends State<UrgentHelpScreen> {



  // ===============================
  // CONTROLLERS
  // ===============================


  final TextEditingController descriptionController =
  TextEditingController();


  final TextEditingController locationController =
  TextEditingController();




  // ===============================
  // LOCATION DATA
  // ===============================


  double? latitude;

  double? longitude;





  // ===============================
  // SERVICE DATA
  // ===============================


  String? selectedCategory;


  String urgency = "urgent";



  bool loading=false;




  // ===============================
  // COLORS
  // ===============================


  static const Color primary =
  Color(0xff2563EB);


  static const Color danger =
  Color(0xffEF4444);



  static const Color background =
  Color(0xffF8FAFC);






  // ===============================
  // CATEGORY LIST
  // ===============================


  final List<Map<String,dynamic>> categories=[



    {
      "name":"Electrical",
      "icon":Icons.electrical_services,
    },


    {
      "name":"Water / Plumbing",
      "icon":Icons.water_damage,
    },


    {
      "name":"AC / Appliance",
      "icon":Icons.ac_unit,
    },


    {
      "name":"Lock / Door",
      "icon":Icons.lock,
    },


    {
      "name":"Vehicle",
      "icon":Icons.car_repair,
    },


    {
      "name":"Home Repair",
      "icon":Icons.home_repair_service,
    },


    {
      "name":"Other",
      "icon":Icons.handyman,
    },


  ];








  // ===============================
  // DISPOSE
  // ===============================


  @override
  void dispose(){


    descriptionController.dispose();


    locationController.dispose();


    super.dispose();


  }




Future<void> sendUrgentNotificationToNearbyWorkers({
  required String serviceId,
  required String customerId,
  required String serviceName,
  required String location,
  required double latitude,
  required double longitude,
}) async {
  try {
    final response = await http.post(
      Uri.parse(
        "http://127.0.0.1:8080/api/notifications/urgent-service",
      ),
      headers: {
        "Content-Type": "application/json",
      },
      body: jsonEncode({
        "serviceId": serviceId,
        "customerId": customerId,
        "serviceName": serviceName,
        "location": location,
        "latitude": latitude,
        "longitude": longitude,
        "radiusKm": 10,
        "title": "🚨 Urgent Service Available",
        "message":
            "$serviceName service request is available near you.",
      }),
    );

    debugPrint("URGENT NOTIFICATION RESPONSE");
    debugPrint("Status: ${response.statusCode}");
    debugPrint("Body: ${response.body}");
  } catch (e) {
    debugPrint(
      "URGENT NOTIFICATION ERROR: $e",
    );
  }
}

// Future<void> sendUrgentNotifications({
//   required String serviceId,
//   required String customerId,
//   required String serviceName,
//   required String location,
// }) async {

//   try {

//     // ==========================================
//     // GET ALL WORKERS
//     // ==========================================

//     DatabaseEvent workerEvent =
//         await FirebaseDatabase.instance
//             .ref("workers")
//             .once();

//     if (!workerEvent.snapshot.exists) {
//       debugPrint("No workers found");
//       return;
//     }

//     final rawWorkers =
//         workerEvent.snapshot.value;

//     if (rawWorkers is! Map) {
//       return;
//     }

//     final workers =
//         Map<dynamic, dynamic>.from(rawWorkers);

//     // ==========================================
//     // SEND NOTIFICATION TO EVERY WORKER
//     // ==========================================

//     for (final entry in workers.entries) {

//       final String workerId =
//           entry.key.toString();

//       // ========================================
//       // DON'T SEND TO CUSTOMER
//       // ========================================

//       if (workerId == customerId) {
//         continue;
//       }

//       // ========================================
//       // CREATE NOTIFICATION
//       // ========================================

//       final DatabaseReference notificationRef =
//           FirebaseDatabase.instance
//               .ref("workers")
//               .child(workerId)
//               .child("notifications")
//               .push();

//       await notificationRef.set({

//         "notificationId":
//             notificationRef.key,

//         "type":
//             "urgent_service",

//         "title":
//             "🚨 Urgent Service Available",

//         "message":
//             "$serviceName service request near $location",

//         "serviceId":
//             serviceId,

//         "customerId":
//             customerId,

//         "serviceName":
//             serviceName,

//         "location":
//             location,

//         "read":
//             false,

//         "createdAt":
//             ServerValue.timestamp,

//       });

//       debugPrint(
//         "Urgent notification sent to worker: $workerId",
//       );
//     }

//   }
//   catch (e) {

//     debugPrint(
//       "URGENT NOTIFICATION ERROR: $e",
//     );

//   }
// }

  // ===============================
  // CREATE EMERGENCY REQUEST
  // ===============================


Future<void> createRequest() async {

  if (selectedCategory == null) {

    showMessage(
      "Select problem category",
    );

    return;
  }

  if (descriptionController.text.trim().isEmpty) {

    showMessage(
      "Describe your problem",
    );

    return;
  }

  if (locationController.text.trim().isEmpty) {

    showMessage(
      "Please select service location",
    );

    return;
  }

  User? user =
      FirebaseAuth.instance.currentUser;

  if (user == null) {

    showMessage(
      "Please login again",
    );

    return;
  }

  try {

    setState(() {
      loading = true;
    });

    // ==========================================
    // CREATE SERVICE
    // ==========================================

    DatabaseReference ref =
        FirebaseDatabase.instance
            .ref("services")
            .push();

    final String serviceId =
        ref.key!;

    // ==========================================
    // SAVE SERVICE
    // ==========================================

  await ref.set({
  "customerId": user.uid,
  "serviceName": selectedCategory,
  "description": descriptionController.text.trim(),
  "location": locationController.text.trim(),
  "latitude": latitude,
  "longitude": longitude,
  "urgency": urgency,
  "urgentServiceFee": 199,
  "emergencyCharge": 199,
  "workerServiceCharge": null,
  "finalPrice": null,
  "priority": urgency == "emergency"
      ? "high"
      : "normal",
  "status": "pending",
  "assignedWorkerId": "",
  "images": [],
  "createdAt": ServerValue.timestamp,
});

if (latitude == null || longitude == null) {
  showMessage("Please select your location again.");
  return;
}

await sendUrgentNotificationToNearbyWorkers(
  serviceId: serviceId,
  customerId: user.uid,
  serviceName: selectedCategory!,
  location: locationController.text.trim(),
  latitude: latitude!,
  longitude: longitude!,
);
    // ==========================================
    // FINISH
    // ==========================================

    if (!mounted) {
      return;
    }

    setState(() {
      loading = false;
    });

    showMessage(
      "Urgent request sent to workers!",
    );

    Navigator.pop(context);

  }
  catch (e) {

    debugPrint(
      "CREATE URGENT REQUEST ERROR: $e",
    );

    if (!mounted) {
      return;
    }

    setState(() {
      loading = false;
    });

    showMessage(
      "Something went wrong. Please try again.",
    );
  }
}
  // ===============================
  // LOCATION PICKER
  // ===============================



  Future<void> selectLocation() async{


    final result =
    await Navigator.push(


      context,


      MaterialPageRoute(

        builder:(context)=>

        const LocationPickerScreen(),

      ),


    );





    if(result!=null){


      setState((){


        locationController.text =
        result["address"];


        latitude =
        result["latitude"];


        longitude =
        result["longitude"];



      });


    }



  }







  void showMessage(String message){


    ScaffoldMessenger.of(context)
        .showSnackBar(


      SnackBar(

        content:
        Text(message),

        behavior:
        SnackBarBehavior.floating,


      ),


    );


  }








  @override
  Widget build(BuildContext context){


    return Scaffold(



      backgroundColor:
      background,



      appBar: AppBar(


        backgroundColor:
        Colors.white,


        elevation:
        0,


        foregroundColor:
        Colors.black,


        title:


        const Text(

          "Urgent Help",

          style:

          TextStyle(

            fontWeight:
            FontWeight.bold,

          ),

        ),



      ),




      body:


      SingleChildScrollView(


        physics:
        const BouncingScrollPhysics(),



        padding:
        const EdgeInsets.all(20),



        child:


        Column(


          crossAxisAlignment:
          CrossAxisAlignment.start,


          children:[



            _buildHeroCard(),



            const SizedBox(
                height:25
            ),



            const Text(

              "Select Problem",

              style:

              TextStyle(

                fontSize:20,

                fontWeight:
                FontWeight.bold,

              ),

            ),



            const SizedBox(
                height:15
            ),



            _categoryGrid(),



            const SizedBox(
                height:25
            ),


            const Text(

              "Explain Your Problem",

              style:

              TextStyle(

                fontSize:18,

                fontWeight:
                FontWeight.bold,

              ),

            ),



            const SizedBox(height:12),




            TextField(


              controller:
              descriptionController,


              maxLines:
              4,



              decoration:
              _inputDecoration(

                "Example: Pipe leakage in kitchen",

              ),



            ),






            const SizedBox(height:25),



            const Text(

              "Urgency Level",

              style:

              TextStyle(

                fontSize:18,

                fontWeight:
                FontWeight.bold,

              ),

            ),




            const SizedBox(height:12),




            _urgencySelector(),





            const SizedBox(height:25),


Container(
  width: double.infinity,
  padding: const EdgeInsets.all(16),

  decoration: BoxDecoration(
    color: const Color(0xffFFF7ED),
    borderRadius: BorderRadius.circular(16),
    border: Border.all(
      color: const Color(0xffFED7AA),
    ),
  ),

  child: Row(
    children: [

      Container(
        height: 45,
        width: 45,

        decoration: BoxDecoration(
          color: const Color(0xffFFEDD5),
          borderRadius: BorderRadius.circular(12),
        ),

        child: const Icon(
          Icons.local_fire_department,
          color: Colors.orange,
        ),
      ),

      const SizedBox(width: 12),

      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,

          children: [

            const Text(
              "Urgent Service Fee",
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 4),

            const Text(
              "A fixed urgent service fee of ₹199 applies.",
              style: TextStyle(
                color: Colors.grey,
                fontSize: 13,
              ),
            ),

          ],
        ),
      ),

      const Text(
        "₹199",
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Colors.orange,
        ),
      ),

    ],
  ),
),


            const Text(

              "Service Location",

              style:

              TextStyle(

                fontSize:18,

                fontWeight:
                FontWeight.bold,

              ),

            ),




            const SizedBox(height:12),






            GestureDetector(


              onTap:
              selectLocation,



              child:

              Container(


                padding:
                const EdgeInsets.all(18),



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


                      blurRadius:
                      8,


                    )

                  ],


                ),





                child:

                Row(



                  children:[



                    Container(


                      height:
                      45,


                      width:
                      45,



                      decoration:

                      BoxDecoration(


                        color:
                        Colors.red.shade50,


                        borderRadius:
                        BorderRadius.circular(15),


                      ),



                      child:

                      const Icon(

                        Icons.location_on,

                        color:
                        danger,

                      ),



                    ),




                    const SizedBox(
                        width:15
                    ),





                    Expanded(


                      child:


                      Text(


                        locationController.text.isEmpty

                            ?

                        "Tap to select location"

                            :

                        locationController.text,



                        maxLines:
                        2,


                        overflow:
                        TextOverflow.ellipsis,



                        style:

                        TextStyle(

                          color:

                          locationController.text.isEmpty

                              ?

                          Colors.grey

                              :

                          Colors.black,

                        ),



                      ),



                    ),




                    const Icon(

                      Icons.arrow_forward_ios,

                      size:
                      16,

                    )



                  ],



                ),



              ),



            ),






            const SizedBox(height:35),






            SizedBox(


              width:
              double.infinity,



              height:
              55,



              child:


              ElevatedButton(


                style:

                ElevatedButton.styleFrom(



                  backgroundColor:
                  danger,



                  elevation:
                  5,



                  shape:

                  RoundedRectangleBorder(

                    borderRadius:
                    BorderRadius.circular(18),

                  ),



                ),




                onPressed:

                loading

                    ?

                null

                    :

                createRequest,





                child:


                loading


                    ?


                const CircularProgressIndicator(

                  color:
                  Colors.white,

                )


                    :



                const Text(


                  "Find Nearby Worker",


                  style:

                  TextStyle(

                    color:
                    Colors.white,


                    fontSize:
                    17,


                    fontWeight:
                    FontWeight.bold,

                  ),


                ),



              ),



            ),



          ],



        ),



      ),



    );


  }










  // ======================================
  // HERO CARD
  // ======================================


  Widget _buildHeroCard(){



    return Container(


      padding:
      const EdgeInsets.all(22),



      decoration:

      BoxDecoration(



        gradient:

        const LinearGradient(

          colors:[

            Color(0xffEF4444),

            Color(0xffF97316),

          ],


        ),



        borderRadius:
        BorderRadius.circular(28),



      ),




      child:

      Row(



        children:[



          Container(


            height:
            60,


            width:
            60,



            decoration:

            BoxDecoration(


              color:
              Colors.white24,


              borderRadius:
              BorderRadius.circular(20),


            ),



            child:

            const Icon(

              Icons.flash_on,

              color:
              Colors.white,


              size:
              35,

            ),



          ),




          const SizedBox(width:15),





          const Expanded(


            child:

            Column(


              crossAxisAlignment:
              CrossAxisAlignment.start,


              children:[


                Text(

                  "Need Immediate Help?",


                  style:

                  TextStyle(

                    color:
                    Colors.white,

                    fontSize:
                    20,

                    fontWeight:
                    FontWeight.bold,

                  ),

                ),




                SizedBox(height:6),




                Text(

                  "We will connect you with nearby workers",

                  style:

                  TextStyle(

                    color:
                    Colors.white70,

                  ),

                ),


              ],


            ),


          )



        ],



      ),



    );


  }










  // ======================================
  // CATEGORY GRID
  // ======================================


  Widget _categoryGrid(){


    return GridView.builder(



      shrinkWrap:
      true,



      physics:

      const NeverScrollableScrollPhysics(),





      itemCount:
      categories.length,




      gridDelegate:

      const SliverGridDelegateWithFixedCrossAxisCount(


        crossAxisCount:
        3,


        crossAxisSpacing:
        12,


        mainAxisSpacing:
        12,


        childAspectRatio:
        .85,


      ),




      itemBuilder:(context,index){



        var item =
        categories[index];



        bool selected =
            selectedCategory ==
                item["name"];





        return GestureDetector(



          onTap:(){


            setState((){


              selectedCategory =
              item["name"];


            });


          },



          child:

          AnimatedContainer(


            duration:

            const Duration(
                milliseconds:250
            ),



            decoration:

            BoxDecoration(


              color:

              selected

                  ?

              Colors.red.shade50

                  :

              Colors.white,




              borderRadius:
              BorderRadius.circular(20),




              border:

              Border.all(


                color:

                selected

                    ?

                danger

                    :

                Colors.transparent,

              ),



            ),




            child:

            Column(



              mainAxisAlignment:
              MainAxisAlignment.center,



              children:[



                Icon(

                  item["icon"],


                  color:
                  danger,


                  size:
                  32,


                ),





                const SizedBox(height:8),





                Text(


                  item["name"],


                  textAlign:
                  TextAlign.center,



                  style:

                  const TextStyle(

                    fontSize:
                    11,

                    fontWeight:
                    FontWeight.bold,

                  ),



                )



              ],



            ),



          ),



        );



      },



    );



  }









  // ======================================
  // URGENCY SELECTOR
  // ======================================


  Widget _urgencySelector(){



    return Row(


      children:[



        Expanded(

          child:

          _urgencyCard(

              "urgent",

              "🟠 Urgent"

          ),


        ),




        const SizedBox(width:15),





        Expanded(

          child:

          _urgencyCard(

              "emergency",

              "🔴 Emergency"

          ),


        ),



      ],



    );


  }









  Widget _urgencyCard(
      String value,
      String title
      ){


    bool active =
        urgency==value;




    return GestureDetector(


      onTap:(){


        setState((){


          urgency=value;


        });


      },




      child:

      AnimatedContainer(



        duration:

        const Duration(
            milliseconds:200
        ),



        padding:
        const EdgeInsets.all(15),




        decoration:

        BoxDecoration(



          color:

          active

              ?

          Colors.red.shade50

              :

          Colors.white,




          borderRadius:
          BorderRadius.circular(18),




          border:

          Border.all(


            color:

            active

                ?

            danger

                :

            Colors.grey.shade300,


          ),



        ),




        child:


        Center(


          child:

          Text(

            title,

            style:

            const TextStyle(

              fontWeight:
              FontWeight.bold,

            ),


          ),


        ),



      ),



    );


  }









  InputDecoration _inputDecoration(String hint){



    return InputDecoration(


      hintText:
      hint,



      filled:
      true,



      fillColor:
      Colors.white,



      border:

      OutlineInputBorder(



        borderRadius:
        BorderRadius.circular(20),



        borderSide:
        BorderSide.none,



      ),



    );


  }



}
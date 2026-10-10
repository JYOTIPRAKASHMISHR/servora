import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';


class LocationPickerScreen extends StatefulWidget {

  const LocationPickerScreen({
    super.key,
  });


  @override
  State<LocationPickerScreen> createState() =>
      _LocationPickerScreenState();

}



class _LocationPickerScreenState 
extends State<LocationPickerScreen>{


  GoogleMapController? mapController;


  LatLng? selectedLocation;


  String address = "";


  bool isLoading = true;



  @override
  void initState(){

    super.initState();

    getCurrentLocation();

  }




  // GET CURRENT GPS LOCATION

  Future<void> getCurrentLocation() async{


    bool serviceEnabled =
    await Geolocator.isLocationServiceEnabled();


    if(!serviceEnabled){

      return;

    }



    LocationPermission permission =
    await Geolocator.checkPermission();



    if(permission ==
        LocationPermission.denied){


      permission =
      await Geolocator.requestPermission();

    }



    Position position =
    await Geolocator.getCurrentPosition(
      desiredAccuracy:
      LocationAccuracy.high,
    );



    setState((){


      selectedLocation =
          LatLng(
              position.latitude,
              position.longitude
          );


      isLoading=false;


    });



    getAddress(selectedLocation!);


  }





  // GET ADDRESS FROM LAT LNG

  Future<void> getAddress(
      LatLng position
      ) async{


    List<Placemark> places =
    await placemarkFromCoordinates(
        position.latitude,
        position.longitude
    );


    Placemark place =
    places.first;



    setState((){


      address =
      "${place.street}, ${place.locality}, ${place.administrativeArea}";


    });


  }






  // WHEN USER MOVES MAP

  void onCameraMove(
      CameraPosition position
      ){


    selectedLocation =
        position.target;


  }





  // WHEN USER STOPS MOVING MAP

  void onCameraIdle(){


    if(selectedLocation!=null){

      getAddress(selectedLocation!);

    }

  }





  @override
  Widget build(BuildContext context){


    return Scaffold(


      appBar: AppBar(

        title:
        const Text(
            "Select Location"
        ),

      ),



      body:

      isLoading

          ?

      const Center(
        child:CircularProgressIndicator(),
      )


          :

      Stack(


        children:[



          GoogleMap(


            initialCameraPosition:

            CameraPosition(

              target:
              selectedLocation!,

              zoom:16,

            ),




            myLocationEnabled:true,


            myLocationButtonEnabled:true,



            onMapCreated:(controller){

              mapController =
                  controller;

            },



            onCameraMove:
            onCameraMove,



            onCameraIdle:
            onCameraIdle,



          ),




          // CENTER PIN

          const Center(

            child:

            Icon(

              Icons.location_pin,

              color:
              Colors.red,

              size:
              50,

            ),

          ),






          // ADDRESS CARD

          Positioned(

            top:20,

            left:20,

            right:20,


            child:

            Container(

              padding:
              const EdgeInsets.all(15),


              decoration:
              BoxDecoration(

                color:
                Colors.white,

                borderRadius:
                BorderRadius.circular(15),

                boxShadow:[

                  BoxShadow(

                    color:
                    Colors.black12,

                    blurRadius:10,

                  )

                ]

              ),



              child:

              Text(

                address.isEmpty

                    ?

                "Move map to select location"

                    :

                address,


                style:
                const TextStyle(

                  fontSize:14,

                  fontWeight:
                  FontWeight.w500,

                ),

              ),


            ),


          ),





          // CONFIRM BUTTON


          Positioned(

            bottom:30,

            left:20,

            right:20,


            child:

            SizedBox(

              height:55,


              child:

              ElevatedButton(


                style:
                ElevatedButton.styleFrom(

                  backgroundColor:
                  const Color(0xff2563EB),


                  shape:
                  RoundedRectangleBorder(

                    borderRadius:
                    BorderRadius.circular(18),

                  ),

                ),



                onPressed:(){


                  Navigator.pop(

                      context,


                      {

                        "latitude":
                        selectedLocation!.latitude,


                        "longitude":
                        selectedLocation!.longitude,


                        "address":
                        address,


                      }

                  );


                },


                child:

                const Text(

                  "Confirm Location",

                  style:
                  TextStyle(

                    color:
                    Colors.white,

                    fontSize:17,

                    fontWeight:
                    FontWeight.bold,

                  ),

                ),


              ),

            ),


          )




        ],


      ),


    );


  }


}
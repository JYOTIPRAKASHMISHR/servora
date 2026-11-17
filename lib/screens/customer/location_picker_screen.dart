import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';
import 'package:flutter/services.dart';


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

 
Future<void> getCurrentLocation() async {
  try {
    bool serviceEnabled =
        await Geolocator.isLocationServiceEnabled();

    if (!serviceEnabled) {
      if (!mounted) return;
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enable location services.'),
        ),
      );
      return;
    }

    LocationPermission permission =
        await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      if (!mounted) return;
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Location permission is required.'),
        ),
      );
      return;
    }

    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 15),
      ),
    );

    if (!mounted) return;

    final location = LatLng(
      position.latitude,
      position.longitude,
    );

    setState(() {
      selectedLocation = location;
      isLoading = false;
    });

    await getAddress(location);
  } catch (e) {
    debugPrint('Unable to get current location: $e');

    if (!mounted) return;

    setState(() => isLoading = false);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Could not get your location. Check GPS and permissions.',
        ),
      ),
    );
  }
}





  // GET ADDRESS FROM LAT LNG



Future<void> getAddress(LatLng position) async {
  if (!mounted) return;

  try {
    final places = await placemarkFromCoordinates(
      position.latitude,
      position.longitude,
    );

    if (!mounted) return;

    if (places.isEmpty) {
      setState(() {
        address = '';
      });
      debugPrint('No readable address returned.');
      return;
    }

    final place = places.first;

    final parts = [
      place.name,
      place.street,
      place.subLocality,
      place.locality,
      place.subAdministrativeArea,
      place.administrativeArea,
      place.postalCode,
      place.country,
    ]
        .whereType<String>()
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList();

    // Remove repeated adjacent address components.
    final uniqueParts = <String>[];
    for (final part in parts) {
      if (uniqueParts.isEmpty || uniqueParts.last != part) {
        uniqueParts.add(part);
      }
    }

    setState(() {
      address = uniqueParts.join(', ');
    });
  } on PlatformException catch (e) {
    debugPrint('Address lookup failed: ${e.message}');

    if (!mounted) return;

    setState(() {
      address = '';
    });
  } catch (e) {
    debugPrint('Unable to resolve address: $e');

    if (!mounted) return;

    setState(() {
      address = '';
    });
  }
}


  // WHEN USER MOVES MAP

  void onCameraMove(
      CameraPosition position
      ){


    selectedLocation =
        position.target;


  }





  // WHEN USER STOPS MOVING MAP

 
bool isGettingAddress = false;

Future<void> onCameraIdle() async {
  if (selectedLocation == null || isGettingAddress) {
    return;
  }

  isGettingAddress = true;

  try {
    await getAddress(selectedLocation!);
  } finally {
    isGettingAddress = false;
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
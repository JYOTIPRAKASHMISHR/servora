import 'package:firebase_database/firebase_database.dart';


class WorkerMatchingService{


final DatabaseReference workersRef =
FirebaseDatabase.instance.ref("workers");



Future<List<Map<String,dynamic>>> findWorkers({
required String category,
}) async{


DatabaseEvent event =
await workersRef.once();



List<Map<String,dynamic>> matchedWorkers=[];



if(event.snapshot.exists){


Map workers =
Map.from(event.snapshot.value as Map);



workers.forEach((key,value){


Map worker =
Map.from(value);



List skills =
List.from(worker["skills"] ?? []);



bool skillMatch=false;



for(String skill in skills){


if(category
.toLowerCase()
.contains(
skill.toLowerCase()
)
||
skill.toLowerCase()
.contains(
category.toLowerCase()
)){


skillMatch=true;


}

}



if(
skillMatch &&
worker["profileCompleted"]==true
){


matchedWorkers.add({

"workerId":key,

"name":
worker["name"],

"skills":
skills,

"location":
worker["location"],

"latitude":
worker["latitude"],

"longitude":
worker["longitude"],


});


}



});


}



return matchedWorkers;


}


}
class MessageModel {

  final String senderId;
  final String message;
  final String time;


  MessageModel({

    required this.senderId,
    required this.message,
    required this.time,

  });


  factory MessageModel.fromMap(Map data){

    return MessageModel(

      senderId:data["senderId"] ?? "",

      message:data["message"] ?? "",

      time:data["time"] ?? "",

    );

  }



  Map<String,dynamic> toMap(){

    return {

      "senderId":senderId,

      "message":message,

      "time":time,

    };

  }

}
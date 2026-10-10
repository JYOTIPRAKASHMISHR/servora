class NotificationModel {

  String id;
  String userId;
  String title;
  String body;
  String type;
  String createdAt;
  bool read;


  NotificationModel({

    required this.id,
    required this.userId,
    required this.title,
    required this.body,
    required this.type,
    required this.createdAt,
    required this.read,

  });


  Map<String,dynamic> toMap(){

    return {

      "id":id,
      "userId":userId,
      "title":title,
      "body":body,
      "type":type,
      "createdAt":createdAt,
      "read":read,

    };

  }

}
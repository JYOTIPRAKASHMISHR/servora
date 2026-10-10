class ApplicationModel {

  final String applicationId;
  final String serviceId;
  final String customerId;
  final String workerId;
  final String price;
  final String message;
  final String status;
  final String createdAt;


  ApplicationModel({

    required this.applicationId,
    required this.serviceId,
    required this.customerId,
    required this.workerId,
    required this.price,
    required this.message,
    required this.status,
    required this.createdAt,

  });


  Map<String,dynamic> toMap(){

    return {

      "applicationId":applicationId,

      "serviceId":serviceId,

      "customerId":customerId,

      "workerId":workerId,

      "price":price,

      "message":message,

      "status":status,

      "createdAt":createdAt,

    };

  }

}
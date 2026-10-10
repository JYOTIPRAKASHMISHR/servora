class ServiceModel {
  final String serviceId;
  final String serviceName;
  final String description;
  final String location;

  final double latitude;
  final double longitude;

  final String budget;
  final String categoryType;
  final String date;
  final String status;
  final String customerId;
  final String createdAt;

  // NEW
  final String urgency;

  ServiceModel({
    required this.serviceId,
    required this.serviceName,
    required this.description,
    required this.location,
    required this.latitude,
    required this.longitude,
    required this.budget,
    required this.categoryType,
    required this.date,
    required this.status,
    required this.customerId,
    required this.createdAt,

    // NEW
    required this.urgency,
  });

  // Firebase Realtime Database -> Model
  factory ServiceModel.fromMap(
    Map<dynamic, dynamic> map,
    String id,
  ) {
    return ServiceModel(
      serviceId: id,

      serviceName:
          map["serviceName"]?.toString() ?? "",

      description:
          map["description"]?.toString() ?? "",

      location:
          map["location"]?.toString() ?? "",

      latitude:
          double.tryParse(
                map["latitude"]?.toString() ?? "",
              ) ??
              0.0,

      longitude:
          double.tryParse(
                map["longitude"]?.toString() ?? "",
              ) ??
              0.0,

      budget:
          map["budget"]?.toString() ?? "",

      categoryType:
          map["categoryType"]?.toString() ?? "",

      date:
          map["date"]?.toString() ?? "",

      status:
          map["status"]?.toString() ?? "pending",

      customerId:
          map["customerId"]?.toString() ?? "",

      createdAt:
          map["createdAt"]?.toString() ?? "",

      // NEW
      urgency:
          map["urgency"]?.toString() ?? "normal",
    );
  }

  // Model -> Firebase
  Map<String, dynamic> toMap() {
    return {
      "serviceId": serviceId,
      "serviceName": serviceName,
      "description": description,
      "location": location,
      "latitude": latitude,
      "longitude": longitude,
      "budget": budget,
      "categoryType": categoryType,
      "date": date,
      "status": status,
      "customerId": customerId,
      "createdAt": createdAt,

      // NEW
      "urgency": urgency,
    };
  }
}
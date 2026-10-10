import 'dart:convert';
import 'package:http/http.dart' as http;

class PaymentApiService {

  // Android Emulator
  static const String baseUrl =
      "http://127.0.0.1:8080";

  Future<Map<String, dynamic>> createOrder({
    required double amount,
  }) async {

    final response = await http.post(
      Uri.parse(
        "$baseUrl/api/payment/create-order",
      ),
      headers: {
        "Content-Type": "application/json",
      },
      body: jsonEncode({
        "amount": amount,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception(
        "Unable to create payment order: "
        "${response.body}",
      );
    }

    return jsonDecode(response.body)
        as Map<String, dynamic>;
  }

  Future<bool> verifyPayment({
    required String paymentId,
    required String orderId,
    required String signature,
  }) async {

    final response = await http.post(
      Uri.parse(
        "$baseUrl/api/payment/verify",
      ),
      headers: {
        "Content-Type": "application/json",
      },
      body: jsonEncode({
        "razorpayPaymentId": paymentId,
        "razorpayOrderId": orderId,
        "razorpaySignature": signature,
      }),
    );

    if (response.statusCode != 200) {
      return false;
    }

    final data =
        jsonDecode(response.body)
            as Map<String, dynamic>;

    return data["success"] == true;
  }
Future<Map<String, dynamic>> createPaymentQR({
  required String serviceId,
  required double amount,
}) async {
  final response = await http.post(
    Uri.parse(
      "$baseUrl/api/payment/create-qr",
    ),
    headers: {
      "Content-Type": "application/json",
    },
    body: jsonEncode({
      "serviceId": serviceId,
      "amount": amount,
    }),
  );

  if (response.statusCode != 200) {
    throw Exception(
      "Unable to create payment QR: "
      "${response.body}",
    );
  }

  final Map<String, dynamic> data =
      jsonDecode(response.body)
          as Map<String, dynamic>;

  if (data["success"] != true) {
    throw Exception(
      data["message"] ??
          "Unable to create payment QR",
    );
  }

  return data;
}
}
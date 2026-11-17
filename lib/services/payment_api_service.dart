import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

class PaymentApiService {

  // Android Emulator

  static const String baseUrl =
      "http://10.29.118.139:8080";

      
 static Future<Map<String, String>> getAuthHeaders() async {
  final user = FirebaseAuth.instance.currentUser;

  if (user == null) {
    throw Exception("User is not logged in.");
  }

  final idToken = await user.getIdToken();

  if (idToken == null || idToken.isEmpty) {
    throw Exception("Unable to get Firebase ID token.");
  }

  return {
    "Content-Type": "application/json",
    "Authorization": "Bearer $idToken",
  };
}

 Future<Map<String, dynamic>> createOrder({
  required String serviceId,
}) async {
  final response = await http.post(
    Uri.parse("$baseUrl/api/payment/create-order"),
    headers: {"Content-Type": "application/json"},
    body: jsonEncode({"serviceId": serviceId}),
  );

  if (response.statusCode != 200) {
    throw Exception(
      "Unable to create payment order: ${response.body}",
    );
  }

  return jsonDecode(response.body) as Map<String, dynamic>;
}

Future<bool> verifyPayment({
  required String serviceId,
  required String paymentId,
  required String orderId,
  required String signature,
}) async {
  try {
    final response = await http
        .post(
          Uri.parse('$baseUrl/api/payment/verify'),
          headers: {
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'serviceId': serviceId,
            'razorpayPaymentId': paymentId,
            'razorpayOrderId': orderId,
            'razorpaySignature': signature,
          }),
        )
        .timeout(const Duration(seconds: 25));

    debugPrint(
      'Payment verification HTTP status: ${response.statusCode}',
    );

    if (response.statusCode != 200) {
      debugPrint(
        'Verification response: ${response.body}',
      );
      return false;
    }

    final decoded = jsonDecode(response.body);

    if (decoded is! Map<String, dynamic>) {
      debugPrint('Unexpected verification response format.');
      return false;
    }

    return decoded['success'] == true;
  } catch (e) {
    debugPrint('Payment verification request failed: $e');
    rethrow;
  }
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


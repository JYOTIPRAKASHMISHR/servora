import 'dart:convert';
import 'package:http/http.dart' as http;

class NotificationApiService {

  static const String baseUrl =
      "http://127.0.0.1:8080";

  static Future<bool> sendNotification({
    required String fcmToken,
    required String title,
    required String body,
  }) async {

    try {

      final response = await http.post(
        Uri.parse(
          "$baseUrl/api/notifications/send",
        ),
        headers: {
          "Content-Type": "application/json",
        },
        body: jsonEncode({
          "fcmToken": fcmToken,
          "title": title,
          "body": body,
        }),
      );

      print(
        "Notification API status: ${response.statusCode}",
      );

      print(
        "Notification API response: ${response.body}",
      );

      return response.statusCode >= 200 &&
          response.statusCode < 300;

    } catch (e) {

      print(
        "Notification API error: $e",
      );

      return false;
    }
  }
}
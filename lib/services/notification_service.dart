import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:vibration/vibration.dart';

class NotificationService {
  // =========================================================
  // FIREBASE MESSAGING
  // =========================================================

  static final FirebaseMessaging messaging =
      FirebaseMessaging.instance;

  // =========================================================
  // LOCAL NOTIFICATIONS
  // =========================================================

  static final FlutterLocalNotificationsPlugin localNotification =
      FlutterLocalNotificationsPlugin();

  // =========================================================
  // NOTIFICATION CHANNELS
  // =========================================================

  // Normal notifications
  static const String normalChannelId =
      'servora_channel';

  static const String normalChannelName =
      'Servora Notifications';

  // Urgent notifications
  static const String urgentChannelId =
      'servora_urgent_channel';

  static const String urgentChannelName =
      'Servora Urgent Notifications';

  // NEW SERVICE notifications
  static const String newServiceChannelId =
      'servora_new_service_channel';

  static const String newServiceChannelName =
      'Servora New Services';

  // =========================================================
  // NAVIGATOR KEY
  // =========================================================

  static GlobalKey<NavigatorState>? navigatorKey;

  // =========================================================
  // INITIALIZE
  // =========================================================

  static Future<void> initialize({
    GlobalKey<NavigatorState>? navigationKey,
  }) async {
    try {
      navigatorKey = navigationKey;

      // -------------------------------------------------------
      // REQUEST NOTIFICATION PERMISSION
      // -------------------------------------------------------

      final NotificationSettings permission =
          await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      print(
        "FCM Permission: ${permission.authorizationStatus}",
      );

      // -------------------------------------------------------
      // ANDROID LOCAL NOTIFICATION INITIALIZATION
      // -------------------------------------------------------

      const AndroidInitializationSettings androidSettings =
          AndroidInitializationSettings(
        '@drawable/ic_stat_servora',
      );

      const InitializationSettings initializationSettings =
          InitializationSettings(
        android: androidSettings,
      );

      await localNotification.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse:
            _onLocalNotificationTap,
      );

      // -------------------------------------------------------
      // NORMAL CHANNEL
      // -------------------------------------------------------

      const AndroidNotificationChannel normalChannel =
          AndroidNotificationChannel(
        normalChannelId,
        normalChannelName,
        description:
            'Normal Servora service notifications',
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
      );

      // -------------------------------------------------------
      // URGENT CHANNEL
      // -------------------------------------------------------

      const AndroidNotificationChannel urgentChannel =
    AndroidNotificationChannel(
  urgentChannelId,
  urgentChannelName,
  description:
      'Urgent Servora service notifications',
  importance: Importance.max,
  playSound: true,
  enableVibration: true,
  sound: RawResourceAndroidNotificationSound(
    'urgent_siren',
  ),
);
      // -------------------------------------------------------
      // NEW SERVICE CHANNEL
      // -------------------------------------------------------

      const AndroidNotificationChannel newServiceChannel =
          AndroidNotificationChannel(
        newServiceChannelId,
        newServiceChannelName,
        description:
            'Notifications for newly available Servora services',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
      );

      // -------------------------------------------------------
      // CREATE ANDROID CHANNELS
      // -------------------------------------------------------

      final AndroidFlutterLocalNotificationsPlugin?
          androidPlugin =
          localNotification
              .resolvePlatformSpecificImplementation<
                  AndroidFlutterLocalNotificationsPlugin>();

      if (androidPlugin != null) {
        await androidPlugin.createNotificationChannel(
          normalChannel,
        );

        await androidPlugin.createNotificationChannel(
          urgentChannel,
        );

        await androidPlugin.createNotificationChannel(
          newServiceChannel,
        );

        print(
          "Android notification channels created",
        );
      }

      // -------------------------------------------------------
      // FOREGROUND FCM
      // -------------------------------------------------------

      FirebaseMessaging.onMessage.listen(
        (RemoteMessage message) async {
          print(
            "======================================",
          );

          print(
            "FCM FOREGROUND MESSAGE",
          );

          print(
            "Title: ${message.notification?.title}",
          );

          print(
            "Body: ${message.notification?.body}",
          );

          print(
            "Data: ${message.data}",
          );

          print(
            "======================================",
          );

          await showNotification(message);
        },
      );

      // -------------------------------------------------------
      // BACKGROUND NOTIFICATION TAP
      // -------------------------------------------------------

      FirebaseMessaging.onMessageOpenedApp.listen(
        (RemoteMessage message) {
          print(
            "FCM notification opened from background",
          );

          print(
            "Notification data: ${message.data}",
          );

          handleNotificationTap(
            message.data,
          );
        },
      );

      // -------------------------------------------------------
      // TERMINATED STATE
      // -------------------------------------------------------

      final RemoteMessage? initialMessage =
          await messaging.getInitialMessage();

      if (initialMessage != null) {
        print(
          "FCM notification opened from terminated state",
        );

        print(
          "Initial notification data: "
          "${initialMessage.data}",
        );

        WidgetsBinding.instance.addPostFrameCallback(
          (_) {
            handleNotificationTap(
              initialMessage.data,
            );
          },
        );
      }

      // -------------------------------------------------------
      // BACKGROUND HANDLER
      // -------------------------------------------------------

      FirebaseMessaging.onBackgroundMessage(
        backgroundHandler,
      );

      // -------------------------------------------------------
      // TOKEN REFRESH LISTENER
      // -------------------------------------------------------

      listenTokenRefresh();

      print(
        "NotificationService initialized successfully",
      );
    } catch (e) {
      print(
        "Notification initialization error: $e",
      );
    }
  }

  // =========================================================
  // BACKGROUND FCM HANDLER
  // =========================================================

  @pragma('vm:entry-point')
  static Future<void> backgroundHandler(
    RemoteMessage message,
  ) async {
    print(
      "======================================",
    );

    print(
      "FCM BACKGROUND MESSAGE",
    );

    print(
      "Title: ${message.notification?.title}",
    );

    print(
      "Body: ${message.notification?.body}",
    );

    print(
      "Data: ${message.data}",
    );

    print(
      "======================================",
    );

    /*
      IMPORTANT:

      Your Spring Boot backend sends both:

      notification:
      {
        title: "...",
        body: "..."
      }

      and:

      data:
      {
        type: "new_service",
        serviceId: "...",
        ...
      }

      When the app is in the background or terminated,
      Android/FCM normally displays the notification
      automatically.

      We DO NOT call showNotification() here because
      that could create a duplicate notification.

      The Android notification channel controls the
      background notification's vibration behavior.
    */
  }

  // =========================================================
  // SAVE FCM TOKEN
  // =========================================================

  static Future<void> saveToken() async {
    try {
      final User? user =
          FirebaseAuth.instance.currentUser;

      if (user == null) {
        print(
          "FCM: User not logged in",
        );
        return;
      }

      print(
        "FCM: Getting token...",
      );

      final String? token =
          await messaging.getToken();

      if (token == null || token.isEmpty) {
        print(
          "FCM: Token is null or empty",
        );
        return;
      }

      print(
        "FCM TOKEN:",
      );

      print(token);

      await FirebaseDatabase.instance
          .ref("users")
          .child(user.uid)
          .update({
        "fcmToken": token,
      });

      print(
        "FCM: TOKEN SAVED SUCCESSFULLY",
      );
    } catch (e) {
      print(
        "FCM TOKEN ERROR: $e",
      );
    }
  }

  // =========================================================
  // TOKEN REFRESH
  // =========================================================

  static void listenTokenRefresh() {
    messaging.onTokenRefresh.listen(
      (String newToken) async {
        try {
          final User? user =
              FirebaseAuth.instance.currentUser;

          if (user == null) {
            print(
              "FCM: Cannot save refreshed token. "
              "User not logged in.",
            );
            return;
          }

          await FirebaseDatabase.instance
              .ref("users")
              .child(user.uid)
              .update({
            "fcmToken": newToken,
          });

          print(
            "FCM: Token refreshed and saved",
          );
        } catch (e) {
          print(
            "FCM token refresh error: $e",
          );
        }
      },
    );
  }

  // =========================================================
  // SHOW DATABASE NOTIFICATION
  // =========================================================

  static Future<void> showDatabaseNotification(
    String title,
    String body, {
    String? serviceId,
    String? type,
    String? senderId,
    String? receiverId,
    bool urgent = false,
  }) async {
    try {
      final String notificationType =
          type ?? "general";

      final bool newService =
          notificationType == "new_service";

      // -------------------------------------------------------
      // 5 SECOND VIBRATION FOR NEW SERVICE
      // -------------------------------------------------------

      if (newService) {
        await _vibrateForNewService();
      }

      // -------------------------------------------------------
      // SELECT CHANNEL
      // -------------------------------------------------------

      final String channelId;

      final String channelName;

      final String channelDescription;

      final Importance importance;

      final Priority priority;

      final Int64List vibrationPattern;

      if (newService) {
        channelId = newServiceChannelId;

        channelName = newServiceChannelName;

        channelDescription =
            'Notifications for newly available Servora services';

        importance = Importance.max;

        priority = Priority.max;

        // Short Android notification vibration.
        // The 5-second vibration is handled separately
        // by Vibration.vibrate().
        vibrationPattern = Int64List.fromList([
          0,
          500,
          200,
          500,
          200,
          500,
        ]);
      } else if (urgent) {
        channelId = urgentChannelId;

        channelName = urgentChannelName;

        channelDescription =
            'Urgent Servora service notifications';

        importance = Importance.max;

        priority = Priority.max;

        vibrationPattern = Int64List.fromList([
          0,
          500,
          200,
          500,
          200,
          800,
        ]);
      } else {
        channelId = normalChannelId;

        channelName = normalChannelName;

        channelDescription =
            'Normal Servora service notifications';

        importance = Importance.high;

        priority = Priority.high;

        vibrationPattern = Int64List.fromList([
          0,
          300,
        ]);
      }

      // -------------------------------------------------------
      // ANDROID NOTIFICATION DETAILS
      // -------------------------------------------------------

      final AndroidNotificationDetails androidDetails =
    AndroidNotificationDetails(
  channelId,
  channelName,
  channelDescription: channelDescription,
  importance: importance,
  priority: priority,
  playSound: true,
  enableVibration: true,
  icon: '@drawable/ic_stat_servora',
  vibrationPattern: vibrationPattern,
  sound: urgent
      ? const RawResourceAndroidNotificationSound(
          'urgent_siren',
        )
      : null,
);

      final NotificationDetails details =
          NotificationDetails(
        android: androidDetails,
      );

      // -------------------------------------------------------
      // PAYLOAD
      // -------------------------------------------------------

      final Map<String, String> payload = {
        "type": notificationType,
        "serviceId": serviceId ?? "",
        "senderId": senderId ?? "",
        "receiverId": receiverId ?? "",
      };

      // -------------------------------------------------------
      // SHOW NOTIFICATION
      // -------------------------------------------------------

      await localNotification.show(
        DateTime.now()
            .millisecondsSinceEpoch
            .remainder(100000),
        title,
        body,
        details,
        payload: _encodePayload(
          payload,
        ),
      );

      print(
        "Database notification displayed",
      );
    } catch (e) {
      print(
        "Database notification error: $e",
      );
    }
  }

  // =========================================================
  // SHOW FCM FOREGROUND NOTIFICATION
  // =========================================================

  static Future<void> showNotification(
    RemoteMessage message,
  ) async {
    try {
      final String type =
          message.data["type"]?.toString() ??
              "general";

      final bool urgent =
          type == "urgent_service";

      final bool newService =
          type == "new_service";

      // =====================================================
      // NEW SERVICE VIBRATION
      // =====================================================

      if (newService) {
        await _vibrateForNewService();
      }

      // =====================================================
      // TITLE
      // =====================================================

      final String title =
          message.notification?.title ??
              message.data["title"]?.toString() ??
              "Servora";

      // =====================================================
      // BODY
      // =====================================================

      final String body =
          message.notification?.body ??
              message.data["body"]?.toString() ??
              "You have a new notification";

      // =====================================================
      // CHANNEL SELECTION
      // =====================================================

      final String channelId;

      final String channelName;

      final String channelDescription;

      final Importance importance;

      final Priority priority;

      final Int64List vibrationPattern;

      if (newService) {
        // ---------------------------------------------------
        // NEW SERVICE
        // ---------------------------------------------------

        channelId = newServiceChannelId;

        channelName = newServiceChannelName;

        channelDescription =
            'Notifications for newly available Servora services';

        importance = Importance.max;

        priority = Priority.max;

        vibrationPattern = Int64List.fromList([
          0,
          500,
          200,
          500,
          200,
          500,
        ]);
      } else if (urgent) {
        // ---------------------------------------------------
        // URGENT
        // ---------------------------------------------------

        channelId = urgentChannelId;

        channelName = urgentChannelName;

        channelDescription =
            'Urgent Servora service notifications';

        importance = Importance.max;

        priority = Priority.max;

        vibrationPattern = Int64List.fromList([
          0,
          500,
          200,
          500,
          200,
          800,
        ]);
      } else {
        // ---------------------------------------------------
        // NORMAL
        // ---------------------------------------------------

        channelId = normalChannelId;

        channelName = normalChannelName;

        channelDescription =
            'Normal Servora service notifications';

        importance = Importance.high;

        priority = Priority.high;

        vibrationPattern = Int64List.fromList([
          0,
          300,
        ]);
      }

      // =====================================================
      // ANDROID DETAILS
      // =====================================================

      final AndroidNotificationDetails androidDetails =
    AndroidNotificationDetails(
  channelId,
  channelName,
  channelDescription: channelDescription,
  importance: importance,
  priority: priority,
  playSound: true,
  enableVibration: true,
  icon: '@drawable/ic_stat_servora',
  vibrationPattern: vibrationPattern,
  sound: urgent
      ? const RawResourceAndroidNotificationSound(
          'urgent_siren',
        )
      : null,
);

      final NotificationDetails details =
          NotificationDetails(
        android: androidDetails,
      );

      // =====================================================
      // SHOW NOTIFICATION
      // =====================================================

      await localNotification.show(
        DateTime.now()
            .millisecondsSinceEpoch
            .remainder(100000),
        title,
        body,
        details,
        payload: _encodePayload(
          message.data,
        ),
      );

      print(
        "Servora notification displayed",
      );

      print(
        "Notification type: $type",
      );
    } catch (e) {
      print(
        "FCM notification display error: $e",
      );
    }
  }

  // =========================================================
  // NEW SERVICE VIBRATION
  // =========================================================

  static Future<void> _vibrateForNewService() async {
    try {
      final bool hasVibrator =
          await Vibration.hasVibrator();

      if (!hasVibrator) {
        print(
          "Device does not have a vibrator",
        );
        return;
      }

      print(
        "📳 NEW SERVICE DETECTED",
      );

      print(
        "📳 Starting 5 second vibration...",
      );

      await Vibration.vibrate(
        duration: 5000,
      );

      print(
        "📳 New service 5 second vibration completed",
      );
    } catch (e) {
      print(
        "Vibration error: $e",
      );
    }
  }

  // =========================================================
  // LOCAL NOTIFICATION TAP
  // =========================================================

  static void _onLocalNotificationTap(
    NotificationResponse response,
  ) {
    try {
      final String? payload =
          response.payload;

      if (payload == null ||
          payload.isEmpty) {
        print(
          "Notification tap: No payload",
        );
        return;
      }

      final Map<String, String> data =
          _decodePayload(payload);

      print(
        "Local notification tapped",
      );

      print(
        "Notification data: $data",
      );

      handleNotificationTap(
        data,
      );
    } catch (e) {
      print(
        "Notification tap error: $e",
      );
    }
  }

  // =========================================================
  // HANDLE NOTIFICATION TAP
  // =========================================================

  static void handleNotificationTap(
    Map<String, dynamic> data,
  ) {
    try {
      final String type =
          data["type"]?.toString() ??
              "";

      final String serviceId =
          data["serviceId"]?.toString() ??
              "";

      final String senderId =
          data["senderId"]?.toString() ??
              "";

      final String receiverId =
          data["receiverId"]?.toString() ??
              "";

      print(
        "======================================",
      );

      print(
        "SERVORA NOTIFICATION TAP",
      );

      print(
        "Type: $type",
      );

      print(
        "Service ID: $serviceId",
      );

      print(
        "Sender ID: $senderId",
      );

      print(
        "Receiver ID: $receiverId",
      );

      print(
        "======================================",
      );

      // -------------------------------------------------------
      // NAVIGATOR CHECK
      // -------------------------------------------------------

      if (navigatorKey?.currentState == null) {
        print(
          "Navigator is not ready yet.",
        );
        return;
      }

      // -------------------------------------------------------
      // SERVICE ID CHECK
      // -------------------------------------------------------

      if (serviceId.isEmpty) {
        print(
          "Notification has no serviceId.",
        );
        return;
      }

      // -------------------------------------------------------
      // NOTIFICATION ROUTING
      // -------------------------------------------------------

      switch (type) {
        case "new_service":
          print(
            "Open AvailableJobsScreen",
          );

          // Add your exact AvailableJobsScreen
          // navigation here when required.

          break;

        case "offer_received":
          print(
            "Open CustomerServiceTrackingScreen",
          );

          break;

        case "offer_accepted":
          print(
            "Open WorkerActiveJobsScreen",
          );

          break;

        case "work_started":
          print(
            "Open CustomerServiceTrackingScreen",
          );

          break;

        case "work_completed":
          print(
            "Open CustomerServiceTrackingScreen",
          );

          break;

        case "payment_completed":
          print(
            "Open WorkerActiveJobsScreen",
          );

          break;

        case "urgent_service":
          print(
            "Open WorkerUrgentJobsScreen",
          );

          break;

        default:
          print(
            "Unknown notification type: $type",
          );
      }
    } catch (e) {
      print(
        "Notification routing error: $e",
      );
    }
  }

  // =========================================================
  // CREATE DATABASE NOTIFICATION
  // =========================================================

  static Future<void> createNotification({
    required String receiverId,
    required String senderId,
    required String serviceId,
    required String type,
    required String title,
    required String body,
  }) async {
    try {
      /*
        IMPORTANT:

        This follows your current structure:

        notifications
            └── PUSH_ID
                  ├── receiverId
                  ├── senderId
                  ├── serviceId
                  ├── type
                  ├── title
                  ├── body
                  ├── createdAt
                  └── isRead

        If your NotificationScreen currently reads:

        notifications/{currentUser.uid}

        then this function should instead save under:

        notifications/{receiverId}/{pushId}

        Your Spring Boot backend is already using:

        notifications/{workerId}/{pushId}

        So for consistency, we use the same structure below.
      */

      final DatabaseReference notificationRef =
          FirebaseDatabase.instance
              .ref("notifications")
              .child(receiverId)
              .push();

      await notificationRef.set({
        "receiverId": receiverId,
        "senderId": senderId,
        "serviceId": serviceId,
        "type": type,
        "title": title,
        "message": body,
        "body": body,
        "createdAt": ServerValue.timestamp,
        "isRead": false,
      });

      print(
        "Notification saved to database",
      );

      print(
        "Receiver: $receiverId",
      );

      print(
        "Type: $type",
      );

      print(
        "Service: $serviceId",
      );
    } catch (e) {
      print(
        "Create notification error: $e",
      );
    }
  }

  // =========================================================
  // PAYLOAD ENCODER
  // =========================================================

  static String _encodePayload(
    Map<String, dynamic> data,
  ) {
    final List<String> parts = [];

    data.forEach(
      (key, value) {
        final String safeKey =
            key
                .toString()
                .replaceAll("|", "");

        final String safeValue =
            value
                .toString()
                .replaceAll("|", "");

        parts.add(
          "$safeKey=$safeValue",
        );
      },
    );

    return parts.join("|");
  }

  // =========================================================
  // PAYLOAD DECODER
  // =========================================================

  static Map<String, String> _decodePayload(
    String payload,
  ) {
    final Map<String, String> result = {};

    final List<String> parts =
        payload.split("|");

    for (final String part in parts) {
      final int separator =
          part.indexOf("=");

      if (separator <= 0) {
        continue;
      }

      final String key =
          part.substring(
        0,
        separator,
      );

      final String value =
          part.substring(
        separator + 1,
      );

      result[key] = value;
    }

    return result;
  }
}
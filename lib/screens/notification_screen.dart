import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_animate/flutter_animate.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() =>
      _NotificationScreenState();
}

class _NotificationScreenState
    extends State<NotificationScreen> {

  // ============================================================
  // FIREBASE
  // ============================================================

  final DatabaseReference notificationsRef =
      FirebaseDatabase.instance.ref("notifications");

  StreamSubscription<DatabaseEvent>? subscription;

  // ============================================================
  // STATE
  // ============================================================

  List<Map<String, dynamic>> notifications = [];

  bool loading = true;

  String? currentUserId;


  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();

    listenNotifications();
  }


  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {

    subscription?.cancel();

    super.dispose();
  }


  // ============================================================
  // LISTEN CURRENT USER NOTIFICATIONS
  // ============================================================

  void listenNotifications() {

    // Cancel old listener first.
    subscription?.cancel();

    final User? user =
        FirebaseAuth.instance.currentUser;


    // ------------------------------------------------------------
    // USER NOT LOGGED IN
    // ------------------------------------------------------------

    if (user == null) {

      if (mounted) {

        setState(() {

          notifications = [];

          loading = false;

          currentUserId = null;
        });
      }

      return;
    }


    currentUserId = user.uid;


    // ------------------------------------------------------------
    // IMPORTANT:
    //
    // Only listen to:
    //
    // notifications/{currentUser.uid}
    //
    // ------------------------------------------------------------

    final DatabaseReference userNotificationsRef =
        notificationsRef.child(user.uid);


    subscription =
        userNotificationsRef.onValue.listen(
      (DatabaseEvent event) {

        final List<Map<String, dynamic>> temp = [];


        // --------------------------------------------------------
        // CHECK DATA EXISTS
        // --------------------------------------------------------

        if (event.snapshot.exists) {

          final Object? rawData =
              event.snapshot.value;


          if (rawData is Map) {

            rawData.forEach((key, value) {

              // --------------------------------------------------
              // Make sure notification itself is a Map
              // --------------------------------------------------

              if (value is Map) {

                final Map<String, dynamic> notification =
                    Map<String, dynamic>.from(value);


                temp.add({

                  "notificationId":
                      key.toString(),

                  ...notification,
                });
              }
            });
          }
        }


        // --------------------------------------------------------
        // LATEST NOTIFICATION FIRST
        // --------------------------------------------------------

        temp.sort((a, b) {

          final String dateA =
              a["createdAt"]?.toString() ?? "";

          final String dateB =
              b["createdAt"]?.toString() ?? "";

          return dateB.compareTo(dateA);
        });


        // --------------------------------------------------------
        // UPDATE UI
        // --------------------------------------------------------

        if (!mounted) {
          return;
        }


        setState(() {

          notifications = temp;

          loading = false;
        });
      },

      onError: (error) {

        debugPrint(
          "Notification listener error: $error",
        );


        if (!mounted) {
          return;
        }


        setState(() {

          loading = false;
        });
      },
    );
  }


  // ============================================================
  // MANUAL REFRESH
  // ============================================================

  Future<void> refreshNotifications() async {

    final User? user =
        FirebaseAuth.instance.currentUser;


    if (user == null) {
      return;
    }


    try {

      final DataSnapshot snapshot =
          await notificationsRef
              .child(user.uid)
              .get();


      final List<Map<String, dynamic>> temp = [];


      if (snapshot.exists) {

        final Object? rawData =
            snapshot.value;


        if (rawData is Map) {

          rawData.forEach((key, value) {

            if (value is Map) {

              final Map<String, dynamic> notification =
                  Map<String, dynamic>.from(value);


              temp.add({

                "notificationId":
                    key.toString(),

                ...notification,
              });
            }
          });
        }
      }


      temp.sort((a, b) {

        final String dateA =
            a["createdAt"]?.toString() ?? "";

        final String dateB =
            b["createdAt"]?.toString() ?? "";

        return dateB.compareTo(dateA);
      });


      if (!mounted) {
        return;
      }


      setState(() {

        notifications = temp;
      });

    } catch (e) {

      debugPrint(
        "Refresh notification error: $e",
      );
    }
  }


  // ============================================================
  // DELETE NOTIFICATION
  // ============================================================

  Future<void> deleteNotification(
      String notificationId) async {

    final User? user =
        FirebaseAuth.instance.currentUser;


    if (user == null) {
      return;
    }


    try {

      await notificationsRef
          .child(user.uid)
          .child(notificationId)
          .remove();

    } catch (e) {

      debugPrint(
        "Delete notification error: $e",
      );
    }
  }


  // ============================================================
  // DELETE ALL NOTIFICATIONS
  // ============================================================

  Future<void> deleteAllNotifications() async {

    final User? user =
        FirebaseAuth.instance.currentUser;


    if (user == null ||
        notifications.isEmpty) {

      return;
    }


    final bool? confirm =
        await showDialog<bool>(
      context: context,

      builder: (context) {

        return AlertDialog(

          shape: RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(22),
          ),

          title: const Text(
            "Clear notifications?",
            style: TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),

          content: const Text(
            "All your notifications will be permanently removed.",
          ),

          actions: [

            TextButton(
              onPressed: () {

                Navigator.pop(
                  context,
                  false,
                );
              },

              child: const Text(
                "Cancel",
              ),
            ),

            ElevatedButton(
              onPressed: () {

                Navigator.pop(
                  context,
                  true,
                );
              },

              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),

              child: const Text(
                "Clear All",
              ),
            ),
          ],
        );
      },
    );


    if (confirm != true) {
      return;
    }


    try {

      await notificationsRef
          .child(user.uid)
          .remove();

    } catch (e) {

      debugPrint(
        "Delete all notifications error: $e",
      );
    }
  }


  // ============================================================
  // NOTIFICATION ICON
  // ============================================================

  IconData notificationIcon(
      String type) {

    switch (type.toLowerCase()) {

      case "new_service":
        return Icons.home_repair_service_rounded;

      case "worker_sent_offer":
        return Icons.currency_rupee_rounded;

      case "worker_accepted_price":
        return Icons.check_circle_rounded;

      case "service_started":
        return Icons.play_circle_fill_rounded;

      case "service_completed":
        return Icons.done_all_rounded;

      default:
        return Icons.notifications_rounded;
    }
  }


  // ============================================================
  // NOTIFICATION COLOR
  // ============================================================

  Color notificationColor(
      String type) {

    switch (type.toLowerCase()) {

      case "new_service":
        return const Color(0xff2563EB);

      case "worker_sent_offer":
        return const Color(0xff2563EB);

      case "worker_accepted_price":
        return const Color(0xff16A34A);

      case "service_started":
        return const Color(0xffF59E0B);

      case "service_completed":
        return const Color(0xff7C3AED);

      default:
        return const Color(0xff64748B);
    }
  }


  // ============================================================
  // FORMAT TYPE
  // ============================================================

  String formatType(String type) {

    if (type.trim().isEmpty) {
      return "NOTIFICATION";
    }


    return type
        .replaceAll("_", " ")
        .toUpperCase();
  }


  // ============================================================
  // FORMAT DATE
  // ============================================================

  String formatDate(dynamic value) {

    if (value == null) {
      return "";
    }


    final String dateString =
        value.toString();


    if (dateString.isEmpty) {
      return "";
    }


    try {

      DateTime date =
          DateTime.parse(dateString).toLocal();


      final String hour =
          date.hour.toString().padLeft(2, "0");

      final String minute =
          date.minute.toString().padLeft(2, "0");


      return
          "${date.day.toString().padLeft(2, '0')}/"
          "${date.month.toString().padLeft(2, '0')}/"
          "${date.year}  "
          "$hour:$minute";

    } catch (e) {

      return dateString;
    }
  }


  // ============================================================
  // GET DISTANCE TEXT
  // ============================================================

  String getDistanceText(
      dynamic distance) {

    if (distance == null) {
      return "";
    }


    final double? value =
        double.tryParse(
      distance.toString(),
    );


    if (value == null) {
      return "";
    }


    return "${value.toStringAsFixed(1)} km away";
  }


  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {

    return Scaffold(

      backgroundColor:
          const Color(0xffF8FAFC),


      appBar: buildAppBar(),


      body: buildBody(),
    );
  }


  // ============================================================
  // APP BAR
  // ============================================================

  PreferredSizeWidget buildAppBar() {

    return AppBar(

      backgroundColor:
          Colors.white,

      elevation: 0,

      scrolledUnderElevation: 0,

      foregroundColor:
          Colors.black,


      centerTitle: false,


      title: const Text(

        "Notifications",

        style: TextStyle(

          fontSize: 22,

          fontWeight:
              FontWeight.w800,

          letterSpacing: -0.3,
        ),
      ),


      actions: [

        if (notifications.isNotEmpty)

          IconButton(

            tooltip:
                "Clear all",

            onPressed:
                deleteAllNotifications,

            icon: const Icon(
              Icons.delete_sweep_rounded,
            ),
          ),


        const SizedBox(
          width: 6,
        ),
      ],
    );
  }


  // ============================================================
  // BODY
  // ============================================================

  Widget buildBody() {

    if (loading) {

      return const Center(

        child:
            CircularProgressIndicator(),
      );
    }


    if (notifications.isEmpty) {

      return RefreshIndicator(

        onRefresh:
            refreshNotifications,

        child: ListView(

          physics:
              const AlwaysScrollableScrollPhysics(),

          children: [

            SizedBox(
              height:
                  MediaQuery.of(context).size.height *
                      0.25,
            ),

            emptyState(),
          ],
        ),
      );
    }


    return RefreshIndicator(

      onRefresh:
          refreshNotifications,

      color:
          const Color(0xff2563EB),


      child: ListView.builder(

        physics:
            const AlwaysScrollableScrollPhysics(),

        padding: const EdgeInsets.fromLTRB(
          16,
          16,
          16,
          30,
        ),


        itemCount:
            notifications.length,


        itemBuilder:
            (context, index) {

          return notificationCard(
            notifications[index],
            index,
          );
        },
      ),
    );
  }


  // ============================================================
  // NOTIFICATION CARD
  // ============================================================

  Widget notificationCard(
      Map<String, dynamic> data,
      int index) {


    final String type =
        data["type"]?.toString() ?? "";


    final String title =
        data["title"]?.toString() ??
        "New Notification";


    final String message =
        data["message"]?.toString() ??
        "You have a new notification.";


    final String date =
        formatDate(
          data["createdAt"],
        );


    final String distance =
        getDistanceText(
          data["distance"],
        );


    final Color color =
        notificationColor(type);


    final IconData icon =
        notificationIcon(type);


    final String notificationId =
        data["notificationId"]?.toString() ??
        index.toString();


    return Dismissible(

      key: ValueKey(
        notificationId,
      ),


      direction:
          DismissDirection.endToStart,


      confirmDismiss:
          (direction) async {

        return true;
      },


      onDismissed:
          (direction) {

        deleteNotification(
          notificationId,
        );
      },


      background: Container(

        margin:
            const EdgeInsets.only(
          bottom: 14,
        ),


        padding:
            const EdgeInsets.only(
          right: 25,
        ),


        alignment:
            Alignment.centerRight,


        decoration:
            BoxDecoration(

          color:
              const Color(0xffEF4444),

          borderRadius:
              BorderRadius.circular(22),
        ),


        child: const Icon(

          Icons.delete_outline_rounded,

          color:
              Colors.white,

          size: 28,
        ),
      ),


      child: Container(

        margin:
            const EdgeInsets.only(
          bottom: 14,
        ),


        padding:
            const EdgeInsets.all(16),


        decoration:
            BoxDecoration(

          color:
              Colors.white,


          borderRadius:
              BorderRadius.circular(22),


          border:
              Border.all(
            color:
                const Color(0xffE2E8F0),
          ),


          boxShadow: [

            BoxShadow(

              color:
                  Colors.black.withOpacity(0.04),

              blurRadius: 12,

              offset:
                  const Offset(0, 5),
            ),
          ],
        ),


        child: Column(

          crossAxisAlignment:
              CrossAxisAlignment.start,


          children: [

            // ==================================================
            // TOP ROW
            // ==================================================

            Row(

              crossAxisAlignment:
                  CrossAxisAlignment.start,


              children: [

                // ----------------------------------------------
                // ICON
                // ----------------------------------------------

                Container(

                  width: 54,

                  height: 54,


                  decoration:
                      BoxDecoration(

                    color:
                        color.withOpacity(0.12),

                    shape:
                        BoxShape.circle,
                  ),


                  child: Icon(

                    icon,

                    color:
                        color,

                    size: 28,
                  ),
                ),


                const SizedBox(
                  width: 13,
                ),


                // ----------------------------------------------
                // TITLE + DATE
                // ----------------------------------------------

                Expanded(

                  child: Column(

                    crossAxisAlignment:
                        CrossAxisAlignment.start,


                    children: [

                      Text(

                        title,

                        maxLines: 2,

                        overflow:
                            TextOverflow.ellipsis,


                        style:
                            const TextStyle(

                          fontSize: 16,

                          fontWeight:
                              FontWeight.w800,

                          color:
                              Color(0xff0F172A),
                        ),
                      ),


                      const SizedBox(
                        height: 5,
                      ),


                      if (date.isNotEmpty)

                        Text(

                          date,

                          style:
                              TextStyle(

                            fontSize: 12,

                            color:
                                Colors.grey.shade500,

                            fontWeight:
                                FontWeight.w500,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),


            const SizedBox(
              height: 14,
            ),


            // ==================================================
            // MESSAGE
            // ==================================================

            Container(

              width:
                  double.infinity,


              padding:
                  const EdgeInsets.all(13),


              decoration:
                  BoxDecoration(

                color:
                    const Color(0xffF8FAFC),

                borderRadius:
                    BorderRadius.circular(14),
              ),


              child: Text(

                message,

                style:
                    const TextStyle(

                  fontSize: 14,

                  height: 1.45,

                  color:
                      Color(0xff475569),

                  fontWeight:
                      FontWeight.w500,
                ),
              ),
            ),


            const SizedBox(
              height: 12,
            ),


            // ==================================================
            // BOTTOM INFORMATION
            // ==================================================

            Row(

              children: [

                // ----------------------------------------------
                // TYPE
                // ----------------------------------------------

                Container(

                  padding:
                      const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),


                  decoration:
                      BoxDecoration(

                    color:
                        color.withOpacity(0.10),

                    borderRadius:
                        BorderRadius.circular(20),
                  ),


                  child: Row(

                    mainAxisSize:
                        MainAxisSize.min,


                    children: [

                      Icon(

                        icon,

                        size: 14,

                        color:
                            color,
                      ),


                      const SizedBox(
                        width: 5,
                      ),


                      Text(

                        formatType(type),

                        style:
                            TextStyle(

                          color:
                              color,

                          fontSize: 10,

                          fontWeight:
                              FontWeight.w800,

                          letterSpacing:
                              0.3,
                        ),
                      ),
                    ],
                  ),
                ),


                const Spacer(),


                // ----------------------------------------------
                // DISTANCE
                // ----------------------------------------------

                if (distance.isNotEmpty)

                  Row(

                    mainAxisSize:
                        MainAxisSize.min,


                    children: [

                      Icon(

                        Icons.location_on_rounded,

                        size: 16,

                        color:
                            Colors.grey.shade500,
                      ),


                      const SizedBox(
                        width: 3,
                      ),


                      Text(

                        distance,

                        style:
                            TextStyle(

                          fontSize: 12,

                          color:
                              Colors.grey.shade600,

                          fontWeight:
                              FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
              ],
            ),


            // ==================================================
            // SERVICE ID
            // ==================================================

            if (data["serviceId"] != null &&
                data["serviceId"]
                    .toString()
                    .isNotEmpty)

              Padding(

                padding:
                    const EdgeInsets.only(
                  top: 10,
                ),


                child: Text(

                  "Service ID: ${data["serviceId"]}",

                  maxLines: 1,

                  overflow:
                      TextOverflow.ellipsis,


                  style:
                      TextStyle(

                    fontSize: 11,

                    color:
                        Colors.grey.shade400,

                    fontWeight:
                        FontWeight.w500,
                  ),
                ),
              ),
          ],
        ),
      ),
    )
        .animate()
        .fade(
          duration: 350.ms,
        )
        .slideY(
          begin: 0.08,
          end: 0,
          duration: 350.ms,
        );
  }


  // ============================================================
  // EMPTY STATE
  // ============================================================

  Widget emptyState() {

    return Padding(

      padding:
          const EdgeInsets.symmetric(
        horizontal: 30,
      ),


      child: Column(

        mainAxisAlignment:
            MainAxisAlignment.center,


        children: [

          // ====================================================
          // ICON
          // ====================================================

          Container(

            width: 140,

            height: 140,


            decoration:
                BoxDecoration(

              color:
                  const Color(0xffDBEAFE),

              shape:
                  BoxShape.circle,

              boxShadow: [

                BoxShadow(

                  color:
                      const Color(0xff2563EB)
                          .withOpacity(0.08),

                  blurRadius: 30,

                  spreadRadius: 5,
                ),
              ],
            ),


            child: const Icon(

              Icons.notifications_none_rounded,

              size: 72,

              color:
                  Color(0xff2563EB),
            ),
          )
              .animate()
              .scale(
                duration: 450.ms,
              ),


          const SizedBox(
            height: 28,
          ),


          // ====================================================
          // TITLE
          // ====================================================

          const Text(

            "No Notifications",

            textAlign:
                TextAlign.center,


            style:
                TextStyle(

              fontSize: 24,

              fontWeight:
                  FontWeight.w800,

              color:
                  Color(0xff0F172A),
            ),
          ),


          const SizedBox(
            height: 10,
          ),


          // ====================================================
          // DESCRIPTION
          // ====================================================

          Text(

            "New service requests and updates\n"
            "will appear here.",

            textAlign:
                TextAlign.center,


            style:
                TextStyle(

              color:
                  Colors.grey.shade600,

              fontSize: 14,

              height: 1.5,

              fontWeight:
                  FontWeight.w500,
            ),
          ),


          const SizedBox(
            height: 24,
          ),


          // ====================================================
          // REFRESH BUTTON
          // ====================================================

          OutlinedButton.icon(

            onPressed:
                refreshNotifications,


            icon: const Icon(
              Icons.refresh_rounded,
              size: 19,
            ),


            label: const Text(
              "Refresh",
            ),


            style:
                OutlinedButton.styleFrom(

              foregroundColor:
                  const Color(0xff2563EB),

              side:
                  const BorderSide(
                color:
                    Color(0xff2563EB),
              ),

              shape:
                  RoundedRectangleBorder(
                borderRadius:
                    BorderRadius.circular(14),
              ),

              padding:
                  const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
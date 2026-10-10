import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:servora/screens/chat_screen.dart';

class CustomerApplicationsScreen extends StatefulWidget {
  final String serviceId;

  const CustomerApplicationsScreen({
    super.key,
    required this.serviceId,
  });

  @override
  State<CustomerApplicationsScreen> createState() =>
      _CustomerApplicationsScreenState();
}

class _CustomerApplicationsScreenState
    extends State<CustomerApplicationsScreen> {

  // ============================================================
  // COLORS
  // ============================================================

  static const Color primaryBlue = Color(0xff2563EB);
  static const Color secondaryBlue = Color(0xff38BDF8);
  static const Color darkBlue = Color(0xff0F172A);
  static const Color background = Color(0xffF4F7FC);
  static const String notificationApi =
    "http://127.0.0.1:8080/api/notifications/worker-action";

  // ============================================================
  // FIREBASE REFERENCES
  // ============================================================

  final DatabaseReference servicesRef =
      FirebaseDatabase.instance.ref("services");

  final DatabaseReference applicationsRef =
      FirebaseDatabase.instance.ref("applications");

  final DatabaseReference workersRef =
      FirebaseDatabase.instance.ref("workers");

  // ============================================================
  // VARIABLES
  // ============================================================

  List<Map<String, dynamic>> applications = [];

  bool loading = true;
  bool updating = false;

  Map<String, dynamic> serviceData = {};

  StreamSubscription<DatabaseEvent>? serviceSubscription;
  StreamSubscription<DatabaseEvent>? applicationSubscription;

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();
    listenApplications();
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    serviceSubscription?.cancel();
    applicationSubscription?.cancel();
    super.dispose();
  }
  Future<void> notifyWorkerAboutAction({
  required String serviceId,
  required String customerId,
  required String workerId,
  required String title,
  required String message,
  required String type,
}) async {

  try {

    final response = await http.post(
      Uri.parse(notificationApi),

      headers: {
        "Content-Type": "application/json",
      },

      body: jsonEncode({
        "serviceId": serviceId,
        "customerId": customerId,
        "workerId": workerId,
        "title": title,
        "message": message,
        "type": type,
      }),
    );

    debugPrint(
      "======================================",
    );

    debugPrint(
      "WORKER NOTIFICATION RESPONSE",
    );

    debugPrint(
      "Status: ${response.statusCode}",
    );

    debugPrint(
      "Body: ${response.body}",
    );

    debugPrint(
      "======================================",
    );

  } catch (e) {

    debugPrint(
      "Worker notification error: $e",
    );
  }
}
  // ============================================================
  // LISTEN APPLICATIONS
  // ============================================================

  void listenApplications() {
    serviceSubscription?.cancel();
    applicationSubscription?.cancel();

    if (mounted) {
      setState(() {
        loading = true;
      });
    }

    serviceSubscription = servicesRef
        .child(widget.serviceId)
        .onValue
        .listen((serviceEvent) async {
      if (!mounted) return;

      try {
        if (!serviceEvent.snapshot.exists) {
          setState(() {
            applications = [];
            serviceData = {};
            loading = false;
          });

          return;
        }

        final rawService = serviceEvent.snapshot.value;

        if (rawService is! Map) {
          setState(() {
            applications = [];
            serviceData = {};
            loading = false;
          });

          return;
        }

        final Map<String, dynamic> data =
            Map<String, dynamic>.from(rawService);

        serviceData = data;

        final String urgency =
            data["urgency"]?.toString() ?? "normal";

        if (urgency == "urgent") {
          await loadUrgentApplications(data);
        } else {
          listenNormalApplications();
        }
      } catch (e) {
        debugPrint("Service Listener Error: $e");

        if (!mounted) return;

        setState(() {
          loading = false;
        });
      }
    });
  }

  // ============================================================
  // LOAD URGENT APPLICATIONS
  // ============================================================

  Future<void> loadUrgentApplications(
      Map<String, dynamic> serviceData) async {
    try {
      final DatabaseEvent event = await servicesRef
          .child(widget.serviceId)
          .child("applications")
          .once();

      List<Map<String, dynamic>> temp = [];

      if (event.snapshot.exists) {
        final rawData = event.snapshot.value;

        if (rawData is Map) {
          for (final entry in rawData.entries) {
            final String workerId = entry.key.toString();

            if (entry.value is! Map) {
              continue;
            }

            final app = Map<String, dynamic>.from(
              entry.value as Map,
            );

            temp.add({
              "applicationId": workerId,
              "workerId": workerId,
              ...app,
            });
          }
        }
      }

      temp.sort((a, b) {
        return b["createdAt"]
            .toString()
            .compareTo(
              a["createdAt"].toString(),
            );
      });

      if (!mounted) return;

      setState(() {
        applications = temp;
        loading = false;
      });
    } catch (e) {
      debugPrint("Urgent Applications Error: $e");

      if (!mounted) return;

      setState(() {
        applications = [];
        loading = false;
      });
    }
  }

  // ============================================================
  // NORMAL APPLICATION LISTENER
  // ============================================================

  void listenNormalApplications() {
    applicationSubscription?.cancel();

    applicationSubscription =
        applicationsRef.onValue.listen((event) {
      if (!mounted) return;

      try {
        if (!event.snapshot.exists) {
          setState(() {
            applications = [];
            loading = false;
          });

          return;
        }

        final rawData = event.snapshot.value;

        if (rawData is! Map) {
          setState(() {
            applications = [];
            loading = false;
          });

          return;
        }

        final Map data = Map.from(rawData);

        List<Map<String, dynamic>> temp = [];

        data.forEach((key, value) {
          if (value is! Map) {
            return;
          }

          final app = Map<String, dynamic>.from(value);

          if (app["serviceId"]?.toString() ==
              widget.serviceId) {
            temp.add({
              "applicationId": key.toString(),
              ...app,
            });
          }
        });

        temp.sort((a, b) {
          return b["createdAt"]
              .toString()
              .compareTo(
                a["createdAt"].toString(),
              );
        });

        setState(() {
          applications = temp;
          loading = false;
        });
      } catch (e) {
        debugPrint(
          "Normal Application Listener Error: $e",
        );

        setState(() {
          loading = false;
        });
      }
    });
  }

  // ============================================================
  // GET SERVICE DATA
  // ============================================================

  Future<Map<String, dynamic>?> getServiceData() async {
    try {
      final DatabaseEvent event = await servicesRef
          .child(widget.serviceId)
          .once();

      if (!event.snapshot.exists) {
        return null;
      }

      final value = event.snapshot.value;

      if (value is! Map) {
        return null;
      }

      return Map<String, dynamic>.from(value);
    } catch (e) {
      debugPrint("Service Fetch Error: $e");
      return null;
    }
  }

  // ============================================================
  // GET WORKER DATA
  // ============================================================

  Future<Map<String, dynamic>?> getWorkerData(
      String uid) async {
    try {
      DatabaseEvent event =
          await workersRef.child(uid).once();

      if (event.snapshot.exists &&
          event.snapshot.value is Map) {
        return Map<String, dynamic>.from(
          event.snapshot.value as Map,
        );
      }

      event = await FirebaseDatabase.instance
          .ref("users")
          .child(uid)
          .once();

      if (event.snapshot.exists &&
          event.snapshot.value is Map) {
        return Map<String, dynamic>.from(
          event.snapshot.value as Map,
        );
      }

      return null;
    } catch (e) {
      debugPrint("Worker Fetch Error: $e");
      return null;
    }
  }

  // ============================================================
  // CALL WORKER
  // ============================================================

  Future<void> callWorker(String phone) async {
    try {
      final String number =
          phone.replaceAll(" ", "");

      if (number.isEmpty) {
        showMessage(
          "Worker phone number not available",
        );
        return;
      }

      final Uri uri = Uri.parse("tel:$number");

      await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
    } catch (e) {
      showMessage("Unable to call worker");
    }
  }

  // ============================================================
  // ACCEPT URGENT OFFER
  // ============================================================

  Future<void> acceptUrgentOffer(
      Map<String, dynamic> application) async {
    if (updating) return;

    setState(() {
      updating = true;
    });

    try {
      final String workerId =
          application["workerId"]?.toString() ?? "";

      if (workerId.isEmpty) {
        throw Exception("Worker ID is missing.");
      }

      final DatabaseEvent serviceEvent =
          await servicesRef
              .child(widget.serviceId)
              .once();

      if (!serviceEvent.snapshot.exists) {
        throw Exception(
          "Service no longer exists.",
        );
      }

      final service = Map<String, dynamic>.from(
        serviceEvent.snapshot.value as Map,
      );

      if (service["bookingLocked"] == true ||
          service["status"] == "assigned") {
        showMessage(
          "This service has already been assigned.",
        );
        return;
      }

      final double urgentFee =
          double.tryParse(
                "${application["urgentServiceFee"] ?? service["emergencyCharge"] ?? 199}",
              ) ??
              199;

      final double workerCharge =
          double.tryParse(
                "${application["workerServiceCharge"] ?? 0}",
              ) ??
              0;

      final double finalPrice =
          double.tryParse(
                "${application["finalPrice"] ?? (urgentFee + workerCharge)}",
              ) ??
              (urgentFee + workerCharge);

      await servicesRef
          .child(widget.serviceId)
          .child("applications")
          .child(workerId)
          .update({
        "status": "accepted",
        "acceptedAt":
            DateTime.now().toIso8601String(),
        "finalPrice": finalPrice,
      });

      await servicesRef
          .child(widget.serviceId)
          .update({
        "status": "assigned",
        "bookingLocked": true,
        "assignedWorkerId": workerId,
        "acceptedApplicationId": workerId,
        "finalPrice": finalPrice,
        "urgentServiceFee": urgentFee,
        "workerServiceCharge": workerCharge,
        "assignedAt":
            DateTime.now().toIso8601String(),
      });

      final DatabaseEvent allApplications =
          await servicesRef
              .child(widget.serviceId)
              .child("applications")
              .once();

      if (allApplications.snapshot.exists) {
        final raw = allApplications.snapshot.value;

        if (raw is Map) {
          for (final entry in raw.entries) {
            final String otherWorkerId =
                entry.key.toString();

            if (otherWorkerId == workerId) {
              continue;
            }

            await servicesRef
                .child(widget.serviceId)
                .child("applications")
                .child(otherWorkerId)
                .update({
              "status": "rejected",
            });
          }
        }
      }

      final currentUser =
          FirebaseAuth.instance.currentUser;

     if (currentUser != null) {

  await notifyWorkerAboutAction(
    serviceId: widget.serviceId,
    customerId: currentUser.uid,
    workerId: workerId,
    title: "Urgent Offer Accepted",
    message:
        "Your urgent service offer has been accepted. Final amount ₹${finalPrice.toStringAsFixed(0)}.",
    type: "urgent_offer_accepted",
  );
}

      showMessage(
        "Urgent service accepted. Worker assigned successfully.",
      );
    } catch (e) {
      debugPrint(
        "Accept urgent offer error: $e",
      );

      showMessage(
        "Failed to accept offer: $e",
      );
    } finally {
      if (mounted) {
        setState(() {
          updating = false;
        });
      }
    }
  }

  // ============================================================
  // ACCEPT NORMAL WORKER
  // ============================================================

  Future<void> acceptNormalWorker(
      Map<String, dynamic> application) async {
    if (updating) return;

    setState(() {
      updating = true;
    });

    try {
      final String applicationId =
          application["applicationId"]?.toString() ?? "";

      final String workerId =
          application["workerId"]?.toString() ?? "";

      if (applicationId.isEmpty ||
          workerId.isEmpty) {
        throw Exception(
          "Application information is missing.",
        );
      }

      final DatabaseEvent serviceEvent =
          await servicesRef
              .child(widget.serviceId)
              .once();

      if (!serviceEvent.snapshot.exists) {
        throw Exception(
          "Service does not exist.",
        );
      }

      final service = Map<String, dynamic>.from(
        serviceEvent.snapshot.value as Map,
      );

      if (service["bookingLocked"] == true ||
          service["status"] == "assigned") {
        showMessage(
          "Service already assigned.",
        );
        return;
      }

      final double price =
          double.tryParse(
                "${application["currentOffer"] ?? application["workerPrice"] ?? 0}",
              ) ??
              0;

      await applicationsRef
          .child(applicationId)
          .update({
        "status": "accepted",
        "finalPrice": price,
        "acceptedAt":
            DateTime.now().toIso8601String(),
      });

      await servicesRef
          .child(widget.serviceId)
          .update({
        "status": "assigned",
        "bookingLocked": true,
        "assignedWorkerId": workerId,
        "acceptedApplicationId": applicationId,
        "finalPrice": price,
        "assignedAt":
            DateTime.now().toIso8601String(),
      });

      final DatabaseEvent all =
          await applicationsRef.once();

      if (all.snapshot.exists) {
        final raw = all.snapshot.value;

        if (raw is Map) {
          for (final entry in raw.entries) {
            final String otherApplicationId =
                entry.key.toString();

            if (otherApplicationId ==
                applicationId) {
              continue;
            }

            if (entry.value is! Map) {
              continue;
            }

            final other =
                Map<String, dynamic>.from(
              entry.value as Map,
            );

            if (other["serviceId"]?.toString() ==
                widget.serviceId) {
              await applicationsRef
                  .child(otherApplicationId)
                  .update({
                "status": "rejected",
              });
            }
          }
        }
      }

      final currentUser =
          FirebaseAuth.instance.currentUser;

     if (currentUser != null) {

  await notifyWorkerAboutAction(
    serviceId: widget.serviceId,
    customerId: currentUser.uid,
    workerId: workerId,
    title: "Offer Accepted",
    message:
        "The customer accepted your offer. You can start the work.",
    type: "worker_offer_accepted",
  );
}

      showMessage(
        "Worker assigned successfully.",
      );
    } catch (e) {
      debugPrint(
        "Normal Accept Error: $e",
      );

      showMessage(
        "Failed to accept worker: $e",
      );
    } finally {
      if (mounted) {
        setState(() {
          updating = false;
        });
      }
    }
  }

  // ============================================================
  // REJECT NORMAL WORKER
  // ============================================================

 Future<void> rejectNormalWorker(
    Map<String, dynamic> application) async {

  try {

    final String applicationId =
        application["applicationId"]?.toString() ?? "";

    final String workerId =
        application["workerId"]?.toString() ?? "";

    final currentUser =
        FirebaseAuth.instance.currentUser;

    if (applicationId.isEmpty) {
      showMessage("Application ID missing.");
      return;
    }

    if (workerId.isEmpty) {
      showMessage("Worker ID missing.");
      return;
    }

    await applicationsRef
        .child(applicationId)
        .update({
      "status": "rejected",
    });

    if (currentUser != null) {

      await notifyWorkerAboutAction(
        serviceId: widget.serviceId,
        customerId: currentUser.uid,
        workerId: workerId,
        title: "Offer Rejected",
        message:
            "The customer rejected your offer for this service.",
        type: "worker_offer_rejected",
      );
    }

    showMessage("Offer rejected.");

  } catch (e) {

    debugPrint(
      "Reject worker error: $e",
    );

    showMessage(
      "Failed to reject offer",
    );
  }
}
  // ============================================================
  // OPEN CHAT
  // ============================================================

  Future<void> openChat(
    Map<String, dynamic> data) async {

  final String workerId =
      data["workerId"]?.toString() ?? "";

  final currentUser =
      FirebaseAuth.instance.currentUser;

  if (workerId.isEmpty) {
    showMessage("Worker ID missing.");
    return;
  }

  if (currentUser != null) {

    await notifyWorkerAboutAction(
      serviceId: widget.serviceId,
      customerId: currentUser.uid,
      workerId: workerId,
      title: "New Chat Message",
      message:
          "The customer opened the chat for your service.",
      type: "customer_chat_opened",
    );
  }

  if (!mounted) return;

  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => ChatScreen(
        serviceId: widget.serviceId,
        customerId:
            data["customerId"] ?? "",
        workerId:
            data["workerId"] ?? "",
        applicationId:
            data["applicationId"] ?? "",
      ),
    ),
  );
}
  // ============================================================
  // SNACKBAR
  // ============================================================

  void showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
        .showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(
              Icons.info_outline_rounded,
              color: Colors.white,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(message),
            ),
          ],
        ),
        behavior:
            SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
          borderRadius:
              BorderRadius.circular(16),
        ),
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final bool isUrgent =
        serviceData["urgency"]?.toString() ==
            "urgent";

    final int pendingCount =
        applications.where((item) {
      final status =
          item["status"]?.toString() ?? "pending";

      return status == "pending";
    }).length;

    return Scaffold(
      backgroundColor: background,

      body: RefreshIndicator(
        color: primaryBlue,
        onRefresh: () async {
          listenApplications();

          await Future.delayed(
            const Duration(milliseconds: 700),
          );
        },

        child: CustomScrollView(
          physics:
              const AlwaysScrollableScrollPhysics(),

          slivers: [

            // ==================================================
            // PREMIUM HEADER
            // ==================================================

           SliverAppBar(
  expandedHeight: 245,
  pinned: true,
  elevation: 0,
  backgroundColor: primaryBlue,
  foregroundColor: Colors.white,

  leading: Padding(
    padding: const EdgeInsets.all(8),
    child: _headerIconButton(
      icon: Icons.arrow_back_rounded,
      onTap: () {
        Navigator.pop(context);
      },
    ),
  ),

  flexibleSpace: FlexibleSpaceBar(
    background: _premiumHeader(
      isUrgent,
      pendingCount,
    ),
  ),
),
            // ==================================================
            // CONTENT
            // ==================================================

            if (loading)
              SliverToBoxAdapter(
                child:
                    _loadingContent(),
              )
            else if (applications.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child:
                    emptyApplications(),
              )
            else ...[
              SliverToBoxAdapter(
                child:
                    _serviceSummary(isUrgent),
              ),

              SliverPadding(
                padding:
                    const EdgeInsets.fromLTRB(
                  18,
                  0,
                  18,
                  30,
                ),

                sliver:
                    SliverList(
                  delegate:
                      SliverChildBuilderDelegate(
                    (context, index) {
                      return applicationCard(
                        applications[index],
                        index,
                      );
                    },
                    childCount:
                        applications.length,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ============================================================
  // PREMIUM HEADER
  // ============================================================

  Widget _premiumHeader(
    bool isUrgent,
    int pendingCount,
  ) {
    return Container(
      decoration:
          const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xff0F3FAE),
            Color(0xff2563EB),
            Color(0xff38BDF8),
          ],
        ),
      ),

      child: Stack(
        children: [

          // -----------------------------------------------
          // GLOW CIRCLES
          // -----------------------------------------------

          Positioned(
            top: -60,
            right: -45,
            child: _glowCircle(
              size: 180,
            ),
          ),

          Positioned(
            bottom: -80,
            left: -60,
            child: _glowCircle(
              size: 190,
            ),
          ),

          // -----------------------------------------------
          // MAIN CONTENT
          // -----------------------------------------------

          SafeArea(
  bottom: false,
  child: Padding(
    padding: const EdgeInsets.fromLTRB(
      22,
      12,
      22,
      10,
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // TOP ROW
        Row(
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Worker Offers",
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 25,
                      fontWeight: FontWeight.w800,
                    ),
                  ),

                  const SizedBox(height: 3),

                  Text(
                    "Review and choose the right worker",
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withOpacity(.78),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 10),

            // Refresh button
            Material(
              color: Colors.white.withOpacity(.14),
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: loading ? null : listenApplications,
                child: const SizedBox(
                  width: 42,
                  height: 42,
                  child: Icon(
                    Icons.refresh_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
              ),
            ),
          
          ],
        ),

        const SizedBox(height: 10),

        // SERVICE ID
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 6,
          ),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(.12),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: Colors.white.withOpacity(.16),
            ),
          ),
          child: Text(
            "SERVICE #${widget.serviceId.length > 10 ? widget.serviceId.substring(0, 10) : widget.serviceId}",
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: .6,
            ),
          ),
        ),

        const SizedBox(height: 10),

        // COMPACT STATS
        Row(
          children: [
            Expanded(
              child: _headerStat(
                icon: Icons.people_alt_rounded,
                value: "${applications.length}",
                title: "Offers",
              ),
            ),

            const SizedBox(width: 8),

            Expanded(
              child: _headerStat(
                icon: Icons.pending_actions_rounded,
                value:
                    "${applications.where((e) => (e["status"] ?? "pending") == "pending").length}",
                title: "Pending",
              ),
            ),

            const SizedBox(width: 8),

            Expanded(
              child: _headerStat(
                icon: Icons.check_circle_rounded,
                value:
                    "${applications.where((e) => (e["status"] ?? "") == "accepted").length}",
                title: "Accepted",
              ),
            ),
          ],
        ),
      ],
    ),
  ),
)

        ],
      ),
    )
        .animate()
        .fade(
          duration: 450.ms,
        );
  }

  // ============================================================
  // GLOW CIRCLE
  // ============================================================

  Widget _glowCircle({
    required double size,
  }) {
    return Container(
      height: size,
      width: size,
      decoration:
          BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white
            .withOpacity(0.07),
      ),
    );
  }

  // ============================================================
  // HEADER BUTTON
  // ============================================================

  Widget _headerIconButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white
          .withOpacity(0.14),
      borderRadius:
          BorderRadius.circular(15),

      child: InkWell(
        onTap: onTap,
        borderRadius:
            BorderRadius.circular(15),

        child: Container(
          height: 45,
          width: 45,

          decoration:
              BoxDecoration(
            borderRadius:
                BorderRadius.circular(15),
            border: Border.all(
              color: Colors.white
                  .withOpacity(0.20),
            ),
          ),

          child: Icon(
            icon,
            size: 21,
          ),
        ),
      ),
    );
  }

  // ============================================================
  // FLOATING HEADER ICON
  // ============================================================

  Widget _floatingHeaderIcon(
      IconData icon) {
    return Container(
      height: 62,
      width: 62,

      decoration:
          BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white
            .withOpacity(0.15),

        border: Border.all(
          color: Colors.white
              .withOpacity(0.25),
        ),

        boxShadow: [
          BoxShadow(
            color: Colors.black
                .withOpacity(0.12),
            blurRadius: 20,
            offset:
                const Offset(0, 8),
          ),
        ],
      ),

      child: Icon(
        icon,
        color: Colors.white,
        size: 30,
      ),
    )
        .animate(
          onPlay: (controller) =>
              controller.repeat(
            reverse: true,
          ),
        )
        .scale(
          begin:
              const Offset(0.95, 0.95),
          end:
              const Offset(1.05, 1.05),
          duration: 1500.ms,
          curve:
              Curves.easeInOut,
        );
  }

  // ============================================================
  // HEADER STAT
  // ============================================================

  Widget _headerStat({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Container(
      height: 68,

      padding:
          const EdgeInsets.symmetric(
        horizontal: 11,
        vertical: 9,
      ),

      decoration:
          BoxDecoration(
        color: Colors.white
            .withOpacity(0.13),

        borderRadius:
            BorderRadius.circular(18),

        border: Border.all(
          color: Colors.white
              .withOpacity(0.16),
        ),
      ),

      child: Row(
        children: [

          Container(
            height: 36,
            width: 36,

            decoration:
                BoxDecoration(
              color: Colors.white
                  .withOpacity(0.16),
              borderRadius:
                  BorderRadius.circular(11),
            ),

            child: Icon(
              icon,
              color: Colors.white,
              size: 19,
            ),
          ),

          const SizedBox(
            width: 7,
          ),

          Expanded(
            child: Column(
              mainAxisAlignment:
                  MainAxisAlignment.center,
              crossAxisAlignment:
                  CrossAxisAlignment.start,

              children: [

                Text(
                  title,
                  maxLines: 1,
                  overflow:
                      TextOverflow.ellipsis,

                  style:
                      const TextStyle(
                    color:
                        Colors.white70,
                    fontSize: 8,
                    fontWeight:
                        FontWeight.w800,
                    letterSpacing:
                        .7,
                  ),
                ),

                const SizedBox(
                  height: 2,
                ),

                Text(
                  value,
                  maxLines: 1,
                  overflow:
                      TextOverflow.ellipsis,

                  style:
                      const TextStyle(
                    color:
                        Colors.white,
                    fontSize: 14,
                    fontWeight:
                        FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // SERVICE SUMMARY
  // ============================================================

  Widget _serviceSummary(
      bool isUrgent) {
    final String serviceName =
        serviceData["serviceName"]
                ?.toString() ??
            "Service Request";

    final String location =
        serviceData["location"]
                ?.toString() ??
            "";

    final String status =
        serviceData["status"]
                ?.toString() ??
            "pending";

    return Padding(
      padding:
          const EdgeInsets.fromLTRB(
        18,
        18,
        18,
        15,
      ),

      child: Container(
        padding:
            const EdgeInsets.all(17),

        decoration:
            BoxDecoration(
          color: Colors.white,
          borderRadius:
              BorderRadius.circular(23),

          border: Border.all(
            color:
                const Color(0xffE6ECF5),
          ),

          boxShadow: [
            BoxShadow(
              color: Colors.black
                  .withOpacity(0.055),
              blurRadius: 18,
              offset:
                  const Offset(0, 8),
            ),
          ],
        ),

        child: Row(
          children: [

            Container(
              height: 52,
              width: 52,

              decoration:
                  BoxDecoration(
                gradient:
                    LinearGradient(
                  colors: isUrgent
                      ? const [
                          Color(0xffF97316),
                          Color(0xffEF4444),
                        ]
                      : const [
                          primaryBlue,
                          secondaryBlue,
                        ],
                ),

                borderRadius:
                    BorderRadius.circular(
                  16,
                ),

                boxShadow: [
                  BoxShadow(
                    color: (isUrgent
                            ? Colors.red
                            : primaryBlue)
                        .withOpacity(.20),
                    blurRadius: 10,
                    offset:
                        const Offset(0, 5),
                  ),
                ],
              ),

              child: Icon(
                isUrgent
                    ? Icons.flash_on_rounded
                    : Icons.handyman_rounded,
                color: Colors.white,
                size: 26,
              ),
            ),

            const SizedBox(
              width: 13,
            ),

            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,

                children: [

                  Text(
                    serviceName,
                    maxLines: 1,
                    overflow:
                        TextOverflow.ellipsis,

                    style:
                        const TextStyle(
                      color: darkBlue,
                      fontSize: 16,
                      fontWeight:
                          FontWeight.w900,
                    ),
                  ),

                  const SizedBox(
                    height: 5,
                  ),

                  if (location.isNotEmpty)
                    Row(
                      children: [
                        const Icon(
                          Icons
                              .location_on_outlined,
                          size: 14,
                          color:
                              Colors.grey,
                        ),
                        const SizedBox(
                          width: 3,
                        ),
                        Expanded(
                          child: Text(
                            location,
                            maxLines: 1,
                            overflow:
                                TextOverflow
                                    .ellipsis,
                            style:
                                const TextStyle(
                              color:
                                  Colors.grey,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),

            _statusPill(status),
          ],
        ),
      ),
    )
        .animate()
        .fade(
          duration: 450.ms,
        )
        .slideY(
          begin: .08,
          end: 0,
          duration: 500.ms,
        );
  }

  // ============================================================
  // STATUS PILL
  // ============================================================

  Widget _statusPill(String status) {
    Color color;

    switch (status) {
      case "assigned":
        color = const Color(0xff16A34A);
        break;

      case "completed":
        color = const Color(0xff2563EB);
        break;

      case "cancelled":
        color = const Color(0xffDC2626);
        break;

      default:
        color = const Color(0xffF59E0B);
    }

    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 6,
      ),

      decoration:
          BoxDecoration(
        color: color.withOpacity(.10),
        borderRadius:
            BorderRadius.circular(20),
      ),

      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight:
              FontWeight.w900,
        ),
      ),
    );
  }

  // ============================================================
  // LOADING
  // ============================================================

  Widget _loadingContent() {
    return Padding(
      padding:
          const EdgeInsets.all(18),

      child: Column(
        children: List.generate(
          3,
          (index) {
            return Container(
              margin:
                  const EdgeInsets.only(
                bottom: 18,
              ),

              height: 250,

              decoration:
                  BoxDecoration(
                color:
                    Colors.white,
                borderRadius:
                    BorderRadius.circular(
                  26,
                ),
              ),
            )
                .animate(
                  onPlay: (controller) =>
                      controller.repeat(),
                )
                .shimmer(
                  duration: 1200.ms,
                );
          },
        ),
      ),
    );
  }

  // ============================================================
  // APPLICATION CARD
  // ============================================================

  Widget applicationCard(
      Map<String, dynamic> data,
      int index) {

    final String status =
        data["status"]?.toString() ??
            "pending";

    final bool isUrgent =
        serviceData["urgency"]?.toString() ==
            "urgent";

    if (isUrgent) {
      return urgentApplicationCard(
        data,
        status,
        index,
      );
    }

    return normalApplicationCard(
      data,
      status,
      index,
    );
  }

  // ============================================================
  // URGENT APPLICATION CARD
  // ============================================================

  Widget urgentApplicationCard(
      Map<String, dynamic> data,
      String status,
      int index) {

    final double urgentFee =
        double.tryParse(
              "${data["urgentServiceFee"] ?? serviceData["urgentServiceFee"] ?? serviceData["emergencyCharge"] ?? 199}",
            ) ??
            199;

    final double workerCharge =
        double.tryParse(
              "${data["workerServiceCharge"] ?? 0}",
            ) ??
            0;

    final double total =
        double.tryParse(
              "${data["finalPrice"] ?? (urgentFee + workerCharge)}",
            ) ??
            (urgentFee + workerCharge);

    return Container(
      margin:
          const EdgeInsets.only(
        bottom: 20,
      ),

      decoration:
          BoxDecoration(
        borderRadius:
            BorderRadius.circular(28),

        gradient:
            const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xffFFF7ED),
            Colors.white,
            Color(0xffFEF2F2),
          ],
        ),

        border: Border.all(
          color:
              const Color(0xffFED7AA),
        ),

        boxShadow: [
          BoxShadow(
            color: Colors.red
                .withOpacity(.08),
            blurRadius: 25,
            offset:
                const Offset(0, 10),
          ),
        ],
      ),

      child: Padding(
        padding:
            const EdgeInsets.all(18),

        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,

          children: [

            // =================================================
            // URGENT HEADER
            // =================================================

            Row(
              children: [

                Container(
                  height: 58,
                  width: 58,

                  decoration:
                      BoxDecoration(
                    gradient:
                        const LinearGradient(
                      colors: [
                        Color(0xffEF4444),
                        Color(0xffF97316),
                      ],
                    ),

                    borderRadius:
                        BorderRadius.circular(
                      18,
                    ),

                    boxShadow: [
                      BoxShadow(
                        color: Colors.red
                            .withOpacity(.22),
                        blurRadius: 13,
                        offset:
                            const Offset(0, 7),
                      ),
                    ],
                  ),

                  child: const Icon(
                    Icons
                        .priority_high_rounded,
                    color:
                        Colors.white,
                    size: 31,
                  ),
                ),

                const SizedBox(
                  width: 13,
                ),

                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,

                    children: [

                      Row(
                        children: [
                          const Text(
                            "URGENT OFFER",
                            style:
                                TextStyle(
                              color:
                                  Color(0xffDC2626),
                              fontSize: 10,
                              fontWeight:
                                  FontWeight.w900,
                              letterSpacing:
                                  1.1,
                            ),
                          ),

                          const SizedBox(
                            width: 7,
                          ),

                          urgentBadge(),
                        ],
                      ),

                      const SizedBox(
                        height: 5,
                      ),

                      Text(
                        data["serviceName"]
                                ?.toString() ??
                            serviceData[
                                    "serviceName"]
                                ?.toString() ??
                            "Urgent Service",
                        maxLines: 1,
                        overflow:
                            TextOverflow.ellipsis,
                        style:
                            const TextStyle(
                          fontSize: 19,
                          fontWeight:
                              FontWeight.w900,
                          color: darkBlue,
                        ),
                      ),
                    ],
                  ),
                ),
              ],

            ),

            const SizedBox(
              height: 17,
            ),

            workerProfile(
              data,
              showCall: true,
            ),

            const SizedBox(
              height: 16,
            ),

            urgentPriceCard(
              urgentFee:
                  urgentFee,
              workerCharge:
                  workerCharge,
              total:
                  total,
            ),

            const SizedBox(
              height: 14,
            ),

            _urgentInfoStrip(),

            const SizedBox(
              height: 17,
            ),

            if (status == "accepted")
              acceptedUrgentCard(total)
            else if (status == "rejected")
              rejectedUrgentCard()
            else
              urgentAcceptButton(
                data,
                total,
              ),
          ],
        ),
      ),
    )
        .animate(
          delay: Duration(
            milliseconds: index * 100,
          ),
        )
        .fade(
          duration: 500.ms,
        )
        .slideY(
          begin: .12,
          end: 0,
          duration: 550.ms,
          curve: Curves.easeOutBack,
        )
        .scale(
          begin:
              const Offset(.97, .97),
          end:
              const Offset(1, 1),
          duration: 500.ms,
        );
  }

  // ============================================================
  // URGENT INFO STRIP
  // ============================================================

  Widget _urgentInfoStrip() {
    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.all(13),

      decoration:
          BoxDecoration(
        color:
            const Color(0xffFFF7ED),
        borderRadius:
            BorderRadius.circular(17),
        border: Border.all(
          color:
              const Color(0xffFED7AA),
        ),
      ),

      child: const Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [

          Icon(
            Icons.flash_on_rounded,
            color:
                Color(0xffEA580C),
            size: 21,
          ),

          SizedBox(
            width: 9,
          ),

          Expanded(
            child: Text(
              "Urgent service offers use a fixed worker charge. No price negotiation is required.",
              style: TextStyle(
                color:
                    Color(0xff7C2D12),
                fontSize: 12,
                height: 1.35,
                fontWeight:
                    FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // URGENT PRICE CARD
  // ============================================================

  Widget urgentPriceCard({
    required double urgentFee,
    required double workerCharge,
    required double total,
  }) {
    return Container(
      width: double.infinity,

      padding:
          const EdgeInsets.all(17),

      decoration:
          BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(20),

        border: Border.all(
          color:
              const Color(0xffE8EDF5),
        ),

        boxShadow: [
          BoxShadow(
            color: Colors.black
                .withOpacity(.035),
            blurRadius: 12,
            offset:
                const Offset(0, 5),
          ),
        ],
      ),

      child: Column(
        children: [

          priceRow(
            "Urgent Service Fee",
            urgentFee,
            const Color(0xffF97316),
          ),

          const SizedBox(
            height: 12,
          ),

          priceRow(
            "Worker Service Charge",
            workerCharge,
            primaryBlue,
          ),

          Padding(
            padding:
                const EdgeInsets.symmetric(
              vertical: 12,
            ),
            child:
                Divider(
              color:
                  Colors.grey.shade200,
            ),
          ),

          Row(
            mainAxisAlignment:
                MainAxisAlignment.spaceBetween,

            children: [

              const Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    "FINAL AMOUNT",
                    style:
                        TextStyle(
                      color:
                          Colors.grey,
                      fontSize: 9,
                      fontWeight:
                          FontWeight.w800,
                      letterSpacing:
                          1,
                    ),
                  ),
                  SizedBox(
                    height: 3,
                  ),
                  Text(
                    "Total Offer",
                    style:
                        TextStyle(
                      fontSize: 15,
                      fontWeight:
                          FontWeight.w800,
                    ),
                  ),
                ],
              ),

              Text(
                "₹${total.toStringAsFixed(0)}",
                style:
                    const TextStyle(
                  fontSize: 25,
                  fontWeight:
                      FontWeight.w900,
                  color:
                      Color(0xff16A34A),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ============================================================
  // PRICE ROW
  // ============================================================

  Widget priceRow(
      String title,
      double amount,
      Color color) {
    return Row(
      mainAxisAlignment:
          MainAxisAlignment.spaceBetween,

      children: [

        Row(
          children: [

            Container(
              height: 31,
              width: 31,

              decoration:
                  BoxDecoration(
                color:
                    color.withOpacity(.10),
                borderRadius:
                    BorderRadius.circular(10),
              ),

              child: Icon(
                Icons.currency_rupee_rounded,
                size: 16,
                color: color,
              ),
            ),

            const SizedBox(
              width: 9,
            ),

            Text(
              title,
              style:
                  const TextStyle(
                fontSize: 13,
                fontWeight:
                    FontWeight.w700,
                color:
                    Color(0xff374151),
              ),
            ),
          ],
        ),

        Text(
          "₹${amount.toStringAsFixed(0)}",
          style:
              TextStyle(
            fontSize: 15,
            fontWeight:
                FontWeight.w900,
            color: color,
          ),
        ),
      ],
    );
  }

  // ============================================================
  // URGENT ACCEPT BUTTON
  // ============================================================

  Widget urgentAcceptButton(
      Map<String, dynamic> data,
      double total) {
    return _premium3DButton(
      icon:
          Icons.check_circle_rounded,
      label:
          "Accept Offer • ₹${total.toStringAsFixed(0)}",
      color:
          const Color(0xff16A34A),
      lightColor:
          const Color(0xffDCFCE7),
      isLoading:
          updating,
      onTap: updating
          ? null
          : () {
              showUrgentAcceptDialog(
                data,
                total,
              );
            },
    );
  }

  // ============================================================
  // URGENT ACCEPT DIALOG
  // ============================================================

  void showUrgentAcceptDialog(
      Map<String, dynamic> data,
      double total) {
    showDialog(
      context: context,
      barrierDismissible: false,

      builder: (context) {
        return Dialog(
          backgroundColor:
              Colors.transparent,

          child: Container(
            padding:
                const EdgeInsets.all(22),

            decoration:
                BoxDecoration(
              color: Colors.white,
              borderRadius:
                  BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: Colors.black
                      .withOpacity(.20),
                  blurRadius: 30,
                  offset:
                      const Offset(0, 14),
                ),
              ],
            ),

            child: Column(
              mainAxisSize:
                  MainAxisSize.min,

              children: [

                Container(
                  height: 72,
                  width: 72,

                  decoration:
                      BoxDecoration(
                    gradient:
                        const LinearGradient(
                      colors: [
                        Color(0xffEF4444),
                        Color(0xffF97316),
                      ],
                    ),
                    shape:
                        BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.red
                            .withOpacity(.22),
                        blurRadius: 15,
                        offset:
                            const Offset(
                          0,
                          7,
                        ),
                      ),
                    ],
                  ),

                  child: const Icon(
                    Icons.flash_on_rounded,
                    color:
                        Colors.white,
                    size: 36,
                  ),
                ),

                const SizedBox(
                  height: 16,
                ),

                const Text(
                  "Accept Urgent Offer?",
                  textAlign:
                      TextAlign.center,
                  style:
                      TextStyle(
                    fontSize: 21,
                    fontWeight:
                        FontWeight.w900,
                    color: darkBlue,
                  ),
                ),

                const SizedBox(
                  height: 8,
                ),

                const Text(
                  "The worker will be assigned immediately after confirmation.",
                  textAlign:
                      TextAlign.center,
                  style:
                      TextStyle(
                    color: Colors.grey,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),

                const SizedBox(
                  height: 18,
                ),

                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.all(16),

                  decoration:
                      BoxDecoration(
                    color:
                        const Color(0xffF0FDF4),
                    borderRadius:
                        BorderRadius.circular(18),
                    border: Border.all(
                      color:
                          const Color(0xffBBF7D0),
                    ),
                  ),

                  child: Column(
                    children: [

                      const Text(
                        "FINAL AMOUNT",
                        style:
                            TextStyle(
                          color:
                              Color(0xff15803D),
                          fontSize: 10,
                          fontWeight:
                              FontWeight.w800,
                          letterSpacing:
                              1.1,
                        ),
                      ),

                      const SizedBox(
                        height: 5,
                      ),

                      Text(
                        "₹${total.toStringAsFixed(0)}",
                        style:
                            const TextStyle(
                          color:
                              Color(0xff16A34A),
                          fontSize: 28,
                          fontWeight:
                              FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(
                  height: 18,
                ),

                Row(
                  children: [

                    Expanded(
                      child:
                          _dialogButton(
                        label:
                            "Cancel",
                        color:
                            Colors.grey,
                        filled:
                            false,
                        onTap: () {
                          Navigator.pop(
                            context,
                          );
                        },
                      ),
                    ),

                    const SizedBox(
                      width: 10,
                    ),

                    Expanded(
                      child:
                          _dialogButton(
                        label:
                            "Accept",
                        color:
                            const Color(
                          0xff16A34A,
                        ),
                        filled:
                            true,
                        onTap: () {
                          Navigator.pop(
                            context,
                          );

                          acceptUrgentOffer(
                            data,
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ============================================================
  // DIALOG BUTTON
  // ============================================================

  Widget _dialogButton({
    required String label,
    required Color color,
    required bool filled,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      height: 50,

      child: ElevatedButton(
        onPressed: onTap,

        style:
            ElevatedButton.styleFrom(
          elevation:
              filled ? 5 : 0,

          backgroundColor:
              filled
                  ? color
                  : Colors.white,

          foregroundColor:
              filled
                  ? Colors.white
                  : color,

          side: BorderSide(
            color:
                color,
          ),

          shape:
              RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(15),
          ),
        ),

        child: Text(
          label,
          style:
              const TextStyle(
            fontWeight:
                FontWeight.w800,
          ),
        ),
      ),
    );
  }

  // ============================================================
  // URGENT BADGE
  // ============================================================

  Widget urgentBadge() {
    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 5,
      ),

      decoration:
          BoxDecoration(
        color:
            const Color(0xffFEE2E2),
        borderRadius:
            BorderRadius.circular(20),
        border: Border.all(
          color:
              const Color(0xffFECACA),
        ),
      ),

      child: const Row(
        mainAxisSize:
            MainAxisSize.min,
        children: [

          Icon(
            Icons.flash_on_rounded,
            size: 12,
            color:
                Color(0xffDC2626),
          ),

          SizedBox(
            width: 3,
          ),

          Text(
            "URGENT",
            style:
                TextStyle(
              color:
                  Color(0xffDC2626),
              fontWeight:
                  FontWeight.w900,
              fontSize: 9,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // ACCEPTED URGENT
  // ============================================================

  Widget acceptedUrgentCard(
      double total) {
    return Container(
      width: double.infinity,

      padding:
          const EdgeInsets.all(16),

      decoration:
          BoxDecoration(
        gradient:
            const LinearGradient(
          colors: [
            Color(0xffF0FDF4),
            Color(0xffDCFCE7),
          ],
        ),

        borderRadius:
            BorderRadius.circular(19),

        border: Border.all(
          color:
              const Color(0xff86EFAC),
        ),
      ),

      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,

        children: [

          const Row(
            children: [

              Icon(
                Icons.check_circle_rounded,
                color:
                    Color(0xff16A34A),
                size: 24,
              ),

              SizedBox(
                width: 8,
              ),

              Text(
                "Urgent Service Confirmed",
                style:
                    TextStyle(
                  color:
                      Color(0xff15803D),
                  fontSize: 16,
                  fontWeight:
                      FontWeight.w900,
                ),
              ),
            ],
          ),

          const SizedBox(
            height: 10,
          ),

          Text(
            "Final Amount: ₹${total.toStringAsFixed(0)}",
            style:
                const TextStyle(
              fontSize: 16,
              fontWeight:
                  FontWeight.w900,
            ),
          ),

          const SizedBox(
            height: 5,
          ),

          const Text(
            "The worker has been assigned to your urgent request.",
            style:
                TextStyle(
              color:
                  Color(0xff15803D),
              fontSize: 12,
            ),
          ),
        ],
      ),
    )
        .animate()
        .fade(
          duration: 450.ms,
        )
        .scale(
          begin:
              const Offset(.96, .96),
          end:
              const Offset(1, 1),
        );
  }

  // ============================================================
  // REJECTED URGENT
  // ============================================================

  Widget rejectedUrgentCard() {
    return Container(
      width: double.infinity,

      padding:
          const EdgeInsets.all(15),

      decoration:
          BoxDecoration(
        color:
            const Color(0xffF8FAFC),
        borderRadius:
            BorderRadius.circular(18),
        border: Border.all(
          color:
              const Color(0xffE5E7EB),
        ),
      ),

      child: const Row(
        children: [

          Icon(
            Icons.cancel_rounded,
            color:
                Colors.grey,
          ),

          SizedBox(
            width: 10,
          ),

          Expanded(
            child: Text(
              "This offer is no longer available.",
              style:
                  TextStyle(
                color:
                    Colors.grey,
                fontWeight:
                    FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // NORMAL APPLICATION CARD
  // ============================================================

  Widget normalApplicationCard(
      Map<String, dynamic> data,
      String status,
      int index) {
    return Container(
      margin:
          const EdgeInsets.only(
        bottom: 20,
      ),

      decoration:
          BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(28),

        border: Border.all(
          color:
              const Color(0xffE5EAF2),
        ),

        boxShadow: [
          BoxShadow(
            color: Colors.black
                .withOpacity(.065),
            blurRadius: 25,
            offset:
                const Offset(0, 11),
          ),

          BoxShadow(
            color: primaryBlue
                .withOpacity(.025),
            blurRadius: 5,
            offset:
                const Offset(0, 2),
          ),
        ],
      ),

      child: ClipRRect(
        borderRadius:
            BorderRadius.circular(28),

        child: Column(
          children: [

            // =================================================
            // TOP BLUE LINE
            // =================================================

            Container(
              height: 5,
              decoration:
                  const BoxDecoration(
                gradient:
                    LinearGradient(
                  colors: [
                    primaryBlue,
                    secondaryBlue,
                  ],
                ),
              ),
            ),

            Padding(
              padding:
                  const EdgeInsets.all(18),

              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,

                children: [

                  workerProfile(
                    data,
                    showCall: true,
                  ),

                  const SizedBox(
                    height: 16,
                  ),

                  normalPriceCard(data),

                  const SizedBox(
                    height: 14,
                  ),

                  messageCard(data),

                  const SizedBox(
                    height: 16,
                  ),

                  if (status == "pending")
                    pendingActionButtons(data),

                  if (status == "accepted")
                    acceptedCard(data),

                  if (status == "rejected")
                    rejectedCard(),
                ],
              ),
            ),
          ],
        ),
      ),
    )
        .animate(
          delay: Duration(
            milliseconds: index * 100,
          ),
        )
        .fade(
          duration: 500.ms,
        )
        .slideY(
          begin: .12,
          end: 0,
          duration: 550.ms,
          curve:
              Curves.easeOutBack,
        )
        .scale(
          begin:
              const Offset(.97, .97),
          end:
              const Offset(1, 1),
          duration: 500.ms,
        );
  }

  // ============================================================
  // WORKER PROFILE
  // ============================================================

  Widget workerProfile(
      Map<String, dynamic> data, {
        bool showCall = true,
      }) {
    final String workerId =
        data["workerId"]?.toString() ?? "";

    return FutureBuilder<
        Map<String, dynamic>?>(
      future: getWorkerData(workerId),

      builder:
          (context, snapshot) {

        if (snapshot.connectionState ==
            ConnectionState.waiting) {
          return Container(
            height: 91,

            decoration:
                BoxDecoration(
              color:
                  const Color(0xffF8FAFC),
              borderRadius:
                  BorderRadius.circular(22),
            ),

            child: const Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child:
                    CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color:
                      primaryBlue,
                ),
              ),
            ),
          );
        }

        final Map<String, dynamic> worker =
            snapshot.data ?? {};

        final bool verified =
            worker["verified"] == true;

        final String workerName =
            worker["name"]?.toString() ??
                data["workerName"]
                    ?.toString() ??
                "Worker";

        final String phone =
            worker["phone"]?.toString() ??
                data["workerPhone"]
                    ?.toString() ??
                "";

        return Container(
          padding:
              const EdgeInsets.all(14),

          decoration:
              BoxDecoration(
            gradient:
                const LinearGradient(
              begin:
                  Alignment.topLeft,
              end:
                  Alignment.bottomRight,
              colors: [
                Color(0xffF9FBFF),
                Color(0xffF3F7FD),
              ],
            ),

            borderRadius:
                BorderRadius.circular(22),

            border: Border.all(
              color:
                  const Color(0xffE4EAF4),
            ),

            boxShadow: [
              BoxShadow(
                color: primaryBlue
                    .withOpacity(.035),
                blurRadius: 14,
                offset:
                    const Offset(0, 6),
              ),
            ],
          ),

          child: Row(
            children: [

              // =================================================
              // AVATAR
              // =================================================

              Container(
                height: 61,
                width: 61,

                decoration:
                    BoxDecoration(
                  shape:
                      BoxShape.circle,

                  gradient:
                      const LinearGradient(
                    begin:
                        Alignment.topLeft,
                    end:
                        Alignment.bottomRight,
                    colors: [
                      Color(0xff2563EB),
                      Color(0xff38BDF8),
                    ],
                  ),

                  boxShadow: [
                    BoxShadow(
                      color: primaryBlue
                          .withOpacity(.22),
                      blurRadius: 12,
                      offset:
                          const Offset(0, 6),
                    ),
                  ],
                ),

                child: const Icon(
                  Icons.person_rounded,
                  size: 34,
                  color:
                      Colors.white,
                ),
              ),

              const SizedBox(
                width: 13,
              ),

              // =================================================
              // WORKER INFO
              // =================================================

              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,

                  children: [

                    Row(
                      children: [

                        Expanded(
                          child: Text(
                            workerName,
                            maxLines: 1,
                            overflow:
                                TextOverflow
                                    .ellipsis,

                            style:
                                const TextStyle(
                              fontSize: 16,
                              fontWeight:
                                  FontWeight.w900,
                              color:
                                  darkBlue,
                            ),
                          ),
                        ),

                        if (verified)
                          verificationBadge(),
                      ],
                    ),

                    const SizedBox(
                      height: 5,
                    ),

                    Row(
                      children: [

                        const Icon(
                          Icons
                              .phone_outlined,
                          size: 14,
                          color:
                              Colors.grey,
                        ),

                        const SizedBox(
                          width: 5,
                        ),

                        Expanded(
                          child: Text(
                            phone.isEmpty
                                ? "Phone unavailable"
                                : phone,

                            maxLines: 1,
                            overflow:
                                TextOverflow
                                    .ellipsis,

                            style:
                                TextStyle(
                              fontSize: 12,
                              color:
                                  Colors.grey
                                      .shade600,
                              fontWeight:
                                  FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(
                      height: 5,
                    ),

                    Row(
                      children: [

                        const Icon(
                          Icons.star_rounded,
                          size: 16,
                          color:
                              Color(0xffF59E0B),
                        ),

                        const SizedBox(
                          width: 4,
                        ),

                        Text(
                          "${worker["rating"] ?? "New"}",
                          style:
                              const TextStyle(
                            fontSize: 12,
                            fontWeight:
                                FontWeight.w800,
                            color:
                                Color(0xff374151),
                          ),
                        ),

                        const SizedBox(
                          width: 5,
                        ),

                        Text(
                          "Servora Worker",
                          style:
                              TextStyle(
                            fontSize: 10,
                            color:
                                Colors.grey
                                    .shade500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(
                width: 7,
              ),

              if (showCall)
                _small3DIconButton(
                  icon:
                      Icons.call_rounded,
                  color:
                      const Color(0xff16A34A),
                  background:
                      const Color(0xffDCFCE7),
                  onTap: phone.isEmpty
                      ? null
                      : () {
                          callWorker(phone);
                        },
                ),
            ],
          ),
        );
      },
    );
  }

  // ============================================================
  // VERIFIED BADGE
  // ============================================================

  Widget verificationBadge() {
    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 7,
        vertical: 4,
      ),

      decoration:
          BoxDecoration(
        color:
            const Color(0xffDCFCE7),
        borderRadius:
            BorderRadius.circular(20),
        border: Border.all(
          color:
              const Color(0xffBBF7D0),
        ),
      ),

      child: const Row(
        mainAxisSize:
            MainAxisSize.min,

        children: [

          Icon(
            Icons.verified_rounded,
            size: 13,
            color:
                Color(0xff16A34A),
          ),

          SizedBox(
            width: 3,
          ),

          Text(
            "Verified",
            style:
                TextStyle(
              fontSize: 9,
              color:
                  Color(0xff15803D),
              fontWeight:
                  FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // NORMAL PRICE CARD
  // ============================================================

  Widget normalPriceCard(
      Map<String, dynamic> data) {
    final String price =
        (data["currentOffer"] ??
                data["workerPrice"] ??
                "0")
            .toString();

    return Container(
      padding:
          const EdgeInsets.all(17),

      decoration:
          BoxDecoration(
        gradient:
            const LinearGradient(
          begin:
              Alignment.topLeft,
          end:
              Alignment.bottomRight,
          colors: [
            Color(0xff1D4ED8),
            Color(0xff2563EB),
            Color(0xff38BDF8),
          ],
        ),

        borderRadius:
            BorderRadius.circular(21),

        boxShadow: [
          BoxShadow(
            color: primaryBlue
                .withOpacity(.27),
            blurRadius: 16,
            offset:
                const Offset(0, 8),
          ),
        ],
      ),

      child: Row(
        children: [

          Container(
            height: 49,
            width: 49,

            decoration:
                BoxDecoration(
              color: Colors.white
                  .withOpacity(.16),
              shape:
                  BoxShape.circle,
              border: Border.all(
                color: Colors.white
                    .withOpacity(.25),
              ),
            ),

            child: const Icon(
              Icons
                  .currency_rupee_rounded,
              color:
                  Colors.white,
              size: 27,
            ),
          ),

          const SizedBox(
            width: 13,
          ),

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,

              children: [

                const Text(
                  "WORKER OFFER",
                  style:
                      TextStyle(
                    color:
                        Colors.white70,
                    fontSize: 9,
                    fontWeight:
                        FontWeight.w800,
                    letterSpacing:
                        1.1,
                  ),
                ),

                const SizedBox(
                  height: 2,
                ),

                Text(
                  "₹$price",
                  style:
                      const TextStyle(
                    color:
                        Colors.white,
                    fontSize: 25,
                    fontWeight:
                        FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),

          Container(
            padding:
                const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 7,
            ),

            decoration:
                BoxDecoration(
              color: Colors.white
                  .withOpacity(.17),
              borderRadius:
                  BorderRadius.circular(12),
            ),

            child: const Row(
              mainAxisSize:
                  MainAxisSize.min,

              children: [

                Icon(
                  Icons
                      .local_offer_rounded,
                  size: 14,
                  color:
                      Colors.white,
                ),

                SizedBox(
                  width: 4,
                ),

                Text(
                  "OFFER",
                  style:
                      TextStyle(
                    color:
                        Colors.white,
                    fontSize: 9,
                    fontWeight:
                        FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    )
        .animate()
        .fade(
          duration: 400.ms,
        )
        .slideX(
          begin: .04,
          end: 0,
          duration: 450.ms,
        );
  }

  // ============================================================
  // MESSAGE CARD
  // ============================================================

  Widget messageCard(
      Map<String, dynamic> data) {
    final String message =
        data["message"]
                ?.toString()
                .trim() ??
            "";

    final bool hasMessage =
        message.isNotEmpty;

    return Container(
      width: double.infinity,

      padding:
          const EdgeInsets.all(15),

      decoration:
          BoxDecoration(
        color:
            const Color(0xffF8FAFC),
        borderRadius:
            BorderRadius.circular(19),
        border: Border.all(
          color:
              const Color(0xffE5E7EB),
        ),
      ),

      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,

        children: [

          Container(
            height: 39,
            width: 39,

            decoration:
                BoxDecoration(
              color:
                  const Color(0xffDBEAFE),
              borderRadius:
                  BorderRadius.circular(12),
            ),

            child: const Icon(
              Icons
                  .chat_bubble_outline_rounded,
              color:
                  primaryBlue,
              size: 20,
            ),
          ),

          const SizedBox(
            width: 11,
          ),

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,

              children: [

                const Text(
                  "WORKER MESSAGE",
                  style:
                      TextStyle(
                    fontSize: 9,
                    fontWeight:
                        FontWeight.w900,
                    color:
                        Color(0xff6B7280),
                    letterSpacing:
                        .7,
                  ),
                ),

                const SizedBox(
                  height: 5,
                ),

                Text(
                  hasMessage
                      ? message
                      : "No message provided by worker",

                  maxLines: 4,
                  overflow:
                      TextOverflow.ellipsis,

                  style: TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    color: hasMessage
                        ? const Color(
                            0xff374151,
                          )
                        : Colors.grey
                            .shade500,
                    fontWeight:
                        FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // ACTION BUTTONS
  // ============================================================

  Widget pendingActionButtons(
      Map<String, dynamic> data) {
    return Row(
      children: [

        Expanded(
          child: _premium3DButton(
            icon:
                Icons.chat_bubble_rounded,
            label:
                "Chat",
            color:
                primaryBlue,
            lightColor:
                const Color(0xffDBEAFE),
            onTap: () {
              openChat(data);
            },
          ),
        ),

        const SizedBox(
          width: 8,
        ),

        Expanded(
          child: _premium3DButton(
            icon:
                Icons.check_circle_rounded,
            label:
                "Accept",
            color:
                const Color(0xff16A34A),
            lightColor:
                const Color(0xffDCFCE7),
            isLoading:
                updating,
            onTap: updating
                ? null
                : () {
                    showNormalAcceptDialog(
                      data,
                    );
                  },
          ),
        ),

        const SizedBox(
          width: 8,
        ),

        Expanded(
          child: _premium3DButton(
            icon:
                Icons.close_rounded,
            label:
                "Reject",
            color:
                const Color(0xffDC2626),
            lightColor:
                const Color(0xffFEE2E2),
            outlined:
                true,
            onTap: () {
  rejectNormalWorker(data);
},
          ),
        ),
      ],
    );
  }

  // ============================================================
  // PREMIUM 3D BUTTON
  // ============================================================

  Widget _premium3DButton({
    required IconData icon,
    required String label,
    required Color color,
    required Color lightColor,
    required VoidCallback? onTap,
    bool outlined = false,
    bool isLoading = false,
  }) {
    return _Animated3DButton(
      icon: icon,
      label: label,
      color: color,
      lightColor: lightColor,
      outlined: outlined,
      isLoading: isLoading,
      onTap: onTap,
    );
  }

  // ============================================================
  // NORMAL ACCEPT DIALOG
  // ============================================================

  void showNormalAcceptDialog(
      Map<String, dynamic> data) {
    final String price =
        (data["currentOffer"] ??
                data["workerPrice"] ??
                "0")
            .toString();

    showDialog(
      context: context,
      barrierDismissible: false,

      builder: (context) {
        return Dialog(
          backgroundColor:
              Colors.transparent,

          child: Container(
            padding:
                const EdgeInsets.all(22),

            decoration:
                BoxDecoration(
              color: Colors.white,
              borderRadius:
                  BorderRadius.circular(28),

              boxShadow: [
                BoxShadow(
                  color: Colors.black
                      .withOpacity(.18),
                  blurRadius: 30,
                  offset:
                      const Offset(0, 14),
                ),
              ],
            ),

            child: Column(
              mainAxisSize:
                  MainAxisSize.min,

              children: [

                Container(
                  height: 72,
                  width: 72,

                  decoration:
                      BoxDecoration(
                    gradient:
                        const LinearGradient(
                      colors: [
                        Color(0xff16A34A),
                        Color(0xff22C55E),
                      ],
                    ),
                    shape:
                        BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.green
                            .withOpacity(.20),
                        blurRadius: 15,
                        offset:
                            const Offset(
                          0,
                          7,
                        ),
                      ),
                    ],
                  ),

                  child: const Icon(
                    Icons
                        .verified_user_rounded,
                    color:
                        Colors.white,
                    size: 34,
                  ),
                ),

                const SizedBox(
                  height: 16,
                ),

                const Text(
                  "Confirm Worker",
                  style:
                      TextStyle(
                    fontSize: 21,
                    fontWeight:
                        FontWeight.w900,
                    color: darkBlue,
                  ),
                ),

                const SizedBox(
                  height: 8,
                ),

                const Text(
                  "Accept this worker for your service?",
                  textAlign:
                      TextAlign.center,
                  style:
                      TextStyle(
                    color: Colors.grey,
                    fontSize: 13,
                  ),
                ),

                const SizedBox(
                  height: 18,
                ),

                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.all(15),

                  decoration:
                      BoxDecoration(
                    color:
                        const Color(0xffF0FDF4),
                    borderRadius:
                        BorderRadius.circular(18),
                    border: Border.all(
                      color:
                          const Color(0xffBBF7D0),
                    ),
                  ),

                  child: Column(
                    children: [

                      const Text(
                        "FINAL PRICE",
                        style:
                            TextStyle(
                          color:
                              Color(0xff15803D),
                          fontSize: 10,
                          fontWeight:
                              FontWeight.w800,
                          letterSpacing:
                              1,
                        ),
                      ),

                      const SizedBox(
                        height: 4,
                      ),

                      Text(
                        "₹$price",
                        style:
                            const TextStyle(
                          fontSize: 28,
                          fontWeight:
                              FontWeight.w900,
                          color:
                              Color(0xff16A34A),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(
                  height: 18,
                ),

                Row(
                  children: [

                    Expanded(
                      child:
                          _dialogButton(
                        label:
                            "Cancel",
                        color:
                            Colors.grey,
                        filled:
                            false,
                        onTap: () {
                          Navigator.pop(
                            context,
                          );
                        },
                      ),
                    ),

                    const SizedBox(
                      width: 10,
                    ),

                    Expanded(
                      child:
                          _dialogButton(
                        label:
                            "Confirm",
                        color:
                            const Color(
                          0xff16A34A,
                        ),
                        filled:
                            true,
                        onTap: () {
                          Navigator.pop(
                            context,
                          );

                          acceptNormalWorker(
                            data,
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ============================================================
  // ACCEPTED NORMAL
  // ============================================================

  Widget acceptedCard(
      Map<String, dynamic> data) {
    final String finalPrice =
        (data["finalPrice"] ??
                data["currentOffer"] ??
                data["workerPrice"] ??
                "0")
            .toString();

    return Container(
      width: double.infinity,

      padding:
          const EdgeInsets.all(16),

      decoration:
          BoxDecoration(
        gradient:
            const LinearGradient(
          colors: [
            Color(0xffF0FDF4),
            Color(0xffDCFCE7),
          ],
        ),

        borderRadius:
            BorderRadius.circular(19),

        border: Border.all(
          color:
              const Color(0xff86EFAC),
        ),
      ),

      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,

        children: [

          const Row(
            children: [

              Icon(
                Icons.check_circle_rounded,
                color:
                    Color(0xff16A34A),
              ),

              SizedBox(
                width: 8,
              ),

              Text(
                "Worker Accepted",
                style:
                    TextStyle(
                  color:
                      Color(0xff15803D),
                  fontSize: 17,
                  fontWeight:
                      FontWeight.w900,
                ),
              ),
            ],
          ),

          const SizedBox(
            height: 10,
          ),

          Text(
            "Final Amount: ₹$finalPrice",
            style:
                const TextStyle(
              fontWeight:
                  FontWeight.w900,
              fontSize: 16,
            ),
          ),

          const SizedBox(
            height: 6,
          ),

          const Text(
            "Your booking is confirmed.",
            style:
                TextStyle(
              color:
                  Color(0xff15803D),
              fontSize: 12,
            ),
          ),
        ],
      ),
    )
        .animate()
        .fade(
          duration: 450.ms,
        )
        .scale(
          begin:
              const Offset(.96, .96),
          end:
              const Offset(1, 1),
        );
  }

  // ============================================================
  // REJECTED NORMAL
  // ============================================================

  Widget rejectedCard() {
    return Container(
      width: double.infinity,

      padding:
          const EdgeInsets.all(15),

      decoration:
          BoxDecoration(
        color:
            const Color(0xffFEF2F2),
        borderRadius:
            BorderRadius.circular(18),
        border: Border.all(
          color:
              const Color(0xffFECACA),
        ),
      ),

      child: const Row(
        children: [

          Icon(
            Icons.cancel_rounded,
            color:
                Color(0xffDC2626),
          ),

          SizedBox(
            width: 10,
          ),

          Text(
            "Offer Rejected",
            style:
                TextStyle(
              color:
                  Color(0xffDC2626),
              fontWeight:
                  FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // EMPTY STATE
  // ============================================================

  Widget emptyApplications() {
    return Center(
      child: Padding(
        padding:
            const EdgeInsets.all(30),

        child: Column(
          mainAxisAlignment:
              MainAxisAlignment.center,

          children: [

            Container(
              height: 125,
              width: 125,

              decoration:
                  BoxDecoration(
                gradient:
                    const LinearGradient(
                  colors: [
                    Color(0xffDBEAFE),
                    Color(0xffE0F2FE),
                  ],
                ),

                shape:
                    BoxShape.circle,

                boxShadow: [
                  BoxShadow(
                    color: primaryBlue
                        .withOpacity(.14),
                    blurRadius: 25,
                    offset:
                        const Offset(0, 12),
                  ),
                ],
              ),

              child: const Icon(
                Icons
                    .people_alt_outlined,
                size: 62,
                color:
                    primaryBlue,
              ),
            )
                .animate(
                  onPlay:
                      (controller) =>
                          controller.repeat(
                    reverse: true,
                  ),
                )
                .scale(
                  begin:
                      const Offset(.95, .95),
                  end:
                      const Offset(1.05, 1.05),
                  duration: 1800.ms,
                  curve:
                      Curves.easeInOut,
                ),

            const SizedBox(
              height: 25,
            ),

            const Text(
              "No Worker Offers Yet",
              textAlign:
                  TextAlign.center,

              style:
                  TextStyle(
                fontSize: 23,
                fontWeight:
                    FontWeight.w900,
                color:
                    darkBlue,
              ),
            ),

            const SizedBox(
              height: 10,
            ),

            const Text(
              "Workers will send offers when they apply for your service request.",
              textAlign:
                  TextAlign.center,

              style:
                  TextStyle(
                color:
                    Colors.grey,
                fontSize: 13,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    )
        .animate()
        .fade(
          duration: 500.ms,
        )
        .slideY(
          begin: .08,
          end: 0,
          duration: 600.ms,
        );
  }
}

// ================================================================
// ANIMATED 3D BUTTON
// ================================================================

class _Animated3DButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Color lightColor;
  final VoidCallback? onTap;

  final bool outlined;
  final bool isLoading;

  const _Animated3DButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.lightColor,
    required this.onTap,
    this.outlined = false,
    this.isLoading = false,
  });

  @override
  State<_Animated3DButton> createState() =>
      _Animated3DButtonState();
}

class _Animated3DButtonState
    extends State<_Animated3DButton> {

  bool pressed = false;

  void pressDown() {
    if (widget.onTap == null) return;

    setState(() {
      pressed = true;
    });
  }

  void pressUp() {
    if (widget.onTap == null) return;

    setState(() {
      pressed = false;
    });

    widget.onTap!();
  }

  void pressCancel() {
    if (!mounted) return;

    setState(() {
      pressed = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool disabled =
        widget.onTap == null;

    return GestureDetector(
      onTapDown: (_) {
        pressDown();
      },

      onTapUp: (_) {
        pressUp();
      },

      onTapCancel: pressCancel,

      child: AnimatedContainer(
        duration:
            const Duration(
          milliseconds: 120,
        ),

        transform:
            Matrix4.translationValues(
          0,
          pressed ? 4 : 0,
          0,
        ),

        child: Container(
          height: 57,

          decoration:
              BoxDecoration(
            borderRadius:
                BorderRadius.circular(18),

            boxShadow: disabled
                ? []
                : [
                    BoxShadow(
                      color:
                          widget.color
                              .withOpacity(
                        pressed
                            ? .08
                            : .24,
                      ),
                      blurRadius:
                          pressed ? 4 : 11,
                      offset:
                          Offset(
                        0,
                        pressed ? 2 : 6,
                      ),
                    ),
                  ],
          ),

          child: Container(
            decoration:
                BoxDecoration(
              borderRadius:
                  BorderRadius.circular(18),

              gradient:
                  widget.outlined ||
                          disabled
                      ? null
                      : LinearGradient(
                          begin:
                              Alignment.topLeft,
                          end:
                              Alignment.bottomRight,
                          colors: [
                            widget.color,
                            Color.lerp(
                                  widget.color,
                                  Colors.white,
                                  .12,
                                ) ??
                                widget.color,
                          ],
                        ),

              color: widget.outlined
                  ? Colors.white
                  : disabled
                      ? Colors.grey.shade300
                      : null,

              border: widget.outlined
                  ? Border.all(
                      color: disabled
                          ? Colors
                              .grey
                              .shade400
                          : widget.color,
                      width: 1.4,
                    )
                  : null,
            ),

            child: Stack(
              children: [

                if (!disabled &&
                    !widget.outlined)
                  Positioned(
                    top: 1,
                    left: 9,
                    right: 9,
                    child: Container(
                      height: 2,
                      decoration:
                          BoxDecoration(
                        color: Colors.white
                            .withOpacity(.20),
                        borderRadius:
                            BorderRadius.circular(
                          10,
                        ),
                      ),
                    ),
                  ),

                Center(
                  child:
                      widget.isLoading
                          ? SizedBox(
                              height: 20,
                              width: 20,
                              child:
                                  CircularProgressIndicator(
                                strokeWidth:
                                    2.5,
                                valueColor:
                                    AlwaysStoppedAnimation<
                                        Color>(
                                  widget.outlined
                                      ? widget.color
                                      : Colors.white,
                                ),
                              ),
                            )
                          : Row(
                              mainAxisAlignment:
                                  MainAxisAlignment
                                      .center,

                              children: [

                                Icon(
                                  widget.icon,
                                  size: 18,
                                  color:
                                      disabled
                                          ? Colors
                                              .grey
                                              .shade600
                                          : widget.outlined
                                              ? widget
                                                  .color
                                              : Colors
                                                  .white,
                                ),

                                const SizedBox(
                                  width: 6,
                                ),

                                Flexible(
                                  child:
                                      Text(
                                    widget.label,
                                    maxLines: 1,
                                    overflow:
                                        TextOverflow
                                            .ellipsis,
                                    style:
                                        TextStyle(
                                      fontSize: 11,
                                      fontWeight:
                                          FontWeight.w900,
                                      color:
                                          disabled
                                              ? Colors
                                                  .grey
                                                  .shade600
                                              : widget.outlined
                                                  ? widget
                                                      .color
                                                  : Colors
                                                      .white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ================================================================
// SMALL 3D CALL BUTTON
// ================================================================

Widget _small3DIconButton({
  required IconData icon,
  required Color color,
  required Color background,
  required VoidCallback? onTap,
}) {
  return _Small3DButton(
    icon: icon,
    color: color,
    background: background,
    onTap: onTap,
  );
}

// ================================================================
// SMALL BUTTON
// ================================================================

class _Small3DButton extends StatefulWidget {
  final IconData icon;
  final Color color;
  final Color background;
  final VoidCallback? onTap;

  const _Small3DButton({
    required this.icon,
    required this.color,
    required this.background,
    required this.onTap,
  });

  @override
  State<_Small3DButton> createState() =>
      _Small3DButtonState();
}

class _Small3DButtonState
    extends State<_Small3DButton> {

  bool pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: widget.onTap == null
          ? null
          : (_) {
              setState(() {
                pressed = true;
              });
            },

      onTapCancel: () {
        setState(() {
          pressed = false;
        });
      },

      onTapUp: widget.onTap == null
          ? null
          : (_) {
              setState(() {
                pressed = false;
              });

              widget.onTap!();
            },

      child: AnimatedContainer(
        duration:
            const Duration(
          milliseconds: 120,
        ),

        transform:
            Matrix4.translationValues(
          0,
          pressed ? 3 : 0,
          0,
        ),

        height: 44,
        width: 44,

        decoration:
            BoxDecoration(
          color:
              widget.background,
          shape:
              BoxShape.circle,

          border: Border.all(
            color:
                widget.color
                    .withOpacity(.08),
          ),

          boxShadow: [
            BoxShadow(
              color:
                  widget.color
                      .withOpacity(
                pressed ? .07 : .18,
              ),
              blurRadius:
                  pressed ? 4 : 9,
              offset:
                  Offset(
                0,
                pressed ? 2 : 4,
              ),
            ),
          ],
        ),

        child: Icon(
          widget.icon,
          color:
              widget.color,
          size: 20,
        ),
      ),
    );
  }
  Widget _headerStat({
  required IconData icon,
  required String value,
  required String label,
}) {
  return Container(
    height: 50,
    padding: const EdgeInsets.symmetric(
      horizontal: 8,
      vertical: 6,
    ),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(.12),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(
        color: Colors.white.withOpacity(.14),
      ),
    ),
    child: Row(
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(.14),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(
            icon,
            color: Colors.white,
            size: 16,
          ),
        ),

        const SizedBox(width: 6),

        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white.withOpacity(.68),
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
}
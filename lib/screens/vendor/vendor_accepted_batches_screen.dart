import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

class VendorAcceptedBatchesScreen
    extends StatefulWidget {
  const VendorAcceptedBatchesScreen({
    super.key,
  });

  @override
  State<VendorAcceptedBatchesScreen>
      createState() =>
          _VendorAcceptedBatchesScreenState();
}

class _VendorAcceptedBatchesScreenState
    extends State<VendorAcceptedBatchesScreen> {
  // ============================================================
  // COLORS
  // ============================================================

  static const Color primaryColor =
      Color(0xff2563EB);

  static const Color backgroundColor =
      Color(0xffF8FAFC);

  // ============================================================
  // FIREBASE
  // ============================================================

  final DatabaseReference database =
      FirebaseDatabase.instance.ref();

  StreamSubscription<DatabaseEvent>?
      subscription;

  // ============================================================
  // STATE
  // ============================================================

  bool loading = true;

  List<Map<String, dynamic>>
      acceptedBatches = [];

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();

    _listenToAcceptedBatches();
  }

  // ============================================================
  // LISTEN
  // ============================================================

  void _listenToAcceptedBatches() {
    final user =
        FirebaseAuth.instance.currentUser;

    if (user == null) {
      setState(() {
        loading = false;
      });
      return;
    }

    subscription?.cancel();

    subscription = database
        .child("vendorAcceptedBatches")
        .child(user.uid)
        .onValue
        .listen(
      (event) {
        if (!mounted) return;

        final List<Map<String, dynamic>>
            list = [];

        if (event.snapshot.exists &&
            event.snapshot.value is Map) {
          final data =
              Map<String, dynamic>.from(
            event.snapshot.value as Map,
          );

          data.forEach(
            (key, value) {
              if (value is Map) {
                list.add({
                  "id": key.toString(),
                  ...Map<String, dynamic>.from(
                    value,
                  ),
                });
              }
            },
          );
        }

        setState(() {
          acceptedBatches = list;
          loading = false;
        });
      },
    );
  }

  // ============================================================
  // ACCEPT JOB
  // ============================================================

  Future<void> _acceptJob(
    Map<String, dynamic> job,
  ) async {
    final user =
        FirebaseAuth.instance.currentUser;

    if (user == null) return;

    final id =
        job["id"].toString();

    try {
      await database
          .child("vendorAcceptedBatches")
          .child(user.uid)
          .child(id)
          .update({
        "status": "accepted",
        "acceptedAt":
            ServerValue.timestamp,
      });

      // ========================================================
      // ALSO UPDATE ORIGINAL BATCH
      // ========================================================

      final apartmentKey =
          job["apartmentKey"].toString();

      final serviceId =
          job["serviceId"].toString();

      await database
          .child("societyServiceBatches")
          .child(apartmentKey)
          .child(serviceId)
          .update({
        "status": "scheduled",
        "vendorStatus": "accepted",
        "updatedAt":
            ServerValue.timestamp,
      });

      if (!mounted) return;

      _showMessage(
        "Service accepted successfully.",
        Colors.green,
      );
    } catch (e) {
      debugPrint(
        "ACCEPT JOB ERROR: $e",
      );

      if (!mounted) return;

      _showMessage(
        "Unable to accept service.",
        Colors.red,
      );
    }
  }

  // ============================================================
  // REJECT JOB
  // ============================================================

  Future<void> _rejectJob(
    Map<String, dynamic> job,
  ) async {
    final user =
        FirebaseAuth.instance.currentUser;

    if (user == null) return;

    final id =
        job["id"].toString();

    try {
      await database
          .child("vendorAcceptedBatches")
          .child(user.uid)
          .child(id)
          .update({
        "status": "rejected",
        "rejectedAt":
            ServerValue.timestamp,
      });

      if (!mounted) return;

      _showMessage(
        "Service rejected.",
        Colors.orange,
      );
    } catch (e) {
      debugPrint(
        "REJECT JOB ERROR: $e",
      );
    }
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          backgroundColor,

      appBar: AppBar(
        backgroundColor:
            Colors.white,
        elevation: 0,

        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back,
            color: Colors.black,
          ),
          onPressed: () {
            Navigator.pop(context);
          },
        ),

        title: const Text(
          "My Service Jobs",
          style: TextStyle(
            color: Colors.black,
            fontWeight:
                FontWeight.bold,
          ),
        ),
      ),

      body: loading
          ? const Center(
              child:
                  CircularProgressIndicator(
                color: primaryColor,
              ),
            )
          : acceptedBatches.isEmpty
              ? _buildEmpty()
              : RefreshIndicator(
                  onRefresh: () async {
                    _listenToAcceptedBatches();

                    await Future.delayed(
                      const Duration(
                        milliseconds: 500,
                      ),
                    );
                  },
                  child:
                      ListView.builder(
                    padding:
                        const EdgeInsets.all(
                      20,
                    ),
                    itemCount:
                        acceptedBatches.length,
                    itemBuilder:
                        (context, index) {
                      return _buildJobCard(
                        acceptedBatches[
                            index],
                      );
                    },
                  ),
                ),
    );
  }

  // ============================================================
  // JOB CARD
  // ============================================================

  Widget _buildJobCard(
    Map<String, dynamic> job,
  ) {
    final status =
        job["status"]
                ?.toString() ??
            "waiting_vendor_acceptance";

    return Container(
      margin:
          const EdgeInsets.only(
        bottom: 16,
      ),
      padding:
          const EdgeInsets.all(18),
      decoration:
          BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                height: 52,
                width: 52,
                decoration:
                    const BoxDecoration(
                  color:
                      Color(0xffDBEAFE),
                  shape:
                      BoxShape.circle,
                ),
                child:
                    const Icon(
                  Icons.home_repair_service,
                  color:
                      primaryColor,
                ),
              ),

              const SizedBox(
                width: 12,
              ),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment
                          .start,
                  children: [
                    Text(
                      job["serviceName"]
                              ?.toString() ??
                          "Service",
                      style:
                          const TextStyle(
                        fontSize: 17,
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),
                    const SizedBox(
                      height: 4,
                    ),
                    Text(
                      job["apartmentName"]
                              ?.toString() ??
                          "Apartment",
                      style:
                          const TextStyle(
                        color: Colors.grey,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),

              _statusBadge(
                status,
              ),
            ],
          ),

          const SizedBox(
            height: 15,
          ),

          Row(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.location_on,
                color:
                    primaryColor,
                size: 20,
              ),
              const SizedBox(
                width: 7,
              ),
              Expanded(
                child: Text(
                  job["address"]
                          ?.toString() ??
                      "Address not available",
                  style:
                      const TextStyle(
                    color:
                        Colors.grey,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(
            height: 14,
          ),

          Container(
            padding:
                const EdgeInsets.all(
              14,
            ),
            decoration:
                BoxDecoration(
              color:
                  const Color(
                0xffF8FAFC,
              ),
              borderRadius:
                  BorderRadius.circular(
                14,
              ),
            ),
            child: Column(
              children: [
                _infoRow(
                  Icons.currency_rupee,
                  "Your Bid",
                  "₹${job["amount"] ?? 0}",
                ),
                const SizedBox(
                  height: 10,
                ),
                _infoRow(
                  Icons.calendar_month,
                  "Service Date",
                  job["scheduledDate"]
                          ?.toString() ??
                      "Not set",
                ),
                const SizedBox(
                  height: 10,
                ),
                _infoRow(
                  Icons.access_time,
                  "Service Time",
                  job["scheduledTime"]
                          ?.toString() ??
                      "Not set",
                ),
              ],
            ),
          ),

          if (status ==
              "waiting_vendor_acceptance") ...[
            const SizedBox(
              height: 15,
            ),

            Row(
              children: [
                Expanded(
                  child:
                      OutlinedButton(
                    onPressed: () {
                      _rejectJob(
                        job,
                      );
                    },
                    child:
                        const Text(
                      "Reject",
                    ),
                  ),
                ),

                const SizedBox(
                  width: 10,
                ),

                Expanded(
                  child:
                      ElevatedButton(
                    onPressed: () {
                      _acceptJob(
                        job,
                      );
                    },
                    style:
                        ElevatedButton
                            .styleFrom(
                      backgroundColor:
                          primaryColor,
                    ),
                    child:
                        const Text(
                      "Accept Job",
                      style:
                          TextStyle(
                        color:
                            Colors.white,
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ============================================================
  // INFO ROW
  // ============================================================

  Widget _infoRow(
    IconData icon,
    String title,
    String value,
  ) {
    return Row(
      children: [
        Icon(
          icon,
          size: 18,
          color: primaryColor,
        ),
        const SizedBox(
          width: 8,
        ),
        Expanded(
          child: Text(
            title,
            style:
                const TextStyle(
              color: Colors.grey,
              fontSize: 12,
            ),
          ),
        ),
        Text(
          value,
          style:
              const TextStyle(
            fontWeight:
                FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  // ============================================================
  // STATUS
  // ============================================================

  Widget _statusBadge(
    String status,
  ) {
    Color color;
    String text;

    switch (status) {
      case "accepted":
        color = Colors.green;
        text = "ACCEPTED";
        break;

      case "rejected":
        color = Colors.red;
        text = "REJECTED";
        break;

      case "completed":
        color = Colors.blue;
        text = "COMPLETED";
        break;

      default:
        color = Colors.orange;
        text =
            "ACTION REQUIRED";
    }

    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 6,
      ),
      decoration:
          BoxDecoration(
        color:
            color.withOpacity(.12),
        borderRadius:
            BorderRadius.circular(9),
      ),
      child: Text(
        text,
        style:
            TextStyle(
          color: color,
          fontSize: 8,
          fontWeight:
              FontWeight.bold,
        ),
      ),
    );
  }

  // ============================================================
  // EMPTY
  // ============================================================

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment:
            MainAxisAlignment.center,
        children: [
          Container(
            height: 100,
            width: 100,
            decoration:
                BoxDecoration(
              color:
                  const Color(
                0xffDBEAFE,
              ),
              borderRadius:
                  BorderRadius.circular(
                30,
              ),
            ),
            child:
                const Icon(
              Icons.work_outline,
              size: 50,
              color: primaryColor,
            ),
          ),

          const SizedBox(
            height: 20,
          ),

          const Text(
            "No Service Jobs",
            style:
                TextStyle(
              fontSize: 20,
              fontWeight:
                  FontWeight.bold,
            ),
          ),

          const SizedBox(
            height: 8,
          ),

          const Text(
            "Selected society service jobs will appear here.",
            textAlign:
                TextAlign.center,
            style:
                TextStyle(
              color: Colors.grey,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // MESSAGE
  // ============================================================

  void _showMessage(
    String message,
    Color color,
  ) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
        .showSnackBar(
      SnackBar(
        content:
            Text(message),
        backgroundColor:
            color,
      ),
    );
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    subscription?.cancel();
    super.dispose();
  }
}

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

class WorkerUrgentJobsScreen extends StatefulWidget {
  const WorkerUrgentJobsScreen({
    super.key,
  });

  @override
  State<WorkerUrgentJobsScreen> createState() =>
      _WorkerUrgentJobsScreenState();
}

class _WorkerUrgentJobsScreenState
    extends State<WorkerUrgentJobsScreen> {
  List<Map<String, dynamic>> urgentJobs = [];

  bool loading = true;

  final currentUser =
      FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    loadUrgentJobs();
  }

  // ============================================================
  // LOAD URGENT JOBS
  // ============================================================

  void loadUrgentJobs() {
    DatabaseReference ref =
        FirebaseDatabase.instance.ref("services");

    ref.onValue.listen((event) {
      List<Map<String, dynamic>> jobs = [];

      if (event.snapshot.exists) {
        final rawData = event.snapshot.value;

        if (rawData is Map) {
          for (final entry in rawData.entries) {
            final key = entry.key.toString();
            final value = entry.value;

            if (value is! Map) {
              continue;
            }

            Map<String, dynamic> request =
                Map<String, dynamic>.from(value);

            // ----------------------------------------------------
            // Only show:
            // urgency = urgent
            // status = pending
            // customer != current worker
            // ----------------------------------------------------

            final bool isUrgent =
                request["urgency"] == "urgent";

            final bool isPending =
                request["status"] == "pending";

            final bool isNotOwnRequest =
                request["customerId"] != currentUser?.uid;

            if (!isUrgent ||
                !isPending ||
                !isNotOwnRequest) {
              continue;
            }

            // ----------------------------------------------------
            // Check whether current worker already applied
            // ----------------------------------------------------

            bool alreadyApplied = false;

            Map<String, dynamic>? application;

            final applications =
                request["applications"];

            if (applications is Map &&
                currentUser != null &&
                applications.containsKey(
                  currentUser!.uid,
                )) {
              alreadyApplied = true;

              final workerApplication =
                  applications[currentUser!.uid];

              if (workerApplication is Map) {
                application =
                    Map<String, dynamic>.from(
                  workerApplication,
                );
              }
            }

            // ----------------------------------------------------
            // Add job
            // ----------------------------------------------------

            jobs.add({
              "id": key,
              ...request,
              "alreadyApplied": alreadyApplied,
              "myApplication": application,
            });
          }
        }
      }

      if (mounted) {
        setState(() {
          urgentJobs = jobs;
          loading = false;
        });
      }
    });
  }

  // ============================================================
  // SEND WORKER OFFER
  // ============================================================

  Future<void> sendWorkerOffer(
    String requestId,
  ) async {
    User? user =
        FirebaseAuth.instance.currentUser;

    if (user == null) {
      return;
    }

    // ----------------------------------------------------------
    // Check if worker already applied
    // ----------------------------------------------------------

    DatabaseReference applicationRef =
        FirebaseDatabase.instance.ref(
      "services/$requestId/applications/${user.uid}",
    );

    DataSnapshot existingApplication =
        await applicationRef.get();

    if (existingApplication.exists) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            "You already applied for this service",
          ),
          backgroundColor: Colors.orange,
        ),
      );

      return;
    }

    // ----------------------------------------------------------
    // Price controller
    // ----------------------------------------------------------

    final TextEditingController priceController =
        TextEditingController();

    // ----------------------------------------------------------
    // Show price dialog
    // ----------------------------------------------------------

    final price = await showDialog<double>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text(
            "Your Service Charge",
            style: TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),

          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "Enter the amount you want to "
                "charge for this service.",
              ),

              const SizedBox(height: 15),

              TextField(
                controller: priceController,
                keyboardType:
                    const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  prefixText: "₹ ",
                  hintText: "Enter your charge",
                  border: OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),

          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text("Cancel"),
            ),

            ElevatedButton(
              onPressed: () {
                final value =
                    double.tryParse(
                  priceController.text.trim(),
                );

                if (value == null || value <= 0) {
                  ScaffoldMessenger.of(context)
                      .showSnackBar(
                    const SnackBar(
                      content: Text(
                        "Enter a valid service charge",
                      ),
                    ),
                  );

                  return;
                }

                Navigator.pop(context, value);
              },
              child: const Text(
                "Send Offer",
              ),
            ),
          ],
        );
      },
    );

    // ----------------------------------------------------------
    // User cancelled dialog
    // ----------------------------------------------------------

    if (price == null) {
      priceController.dispose();
      return;
    }

    try {
      // --------------------------------------------------------
      // Get service request
      // --------------------------------------------------------

      DatabaseReference requestRef =
          FirebaseDatabase.instance.ref(
        "services/$requestId",
      );

      DataSnapshot snapshot =
          await requestRef.get();

      if (!snapshot.exists) {
        throw Exception(
          "Service request no longer exists.",
        );
      }

      if (snapshot.value is! Map) {
        throw Exception(
          "Invalid service request data.",
        );
      }

      final data =
          Map<String, dynamic>.from(
        snapshot.value as Map,
      );

      // --------------------------------------------------------
      // Check request status again
      // --------------------------------------------------------

      if (data["status"] != "pending") {
        if (!mounted) return;

        ScaffoldMessenger.of(context)
            .showSnackBar(
          const SnackBar(
            content: Text(
              "This service is no longer available.",
            ),
            backgroundColor: Colors.orange,
          ),
        );

        return;
      }

      // --------------------------------------------------------
      // Get urgent service fee
      //
      // Supports your current Firebase field:
      // emergencyCharge
      //
      // Also supports future field:
      // urgentServiceFee
      // --------------------------------------------------------

      final double urgentFee =
          double.tryParse(
                "${data["urgentServiceFee"] ??
                    data["emergencyCharge"] ??
                    199}",
              ) ??
              199;

      // --------------------------------------------------------
      // Calculate final price
      // --------------------------------------------------------

      final double finalPrice =
          urgentFee + price;

      // --------------------------------------------------------
      // Save worker application
      // --------------------------------------------------------

      await applicationRef.set({
        "workerId": user.uid,
        "workerServiceCharge": price,
        "urgentServiceFee": urgentFee,
        "finalPrice": finalPrice,
        "status": "applied",
        "createdAt":
            DateTime.now().toIso8601String(),
      });

      // --------------------------------------------------------
      // Success message
      // --------------------------------------------------------

      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            "Offer sent. Total ₹${finalPrice.toStringAsFixed(0)}",
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            "Failed to send offer: $e",
          ),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      priceController.dispose();
    }
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          const Color(0xffF8FAFC),

      appBar: AppBar(
        title: const Text(
          "Urgent Jobs",
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),

        backgroundColor: Colors.white,

        foregroundColor: Colors.black,

        elevation: 0,
      ),

      body: loading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : urgentJobs.isEmpty
              ? const Center(
                  child: Text(
                    "No urgent jobs available",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),
                )
              : ListView.builder(
                  padding:
                      const EdgeInsets.all(16),

                  itemCount:
                      urgentJobs.length,

                  itemBuilder:
                      (context, index) {
                    return urgentJobCard(
                      urgentJobs[index],
                    );
                  },
                ),
    );
  }

  // ============================================================
  // URGENT JOB CARD
  // ============================================================

  Widget urgentJobCard(
    Map<String, dynamic> job,
  ) {
    final bool alreadyApplied =
        job["alreadyApplied"] == true;

    final Map<String, dynamic>?
        application =
        job["myApplication"];

    // ----------------------------------------------------------
    // Get worker's submitted charge
    // ----------------------------------------------------------

    double? workerCharge;

    if (application != null &&
        application["workerServiceCharge"] !=
            null) {
      workerCharge =
          double.tryParse(
        application["workerServiceCharge"]
            .toString(),
      );
    }

    // ----------------------------------------------------------
    // Get worker's final offer
    // ----------------------------------------------------------

    double? finalPrice;

    if (application != null &&
        application["finalPrice"] != null) {
      finalPrice =
          double.tryParse(
        application["finalPrice"].toString(),
      );
    }

    // ----------------------------------------------------------
    // Urgent service fee
    // ----------------------------------------------------------

    final double urgentFee =
        double.tryParse(
              "${job["urgentServiceFee"] ??
                  job["emergencyCharge"] ??
                  199}",
            ) ??
            199;

    return Container(
      margin:
          const EdgeInsets.only(bottom: 16),

      padding:
          const EdgeInsets.all(20),

      decoration: BoxDecoration(
        color: Colors.white,

        borderRadius:
            BorderRadius.circular(25),

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
          // ====================================================
          // HEADER
          // ====================================================

          Row(
            children: [
              Container(
                height: 50,
                width: 50,

                decoration:
                    BoxDecoration(
                  color:
                      Colors.red.shade50,

                  shape:
                      BoxShape.circle,
                ),

                child: const Icon(
                  Icons.warning,
                  color: Colors.red,
                ),
              ),

              const SizedBox(width: 15),

              Expanded(
                child: Text(
                  job["serviceName"] ??
                      "Urgent Service",

                  style:
                      const TextStyle(
                    fontSize: 18,
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 15),

          // ====================================================
          // DESCRIPTION
          // ====================================================

          Text(
            job["description"] ?? "",

            style:
                const TextStyle(
              fontSize: 15,
              height: 1.4,
            ),
          ),

          const SizedBox(height: 15),

          // ====================================================
          // LOCATION
          // ====================================================

          Row(
            crossAxisAlignment:
                CrossAxisAlignment.start,

            children: [
              const Icon(
                Icons.location_on,
                size: 18,
                color: Colors.red,
              ),

              const SizedBox(width: 5),

              Expanded(
                child: Text(
                  job["location"] ?? "",

                  style:
                      const TextStyle(
                    color: Colors.grey,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // ====================================================
          // URGENT LABEL
          // ====================================================

          Container(
            padding:
                const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 7,
            ),

            decoration:
                BoxDecoration(
              color:
                  Colors.red.shade50,

              borderRadius:
                  BorderRadius.circular(20),
            ),

            child: const Text(
              "🚨 URGENT",

              style:
                  TextStyle(
                color: Colors.red,
                fontWeight:
                    FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),

          const SizedBox(height: 15),

          // ====================================================
          // URGENT SERVICE FEE
          // ====================================================

          Container(
            width: double.infinity,

            padding:
                const EdgeInsets.all(15),

            decoration:
                BoxDecoration(
              color:
                  const Color(0xffFFF7ED),

              borderRadius:
                  BorderRadius.circular(15),

              border: Border.all(
                color:
                    const Color(0xffFED7AA),
              ),
            ),

            child: Row(
              children: [
                Container(
                  height: 38,
                  width: 38,

                  decoration:
                      BoxDecoration(
                    color:
                        const Color(
                      0xffFFEDD5,
                    ),

                    borderRadius:
                        BorderRadius.circular(
                      10,
                    ),
                  ),

                  child: const Icon(
                    Icons.flash_on,
                    color: Colors.orange,
                    size: 21,
                  ),
                ),

                const SizedBox(width: 10),

                const Expanded(
                  child: Text(
                    "Urgent Service Fee",

                    style:
                        TextStyle(
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),
                ),

                Text(
                  "₹${urgentFee.toStringAsFixed(0)}",

                  style:
                      const TextStyle(
                    fontSize: 18,
                    fontWeight:
                        FontWeight.bold,
                    color: Colors.orange,
                  ),
                ),
              ],
            ),
          ),

          // ====================================================
          // SHOW WORKER PRICE AFTER APPLYING
          // ====================================================

          if (alreadyApplied &&
              workerCharge != null) ...[
            const SizedBox(height: 12),

            _priceRow(
              "Your Service Charge",
              "₹${workerCharge.toStringAsFixed(0)}",
            ),

            const SizedBox(height: 8),

            const Divider(),

            const SizedBox(height: 8),

            _priceRow(
              "Your Total Offer",
              finalPrice != null
                  ? "₹${finalPrice.toStringAsFixed(0)}"
                  : "₹${(urgentFee + workerCharge).toStringAsFixed(0)}",
              bold: true,
            ),
          ],

          const SizedBox(height: 20),

          // ====================================================
          // APPLICATION STATUS / BUTTON
          // ====================================================

          if (alreadyApplied)
            Container(
              width: double.infinity,

              padding:
                  const EdgeInsets.symmetric(
                vertical: 13,
                horizontal: 12,
              ),

              decoration:
                  BoxDecoration(
                color:
                    Colors.green.shade50,

                borderRadius:
                    BorderRadius.circular(
                  15,
                ),

                border: Border.all(
                  color:
                      Colors.green.shade200,
                ),
              ),

              child: const Column(
                children: [
                  Text(
                    "✓ Already Applied",

                    style:
                        TextStyle(
                      color: Colors.green,
                      fontWeight:
                          FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),

                  SizedBox(height: 3),

                  Text(
                    "Waiting for customer response",

                    style:
                        TextStyle(
                      color: Colors.grey,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            )
          else
            SizedBox(
              width: double.infinity,
              height: 48,

              child: ElevatedButton(
                style:
                    ElevatedButton.styleFrom(
                  backgroundColor:
                      Colors.red,

                  foregroundColor:
                      Colors.white,

                  elevation: 0,

                  shape:
                      RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(
                      15,
                    ),
                  ),
                ),

                onPressed: () {
                  sendWorkerOffer(
                    job["id"].toString(),
                  );
                },

                child: const Text(
                  "Send Price Offer",

                  style:
                      TextStyle(
                    fontSize: 15,
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ============================================================
  // PRICE ROW
  // ============================================================

  Widget _priceRow(
    String title,
    String amount, {
    bool bold = false,
  }) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,

            style: TextStyle(
              fontSize: 14,

              fontWeight: bold
                  ? FontWeight.bold
                  : FontWeight.normal,
            ),
          ),
        ),

        Text(
          amount,

          style: TextStyle(
            fontSize: bold ? 17 : 15,

            fontWeight: bold
                ? FontWeight.bold
                : FontWeight.w600,

            color: bold
                ? Colors.green.shade700
                : Colors.black,
          ),
        ),
      ],
    );
  }
}
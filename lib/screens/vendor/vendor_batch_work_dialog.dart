import 'dart:math';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

const Color primaryColor = Color(0xff2563EB);

class VendorBatchWorkDialog extends StatefulWidget {
  final Map<String, dynamic> batch;

  const VendorBatchWorkDialog({
    super.key,
    required this.batch,
  });

  @override
  State<VendorBatchWorkDialog> createState() =>
      _VendorBatchWorkDialogState();
}

class _VendorBatchWorkDialogState
    extends State<VendorBatchWorkDialog>
    with SingleTickerProviderStateMixin {
  final DatabaseReference database =
      FirebaseDatabase.instance.ref();

  bool loading = true;

  List<Map<String, dynamic>> participants = [];

  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    _loadParticipants();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  // ============================================================
  // LOAD PARTICIPANTS
  // ============================================================

  Future<void> _loadParticipants() async {
    try {
      final apartmentKey =
          widget.batch["apartmentKey"]?.toString() ?? "";

      final serviceId =
          widget.batch["serviceId"]?.toString() ?? "";

      if (apartmentKey.isEmpty || serviceId.isEmpty) {
        return;
      }

      final snapshot = await database
          .child("societyServiceBatches")
          .child(apartmentKey)
          .child(serviceId)
          .child("participants")
          .get();

      if (!snapshot.exists || snapshot.value == null) {
        if (!mounted) return;

        setState(() {
          participants = [];
          loading = false;
        });

        return;
      }

      final participantsMap =
          Map<String, dynamic>.from(
        snapshot.value as Map,
      );

      final List<Map<String, dynamic>> loaded = [];

      for (final entry in participantsMap.entries) {
        if (entry.value is! Map) continue;

        final data =
            Map<String, dynamic>.from(
          entry.value as Map,
        );

        loaded.add({
          "customerUid": entry.key.toString(),
          ...data,
        });
      }

      // Sort flats alphabetically/numerically
      loaded.sort((a, b) {
        final flatA =
            a["flatNumber"]?.toString() ?? "";

        final flatB =
            b["flatNumber"]?.toString() ?? "";

        return flatA.compareTo(flatB);
      });

      if (!mounted) return;

      setState(() {
        participants = loaded;
        loading = false;
      });

      _animationController.forward(from: 0);
    } catch (e) {
      debugPrint(
        "LOAD PARTICIPANTS ERROR: $e",
      );

      if (!mounted) return;

      setState(() {
        loading = false;
      });
    }
  }

  // ============================================================
  // GENERATE 4 DIGIT OTP
  // ============================================================

  String _generateOtp() {
    final random = Random();

    return (1000 + random.nextInt(9000)).toString();
  }

  // ============================================================
  // DATABASE REFERENCE FOR PARTICIPANT
  // ============================================================

  DatabaseReference _participantRef(
    String customerUid,
  ) {
    final apartmentKey =
        widget.batch["apartmentKey"]?.toString() ?? "";

    final serviceId =
        widget.batch["serviceId"]?.toString() ?? "";

    return database
        .child("societyServiceBatches")
        .child(apartmentKey)
        .child(serviceId)
        .child("participants")
        .child(customerUid);
  }

  // ============================================================
// LOCK BATCH PRICE
// ============================================================

Future<bool> _lockBatchPrice() async {
  try {
    final apartmentKey =
        widget.batch["apartmentKey"]?.toString() ?? "";

    final serviceId =
        widget.batch["serviceId"]?.toString() ?? "";

    final bidId =
        widget.batch["bidId"]?.toString() ?? "";

    if (apartmentKey.isEmpty ||
        serviceId.isEmpty ||
        bidId.isEmpty) {
      debugPrint(
        "❌ Missing batch/bid information",
      );

      return false;
    }

    final batchRef = database
        .child("societyServiceBatches")
        .child(apartmentKey)
        .child(serviceId);

    // --------------------------------------------------------
    // READ LATEST BATCH DATA
    // --------------------------------------------------------

    final batchSnapshot =
        await batchRef.get();

    if (!batchSnapshot.exists ||
        batchSnapshot.value is! Map) {
      debugPrint(
        "❌ Batch not found",
      );

      return false;
    }

    final batchData =
        Map<String, dynamic>.from(
      batchSnapshot.value as Map,
    );

    // --------------------------------------------------------
    // IF ALREADY LOCKED
    // --------------------------------------------------------

    if (batchData["priceLocked"] == true) {
      debugPrint(
        "🔒 Batch price already locked.",
      );

      return true;
    }

    // --------------------------------------------------------
    // READ VENDOR BID
    // --------------------------------------------------------

    final bidSnapshot = await batchRef
        .child("bids")
        .child(bidId)
        .get();

    if (!bidSnapshot.exists ||
        bidSnapshot.value is! Map) {
      debugPrint(
        "❌ Vendor bid not found.",
      );

      return false;
    }

    final bidData =
        Map<String, dynamic>.from(
      bidSnapshot.value as Map,
    );

    // --------------------------------------------------------
    // GET CURRENT PRICE
    // --------------------------------------------------------

    final double currentPrice =
        double.tryParse(
              bidData["currentPrice"]
                      ?.toString() ??
                  "",
            ) ??
            double.tryParse(
              bidData["bidAmount"]
                      ?.toString() ??
                  "",
            ) ??
            0;

    if (currentPrice <= 0) {
      debugPrint(
        "❌ Invalid current vendor price: $currentPrice",
      );

      return false;
    }

    debugPrint(
      "======================================",
    );

    debugPrint(
      "🔒 LOCKING BATCH PRICE",
    );

    debugPrint(
      "Apartment: $apartmentKey",
    );

    debugPrint(
      "Service: $serviceId",
    );

    debugPrint(
      "Vendor Bid: $bidId",
    );

    debugPrint(
      "Current Price: ₹$currentPrice",
    );

    debugPrint(
      "======================================",
    );

    // --------------------------------------------------------
    // LOCK PRICE
    // --------------------------------------------------------

    await batchRef.update({
      "priceLocked": true,
      "lockedPrice": currentPrice,
      "workStarted": true,
      "status": "in_progress",
      "priceLockedAt": ServerValue.timestamp,
      "updatedAt": ServerValue.timestamp,
    });

    debugPrint(
      "✅ BATCH PRICE LOCKED AT ₹$currentPrice",
    );

    return true;
  } catch (e, stackTrace) {
    debugPrint(
      "❌ LOCK BATCH PRICE ERROR: $e",
    );

    debugPrint(
      stackTrace.toString(),
    );

    return false;
  }
}

  // ============================================================
  // START WORK
  // ============================================================

  Future<void> _startWork(
    int index,
  ) async {
    final participant =
        participants[index];

    final customerUid =
        participant["customerUid"]?.toString() ?? "";

    if (customerUid.isEmpty) {
      return;
    }

    try {
      final workOtp = _generateOtp();

      await _participantRef(customerUid).update({
        "workOtp": workOtp,
        "workStarted": true,
        "workVerified": false,
        "workStatus": "otp_pending",
        "startedAt": ServerValue.timestamp,
      });

      if (!mounted) return;

      setState(() {
        participants[index] = {
          ...participants[index],
          "workOtp": workOtp,
          "workStarted": true,
          "workVerified": false,
          "workStatus": "otp_pending",
        };
      });

      _showOtpVerificationDialog(
        index: index,
        type: "work",
      );
    } catch (e) {
      debugPrint(
        "START WORK ERROR: $e",
      );

      _showMessage(
        "Unable to start work.",
        Colors.red,
      );
    }
  }

  // ============================================================
  // VERIFY WORK OTP
  // ============================================================

// ============================================================
// VERIFY WORK OTP
// ============================================================

Future<void> _verifyWorkOtp(
  int index,
  String enteredOtp,
) async {
  final participant =
      participants[index];

  final customerUid =
      participant["customerUid"]?.toString() ?? "";

  final savedOtp =
      participant["workOtp"]?.toString() ?? "";

  if (enteredOtp != savedOtp) {
    _showMessage(
      "Incorrect OTP. Please try again.",
      Colors.red,
    );
    return;
  }

  try {
    // ========================================================
    // FIRST: LOCK THE BATCH PRICE
    // ========================================================

    final priceLocked =
        await _lockBatchPrice();

    if (!priceLocked) {
      _showMessage(
        "Unable to lock the batch price. Work cannot start.",
        Colors.red,
      );

      return;
    }

    // ========================================================
    // THEN: MARK THIS FLAT'S WORK AS STARTED
    // ========================================================

    await _participantRef(customerUid).update({
      "workVerified": true,
      "workStatus": "started",
      "workStarted": true,
      "workVerifiedAt":
          ServerValue.timestamp,
    });

    if (!mounted) return;

    Navigator.pop(context);

    setState(() {
      participants[index] = {
        ...participants[index],
        "workStarted": true,
        "workVerified": true,
        "workStatus": "started",
      };
    });

    _showMessage(
      "Work started successfully! Batch price is now locked.",
      Colors.green,
    );

    // ========================================================
    // PREPARE COMPLETION OTP
    // ========================================================

    await _prepareCompletionOtp(index);
  } catch (e) {
    debugPrint(
      "VERIFY WORK OTP ERROR: $e",
    );

    _showMessage(
      "Unable to verify OTP.",
      Colors.red,
    );
  }
}
  // ============================================================
  // PREPARE COMPLETION OTP
  // ============================================================

  Future<void> _prepareCompletionOtp(
    int index,
  ) async {
    final participant =
        participants[index];

    final customerUid =
        participant["customerUid"]?.toString() ?? "";

    if (customerUid.isEmpty) {
      return;
    }

    try {
      final completionOtp = _generateOtp();

      await _participantRef(customerUid).update({
        "completionOtp": completionOtp,
        "completed": false,
        "completionStatus": "otp_pending",
      });

      if (!mounted) return;

      setState(() {
        participants[index] = {
          ...participants[index],
          "completionOtp": completionOtp,
          "completed": false,
          "completionStatus": "otp_pending",
        };
      });
    } catch (e) {
      debugPrint(
        "COMPLETION OTP ERROR: $e",
      );
    }
  }

  // ============================================================
  // VERIFY COMPLETION OTP
  // ============================================================

  Future<void> _verifyCompletionOtp(
    int index,
    String enteredOtp,
  ) async {
    final participant =
        participants[index];

    final customerUid =
        participant["customerUid"]?.toString() ?? "";

    final savedOtp =
        participant["completionOtp"]
                ?.toString() ??
            "";

    if (enteredOtp != savedOtp) {
      _showMessage(
        "Incorrect completion OTP.",
        Colors.red,
      );
      return;
    }

    try {
      await _participantRef(customerUid).update({
        "completed": true,
        "completionStatus": "completed",
        "completedAt":
            ServerValue.timestamp,
      });

      if (!mounted) return;

      Navigator.pop(context);

      setState(() {
        participants[index] = {
          ...participants[index],
          "completed": true,
          "completionStatus": "completed",
        };
      });

      _showMessage(
        "Work completed successfully!",
        Colors.green,
      );
    } catch (e) {
      debugPrint(
        "VERIFY COMPLETION OTP ERROR: $e",
      );

      _showMessage(
        "Unable to complete work.",
        Colors.red,
      );
    }
  }

  // ============================================================
  // OTP DIALOG
  // ============================================================

  void _showOtpVerificationDialog({
    required int index,
    required String type,
  }) {
    final participant =
        participants[index];

    final flatNumber =
        participant["flatNumber"]?.toString() ??
            "Flat";

    final isWork = type == "work";

    final controller =
        TextEditingController();

    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom:
                MediaQuery.of(context)
                    .viewInsets
                    .bottom,
          ),
          child: Container(
            padding: const EdgeInsets.fromLTRB(
              22,
              10,
              22,
              25,
            ),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(30),
              ),
            ),
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize:
                    MainAxisSize.min,
                children: [
                  // HANDLE
                  Container(
                    width: 45,
                    height: 5,
                    margin:
                        const EdgeInsets.only(
                      bottom: 22,
                    ),
                    decoration:
                        BoxDecoration(
                      color:
                          const Color(0xffCBD5E1),
                      borderRadius:
                          BorderRadius.circular(
                        20,
                      ),
                    ),
                  ),

                  // ICON
                  Container(
                    height: 72,
                    width: 72,
                    decoration:
                        BoxDecoration(
                      color: isWork
                          ? const Color(
                              0xffDBEAFE,
                            )
                          : const Color(
                              0xffDCFCE7,
                            ),
                      shape:
                          BoxShape.circle,
                    ),
                    child: Icon(
                      isWork
                          ? Icons.lock_open_rounded
                          : Icons.verified_rounded,
                      color: isWork
                          ? primaryColor
                          : Colors.green,
                      size: 36,
                    ),
                  ),

                  const SizedBox(
                    height: 15,
                  ),

                  Text(
                    isWork
                        ? "Verify Start Work"
                        : "Verify Completion",
                    style:
                        const TextStyle(
                      fontSize: 21,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),

                  const SizedBox(
                    height: 6,
                  ),

                  Text(
                    "Flat $flatNumber",
                    style: TextStyle(
                      color:
                          Colors.grey.shade600,
                      fontSize: 14,
                    ),
                  ),

                  const SizedBox(
                    height: 18,
                  ),

                  Text(
                    isWork
                        ? "Ask the resident for the 4-digit work OTP."
                        : "Ask the resident for the 4-digit completion OTP.",
                    textAlign:
                        TextAlign.center,
                    style: TextStyle(
                      color:
                          Colors.grey.shade600,
                      height: 1.4,
                    ),
                  ),

                  const SizedBox(
                    height: 20,
                  ),

                  TextFormField(
                    controller: controller,
                    keyboardType:
                        TextInputType.number,
                    maxLength: 4,
                    textAlign:
                        TextAlign.center,
                    style:
                        const TextStyle(
                      fontSize: 28,
                      fontWeight:
                          FontWeight.bold,
                      letterSpacing: 10,
                    ),
                    decoration:
                        InputDecoration(
                      counterText: "",
                      hintText: "••••",
                      filled: true,
                      fillColor:
                          const Color(
                        0xffF8FAFC,
                      ),
                      border:
                          OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(
                          16,
                        ),
                        borderSide:
                            const BorderSide(
                          color:
                              Color(0xffE2E8F0),
                        ),
                      ),
                      enabledBorder:
                          OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(
                          16,
                        ),
                        borderSide:
                            const BorderSide(
                          color:
                              Color(0xffE2E8F0),
                        ),
                      ),
                      focusedBorder:
                          OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(
                          16,
                        ),
                        borderSide:
                            const BorderSide(
                          color:
                              primaryColor,
                          width: 2,
                        ),
                      ),
                    ),
                    validator: (value) {
                      if (value == null ||
                          value.length != 4) {
                        return "Enter 4-digit OTP";
                      }

                      return null;
                    },
                  ),

                  const SizedBox(
                    height: 12,
                  ),

                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: () {
                        if (!formKey
                            .currentState!
                            .validate()) {
                          return;
                        }

                        if (isWork) {
                          _verifyWorkOtp(
                            index,
                            controller.text
                                .trim(),
                          );
                        } else {
                          _verifyCompletionOtp(
                            index,
                            controller.text
                                .trim(),
                          );
                        }
                      },
                      style:
                          ElevatedButton
                              .styleFrom(
                        backgroundColor:
                            isWork
                                ? primaryColor
                                : Colors.green,
                        foregroundColor:
                            Colors.white,
                        elevation: 0,
                        shape:
                            RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius
                                  .circular(
                            16,
                          ),
                        ),
                      ),
                      child: Text(
                        isWork
                            ? "Verify & Start Work"
                            : "Verify & Complete",
                        style:
                            const TextStyle(
                          fontWeight:
                              FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ============================================================
  // PARTICIPANT CARD
  // ============================================================

  Widget _buildParticipantCard(
    Map<String, dynamic> participant,
    int index,
  ) {
    final flatNumber =
        participant["flatNumber"]?.toString() ??
            "Unknown";

    final workStarted =
        participant["workStarted"] == true;

    final workVerified =
        participant["workVerified"] == true;

    final completed =
        participant["completed"] == true;

    Color statusColor;
    IconData statusIcon;
    String statusText;

    if (completed) {
      statusColor = Colors.green;
      statusIcon =
          Icons.check_circle_rounded;
      statusText = "Completed";
    } else if (workVerified) {
      statusColor = Colors.blue;
      statusIcon =
          Icons.construction_rounded;
      statusText = "Work in Progress";
    } else if (workStarted) {
      statusColor = Colors.orange;
      statusIcon =
          Icons.lock_clock_rounded;
      statusText = "OTP Verification";
    } else {
      statusColor =
          const Color(0xff64748B);
      statusIcon =
          Icons.schedule_rounded;
      statusText = "Not Started";
    }

    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        final animation =
            CurvedAnimation(
          parent: _animationController,
          curve: Curves.easeOutCubic,
        );

        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position:
                Tween<Offset>(
              begin:
                  const Offset(0, 0.08),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          ),
        );
      },
      child: Container(
        margin:
            const EdgeInsets.only(
          bottom: 13,
        ),
        padding:
            const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius:
              BorderRadius.circular(20),
          border: Border.all(
            color:
                const Color(0xffE2E8F0),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black
                  .withOpacity(0.04),
              blurRadius: 12,
              offset:
                  const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              children: [
                // FLAT ICON
                Container(
                  height: 52,
                  width: 52,
                  decoration:
                      BoxDecoration(
                    color:
                        const Color(
                      0xffEFF6FF,
                    ),
                    borderRadius:
                        BorderRadius.circular(
                      15,
                    ),
                  ),
                  child: const Icon(
                    Icons
                        .home_work_rounded,
                    color:
                        primaryColor,
                    size: 26,
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
                        "Flat $flatNumber",
                        style:
                            const TextStyle(
                          fontSize: 17,
                          fontWeight:
                              FontWeight.bold,
                        ),
                      ),

                      const SizedBox(
                        height: 5,
                      ),

                      Row(
                        children: [
                          Icon(
                            statusIcon,
                            size: 15,
                            color:
                                statusColor,
                          ),
                          const SizedBox(
                            width: 5,
                          ),
                          Text(
                            statusText,
                            style:
                                TextStyle(
                              color:
                                  statusColor,
                              fontSize: 12,
                              fontWeight:
                                  FontWeight
                                      .w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                _buildStatusIcon(
                  completed: completed,
                  workVerified:
                      workVerified,
                ),
              ],
            ),

            const SizedBox(
              height: 14,
            ),

            // ACTION
            if (!workStarted)
              _buildActionButton(
                label: "Start Work",
                icon:
                    Icons.play_arrow_rounded,
                color: primaryColor,
                onPressed: () {
                  _startWork(index);
                },
              )
            else if (workStarted &&
                !workVerified)
              _buildActionButton(
                label: "Enter Start OTP",
                icon:
                    Icons.lock_open_rounded,
                color: Colors.orange,
                onPressed: () {
                  _showOtpVerificationDialog(
                    index: index,
                    type: "work",
                  );
                },
              )
            else if (workVerified &&
                !completed)
              _buildActionButton(
                label: "Enter Completion OTP",
                icon:
                    Icons.verified_rounded,
                color: Colors.green,
                onPressed: () {
                  _showOtpVerificationDialog(
                    index: index,
                    type: "completion",
                  );
                },
              )
            else
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(
                  vertical: 13,
                ),
                decoration:
                    BoxDecoration(
                  color:
                      const Color(
                    0xffECFDF5,
                  ),
                  borderRadius:
                      BorderRadius.circular(
                    14,
                  ),
                ),
                child: const Row(
                  mainAxisAlignment:
                      MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons
                          .check_circle_rounded,
                      color:
                          Colors.green,
                      size: 19,
                    ),
                    SizedBox(width: 7),
                    Text(
                      "Work Completed",
                      style:
                          TextStyle(
                        color:
                            Colors.green,
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // STATUS ICON
  // ============================================================

  Widget _buildStatusIcon({
    required bool completed,
    required bool workVerified,
  }) {
    if (completed) {
      return Container(
        height: 38,
        width: 38,
        decoration:
            const BoxDecoration(
          color:
              Color(0xffDCFCE7),
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.check_rounded,
          color: Colors.green,
        ),
      );
    }

    if (workVerified) {
      return Container(
        height: 38,
        width: 38,
        decoration:
            const BoxDecoration(
          color:
              Color(0xffDBEAFE),
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.build_rounded,
          color: primaryColor,
        ),
      );
    }

    return Container(
      height: 38,
      width: 38,
      decoration:
          const BoxDecoration(
        color:
            Color(0xffF1F5F9),
        shape: BoxShape.circle,
      ),
      child: const Icon(
        Icons.arrow_forward_ios_rounded,
        size: 15,
        color:
            Color(0xff64748B),
      ),
    );
  }

  // ============================================================
  // ACTION BUTTON
  // ============================================================

  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(
          icon,
          size: 20,
        ),
        label: Text(
          label,
          style: const TextStyle(
            fontWeight:
                FontWeight.bold,
          ),
        ),
        style:
            ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor:
              Colors.white,
          elevation: 0,
          shape:
              RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(
              14,
            ),
          ),
        ),
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
        content: Text(message),
        backgroundColor: color,
        behavior:
            SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(
          borderRadius:
              BorderRadius.circular(12),
        ),
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final serviceName =
        widget.batch["serviceName"]
                ?.toString() ??
            "Service";

    final apartmentName =
        widget.batch["apartmentName"]
                ?.toString() ??
            "Apartment";

    final completedCount =
        participants
            .where(
              (p) =>
                  p["completed"] == true,
            )
            .length;

    final totalCount =
        participants.length;

    return Container(
      height:
          MediaQuery.of(context).size.height *
              0.90,
      decoration:
          const BoxDecoration(
        color:
            Color(0xffF8FAFC),
        borderRadius:
            BorderRadius.vertical(
          top: Radius.circular(30),
        ),
      ),
      child: Column(
        children: [
          // ====================================================
          // HEADER
          // ====================================================

          Container(
            padding:
                const EdgeInsets.fromLTRB(
              20,
              10,
              20,
              18,
            ),
            decoration:
                const BoxDecoration(
              color: Colors.white,
              borderRadius:
                  BorderRadius.vertical(
                top:
                    Radius.circular(30),
              ),
            ),
            child: Column(
              children: [
                Container(
                  width: 45,
                  height: 5,
                  decoration:
                      BoxDecoration(
                    color:
                        const Color(
                      0xffCBD5E1,
                    ),
                    borderRadius:
                        BorderRadius.circular(
                      10,
                    ),
                  ),
                ),

                const SizedBox(
                  height: 18,
                ),

                Row(
                  children: [
                    Container(
                      height: 50,
                      width: 50,
                      decoration:
                          BoxDecoration(
                        color:
                            const Color(
                          0xffDBEAFE,
                        ),
                        borderRadius:
                            BorderRadius.circular(
                          15,
                        ),
                      ),
                      child:
                          const Icon(
                        Icons
                            .engineering_rounded,
                        color:
                            primaryColor,
                        size: 27,
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
                            serviceName,
                            maxLines: 1,
                            overflow:
                                TextOverflow
                                    .ellipsis,
                            style:
                                const TextStyle(
                              fontSize: 18,
                              fontWeight:
                                  FontWeight
                                      .bold,
                            ),
                          ),
                          const SizedBox(
                            height: 3,
                          ),
                          Text(
                            apartmentName,
                            maxLines: 1,
                            overflow:
                                TextOverflow
                                    .ellipsis,
                            style:
                                TextStyle(
                              color: Colors
                                  .grey
                                  .shade600,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),

                    IconButton(
                      onPressed: () {
                        Navigator.pop(
                          context,
                        );
                      },
                      icon:
                          const Icon(
                        Icons.close_rounded,
                      ),
                    ),
                  ],
                ),

                const SizedBox(
                  height: 15,
                ),

                // PROGRESS
                Container(
                  padding:
                      const EdgeInsets.all(
                    13,
                  ),
                  decoration:
                      BoxDecoration(
                    color:
                        const Color(
                      0xffF8FAFC,
                    ),
                    borderRadius:
                        BorderRadius.circular(
                      15,
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons
                            .groups_rounded,
                        color:
                            primaryColor,
                        size: 20,
                      ),

                      const SizedBox(
                        width: 8,
                      ),

                      Expanded(
                        child: Text(
                          "$completedCount of $totalCount flats completed",
                          style:
                              const TextStyle(
                            fontWeight:
                                FontWeight
                                    .w600,
                            fontSize: 13,
                          ),
                        ),
                      ),

                      if (totalCount > 0)
                        Text(
                          "${((completedCount / totalCount) * 100).toInt()}%",
                          style:
                              const TextStyle(
                            color:
                                primaryColor,
                            fontWeight:
                                FontWeight
                                    .bold,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ====================================================
          // PARTICIPANTS
          // ====================================================

          Expanded(
            child: loading
                ? const Center(
                    child:
                        CircularProgressIndicator(
                      color:
                          primaryColor,
                    ),
                  )
                : participants.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        physics:
                            const BouncingScrollPhysics(),
                        padding:
                            const EdgeInsets
                                .fromLTRB(
                          16,
                          16,
                          16,
                          30,
                        ),
                        itemCount:
                            participants.length,
                        itemBuilder:
                            (context, index) {
                          return _buildParticipantCard(
                            participants[
                                index],
                            index,
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // EMPTY
  // ============================================================

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding:
            const EdgeInsets.all(30),
        child: Column(
          mainAxisAlignment:
              MainAxisAlignment.center,
          children: [
            Container(
              height: 90,
              width: 90,
              decoration:
                  const BoxDecoration(
                color:
                    Color(0xffDBEAFE),
                shape: BoxShape.circle,
              ),
              child:
                  const Icon(
                Icons
                    .home_work_outlined,
                color:
                    primaryColor,
                size: 42,
              ),
            ),
            const SizedBox(
              height: 18,
            ),
            const Text(
              "No flats found",
              style:
                  TextStyle(
                fontSize: 19,
                fontWeight:
                    FontWeight.bold,
              ),
            ),
            const SizedBox(
              height: 7,
            ),
            Text(
              "There are no residents in this service batch.",
              textAlign:
                  TextAlign.center,
              style: TextStyle(
                color:
                    Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
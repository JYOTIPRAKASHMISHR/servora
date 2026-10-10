import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:servora/services/payment_api_service.dart';

class WorkerActiveJobsScreen extends StatefulWidget {
  const WorkerActiveJobsScreen({super.key});

  @override
  State<WorkerActiveJobsScreen> createState() =>
      _WorkerActiveJobsScreenState();
}

class _WorkerActiveJobsScreenState
    extends State<WorkerActiveJobsScreen> {
  // =============================================================
  // FIREBASE
  // =============================================================

  final DatabaseReference servicesRef =
      FirebaseDatabase.instance.ref("services");

  final DatabaseReference usersRef =
      FirebaseDatabase.instance.ref("users");

  final DatabaseReference notificationsRef =
      FirebaseDatabase.instance.ref("notifications");

  final User? currentUser =
      FirebaseAuth.instance.currentUser;

  // =============================================================
  // STATE
  // =============================================================

  List<Map<String, dynamic>> activeJobs = [];

  bool loading = true;

  StreamSubscription? subscription;

  /// Prevent multiple operations on same service.
  final Set<String> processingJobs = {};

  /// OTP input controllers.
  final Map<String, TextEditingController> otpControllers = {};

  // =============================================================
  // RANDOM OTP GENERATOR
  // =============================================================

  final Random _random = Random();

  String _generate4DigitOtp() {
    return (1000 + _random.nextInt(9000)).toString();
  }

  // =============================================================
  // INIT
  // =============================================================

  @override
  void initState() {
    super.initState();
    listenWorkerJobs();
  }

  // =============================================================
  // DISPOSE
  // =============================================================

  @override
  void dispose() {
    subscription?.cancel();

    for (final controller in otpControllers.values) {
      controller.dispose();
    }

    otpControllers.clear();

    super.dispose();
  }

  // =============================================================
  // OTP CONTROLLER
  // =============================================================

  TextEditingController otpControllerFor(
    String serviceId,
  ) {
    if (!otpControllers.containsKey(serviceId)) {
      otpControllers[serviceId] =
          TextEditingController();
    }

    return otpControllers[serviceId]!;
  }

  // =============================================================
  // LISTEN WORKER JOBS
  // =============================================================

  void listenWorkerJobs() {
    if (currentUser == null) {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
      return;
    }

    subscription =
        servicesRef.onValue.listen((event) {
      if (!mounted) {
        return;
      }

      if (!event.snapshot.exists) {
        setState(() {
          activeJobs = [];
          loading = false;
        });
        return;
      }

      final rawData = event.snapshot.value;

      if (rawData is! Map) {
        setState(() {
          activeJobs = [];
          loading = false;
        });
        return;
      }

      final Map data = Map.from(rawData);

      final List<Map<String, dynamic>> temp = [];

      data.forEach((key, value) {
        if (value is! Map) {
          return;
        }

        final Map<String, dynamic> service =
            Map<String, dynamic>.from(value);

        final String assignedWorkerId =
            service["assignedWorkerId"]
                    ?.toString() ??
                "";

        final String status =
            service["status"]?.toString() ??
                "assigned";

        // =========================================================
        // ACTIVE JOBS
        //
        // completed jobs disappear.
        // payment_pending remains visible.
        // =========================================================

        if (assignedWorkerId ==
                currentUser!.uid &&
            status != "completed") {
          temp.add({
            "serviceId": key.toString(),
            ...service,
          });
        }
      });

      // ===========================================================
      // NEWEST FIRST
      // ===========================================================

      temp.sort((a, b) {
        final dynamic aTime =
            a["acceptedAt"] ??
                a["createdAt"] ??
                0;

        final dynamic bTime =
            b["acceptedAt"] ??
                b["createdAt"] ??
                0;

        final int aNumber =
            int.tryParse(
                  aTime.toString(),
                ) ??
                0;

        final int bNumber =
            int.tryParse(
                  bTime.toString(),
                ) ??
                0;

        return bNumber.compareTo(aNumber);
      });

      setState(() {
        activeJobs = temp;
        loading = false;
      });
    });
  }

  // =============================================================
  // BUILD
  // =============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          const Color(0xffF4F7FB),
      appBar: buildAppBar(),
      body: loading
          ? buildLoading()
          : activeJobs.isEmpty
              ? emptyJobs()
              : RefreshIndicator(
                  color:
                      const Color(0xff2563EB),
                  onRefresh: () async {
                    await Future.delayed(
                      const Duration(
                        milliseconds: 500,
                      ),
                    );
                  },
                  child: ListView.builder(
                    physics:
                        const AlwaysScrollableScrollPhysics(
                      parent:
                          BouncingScrollPhysics(),
                    ),
                    padding:
                        const EdgeInsets.fromLTRB(
                      16,
                      18,
                      16,
                      35,
                    ),
                    itemCount:
                        activeJobs.length,
                    itemBuilder:
                        (context, index) {
                      return buildJobCard(
                        activeJobs[index],
                        index,
                      );
                    },
                  ),
                ),
    );
  }

  // =============================================================
  // LOADING
  // =============================================================

  Widget buildLoading() {
    return Center(
      child: Column(
        mainAxisAlignment:
            MainAxisAlignment.center,
        children: [
          Container(
            height: 82,
            width: 82,
            decoration: BoxDecoration(
              gradient:
                  const LinearGradient(
                colors: [
                  Color(0xff2563EB),
                  Color(0xff38BDF8),
                ],
              ),
              borderRadius:
                  BorderRadius.circular(26),
              boxShadow: [
                BoxShadow(
                  color:
                      const Color(
                    0xff2563EB,
                  ).withOpacity(.30),
                  blurRadius: 25,
                  offset:
                      const Offset(0, 12),
                ),
              ],
            ),
            child: const Icon(
              Icons.work_history_rounded,
              color: Colors.white,
              size: 42,
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
                    const Offset(.92, .92),
                end:
                    const Offset(1.05, 1.05),
                duration: 900.ms,
              ),
          const SizedBox(height: 22),
          const Text(
            "Loading your jobs...",
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: Color(0xff0F172A),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            "Please wait",
            style: TextStyle(
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  // =============================================================
  // APP BAR
  // =============================================================

  PreferredSizeWidget buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      foregroundColor:
          const Color(0xff0F172A),
      elevation: 0,
      centerTitle: false,
      titleSpacing: 18,
      title: const Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Text(
            "Active Jobs",
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 21,
              letterSpacing: -.4,
            ),
          ),
          SizedBox(height: 3),
          Text(
            "Manage your assigned services",
            style: TextStyle(
              color: Colors.grey,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
      bottom: PreferredSize(
        preferredSize:
            const Size.fromHeight(1),
        child: Container(
          height: 1,
          color:
              const Color(0xffE5E7EB),
        ),
      ),
    );
  }

  // =============================================================
  // JOB CARD
  // =============================================================

  Widget buildJobCard(
    Map<String, dynamic> job,
    int index,
  ) {
    final String status =
        job["status"]?.toString() ??
            "assigned";

    return _Animated3DCard(
      delay: index * 80,
      child: Container(
        margin:
            const EdgeInsets.only(bottom: 18),
        padding:
            const EdgeInsets.all(19),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius:
              BorderRadius.circular(28),
          border: Border.all(
            color:
                const Color(0xffE8EEF7),
          ),
          boxShadow: [
            BoxShadow(
              color:
                  Colors.black.withOpacity(.055),
              blurRadius: 22,
              offset:
                  const Offset(0, 10),
            ),
            BoxShadow(
              color:
                  _statusColor(status)
                      .withOpacity(.08),
              blurRadius: 35,
              offset:
                  const Offset(0, 14),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            // =====================================================
            // HEADER
            // =====================================================

            Row(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        height: 50,
                        width: 50,
                        decoration:
                            BoxDecoration(
                          gradient:
                              const LinearGradient(
                            colors: [
                              Color(0xff2563EB),
                              Color(0xff38BDF8),
                            ],
                          ),
                          borderRadius:
                              BorderRadius.circular(
                            16,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color:
                                  const Color(
                                0xff2563EB,
                              ).withOpacity(.25),
                              blurRadius: 12,
                              offset:
                                  const Offset(
                                0,
                                6,
                              ),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons
                              .handyman_rounded,
                          color: Colors.white,
                          size: 26,
                        ),
                      )
                          .animate(
                            onPlay:
                                (controller) =>
                                    controller.repeat(
                              reverse: true,
                            ),
                          )
                          .moveY(
                            begin: 0,
                            end: -3,
                            duration:
                                1200.ms,
                          ),
                      const SizedBox(
                        width: 13,
                      ),
                      Expanded(
                        child: Text(
                          job["title"] ??
                              "Service Request",
                          maxLines: 2,
                          overflow:
                              TextOverflow.ellipsis,
                          style:
                              const TextStyle(
                            fontSize: 18,
                            fontWeight:
                                FontWeight.w800,
                            color:
                                Color(0xff0F172A),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                statusBadge(status),
              ],
            ),

            const SizedBox(height: 20),

            customerInfo(job),

            const SizedBox(height: 16),

            priceCard(job),

            const SizedBox(height: 16),

            serviceDetails(job),

            const SizedBox(height: 18),

            // =====================================================
            // OTP SECTION
            // =====================================================

            buildOtpSection(job),

            const SizedBox(height: 18),

            // =====================================================
            // ACTION
            // =====================================================

            jobActionButton(job),
          ],
        ),
      ),
    );
  }

  // =============================================================
  // CUSTOMER INFO
  // =============================================================

  Widget customerInfo(
    Map<String, dynamic> job,
  ) {
    final String customerId =
        job["customerId"]?.toString() ??
            "";

    return Container(
      padding:
          const EdgeInsets.all(15),
      decoration: BoxDecoration(
        gradient:
            const LinearGradient(
          colors: [
            Color(0xffF8FAFC),
            Color(0xffF1F5F9),
          ],
        ),
        borderRadius:
            BorderRadius.circular(20),
        border: Border.all(
          color:
              const Color(0xffE2E8F0),
        ),
      ),
      child: Row(
        children: [
          Container(
            height: 52,
            width: 52,
            decoration:
                BoxDecoration(
              gradient:
                  const LinearGradient(
                colors: [
                  Color(0xffDBEAFE),
                  Color(0xffBFDBFE),
                ],
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color:
                      const Color(
                    0xff2563EB,
                  ).withOpacity(.12),
                  blurRadius: 10,
                  offset:
                      const Offset(0, 5),
                ),
              ],
            ),
            child: const Icon(
              Icons.person_rounded,
              color:
                  Color(0xff2563EB),
              size: 29,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child:
                FutureBuilder<DataSnapshot>(
              future: customerId.isEmpty
                  ? null
                  : usersRef
                      .child(customerId)
                      .get(),
              builder:
                  (context, snapshot) {
                if (!snapshot.hasData ||
                    snapshot.data!.value ==
                        null) {
                  return const Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Customer",
                        style: TextStyle(
                          fontWeight:
                              FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        "Customer information",
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  );
                }

                if (snapshot.data!.value
                    is! Map) {
                  return const Text(
                    "Customer",
                  );
                }

                final Map customer =
                    Map.from(
                  snapshot.data!.value
                      as Map,
                );

                return Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      customer["name"] ??
                          "Customer",
                      maxLines: 1,
                      overflow:
                          TextOverflow.ellipsis,
                      style:
                          const TextStyle(
                        fontWeight:
                            FontWeight.w800,
                        fontSize: 16,
                        color:
                            Color(0xff0F172A),
                      ),
                    ),
                    const SizedBox(height: 5),
                    if ((customer["phone"] ??
                            "")
                        .toString()
                        .isNotEmpty)
                      Row(
                        children: [
                          const Icon(
                            Icons.phone_outlined,
                            size: 14,
                            color: Colors.grey,
                          ),
                          const SizedBox(
                              width: 5),
                          Expanded(
                            child: Text(
                              customer["phone"]
                                  .toString(),
                              maxLines: 1,
                              overflow:
                                  TextOverflow
                                      .ellipsis,
                              style:
                                  const TextStyle(
                                color:
                                    Colors.grey,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // =============================================================
  // PRICE CARD
  // =============================================================

  Widget priceCard(
    Map<String, dynamic> job,
  ) {
    final dynamic price =
        job["finalPrice"] ??
            job["budget"] ??
            0;

    return Container(
      padding:
          const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient:
            const LinearGradient(
          colors: [
            Color(0xffECFDF5),
            Color(0xffD1FAE5),
          ],
        ),
        borderRadius:
            BorderRadius.circular(20),
        border: Border.all(
          color:
              const Color(0xffA7F3D0),
        ),
        boxShadow: [
          BoxShadow(
            color:
                Colors.green.withOpacity(.07),
            blurRadius: 12,
            offset:
                const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            height: 48,
            width: 48,
            decoration:
                BoxDecoration(
              color: Colors.white,
              borderRadius:
                  BorderRadius.circular(15),
            ),
            child: const Icon(
              Icons
                  .currency_rupee_rounded,
              color: Colors.green,
              size: 25,
            ),
          ),
          const SizedBox(width: 13),
          Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              const Text(
                "Final Price",
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 12,
                  fontWeight:
                      FontWeight.w600,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                "₹$price",
                style:
                    const TextStyle(
                  fontSize: 22,
                  fontWeight:
                      FontWeight.w900,
                  color: Colors.green,
                ),
              ),
            ],
          ),
          const Spacer(),
          const Icon(
            Icons.verified_rounded,
            color: Colors.green,
            size: 24,
          ),
        ],
      ),
    );
  }

  // =============================================================
  // SERVICE DETAILS
  // =============================================================

  Widget serviceDetails(
    Map<String, dynamic> job,
  ) {
    return Container(
      padding:
          const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color:
            const Color(0xffFAFAFA),
        borderRadius:
            BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          detailRow(
            Icons.location_on_rounded,
            "Location",
            job["location"]?.toString() ??
                "Not added",
          ),
          const SizedBox(height: 13),
          detailRow(
            Icons.calendar_month_rounded,
            "Accepted Date",
            job["acceptedAt"]
                    ?.toString() ??
                "Not available",
          ),
        ],
      ),
    );
  }

  // =============================================================
  // DETAIL ROW
  // =============================================================

  Widget detailRow(
    IconData icon,
    String title,
    String value,
  ) {
    return Row(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Container(
          height: 38,
          width: 38,
          decoration:
              BoxDecoration(
            color:
                const Color(0xffDBEAFE),
            borderRadius:
                BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            size: 20,
            color:
                const Color(0xff2563EB),
          ),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style:
                    const TextStyle(
                  color: Colors.grey,
                  fontSize: 11,
                  fontWeight:
                      FontWeight.w600,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                value,
                maxLines: 2,
                overflow:
                    TextOverflow.ellipsis,
                style:
                    const TextStyle(
                  fontWeight:
                      FontWeight.w700,
                  color:
                      Color(0xff1E293B),
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // =============================================================
  // OTP SECTION
  // =============================================================

  Widget buildOtpSection(
    Map<String, dynamic> job,
  ) {
    final String status =
        job["status"]?.toString() ??
            "assigned";

    final String serviceId =
        job["serviceId"]?.toString() ??
            "";

    if (serviceId.isEmpty) {
      return const SizedBox.shrink();
    }

    // ===========================================================
    // START OTP
    // ===========================================================

    if (status == "assigned") {
      final String startOtp =
          job["startOtp"]?.toString() ??
              "";

      // OTP generated.
      if (startOtp.isNotEmpty) {
        return _workerOtpInputCard(
          serviceId: serviceId,
          title:
              "Enter Customer Start OTP",
          subtitle:
              "Ask the customer for the 4-digit OTP displayed in their Servora app.",
          buttonText:
              "Verify Start OTP",
          color:
              const Color(0xff2563EB),
          icon:
              Icons.lock_clock_rounded,
          onVerify: () async {
            await verifyStartOtpFromField(
              job,
            );
          },
        );
      }

      return _otpInstructionCard(
        icon:
            Icons.lock_clock_rounded,
        title:
            "Start Verification Required",
        message:
            "Generate a secure 4-digit Start OTP. "
            "The customer will see it in their Servora app. "
            "Ask the customer for the OTP and enter it below.",
        color:
            const Color(0xff2563EB),
      );
    }

    // ===========================================================
    // STARTED
    // ===========================================================

    if (status == "started") {
      return _verifiedCard(
        icon:
            Icons.play_circle_fill_rounded,
        title:
            "Start OTP Verified",
        message:
            "Customer verification is complete. "
            "You can continue working on the service.",
        color:
            const Color(0xff0284C7),
      );
    }

    // ===========================================================
    // PAYMENT PENDING
    // ===========================================================

    if (status == "payment_pending") {
      final bool completionVerified =
          job["completionOtpVerified"] ==
              true;

      if (completionVerified) {
        return _verifiedCard(
          icon:
              Icons.verified_rounded,
          title:
              "Completion OTP Verified",
          message:
              "Customer verification is complete.",
          color:
              const Color(0xff16A34A),
        );
      }

      final String completionOtp =
          job["completionOtp"]
                  ?.toString() ??
              "";

      if (completionOtp.isEmpty) {
        return _otpInstructionCard(
          icon:
              Icons.lock_clock_rounded,
          title:
              "Completion OTP Pending",
          message:
              "The completion OTP has not been generated yet.",
          color:
              const Color(0xffD97706),
        );
      }

      final String paymentStatus =
          job["paymentStatus"]
                  ?.toString() ??
              "pending";

      final bool paymentReceived =
          paymentStatus == "paid" ||
          paymentStatus ==
              "reported_paid";

      if (!paymentReceived) {
        return _otpInstructionCard(
          icon:
              Icons.payment_rounded,
          title:
              "Waiting for Customer Payment",
          message:
              "The customer must complete payment first. "
              "After payment is received, ask the customer "
              "for the Completion OTP.",
          color:
              const Color(0xffD97706),
        );
      }

      return _workerOtpInputCard(
        serviceId: serviceId,
        title:
            "Enter Customer Completion OTP",
        subtitle:
            "Payment received. Ask the customer for the 4-digit completion OTP shown in their Servora app.",
        buttonText:
            "Verify & Complete Service",
        color:
            const Color(0xff16A34A),
        icon:
            Icons.verified_user_rounded,
        onVerify: () async {
          await verifyCompletionOtpFromField(
            job,
          );
        },
      );
    }

    return const SizedBox.shrink();
  }

  // =============================================================
  // OTP INSTRUCTION CARD
  // =============================================================

  Widget _otpInstructionCard({
    required IconData icon,
    required String title,
    required String message,
    required Color color,
  }) {
    return Container(
      padding:
          const EdgeInsets.all(17),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withOpacity(.09),
            color.withOpacity(.025),
          ],
        ),
        borderRadius:
            BorderRadius.circular(22),
        border: Border.all(
          color:
              color.withOpacity(.20),
        ),
        boxShadow: [
          BoxShadow(
            color:
                color.withOpacity(.07),
            blurRadius: 18,
            offset:
                const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Container(
            height: 48,
            width: 48,
            decoration:
                BoxDecoration(
              gradient:
                  LinearGradient(
                colors: [
                  color,
                  Color.lerp(
                        color,
                        Colors.white,
                        .18,
                      ) ??
                      color,
                ],
              ),
              borderRadius:
                  BorderRadius.circular(15),
              boxShadow: [
                BoxShadow(
                  color:
                      color.withOpacity(.20),
                  blurRadius: 12,
                  offset:
                      const Offset(0, 6),
                ),
              ],
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: 25,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: color,
                    fontWeight:
                        FontWeight.w900,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  message,
                  style:
                      const TextStyle(
                    color:
                        Color(0xff475569),
                    fontSize: 12,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    )
        .animate()
        .fade(duration: 400.ms)
        .slideX(
          begin: .06,
          duration: 450.ms,
        );
  }

  // =============================================================
  // WORKER OTP INPUT
  // =============================================================

  Widget _workerOtpInputCard({
    required String serviceId,
    required String title,
    required String subtitle,
    required String buttonText,
    required Color color,
    required IconData icon,
    required Future<void> Function()
        onVerify,
  }) {
    final controller =
        otpControllerFor(serviceId);

    return Container(
      padding:
          const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withOpacity(.09),
            color.withOpacity(.025),
          ],
        ),
        borderRadius:
            BorderRadius.circular(24),
        border: Border.all(
          color:
              color.withOpacity(.22),
          width: 1.3,
        ),
        boxShadow: [
          BoxShadow(
            color:
                color.withOpacity(.10),
            blurRadius: 20,
            offset:
                const Offset(0, 10),
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
                height: 50,
                width: 50,
                decoration:
                    BoxDecoration(
                  gradient:
                      LinearGradient(
                    colors: [
                      color,
                      Color.lerp(
                            color,
                            Colors.white,
                            .18,
                          ) ??
                          color,
                    ],
                  ),
                  borderRadius:
                      BorderRadius.circular(
                    16,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color:
                          color.withOpacity(
                        .25,
                      ),
                      blurRadius: 14,
                      offset:
                          const Offset(
                        0,
                        7,
                      ),
                    ),
                  ],
                ),
                child: Icon(
                  icon,
                  color: Colors.white,
                  size: 26,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style:
                          TextStyle(
                        color: color,
                        fontSize: 15,
                        fontWeight:
                            FontWeight.w900,
                      ),
                    ),
                    const SizedBox(
                      height: 5,
                    ),
                    Text(
                      subtitle,
                      style:
                          const TextStyle(
                        color:
                            Color(0xff64748B),
                        fontSize: 11.5,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          // =======================================================
          // OTP INPUT
          // =======================================================

          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius:
                  BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color:
                      Colors.black.withOpacity(
                    .04,
                  ),
                  blurRadius: 12,
                  offset:
                      const Offset(0, 5),
                ),
              ],
            ),
            child: TextField(
              controller: controller,
              keyboardType:
                  TextInputType.number,
              textInputAction:
                  TextInputAction.done,
              maxLength: 4,
              obscureText: true,
              textAlign:
                  TextAlign.center,
              style: TextStyle(
                fontSize: 28,
                fontWeight:
                    FontWeight.w900,
                letterSpacing: 12,
                color: color,
              ),
              decoration:
                  InputDecoration(
                counterText: "",
                hintText: "••••",
                hintStyle:
                    const TextStyle(
                  color:
                      Color(0xffCBD5E1),
                  fontSize: 25,
                  letterSpacing: 10,
                ),
                filled: true,
                fillColor: Colors.white,
                contentPadding:
                    const EdgeInsets.symmetric(
                  vertical: 17,
                  horizontal: 15,
                ),
                prefixIcon: Icon(
                  Icons.password_rounded,
                  color: color,
                ),
                border:
                    OutlineInputBorder(
                  borderRadius:
                      BorderRadius.circular(
                    18,
                  ),
                  borderSide:
                      BorderSide.none,
                ),
                focusedBorder:
                    OutlineInputBorder(
                  borderRadius:
                      BorderRadius.circular(
                    18,
                  ),
                  borderSide:
                      BorderSide(
                    color: color,
                    width: 2,
                  ),
                ),
              ),
              onSubmitted: (_) {
                if (!processingJobs
                    .contains(serviceId)) {
                  onVerify();
                }
              },
            ),
          ),

          const SizedBox(height: 13),

          _AnimatedActionButton(
            icon: icon,
            text: buttonText,
            color: color,
            loading: processingJobs
                .contains(serviceId),
            onPressed:
                processingJobs.contains(
                  serviceId,
                )
                    ? null
                    : () {
                        onVerify();
                      },
          ),
        ],
      ),
    )
        .animate()
        .fade(duration: 450.ms)
        .slideY(
          begin: .08,
          duration: 500.ms,
          curve:
              Curves.easeOutCubic,
        );
  }

  // =============================================================
  // VERIFIED CARD
  // =============================================================

  Widget _verifiedCard({
    required IconData icon,
    required String title,
    required String message,
    required Color color,
  }) {
    return Container(
      padding:
          const EdgeInsets.all(17),
      decoration: BoxDecoration(
        gradient:
            const LinearGradient(
          colors: [
            Color(0xffECFDF5),
            Color(0xffD1FAE5),
          ],
        ),
        borderRadius:
            BorderRadius.circular(22),
        border: Border.all(
          color:
              const Color(0xffA7F3D0),
        ),
        boxShadow: [
          BoxShadow(
            color:
                Colors.green.withOpacity(
              .08,
            ),
            blurRadius: 16,
            offset:
                const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            height: 48,
            width: 48,
            decoration:
                BoxDecoration(
              color: Colors.white,
              borderRadius:
                  BorderRadius.circular(15),
            ),
            child: Icon(
              icon,
              color: color,
              size: 26,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: color,
                    fontWeight:
                        FontWeight.w900,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  message,
                  style:
                      const TextStyle(
                    color:
                        Color(0xff475569),
                    fontSize: 11.5,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.check_circle_rounded,
            color: Colors.green,
            size: 27,
          ),
        ],
      ),
    )
        .animate()
        .fade(duration: 450.ms)
        .scale(
          begin:
              const Offset(.96, .96),
          duration: 450.ms,
        );
  }

  // =============================================================
  // STATUS BADGE
  // =============================================================

  Widget statusBadge(
    String status,
  ) {
    final Color color =
        _statusColor(status);

    String text = status
        .replaceAll("_", " ")
        .toUpperCase();

    IconData icon =
        Icons.hourglass_top_rounded;

    if (status == "assigned") {
      icon =
          Icons.assignment_turned_in_rounded;
    } else if (status == "started") {
      icon =
          Icons.play_circle_fill_rounded;
    } else if (status ==
        "payment_pending") {
      text = "PAYMENT PENDING";
      icon =
          Icons.payments_rounded;
    }

    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 7,
      ),
      decoration: BoxDecoration(
        color:
            color.withOpacity(.10),
        borderRadius:
            BorderRadius.circular(20),
        border: Border.all(
          color:
              color.withOpacity(.20),
        ),
      ),
      child: Row(
        mainAxisSize:
            MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: color,
          ),
          const SizedBox(width: 5),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontWeight:
                  FontWeight.w800,
              fontSize: 10,
            ),
          ),
        ],
      ),
    )
        .animate()
        .fade()
        .scale(
          begin:
              const Offset(.85, .85),
          duration: 350.ms,
        );
  }

  // =============================================================
  // STATUS COLOR
  // =============================================================

  Color _statusColor(
    String status,
  ) {
    switch (status) {
      case "assigned":
        return const Color(
          0xff2563EB,
        );

      case "started":
        return const Color(
          0xff0284C7,
        );

      case "payment_pending":
        return const Color(
          0xffD97706,
        );

      case "completed":
        return const Color(
          0xff16A34A,
        );

      case "cancelled":
        return const Color(
          0xffDC2626,
        );

      default:
        return const Color(
          0xffF59E0B,
        );
    }
  }

  // =============================================================
  // JOB ACTION BUTTON
  // =============================================================

  Widget jobActionButton(
    Map<String, dynamic> job,
  ) {
    final String status =
        job["status"]?.toString() ??
            "assigned";

    final String serviceId =
        job["serviceId"]?.toString() ??
            "";

    final bool processing =
        processingJobs.contains(
      serviceId,
    );

    // ===========================================================
    // ASSIGNED
    // ===========================================================

    if (status == "assigned") {
      final String startOtp =
          job["startOtp"]?.toString() ??
              "";

      if (startOtp.isNotEmpty) {
        return Container(
          width: double.infinity,
          padding:
              const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color:
                const Color(0xffEFF6FF),
            borderRadius:
                BorderRadius.circular(17),
            border: Border.all(
              color:
                  const Color(0xffBFDBFE),
            ),
          ),
          child: const Row(
            children: [
              Icon(
                Icons.lock_rounded,
                color:
                    Color(0xff2563EB),
              ),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  "Enter the customer's Start OTP above to begin work.",
                  style: TextStyle(
                    color:
                        Color(0xff1E40AF),
                    fontWeight:
                        FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        );
      }

      return _AnimatedActionButton(
        icon:
            Icons.lock_clock_rounded,
        text: processing
            ? "Generating OTP..."
            : "Generate Start OTP",
        color:
            const Color(0xff2563EB),
        loading: processing,
        onPressed: processing
            ? null
            : () {
                generateStartOtp(
                  job,
                );
              },
      );
    }

    // ===========================================================
    // STARTED
    // ===========================================================

    if (status == "started") {
      return Column(
        children: [
          Container(
            width: double.infinity,
            padding:
                const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient:
                  const LinearGradient(
                colors: [
                  Color(0xffEFF6FF),
                  Color(0xffDBEAFE),
                ],
              ),
              borderRadius:
                  BorderRadius.circular(17),
              border: Border.all(
                color:
                    const Color(0xffBFDBFE),
              ),
            ),
            child: const Row(
              mainAxisAlignment:
                  MainAxisAlignment.center,
              children: [
                Icon(
                  Icons
                      .construction_rounded,
                  color:
                      Color(0xff0284C7),
                ),
                SizedBox(width: 8),
                Text(
                  "Work In Progress",
                  style: TextStyle(
                    color:
                        Color(0xff0284C7),
                    fontWeight:
                        FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // =====================================================
          // IMPORTANT:
          // Worker can now finish physical work.
          // This generates completion OTP.
          // =====================================================

          _AnimatedActionButton(
            icon:
                Icons.task_alt_rounded,
            text: processing
                ? "Processing..."
                : "Mark Work Completed",
            color:
                const Color(0xff16A34A),
            loading: processing,
            onPressed: processing
                ? null
                : () {
                    showCompleteDialog(
                      job,
                    );
                  },
          ),
        ],
      );
    }

    // ===========================================================
    // PAYMENT PENDING
    // ===========================================================

    if (status ==
        "payment_pending") {
      final String paymentStatus =
          job["paymentStatus"]
                  ?.toString() ??
              "pending";

      final bool paymentReceived =
          paymentStatus == "paid" ||
          paymentStatus ==
              "reported_paid";

      return Column(
        children: [
          _AnimatedActionButton(
            icon:
                Icons.qr_code_2_rounded,
            text:
                "Show Payment QR",
            color:
                const Color(0xff7C3AED),
            loading: processing,
            onPressed: processing
                ? null
                : () {
                    showPaymentQR(
                      job,
                    );
                  },
          ),

          const SizedBox(height: 11),

          if (!paymentReceived)
            Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.all(14),
              decoration:
                  BoxDecoration(
                color:
                    const Color(
                  0xffFFF7ED,
                ),
                borderRadius:
                    BorderRadius.circular(
                  16,
                ),
                border: Border.all(
                  color:
                      const Color(
                    0xffFED7AA,
                  ),
                ),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons
                        .hourglass_bottom_rounded,
                    color:
                        Color(0xffD97706),
                  ),
                  SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      "Waiting for customer payment.",
                      style:
                          TextStyle(
                        color:
                            Color(
                          0xff9A3412,
                        ),
                        fontWeight:
                            FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          if (paymentReceived)
            Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.all(14),
              decoration:
                  BoxDecoration(
                color:
                    const Color(
                  0xffECFDF5,
                ),
                borderRadius:
                    BorderRadius.circular(
                  16,
                ),
                border: Border.all(
                  color:
                      const Color(
                    0xffA7F3D0,
                  ),
                ),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons
                        .check_circle_rounded,
                    color:
                        Color(0xff16A34A),
                  ),
                  SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      "Payment received. Enter the customer's completion OTP above.",
                      style:
                          TextStyle(
                        color:
                            Color(
                          0xff166534,
                        ),
                        fontWeight:
                            FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      );
    }

    // ===========================================================
    // COMPLETED
    // ===========================================================

    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.all(15),
      decoration:
          BoxDecoration(
        gradient:
            const LinearGradient(
          colors: [
            Color(0xffECFDF5),
            Color(0xffD1FAE5),
          ],
        ),
        borderRadius:
            BorderRadius.circular(17),
      ),
      child: const Row(
        mainAxisAlignment:
            MainAxisAlignment.center,
        children: [
          Icon(
            Icons.done_all_rounded,
            color: Colors.green,
          ),
          SizedBox(width: 8),
          Text(
            "Work Completed",
            style: TextStyle(
              color: Colors.green,
              fontWeight:
                  FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // =============================================================
  // GENERATE START OTP
  // =============================================================

  Future<void> generateStartOtp(
    Map<String, dynamic> job,
  ) async {
    final String serviceId =
        job["serviceId"]?.toString() ??
            "";

    final String customerId =
        job["customerId"]?.toString() ??
            "";

    if (serviceId.isEmpty) {
      showMessage(
        "Service ID missing",
      );
      return;
    }

    if (customerId.isEmpty) {
      showMessage(
        "Customer ID missing",
      );
      return;
    }

    if (currentUser == null) {
      showMessage(
        "Worker is not logged in",
      );
      return;
    }

    if (processingJobs.contains(
      serviceId,
    )) {
      return;
    }

    try {
      setState(() {
        processingJobs.add(
          serviceId,
        );
      });

      final DatabaseReference serviceRef =
          servicesRef.child(
        serviceId,
      );

      final DataSnapshot snapshot =
          await serviceRef.get();

      String startOtp = "";

      // =========================================================
      // PRESERVE EXISTING OTP
      // =========================================================

      if (snapshot.exists &&
          snapshot.value is Map) {
        final Map existing =
            Map.from(
          snapshot.value as Map,
        );

        startOtp =
            existing["startOtp"]
                    ?.toString() ??
                "";
      }

      // =========================================================
      // GENERATE RANDOM 4 DIGIT OTP
      // =========================================================

      if (startOtp.isEmpty) {
        startOtp =
            _generate4DigitOtp();
      }

      final int now =
          DateTime.now()
              .millisecondsSinceEpoch;

      // =========================================================
      // SAVE START OTP
      // =========================================================

      await serviceRef.update({
        "startOtp": startOtp,
        "startOtpCreatedAt": now,
        "startOtpVerified": false,
        "updatedAt": now,
      });

      // =========================================================
      // CUSTOMER NOTIFICATION
      // =========================================================

      await notificationsRef
          .child(customerId)
          .push()
          .set({
        "receiverId": customerId,
        "senderId": currentUser!.uid,
        "serviceId": serviceId,
        "title":
            "Start OTP Required",
        "message":
            "Your worker is ready to start the service. "
            "Open Servora and provide the Start OTP to your worker.",
        "type":
            "start_otp_generated",
        "createdAt": now,
        "read": false,
      });

      if (!mounted) {
        return;
      }

      showSuccessMessage(
        "Start OTP generated. Ask the customer for the OTP.",
      );
    } catch (e) {
      showMessage(
        "Unable to generate Start OTP: $e",
      );
    } finally {
      if (mounted) {
        setState(() {
          processingJobs.remove(
            serviceId,
          );
        });
      }
    }
  }

  // =============================================================
  // VERIFY START OTP FROM FIELD
  // =============================================================

  Future<void> verifyStartOtpFromField(
    Map<String, dynamic> job,
  ) async {
    final String serviceId =
        job["serviceId"]?.toString() ??
            "";

    if (serviceId.isEmpty) {
      showMessage(
        "Service ID missing",
      );
      return;
    }

    final controller =
        otpControllerFor(serviceId);

    final String enteredOtp =
        controller.text.trim();

    if (enteredOtp.length != 4) {
      showMessage(
        "Please enter the 4-digit OTP provided by the customer.",
      );
      return;
    }

    if (processingJobs.contains(
      serviceId,
    )) {
      return;
    }

    try {
      setState(() {
        processingJobs.add(
          serviceId,
        );
      });

      final bool correct =
          await verifyStartOtp(
        job,
        enteredOtp,
      );

      if (!correct) {
        controller.clear();

        if (mounted) {
          showErrorMessage(
            "Incorrect OTP. Please enter the OTP provided by the customer.",
          );
        }

        return;
      }

      controller.clear();
    } finally {
      if (mounted) {
        setState(() {
          processingJobs.remove(
            serviceId,
          );
        });
      }
    }
  }

  // =============================================================
  // VERIFY START OTP
  // =============================================================

  Future<bool> verifyStartOtp(
    Map<String, dynamic> job,
    String enteredOtp,
  ) async {
    final String serviceId =
        job["serviceId"]?.toString() ??
            "";

    if (serviceId.isEmpty) {
      showMessage(
        "Service ID missing",
      );
      return false;
    }

    try {
      final DataSnapshot snapshot =
          await servicesRef
              .child(serviceId)
              .get();

      if (!snapshot.exists ||
          snapshot.value is! Map) {
        showMessage(
          "Service data not found.",
        );
        return false;
      }

      final Map service =
          Map.from(
        snapshot.value as Map,
      );

      final String savedOtp =
          service["startOtp"]
                  ?.toString() ??
              "";

      if (savedOtp.isEmpty) {
        showMessage(
          "Start OTP has not been generated yet.",
        );
        return false;
      }

      // =========================================================
      // WRONG OTP
      // =========================================================

      if (enteredOtp != savedOtp) {
        return false;
      }

      final int now =
          DateTime.now()
              .millisecondsSinceEpoch;

      // =========================================================
      // CORRECT OTP
      // =========================================================

      await servicesRef
          .child(serviceId)
          .update({
        "status": "started",
        "startOtpVerified": true,
        "startOtpVerifiedAt": now,
        "updatedAt": now,
      });

      final String customerId =
          service["customerId"]
                  ?.toString() ??
              "";
      final String serviceName =
    service["serviceName"]?.toString() ??
        service["title"]?.toString() ??
        "your service";        

      // =========================================================
      // CUSTOMER NOTIFICATION
      // =========================================================

 if (customerId.isNotEmpty &&
    currentUser != null) {
  await notificationsRef
      .child(customerId)
      .push()
      .set({
    "receiverId": customerId,
    "senderId": currentUser!.uid,
    "serviceId": serviceId,

    // SERVICE INFORMATION
    "serviceName": serviceName,

    "title": "Worker Started Your Service",

    "message":
        "Your worker has started working on $serviceName. "
        "Your Start OTP was verified successfully.",

    "type": "start_otp_verified",
    "createdAt": now,
    "read": false,
  });
}

      showSuccessMessage(
        "Start OTP verified. Work has started successfully.",
      );

      return true;
    } catch (e) {
      showMessage(
        "OTP verification failed: $e",
      );
      return false;
    }
  }

  // =============================================================
  // COMPLETE WORK DIALOG
  // =============================================================

  void showCompleteDialog(
    Map<String, dynamic> job,
  ) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(
              25,
            ),
          ),
          title: const Row(
            children: [
              Icon(
                Icons
                    .check_circle_rounded,
                color: Colors.green,
              ),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  "Complete Service?",
                  style: TextStyle(
                    fontWeight:
                        FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          content: const Text(
            "Confirm that the physical work has been completed.\n\n"
            "Servora will generate a secure 4-digit Completion OTP "
            "for the customer. The customer must complete payment "
            "before giving the Completion OTP to you.",
            style: TextStyle(
              height: 1.45,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                );
              },
              child:
                  const Text("Cancel"),
            ),
            ElevatedButton(
              style:
                  ElevatedButton.styleFrom(
                backgroundColor:
                    Colors.green,
                foregroundColor:
                    Colors.white,
                shape:
                    RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(
                    13,
                  ),
                ),
              ),
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                );

                startPaymentProcess(
                  job,
                );
              },
              child: const Text(
                "Continue",
                style: TextStyle(
                  fontWeight:
                      FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // =============================================================
  // START PAYMENT PROCESS
  //
  // THIS ALSO GENERATES COMPLETION OTP.
  // =============================================================

  Future<void> startPaymentProcess(
    Map<String, dynamic> job,
  ) async {
    final String serviceId =
        job["serviceId"]?.toString() ??
            "";

    final String customerId =
        job["customerId"]?.toString() ??
            "";

    if (serviceId.isEmpty) {
      showMessage(
        "Service ID missing",
      );
      return;
    }

    if (customerId.isEmpty) {
      showMessage(
        "Customer ID missing",
      );
      return;
    }

    if (processingJobs.contains(
      serviceId,
    )) {
      return;
    }

    try {
      setState(() {
        processingJobs.add(
          serviceId,
        );
      });

      final DatabaseReference serviceRef =
          servicesRef.child(
        serviceId,
      );

      final DataSnapshot snapshot =
          await serviceRef.get();

      String completionOtp = "";

      // =========================================================
      // PRESERVE EXISTING OTP
      // =========================================================

      if (snapshot.exists &&
          snapshot.value is Map) {
        final Map existing =
            Map.from(
          snapshot.value as Map,
        );

        completionOtp =
            existing["completionOtp"]
                    ?.toString() ??
                "";
      }

      // =========================================================
      // GENERATE RANDOM 4 DIGIT COMPLETION OTP
      // =========================================================

      if (completionOtp.isEmpty) {
        completionOtp =
            _generate4DigitOtp();
      }

      final int now =
          DateTime.now()
              .millisecondsSinceEpoch;

      // =========================================================
      // PAYMENT PENDING
      // =========================================================

      await serviceRef.update({
        "status":
            "payment_pending",
        "paymentMethod":
            "servora_qr",
        "paymentStatus":
            "pending",
        "completionOtp":
            completionOtp,
        "completionOtpCreatedAt":
            now,
        "completionOtpVerified":
            false,
        "updatedAt":
            now,
      });

      // =========================================================
      // CUSTOMER NOTIFICATION
      // =========================================================

      if (currentUser != null) {
        await notificationsRef
            .child(customerId)
            .push()
            .set({
          "receiverId":
              customerId,
          "senderId":
              currentUser!.uid,
          "serviceId":
              serviceId,
          "title":
              "Service Work Completed",
          "message":
              "Your worker has finished the physical work. "
              "Please complete payment and provide the Completion OTP to your worker.",
          "type":
              "completion_otp_generated",
          "createdAt":
              now,
          "read":
              false,
        });
      }

      if (!mounted) {
        return;
      }

      showSuccessMessage(
        "Completion OTP generated. Customer must complete payment first.",
      );

      await Future.delayed(
        const Duration(
          milliseconds: 300,
        ),
      );

      if (!mounted) {
        return;
      }

      // =========================================================
      // SHOW PAYMENT QR
      // =========================================================

      showPaymentQR(job);
    } catch (e) {
      showMessage(
        "Unable to start payment: $e",
      );
    } finally {
      if (mounted) {
        setState(() {
          processingJobs.remove(
            serviceId,
          );
        });
      }
    }
  }

  // =============================================================
  // VERIFY COMPLETION OTP FROM FIELD
  // =============================================================

  Future<void>
      verifyCompletionOtpFromField(
    Map<String, dynamic> job,
  ) async {
    final String serviceId =
        job["serviceId"]?.toString() ??
            "";

    if (serviceId.isEmpty) {
      showMessage(
        "Service ID missing",
      );
      return;
    }

    final controller =
        otpControllerFor(serviceId);

    final String enteredOtp =
        controller.text.trim();

    if (enteredOtp.length != 4) {
      showMessage(
        "Please enter the 4-digit completion OTP provided by the customer.",
      );
      return;
    }

    if (processingJobs.contains(
      serviceId,
    )) {
      return;
    }

    try {
      setState(() {
        processingJobs.add(
          serviceId,
        );
      });

      final bool correct =
          await verifyCompletionOtp(
        job,
        enteredOtp,
      );

      if (!correct) {
        controller.clear();

        if (mounted) {
          showErrorMessage(
            "Incorrect OTP. Please enter the completion OTP provided by the customer.",
          );
        }

        return;
      }

      controller.clear();
    } finally {
      if (mounted) {
        setState(() {
          processingJobs.remove(
            serviceId,
          );
        });
      }
    }
  }

  // =============================================================
  // VERIFY COMPLETION OTP
  // =============================================================

  Future<bool> verifyCompletionOtp(
    Map<String, dynamic> job,
    String enteredOtp,
  ) async {
    final String serviceId =
        job["serviceId"]?.toString() ??
            "";

    if (serviceId.isEmpty) {
      showMessage(
        "Service ID missing",
      );
      return false;
    }

    try {
      // =========================================================
      // FRESH FIREBASE READ
      // =========================================================

      final DataSnapshot snapshot =
          await servicesRef
              .child(serviceId)
              .get();

      if (!snapshot.exists ||
          snapshot.value is! Map) {
        showMessage(
          "Service data not found.",
        );
        return false;
      }

      final Map service =
          Map.from(
        snapshot.value as Map,
      );

      final String savedOtp =
          service["completionOtp"]
                  ?.toString() ??
              "";

      if (savedOtp.isEmpty) {
        showMessage(
          "Completion OTP has not been generated.",
        );
        return false;
      }

      // =========================================================
      // PAYMENT CHECK
      // =========================================================

      final String paymentStatus =
          service["paymentStatus"]
                  ?.toString() ??
              "pending";

      final bool paymentReceived =
          paymentStatus == "paid" ||
          paymentStatus ==
              "reported_paid";

      if (!paymentReceived) {
        showMessage(
          "Payment has not been confirmed yet.",
        );
        return false;
      }

      // =========================================================
      // OTP CHECK
      // =========================================================

      if (enteredOtp != savedOtp) {
        return false;
      }

      final int now =
          DateTime.now()
              .millisecondsSinceEpoch;

      // =========================================================
      // COMPLETE SERVICE
      // =========================================================

      await servicesRef
          .child(serviceId)
          .update({
        "status":
            "completed",
        "completionOtpVerified":
            true,
        "completionOtpVerifiedAt":
            now,
        "completedAt":
            now,
        "updatedAt":
            now,
      });

      final String customerId =
          service["customerId"]
                  ?.toString() ??
              "";

      // =========================================================
      // CUSTOMER NOTIFICATION
      // =========================================================

      if (customerId.isNotEmpty &&
          currentUser != null) {
        await notificationsRef
            .child(customerId)
            .push()
            .set({
          "receiverId":
              customerId,
          "senderId":
              currentUser!.uid,
          "serviceId":
              serviceId,
          "title":
              "Service Completed",
          "message":
              "Your Completion OTP was verified successfully. "
              "Your Servora service is now completed.",
          "type":
              "completion_otp_verified",
          "createdAt":
              now,
          "read":
              false,
        });
      }

      showSuccessMessage(
        "Completion OTP verified. Service completed successfully.",
      );

      return true;
    } catch (e) {
      showMessage(
        "Completion verification failed: $e",
      );
      return false;
    }
  }

  // =============================================================
  // SHOW PAYMENT QR
  // =============================================================

  Future<void> showPaymentQR(
    Map job,
  ) async {
    final String serviceId =
        job["serviceId"]?.toString() ??
            "";

    if (serviceId.isEmpty) {
      showMessage(
        "Service ID missing",
      );
      return;
    }

    try {
      // =========================================================
      // FRESH SERVICE DATA
      // =========================================================

      final DataSnapshot snapshot =
          await servicesRef
              .child(serviceId)
              .get();

      if (!snapshot.exists ||
          snapshot.value is! Map) {
        showMessage(
          "Service data not found.",
        );
        return;
      }

      final Map<String, dynamic> service =
          Map<String, dynamic>.from(
        snapshot.value as Map,
      );

      // =========================================================
      // PRICE
      // =========================================================

      final dynamic rawAmount =
          service["finalPrice"] ??
              service["budget"] ??
              0;

      final double amount =
          double.tryParse(
                rawAmount.toString(),
              ) ??
              0;

      if (amount <= 0) {
        showMessage(
          "Invalid payment amount",
        );
        return;
      }

      // =========================================================
      // EXISTING QR
      // =========================================================

      final String existingQrId =
          service["razorpayQrId"]
                  ?.toString() ??
              "";

      final String existingQrData =
          service["paymentQrData"]
                  ?.toString() ??
              "";

      if (existingQrId.isNotEmpty &&
          existingQrData.isNotEmpty) {
        if (!mounted) {
          return;
        }

        showServoraPaymentQR(
          service,
          amount,
          existingQrData,
        );

        return;
      }

      // =========================================================
      // GENERATE QR
      // =========================================================

      if (mounted) {
        showMessage(
          "Generating Servora payment QR...",
        );
      }

      final Map<String, dynamic> qrResponse =
          await PaymentApiService()
              .createPaymentQR(
        serviceId: serviceId,
        amount: amount,
      );

      print(
        "================================",
      );
      print(
        "RAZORPAY QR RESPONSE:",
      );
      print(qrResponse);
      print(
        "================================",
      );

      final String qrId =
          qrResponse["id"]
                  ?.toString() ??
              "";

      final String qrData =
          qrResponse["image_content"]
                  ?.toString() ??
              "";

      if (qrId.isEmpty) {
        showMessage(
          "Razorpay QR ID was not received.",
        );
        return;
      }

      if (qrData.isEmpty) {
        showMessage(
          "Razorpay QR payment data was not received.",
        );
        return;
      }

      // =========================================================
      // SAVE QR
      // =========================================================

      final int now =
          DateTime.now()
              .millisecondsSinceEpoch;

      await servicesRef
          .child(serviceId)
          .update({
        "paymentMethod":
            "servora_qr",
        "paymentStatus":
            "pending",
        "razorpayQrId":
            qrId,
        "paymentQrData":
            qrData,
        "paymentQrImageUrl":
            qrResponse["image_url"]
                    ?.toString() ??
                "",
        "paymentQrAmount":
            amount,
        "paymentQrCreatedAt":
            now,
        "updatedAt":
            now,
      });

      if (!mounted) {
        return;
      }

      showServoraPaymentQR(
        service,
        amount,
        qrData,
      );
    } catch (e) {
      if (!mounted) {
        return;
      }

      showMessage(
        "QR generation failed: $e",
      );
    }
  }

  // =============================================================
  // PAYMENT QR BOTTOM SHEET
  // =============================================================

  void showServoraPaymentQR(
    Map job,
    double amount,
    String imageUrl,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor:
          Colors.transparent,
      builder: (context) {
        return Container(
          padding:
              const EdgeInsets.fromLTRB(
            24,
            20,
            24,
            30,
          ),
          decoration:
              const BoxDecoration(
            color: Colors.white,
            borderRadius:
                BorderRadius.vertical(
              top: Radius.circular(32),
            ),
          ),
          child: SafeArea(
            child:
                SingleChildScrollView(
              child: Column(
                children: [
                  Container(
                    height: 5,
                    width: 50,
                    decoration:
                        BoxDecoration(
                      color: Colors
                          .grey
                          .shade300,
                      borderRadius:
                          BorderRadius.circular(
                        10,
                      ),
                    ),
                  ),

                  const SizedBox(
                    height: 20,
                  ),

                  Container(
                    height: 60,
                    width: 60,
                    decoration:
                        BoxDecoration(
                      gradient:
                          const LinearGradient(
                        colors: [
                          Color(
                            0xff7C3AED,
                          ),
                          Color(
                            0xffA855F7,
                          ),
                        ],
                      ),
                      borderRadius:
                          BorderRadius.circular(
                        20,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color:
                              const Color(
                            0xff7C3AED,
                          ).withOpacity(.25),
                          blurRadius: 20,
                          offset:
                              const Offset(
                            0,
                            8,
                          ),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons
                          .qr_code_2_rounded,
                      color:
                          Colors.white,
                      size: 34,
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
                            const Offset(
                          .94,
                          .94,
                        ),
                        end:
                            const Offset(
                          1.05,
                          1.05,
                        ),
                        duration:
                            900.ms,
                      ),

                  const SizedBox(
                    height: 15,
                  ),

                  const Text(
                    "Servora Payment",
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight:
                          FontWeight.w900,
                    ),
                  ),

                  const SizedBox(
                    height: 5,
                  ),

                  const Text(
                    "Customer should scan this QR to pay.",
                    textAlign:
                        TextAlign.center,
                    style: TextStyle(
                      color:
                          Colors.grey,
                      fontSize: 13,
                    ),
                  ),

                  const SizedBox(
                    height: 20,
                  ),

                  Container(
                    width:
                        double.infinity,
                    padding:
                        const EdgeInsets
                            .symmetric(
                      horizontal: 25,
                      vertical: 17,
                    ),
                    decoration:
                        BoxDecoration(
                      gradient:
                          const LinearGradient(
                        colors: [
                          Color(
                            0xffECFDF5,
                          ),
                          Color(
                            0xffD1FAE5,
                          ),
                        ],
                      ),
                      borderRadius:
                          BorderRadius.circular(
                        20,
                      ),
                    ),
                    child: Column(
                      children: [
                        const Text(
                          "Amount to Pay",
                          style:
                              TextStyle(
                            color:
                                Colors.grey,
                            fontWeight:
                                FontWeight
                                    .w600,
                          ),
                        ),
                        const SizedBox(
                          height: 5,
                        ),
                        Text(
                          "₹${amount.toStringAsFixed(2)}",
                          style:
                              const TextStyle(
                            fontSize: 30,
                            fontWeight:
                                FontWeight
                                    .w900,
                            color:
                                Colors.green,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(
                    height: 20,
                  ),

                  Container(
                    padding:
                        const EdgeInsets
                            .all(15),
                    decoration:
                        BoxDecoration(
                      color:
                          Colors.white,
                      borderRadius:
                          BorderRadius.circular(
                        22,
                      ),
                      border: Border.all(
                        color: Colors
                            .grey
                            .shade300,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color:
                              Colors.black
                                  .withOpacity(
                            .06,
                          ),
                          blurRadius: 20,
                          offset:
                              const Offset(
                            0,
                            10,
                          ),
                        ),
                      ],
                    ),
                    child: QrImageView(
                      data: imageUrl,
                      version:
                          QrVersions.auto,
                      size: 260,
                      backgroundColor:
                          Colors.white,
                    ),
                  )
                      .animate()
                      .fade(
                        duration:
                            500.ms,
                      )
                      .scale(
                        begin:
                            const Offset(
                          .92,
                          .92,
                        ),
                        duration:
                            500.ms,
                      ),

                  const SizedBox(
                    height: 18,
                  ),

                  const Text(
                    "SERVORA",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight:
                          FontWeight.w900,
                      letterSpacing: 2,
                    ),
                  ),

                  const SizedBox(
                    height: 5,
                  ),

                  const Text(
                    "Payment goes to Servora",
                    style: TextStyle(
                      color:
                          Colors.grey,
                    ),
                  ),

                  const SizedBox(
                    height: 20,
                  ),

                  Container(
                    padding:
                        const EdgeInsets
                            .all(14),
                    decoration:
                        BoxDecoration(
                      color:
                          Colors.blue
                              .shade50,
                      borderRadius:
                          BorderRadius.circular(
                        16,
                      ),
                    ),
                    child: const Row(
                      crossAxisAlignment:
                          CrossAxisAlignment
                              .start,
                      children: [
                        Icon(
                          Icons
                              .info_outline_rounded,
                          color:
                              Colors.blue,
                        ),
                        SizedBox(
                          width: 10,
                        ),
                        Expanded(
                          child: Text(
                            "After payment, ask the customer for the completion OTP shown on their Servora page.",
                            style:
                                TextStyle(
                              fontSize: 13,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(
                    height: 20,
                  ),

                  SizedBox(
                    width:
                        double.infinity,
                    child:
                        _AnimatedActionButton(
                      icon: Icons
                          .close_rounded,
                      text:
                          "Close QR",
                      color:
                          const Color(
                        0xff7C3AED,
                      ),
                      onPressed: () {
                        Navigator.pop(
                          context,
                        );
                      },
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

  // =============================================================
  // SUCCESS MESSAGE
  // =============================================================

  void showSuccessMessage(
    String message,
  ) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
        .hideCurrentSnackBar();

    ScaffoldMessenger.of(context)
        .showSnackBar(
      SnackBar(
        backgroundColor:
            const Color(0xff16A34A),
        behavior:
            SnackBarBehavior.floating,
        duration:
            const Duration(seconds: 4),
        shape:
            RoundedRectangleBorder(
          borderRadius:
              BorderRadius.circular(15),
        ),
        content: Row(
          children: [
            const Icon(
              Icons
                  .check_circle_rounded,
              color: Colors.white,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style:
                    const TextStyle(
                  fontWeight:
                      FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =============================================================
  // ERROR MESSAGE
  // =============================================================

  void showErrorMessage(
    String message,
  ) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
        .hideCurrentSnackBar();

    ScaffoldMessenger.of(context)
        .showSnackBar(
      SnackBar(
        backgroundColor:
            const Color(0xffDC2626),
        behavior:
            SnackBarBehavior.floating,
        duration:
            const Duration(seconds: 4),
        shape:
            RoundedRectangleBorder(
          borderRadius:
              BorderRadius.circular(15),
        ),
        content: Row(
          children: [
            const Icon(
              Icons
                  .error_outline_rounded,
              color: Colors.white,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style:
                    const TextStyle(
                  fontWeight:
                      FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =============================================================
  // NORMAL MESSAGE
  // =============================================================

  void showMessage(
    String text,
  ) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
        .hideCurrentSnackBar();

    ScaffoldMessenger.of(context)
        .showSnackBar(
      SnackBar(
        content: Text(text),
        behavior:
            SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(
          borderRadius:
              BorderRadius.circular(15),
        ),
      ),
    );
  }

  // =============================================================
  // EMPTY JOBS
  // =============================================================

  Widget emptyJobs() {
    return Center(
      child: Padding(
        padding:
            const EdgeInsets.all(30),
        child: Column(
          mainAxisAlignment:
              MainAxisAlignment.center,
          children: [
            Container(
              height: 120,
              width: 120,
              decoration:
                  const BoxDecoration(
                gradient:
                    LinearGradient(
                  colors: [
                    Color(0xffDBEAFE),
                    Color(0xffBFDBFE),
                  ],
                ),
                shape:
                    BoxShape.circle,
              ),
              child: const Icon(
                Icons
                    .work_outline_rounded,
                size: 58,
                color:
                    Color(0xff2563EB),
              ),
            )
                .animate(
                  onPlay:
                      (controller) =>
                          controller.repeat(
                    reverse: true,
                  ),
                )
                .moveY(
                  begin: 0,
                  end: -8,
                  duration:
                      1200.ms,
                ),

            const SizedBox(
              height: 25,
            ),

            const Text(
              "No Active Jobs",
              style: TextStyle(
                fontSize: 24,
                fontWeight:
                    FontWeight.w900,
                color:
                    Color(0xff0F172A),
              ),
            ),

            const SizedBox(
              height: 9,
            ),

            const Text(
              "Accepted services will appear here",
              textAlign:
                  TextAlign.center,
              style: TextStyle(
                color: Colors.grey,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =================================================================
// ANIMATED 3D CARD
// =================================================================

class _Animated3DCard
    extends StatefulWidget {
  final Widget child;
  final int delay;

  const _Animated3DCard({
    required this.child,
    required this.delay,
  });

  @override
  State<_Animated3DCard> createState() =>
      _Animated3DCardState();
}

class _Animated3DCardState
    extends State<_Animated3DCard> {
  bool pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) {
        setState(() {
          pressed = true;
        });
      },
      onTapUp: (_) {
        setState(() {
          pressed = false;
        });
      },
      onTapCancel: () {
        setState(() {
          pressed = false;
        });
      },
      child: AnimatedScale(
        scale: pressed ? .985 : 1,
        duration:
            const Duration(
          milliseconds: 120,
        ),
        child: AnimatedContainer(
          duration:
              const Duration(
            milliseconds: 160,
          ),
          transform:
              Matrix4.identity()
                ..setEntry(
                  3,
                  2,
                  0.001,
                )
                ..rotateX(
                  pressed ? .008 : 0,
                )
                ..rotateY(
                  pressed ? -.004 : 0,
                ),
          transformAlignment:
              Alignment.center,
          child: widget.child,
        ),
      ),
    )
        .animate(
          delay: widget.delay.ms,
        )
        .fade(
          duration: 500.ms,
        )
        .slideY(
          begin: .12,
          end: 0,
          duration: 550.ms,
          curve:
              Curves.easeOutCubic,
        );
  }
}

// =================================================================
// ANIMATED ACTION BUTTON
// =================================================================

class _AnimatedActionButton
    extends StatefulWidget {
  final IconData icon;
  final String text;
  final Color color;
  final VoidCallback? onPressed;
  final bool loading;

  const _AnimatedActionButton({
    required this.icon,
    required this.text,
    required this.color,
    required this.onPressed,
    this.loading = false,
  });

  @override
  State<_AnimatedActionButton> createState() =>
      _AnimatedActionButtonState();
}

class _AnimatedActionButtonState
    extends State<_AnimatedActionButton> {
  bool pressed = false;

  @override
  Widget build(BuildContext context) {
    final bool disabled =
        widget.onPressed == null;

    return GestureDetector(
      onTapDown: disabled
          ? null
          : (_) {
              setState(() {
                pressed = true;
              });
            },
      onTapUp: disabled
          ? null
          : (_) {
              setState(() {
                pressed = false;
              });

              widget.onPressed
                  ?.call();
            },
      onTapCancel: disabled
          ? null
          : () {
              setState(() {
                pressed = false;
              });
            },
      child: AnimatedScale(
        scale: pressed ? .96 : 1,
        duration:
            const Duration(
          milliseconds: 110,
        ),
        child: AnimatedContainer(
          duration:
              const Duration(
            milliseconds: 140,
          ),
          width: double.infinity,
          padding:
              const EdgeInsets.symmetric(
            vertical: 16,
          ),
          decoration: BoxDecoration(
            gradient:
                LinearGradient(
              colors: [
                widget.color,
                Color.lerp(
                      widget.color,
                      Colors.white,
                      .15,
                    ) ??
                    widget.color,
              ],
            ),
            borderRadius:
                BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color:
                    widget.color
                        .withOpacity(
                  .25,
                ),
                blurRadius:
                    pressed ? 8 : 16,
                offset: Offset(
                  0,
                  pressed ? 3 : 8,
                ),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment:
                MainAxisAlignment.center,
            children: [
              if (widget.loading)
                const SizedBox(
                  height: 21,
                  width: 21,
                  child:
                      CircularProgressIndicator(
                    strokeWidth: 2,
                    color:
                        Colors.white,
                  ),
                )
              else
                Icon(
                  widget.icon,
                  color:
                      Colors.white,
                  size: 22,
                ),

              const SizedBox(
                width: 9,
              ),

              Text(
                widget.text,
                style:
                    const TextStyle(
                  color: Colors.white,
                  fontWeight:
                      FontWeight.w800,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
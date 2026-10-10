import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:servora/services/payment_api_service.dart';
import 'package:servora/services/payment_service.dart';
import 'package:url_launcher/url_launcher.dart';

class CustomerServiceTrackingScreen extends StatefulWidget {
  final String serviceId;

  const CustomerServiceTrackingScreen({
    super.key,
    required this.serviceId,
  });

  @override
  State<CustomerServiceTrackingScreen> createState() =>
      _CustomerServiceTrackingScreenState();
}

class _CustomerServiceTrackingScreenState
    extends State<CustomerServiceTrackingScreen> {
  // ============================================================
  // FIREBASE REFERENCES
  // ============================================================

  final DatabaseReference servicesRef =
      FirebaseDatabase.instance.ref("services");

  final DatabaseReference usersRef =
      FirebaseDatabase.instance.ref("users");

  // ============================================================
  // DATA
  // ============================================================

  Map<String, dynamic>? service;

  Map<String, dynamic>? worker;

  bool loading = true;

  bool workerLoading = false;

  // ============================================================
  // PAYMENT STATE
  // ============================================================

  bool paymentLoading = false;

  bool paymentCompleted = false;

  String? paymentId;

  String? paymentOrderId;

  String? paymentSignature;

  // ============================================================
  // SUBSCRIPTION
  // ============================================================

  StreamSubscription? serviceSubscription;

  late PaymentService _paymentService;

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();

    _paymentService = PaymentService();

    // ----------------------------------------------------------
    // RAZORPAY SUCCESS
    // ----------------------------------------------------------

    _paymentService.onPaymentSuccess = (response) async {
      if (!mounted) return;

      assert(() {
        debugPrint("RAZORPAY SUCCESS");
        debugPrint("Payment ID: ${response.paymentId}");
        debugPrint("Order ID: ${response.orderId}");
        return true;
      }());

      setState(() {
        paymentLoading = false;
        paymentCompleted = true;

        paymentId = response.paymentId;
        paymentOrderId = response.orderId;
        paymentSignature = response.signature;
      });

      await savePaymentToFirebase(
        response.paymentId,
        response.orderId,
        response.signature,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xff16A34A),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          content: const Row(
            children: [
              Icon(
                Icons.check_circle_rounded,
                color: Colors.white,
              ),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  "Payment successful!",
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    };

    // ----------------------------------------------------------
    // RAZORPAY ERROR
    // ----------------------------------------------------------

    _paymentService.onPaymentError = (response) {
      if (!mounted) return;

      assert(() {
        debugPrint("RAZORPAY PAYMENT FAILED");
        debugPrint("Code: ${response.code}");
        debugPrint("Message: ${response.message}");
        return true;
      }());

      setState(() {
        paymentLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xffDC2626),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          content: Row(
            children: [
              const Icon(
                Icons.error_outline_rounded,
                color: Colors.white,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  "Payment failed: ${response.message}",
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    };

    // ----------------------------------------------------------
    // EXTERNAL WALLET
    // ----------------------------------------------------------

    _paymentService.onExternalWallet = (response) {
      assert(() {
        debugPrint(
          "External wallet selected: ${response.walletName}",
        );
        return true;
      }());
    };

    // ----------------------------------------------------------
    // FIREBASE LISTENER
    // ----------------------------------------------------------

    listenService();
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    serviceSubscription?.cancel();

    _paymentService.dispose();

    super.dispose();
  }

  // ============================================================
  // START PAYMENT
  // ============================================================

  Future<void> startPayment() async {
    if (service == null) {
      return;
    }

    if (paymentLoading) {
      return;
    }

    // ----------------------------------------------------------
    // SERVICE STATUS
    // ----------------------------------------------------------

    final String status =
        service?["status"]?.toString() ?? "";

    /*
      PAYMENT IS ALLOWED WHEN:

      1. status == completed
         OR
      2. status == payment_pending

      This is important because the worker screen now uses:

      assigned
          ↓
      started
          ↓
      payment_pending
          ↓
      customer pays
          ↓
      completion OTP verification
          ↓
      completed
    */

    if (status != "completed" &&
        status != "payment_pending") {
      showMessage(
        "Payment is not available yet.",
      );
      return;
    }

    // ----------------------------------------------------------
    // CUSTOMER CONFIRMATION
    // ----------------------------------------------------------

    final bool confirmed =
        service?["customerConfirmed"] == true;

    if (status == "completed" && !confirmed) {
      showMessage(
        "Please confirm the completed service first.",
      );
      return;
    }

    // ----------------------------------------------------------
    // ALREADY PAID
    // ----------------------------------------------------------

    final String paymentStatus =
        service?["paymentStatus"]?.toString() ?? "";

    if (paymentStatus == "paid") {
      showMessage(
        "Payment has already been completed.",
      );
      return;
    }

    // ----------------------------------------------------------
    // FINAL PRICE
    // ----------------------------------------------------------

    final double? finalPrice = double.tryParse(
      service?["finalPrice"]?.toString() ?? "",
    );

    if (finalPrice == null || finalPrice <= 0) {
      showMessage(
        "Invalid final service amount.",
      );
      return;
    }

    // ----------------------------------------------------------
    // LOADING
    // ----------------------------------------------------------

    setState(() {
      paymentLoading = true;
    });

    try {
      final PaymentApiService paymentApi =
          PaymentApiService();

      // --------------------------------------------------------
      // CREATE RAZORPAY ORDER
      // --------------------------------------------------------

      final Map<String, dynamic> order =
          await paymentApi.createOrder(
        amount: finalPrice,
      );

      assert(() {
        debugPrint(
          "Backend order response: $order",
        );
        return true;
      }());

      // --------------------------------------------------------
      // ORDER ID
      // --------------------------------------------------------

      final String? orderId =
          order["id"]?.toString();

      if (orderId == null || orderId.isEmpty) {
        throw Exception(
          "Razorpay order ID was not returned by backend.",
        );
      }

      // --------------------------------------------------------
      // RAZORPAY KEY
      // --------------------------------------------------------

      const String razorpayKeyId =
          "rzp_test_TSI2EhlZvprEF7";

      // --------------------------------------------------------
      // RUPEES → PAISE
      // --------------------------------------------------------

      final int amountInPaise =
          (finalPrice * 100).round();

      // --------------------------------------------------------
      // OPEN CHECKOUT
      // --------------------------------------------------------

      _paymentService.openCheckout(
        keyId: razorpayKeyId,
        amountInPaise: amountInPaise,
        orderId: orderId,
        customerName:
            service?["customerName"]?.toString(),
        customerEmail:
            service?["customerEmail"]?.toString(),
        customerPhone:
            service?["customerPhone"]?.toString(),
        description:
            "Servora Service Payment",
      );
    } catch (e) {
      assert(() {
        debugPrint(
          "PAYMENT START ERROR: $e",
        );
        return true;
      }());

      if (!mounted) return;

      setState(() {
        paymentLoading = false;
      });

      showErrorMessage(
        "Unable to start payment: $e",
      );
    }
  }

  // ============================================================
  // SAVE PAYMENT TO FIREBASE
  // ============================================================

  Future<void> savePaymentToFirebase(
    String? razorpayPaymentId,
    String? razorpayOrderId,
    String? razorpaySignature,
  ) async {
    try {
      final DatabaseReference serviceRef =
          servicesRef.child(widget.serviceId);

      await serviceRef.update({
        "paymentStatus": "paid",
        "paymentId": razorpayPaymentId,
        "paymentOrderId": razorpayOrderId,
        "paymentSignature": razorpaySignature,
        "paymentAmount":
            service?["finalPrice"],
        "paymentCurrency": "INR",
        "paymentCompletedAt":
            ServerValue.timestamp,
      });

      assert(() {
        debugPrint(
          "Payment information saved to Firebase.",
        );
        return true;
      }());
    } catch (e) {
      assert(() {
        debugPrint(
          "Failed to save payment information: $e",
        );
        return true;
      }());
    }
  }

  // ============================================================
  // LISTEN SERVICE
  // ============================================================

  void listenService() {
    serviceSubscription =
        servicesRef
            .child(widget.serviceId)
            .onValue
            .listen(
      (event) {
        if (!event.snapshot.exists) {
          if (!mounted) return;

          setState(() {
            loading = false;
            service = null;
          });

          return;
        }

        final dynamic rawData =
            event.snapshot.value;

        if (rawData is! Map) {
          if (!mounted) return;

          setState(() {
            loading = false;
            service = null;
          });

          return;
        }

        final Map<String, dynamic> data =
            Map<String, dynamic>.from(
          rawData,
        );

        if (!mounted) return;

        setState(() {
          service = data;

          loading = false;

          paymentCompleted =
              data["paymentStatus"] == "paid";

          paymentId =
              data["paymentId"]?.toString();

          paymentOrderId =
              data["paymentOrderId"]?.toString();

          paymentSignature =
              data["paymentSignature"]?.toString();
        });

        loadWorker();
      },
    );
  }

  // ============================================================
  // LOAD WORKER
  // ============================================================

  Future<void> loadWorker() async {
    if (service == null) {
      return;
    }

    final String? workerId =
        service!["assignedWorkerId"]
            ?.toString();

    if (workerId == null ||
        workerId.isEmpty) {
      if (!mounted) return;

      setState(() {
        worker = null;
      });

      return;
    }

    try {
      if (!mounted) return;

      setState(() {
        workerLoading = true;
      });

      final DatabaseEvent event =
          await usersRef
              .child(workerId)
              .once();

      if (event.snapshot.exists) {
        final dynamic rawWorker =
            event.snapshot.value;

        if (rawWorker is Map) {
          if (!mounted) return;

          setState(() {
            worker =
                Map<String, dynamic>.from(
              rawWorker,
            );
          });
        }
      }
    } catch (e) {
      assert(() {
        debugPrint(
          "Worker loading error: $e",
        );
        return true;
      }());
    } finally {
      if (!mounted) return;

      setState(() {
        workerLoading = false;
      });
    }
  }

  // ============================================================
  // CALL WORKER
  // ============================================================

  Future<void> callWorker(
    String phone,
  ) async {
    final Uri url =
        Uri.parse("tel:$phone");

    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      showErrorMessage(
        "Unable to open phone dialer.",
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
          const Color(0xffF4F7FB),
      appBar: buildAppBar(),
      body: loading
          ? buildLoading()
          : service == null
              ? emptyService()
              : buildBody(),
    );
  }

  // ============================================================
  // APP BAR
  // ============================================================

  PreferredSizeWidget buildAppBar() {
    return AppBar(
      elevation: 0,
      backgroundColor: Colors.white,
      foregroundColor:
          const Color(0xff0F172A),
      centerTitle: false,
      titleSpacing: 18,
      title: const Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Text(
            "Service Tracking",
            style: TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.w900,
              letterSpacing: -.4,
            ),
          ),
          SizedBox(height: 2),
          Text(
            "Track your Servora service",
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey,
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

  // ============================================================
  // LOADING
  // ============================================================

  Widget buildLoading() {
    return Center(
      child: Column(
        mainAxisAlignment:
            MainAxisAlignment.center,
        children: [
          Container(
            height: 90,
            width: 90,
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
                  BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color:
                      const Color(0xff2563EB)
                          .withOpacity(.28),
                  blurRadius: 28,
                  offset:
                      const Offset(0, 12),
                ),
              ],
            ),
            child: const Icon(
              Icons.location_searching_rounded,
              color: Colors.white,
              size: 43,
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
                    const Offset(1.06, 1.06),
                duration: 1000.ms,
              ),
          const SizedBox(height: 22),
          const Text(
            "Loading service...",
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
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

  // ============================================================
  // MAIN BODY
  // ============================================================

  Widget buildBody() {
    final String status =
        service?["status"]?.toString() ??
            "available";

    final bool confirmed =
        service?["customerConfirmed"] ==
            true;

    return RefreshIndicator(
      color:
          const Color(0xff2563EB),
      onRefresh: () async {
        await servicesRef
            .child(widget.serviceId)
            .get();
      },
      child: SingleChildScrollView(
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
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            // ----------------------------------------------------
            // HEADER
            // ----------------------------------------------------

            buildServiceHeader(),

            const SizedBox(height: 18),

            // ----------------------------------------------------
            // OTP SECURITY SECTION
            //
            // THIS IS WHERE CUSTOMER SEES OTP
            // ----------------------------------------------------

            buildCustomerOtpSection(),

            const SizedBox(height: 18),

            // ----------------------------------------------------
            // STATUS
            // ----------------------------------------------------

            buildStatusCard(status),

            const SizedBox(height: 18),

            // ----------------------------------------------------
            // WORKER
            // ----------------------------------------------------

            if (workerLoading)
              buildWorkerLoading()
            else if (worker != null)
              buildWorkerCard(),

            if (worker != null)
              const SizedBox(height: 18),

            // ----------------------------------------------------
            // PRICE
            // ----------------------------------------------------

            buildPriceCard(),

            const SizedBox(height: 25),

            const Text(
              "Service Progress",
              style: TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.w900,
                color: Color(0xff0F172A),
              ),
            ),

            const SizedBox(height: 15),

            buildTimeline(
              status,
              confirmed,
            ),

            // ----------------------------------------------------
            // COMPLETION
            // ----------------------------------------------------

            if (status == "completed")
              completionSection(),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // SERVICE HEADER
  // ============================================================

  Widget buildServiceHeader() {
    final String serviceName =
        service?["serviceName"]?.toString() ??
            service?["title"]?.toString() ??
            "Service Request";

    final String description =
        service?["description"]?.toString() ??
            "No description available";

    final String shortId =
        widget.serviceId.length > 8
            ? widget.serviceId.substring(0, 8)
            : widget.serviceId;

    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.all(21),
      decoration: BoxDecoration(
        gradient:
            const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xff1D4ED8),
            Color(0xff2563EB),
            Color(0xff38BDF8),
          ],
        ),
        borderRadius:
            BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color:
                const Color(0xff2563EB)
                    .withOpacity(.30),
            blurRadius: 28,
            offset:
                const Offset(0, 13),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Decorative circles
          Positioned(
            right: -30,
            top: -35,
            child: Container(
              height: 120,
              width: 120,
              decoration:
                  BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white
                    .withOpacity(.08),
              ),
            ),
          ),

          Positioned(
            right: 25,
            bottom: -50,
            child: Container(
              height: 100,
              width: 100,
              decoration:
                  BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white
                    .withOpacity(.06),
              ),
            ),
          ),

          Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    height: 61,
                    width: 61,
                    decoration:
                        BoxDecoration(
                      color: Colors.white
                          .withOpacity(.18),
                      borderRadius:
                          BorderRadius.circular(
                        19,
                      ),
                      border: Border.all(
                        color: Colors.white
                            .withOpacity(.20),
                      ),
                    ),
                    child: const Icon(
                      Icons.handyman_rounded,
                      size: 32,
                      color: Colors.white,
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
                        end: -4,
                        duration: 1300.ms,
                      ),

                  const SizedBox(width: 14),

                  Expanded(
                    child: Text(
                      serviceName,
                      maxLines: 2,
                      overflow:
                          TextOverflow.ellipsis,
                      style:
                          const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        height: 1.15,
                        fontWeight:
                            FontWeight.w900,
                        letterSpacing: -.5,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 19),

              Text(
                description,
                maxLines: 3,
                overflow:
                    TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white
                      .withOpacity(.90),
                  fontSize: 13.5,
                  height: 1.5,
                  fontWeight:
                      FontWeight.w500,
                ),
              ),

              const SizedBox(height: 18),

              Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets
                            .symmetric(
                      horizontal: 13,
                      vertical: 8,
                    ),
                    decoration:
                        BoxDecoration(
                      color: Colors.white
                          .withOpacity(.16),
                      borderRadius:
                          BorderRadius.circular(
                        20,
                      ),
                    ),
                    child: Row(
                      mainAxisSize:
                          MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.tag_rounded,
                          size: 14,
                          color:
                              Colors.white,
                        ),
                        const SizedBox(
                          width: 5,
                        ),
                        Text(
                          shortId,
                          style:
                              const TextStyle(
                            color:
                                Colors.white,
                            fontSize: 11,
                            fontWeight:
                                FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const Spacer(),

                  Container(
                    padding:
                        const EdgeInsets
                            .symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration:
                        BoxDecoration(
                      color: Colors.white
                          .withOpacity(.16),
                      borderRadius:
                          BorderRadius.circular(
                        20,
                      ),
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          Icons
                              .shield_rounded,
                          size: 14,
                          color:
                              Colors.white,
                        ),
                        SizedBox(width: 5),
                        Text(
                          "Protected",
                          style:
                              TextStyle(
                            color:
                                Colors.white,
                            fontSize: 11,
                            fontWeight:
                                FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    )
        .animate()
        .fade(duration: 550.ms)
        .slideY(
          begin: .12,
          duration: 600.ms,
          curve: Curves.easeOutCubic,
        );
  }

  // ============================================================
  // CUSTOMER OTP SECTION
  //
  // IMPORTANT:
  // OTP IS SHOWN HERE ONLY.
  // ============================================================

  Widget buildCustomerOtpSection() {
    final String status =
        service?["status"]?.toString() ??
            "";

    final String startOtp =
        service?["startOtp"]?.toString() ??
            "";

    final String completionOtp =
        service?["completionOtp"]
                ?.toString() ??
            "";

    final bool startVerified =
        service?["startOtpVerified"] ==
            true;

    final bool completionVerified =
        service?["completionOtpVerified"] ==
            true;

    // ----------------------------------------------------------
    // START OTP
    // ----------------------------------------------------------

    if (startOtp.isNotEmpty &&
        !startVerified &&
        status != "completed") {
      return buildOtpCard(
        title: "Start Verification OTP",
        subtitle:
            "Give this 4-digit OTP to your worker when they arrive to start the service.",
        otp: startOtp,
        icon: Icons.play_circle_fill_rounded,
        color: const Color(0xff2563EB),
        statusText:
            "Waiting for worker verification",
      )
          .animate()
          .fade(duration: 500.ms)
          .slideY(
            begin: .08,
            duration: 550.ms,
          );
    }

    // ----------------------------------------------------------
    // COMPLETION OTP
    // ----------------------------------------------------------

    if (completionOtp.isNotEmpty &&
        !completionVerified &&
        (status == "payment_pending" ||
            status == "completed")) {
      return buildOtpCard(
        title: "Completion Verification OTP",
        subtitle:
            "Give this 4-digit OTP to your worker after the service payment is completed.",
        otp: completionOtp,
        icon: Icons.verified_user_rounded,
        color: const Color(0xff7C3AED),
        statusText:
            paymentCompleted
                ? "Payment received • Give OTP to worker"
                : "Keep this OTP ready for completion",
      )
          .animate()
          .fade(duration: 500.ms)
          .slideY(
            begin: .08,
            duration: 550.ms,
          );
    }

    // ----------------------------------------------------------
    // START VERIFIED
    // ----------------------------------------------------------

    if (startVerified &&
        status == "started" &&
        completionOtp.isEmpty) {
      return buildVerifiedCard(
        title: "Start Verification Complete",
        message:
            "Your Start OTP has been verified by the worker. The service is now in progress.",
        icon: Icons.verified_rounded,
        color: const Color(0xff16A34A),
      );
    }

    // ----------------------------------------------------------
    // PAYMENT COMPLETED / COMPLETION OTP VERIFIED
    // ----------------------------------------------------------

    if (completionVerified) {
      return buildVerifiedCard(
        title: "Completion Verification Complete",
        message:
            "Your completion OTP has been successfully verified.",
        icon: Icons.verified_rounded,
        color: const Color(0xff16A34A),
      );
    }

    // ----------------------------------------------------------
    // PAYMENT PENDING
    // ----------------------------------------------------------

    if (status == "payment_pending") {
      return buildInfoSecurityCard(
        title: "Payment & Verification",
        message:
            "Your worker has finished the service. Complete the payment below and follow the OTP verification step.",
        icon: Icons.lock_rounded,
        color: const Color(0xffD97706),
      );
    }

    return const SizedBox.shrink();
  }

  // ============================================================
  // OTP CARD
  // ============================================================

  Widget buildOtpCard({
    required String title,
    required String subtitle,
    required String otp,
    required IconData icon,
    required Color color,
    required String statusText,
  }) {
    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient:
            LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withOpacity(.10),
            Colors.white,
          ],
        ),
        borderRadius:
            BorderRadius.circular(27),
        border: Border.all(
          color: color.withOpacity(.25),
          width: 1.3,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(.12),
            blurRadius: 24,
            offset:
                const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          // ------------------------------------------------------
          // HEADER
          // ------------------------------------------------------

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
                      color.withOpacity(.72),
                    ],
                  ),
                  borderRadius:
                      BorderRadius.circular(
                    16,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color:
                          color.withOpacity(.25),
                      blurRadius: 14,
                      offset:
                          const Offset(0, 7),
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
                      style: TextStyle(
                        color: color,
                        fontSize: 16,
                        fontWeight:
                            FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "CUSTOMER ONLY",
                      style:
                          TextStyle(
                        color: color
                            .withOpacity(.65),
                        fontSize: 9,
                        fontWeight:
                            FontWeight.w900,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets
                        .symmetric(
                  horizontal: 9,
                  vertical: 6,
                ),
                decoration:
                    BoxDecoration(
                  color: color
                      .withOpacity(.10),
                  borderRadius:
                      BorderRadius.circular(
                    20,
                  ),
                ),
                child: Icon(
                  Icons.lock_rounded,
                  color: color,
                  size: 17,
                ),
              ),
            ],
          ),

          const SizedBox(height: 15),

          Text(
            subtitle,
            style: const TextStyle(
              color: Color(0xff475569),
              fontSize: 12.5,
              height: 1.45,
              fontWeight:
                  FontWeight.w500,
            ),
          ),

          const SizedBox(height: 17),

          // ------------------------------------------------------
          // OTP DISPLAY
          // ------------------------------------------------------

          Container(
            width: double.infinity,
            padding:
                const EdgeInsets.symmetric(
              vertical: 18,
              horizontal: 12,
            ),
            decoration:
                BoxDecoration(
              color: Colors.white,
              borderRadius:
                  BorderRadius.circular(
                22,
              ),
              border: Border.all(
                color:
                    color.withOpacity(.20),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black
                      .withOpacity(.05),
                  blurRadius: 18,
                  offset:
                      const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              children: [
                const Text(
                  "YOUR OTP",
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 10,
                    fontWeight:
                        FontWeight.w800,
                    letterSpacing: 2,
                  ),
                ),

                const SizedBox(height: 9),

                Row(
                  mainAxisAlignment:
                      MainAxisAlignment.center,
                  children:
                      List.generate(
                    otp.length,
                    (index) {
                      return Container(
                        margin:
                            const EdgeInsets
                                .symmetric(
                          horizontal: 4,
                        ),
                        height: 54,
                        width: 47,
                        alignment:
                            Alignment.center,
                        decoration:
                            BoxDecoration(
                          gradient:
                              LinearGradient(
                            colors: [
                              color
                                  .withOpacity(
                                .12,
                              ),
                              color
                                  .withOpacity(
                                .04,
                              ),
                            ],
                          ),
                          borderRadius:
                              BorderRadius
                                  .circular(
                            14,
                          ),
                          border: Border.all(
                            color: color
                                .withOpacity(
                              .20,
                            ),
                          ),
                        ),
                        child: Text(
                          otp[index],
                          style:
                              TextStyle(
                            color: color,
                            fontSize: 25,
                            fontWeight:
                                FontWeight.w900,
                          ),
                        ),
                      )
                          .animate(
                            delay:
                                (index * 80).ms,
                          )
                          .fade()
                          .scale(
                            begin:
                                const Offset(
                              .7,
                              .7,
                            ),
                            duration:
                                350.ms,
                          );
                    },
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 13),

          // ------------------------------------------------------
          // STATUS
          // ------------------------------------------------------

          Container(
            width: double.infinity,
            padding:
                const EdgeInsets.all(12),
            decoration:
                BoxDecoration(
              color:
                  color.withOpacity(.07),
              borderRadius:
                  BorderRadius.circular(
                14,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  color: color,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    statusText,
                    style: TextStyle(
                      color: color,
                      fontSize: 11.5,
                      fontWeight:
                          FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          const Row(
            children: [
              Icon(
                Icons.security_rounded,
                size: 14,
                color: Colors.grey,
              ),
              SizedBox(width: 6),
              Expanded(
                child: Text(
                  "Do not share this OTP with anyone except your assigned Servora worker.",
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 10.5,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ============================================================
  // VERIFIED CARD
  // ============================================================

  Widget buildVerifiedCard({
    required String title,
    required String message,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.all(17),
      decoration: BoxDecoration(
        gradient:
            LinearGradient(
          colors: [
            color.withOpacity(.10),
            Colors.white,
          ],
        ),
        borderRadius:
            BorderRadius.circular(23),
        border: Border.all(
          color: color.withOpacity(.20),
        ),
      ),
      child: Row(
        children: [
          Container(
            height: 48,
            width: 48,
            decoration:
                BoxDecoration(
              color:
                  color.withOpacity(.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: color,
              size: 27,
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
                const SizedBox(height: 4),
                Text(
                  message,
                  style: const TextStyle(
                    color: Color(0xff475569),
                    fontSize: 11.5,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    )
        .animate()
        .fade()
        .slideX(
          begin: .06,
          duration: 450.ms,
        );
  }

  // ============================================================
  // SECURITY INFO CARD
  // ============================================================

  Widget buildInfoSecurityCard({
    required String title,
    required String message,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(23),
        border: Border.all(
          color:
              color.withOpacity(.20),
        ),
        boxShadow: [
          BoxShadow(
            color:
                color.withOpacity(.08),
            blurRadius: 20,
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
              color:
                  color.withOpacity(.10),
              borderRadius:
                  BorderRadius.circular(
                15,
              ),
            ),
            child: Icon(
              icon,
              color: color,
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
                const SizedBox(height: 4),
                Text(
                  message,
                  style: const TextStyle(
                    color: Color(0xff475569),
                    fontSize: 11.5,
                    height: 1.4,
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
  // STATUS CARD
  // ============================================================

  Widget buildStatusCard(
    String status,
  ) {
    Color color =
        const Color(0xffF59E0B);

    String title = "Waiting";

    String message =
        "Waiting for the service to begin.";

    IconData icon =
        Icons.hourglass_top_rounded;

    if (status == "assigned") {
      color =
          const Color(0xff2563EB);
      title = "WORKER ASSIGNED";
      message =
          "Your worker has accepted the service request.";
      icon =
          Icons.person_pin_circle_rounded;
    } else if (status == "started") {
      color =
          const Color(0xff0284C7);
      title = "SERVICE IN PROGRESS";
      message =
          "Your worker is currently working on your service.";
      icon =
          Icons.engineering_rounded;
    } else if (status == "payment_pending") {
      color =
          const Color(0xffD97706);
      title = "PAYMENT PENDING";
      message =
          "Service work is finished. Complete your payment.";
      icon =
          Icons.payments_rounded;
    } else if (status == "completed") {
      color =
          const Color(0xff16A34A);
      title = "SERVICE COMPLETED";
      message =
          "Your service has been completed successfully.";
      icon =
          Icons.check_circle_rounded;
    }

    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient:
            LinearGradient(
          colors: [
            color.withOpacity(.12),
            Colors.white,
          ],
        ),
        borderRadius:
            BorderRadius.circular(23),
        border: Border.all(
          color:
              color.withOpacity(.22),
        ),
        boxShadow: [
          BoxShadow(
            color:
                color.withOpacity(.07),
            blurRadius: 20,
            offset:
                const Offset(0, 9),
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
                colors: [
                  color,
                  color.withOpacity(.72),
                ],
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color:
                      color.withOpacity(.25),
                  blurRadius: 14,
                  offset:
                      const Offset(0, 6),
                ),
              ],
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: 26,
            ),
          ),
          const SizedBox(width: 13),
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
                  style: const TextStyle(
                    color: Color(0xff475569),
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    )
        .animate()
        .fade(duration: 500.ms)
        .slideX(
          begin: .06,
          duration: 500.ms,
        );
  }

  // ============================================================
  // WORKER LOADING
  // ============================================================

  Widget buildWorkerLoading() {
    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(24),
      ),
      child: const Row(
        children: [
          SizedBox(
            height: 25,
            width: 25,
            child:
                CircularProgressIndicator(
              strokeWidth: 2,
            ),
          ),
          SizedBox(width: 13),
          Text(
            "Loading worker details...",
            style: TextStyle(
              fontWeight:
                  FontWeight.w600,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // WORKER CARD
  // ============================================================

  Widget buildWorkerCard() {
    final String workerName =
        worker?["name"]?.toString() ??
            worker?["username"]?.toString() ??
            "Servora Worker";

    final String phone =
        worker?["phone"]?.toString() ?? "";

    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(25),
        border: Border.all(
          color:
              const Color(0xffE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black
                .withOpacity(.055),
            blurRadius: 22,
            offset:
                const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.engineering_rounded,
                color:
                    Color(0xff2563EB),
                size: 20,
              ),
              SizedBox(width: 8),
              Text(
                "Assigned Worker",
                style: TextStyle(
                  fontSize: 15,
                  fontWeight:
                      FontWeight.w900,
                ),
              ),
            ],
          ),

          const SizedBox(height: 15),

          Row(
            children: [
              Container(
                height: 62,
                width: 62,
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
                      ).withOpacity(.15),
                      blurRadius: 13,
                      offset:
                          const Offset(0, 6),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.person_rounded,
                  color:
                      Color(0xff2563EB),
                  size: 34,
                ),
              ),

              const SizedBox(width: 14),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      workerName,
                      maxLines: 1,
                      overflow:
                          TextOverflow.ellipsis,
                      style:
                          const TextStyle(
                        fontSize: 17,
                        fontWeight:
                            FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 5),
                    if (phone.isNotEmpty)
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
                              phone,
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
                ),
              ),

              if (phone.isNotEmpty)
                GestureDetector(
                  onTap: () {
                    callWorker(phone);
                  },
                  child: Container(
                    height: 46,
                    width: 46,
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
                          color:
                              Colors.green
                                  .withOpacity(
                            .22,
                          ),
                          blurRadius: 13,
                          offset:
                              const Offset(
                            0,
                            6,
                          ),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.call_rounded,
                      color: Colors.white,
                      size: 21,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    )
        .animate()
        .fade(duration: 550.ms)
        .slideY(
          begin: .08,
          duration: 550.ms,
        );
  }

  // ============================================================
  // PRICE CARD
  // ============================================================

  Widget buildPriceCard() {
    final String price =
        service?["finalPrice"]?.toString() ??
            "0";

    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.all(19),
      decoration: BoxDecoration(
        gradient:
            const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xffECFDF5),
            Color(0xffD1FAE5),
          ],
        ),
        borderRadius:
            BorderRadius.circular(25),
        border: Border.all(
          color:
              const Color(0xffA7F3D0),
        ),
        boxShadow: [
          BoxShadow(
            color:
                Colors.green.withOpacity(.08),
            blurRadius: 20,
            offset:
                const Offset(0, 9),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            height: 55,
            width: 55,
            decoration:
                const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.currency_rupee_rounded,
              color: Colors.green,
              size: 27,
            ),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              const Text(
                "Final Agreed Price",
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 12,
                  fontWeight:
                      FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                "₹$price",
                style: const TextStyle(
                  color: Colors.green,
                  fontSize: 25,
                  fontWeight:
                      FontWeight.w900,
                ),
              ),
            ],
          ),
          const Spacer(),
          Container(
            padding:
                const EdgeInsets.all(9),
            decoration:
                const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.verified_rounded,
              color: Colors.green,
              size: 21,
            ),
          ),
        ],
      ),
    )
        .animate()
        .fade(duration: 500.ms)
        .slideY(
          begin: .08,
          duration: 500.ms,
        );
  }

  // ============================================================
  // TIMELINE
  // ============================================================

  Widget buildTimeline(
    String status,
    bool confirmed,
  ) {
    final List<Map<String, dynamic>>
        steps = [
      {
        "title": "Request Created",
        "icon":
            Icons.add_circle_rounded,
        "done": true,
      },
      {
        "title": "Worker Assigned",
        "icon":
            Icons.person_rounded,
        "done":
            status == "assigned" ||
                status == "started" ||
                status == "payment_pending" ||
                status == "completed",
      },
      {
        "title": "Work Started",
        "icon":
            Icons.play_circle_fill_rounded,
        "done":
            status == "started" ||
                status == "payment_pending" ||
                status == "completed",
      },
      {
        "title": "Work Completed",
        "icon":
            Icons.check_circle_rounded,
        "done":
            status == "payment_pending" ||
                status == "completed",
      },
      {
        "title": "Payment Completed",
        "icon":
            Icons.payments_rounded,
        "done":
            paymentCompleted,
      },
      // {
      //   "title": "Service Closed",
      //   "icon":
      //       Icons.verified_rounded,
      //   "done":
      //       status == "completed" &&
      //           service?["completionOtpVerified"] ==
      //               true,
      // },
    ];

    return Column(
      children: List.generate(
        steps.length,
        (index) {
          return timelineItem(
            title:
                steps[index]["title"]
                    as String,
            icon:
                steps[index]["icon"]
                    as IconData,
            completed:
                steps[index]["done"]
                    as bool,
            active:
                _isTimelineActive(
              index,
              status,
            ),
            last:
                index == steps.length - 1,
            index: index,
          );
        },
      ),
    );
  }

  bool _isTimelineActive(
    int index,
    String status,
  ) {
    if (index == 1) {
      return status == "assigned";
    }

    if (index == 2) {
      return status == "started";
    }

    if (index == 3) {
      return status == "payment_pending";
    }

    if (index == 4) {
      return paymentCompleted;
    }

    return false;
  }

  // ============================================================
  // TIMELINE ITEM
  // ============================================================

  Widget timelineItem({
    required String title,
    required IconData icon,
    required bool completed,
    required bool active,
    required bool last,
    required int index,
  }) {
    final Color color = completed
        ? const Color(0xff16A34A)
        : active
            ? const Color(0xff2563EB)
            : const Color(0xffCBD5E1);

    return Row(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            AnimatedContainer(
              duration:
                  const Duration(
                milliseconds: 500,
              ),
              height: 52,
              width: 52,
              decoration:
                  BoxDecoration(
                shape: BoxShape.circle,
                gradient:
                    completed || active
                        ? LinearGradient(
                            colors: [
                              color,
                              color.withOpacity(
                                .70,
                              ),
                            ],
                          )
                        : null,
                color:
                    completed || active
                        ? null
                        : const Color(
                            0xffF1F5F9,
                          ),
                border: Border.all(
                  color:
                      color.withOpacity(.35),
                  width: 1.5,
                ),
                boxShadow:
                    completed || active
                        ? [
                            BoxShadow(
                              color: color
                                  .withOpacity(
                                .20,
                              ),
                              blurRadius: 13,
                              offset:
                                  const Offset(
                                0,
                                6,
                              ),
                            ),
                          ]
                        : [],
              ),
              child: Icon(
                icon,
                color:
                    completed || active
                        ? Colors.white
                        : const Color(
                            0xff94A3B8,
                          ),
                size: 23,
              ),
            )
                .animate(
                  delay:
                      (index * 70).ms,
                )
                .fade()
                .scale(
                  begin:
                      const Offset(
                    .8,
                    .8,
                  ),
                  duration:
                      400.ms,
                ),

            if (!last)
              AnimatedContainer(
                duration:
                    const Duration(
                  milliseconds: 500,
                ),
                height: 62,
                width: 3,
                decoration:
                    BoxDecoration(
                  color: completed
                      ? const Color(
                          0xff16A34A,
                        )
                      : const Color(
                          0xffE2E8F0,
                        ),
                  borderRadius:
                      BorderRadius.circular(
                    10,
                  ),
                ),
              ),
          ],
        ),

        const SizedBox(width: 14),

        Expanded(
          child: AnimatedContainer(
            duration:
                const Duration(
              milliseconds: 450,
            ),
            margin:
                const EdgeInsets.only(
              bottom: 20,
            ),
            padding:
                const EdgeInsets.all(17),
            decoration:
                BoxDecoration(
              color: completed
                  ? const Color(
                      0xffF0FDF4,
                    )
                  : active
                      ? const Color(
                          0xffEFF6FF,
                        )
                      : Colors.white,
              borderRadius:
                  BorderRadius.circular(
                19,
              ),
              border: Border.all(
                color: completed
                    ? const Color(
                        0xffBBF7D0,
                      )
                    : active
                        ? const Color(
                            0xffBFDBFE,
                          )
                        : const Color(
                            0xffE2E8F0,
                          ),
              ),
              boxShadow:
                  active || completed
                      ? [
                          BoxShadow(
                            color: color
                                .withOpacity(
                              .07,
                            ),
                            blurRadius: 15,
                            offset:
                                const Offset(
                              0,
                              7,
                            ),
                          ),
                        ]
                      : [],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment
                            .start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontWeight:
                              FontWeight.w800,
                          fontSize: 13,
                          color: completed
                              ? const Color(
                                  0xff16A34A,
                                )
                              : active
                                  ? const Color(
                                      0xff2563EB,
                                    )
                                  : const Color(
                                      0xff94A3B8,
                                    ),
                        ),
                      ),
                      if (active &&
                          !completed) ...[
                        const SizedBox(
                            height: 4),
                        const Text(
                          "Current step",
                          style: TextStyle(
                            color:
                                Colors.grey,
                            fontSize: 10,
                            fontWeight:
                                FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Icon(
                  completed
                      ? Icons
                          .check_circle_rounded
                      : active
                          ? Icons
                              .radio_button_checked
                          : Icons
                              .radio_button_unchecked,
                  color:
                      completed || active
                          ? color
                          : const Color(
                              0xffCBD5E1,
                            ),
                  size: 21,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // COMPLETION SECTION
  // ============================================================

  Widget completionSection() {
    final bool confirmed =
        service?["customerConfirmed"] ==
            true;

    return Container(
      width: double.infinity,
      margin:
          const EdgeInsets.only(
        top: 8,
      ),
      padding:
          const EdgeInsets.all(19),
      decoration: BoxDecoration(
        gradient:
            const LinearGradient(
          colors: [
            Color(0xffECFDF5),
            Color(0xffF0FDF4),
          ],
        ),
        borderRadius:
            BorderRadius.circular(25),
        border: Border.all(
          color:
              const Color(0xffBBF7D0),
        ),
        boxShadow: [
          BoxShadow(
            color:
                Colors.green.withOpacity(.08),
            blurRadius: 20,
            offset:
                const Offset(0, 9),
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
                height: 48,
                width: 48,
                decoration:
                    const BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons
                      .check_circle_rounded,
                  color: Colors.white,
                  size: 27,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Service Completed",
                      style: TextStyle(
                        color: Colors.green,
                        fontSize: 17,
                        fontWeight:
                            FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      "Your service work is complete.",
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 17),

          Text(
            confirmed
                ? "You have confirmed this service."
                : "Please confirm the completed service and rate your worker.",
            style: const TextStyle(
              color: Color(0xff475569),
              fontSize: 12.5,
              height: 1.4,
            ),
          ),

          const SizedBox(height: 17),

          if (!confirmed)
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed:
                    showRatingDialog,
                style:
                    ElevatedButton.styleFrom(
                  backgroundColor:
                      Colors.green,
                  foregroundColor:
                      Colors.white,
                  elevation: 0,
                  shape:
                      RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(
                      16,
                    ),
                  ),
                ),
                child: const Row(
                  mainAxisAlignment:
                      MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons
                          .star_rounded,
                    ),
                    SizedBox(width: 8),
                    Text(
                      "Confirm & Rate Worker",
                      style: TextStyle(
                        fontWeight:
                            FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          if (confirmed) ...[
            const SizedBox(height: 5),

            Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.all(14),
              decoration:
                  BoxDecoration(
                color: Colors.white,
                borderRadius:
                    BorderRadius.circular(
                  17,
                ),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons
                        .verified_rounded,
                    color: Colors.green,
                  ),
                  SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      "Service confirmation completed.",
                      style: TextStyle(
                        color: Colors.green,
                        fontWeight:
                            FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 15),

            buildPaymentSection(),
          ],
        ],
      ),
    )
        .animate()
        .fade(duration: 600.ms)
        .slideY(
          begin: .08,
          duration: 600.ms,
        );
  }

  // ============================================================
  // PAYMENT SECTION
  // ============================================================

  Widget buildPaymentSection() {
    // ----------------------------------------------------------
    // PAYMENT COMPLETED
    // ----------------------------------------------------------

    if (paymentCompleted) {
      return Container(
        width: double.infinity,
        padding:
            const EdgeInsets.all(17),
        decoration: BoxDecoration(
          color:
              const Color(0xffF0FDF4),
          borderRadius:
              BorderRadius.circular(20),
          border: Border.all(
            color:
                const Color(0xffBBF7D0),
          ),
        ),
        child: Column(
          children: [
            Container(
              height: 58,
              width: 58,
              decoration:
                  const BoxDecoration(
                color: Colors.green,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons
                    .check_circle_rounded,
                color: Colors.white,
                size: 33,
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
                      const Offset(
                    .94,
                    .94,
                  ),
                  end:
                      const Offset(
                    1.05,
                    1.05,
                  ),
                  duration: 900.ms,
                ),

            const SizedBox(height: 10),

            const Text(
              "Payment Successful",
              style: TextStyle(
                color: Colors.green,
                fontSize: 18,
                fontWeight:
                    FontWeight.w900,
              ),
            ),

            const SizedBox(height: 5),

            const Text(
              "Payment has been recorded successfully.",
              textAlign:
                  TextAlign.center,
              style: TextStyle(
                color: Colors.grey,
                fontSize: 11.5,
              ),
            ),

            if (paymentId != null) ...[
              const SizedBox(height: 10),
              Container(
                padding:
                    const EdgeInsets.all(10),
                decoration:
                    BoxDecoration(
                  color: Colors.white,
                  borderRadius:
                      BorderRadius.circular(
                    12,
                  ),
                ),
                child: Text(
                  "Payment ID: $paymentId",
                  textAlign:
                      TextAlign.center,
                  style:
                      const TextStyle(
                    color:
                        Colors.black54,
                    fontSize: 10,
                    fontWeight:
                        FontWeight.w600,
                  ),
                ),
              ),
            ],

            // --------------------------------------------------
            // COMPLETION OTP REMINDER
            // --------------------------------------------------

            if ((service?[
                        "completionOtp"] ??
                    "")
                .toString()
                .isNotEmpty &&
                service?[
                        "completionOtpVerified"] !=
                    true) ...[
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.all(
                  13,
                ),
                decoration:
                    BoxDecoration(
                  color:
                      const Color(
                    0xffF5F3FF,
                  ),
                  borderRadius:
                      BorderRadius.circular(
                    15,
                  ),
                  border: Border.all(
                    color:
                        const Color(
                      0xffDDD6FE,
                    ),
                  ),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons
                          .password_rounded,
                      color:
                          Color(0xff7C3AED),
                    ),
                    SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        "Give your Completion OTP to the worker to finish the service verification.",
                        style: TextStyle(
                          color:
                              Color(0xff6D28D9),
                          fontSize: 11.5,
                          fontWeight:
                              FontWeight.w700,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      );
    }

    // ----------------------------------------------------------
    // PAYMENT BUTTON
    // ----------------------------------------------------------

    final String status =
        service?["status"]?.toString() ??
            "";

    final bool canPay =
        status == "payment_pending" ||
            status == "completed";

    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(20),
        border: Border.all(
          color:
              const Color(0xffDBEAFE),
        ),
        boxShadow: [
          BoxShadow(
            color:
                Colors.blue.withOpacity(.05),
            blurRadius: 15,
            offset:
                const Offset(0, 7),
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
                height: 43,
                width: 43,
                decoration:
                    BoxDecoration(
                  color:
                      const Color(
                    0xffDBEAFE,
                  ),
                  borderRadius:
                      BorderRadius.circular(
                    13,
                  ),
                ),
                child: const Icon(
                  Icons
                      .account_balance_wallet_rounded,
                  color:
                      Color(0xff2563EB),
                ),
              ),
              const SizedBox(width: 11),
              const Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Payment",
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight:
                            FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      "Complete your service payment",
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          Container(
            padding:
                const EdgeInsets.all(12),
            decoration:
                BoxDecoration(
              color:
                  const Color(0xffF8FAFC),
              borderRadius:
                  BorderRadius.circular(
                14,
              ),
            ),
            child: const Row(
              children: [
                Icon(
                  Icons.security_rounded,
                  color:
                      Color(0xff2563EB),
                  size: 18,
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "Secure payment powered by Razorpay.",
                    style: TextStyle(
                      color:
                          Color(0xff475569),
                      fontSize: 11,
                      fontWeight:
                          FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          SizedBox(
            width: double.infinity,
            height: 53,
            child: ElevatedButton(
              onPressed:
                  !canPay ||
                          paymentLoading
                      ? null
                      : startPayment,
              style:
                  ElevatedButton.styleFrom(
                backgroundColor:
                    const Color(
                  0xff2563EB,
                ),
                disabledBackgroundColor:
                    const Color(
                  0xffCBD5E1,
                ),
                elevation: 0,
                shape:
                    RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(
                    17,
                  ),
                ),
              ),
              child: paymentLoading
                  ? const Row(
                      mainAxisAlignment:
                          MainAxisAlignment
                              .center,
                      children: [
                        SizedBox(
                          height: 21,
                          width: 21,
                          child:
                              CircularProgressIndicator(
                            strokeWidth: 2,
                            color:
                                Colors.white,
                          ),
                        ),
                        SizedBox(
                            width: 10),
                        Text(
                          "Starting Payment...",
                          style: TextStyle(
                            color:
                                Colors.white,
                            fontWeight:
                                FontWeight.w800,
                          ),
                        ),
                      ],
                    )
                  : Row(
                      mainAxisAlignment:
                          MainAxisAlignment
                              .center,
                      children: [
                        const Icon(
                          Icons
                              .lock_rounded,
                          color:
                              Colors.white,
                        ),
                        const SizedBox(
                            width: 8),
                        Text(
                          "Pay ₹${service?["finalPrice"] ?? 0}",
                          style:
                              const TextStyle(
                            color:
                                Colors.white,
                            fontSize: 16,
                            fontWeight:
                                FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // RATING DIALOG
  // ============================================================

  void showRatingDialog() {
    int rating = 5;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder:
              (context, setDialogState) {
            return AlertDialog(
              shape:
                  RoundedRectangleBorder(
                borderRadius:
                    BorderRadius.circular(
                  27,
                ),
              ),
              title: const Row(
                children: [
                  Icon(
                    Icons.star_rounded,
                    color:
                        Color(0xffF59E0B),
                  ),
                  SizedBox(width: 8),
                  Text(
                    "Rate Worker",
                    style: TextStyle(
                      fontWeight:
                          FontWeight.w900,
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize:
                    MainAxisSize.min,
                children: [
                  const Text(
                    "How was your service?",
                    style: TextStyle(
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(
                      height: 18),
                  Row(
                    mainAxisAlignment:
                        MainAxisAlignment
                            .center,
                    children:
                        List.generate(
                      5,
                      (index) {
                        return GestureDetector(
                          onTap: () {
                            setDialogState(
                              () {
                                rating =
                                    index + 1;
                              },
                            );
                          },
                          child: Padding(
                            padding:
                                const EdgeInsets
                                    .all(
                              3,
                            ),
                            child: Icon(
                              Icons
                                  .star_rounded,
                              size: 39,
                              color: index <
                                      rating
                                  ? const Color(
                                      0xffF59E0B,
                                    )
                                  : const Color(
                                      0xffCBD5E1,
                                    ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
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
                        14,
                      ),
                    ),
                  ),
                  onPressed: () async {
                    try {
                      await servicesRef
                          .child(
                        widget.serviceId,
                      )
                          .update({
                        "customerConfirmed":
                            true,
                        "rating": rating,
                        "customerConfirmedAt":
                            ServerValue.timestamp,
                      });

                      if (!dialogContext
                          .mounted) {
                        return;
                      }

                      Navigator.pop(
                        dialogContext,
                      );

                      showSuccessMessage(
                        "Service confirmed successfully.",
                      );
                    } catch (e) {
                      if (!dialogContext
                          .mounted) {
                        return;
                      }

                      showErrorMessage(
                        "Failed to confirm service: $e",
                      );
                    }
                  },
                  child:
                      const Text(
                    "Submit",
                    style: TextStyle(
                      fontWeight:
                          FontWeight.w800,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ============================================================
  // EMPTY SERVICE
  // ============================================================

  Widget emptyService() {
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
                  const BoxDecoration(
                gradient:
                    LinearGradient(
                  colors: [
                    Color(0xffDBEAFE),
                    Color(0xffBFDBFE),
                  ],
                ),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons
                    .search_off_rounded,
                size: 59,
                color:
                    Color(0xff2563EB),
              ),
            )
                .animate(
                  onPlay: (controller) =>
                      controller.repeat(
                    reverse: true,
                  ),
                )
                .moveY(
                  begin: 0,
                  end: -7,
                  duration: 1100.ms,
                ),

            const SizedBox(height: 23),

            const Text(
              "Service Not Found",
              style: TextStyle(
                fontSize: 23,
                fontWeight:
                    FontWeight.w900,
              ),
            ),

            const SizedBox(height: 7),

            const Text(
              "No service information is available.",
              textAlign:
                  TextAlign.center,
              style: TextStyle(
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // SUCCESS MESSAGE
  // ============================================================

  void showSuccessMessage(
    String message,
  ) {
    if (!mounted) return;

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
              BorderRadius.circular(16),
        ),
        content: Row(
          children: [
            const Icon(
              Icons
                  .check_circle_rounded,
              color: Colors.white,
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                message,
                style:
                    const TextStyle(
                  color: Colors.white,
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

  // ============================================================
  // ERROR MESSAGE
  // ============================================================

  void showErrorMessage(
    String message,
  ) {
    if (!mounted) return;

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
              BorderRadius.circular(16),
        ),
        content: Row(
          children: [
            const Icon(
              Icons
                  .error_outline_rounded,
              color: Colors.white,
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                message,
                style:
                    const TextStyle(
                  color: Colors.white,
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

  // ============================================================
  // NORMAL MESSAGE
  // ============================================================

  void showMessage(
    String message,
  ) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
        .showSnackBar(
      SnackBar(
        behavior:
            SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(
          borderRadius:
              BorderRadius.circular(16),
        ),
        content: Text(message),
      ),
    );
  }

  // ============================================================
  // COMMON INFO ROW
  // ============================================================

  Widget infoRow(
    IconData icon,
    String title,
    String value,
  ) {
    return Row(
      children: [
        Container(
          height: 34,
          width: 34,
          decoration:
              BoxDecoration(
            color:
                const Color(0xffDBEAFE),
            borderRadius:
                BorderRadius.circular(
              10,
            ),
          ),
          child: Icon(
            icon,
            color:
                const Color(0xff2563EB),
            size: 18,
          ),
        ),
        const SizedBox(width: 9),
        Text(
          "$title : ",
          style:
              const TextStyle(
            color: Colors.grey,
            fontSize: 12,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style:
                const TextStyle(
              fontWeight:
                  FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ),
      ],
    );
  }
}
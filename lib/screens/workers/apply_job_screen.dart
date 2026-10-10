import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

import 'package:servora/models/service_model.dart';
import 'package:servora/screens/workers/available_jobs_screen.dart';

import 'dart:convert';
import 'package:http/http.dart' as http;

class ApplyJobScreen extends StatefulWidget {
  final ServiceModel job;

  const ApplyJobScreen({
    super.key,
    required this.job,
  });

  @override
  State<ApplyJobScreen> createState() =>
      _ApplyJobScreenState();
}

class _ApplyJobScreenState extends State<ApplyJobScreen> {
  // ============================================================
  // COLORS
  // ============================================================

  static const Color primaryBlue =
      Color(0xff2563EB);

  static const Color darkBlue =
      Color(0xff1D4ED8);

  static const Color skyBlue =
      Color(0xff38BDF8);

  static const Color background =
      Color(0xffF4F7FC);

  static const String notificationApi =
    "http://127.0.0.1:8080/api/notifications/offer-received";    

  // ============================================================
  // CONTROLLERS
  // ============================================================

  final TextEditingController priceController =
      TextEditingController();

  final TextEditingController messageController =
      TextEditingController();

  // ============================================================
  // FIREBASE
  // ============================================================

  final DatabaseReference applicationsRef =
      FirebaseDatabase.instance.ref("applications");

  // ============================================================
  // STATE
  // ============================================================

  bool loading = false;

  bool acceptCustomerPrice = false;
  bool get isUrgentOrEmergency {
  final String urgency =
      widget.job.urgency.trim().toLowerCase();

  return urgency == "urgent" ||
      urgency == "emergency";
}

bool get isEmergency {
  return widget.job.urgency.trim().toLowerCase() ==
      "emergency";
}
  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    priceController.dispose();
    messageController.dispose();
    super.dispose();
  }

  // ============================================================
  // CHECK ALREADY APPLIED
  // ============================================================

  Future<bool> alreadyApplied() async {
    User? user =
        FirebaseAuth.instance.currentUser;

    if (user == null) {
      return false;
    }

    DatabaseEvent event =
        await applicationsRef.once();

    if (!event.snapshot.exists) {
      return false;
    }

    Map data =
        Map.from(
          event.snapshot.value as Map,
        );

    for (var value in data.values) {
      Map app =
          Map.from(value);

      if (app["serviceId"] ==
              widget.job.serviceId &&
          app["workerId"] ==
              user.uid) {
        return true;
      }
    }

    return false;
  }


  Future<void> notifyCustomerAboutOffer({
  required String serviceId,
  required String workerId,
  required String customerId,
  required String title,
  required String message,
}) async {
  try {
    final response = await http.post(
      Uri.parse(notificationApi),
      headers: {
        "Content-Type": "application/json",
      },
      body: jsonEncode({
        "serviceId": serviceId,
        "workerId": workerId,
        "customerId": customerId,
        "title": title,
        "message": message,
      }),
    );

    debugPrint(
      "Offer notification status: ${response.statusCode}",
    );

    debugPrint(
      "Offer notification response: ${response.body}",
    );

    if (response.statusCode >= 200 &&
        response.statusCode < 300) {
      debugPrint(
        "Customer notification sent successfully",
      );
    } else {
      debugPrint(
        "Customer notification failed",
      );
    }
  } catch (e) {
    debugPrint(
      "Customer notification error: $e",
    );
  }
}

  // ============================================================
  // SUBMIT APPLICATION
  // ============================================================

  Future<void> submitApplication() async {
  if (!validateOffer()) {
    return;
  }

  try {
    setState(() {
      loading = true;
    });

    // ============================================================
    // GET CURRENT WORKER
    // ============================================================

    User? user =
        FirebaseAuth.instance.currentUser;

    if (user == null) {
      throw Exception(
        "Worker not logged in",
      );
    }

    // ============================================================
    // CHECK ALREADY APPLIED
    // ============================================================

    bool exists =
        await alreadyApplied();

    if (exists) {
      if (mounted) {
        setState(() {
          loading = false;
        });

        _showMessage(
          "You already applied for this service",
        );
      }

      return;
    }

    // ============================================================
    // GET CUSTOMER ID
    // ============================================================

    String customerId =
        widget.job.customerId;

    if (customerId.isEmpty) {
      throw Exception(
        "Customer information missing",
      );
    }

    // ============================================================
    // CREATE APPLICATION REFERENCE
    // ============================================================

    DatabaseReference applicationRef =
        FirebaseDatabase.instance
            .ref("applications")
            .push();

    // ============================================================
    // PREPARE OFFER DATA
    // ============================================================

    final String workerPrice =
    isUrgentOrEmergency
        ? priceController.text.trim()
        : acceptCustomerPrice
            ? widget.job.budget
            : priceController.text.trim();

 final String applicationMessage =
    isUrgentOrEmergency
        ? messageController.text.trim()
        : acceptCustomerPrice
            ? "Worker accepted customer budget"
            : messageController.text.trim();

   final String priceType =
    isUrgentOrEmergency
        ? "worker_bid"
        : acceptCustomerPrice
            ? "customer_price"
            : "worker_offer";
final String priceStatus =
    isUrgentOrEmergency
        ? "pending"
        : acceptCustomerPrice
            ? "agreed"
            : "negotiating";

    // ============================================================
    // CREATE APPLICATION
    // ============================================================

  await applicationRef.set({
  "applicationId":
      applicationRef.key,

  "serviceId":
      widget.job.serviceId,

  "customerId":
      customerId,

  "workerId":
      user.uid,

  "workerName":
      user.displayName ?? "Worker",

  "workerPhone":
      user.phoneNumber ?? "",

  "urgency":
      widget.job.urgency,

  "workerPrice":
      workerPrice,

  "currentOffer":
      workerPrice,

  "message":
      applicationMessage,

  "priceType":
      priceType,

  "priceStatus":
      priceStatus,

  "status":
      "pending",

  "createdAt":
      DateTime.now().toIso8601String(),
});
    // ============================================================
    // NOTIFICATION TITLE
    // ============================================================

   final String notificationTitle =
    isUrgentOrEmergency
        ? "New Bid Received"
        : acceptCustomerPrice
            ? "Worker Accepted Your Budget"
            : "New Worker Offer";

    // ============================================================
    // NOTIFICATION MESSAGE
    // ============================================================

 final String notificationMessage =
    isUrgentOrEmergency
        ? "${user.displayName ?? "A worker"} submitted a bid of ₹$workerPrice for your ${widget.job.serviceName} request."
        : acceptCustomerPrice
            ? "${user.displayName ?? "A worker"} accepted your budget for ${widget.job.serviceName}."
            : "${user.displayName ?? "A worker"} sent you a new offer for ${widget.job.serviceName}.";
    // ============================================================
    // SEND NOTIFICATION TO CUSTOMER
    //
    // Flutter → Spring Boot → Firebase FCM → Customer
    // ============================================================

    await notifyCustomerAboutOffer(
      serviceId:
          widget.job.serviceId,

      workerId:
          user.uid,

      customerId:
          customerId,

      title:
          notificationTitle,

      message:
          notificationMessage,
    );

    // ============================================================
    // APPLICATION SUCCESS
    // ============================================================

    if (!mounted) {
      return;
    }

    setState(() {
      loading = false;
    });

    _showMessage(
      "Application Sent Successfully",
    );

    // ============================================================
    // WAIT BEFORE NAVIGATION
    // ============================================================

    await Future.delayed(
      const Duration(
        milliseconds: 500,
      ),
    );

    if (!mounted) {
      return;
    }

    // ============================================================
    // GO BACK TO AVAILABLE JOBS
    // ============================================================

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            const AvailableJobsScreen(),
      ),
    );
  } catch (e) {
    // ============================================================
    // ERROR HANDLING
    // ============================================================

    if (!mounted) {
      return;
    }

    setState(() {
      loading = false;
    });

    _showMessage(
      e.toString(),
    );
  }
}
  // ============================================================
  // VALIDATION
  // ============================================================

bool validateOffer() {
  // ============================================================
  // URGENT / EMERGENCY
  // WORKER MUST ENTER THEIR OWN PRICE
  // ============================================================

  if (isUrgentOrEmergency) {
    final String price =
        priceController.text.trim();

    final String message =
        messageController.text.trim();

    if (price.isEmpty) {
      _showMessage(
        "Please enter your bid amount",
      );
      return false;
    }

    final double? amount =
        double.tryParse(price);

    if (amount == null || amount <= 0) {
      _showMessage(
        "Please enter a valid bid amount",
      );
      return false;
    }

    if (message.isEmpty) {
      _showMessage(
        "Please enter a message for the customer",
      );
      return false;
    }

    if (message.length < 10) {
      _showMessage(
        "Message should contain minimum 10 characters",
      );
      return false;
    }

    return true;
  }

  // ============================================================
  // NORMAL SERVICE
  // ============================================================

  if (acceptCustomerPrice) {
    return true;
  }

  final String price =
      priceController.text.trim();

  final String message =
      messageController.text.trim();

  if (price.isEmpty) {
    _showMessage(
      "Please enter your service price",
    );

    return false;
  }

  if (double.tryParse(price) == null) {
    _showMessage(
      "Please enter valid price",
    );

    return false;
  }

  if (message.isEmpty) {
    _showMessage(
      "Please enter message for customer",
    );

    return false;
  }

  if (message.length < 10) {
    _showMessage(
      "Message should contain minimum 10 characters",
    );

    return false;
  }

  return true;
}
  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          background,

      appBar:
          _buildAppBar(),

      body:
          SingleChildScrollView(
        physics:
            const BouncingScrollPhysics(),

        padding:
            const EdgeInsets.fromLTRB(
          16,
          14,
          16,
          35,
        ),

        child:
            Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,

          children: [
            _buildHeroSection(),

            const SizedBox(
              height: 20,
            ),

            _buildOfferHeading(),

            const SizedBox(
              height: 15,
            ),

            _buildOfferSection(),

            const SizedBox(
              height: 18,
            ),

            _buildOfferPreview(),

            const SizedBox(
              height: 25,
            ),

            _submitButton(),

            const SizedBox(
              height: 18,
            ),

            _buildSecurityNote(),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // APP BAR
  // ============================================================

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor:
          Colors.white,

      foregroundColor:
          const Color(0xff111827),

      elevation:
          0,

      scrolledUnderElevation:
          0,

      leading:
          Padding(
        padding:
            const EdgeInsets.only(
          left: 10,
        ),
        child:
            _appBarButton(
          Icons.arrow_back_rounded,
          () {
            Navigator.pop(context);
          },
        ),
      ),

      titleSpacing:
          8,

      title:
          const Text(
        "Apply For Job",
        style:
            TextStyle(
          fontSize: 20,
          fontWeight:
              FontWeight.w800,
          letterSpacing:
              -0.4,
        ),
      ),

      actions: [
        Padding(
          padding:
              const EdgeInsets.only(
            right: 12,
          ),
          child:
              _appBarButton(
            Icons.help_outline_rounded,
            () {
              _showMessage(
                "Review the customer budget and send your best offer.",
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _appBarButton(
    IconData icon,
    VoidCallback onTap,
  ) {
    return Material(
      color:
          const Color(0xffF1F5F9),

      borderRadius:
          BorderRadius.circular(13),

      child:
          InkWell(
        borderRadius:
            BorderRadius.circular(13),

        onTap:
            onTap,

        child:
            SizedBox(
          height: 42,
          width: 42,

          child:
              Icon(
            icon,
            size: 21,
            color:
                const Color(0xff334155),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // HERO SECTION
  // ============================================================

  Widget _buildHeroSection() {
    return Container(
      width:
          double.infinity,

      padding:
          const EdgeInsets.fromLTRB(
        20,
        20,
        20,
        18,
      ),

      decoration:
          BoxDecoration(
        gradient:
            const LinearGradient(
          begin:
              Alignment.topLeft,

          end:
              Alignment.bottomRight,

          colors: [
            Color(0xff2563EB),
            Color(0xff1D4ED8),
            Color(0xff38BDF8),
          ],
        ),

        borderRadius:
            BorderRadius.circular(30),

        boxShadow: [
          BoxShadow(
            color:
                primaryBlue
                    .withOpacity(0.28),

            blurRadius:
                28,

            offset:
                const Offset(
              0,
              14,
            ),
          ),
        ],
      ),

      child:
          Stack(
        children: [
          // Decorative circles
          Positioned(
            top: -65,
            right: -45,
            child:
                Container(
              height: 170,
              width: 170,
              decoration:
                  BoxDecoration(
                color:
                    Colors.white
                        .withOpacity(
                  0.08,
                ),
                shape:
                    BoxShape.circle,
              ),
            ),
          ),

          Positioned(
            bottom: -80,
            left: -60,
            child:
                Container(
              height: 190,
              width: 190,
              decoration:
                  BoxDecoration(
                color:
                    skyBlue
                        .withOpacity(
                  0.12,
                ),
                shape:
                    BoxShape.circle,
              ),
            ),
          ),

          Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,

            children: [
              Row(
                children: [
                  _animatedServiceIcon(),

                  const SizedBox(
                    width: 15,
                  ),

                  Expanded(
                    child:
                        Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,

                      children: [
                        Text(
                          widget.job.serviceName
                                  .isEmpty
                              ? "Service Request"
                              : widget.job.serviceName,

                          maxLines:
                              2,

                          overflow:
                              TextOverflow.ellipsis,

                          style:
                              const TextStyle(
                            color:
                                Colors.white,

                            fontSize:
                                22,

                            fontWeight:
                                FontWeight.w900,

                            height:
                                1.05,

                            letterSpacing:
                                -0.6,
                          ),
                        ),

                        const SizedBox(
                          height: 7,
                        ),

                        Row(
                          children: [
                            const Icon(
                              Icons
                                  .verified_rounded,

                              size:
                                  15,

                              color:
                                  Colors.white70,
                            ),

                            const SizedBox(
                              width: 5,
                            ),

                            Expanded(
                              child:
                                  Text(
                                widget.job.categoryType
                                        .isEmpty
                                    ? "Professional Service"
                                    : widget.job.categoryType,

                                maxLines:
                                    1,

                                overflow:
                                    TextOverflow.ellipsis,

                                style:
                                    const TextStyle(
                                  color:
                                      Colors.white70,

                                  fontSize:
                                      12,

                                  fontWeight:
                                      FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(
                height: 20,
              ),

              Container(
                padding:
                    const EdgeInsets.all(
                  14,
                ),

                decoration:
                    BoxDecoration(
                  color:
                      Colors.white
                          .withOpacity(
                    0.12,
                  ),

                  borderRadius:
                      BorderRadius.circular(
                    18,
                  ),

                  border:
                      Border.all(
                    color:
                        Colors.white
                            .withOpacity(
                      0.14,
                    ),
                  ),
                ),

                child:
                    Row(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,

                  children: [
                    Container(
                      height: 38,
                      width: 38,

                      decoration:
                          BoxDecoration(
                        color:
                            Colors.white
                                .withOpacity(
                          0.15,
                        ),

                        borderRadius:
                            BorderRadius.circular(
                          12,
                        ),
                      ),

                      child:
                          const Icon(
                        Icons
                            .description_rounded,

                        color:
                            Colors.white,

                        size: 20,
                      ),
                    ),

                    const SizedBox(
                      width: 11,
                    ),

                    Expanded(
                      child:
                          Text(
                        widget.job.description
                                .isEmpty
                            ? "No description provided by the customer."
                            : widget.job.description,

                        maxLines:
                            4,

                        overflow:
                            TextOverflow.ellipsis,

                        style:
                            const TextStyle(
                          color:
                              Colors.white,

                          fontSize:
                              13,

                          height:
                              1.5,

                          fontWeight:
                              FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(
                height: 15,
              ),

              _customerBudgetCard(),
            ],
          ),
        ],
      ),
    )
        .animate()
        .fadeIn(
          duration:
              550.ms,
        )
        .slideY(
          begin:
              0.10,

          end:
              0,

          duration:
              600.ms,

          curve:
              Curves.easeOutCubic,
        );
  }

  // ============================================================
  // ANIMATED SERVICE ICON
  // ============================================================

  Widget _animatedServiceIcon() {
    return Container(
      height: 68,
      width: 68,

      decoration:
          BoxDecoration(
        gradient:
            const LinearGradient(
          begin:
              Alignment.topLeft,

          end:
              Alignment.bottomRight,

          colors: [
            Colors.white,
            Color(0xffDBEAFE),
          ],
        ),

        borderRadius:
            BorderRadius.circular(22),

        boxShadow: [
          BoxShadow(
            color:
                Colors.black
                    .withOpacity(
              0.20,
            ),

            blurRadius:
                20,

            offset:
                const Offset(
              0,
              10,
            ),
          ),
        ],
      ),

      child:
          Icon(
        _serviceIcon(
          widget.job.serviceName,
        ),

        color:
            primaryBlue,

        size:
            34,
      ),
    )
        .animate(
      onPlay:
          (controller) =>
              controller.repeat(
        reverse:
            true,
      ),
    )
        .moveY(
      begin:
          0,

      end:
          -5,

      duration:
          1700.ms,

      curve:
          Curves.easeInOut,
    );
  }

  // ============================================================
  // CUSTOMER BUDGET
  // ============================================================

  Widget _customerBudgetCard() {
    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 15,
        vertical: 13,
      ),

      decoration:
          BoxDecoration(
        color:
            Colors.white
                .withOpacity(
          0.16,
        ),

        borderRadius:
            BorderRadius.circular(
          19,
        ),

        border:
            Border.all(
          color:
              Colors.white
                  .withOpacity(
            0.18,
          ),
        ),
      ),

      child:
          Row(
        children: [
          Container(
            height: 44,
            width: 44,

            decoration:
                const BoxDecoration(
              color:
                  Colors.white,

              shape:
                  BoxShape.circle,
            ),

            child:
                const Icon(
              Icons.currency_rupee_rounded,

              color:
                  primaryBlue,

              size:
                  23,
            ),
          ),

          const SizedBox(
            width: 12,
          ),

          Expanded(
            child:
                Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,

              children: [
                const Text(
                  "CUSTOMER BUDGET",

                  style:
                      TextStyle(
                    color:
                        Colors.white70,

                    fontSize:
                        9,

                    fontWeight:
                        FontWeight.w800,

                    letterSpacing:
                        1,
                  ),
                ),

                const SizedBox(
                  height: 2,
                ),

                Text(
                  "₹${widget.job.budget.isEmpty ? "0" : widget.job.budget}",

                  style:
                      const TextStyle(
                    color:
                        Colors.white,

                    fontSize:
                        21,

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
              color:
                  Colors.white
                      .withOpacity(
                0.13,
              ),

              borderRadius:
                  BorderRadius.circular(
                30,
              ),
            ),

            child:
                const Row(
              mainAxisSize:
                  MainAxisSize.min,

              children: [
                Icon(
                  Icons
                      .account_balance_wallet_rounded,

                  color:
                      Colors.white,

                  size:
                      14,
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

                    fontSize:
                        9,

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
  // OFFER HEADING
  // ============================================================

  Widget _buildOfferHeading() {
    return Column(
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
                gradient:
                    const LinearGradient(
                  colors: [
                    Color(0xff3B82F6),
                    Color(0xff2563EB),
                  ],
                ),

                borderRadius:
                    BorderRadius.circular(
                  14,
                ),

                boxShadow: [
                  BoxShadow(
                    color:
                        primaryBlue
                            .withOpacity(
                      0.20,
                    ),

                    blurRadius:
                        12,

                    offset:
                        const Offset(
                      0,
                      6,
                    ),
                  ),
                ],
              ),

              child:
                  const Icon(
                Icons
                    .local_offer_rounded,

                color:
                    Colors.white,

                size:
                    21,
              ),
            ),

            const SizedBox(
              width: 11,
            ),

            const Expanded(
              child:
                  Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,

                children: [
                  Text(
                    "Make Your Offer",

                    style:
                        TextStyle(
                      color:
                          Color(0xff111827),

                      fontSize:
                          22,

                      fontWeight:
                          FontWeight.w900,

                      letterSpacing:
                          -0.5,
                    ),
                  ),

                  SizedBox(
                    height: 3,
                  ),

                  Text(
                    "Choose how you want to respond to the customer",

                    style:
                        TextStyle(
                      color:
                          Color(0xff64748B),

                      fontSize:
                          12,

                      fontWeight:
                          FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    )
        .animate()
        .fadeIn(
          delay:
              180.ms,

          duration:
              450.ms,
        )
        .slideX(
          begin:
              -0.05,

          end:
              0,

          delay:
              180.ms,

          duration:
              500.ms,
        );
  }

  // ============================================================
  // OFFER SECTION
  // ============================================================

  Widget _buildOfferSection() {
    return Container(
      width:
          double.infinity,

      padding:
          const EdgeInsets.all(
        18,
      ),

      decoration:
          BoxDecoration(
        color:
            Colors.white,

        borderRadius:
            BorderRadius.circular(
          26,
        ),

        boxShadow: [
          BoxShadow(
            color:
                Colors.black
                    .withOpacity(
              0.055,
            ),

            blurRadius:
                24,

            offset:
                const Offset(
              0,
              10,
            ),
          ),
        ],
      ),

      child:
          Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,

       children: [
  if (!isUrgentOrEmergency)
    _buildAcceptBudgetCard(),

  if (!isUrgentOrEmergency)
    const SizedBox(
      height: 18,
    ),

  _inputLabel(
    isUrgentOrEmergency
        ? "YOUR BID AMOUNT"
        : "YOUR SERVICE PRICE",
    Icons.currency_rupee_rounded,
  ),

          const SizedBox(
            height: 8,
          ),

          TextField(
  controller:
      priceController,

  enabled:
      isUrgentOrEmergency
          ? true
          : !acceptCustomerPrice,

  keyboardType:
      const TextInputType.numberWithOptions(
    decimal: true,
  ),

            style:
                const TextStyle(
              fontSize:
                  16,

              fontWeight:
                  FontWeight.w800,

              color:
                  Color(0xff1E293B),
            ),

            decoration:
                _priceInputDecoration(),
          ),

          const SizedBox(
            height: 18,
          ),

          _inputLabel(
            "MESSAGE TO CUSTOMER",
            Icons.message_rounded,
          ),

          const SizedBox(
            height: 8,
          ),

          TextField(
            controller:
                messageController,

            maxLines:
                5,

            minLines:
                4,

            textInputAction:
                TextInputAction.newline,

            style:
                const TextStyle(
              fontSize:
                  14,

              fontWeight:
                  FontWeight.w500,

              color:
                  Color(0xff334155),

              height:
                  1.4,
            ),

            decoration:
                _messageInputDecoration(),
          ),

          const SizedBox(
            height: 8,
          ),

          Row(
            children: [
              const Icon(
                Icons
                    .info_outline_rounded,

                size:
                    14,

                color:
                    Color(0xff94A3B8),
              ),

              const SizedBox(
                width:
                    5,
              ),

              Expanded(
                child:
                    Text(
                  "Explain your experience, work plan or anything useful for the customer.",

                  style:
                      const TextStyle(
                    color:
                        Color(0xff94A3B8),

                    fontSize:
                        10,

                    fontWeight:
                        FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ],
     
      ),
    )
        .animate()
        .fadeIn(
          delay:
              280.ms,

          duration:
              500.ms,
        )
        .slideY(
          begin:
              0.08,

          end:
              0,

          delay:
              280.ms,

          duration:
              550.ms,

          curve:
              Curves.easeOutCubic,
        );
  }

  // ============================================================
  // ACCEPT CUSTOMER BUDGET CARD
  // ============================================================

  Widget _buildAcceptBudgetCard() {
    return AnimatedContainer(
      duration:
          const Duration(
        milliseconds:
            300,
      ),

      curve:
          Curves.easeOutCubic,

      width:
          double.infinity,

      padding:
          const EdgeInsets.all(
        15,
      ),

      decoration:
          BoxDecoration(
        gradient:
            acceptCustomerPrice
                ? const LinearGradient(
                    begin:
                        Alignment.topLeft,

                    end:
                        Alignment.bottomRight,

                    colors: [
                      Color(0xffEFF6FF),
                      Color(0xffDBEAFE),
                    ],
                  )
                : null,

        color:
            acceptCustomerPrice
                ? null
                : const Color(
                    0xffF8FAFC,
                  ),

        borderRadius:
            BorderRadius.circular(
          20,
        ),

        border:
            Border.all(
          color:
              acceptCustomerPrice
                  ? const Color(
                      0xff93C5FD,
                    )
                  : const Color(
                      0xffE2E8F0,
                    ),

          width:
              acceptCustomerPrice
                  ? 1.5
                  : 1,
        ),

        boxShadow:
            acceptCustomerPrice
                ? [
                    BoxShadow(
                      color:
                          primaryBlue
                              .withOpacity(
                        0.10,
                      ),

                      blurRadius:
                          15,

                      offset:
                          const Offset(
                        0,
                        7,
                      ),
                    ),
                  ]
                : [],
      ),

      child:
          Row(
        children: [
          AnimatedContainer(
            duration:
                const Duration(
              milliseconds:
                  300,
            ),

            height:
                47,

            width:
                47,

            decoration:
                BoxDecoration(
              gradient:
                  acceptCustomerPrice
                      ? const LinearGradient(
                          colors: [
                            Color(
                                0xff3B82F6),
                            Color(
                                0xff2563EB),
                          ],
                        )
                      : null,

              color:
                  acceptCustomerPrice
                      ? null
                      : const Color(
                          0xffE2E8F0,
                        ),

              borderRadius:
                  BorderRadius.circular(
                15,
              ),
            ),

            child:
                Icon(
              acceptCustomerPrice
                  ? Icons
                      .check_rounded
                  : Icons
                      .currency_rupee_rounded,

              color:
                  acceptCustomerPrice
                      ? Colors.white
                      : const Color(
                          0xff64748B,
                        ),

              size:
                  24,
            ),
          ),

          const SizedBox(
            width: 12,
          ),

          Expanded(
            child:
                Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,

              children: [
                const Text(
                  "Accept customer budget",

                  style:
                      TextStyle(
                    color:
                        Color(0xff1E293B),

                    fontSize:
                        14,

                    fontWeight:
                        FontWeight.w800,
                  ),
                ),

                const SizedBox(
                  height: 4,
                ),

                Text(
                  "Work for ₹${widget.job.budget}",

                  style:
                      TextStyle(
                    color:
                        acceptCustomerPrice
                            ? primaryBlue
                            : const Color(
                                0xff64748B,
                              ),

                    fontSize:
                        12,

                    fontWeight:
                        FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),

          Switch.adaptive(
            value:
                acceptCustomerPrice,

            activeColor:
                primaryBlue,

            onChanged:
                (value) {
              setState(() {
                acceptCustomerPrice =
                    value;

                if (value) {
                  priceController
                      .clear();

                  messageController
                      .clear();
                }
              });
            },
          ),
        ],
      ),
    );
  }

  // ============================================================
  // INPUT LABEL
  // ============================================================

  Widget _inputLabel(
    String title,
    IconData icon,
  ) {
    return Row(
      children: [
        Icon(
          icon,

          size:
              15,

          color:
              primaryBlue,
        ),

        const SizedBox(
          width: 6,
        ),

        Text(
          title,

          style:
              const TextStyle(
            color:
                Color(0xff475569),

            fontSize:
                10,

            fontWeight:
                FontWeight.w900,

            letterSpacing:
                0.7,
          ),
        ),
      ],
    );
  }

  // ============================================================
  // PRICE INPUT
  // ============================================================

  InputDecoration _priceInputDecoration() {
    return InputDecoration(
      hintText:
          "Enter your price",

      hintStyle:
          const TextStyle(
        color:
            Color(0xff94A3B8),

        fontSize:
            14,

        fontWeight:
            FontWeight.w500,
      ),

      prefixIcon:
          Container(
        margin:
            const EdgeInsets.all(
          10,
        ),

        height:
            35,

        width:
            35,

        decoration:
            BoxDecoration(
          gradient:
              const LinearGradient(
            colors: [
              Color(0xff3B82F6),
              Color(0xff2563EB),
            ],
          ),

          borderRadius:
              BorderRadius.circular(
            11,
          ),
        ),

        child:
            const Icon(
          Icons.currency_rupee_rounded,

          color:
              Colors.white,

          size:
              18,
        ),
      ),

      suffixText:
          " INR",

      suffixStyle:
          const TextStyle(
        color:
            Color(0xff94A3B8),

        fontSize:
            11,

        fontWeight:
            FontWeight.w700,
      ),

      filled:
          true,

      fillColor:
          acceptCustomerPrice
              ? const Color(
                  0xffF1F5F9,
                )
              : const Color(
                  0xffF8FAFC,
                ),

      contentPadding:
          const EdgeInsets.symmetric(
        horizontal:
            16,

        vertical:
            17,
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

      enabledBorder:
          OutlineInputBorder(
        borderRadius:
            BorderRadius.circular(
          18,
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
          18,
        ),

        borderSide:
            const BorderSide(
          color:
              primaryBlue,

          width:
              1.7,
        ),
      ),

      disabledBorder:
          OutlineInputBorder(
        borderRadius:
            BorderRadius.circular(
          18,
        ),

        borderSide:
            const BorderSide(
          color:
              Color(0xffE2E8F0),
        ),
      ),
    );
  }

  // ============================================================
  // MESSAGE INPUT
  // ============================================================

  InputDecoration _messageInputDecoration() {
    return InputDecoration(
      hintText:
          "Example: I have 5 years of experience and can complete the work within the requested schedule...",

      hintStyle:
          const TextStyle(
        color:
            Color(0xffA0AEC0),

        fontSize:
            12,

        height:
            1.5,
      ),

      prefixIcon:
          const Padding(
        padding:
            EdgeInsets.only(
          left: 14,
          right: 4,
          bottom: 70,
        ),

        child:
            Icon(
          Icons
              .chat_bubble_outline_rounded,

          color:
              primaryBlue,

          size:
              19,
        ),
      ),

      filled:
          true,

      fillColor:
          const Color(
        0xffF8FAFC,
      ),

      contentPadding:
          const EdgeInsets.all(
        16,
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

      enabledBorder:
          OutlineInputBorder(
        borderRadius:
            BorderRadius.circular(
          18,
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
          18,
        ),

        borderSide:
            const BorderSide(
          color:
              primaryBlue,

          width:
              1.7,
        ),
      ),
    );
  }

  // ============================================================
  // OFFER PREVIEW
  // ============================================================

  Widget _buildOfferPreview() {
    String price =
        acceptCustomerPrice
            ? widget.job.budget
            : priceController.text.trim();

    if (price.isEmpty) {
      price = "Not set";
    }

    String offerType =
        acceptCustomerPrice
            ? "Customer budget accepted"
            : "Your service offer";

    return AnimatedContainer(
      duration:
          const Duration(
        milliseconds:
            300,
      ),

      width:
          double.infinity,

      padding:
          const EdgeInsets.all(
        16,
      ),

      decoration:
          BoxDecoration(
        color:
            Colors.white,

        borderRadius:
            BorderRadius.circular(
          21,
        ),

        border:
            Border.all(
          color:
              const Color(
            0xffE2E8F0,
          ),
        ),

        boxShadow: [
          BoxShadow(
            color:
                Colors.black
                    .withOpacity(
              0.035,
            ),

            blurRadius:
                15,

            offset:
                const Offset(
              0,
              7,
            ),
          ),
        ],
      ),

      child:
          Row(
        children: [
          Container(
            height:
                45,

            width:
                45,

            decoration:
                BoxDecoration(
              gradient:
                  const LinearGradient(
                colors: [
                  Color(0xff3B82F6),
                  Color(0xff2563EB),
                ],
              ),

              borderRadius:
                  BorderRadius.circular(
                14,
              ),
            ),

            child:
                const Icon(
              Icons
                  .receipt_long_rounded,

              color:
                  Colors.white,

              size:
                  22,
            ),
          ),

          const SizedBox(
            width:
                11,
          ),

          Expanded(
            child:
                Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,

              children: [
                Text(
                  offerType,

                  style:
                      const TextStyle(
                    color:
                        Color(0xff64748B),

                    fontSize:
                        10,

                    fontWeight:
                        FontWeight.w700,
                  ),
                ),

                const SizedBox(
                  height:
                      3,
                ),

                Text(
                  "₹$price",

                  style:
                      const TextStyle(
                    color:
                        Color(0xff1E293B),

                    fontSize:
                        20,

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
              horizontal:
                  10,

              vertical:
                  6,
            ),

            decoration:
                BoxDecoration(
              color:
                  acceptCustomerPrice
                      ? const Color(
                          0xffDCFCE7,
                        )
                      : const Color(
                          0xffDBEAFE,
                        ),

              borderRadius:
                  BorderRadius.circular(
                30,
              ),
            ),

            child:
                Text(
              acceptCustomerPrice
                  ? "AGREED"
                  : "OFFER",

              style:
                  TextStyle(
                color:
                    acceptCustomerPrice
                        ? const Color(
                            0xff15803D,
                          )
                        : darkBlue,

                fontSize:
                    9,

                fontWeight:
                    FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    )
        .animate(
      target:
          acceptCustomerPrice
              ? 1
              : 0,
    )
        .scale(
      begin:
          const Offset(
        0.98,
        0.98,
      ),

      end:
          const Offset(
        1,
        1,
      ),

      duration:
          300.ms,
    );
  }

  // ============================================================
  // SUBMIT BUTTON
  // ============================================================

  Widget _submitButton() {
    return SizedBox(
      width:
          double.infinity,

      height:
          62,

      child:
          ElevatedButton(
        onPressed:
            loading
                ? null
                : submitApplication,

        style:
            ElevatedButton.styleFrom(
          backgroundColor:
              primaryBlue,

          disabledBackgroundColor:
              const Color(
            0xff93C5FD,
          ),

          elevation:
              10,

          shadowColor:
              primaryBlue
                  .withOpacity(
            0.35,
          ),

          shape:
              RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(
              20,
            ),
          ),

          padding:
              EdgeInsets.zero,
        ),

        child:
            loading
                ? Row(
                    mainAxisAlignment:
                        MainAxisAlignment.center,

                    children: [
                      const SizedBox(
                        height:
                            22,

                        width:
                            22,

                        child:
                            CircularProgressIndicator(
                          strokeWidth:
                              2.4,

                          color:
                              Colors.white,
                        ),
                      ),

                      const SizedBox(
                        width:
                            12,
                      ),

                      const Text(
                        "Sending Application...",

                        style:
                            TextStyle(
                          color:
                              Colors.white,

                          fontSize:
                              15,

                          fontWeight:
                              FontWeight.w800,
                        ),
                      ),
                    ],
                  )
                : Row(
                    mainAxisAlignment:
                        MainAxisAlignment.center,

                    children: [
                      Container(
                        height:
                            34,

                        width:
                            34,

                        decoration:
                            BoxDecoration(
                          color:
                              Colors.white
                                  .withOpacity(
                            0.15,
                          ),

                          shape:
                              BoxShape.circle,
                        ),

                        child:
                            const Icon(
                          Icons
                              .send_rounded,

                          color:
                              Colors.white,

                          size:
                              18,
                        ),
                      ),

                      const SizedBox(
                        width:
                            10,
                      ),

                      Text(
  isUrgentOrEmergency
      ? "Submit Bid"
      : acceptCustomerPrice
          ? "Send Application"
          : "Send Offer",

                        style:
                            const TextStyle(
                          color:
                              Colors.white,

                          fontSize:
                              17,

                          fontWeight:
                              FontWeight.w900,

                          letterSpacing:
                              -0.2,
                        ),
                      ),

                      const SizedBox(
                        width:
                            10,
                      ),

                      Container(
                        height:
                            30,

                        width:
                            30,

                        decoration:
                            BoxDecoration(
                          color:
                              Colors.white
                                  .withOpacity(
                            0.15,
                          ),

                          shape:
                              BoxShape.circle,
                        ),

                        child:
                            const Icon(
                          Icons
                              .arrow_forward_rounded,

                          color:
                              Colors.white,

                          size:
                              16,
                        ),
                      ),
                    ],
                  ),
      ),
    )
        .animate(
      onPlay:
          (controller) =>
              controller.repeat(
        reverse:
            true,
      ),
    )
        .shimmer(
      delay:
          2200.ms,

      duration:
          1400.ms,

      color:
          Colors.white
              .withOpacity(
        0.18,
      ),
    );
  }

  // ============================================================
  // SECURITY NOTE
  // ============================================================

  Widget _buildSecurityNote() {
    return Row(
      mainAxisAlignment:
          MainAxisAlignment.center,

      children: [
        Container(
          height:
              28,

          width:
              28,

          decoration:
              BoxDecoration(
            color:
                const Color(
              0xffE0ECFF,
            ),

            shape:
                BoxShape.circle,
          ),

          child:
              const Icon(
            Icons
                .shield_rounded,

            color:
                primaryBlue,

            size:
                15,
          ),
        ),

        const SizedBox(
          width:
              7,
        ),

        Flexible(
          child:
              Text(
            "Your application is securely processed by Servora",

            textAlign:
                TextAlign.center,

            style:
                const TextStyle(
              color:
                  Color(0xff94A3B8),

              fontSize:
                  10,

              fontWeight:
                  FontWeight.w600,
            ),
          ),
        ),
      ],
    )
        .animate()
        .fadeIn(
          delay:
              700.ms,

          duration:
              500.ms,
        );
  }

  // ============================================================
  // SERVICE ICON
  // ============================================================

  IconData _serviceIcon(
    String serviceName,
  ) {
    final String name =
        serviceName.toLowerCase();

    if (name.contains("clean")) {
      return Icons
          .cleaning_services_rounded;
    }

    if (name.contains("electric")) {
      return Icons
          .electrical_services_rounded;
    }

    if (name.contains("plumb")) {
      return Icons
          .plumbing_rounded;
    }

    if (name.contains("garden")) {
      return Icons
          .yard_rounded;
    }

    if (name.contains("paint")) {
      return Icons
          .format_paint_rounded;
    }

    if (name.contains("car")) {
      return Icons
          .directions_car_rounded;
    }

    if (name.contains("bike")) {
      return Icons
          .two_wheeler_rounded;
    }

    if (name.contains("repair")) {
      return Icons
          .build_circle_rounded;
    }

    if (name.contains("appliance")) {
      return Icons
          .home_repair_service_rounded;
    }

    if (name.contains("tutor")) {
      return Icons
          .school_rounded;
    }

    if (name.contains("baby")) {
      return Icons
          .child_care_rounded;
    }

    if (name.contains("elder")) {
      return Icons
          .elderly_rounded;
    }

    if (name.contains("moving")) {
      return Icons
          .local_shipping_rounded;
    }

    if (name.contains("massage")) {
      return Icons
          .spa_rounded;
    }

    return Icons
        .handyman_rounded;
  }

  // ============================================================
  // SNACKBAR
  // ============================================================

  void _showMessage(
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
        behavior:
            SnackBarBehavior.floating,

        margin:
            const EdgeInsets.all(
          16,
        ),

        backgroundColor:
            const Color(
          0xff1E293B,
        ),

        elevation:
            8,

        shape:
            RoundedRectangleBorder(
          borderRadius:
              BorderRadius.circular(
            15,
          ),
        ),

        content:
            Row(
          children: [
            const Icon(
              Icons
                  .info_outline_rounded,

              color:
                  Colors.white,

              size:
                  19,
            ),

            const SizedBox(
              width:
                  9,
            ),

            Expanded(
              child:
                  Text(
                message,

                style:
                    const TextStyle(
                  color:
                      Colors.white,

                  fontWeight:
                      FontWeight.w600,

                  fontSize:
                      13,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
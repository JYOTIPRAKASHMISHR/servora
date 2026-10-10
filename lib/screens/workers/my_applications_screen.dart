import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:servora/screens/chat_screen.dart';
import 'package:url_launcher/url_launcher.dart';

class MyApplicationsScreen extends StatefulWidget {
  const MyApplicationsScreen({
    super.key,
  });

  @override
  State<MyApplicationsScreen> createState() =>
      _MyApplicationsScreenState();
}

class _MyApplicationsScreenState
    extends State<MyApplicationsScreen> {
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

  // ============================================================
  // FIREBASE
  // ============================================================

  final DatabaseReference applicationRef =
      FirebaseDatabase.instance.ref(
    "applications",
  );

  // ============================================================
  // STATE
  // ============================================================

  List<Map> applications = [];

  bool loading = true;

  bool refreshing = false;

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();

    fetchApplications();
  }

  // ============================================================
  // FETCH APPLICATIONS
  // ============================================================

  Future<void> fetchApplications() async {
    try {
      if (mounted) {
        setState(() {
          loading = true;
        });
      }

      User? user =
          FirebaseAuth.instance.currentUser;

      if (user == null) {
        if (!mounted) return;

        setState(() {
          applications = [];
          loading = false;
        });

        return;
      }

      DatabaseEvent event =
          await applicationRef.once();

      List<Map> temp = [];

      if (event.snapshot.exists) {
        Map data =
            Map.from(
          event.snapshot.value as Map,
        );

        data.forEach((key, value) {
          if (value is! Map) {
            return;
          }

          Map app =
              Map.from(value);

          if (app["workerId"] ==
              user.uid) {
            app["applicationId"] =
                key;

            temp.add(app);
          }
        });
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
      debugPrint(
        "Fetch Applications Error: $e",
      );

      if (!mounted) return;

      setState(() {
        loading = false;
      });

      showMessage(
        "Unable to load applications",
      );
    }
  }

  // ============================================================
  // CALL CUSTOMER
  // ============================================================

  Future<void> callWorker(
    String phone,
  ) async {
    String cleanPhone =
        phone.replaceAll(
      " ",
      "",
    );

    final Uri phoneUri =
        Uri.parse(
      "tel:$cleanPhone",
    );

    try {
      if (await launchUrl(
        phoneUri,
        mode:
            LaunchMode.externalApplication,
      )) {
        debugPrint(
          "Calling $cleanPhone",
        );
      } else {
        showMessage(
          "Phone app not available",
        );
      }
    } catch (e) {
      showMessage(
        e.toString(),
      );
    }
  }

  // ============================================================
  // MESSAGE
  // ============================================================

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
        behavior:
            SnackBarBehavior.floating,

        margin:
            const EdgeInsets.all(16),

        backgroundColor:
            const Color(0xff1E293B),

        elevation: 8,

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
              size: 19,
            ),

            const SizedBox(
              width: 9,
            ),

            Expanded(
              child:
                  Text(
                text,
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

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      backgroundColor:
          background,

      appBar:
          _buildAppBar(),

      body:
          loading
              ? _loadingState()
              : applications.isEmpty
                  ? _emptyState()
                  : RefreshIndicator(
                      color:
                          primaryBlue,

                      backgroundColor:
                          Colors.white,

                      strokeWidth:
                          2.5,

                      onRefresh:
                          fetchApplications,

                      child:
                          ListView.builder(
                        physics:
                            const BouncingScrollPhysics(
                          parent:
                              AlwaysScrollableScrollPhysics(),
                        ),

                        padding:
                            const EdgeInsets.fromLTRB(
                          16,
                          10,
                          16,
                          35,
                        ),

                        itemCount:
                            applications.length + 1,

                        itemBuilder:
                            (context, index) {
                          if (index == 0) {
                            return _buildSummaryHeader();
                          }

                          final int applicationIndex =
                              index - 1;

                          return _applicationCard(
                            applications[
                                applicationIndex],
                            applicationIndex,
                          );
                        },
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
        "My Applications",
        style:
            TextStyle(
          fontSize:
              20,
          fontWeight:
              FontWeight.w900,
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
            Icons.refresh_rounded,
            () async {
              await fetchApplications();
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
          BorderRadius.circular(
        13,
      ),

      child:
          InkWell(
        borderRadius:
            BorderRadius.circular(
          13,
        ),

        onTap:
            onTap,

        child:
            SizedBox(
          height:
              42,

          width:
              42,

          child:
              Icon(
            icon,
            size:
                21,
            color:
                const Color(0xff334155),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // SUMMARY HEADER
  // ============================================================

  Widget _buildSummaryHeader() {
    int total =
        applications.length;

    int pending =
        applications
            .where(
              (app) =>
                  (app["status"] ??
                          "pending")
                      .toString()
                      .toLowerCase() ==
                  "pending",
            )
            .length;

    int accepted =
        applications
            .where(
              (app) =>
                  (app["status"] ??
                          "")
                      .toString()
                      .toLowerCase() ==
                  "accepted",
            )
            .length;

    return Container(
      margin:
          const EdgeInsets.only(
        bottom:
            17,
      ),

      padding:
          const EdgeInsets.all(
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
            Color(0xff1D4ED8),
            Color(0xff2563EB),
            Color(0xff38BDF8),
          ],
        ),

        borderRadius:
            BorderRadius.circular(
          27,
        ),

        boxShadow: [
          BoxShadow(
            color:
                primaryBlue
                    .withOpacity(
              0.25,
            ),

            blurRadius:
                25,

            offset:
                const Offset(
              0,
              12,
            ),
          ),
        ],
      ),

      child:
          Stack(
        children: [
          Positioned(
            right:
                -45,

            top:
                -65,

            child:
                Container(
              height:
                  160,

              width:
                  160,

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
            left:
                -55,

            bottom:
                -80,

            child:
                Container(
              height:
                  170,

              width:
                  170,

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
                  Container(
                    height:
                        52,

                    width:
                        52,

                    decoration:
                        BoxDecoration(
                      color:
                          Colors.white
                              .withOpacity(
                        0.16,
                      ),

                      borderRadius:
                          BorderRadius.circular(
                        16,
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
                        const Icon(
                      Icons
                          .assignment_rounded,

                      color:
                          Colors.white,

                      size:
                          27,
                    ),
                  ),

                  const SizedBox(
                    width:
                        12,
                  ),

                  const Expanded(
                    child:
                        Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,

                      children: [
                        Text(
                          "Your Applications",

                          style:
                              TextStyle(
                            color:
                                Colors.white,

                            fontSize:
                                19,

                            fontWeight:
                                FontWeight.w900,
                          ),
                        ),

                        SizedBox(
                          height:
                              3,
                        ),

                        Text(
                          "Track your offers and customer responses",

                          style:
                              TextStyle(
                            color:
                                Colors.white70,

                            fontSize:
                                10,

                            fontWeight:
                                FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(
                height:
                    18,
              ),

              Row(
                children: [
                  Expanded(
                    child:
                        _summaryStat(
                      "TOTAL",
                      total.toString(),
                      Icons
                          .assignment_outlined,
                    ),
                  ),

                  const SizedBox(
                    width:
                        8,
                  ),

                  Expanded(
                    child:
                        _summaryStat(
                      "PENDING",
                      pending.toString(),
                      Icons
                          .hourglass_top_rounded,
                    ),
                  ),

                  const SizedBox(
                    width:
                        8,
                  ),

                  Expanded(
                    child:
                        _summaryStat(
                      "ACCEPTED",
                      accepted.toString(),
                      Icons
                          .check_circle_outline_rounded,
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
        .fadeIn(
          duration:
              550.ms,
        )
        .slideY(
          begin:
              0.08,

          end:
              0,

          duration:
              600.ms,

          curve:
              Curves.easeOutCubic,
        );
  }

  Widget _summaryStat(
    String title,
    String value,
    IconData icon,
  ) {
    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal:
            9,

        vertical:
            10,
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
          16,
        ),

        border:
            Border.all(
          color:
              Colors.white
                  .withOpacity(
            0.10,
          ),
        ),
      ),

      child:
          Row(
        children: [
          Icon(
            icon,

            color:
                Colors.white,

            size:
                17,
          ),

          const SizedBox(
            width:
                6,
          ),

          Expanded(
            child:
                Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,

              children: [
                Text(
                  title,

                  style:
                      const TextStyle(
                    color:
                        Colors.white70,

                    fontSize:
                        7,

                    fontWeight:
                        FontWeight.w900,

                    letterSpacing:
                        0.5,
                  ),
                ),

                const SizedBox(
                  height:
                      1,
                ),

                Text(
                  value,

                  style:
                      const TextStyle(
                    color:
                        Colors.white,

                    fontSize:
                        17,

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
  // APPLICATION CARD
  // ============================================================

  Widget _applicationCard(
    Map data,
    int index,
  ) {
    String status =
        (data["status"] ??
                "pending")
            .toString()
            .toLowerCase();

    String currentOffer =
        (data["currentOffer"] ??
                data["workerPrice"] ??
                "0")
            .toString();

    String workerPrice =
        (data["workerPrice"] ??
                "0")
            .toString();

    bool negotiated =
        data["currentOffer"] !=
                null &&
            data["currentOffer"]
                    .toString() !=
                workerPrice;

    bool agreed =
        data["priceStatus"] ==
            "agreed";

    return Container(
      margin:
          const EdgeInsets.only(
        bottom:
            18,
      ),

      decoration:
          BoxDecoration(
        color:
            Colors.white,

        borderRadius:
            BorderRadius.circular(
          27,
        ),

        boxShadow: [
          BoxShadow(
            color:
                Colors.black
                    .withOpacity(
              0.055,
            ),

            blurRadius:
                25,

            offset:
                const Offset(
              0,
              11,
            ),
          ),
        ],
      ),

      child:
          ClipRRect(
        borderRadius:
            BorderRadius.circular(
          27,
        ),

        child:
            Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,

          children: [
            _applicationTop(
              data,
              status,
              index,
            ),

            Padding(
              padding:
                  const EdgeInsets.fromLTRB(
                18,
                16,
                18,
                18,
              ),

              child:
                  Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,

                children: [
                  _priceHero(
                    currentOffer,
                    agreed,
                  ),

                  if (negotiated)
                    _negotiatedCard(
                      currentOffer,
                    ),

                  if (agreed)
                    _agreedCard(
                      currentOffer,
                    ),

                  const SizedBox(
                    height:
                        17,
                  ),

                  _messageCard(
                    data,
                  ),

                  const SizedBox(
                    height:
                        17,
                  ),

                  _statusCard(
                    status,
                  ),

                  if (status ==
                      "accepted")
                    _acceptedCard(
                      currentOffer,
                    ),

                  if (status ==
                          "pending" &&
                      !agreed)
                    Padding(
                      padding:
                          const EdgeInsets.only(
                        top:
                            18,
                      ),

                      child:
                          _chatButton(
                        data,
                      ),
                    ),

                  if (status ==
                      "accepted")
                    Padding(
                      padding:
                          const EdgeInsets.only(
                        top:
                            18,
                      ),

                      child:
                          _workerInfoCard(
                        data,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    )
        .animate()
        .fadeIn(
          delay:
              (100 * index).ms,

          duration:
              500.ms,
        )
        .slideY(
          begin:
              0.10,

          end:
              0,

          delay:
              (100 * index).ms,

          duration:
              550.ms,

          curve:
              Curves.easeOutCubic,
        );
  }

  // ============================================================
  // APPLICATION TOP
  // ============================================================

  Widget _applicationTop(
    Map data,
    String status,
    int index,
  ) {
    return Container(
      padding:
          const EdgeInsets.all(
        17,
      ),

      decoration:
          const BoxDecoration(
        gradient:
            LinearGradient(
          begin:
              Alignment.topLeft,

          end:
              Alignment.bottomRight,

          colors: [
            Color(0xffEFF6FF),
            Color(0xffF8FBFF),
          ],
        ),
      ),

      child:
          Row(
        children: [
          Container(
            height:
                59,

            width:
                59,

            decoration:
                BoxDecoration(
              gradient:
                  const LinearGradient(
                begin:
                    Alignment.topLeft,

                end:
                    Alignment.bottomRight,

                colors: [
                  Color(0xff3B82F6),
                  Color(0xff1D4ED8),
                ],
              ),

              borderRadius:
                  BorderRadius.circular(
                19,
              ),

              boxShadow: [
                BoxShadow(
                  color:
                      primaryBlue
                          .withOpacity(
                    0.24,
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
                Icon(
              _serviceIcon(
                data["serviceName"]
                        ?.toString() ??
                    "",
              ),

              color:
                  Colors.white,

              size:
                  29,
            ),
          ),

          const SizedBox(
            width:
                13,
          ),

          Expanded(
            child:
                Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,

              children: [
                Text(
                  data["serviceName"]
                          ?.toString()
                          .isNotEmpty ==
                      true
                      ? data["serviceName"]
                          .toString()
                      : "Service Offer",

                  maxLines:
                      1,

                  overflow:
                      TextOverflow.ellipsis,

                  style:
                      const TextStyle(
                    color:
                        Color(0xff111827),

                    fontSize:
                        17,

                    fontWeight:
                        FontWeight.w900,
                  ),
                ),

                const SizedBox(
                  height:
                      4,
                ),

                Text(
                  "ID: ${data["serviceId"] ?? ""}",

                  maxLines:
                      1,

                  overflow:
                      TextOverflow.ellipsis,

                  style:
                      const TextStyle(
                    color:
                        Color(0xff94A3B8),

                    fontSize:
                        9,

                    fontWeight:
                        FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),

          _statusMiniBadge(
            status,
          ),
        ],
      ),
    );
  }

  // ============================================================
  // STATUS MINI BADGE
  // ============================================================

  Widget _statusMiniBadge(
    String status,
  ) {
    Color color =
        _statusColor(status);

    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal:
            9,

        vertical:
            7,
      ),

      decoration:
          BoxDecoration(
        color:
            color.withOpacity(
          0.10,
        ),

        borderRadius:
            BorderRadius.circular(
          30,
        ),

        border:
            Border.all(
          color:
              color.withOpacity(
            0.16,
          ),
        ),
      ),

      child:
          Row(
        mainAxisSize:
            MainAxisSize.min,

        children: [
          Container(
            height:
                7,

            width:
                7,

            decoration:
                BoxDecoration(
              color:
                  color,

              shape:
                  BoxShape.circle,
            ),
          ),

          const SizedBox(
            width:
                5,
          ),

          Text(
            status.toUpperCase(),

            style:
                TextStyle(
              color:
                  color,

              fontSize:
                  8,

              fontWeight:
                  FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // PRICE HERO
  // ============================================================

  Widget _priceHero(
    String price,
    bool agreed,
  ) {
    return Container(
      width:
          double.infinity,

      padding:
          const EdgeInsets.all(
        17,
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
            Color(0xff1D4ED8),
            Color(0xff2563EB),
            Color(0xff38BDF8),
          ],
        ),

        borderRadius:
            BorderRadius.circular(
          21,
        ),

        boxShadow: [
          BoxShadow(
            color:
                primaryBlue
                    .withOpacity(
              0.18,
            ),

            blurRadius:
                18,

            offset:
                const Offset(
              0,
              8,
            ),
          ),
        ],
      ),

      child:
          Row(
        children: [
          Container(
            height:
                49,

            width:
                49,

            decoration:
                BoxDecoration(
              color:
                  Colors.white
                      .withOpacity(
                0.14,
              ),

              borderRadius:
                  BorderRadius.circular(
                15,
              ),
            ),

            child:
                const Icon(
              Icons
                  .currency_rupee_rounded,

              color:
                  Colors.white,

              size:
                  24,
            ),
          ),

          const SizedBox(
            width:
                12,
          ),

          Expanded(
            child:
                Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,

              children: [
                Text(
                  agreed
                      ? "FINAL AGREED PRICE"
                      : "CURRENT OFFER",

                  style:
                      const TextStyle(
                    color:
                        Colors.white70,

                    fontSize:
                        8,

                    fontWeight:
                        FontWeight.w900,

                    letterSpacing:
                        0.7,
                  ),
                ),

                const SizedBox(
                  height:
                      2,
                ),

                Text(
                  "₹$price",

                  style:
                      const TextStyle(
                    color:
                        Colors.white,

                    fontSize:
                        25,

                    fontWeight:
                        FontWeight.w900,

                    letterSpacing:
                        -0.5,
                  ),
                ),
              ],
            ),
          ),

          if (agreed)
            Container(
              padding:
                  const EdgeInsets.symmetric(
                horizontal:
                    9,

                vertical:
                    7,
              ),

              decoration:
                  BoxDecoration(
                color:
                    Colors.white
                        .withOpacity(
                  0.15,
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
                        .check_circle_rounded,

                    color:
                        Colors.white,

                    size:
                        14,
                  ),

                  SizedBox(
                    width:
                        4,
                  ),

                  Text(
                    "AGREED",

                    style:
                        TextStyle(
                      color:
                          Colors.white,

                      fontSize:
                          8,

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
  // NEGOTIATED CARD
  // ============================================================

  Widget _negotiatedCard(
    String price,
  ) {
    return Container(
      margin:
          const EdgeInsets.only(
        top:
            10,
      ),

      padding:
          const EdgeInsets.all(
        12,
      ),

      decoration:
          BoxDecoration(
        color:
            const Color(0xffFFF7ED),

        borderRadius:
            BorderRadius.circular(
          15,
        ),

        border:
            Border.all(
          color:
              const Color(0xffFED7AA),
        ),
      ),

      child:
          Row(
        children: [
          Container(
            height:
                32,

            width:
                32,

            decoration:
                const BoxDecoration(
              color:
                  Color(0xffFFEDD5),

              shape:
                  BoxShape.circle,
            ),

            child:
                const Icon(
              Icons
                  .swap_horiz_rounded,

              color:
                  Color(0xffEA580C),

              size:
                  18,
            ),
          ),

          const SizedBox(
            width:
                9,
          ),

          Expanded(
            child:
                Text(
              "Negotiated Price: ₹$price",

              style:
                  const TextStyle(
                color:
                    Color(0xffC2410C),

                fontSize:
                    12,

                fontWeight:
                    FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // AGREED CARD
  // ============================================================

  Widget _agreedCard(
    String price,
  ) {
    return Container(
      margin:
          const EdgeInsets.only(
        top:
            10,
      ),

      padding:
          const EdgeInsets.all(
        12,
      ),

      decoration:
          BoxDecoration(
        color:
            const Color(0xffF0FDF4),

        borderRadius:
            BorderRadius.circular(
          15,
        ),

        border:
            Border.all(
          color:
              const Color(0xffBBF7D0),
        ),
      ),

      child:
          Row(
        children: [
          Container(
            height:
                32,

            width:
                32,

            decoration:
                const BoxDecoration(
              color:
                  Color(0xffDCFCE7),

              shape:
                  BoxShape.circle,
            ),

            child:
                const Icon(
              Icons
                  .verified_rounded,

              color:
                  Color(0xff16A34A),

              size:
                  18,
            ),
          ),

          const SizedBox(
            width:
                9,
          ),

          Expanded(
            child:
                Text(
              "Final Agreed Price: ₹$price",

              style:
                  const TextStyle(
                color:
                    Color(0xff15803D),

                fontSize:
                    12,

                fontWeight:
                    FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // MESSAGE CARD
  // ============================================================

  Widget _messageCard(
    Map data,
  ) {
    String message =
        (data["message"] ??
                "No message")
            .toString();

    return Container(
      width:
          double.infinity,

      padding:
          const EdgeInsets.all(
        14,
      ),

      decoration:
          BoxDecoration(
        color:
            const Color(0xffF8FAFC),

        borderRadius:
            BorderRadius.circular(
          18,
        ),

        border:
            Border.all(
          color:
              const Color(0xffE2E8F0),
        ),
      ),

      child:
          Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,

        children: [
          Container(
            height:
                39,

            width:
                39,

            decoration:
                BoxDecoration(
              color:
                  const Color(0xffE0ECFF),

              borderRadius:
                  BorderRadius.circular(
                12,
              ),
            ),

            child:
                const Icon(
              Icons
                  .chat_bubble_outline_rounded,

              color:
                  primaryBlue,

              size:
                  19,
            ),
          ),

          const SizedBox(
            width:
                10,
          ),

          Expanded(
            child:
                Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,

              children: [
                const Text(
                  "WORKER MESSAGE",

                  style:
                      TextStyle(
                    color:
                        Color(0xff94A3B8),

                    fontSize:
                        8,

                    fontWeight:
                        FontWeight.w900,

                    letterSpacing:
                        0.7,
                  ),
                ),

                const SizedBox(
                  height:
                      4,
                ),

                Text(
                  message,

                  style:
                      const TextStyle(
                    color:
                        Color(0xff334155),

                    fontSize:
                        13,

                    height:
                        1.45,

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
  // STATUS CARD
  // ============================================================

  Widget _statusCard(
    String status,
  ) {
    Color color =
        _statusColor(status);

    String description;

    switch (status) {
      case "accepted":
        description =
            "Customer accepted your application.";
        break;

      case "rejected":
        description =
            "This application was rejected.";
        break;

      default:
        description =
            "Waiting for customer response.";
    }

    return Container(
      padding:
          const EdgeInsets.all(
        14,
      ),

      decoration:
          BoxDecoration(
        color:
            color.withOpacity(
          0.06,
        ),

        borderRadius:
            BorderRadius.circular(
          18,
        ),

        border:
            Border.all(
          color:
              color.withOpacity(
            0.12,
          ),
        ),
      ),

      child:
          Row(
        children: [
          Container(
            height:
                40,

            width:
                40,

            decoration:
                BoxDecoration(
              color:
                  color.withOpacity(
                0.12,
              ),

              shape:
                  BoxShape.circle,
            ),

            child:
                Icon(
              _statusIcon(
                status,
              ),

              color:
                  color,

              size:
                  20,
            ),
          ),

          const SizedBox(
            width:
                10,
          ),

          Expanded(
            child:
                Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,

              children: [
                Text(
                  status.toUpperCase(),

                  style:
                      TextStyle(
                    color:
                        color,

                    fontSize:
                        10,

                    fontWeight:
                        FontWeight.w900,

                    letterSpacing:
                        0.6,
                  ),
                ),

                const SizedBox(
                  height:
                      3,
                ),

                Text(
                  description,

                  style:
                      const TextStyle(
                    color:
                        Color(0xff64748B),

                    fontSize:
                        10,

                    fontWeight:
                        FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

          if (status ==
              "pending")
            _pulsingDot(color),
        ],
      ),
    );
  }

  Widget _pulsingDot(
    Color color,
  ) {
    return Container(
      height:
          12,

      width:
          12,

      decoration:
          BoxDecoration(
        color:
            color,

        shape:
            BoxShape.circle,
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
        .scale(
      begin:
          const Offset(
        0.65,
        0.65,
      ),

      end:
          const Offset(
        1.15,
        1.15,
      ),

      duration:
          800.ms,
    )
        .fade(
      begin:
          0.5,

      end:
          1,

      duration:
          800.ms,
    );
  }

  // ============================================================
  // ACCEPTED CARD
  // ============================================================

  Widget _acceptedCard(
    String price,
  ) {
    return Container(
      margin:
          const EdgeInsets.only(
        top:
            15,
      ),

      padding:
          const EdgeInsets.all(
        16,
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
            Color(0xffDCFCE7),
            Color(0xffF0FDF4),
          ],
        ),

        borderRadius:
            BorderRadius.circular(
          20,
        ),

        border:
            Border.all(
          color:
              const Color(0xffBBF7D0),
        ),

        boxShadow: [
          BoxShadow(
            color:
                Colors.green
                    .withOpacity(
              0.08,
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
                48,

            width:
                48,

            decoration:
                const BoxDecoration(
              color:
                  Colors.white,

              shape:
                  BoxShape.circle,
            ),

            child:
                const Icon(
              Icons
                  .celebration_rounded,

              color:
                  Color(0xff16A34A),

              size:
                  25,
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
                const Text(
                  "Offer Accepted",

                  style:
                      TextStyle(
                    color:
                        Color(0xff15803D),

                    fontSize:
                        16,

                    fontWeight:
                        FontWeight.w900,
                  ),
                ),

                const SizedBox(
                  height:
                      3,
                ),

                Text(
                  "Final Price: ₹$price",

                  style:
                      const TextStyle(
                    color:
                        Color(0xff166534),

                    fontSize:
                        12,

                    fontWeight:
                        FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),

          const Icon(
            Icons
                .check_circle_rounded,

            color:
                Color(0xff16A34A),

            size:
                25,
          ),
        ],
      ),
    )
        .animate()
        .fadeIn(
          duration:
              450.ms,
        )
        .scale(
          begin:
              const Offset(
            0.96,
            0.96,
          ),

          end:
              const Offset(
            1,
            1,
          ),

          duration:
              500.ms,
        );
  }

  // ============================================================
  // CHAT BUTTON
  // ============================================================

  Widget _chatButton(
    Map data,
  ) {
    return SizedBox(
      width:
          double.infinity,

      height:
          54,

      child:
          ElevatedButton(
        style:
            ElevatedButton.styleFrom(
          backgroundColor:
              primaryBlue,

          elevation:
              7,

          shadowColor:
              primaryBlue
                  .withOpacity(
            0.30,
          ),

          shape:
              RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(
              17,
            ),
          ),
        ),

        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  ChatScreen(
                serviceId:
                    data[
                        "serviceId"],

                customerId:
                    data[
                        "customerId"],

                workerId:
                    data[
                        "workerId"],

                applicationId:
                    data[
                        "applicationId"],
              ),
            ),
          );
        },

        child:
            Row(
          mainAxisAlignment:
              MainAxisAlignment.center,

          children: [
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
                    .chat_rounded,

                color:
                    Colors.white,

                size:
                    17,
              ),
            ),

            const SizedBox(
              width:
                  9,
            ),

            const Text(
              "Chat With Customer",

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

            const SizedBox(
              width:
                  9,
            ),

            const Icon(
              Icons
                  .arrow_forward_rounded,

              color:
                  Colors.white,

              size:
                  18,
            ),
          ],
        ),
      ),
    )
        .animate()
        .fadeIn(
          duration:
              450.ms,
        )
        .slideY(
          begin:
              0.12,

          end:
              0,

          duration:
              500.ms,
        );
  }

  // ============================================================
  // CUSTOMER INFORMATION
  // ============================================================

  Widget _workerInfoCard(
    Map data,
  ) {
    return FutureBuilder<DataSnapshot>(
      future:
          FirebaseDatabase.instance
              .ref("users")
              .child(
                data[
                    "customerId"],
              )
              .get(),

      builder:
          (context, snapshot) {
        if (snapshot.connectionState ==
            ConnectionState.waiting) {
          return Container(
            padding:
                const EdgeInsets.all(
              18,
            ),

            decoration:
                BoxDecoration(
              color:
                  const Color(
                0xffF8FAFC,
              ),

              borderRadius:
                  BorderRadius.circular(
                18,
              ),
            ),

            child:
                const Center(
              child:
                  SizedBox(
                height:
                    22,

                width:
                    22,

                child:
                    CircularProgressIndicator(
                  strokeWidth:
                      2,

                  color:
                      primaryBlue,
                ),
              ),
            ),
          );
        }

        if (!snapshot.hasData ||
            snapshot.data!.value ==
                null) {
          return Container(
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
                17,
              ),
            ),

            child:
                const Text(
              "Customer information unavailable",
              style:
                  TextStyle(
                color:
                    Color(0xff64748B),

                fontSize:
                    12,
              ),
            ),
          );
        }

        if (snapshot.data!.value
            is! Map) {
          return const Text(
            "Customer information unavailable",
          );
        }

        Map customer =
            Map.from(
          snapshot.data!.value
              as Map,
        );

        String customerName =
            customer["name"]
                    ?.toString() ??
                "Customer";

        String phone =
            customer["phone"]
                    ?.toString() ??
                "";

        return Container(
          padding:
              const EdgeInsets.all(
            15,
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
                Color(0xffF8FAFC),
                Color(0xffEFF6FF),
              ],
            ),

            borderRadius:
                BorderRadius.circular(
              20,
            ),

            border:
                Border.all(
              color:
                  const Color(
                0xffDDE8F7,
              ),
            ),
          ),

          child:
              Row(
            children: [
              Container(
                height:
                    55,

                width:
                    55,

                decoration:
                    BoxDecoration(
                  gradient:
                      const LinearGradient(
                    colors: [
                      Color(0xffDBEAFE),
                      Color(0xffBFDBFE),
                    ],
                  ),

                  shape:
                      BoxShape.circle,

                  boxShadow: [
                    BoxShadow(
                      color:
                          primaryBlue
                              .withOpacity(
                        0.12,
                      ),

                      blurRadius:
                          12,

                      offset:
                          const Offset(
                        0,
                        5,
                      ),
                    ),
                  ],
                ),

                child:
                    const Icon(
                  Icons
                      .person_rounded,

                  color:
                      primaryBlue,

                  size:
                      31,
                ),
              ),

              const SizedBox(
                width:
                    12,
              ),

              Expanded(
                child:
                    Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,

                  children: [
                    const Text(
                      "CUSTOMER",

                      style:
                          TextStyle(
                        color:
                            Color(0xff94A3B8),

                        fontSize:
                            8,

                        fontWeight:
                            FontWeight.w900,

                        letterSpacing:
                            0.8,
                      ),
                    ),

                    const SizedBox(
                      height:
                          3,
                    ),

                    Text(
                      customerName,

                      maxLines:
                          1,

                      overflow:
                          TextOverflow.ellipsis,

                      style:
                          const TextStyle(
                        color:
                            Color(0xff1E293B),

                        fontSize:
                            16,

                        fontWeight:
                            FontWeight.w900,
                      ),
                    ),

                    if (phone
                        .isNotEmpty)
                      Padding(
                        padding:
                            const EdgeInsets.only(
                          top:
                              3,
                        ),

                        child:
                            Text(
                          phone,

                          maxLines:
                              1,

                          overflow:
                              TextOverflow.ellipsis,

                          style:
                              const TextStyle(
                            color:
                                Color(0xff64748B),

                            fontSize:
                                10,

                            fontWeight:
                                FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              if (phone
                  .isNotEmpty)
                Material(
                  color:
                      const Color(
                    0xffDCFCE7,
                  ),

                  shape:
                      const CircleBorder(),

                  child:
                      InkWell(
                    customBorder:
                        const CircleBorder(),

                    onTap: () {
                      callWorker(
                        phone,
                      );
                    },

                    child:
                        const SizedBox(
                      height:
                          43,

                      width:
                          43,

                      child:
                          Icon(
                        Icons
                            .call_rounded,

                        color:
                            Color(
                          0xff16A34A,
                        ),

                        size:
                            21,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  // ============================================================
  // STATUS COLOR
  // ============================================================

  Color _statusColor(
    String status,
  ) {
    switch (status) {
      case "accepted":
        return const Color(
          0xff16A34A,
        );

      case "rejected":
        return const Color(
          0xffDC2626,
        );

      case "completed":
        return const Color(
          0xff7C3AED,
        );

      case "started":
        return const Color(
          0xff2563EB,
        );

      default:
        return const Color(
          0xffEA580C,
        );
    }
  }

  // ============================================================
  // STATUS ICON
  // ============================================================

  IconData _statusIcon(
    String status,
  ) {
    switch (status) {
      case "accepted":
        return Icons
            .check_circle_rounded;

      case "rejected":
        return Icons
            .cancel_rounded;

      case "completed":
        return Icons
            .task_alt_rounded;

      case "started":
        return Icons
            .play_circle_rounded;

      default:
        return Icons
            .hourglass_top_rounded;
    }
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
  // LOADING STATE
  // ============================================================

  Widget _loadingState() {
    return Center(
      child:
          Column(
        mainAxisAlignment:
            MainAxisAlignment.center,

        children: [
          Container(
            height:
                80,

            width:
                80,

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
                25,
              ),

              boxShadow: [
                BoxShadow(
                  color:
                      primaryBlue
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
                const Padding(
              padding:
                  EdgeInsets.all(
                25,
              ),

              child:
                  CircularProgressIndicator(
                strokeWidth:
                    2.5,

                color:
                    Colors.white,
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
              .scale(
            begin:
                const Offset(
              0.90,
              0.90,
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
            height:
                22,
          ),

          const Text(
            "Loading Applications...",

            style:
                TextStyle(
              color:
                  Color(0xff334155),

              fontSize:
                  16,

              fontWeight:
                  FontWeight.w800,
            ),
          ),

          const SizedBox(
            height:
                6,
          ),

          const Text(
            "Please wait",

            style:
                TextStyle(
              color:
                  Color(0xff94A3B8),

              fontSize:
                  11,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // EMPTY STATE
  // ============================================================

  Widget _emptyState() {
    return Center(
      child:
          Padding(
        padding:
            const EdgeInsets.all(
          30,
        ),

        child:
            Column(
          mainAxisAlignment:
              MainAxisAlignment.center,

          children: [
            Container(
              height:
                  135,

              width:
                  135,

              decoration:
                  BoxDecoration(
                gradient:
                    const LinearGradient(
                  begin:
                      Alignment.topLeft,

                  end:
                      Alignment.bottomRight,

                  colors: [
                    Color(0xffDBEAFE),
                    Color(0xffEFF6FF),
                  ],
                ),

                shape:
                    BoxShape.circle,

                boxShadow: [
                  BoxShadow(
                    color:
                        primaryBlue
                            .withOpacity(
                      0.12,
                    ),

                    blurRadius:
                        25,

                    offset:
                        const Offset(
                      0,
                      10,
                    ),
                  ),
                ],
              ),

              child:
                  const Icon(
                Icons
                    .assignment_outlined,

                size:
                    65,

                color:
                    primaryBlue,
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
                .scale(
              begin:
                  const Offset(
                0.94,
                0.94,
              ),

              end:
                  const Offset(
                1.04,
                1.04,
              ),

              duration:
                  1300.ms,
            ),

            const SizedBox(
              height:
                  27,
            ),

            const Text(
              "No Applications Yet",

              style:
                  TextStyle(
                color:
                    Color(0xff111827),

                fontSize:
                    23,

                fontWeight:
                    FontWeight.w900,

                letterSpacing:
                    -0.5,
              ),
            ),

            const SizedBox(
              height:
                  9,
            ),

            const Text(
              "Apply for available jobs and\ntrack your offers here.",

              textAlign:
                  TextAlign.center,

              style:
                  TextStyle(
                color:
                    Color(0xff64748B),

                fontSize:
                    13,

                height:
                    1.5,

                fontWeight:
                    FontWeight.w500,
              ),
            ),

            const SizedBox(
              height:
                  28,
            ),

            SizedBox(
              height:
                  52,

              child:
                  ElevatedButton.icon(
                onPressed:
                    fetchApplications,

                icon:
                    const Icon(
                  Icons
                      .refresh_rounded,

                  color:
                      Colors.white,
                ),

                label:
                    const Text(
                  "Refresh Applications",

                  style:
                      TextStyle(
                    color:
                        Colors.white,

                    fontWeight:
                        FontWeight.w800,
                  ),
                ),

                style:
                    ElevatedButton.styleFrom(
                  backgroundColor:
                      primaryBlue,

                  elevation:
                      7,

                  shadowColor:
                      primaryBlue
                          .withOpacity(
                    0.25,
                  ),

                  padding:
                      const EdgeInsets.symmetric(
                    horizontal:
                        23,
                  ),

                  shape:
                      RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(
                      16,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
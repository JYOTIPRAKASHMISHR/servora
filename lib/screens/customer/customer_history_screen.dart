import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'customer_service_tracking_screen.dart';

class CustomerHistoryScreen extends StatefulWidget {
  const CustomerHistoryScreen({super.key});

  @override
  State<CustomerHistoryScreen> createState() =>
      _CustomerHistoryScreenState();
}

class _CustomerHistoryScreenState extends State<CustomerHistoryScreen> {
  // ============================================================
  // COLORS
  // ============================================================

  static const Color primaryBlue = Color(0xff2563EB);
  static const Color secondaryBlue = Color(0xff38BDF8);
  static const Color darkBlue = Color(0xff0F172A);
  static const Color background = Color(0xffF4F7FC);

  // ============================================================
  // FIREBASE
  // ============================================================

  final DatabaseReference servicesRef =
      FirebaseDatabase.instance.ref("services");

  List<Map<String, dynamic>> services = [];

  StreamSubscription<DatabaseEvent>? subscription;

  bool loading = true;

  final User? currentUser = FirebaseAuth.instance.currentUser;

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();

    listenHistory();
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
  // LISTEN HISTORY
  // ============================================================

  void listenHistory() {
    subscription?.cancel();

    if (currentUser == null) {
      if (mounted) {
        setState(() {
          services = [];
          loading = false;
        });
      }

      return;
    }

    setState(() {
      loading = true;
    });

    subscription = servicesRef.onValue.listen(
      (event) {
        if (!event.snapshot.exists ||
            event.snapshot.value == null) {
          if (!mounted) return;

          setState(() {
            services = [];
            loading = false;
          });

          return;
        }

        final rawData = event.snapshot.value;

        if (rawData is! Map) {
          if (!mounted) return;

          setState(() {
            services = [];
            loading = false;
          });

          return;
        }

        final Map<dynamic, dynamic> data =
            Map<dynamic, dynamic>.from(rawData);

        final List<Map<String, dynamic>> temp = [];

        data.forEach((key, value) {
          if (value is! Map) {
            return;
          }

          final Map<String, dynamic> service =
              Map<String, dynamic>.from(value);

          final String customerId =
              service["customerId"]?.toString() ?? "";

          final String status =
              service["status"]?.toString().toLowerCase() ?? "";

          final bool belongsToCurrentUser =
              customerId == currentUser!.uid;

          final bool isHistoryStatus =
              status == "assigned" ||
              status == "started" ||
              status == "completed" ||
              status == "confirmed";

          if (belongsToCurrentUser && isHistoryStatus) {
            temp.add({
              "serviceId": key.toString(),
              ...service,
            });
          }
        });

        temp.sort((a, b) {
          final dynamic dateA = a["createdAt"];
          final dynamic dateB = b["createdAt"];

          final int aValue =
              int.tryParse(dateA?.toString() ?? "") ?? 0;

          final int bValue =
              int.tryParse(dateB?.toString() ?? "") ?? 0;

          return bValue.compareTo(aValue);
        });

        if (!mounted) return;

        setState(() {
          services = temp;
          loading = false;
        });
      },
      onError: (error) {
        if (!mounted) return;

        setState(() {
          loading = false;
        });

        _showMessage(
          "Unable to load service history.",
          isError: true,
        );
      },
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

@override
Widget build(BuildContext context) {
  final int completedCount = services.where((service) {
    final status =
        service["status"]?.toString().toLowerCase() ?? "";

    return status == "completed" || status == "confirmed";
  }).length;

  final int activeCount = services.where((service) {
    final status =
        service["status"]?.toString().toLowerCase() ?? "";

    return status == "assigned" || status == "started";
  }).length;

  return Scaffold(
    backgroundColor: background,

    body: RefreshIndicator(
      color: primaryBlue,

      onRefresh: () async {
        listenHistory();

        await Future.delayed(
          const Duration(milliseconds: 700),
        );
      },

      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),

        slivers: [
          // ============================================================
          // PREMIUM APP BAR
          // ============================================================

          SliverAppBar(
            expandedHeight: 285,
            collapsedHeight: 70,
            pinned: true,

            elevation: 0,

            backgroundColor: darkBlue,
            foregroundColor: Colors.white,

            // ----------------------------------------------------------
            // BACK BUTTON
            // ----------------------------------------------------------

            leading: Padding(
              padding: const EdgeInsets.all(8),

              child: _headerButton(
                icon: Icons.arrow_back_rounded,

                onTap: () {
                  Navigator.pop(context);
                },
              ),
            ),

            // ----------------------------------------------------------
            // REFRESH BUTTON
            // ----------------------------------------------------------

            actions: [
              Padding(
                padding: const EdgeInsets.all(8),

                child: _headerButton(
                  icon: Icons.refresh_rounded,

                  onTap: loading
                      ? null
                      : listenHistory,
                ),
              ),
            ],

            // ----------------------------------------------------------
            // FLEXIBLE SPACE
            // ----------------------------------------------------------

            flexibleSpace: FlexibleSpaceBar(
              collapseMode: CollapseMode.parallax,

              // IMPORTANT:
              // Keep collapsed title away from back/refresh buttons.
              titlePadding: const EdgeInsets.only(
                left: 70,
                right: 60,
                bottom: 15,
              ),

              title: const Text(
                "My Services",

                maxLines: 1,

                overflow: TextOverflow.ellipsis,

                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),

              background: _premiumHeader(
                completedCount,
                activeCount,
              ),
            ),
          ),

          // ============================================================
          // LOADING
          // ============================================================

          if (loading)
            SliverToBoxAdapter(
              child: _loadingContent(),
            )

          // ============================================================
          // EMPTY
          // ============================================================

          else if (services.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: _emptyWidget(),
            )

          // ============================================================
          // SERVICES
          // ============================================================

          else ...[
            SliverToBoxAdapter(
              child: _sectionHeader(),
            ),

            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                18,
                0,
                18,
                30,
              ),

              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    return _serviceCard(
                      services[index],
                      index,
                    );
                  },

                  childCount: services.length,
                ),
              ),
            ),
          ],
        ],
      ),
    ),
  );
}

// ======================================================================
// PREMIUM HEADER
// ======================================================================

Widget _premiumHeader(
  int completedCount,
  int activeCount,
) {
  return Container(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,

        colors: [
          Color(0xff020617),
          Color(0xff0F172A),
          Color(0xff1D4ED8),
          Color(0xff2563EB),
        ],
      ),
    ),

    child: Stack(
      clipBehavior: Clip.hardEdge,

      children: [
        // ============================================================
        // BACKGROUND GLOW
        // ============================================================

        Positioned(
          top: -70,
          right: -55,

          child: _glowCircle(
            size: 180,
            color: secondaryBlue,
          ),
        ),

        Positioned(
          bottom: -80,
          left: -60,

          child: _glowCircle(
            size: 190,
            color: primaryBlue,
          ),
        ),

        Positioned(
          top: 110,
          right: 80,

          child: _glowCircle(
            size: 55,
            color: Colors.white,
          ),
        ),

        // ============================================================
        // HEADER CONTENT
        // ============================================================

        SafeArea(
          bottom: false,

          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              22,
              92,
              22,
              20,
            ),

            child: Column(
              mainAxisSize: MainAxisSize.min,

              crossAxisAlignment:
                  CrossAxisAlignment.start,

              children: [
                // ======================================================
                // TITLE ROW
                // ======================================================

                Row(
                  crossAxisAlignment:
                      CrossAxisAlignment.center,

                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,

                        mainAxisSize: MainAxisSize.min,

                        children: [
                          const Text(
                            "Your Service Journey",

                            maxLines: 1,

                            overflow:
                                TextOverflow.ellipsis,

                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight:
                                  FontWeight.w900,
                              letterSpacing: -.5,
                            ),
                          ),

                          const SizedBox(height: 5),

                          Text(
                            "Track all your booked services",

                            maxLines: 1,

                            overflow:
                                TextOverflow.ellipsis,

                            style: TextStyle(
                              color: Colors.white
                                  .withOpacity(.72),
                              fontSize: 12,
                              fontWeight:
                                  FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(width: 12),

                    // ==================================================
                    // HISTORY ICON
                    // ==================================================

                    Container(
                      width: 48,
                      height: 48,

                      decoration: BoxDecoration(
                        color: Colors.white
                            .withOpacity(.12),

                        borderRadius:
                            BorderRadius.circular(15),

                        border: Border.all(
                          color: Colors.white
                              .withOpacity(.18),
                        ),

                        boxShadow: [
                          BoxShadow(
                            color: Colors.black
                                .withOpacity(.20),

                            blurRadius: 15,

                            offset:
                                const Offset(0, 7),
                          ),
                        ],
                      ),

                      child: const Icon(
                        Icons.history_rounded,

                        color: Colors.white,

                        size: 25,
                      ),
                    )
                        .animate()
                        .fadeIn(
                          duration: 500.ms,
                        )
                        .scale(
                          begin: const Offset(
                            .7,
                            .7,
                          ),
                        ),
                  ],
                ),

                const SizedBox(height: 18),

                // ======================================================
                // STAT CARDS
                // ======================================================

                Row(
                  children: [
                    Expanded(
                      child: _headerStat(
                        icon: Icons
                            .miscellaneous_services_rounded,

                        value:
                            services.length.toString(),

                        label: "TOTAL",
                      ),
                    ),

                    const SizedBox(width: 9),

                    Expanded(
                      child: _headerStat(
                        icon:
                            Icons.bolt_rounded,

                        value:
                            activeCount.toString(),

                        label: "ACTIVE",
                      ),
                    ),

                    const SizedBox(width: 9),

                    Expanded(
                      child: _headerStat(
                        icon:
                            Icons.verified_rounded,

                        value:
                            completedCount.toString(),

                        label: "DONE",
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  )
      .animate()
      .fadeIn(
        duration: 450.ms,
      );
}
  // ============================================================
  // HEADER STAT
  // ============================================================

  Widget _headerStat({
    required IconData icon,
    required String value,
    required String label,
  }) {
    return Container(
      height: 64,

      padding: const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 8,
      ),

      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.11),

        borderRadius: BorderRadius.circular(17),

        border: Border.all(
          color: Colors.white.withOpacity(.15),
        ),

        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.12),
            blurRadius: 14,
            offset: const Offset(0, 7),
          ),
        ],
      ),

      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,

            decoration: BoxDecoration(
              color: Colors.white.withOpacity(.13),
              borderRadius:
                  BorderRadius.circular(10),
            ),

            child: Icon(
              icon,
              color: Colors.white,
              size: 18,
            ),
          ),

          const SizedBox(width: 7),

          Expanded(
            child: Column(
              mainAxisAlignment:
                  MainAxisAlignment.center,

              crossAxisAlignment:
                  CrossAxisAlignment.start,

              children: [
                Text(
                  value,
                  maxLines: 1,
                  overflow:
                      TextOverflow.ellipsis,

                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),

                const SizedBox(height: 1),

                Text(
                  label,
                  maxLines: 1,
                  overflow:
                      TextOverflow.ellipsis,

                  style: TextStyle(
                    color: Colors.white
                        .withOpacity(.62),
                    fontSize: 8,
                    fontWeight: FontWeight.w700,
                    letterSpacing: .5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    )
        .animate()
        .fadeIn(
          delay: 150.ms,
          duration: 500.ms,
        )
        .slideY(
          begin: .15,
          end: 0,
        );
  }

  // ============================================================
  // GLOW CIRCLE
  // ============================================================

  Widget _glowCircle({
    required double size,
    required Color color,
  }) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,

        decoration: BoxDecoration(
          shape: BoxShape.circle,

          color: color.withOpacity(.08),

          boxShadow: [
            BoxShadow(
              color: color.withOpacity(.12),
              blurRadius: 80,
              spreadRadius: 20,
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // HEADER BUTTON
  // ============================================================

  Widget _headerButton({
    required IconData icon,
    required VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.white.withOpacity(.12),

      borderRadius:
          BorderRadius.circular(14),

      child: InkWell(
        borderRadius:
            BorderRadius.circular(14),

        onTap: onTap,

        child: SizedBox(
          width: 42,
          height: 42,

          child: Icon(
            icon,
            color: Colors.white,
            size: 21,
          ),
        ),
      ),
    );
  }

  // ============================================================
  // SECTION HEADER
  // ============================================================

  Widget _sectionHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        20,
        22,
        20,
        14,
      ),

      child: Row(
        children: [
          Container(
            width: 4,
            height: 24,

            decoration: BoxDecoration(
              color: primaryBlue,
              borderRadius:
                  BorderRadius.circular(10),
            ),
          ),

          const SizedBox(width: 10),

          const Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,

              children: [
                Text(
                  "Service History",
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                    color: darkBlue,
                  ),
                ),

                SizedBox(height: 2),

                Text(
                  "Your recent service activity",
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

          Container(
            padding:
                const EdgeInsets.symmetric(
              horizontal: 11,
              vertical: 7,
            ),

            decoration: BoxDecoration(
              color: primaryBlue
                  .withOpacity(.08),

              borderRadius:
                  BorderRadius.circular(20),
            ),

            child: Text(
              "${services.length} SERVICES",
              style: const TextStyle(
                color: primaryBlue,
                fontSize: 9,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    )
        .animate()
        .fadeIn(duration: 400.ms)
        .slideX(begin: -.08);
  }

  // ============================================================
  // SERVICE CARD
  // ============================================================

  Widget _serviceCard(
    Map<String, dynamic> data,
    int index,
  ) {
    final String status =
        data["status"]?.toString().toLowerCase() ??
            "assigned";

    final String serviceName =
        data["serviceName"]?.toString() ??
            "Service Request";

    final String workerId =
        data["assignedWorkerId"]?.toString() ??
            "Not Assigned";

    final dynamic finalPrice =
        data["finalPrice"];

    final Color statusColor =
        _statusColor(status);

    final IconData statusIcon =
        _statusIcon(status);

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,

          MaterialPageRoute(
            builder: (context) =>
                CustomerServiceTrackingScreen(
              serviceId:
                  data["serviceId"],
            ),
          ),
        );
      },

      child: Container(
        margin:
            const EdgeInsets.only(bottom: 18),

        decoration: BoxDecoration(
          color: Colors.white,

          borderRadius:
              BorderRadius.circular(26),

          border: Border.all(
            color: Colors.black.withOpacity(.035),
          ),

          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(.07),
              blurRadius: 22,
              offset: const Offset(0, 10),
            ),

            BoxShadow(
              color: primaryBlue.withOpacity(.035),
              blurRadius: 30,
              offset: const Offset(0, 5),
            ),
          ],
        ),

        child: ClipRRect(
          borderRadius:
              BorderRadius.circular(26),

          child: Column(
            children: [
              // ==================================================
              // TOP ACCENT
              // ==================================================

              Container(
                height: 5,

                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      statusColor,
                      statusColor.withOpacity(.45),
                      primaryBlue,
                    ],
                  ),
                ),
              ),

              Padding(
                padding:
                    const EdgeInsets.all(17),

                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,

                  children: [
                    // ==================================================
                    // SERVICE HEADER
                    // ==================================================

                    Row(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,

                      children: [
                        _serviceIcon(
                          serviceName,
                          statusColor,
                        ),

                        const SizedBox(width: 13),

                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,

                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      serviceName,
                                      maxLines: 2,
                                      overflow:
                                          TextOverflow.ellipsis,

                                      style:
                                          const TextStyle(
                                        fontSize: 17,
                                        fontWeight:
                                            FontWeight.w900,
                                        color: darkBlue,
                                      ),
                                    ),
                                  ),

                                  const SizedBox(
                                    width: 7,
                                  ),

                                  Icon(
                                    Icons
                                        .arrow_forward_ios_rounded,
                                    size: 14,
                                    color: Colors
                                        .grey
                                        .shade400,
                                  ),
                                ],
                              ),

                              const SizedBox(height: 6),

                              Text(
                                "ID: ${_shortServiceId(data["serviceId"])}",
                                maxLines: 1,
                                overflow:
                                    TextOverflow.ellipsis,

                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors
                                      .grey
                                      .shade500,
                                  fontWeight:
                                      FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // ==================================================
                    // STATUS
                    // ==================================================

                    _statusContainer(
                      status,
                      statusColor,
                      statusIcon,
                    ),

                    const SizedBox(height: 14),

                    // ==================================================
                    // INFORMATION
                    // ==================================================

                    Row(
                      children: [
                        Expanded(
                          child: _infoTile(
                            icon: Icons
                                .currency_rupee_rounded,
                            title: "FINAL PRICE",
                            value:
                                "₹${_formatPrice(finalPrice)}",
                            iconColor:
                                Colors.green,
                          ),
                        ),

                        const SizedBox(width: 10),

                        Expanded(
                          child: _infoTile(
                            icon:
                                Icons.person_rounded,
                            title: "WORKER",
                            value: _shortWorkerId(
                              workerId,
                            ),
                            iconColor:
                                primaryBlue,
                          ),
                        ),
                      ],
                    ),

                    // ==================================================
                    // LOCATION
                    // ==================================================

                    if ((data["location"]
                                ?.toString()
                                .isNotEmpty ??
                            false)) ...[
                      const SizedBox(height: 11),

                      _locationCard(
                        data["location"]
                            .toString(),
                      ),
                    ],

                    const SizedBox(height: 15),

                    // ==================================================
                    // VIEW TRACKING
                    // ==================================================

                    _trackingButton(
                      statusColor,
                      data["serviceId"].toString(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    )
        .animate()
        .fadeIn(
          delay: Duration(
            milliseconds: 80 * index,
          ),
          duration: 500.ms,
        )
        .slideY(
          begin: .14,
          end: 0,
          curve: Curves.easeOutCubic,
        );
  }

  // ============================================================
  // SERVICE ICON
  // ============================================================

  Widget _serviceIcon(
    String serviceName,
    Color statusColor,
  ) {
    final String name =
        serviceName.toLowerCase();

    IconData icon =
        Icons.home_repair_service_rounded;

    if (name.contains("clean")) {
      icon = Icons.cleaning_services_rounded;
    } else if (name.contains("electric")) {
      icon = Icons.electrical_services_rounded;
    } else if (name.contains("plumb")) {
      icon = Icons.plumbing_rounded;
    } else if (name.contains("garden")) {
      icon = Icons.yard_rounded;
    } else if (name.contains("paint")) {
      icon = Icons.format_paint_rounded;
    } else if (name.contains("car")) {
      icon = Icons.directions_car_rounded;
    } else if (name.contains("bike")) {
      icon = Icons.two_wheeler_rounded;
    } else if (name.contains("repair")) {
      icon = Icons.build_circle_rounded;
    } else if (name.contains("appliance")) {
      icon = Icons.kitchen_rounded;
    } else if (name.contains("tutor")) {
      icon = Icons.school_rounded;
    } else if (name.contains("baby")) {
      icon = Icons.child_friendly_rounded;
    } else if (name.contains("elder")) {
      icon = Icons.elderly_rounded;
    }

    return Container(
      width: 58,
      height: 58,

      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            statusColor.withOpacity(.16),
            statusColor.withOpacity(.06),
          ],
        ),

        borderRadius:
            BorderRadius.circular(18),

        border: Border.all(
          color: statusColor.withOpacity(.12),
        ),

        boxShadow: [
          BoxShadow(
            color: statusColor.withOpacity(.08),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),

      child: Icon(
        icon,
        color: statusColor,
        size: 28,
      ),
    )
        .animate()
        .scale(
          begin: const Offset(.8, .8),
          duration: 450.ms,
          curve: Curves.easeOutBack,
        );
  }

  // ============================================================
  // STATUS CONTAINER
  // ============================================================

  Widget _statusContainer(
    String status,
    Color color,
    IconData icon,
  ) {
    return Container(
      width: double.infinity,

      padding:
          const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 10,
      ),

      decoration: BoxDecoration(
        color: color.withOpacity(.07),

        borderRadius:
            BorderRadius.circular(15),

        border: Border.all(
          color: color.withOpacity(.12),
        ),
      ),

      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,

            decoration: BoxDecoration(
              color: color.withOpacity(.13),
              shape: BoxShape.circle,
            ),

            child: Icon(
              icon,
              color: color,
              size: 16,
            ),
          ),

          const SizedBox(width: 10),

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,

              children: [
                Text(
                  _statusTitle(status),
                  maxLines: 1,
                  overflow:
                      TextOverflow.ellipsis,

                  style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight:
                        FontWeight.w900,
                  ),
                ),

                const SizedBox(height: 2),

                Text(
                  _statusDescription(status),
                  maxLines: 1,
                  overflow:
                      TextOverflow.ellipsis,

                  style: TextStyle(
                    color: color.withOpacity(.70),
                    fontSize: 9,
                    fontWeight:
                        FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

          Container(
            padding:
                const EdgeInsets.symmetric(
              horizontal: 9,
              vertical: 5,
            ),

            decoration: BoxDecoration(
              color: color.withOpacity(.13),
              borderRadius:
                  BorderRadius.circular(20),
            ),

            child: Text(
              status.toUpperCase(),
              style: TextStyle(
                color: color,
                fontSize: 8,
                fontWeight:
                    FontWeight.w900,
                letterSpacing: .5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // INFO TILE
  // ============================================================

  Widget _infoTile({
    required IconData icon,
    required String title,
    required String value,
    required Color iconColor,
  }) {
    return Container(
      constraints:
          const BoxConstraints(
        minHeight: 70,
      ),

      padding:
          const EdgeInsets.all(11),

      decoration: BoxDecoration(
        color: const Color(0xffF8FAFC),

        borderRadius:
            BorderRadius.circular(16),

        border: Border.all(
          color: Colors.black.withOpacity(.045),
        ),
      ),

      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,

            decoration: BoxDecoration(
              color: iconColor.withOpacity(.10),
              borderRadius:
                  BorderRadius.circular(10),
            ),

            child: Icon(
              icon,
              color: iconColor,
              size: 17,
            ),
          ),

          const SizedBox(width: 8),

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

                  style: TextStyle(
                    color: Colors.grey.shade500,
                    fontSize: 8,
                    fontWeight:
                        FontWeight.w800,
                    letterSpacing: .4,
                  ),
                ),

                const SizedBox(height: 4),

                Text(
                  value,
                  maxLines: 1,
                  overflow:
                      TextOverflow.ellipsis,

                  style: const TextStyle(
                    color: darkBlue,
                    fontSize: 12,
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
  // LOCATION CARD
  // ============================================================

  Widget _locationCard(String location) {
    return Container(
      width: double.infinity,

      padding:
          const EdgeInsets.symmetric(
        horizontal: 11,
        vertical: 10,
      ),

      decoration: BoxDecoration(
        color: const Color(0xffF8FAFC),

        borderRadius:
            BorderRadius.circular(14),

        border: Border.all(
          color: Colors.black.withOpacity(.04),
        ),
      ),

      child: Row(
        children: [
          Container(
            width: 31,
            height: 31,

            decoration: BoxDecoration(
              color: Colors.red.withOpacity(.08),
              borderRadius:
                  BorderRadius.circular(9),
            ),

            child: const Icon(
              Icons.location_on_rounded,
              color: Colors.redAccent,
              size: 17,
            ),
          ),

          const SizedBox(width: 9),

          Expanded(
            child: Text(
              location,
              maxLines: 2,
              overflow:
                  TextOverflow.ellipsis,

              style: TextStyle(
                color: Colors.grey.shade700,
                fontSize: 10,
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
  // TRACKING BUTTON
  // ============================================================

  Widget _trackingButton(
    Color statusColor,
    String serviceId,
  ) {
    return Container(
      width: double.infinity,

      height: 48,

      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            statusColor,
            statusColor.withOpacity(.82),
          ],
        ),

        borderRadius:
            BorderRadius.circular(15),

        boxShadow: [
          BoxShadow(
            color: statusColor.withOpacity(.22),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
child: Material(
  color: Colors.transparent,

  child: InkWell(
    borderRadius: BorderRadius.circular(15),

    onTap: () {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => CustomerServiceTrackingScreen(
            serviceId: serviceId,
          ),
        ),
      );
    },

    child: const Row(
      mainAxisAlignment: MainAxisAlignment.center,

      children: [
        Icon(
          Icons.location_searching_rounded,
          color: Colors.white,
          size: 18,
        ),

        SizedBox(width: 8),

        Text(
          "VIEW SERVICE TRACKING",
          style: TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w900,
            letterSpacing: .5,
          ),
        ),

        SizedBox(width: 7),

        Icon(
          Icons.arrow_forward_rounded,
          color: Colors.white,
          size: 17,
        ),
      ],
    ),
  ),
),
    );
  }

  // ============================================================
  // LOADING
  // ============================================================

 Widget _loadingContent() {
  return Padding(
    padding: const EdgeInsets.fromLTRB(
      18,
      20,
      18,
      30,
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(
        3,
        (index) {
          return Container(
            margin: const EdgeInsets.only(
              bottom: 16,
            ),

            padding: const EdgeInsets.all(17),

            decoration: BoxDecoration(
              color: Colors.white,

              borderRadius:
                  BorderRadius.circular(25),

              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(.05),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),

            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                // ============================================
                // TOP ROW
                // ============================================

                Row(
                  crossAxisAlignment:
                      CrossAxisAlignment.center,
                  children: [
                    _loadingBox(
                      width: 58,
                      height: 58,
                      radius: 18,
                    ),

                    const SizedBox(width: 12),

                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          _loadingBox(
                            width: 170,
                            height: 15,
                            radius: 8,
                          ),

                          const SizedBox(height: 8),

                          _loadingBox(
                            width: 105,
                            height: 10,
                            radius: 6,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // ============================================
                // STATUS
                // ============================================

                _loadingBox(
                  width: double.infinity,
                  height: 42,
                  radius: 14,
                ),

                const SizedBox(height: 12),

                // ============================================
                // INFORMATION
                // ============================================

                Row(
                  children: [
                    Expanded(
                      child: _loadingBox(
                        width: double.infinity,
                        height: 60,
                        radius: 14,
                      ),
                    ),

                    const SizedBox(width: 10),

                    Expanded(
                      child: _loadingBox(
                        width: double.infinity,
                        height: 60,
                        radius: 14,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // ============================================
                // BUTTON
                // ============================================

                _loadingBox(
                  width: double.infinity,
                  height: 44,
                  radius: 14,
                ),
              ],
            ),
          )
              .animate(
                onPlay: (controller) {
                  controller.repeat();
                },
              )
              .shimmer(
                duration: 1200.ms,
              );
        },
      ),
    ),
  );
}
  Widget _loadingBox({
    required double width,
    required double height,
    required double radius,
  }) {
    return Container(
      width: width,
      height: height,

      decoration: BoxDecoration(
        color: const Color(0xffE8EDF5),
        borderRadius:
            BorderRadius.circular(radius),
      ),
    );
  }

  // ============================================================
  // EMPTY STATE
  // ============================================================

  Widget _emptyWidget() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),

        child: Column(
          mainAxisAlignment:
              MainAxisAlignment.center,

          children: [
            Container(
              width: 125,
              height: 125,

              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xffDBEAFE),
                    Color(0xffEFF6FF),
                  ],
                ),

                shape: BoxShape.circle,

                boxShadow: [
                  BoxShadow(
                    color:
                        primaryBlue.withOpacity(.10),
                    blurRadius: 30,
                    spreadRadius: 5,
                  ),
                ],
              ),

              child: const Icon(
                Icons.history_rounded,
                size: 60,
                color: primaryBlue,
              ),
            )
                .animate()
                .scale(
                  begin:
                      const Offset(.7, .7),
                  duration: 600.ms,
                  curve:
                      Curves.easeOutBack,
                ),

            const SizedBox(height: 24),

            const Text(
              "No Services Yet",
              textAlign: TextAlign.center,

              style: TextStyle(
                fontSize: 23,
                fontWeight: FontWeight.w900,
                color: darkBlue,
              ),
            ),

            const SizedBox(height: 8),

            Text(
              "Your completed and active services\nwill appear here.",
              textAlign: TextAlign.center,

              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 13,
                height: 1.5,
                fontWeight:
                    FontWeight.w500,
              ),
            ),

            const SizedBox(height: 22),

            Container(
              padding:
                  const EdgeInsets.symmetric(
                horizontal: 17,
                vertical: 10,
              ),

              decoration: BoxDecoration(
                color:
                    primaryBlue.withOpacity(.08),

                borderRadius:
                    BorderRadius.circular(25),
              ),

              child: const Row(
                mainAxisSize:
                    MainAxisSize.min,

                children: [
                  Icon(
                    Icons.touch_app_rounded,
                    color: primaryBlue,
                    size: 17,
                  ),

                  SizedBox(width: 7),

                  Text(
                    "Book a service to get started",
                    style: TextStyle(
                      color: primaryBlue,
                      fontSize: 11,
                      fontWeight:
                          FontWeight.w800,
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
  // STATUS COLOR
  // ============================================================

  Color _statusColor(String status) {
    switch (status) {
      case "assigned":
        return const Color(0xff2563EB);

      case "started":
        return const Color(0xffF59E0B);

      case "completed":
        return const Color(0xff16A34A);

      case "confirmed":
        return const Color(0xff059669);

      case "cancelled":
        return const Color(0xffDC2626);

      default:
        return const Color(0xff64748B);
    }
  }

  // ============================================================
  // STATUS ICON
  // ============================================================

  IconData _statusIcon(String status) {
    switch (status) {
      case "assigned":
        return Icons.assignment_ind_rounded;

      case "started":
        return Icons.engineering_rounded;

      case "completed":
        return Icons.task_alt_rounded;

      case "confirmed":
        return Icons.verified_rounded;

      case "cancelled":
        return Icons.cancel_rounded;

      default:
        return Icons.info_rounded;
    }
  }

  // ============================================================
  // STATUS TITLE
  // ============================================================

  String _statusTitle(String status) {
    switch (status) {
      case "assigned":
        return "Worker Assigned";

      case "started":
        return "Service In Progress";

      case "completed":
        return "Service Completed";

      case "confirmed":
        return "Service Confirmed";

      case "cancelled":
        return "Service Cancelled";

      default:
        return "Service Status";
    }
  }

  // ============================================================
  // STATUS DESCRIPTION
  // ============================================================

  String _statusDescription(String status) {
    switch (status) {
      case "assigned":
        return "Your worker has been assigned";

      case "started":
        return "The worker has started the service";

      case "completed":
        return "The service has been completed";

      case "confirmed":
        return "You confirmed this service";

      case "cancelled":
        return "This service was cancelled";

      default:
        return "View service details";
    }
  }

  // ============================================================
  // SHORT SERVICE ID
  // ============================================================

  String _shortServiceId(dynamic value) {
    final String id =
        value?.toString() ?? "";

    if (id.isEmpty) {
      return "N/A";
    }

    if (id.length <= 12) {
      return id;
    }

    return "${id.substring(0, 6)}...${id.substring(id.length - 4)}";
  }

  // ============================================================
  // SHORT WORKER ID
  // ============================================================

  String _shortWorkerId(String workerId) {
    if (workerId == "Not Assigned") {
      return workerId;
    }

    if (workerId.length <= 13) {
      return workerId;
    }

    return "${workerId.substring(0, 6)}...";
  }

  // ============================================================
  // FORMAT PRICE
  // ============================================================

  String _formatPrice(dynamic value) {
    if (value == null ||
        value.toString().isEmpty) {
      return "0";
    }

    final double? price =
        double.tryParse(
      value.toString(),
    );

    if (price == null) {
      return value.toString();
    }

    if (price % 1 == 0) {
      return price.toInt().toString();
    }

    return price.toStringAsFixed(2);
  }

  // ============================================================
  // MESSAGE
  // ============================================================

  void _showMessage(
    String message, {
    bool isError = false,
  }) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior:
              SnackBarBehavior.floating,

          margin:
              const EdgeInsets.all(16),

          backgroundColor:
              isError
                  ? Colors.red.shade700
                  : darkBlue,

          shape:
              RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(14),
          ),

          content: Row(
            children: [
              Icon(
                isError
                    ? Icons.error_outline_rounded
                    : Icons.check_circle_outline_rounded,
                color: Colors.white,
              ),

              const SizedBox(width: 10),

              Expanded(
                child: Text(
                  message,
                  style:
                      const TextStyle(
                    color: Colors.white,
                    fontWeight:
                        FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
  }
}
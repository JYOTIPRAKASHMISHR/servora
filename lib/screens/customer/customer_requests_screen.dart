import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'customer_applications_screen.dart';

class CustomerRequestsScreen extends StatefulWidget {
  const CustomerRequestsScreen({
    super.key,
  });

  @override
  State<CustomerRequestsScreen> createState() =>
      _CustomerRequestsScreenState();
}

class _CustomerRequestsScreenState
    extends State<CustomerRequestsScreen> {
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

  List<Map<String, dynamic>> requests = [];

  bool loading = true;

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();
    fetchRequests();
  }

  // ============================================================
  // DELETE SERVICE
  // ============================================================

  Future<void> deleteService(String serviceId) async {
    try {
      await FirebaseDatabase.instance
          .ref("services")
          .child(serviceId)
          .remove();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.green.shade600,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          content: const Row(
            children: [
              Icon(
                Icons.check_circle,
                color: Colors.white,
              ),
              SizedBox(width: 10),
              Text(
                "Service request deleted",
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      );

      await fetchRequests();
    } catch (e) {
      debugPrint("DELETE ERROR: $e");

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.red.shade600,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          content: const Row(
            children: [
              Icon(
                Icons.error_outline,
                color: Colors.white,
              ),
              SizedBox(width: 10),
              Text(
                "Failed to delete request",
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      );
    }
  }

  // ============================================================
  // FETCH CUSTOMER REQUESTS
  // ============================================================

  Future<void> fetchRequests() async {
    if (mounted) {
      setState(() {
        loading = true;
      });
    }

    try {
      final User? user =
          FirebaseAuth.instance.currentUser;

      if (user == null) {
        if (!mounted) return;

        setState(() {
          requests = [];
          loading = false;
        });

        return;
      }

      final DatabaseEvent serviceEvent =
          await servicesRef.once();

      final List<Map<String, dynamic>> temp = [];

      if (serviceEvent.snapshot.exists) {
        final dynamic rawData =
            serviceEvent.snapshot.value;

        if (rawData is Map) {
          for (final item in rawData.entries) {
            final dynamic value = item.value;

            if (value is! Map) {
              continue;
            }

            final Map<String, dynamic> service =
                Map<String, dynamic>.from(value);

            final String customerId =
                (service["customerId"] ?? "")
                    .toString();

            if (customerId == user.uid &&
                _shouldShowInRequests(service)) {
              final String serviceId =
                  item.key.toString();

              final int count =
                  await getApplicationCount(
                serviceId,
              );

              temp.add({
                "serviceId": serviceId,
                ...service,
                "applicationCount": count,
              });
            }
          }
        }
      }

      if (!mounted) return;

      setState(() {
        requests = temp;
        loading = false;
      });
    } catch (e) {
      debugPrint(
        "FETCH REQUEST ERROR: $e",
      );

      if (!mounted) return;

      setState(() {
        loading = false;
      });
    }
  }

  // ============================================================
  // GET APPLICATION COUNT
  // ============================================================

  Future<int> getApplicationCount(
    String serviceId,
  ) async {
    int count = 0;

    try {
      // ========================================================
      // NORMAL APPLICATIONS
      // ========================================================

      final DatabaseEvent normalEvent =
          await FirebaseDatabase.instance
              .ref("applications")
              .once();

      if (normalEvent.snapshot.exists) {
        final dynamic raw =
            normalEvent.snapshot.value;

        if (raw is Map) {
          for (final item in raw.entries) {
            final dynamic value = item.value;

            if (value is! Map) {
              continue;
            }

            final Map app =
                Map.from(value);

            if (app["serviceId"]?.toString() ==
                serviceId) {
              final String status =
                  (app["status"] ?? "")
                      .toString();

              if (status == "pending" ||
                  status == "applied" ||
                  status == "selected" ||
                  status == "negotiating") {
                count++;
              }
            }
          }
        }
      }

      // ========================================================
      // URGENT APPLICATIONS
      // ========================================================

      final DatabaseEvent urgentEvent =
          await FirebaseDatabase.instance
              .ref(
                "services/$serviceId/applications",
              )
              .once();

      if (urgentEvent.snapshot.exists) {
        final dynamic raw =
            urgentEvent.snapshot.value;

        if (raw is Map) {
          for (final item in raw.entries) {
            final dynamic value = item.value;

            if (value is! Map) {
              continue;
            }

            final Map app =
                Map.from(value);

            final String status =
                (app["status"] ?? "")
                    .toString();

            if (status == "pending" ||
                status == "applied" ||
                status == "selected" ||
                status == "negotiating") {
              count++;
            }
          }
        }
      }

      return count;
    } catch (e) {
      debugPrint(
        "COUNT ERROR $e",
      );

      return 0;
    }
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,

      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildTopHeader(),

            Expanded(
              child: loading
                  ? _buildLoadingState()
                  : requests.isEmpty
                      ? _emptyState()
                      : RefreshIndicator(
                          color: primaryBlue,
                          backgroundColor: Colors.white,
                          strokeWidth: 2.5,
                          onRefresh: fetchRequests,
                          child: ListView.builder(
                            physics:
                                const BouncingScrollPhysics(
                              parent:
                                  AlwaysScrollableScrollPhysics(),
                            ),
                            padding:
                                const EdgeInsets.fromLTRB(
                              18,
                              18,
                              18,
                              35,
                            ),
                            itemCount:
                                requests.length,
                            itemBuilder:
                                (context, index) {
                              return _requestCard(
                                requests[index],
                                index,
                              );
                            },
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // PREMIUM TOP HEADER
  // ============================================================

  Widget _buildTopHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
        20,
        18,
        20,
        24,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xff1D4ED8),
            Color(0xff2563EB),
            Color(0xff38BDF8),
          ],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x332563EB),
            blurRadius: 22,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // BACK BUTTON
              _glassButton(
                icon: Icons.arrow_back_ios_new_rounded,
                onTap: () {
                  Navigator.pop(context);
                },
              ),

              const SizedBox(width: 14),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "My Requests",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 25,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Manage your service requests",
                      style: TextStyle(
                        color: Colors.white
                            .withOpacity(.82),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),

              // REFRESH
              _glassButton(
                icon: Icons.refresh_rounded,
                onTap: fetchRequests,
              ),
            ],
          ),

          const SizedBox(height: 20),

          // HEADER STATS
          Row(
            children: [
              Expanded(
                child: _headerStat(
                  icon: Icons.assignment_rounded,
                  title: "Requests",
                  value: requests.length.toString(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _headerStat(
                  icon: Icons.people_alt_rounded,
                  title: "Applications",
                  value: _totalApplications()
                      .toString(),
                ),
              ),
            ],
          ),
        ],
      ),
    )
        .animate()
        .fade(
          duration: 500.ms,
        )
        .slideY(
          begin: -.08,
          end: 0,
          duration: 550.ms,
          curve: Curves.easeOutCubic,
        );
  }

  // ============================================================
  // HEADER GLASS BUTTON
  // ============================================================

  Widget _glassButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius:
            BorderRadius.circular(15),
        onTap: onTap,
        child: Container(
          width: 45,
          height: 45,
          decoration: BoxDecoration(
            color: Colors.white
                .withOpacity(.16),
            borderRadius:
                BorderRadius.circular(15),
            border: Border.all(
              color: Colors.white
                  .withOpacity(.25),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black
                    .withOpacity(.10),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Icon(
            icon,
            color: Colors.white,
            size: 20,
          ),
        ),
      ),
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
      padding:
          const EdgeInsets.symmetric(
        horizontal: 15,
        vertical: 13,
      ),
      decoration: BoxDecoration(
        color: Colors.white
            .withOpacity(.14),
        borderRadius:
            BorderRadius.circular(18),
        border: Border.all(
          color: Colors.white
              .withOpacity(.18),
        ),
      ),
      child: Row(
        children: [
          Container(
            height: 36,
            width: 36,
            decoration: BoxDecoration(
              color: Colors.white
                  .withOpacity(.16),
              borderRadius:
                  BorderRadius.circular(11),
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: 19,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.white
                        .withOpacity(.75),
                    fontSize: 11,
                    fontWeight:
                        FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight:
                        FontWeight.w800,
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
  // TOTAL APPLICATIONS
  // ============================================================

  int _totalApplications() {
    int total = 0;

    for (final request in requests) {
      final dynamic value =
          request["applicationCount"];

      if (value is int) {
        total += value;
      } else {
        total +=
            int.tryParse(
                  value.toString(),
                ) ??
                0;
      }
    }

    return total;
  }

  // ============================================================
  // LOADING
  // ============================================================

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment:
            MainAxisAlignment.center,
        children: [
          Container(
            height: 82,
            width: 82,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient:
                  const LinearGradient(
                colors: [
                  primaryBlue,
                  secondaryBlue,
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: primaryBlue
                      .withOpacity(.28),
                  blurRadius: 25,
                  spreadRadius: 4,
                ),
              ],
            ),
            child: const Padding(
              padding: EdgeInsets.all(23),
              child:
                  CircularProgressIndicator(
                strokeWidth: 3,
                valueColor:
                    AlwaysStoppedAnimation<
                        Color>(
                  Colors.white,
                ),
              ),
            ),
          )
              .animate(
                onPlay: (controller) =>
                    controller.repeat(),
              )
              .shimmer(
                duration: 1600.ms,
              ),

          const SizedBox(height: 22),

          const Text(
            "Loading your requests...",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: darkBlue,
            ),
          ),

          const SizedBox(height: 7),

          Text(
            "Please wait a moment",
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // REQUEST CARD
  // ============================================================

  Widget _requestCard(
    Map<String, dynamic> data,
    int index,
  ) {
    final String status =
        (data["status"] ?? "pending")
            .toString();

    final String urgency =
        (data["urgency"] ?? "normal")
            .toString();

    final bool isUrgent =
        urgency == "urgent";

    final double urgentFee =
        double.tryParse(
              "${data["urgentServiceFee"] ?? data["emergencyCharge"] ?? 199}",
            ) ??
            199;

    final int applicationCount =
        _parseApplicationCount(
      data["applicationCount"],
    );

    final String serviceName =
        (data["serviceName"] ??
                "Service Request")
            .toString();

    final String location =
        (data["location"] ??
                "No location")
            .toString();

    final String description =
        (data["description"] ?? "")
            .toString();

    final String serviceId =
        (data["serviceId"] ?? "")
            .toString();

    return Container(
      margin:
          const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        borderRadius:
            BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black
                .withOpacity(.055),
            blurRadius: 25,
            offset: const Offset(0, 12),
          ),
          BoxShadow(
            color: primaryBlue
                .withOpacity(.035),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius:
            BorderRadius.circular(28),
        child: Container(
          color: Colors.white,
          child: Column(
            children: [
              // ==================================================
              // TOP COLOR STRIP
              // ==================================================

              Container(
                height: 5,
                decoration:
                    BoxDecoration(
                  gradient:
                      LinearGradient(
                    colors: isUrgent
                        ? [
                            Colors.red,
                            Colors.orange,
                          ]
                        : [
                            primaryBlue,
                            secondaryBlue,
                          ],
                  ),
                ),
              ),

              Padding(
                padding:
                    const EdgeInsets.fromLTRB(
                  18,
                  18,
                  18,
                  20,
                ),
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    // ==========================================
                    // HEADER
                    // ==========================================

                    Row(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        _serviceIcon(
                          isUrgent: isUrgent,
                        ),

                        const SizedBox(width: 14),

                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Text(
                                serviceName,
                                maxLines: 2,
                                overflow:
                                    TextOverflow.ellipsis,
                                style:
                                    const TextStyle(
                                  color: darkBlue,
                                  fontSize: 18,
                                  fontWeight:
                                      FontWeight.w800,
                                  letterSpacing:
                                      -.2,
                                ),
                              ),

                              const SizedBox(
                                height: 5,
                              ),

                              Text(
                                "Service Request",
                                style:
                                    TextStyle(
                                  color: Colors
                                      .grey
                                      .shade500,
                                  fontSize: 12,
                                  fontWeight:
                                      FontWeight.w500,
                                ),
                              ),

                              const SizedBox(
                                height: 10,
                              ),

                              Wrap(
                                spacing: 7,
                                runSpacing: 7,
                                children: [
                                  _statusBadge(
                                    status,
                                  ),
                                  _urgencyBadge(
                                    urgency,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(width: 5),

                        if (status == "pending")
                          _deleteButton(
                            serviceId,
                          ),
                      ],
                    ),

                    const SizedBox(height: 18),

                    // ==========================================
                    // SERVICE ID
                    // ==========================================

                    Container(
                      width: double.infinity,
                      padding:
                          const EdgeInsets.symmetric(
                        horizontal: 13,
                        vertical: 10,
                      ),
                      decoration:
                          BoxDecoration(
                        color:
                            const Color(
                          0xffF8FAFC,
                        ),
                        borderRadius:
                            BorderRadius.circular(
                          12,
                        ),
                        border: Border.all(
                          color:
                              const Color(
                            0xffE2E8F0,
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons
                                .fingerprint_rounded,
                            size: 17,
                            color: Colors
                                .grey
                                .shade500,
                          ),
                          const SizedBox(
                            width: 8,
                          ),
                          Expanded(
                            child: Text(
                              serviceId,
                              maxLines: 1,
                              overflow:
                                  TextOverflow.ellipsis,
                              style:
                                  TextStyle(
                                color: Colors
                                    .grey
                                    .shade600,
                                fontSize: 11,
                                fontWeight:
                                    FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 18),

                    // ==========================================
                    // URGENT FEE
                    // ==========================================

                    if (isUrgent)
                      _urgentFeeCard(
                        urgentFee,
                      ),

                    if (isUrgent)
                      const SizedBox(height: 15),

                    // ==========================================
                    // QUICK APPLICATION STAT
                    // ==========================================

                    _applicationStatCard(
                      applicationCount,
                      isUrgent,
                    ),

                    const SizedBox(height: 16),

                    // ==========================================
                    // LOCATION
                    // ==========================================

                    _premiumInfoTile(
                      icon:
                          Icons.location_on_rounded,
                      title: "Location",
                      value: location,
                      iconColor:
                          const Color(
                        0xff2563EB,
                      ),
                    ),

                    const SizedBox(height: 12),

                    // ==========================================
                    // DESCRIPTION
                    // ==========================================

                    _premiumInfoTile(
                      icon:
                          Icons.description_rounded,
                      title: "Description",
                      value: description.isEmpty
                          ? "No description provided"
                          : description,
                      iconColor:
                          const Color(
                        0xff7C3AED,
                      ),
                    ),

                    const SizedBox(height: 20),

                    // ==========================================
                    // VIEW OFFERS BUTTON
                    // ==========================================

                    _viewOffersButton(
                      data: data,
                      isUrgent: isUrgent,
                      applicationCount:
                          applicationCount,
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
        .fade(
          delay: (70 * index).ms,
          duration: 500.ms,
        )
        .slideY(
          begin: .15,
          end: 0,
          delay: (70 * index).ms,
          duration: 550.ms,
          curve: Curves.easeOutCubic,
        )
        .scale(
          begin: const Offset(.97, .97),
          end: const Offset(1, 1),
          delay: (70 * index).ms,
          duration: 550.ms,
          curve: Curves.easeOutCubic,
        );
  }

  // ============================================================
  // SERVICE ICON
  // ============================================================

  Widget _serviceIcon({
    required bool isUrgent,
  }) {
    return Container(
      height: 62,
      width: 62,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isUrgent
              ? [
                  const Color(0xfffff1f2),
                  const Color(0xffffe4e6),
                ]
              : [
                  const Color(0xffeff6ff),
                  const Color(0xffdbeafe),
                ],
        ),
        borderRadius:
            BorderRadius.circular(20),
        border: Border.all(
          color: isUrgent
              ? const Color(0xffffcdd3)
              : const Color(0xffbfdbfe),
        ),
        boxShadow: [
          BoxShadow(
            color: isUrgent
                ? Colors.red
                    .withOpacity(.08)
                : primaryBlue
                    .withOpacity(.08),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Icon(
        isUrgent
            ? Icons.priority_high_rounded
            : Icons.handyman_rounded,
        color: isUrgent
            ? Colors.red
            : primaryBlue,
        size: 31,
      ),
    )
        .animate(
          onPlay: (controller) =>
              controller.repeat(
            reverse: true,
          ),
        )
        .scale(
          begin: const Offset(.96, .96),
          end: const Offset(1.03, 1.03),
          duration: 1400.ms,
          curve: Curves.easeInOut,
        );
  }

  // ============================================================
  // DELETE BUTTON
  // ============================================================

  Widget _deleteButton(
    String serviceId,
  ) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius:
            BorderRadius.circular(14),
        onTap: () {
          showDeleteDialog(serviceId);
        },
        child: Container(
          height: 40,
          width: 40,
          decoration: BoxDecoration(
            color:
                const Color(0xfffff1f2),
            borderRadius:
                BorderRadius.circular(14),
            border: Border.all(
              color:
                  const Color(0xffffcdd3),
            ),
          ),
          child: const Icon(
            Icons.delete_outline_rounded,
            color: Colors.red,
            size: 21,
          ),
        ),
      ),
    )
        .animate()
        .fadeIn(
          duration: 400.ms,
        );
  }

  // ============================================================
  // URGENT FEE
  // ============================================================

  Widget _urgentFeeCard(
    double urgentFee,
  ) {
    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.all(15),
      decoration: BoxDecoration(
        gradient:
            const LinearGradient(
          colors: [
            Color(0xfffffbeb),
            Color(0xfffff7ed),
          ],
        ),
        borderRadius:
            BorderRadius.circular(18),
        border: Border.all(
          color:
              const Color(0xfffed7aa),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.orange
                .withOpacity(.07),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            height: 43,
            width: 43,
            decoration: BoxDecoration(
              color: Colors.orange
                  .withOpacity(.12),
              borderRadius:
                  BorderRadius.circular(13),
            ),
            child: const Icon(
              Icons.bolt_rounded,
              color: Colors.orange,
              size: 24,
            ),
          ),

          const SizedBox(width: 12),

          const Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  "Urgent Service",
                  style: TextStyle(
                    fontWeight:
                        FontWeight.w800,
                    fontSize: 14,
                    color:
                        Color(0xff9A3412),
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  "Additional urgent fee",
                  style: TextStyle(
                    color:
                        Color(0xffA16207),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),

          Text(
            "₹${urgentFee.toStringAsFixed(0)}",
            style: const TextStyle(
              color:
                  Color(0xffEA580C),
              fontSize: 18,
              fontWeight:
                  FontWeight.w900,
            ),
          ),
        ],
      ),
    )
        .animate()
        .fadeIn(
          duration: 450.ms,
        )
        .slideX(
          begin: .05,
          end: 0,
          duration: 450.ms,
        );
  }

  // ============================================================
  // APPLICATION STAT CARD
  // ============================================================

  Widget _applicationStatCard(
    int applicationCount,
    bool isUrgent,
  ) {
    final bool hasApplications =
        applicationCount > 0;

    return Container(
      padding:
          const EdgeInsets.all(15),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: hasApplications
              ? [
                  const Color(0xffeff6ff),
                  const Color(0xfff0f9ff),
                ]
              : [
                  const Color(0xfff8fafc),
                  const Color(0xfff1f5f9),
                ],
        ),
        borderRadius:
            BorderRadius.circular(19),
        border: Border.all(
          color: hasApplications
              ? const Color(0xffbfdbfe)
              : const Color(0xffe2e8f0),
        ),
      ),
      child: Row(
        children: [
          Container(
            height: 45,
            width: 45,
            decoration: BoxDecoration(
              gradient: hasApplications
                  ? const LinearGradient(
                      colors: [
                        primaryBlue,
                        secondaryBlue,
                      ],
                    )
                  : null,
              color: hasApplications
                  ? null
                  : Colors.grey.shade200,
              borderRadius:
                  BorderRadius.circular(14),
              boxShadow:
                  hasApplications
                      ? [
                          BoxShadow(
                            color: primaryBlue
                                .withOpacity(.18),
                            blurRadius: 12,
                            offset:
                                const Offset(
                              0,
                              5,
                            ),
                          ),
                        ]
                      : null,
            ),
            child: Icon(
              hasApplications
                  ? Icons
                      .people_alt_rounded
                  : Icons.person_search_rounded,
              color: hasApplications
                  ? Colors.white
                  : Colors.grey.shade500,
              size: 23,
            ),
          ),

          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  hasApplications
                      ? "Workers Interested"
                      : "Waiting for Workers",
                  style: TextStyle(
                    color: darkBlue,
                    fontSize: 14,
                    fontWeight:
                        FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  hasApplications
                      ? "Workers have applied to this request"
                      : "No worker applications yet",
                  style: TextStyle(
                    color:
                        Colors.grey.shade600,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),

          Container(
            padding:
                const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 8,
            ),
            decoration: BoxDecoration(
              color: hasApplications
                  ? primaryBlue
                  : Colors.grey.shade200,
              borderRadius:
                  BorderRadius.circular(12),
            ),
            child: Text(
              "$applicationCount",
              style: TextStyle(
                color: hasApplications
                    ? Colors.white
                    : Colors.grey.shade600,
                fontSize: 18,
                fontWeight:
                    FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // PREMIUM INFO TILE
  // ============================================================

  Widget _premiumInfoTile({
    required IconData icon,
    required String title,
    required String value,
    required Color iconColor,
  }) {
    return Container(
      padding:
          const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color:
            const Color(0xffFAFBFD),
        borderRadius:
            BorderRadius.circular(17),
        border: Border.all(
          color:
              const Color(0xffE8EDF4),
        ),
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Container(
            height: 42,
            width: 42,
            decoration: BoxDecoration(
              color: iconColor
                  .withOpacity(.10),
              borderRadius:
                  BorderRadius.circular(13),
            ),
            child: Icon(
              icon,
              color: iconColor,
              size: 21,
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
                    color:
                        Colors.grey.shade500,
                    fontSize: 11,
                    fontWeight:
                        FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  maxLines: 3,
                  overflow:
                      TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: darkBlue,
                    fontSize: 13,
                    fontWeight:
                        FontWeight.w700,
                    height: 1.3,
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
  // VIEW OFFERS BUTTON
  // ============================================================

  Widget _viewOffersButton({
    required Map<String, dynamic> data,
    required bool isUrgent,
    required int applicationCount,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius:
            BorderRadius.circular(18),
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  CustomerApplicationsScreen(
                serviceId:
                    data["serviceId"]
                        .toString(),
              ),
            ),
          );

          if (!mounted) return;

          await fetchRequests();
        },
        child: Container(
          width: double.infinity,
          height: 56,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isUrgent
                  ? [
                      const Color(0xffDC2626),
                      const Color(0xffF97316),
                    ]
                  : [
                      primaryBlue,
                      const Color(0xff3B82F6),
                      secondaryBlue,
                    ],
            ),
            borderRadius:
                BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: isUrgent
                    ? Colors.red
                        .withOpacity(.22)
                    : primaryBlue
                        .withOpacity(.23),
                blurRadius: 18,
                offset:
                    const Offset(0, 9),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment:
                MainAxisAlignment.center,
            children: [
              Container(
                height: 34,
                width: 34,
                decoration: BoxDecoration(
                  color: Colors.white
                      .withOpacity(.16),
                  borderRadius:
                      BorderRadius.circular(11),
                ),
                child: const Icon(
                  Icons.people_alt_rounded,
                  color: Colors.white,
                  size: 19,
                ),
              ),

              const SizedBox(width: 11),

              Text(
                applicationCount > 0
                    ? "View $applicationCount Worker"
                        "${applicationCount == 1 ? '' : 's'}"
                        " Offer"
                    : "View Worker Offers",
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight:
                      FontWeight.w800,
                  letterSpacing: .1,
                ),
              ),

              const SizedBox(width: 9),

              const Icon(
                Icons.arrow_forward_rounded,
                color: Colors.white,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    )
        .animate()
        .fadeIn(
          duration: 500.ms,
        )
        .slideY(
          begin: .08,
          end: 0,
          duration: 500.ms,
        );
  }

  // ============================================================
  // STATUS BADGE
  // ============================================================

  Widget _statusBadge(
    String status,
  ) {
    Color color;
    IconData icon;

    switch (status) {
      case "assigned":
        color = Colors.green;
        icon = Icons.check_circle_rounded;
        break;

      case "completed":
        color = primaryBlue;
        icon = Icons.done_all_rounded;
        break;

      case "started":
        color = Colors.deepPurple;
        icon = Icons.play_circle_fill_rounded;
        break;

      case "cancelled":
        color = Colors.red;
        icon = Icons.cancel_rounded;
        break;

      case "pending":
      default:
        color = Colors.orange;
        icon = Icons.schedule_rounded;
        break;
    }

    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(.10),
        borderRadius:
            BorderRadius.circular(30),
        border: Border.all(
          color: color.withOpacity(.20),
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
            status.toUpperCase(),
            style: TextStyle(
              color: color,
              fontWeight:
                  FontWeight.w800,
              fontSize: 10,
              letterSpacing: .4,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // URGENCY BADGE
  // ============================================================

  Widget _urgencyBadge(
    String urgency,
  ) {
    final bool urgent =
        urgency == "urgent";

    final Color color =
        urgent ? Colors.red : Colors.green;

    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(.10),
        borderRadius:
            BorderRadius.circular(30),
        border: Border.all(
          color: color.withOpacity(.18),
        ),
      ),
      child: Row(
        mainAxisSize:
            MainAxisSize.min,
        children: [
          Icon(
            urgent
                ? Icons.bolt_rounded
                : Icons.verified_rounded,
            size: 14,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            urgent ? "URGENT" : "NORMAL",
            style: TextStyle(
              color: color,
              fontWeight:
                  FontWeight.w800,
              fontSize: 10,
              letterSpacing: .4,
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
      child: SingleChildScrollView(
        physics:
            const BouncingScrollPhysics(),
        padding:
            const EdgeInsets.symmetric(
          horizontal: 30,
        ),
        child: Column(
          mainAxisAlignment:
              MainAxisAlignment.center,
          children: [
            const SizedBox(height: 40),

            // 3D ICON
            Container(
              height: 135,
              width: 135,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient:
                    const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xffDBEAFE),
                    Color(0xffEFF6FF),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: primaryBlue
                        .withOpacity(.15),
                    blurRadius: 30,
                    spreadRadius: 4,
                    offset:
                        const Offset(0, 12),
                  ),
                ],
              ),
              child: Center(
                child: Container(
                  height: 92,
                  width: 92,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient:
                        const LinearGradient(
                      colors: [
                        primaryBlue,
                        secondaryBlue,
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: primaryBlue
                            .withOpacity(.25),
                        blurRadius: 20,
                        offset:
                            const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons
                        .assignment_rounded,
                    color: Colors.white,
                    size: 43,
                  ),
                ),
              ),
            )
                .animate(
                  onPlay: (controller) =>
                      controller.repeat(
                    reverse: true,
                  ),
                )
                .moveY(
                  begin: -5,
                  end: 5,
                  duration: 1800.ms,
                  curve: Curves.easeInOut,
                ),

            const SizedBox(height: 30),

            const Text(
              "No Requests Created",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: darkBlue,
                fontSize: 23,
                fontWeight:
                    FontWeight.w800,
                letterSpacing: -.4,
              ),
            )
                .animate()
                .fadeIn(
                  delay: 200.ms,
                  duration: 500.ms,
                )
                .slideY(
                  begin: .15,
                  end: 0,
                  delay: 200.ms,
                ),

            const SizedBox(height: 10),

            Text(
              "Create a service request and let\n"
              "verified workers send you offers.",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 14,
                height: 1.5,
              ),
            )
                .animate()
                .fadeIn(
                  delay: 300.ms,
                  duration: 500.ms,
                ),

            const SizedBox(height: 28),

            Container(
              padding:
                  const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 13,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius:
                    BorderRadius.circular(16),
                border: Border.all(
                  color:
                      const Color(0xffE2E8F0),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black
                        .withOpacity(.04),
                    blurRadius: 15,
                    offset:
                        const Offset(0, 7),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize:
                    MainAxisSize.min,
                children: [
                  const Icon(
                    Icons
                        .lightbulb_rounded,
                    color: Colors.orange,
                    size: 20,
                  ),
                  const SizedBox(width: 9),
                  Text(
                    "Your requests will appear here",
                    style: TextStyle(
                      color:
                          Colors.grey.shade700,
                      fontSize: 12,
                      fontWeight:
                          FontWeight.w600,
                    ),
                  ),
                ],
              ),
            )
                .animate()
                .fadeIn(
                  delay: 450.ms,
                )
                .scale(
                  begin:
                      const Offset(.92, .92),
                ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // SHOULD SHOW IN REQUESTS
  // ============================================================

  bool _shouldShowInRequests(
    Map service,
  ) {
    final String status =
        (service["status"] ?? "pending")
            .toString();

    // These statuses should NOT appear here.
    if (status == "started" ||
        status == "completed" ||
        status == "cancelled") {
      return false;
    }

    // Pending and assigned remain visible.
    return true;
  }

  // ============================================================
  // DELETE CONFIRMATION
  // ============================================================

  void showDeleteDialog(
    String serviceId,
  ) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding:
              const EdgeInsets.symmetric(
            horizontal: 25,
          ),
          child: Container(
            padding:
                const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius:
                  BorderRadius.circular(26),
              boxShadow: [
                BoxShadow(
                  color: Colors.black
                      .withOpacity(.18),
                  blurRadius: 30,
                  offset:
                      const Offset(0, 15),
                ),
              ],
            ),
            child: Column(
              mainAxisSize:
                  MainAxisSize.min,
              children: [
                Container(
                  height: 68,
                  width: 68,
                  decoration: BoxDecoration(
                    color:
                        const Color(0xfffff1f2),
                    borderRadius:
                        BorderRadius.circular(
                      20,
                    ),
                  ),
                  child: const Icon(
                    Icons
                        .delete_forever_rounded,
                    color: Colors.red,
                    size: 34,
                  ),
                ),

                const SizedBox(height: 18),

                const Text(
                  "Delete Request?",
                  style: TextStyle(
                    color: darkBlue,
                    fontSize: 20,
                    fontWeight:
                        FontWeight.w800,
                  ),
                ),

                const SizedBox(height: 8),

                Text(
                  "Are you sure you want to delete "
                  "this service request?",
                  textAlign:
                      TextAlign.center,
                  style: TextStyle(
                    color:
                        Colors.grey.shade600,
                    fontSize: 13,
                    height: 1.45,
                  ),
                ),

                const SizedBox(height: 23),

                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 48,
                        child: OutlinedButton(
                          style:
                              OutlinedButton.styleFrom(
                            foregroundColor:
                                darkBlue,
                            side: BorderSide(
                              color: Colors
                                  .grey
                                  .shade300,
                            ),
                            shape:
                                RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius
                                      .circular(
                                14,
                              ),
                            ),
                          ),
                          onPressed: () {
                            Navigator.pop(
                              context,
                            );
                          },
                          child:
                              const Text(
                            "Cancel",
                            style:
                                TextStyle(
                              fontWeight:
                                  FontWeight
                                      .w700,
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(width: 12),

                    Expanded(
                      child: SizedBox(
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
                                  BorderRadius
                                      .circular(
                                14,
                              ),
                            ),
                          ),
                          onPressed: () {
                            Navigator.pop(
                              context,
                            );

                            deleteService(
                              serviceId,
                            );
                          },
                          child:
                              const Text(
                            "Delete",
                            style:
                                TextStyle(
                              fontWeight:
                                  FontWeight
                                      .w800,
                            ),
                          ),
                        ),
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
  // SAFE APPLICATION COUNT
  // ============================================================

  int _parseApplicationCount(
    dynamic value,
  ) {
    if (value is int) {
      return value;
    }

    return int.tryParse(
          value?.toString() ?? "0",
        ) ??
        0;
  }
}
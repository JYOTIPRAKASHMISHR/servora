import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';

import 'package:servora/models/service_model.dart';
import 'package:servora/screens/workers/job_details_screen.dart';

class AvailableJobsScreen extends StatefulWidget {
  const AvailableJobsScreen({
    super.key,
  });

  @override
  State<AvailableJobsScreen> createState() =>
      _AvailableJobsScreenState();
}

class _AvailableJobsScreenState
    extends State<AvailableJobsScreen> {
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
  // COLORS
  // ============================================================

  static const Color primaryBlue =
      Color(0xff2563EB);

  static const Color darkBlue =
      Color(0xff1D4ED8);

  static const Color lightBlue =
      Color(0xffEFF6FF);

  static const Color background =
      Color(0xffF4F7FC);

  // ============================================================
  // VARIABLES
  // ============================================================

  bool loading = true;

  List<ServiceModel> jobs = [];

  Set<String> appliedServiceIds = {};

  double? workerLatitude;
  double? workerLongitude;

  // ============================================================
  // INITIALIZATION
  // ============================================================

  @override
  void initState() {
    super.initState();

    initialize();
  }

  Future<void> initialize() async {
    await checkWorkerApplications();
    await getWorkerLocation();
    await fetchJobs();
  }

  // ============================================================
  // CHECK ALREADY APPLIED JOBS
  // ============================================================

  Future<void> checkWorkerApplications() async {
    try {
      final User? user =
          FirebaseAuth.instance.currentUser;

      if (user == null) {
        return;
      }

      final DatabaseEvent event =
          await applicationsRef.once();

      if (!event.snapshot.exists) {
        if (mounted) {
          setState(() {
            appliedServiceIds = {};
          });
        }

        return;
      }

      final dynamic rawData =
          event.snapshot.value;

      if (rawData is! Map) {
        return;
      }

      final Map data =
          Map.from(rawData);

      final Set<String> temp = {};

      data.forEach((key, value) {
        if (value is! Map) {
          return;
        }

        final Map app =
            Map.from(value);

        if (app["workerId"] ==
            user.uid) {
          if (app["serviceId"] != null) {
            temp.add(
              app["serviceId"].toString(),
            );
          }
        }
      });

      if (!mounted) {
        return;
      }

      setState(() {
        appliedServiceIds = temp;
      });
    } catch (e) {
      debugPrint(
        "Application Check Error: $e",
      );
    }
  }

  // ============================================================
  // GET WORKER LOCATION
  // ============================================================

  Future<void> getWorkerLocation() async {
    try {
      final User? user =
          FirebaseAuth.instance.currentUser;

      if (user == null) {
        return;
      }

      final DatabaseEvent event =
          await workersRef
              .child(user.uid)
              .once();

      if (!event.snapshot.exists) {
        return;
      }

      final dynamic rawData =
          event.snapshot.value;

      if (rawData is! Map) {
        return;
      }

      final Map data =
          Map.from(rawData);

      workerLatitude =
          double.tryParse(
        data["latitude"]?.toString() ?? "",
      );

      workerLongitude =
          double.tryParse(
        data["longitude"]?.toString() ?? "",
      );

      if (!mounted) {
        return;
      }

      setState(() {});
    } catch (e) {
      debugPrint(
        "Location Error: $e",
      );
    }
  }

  // ============================================================
  // CALCULATE DISTANCE
  // ============================================================

  double? calculateDistance(
    ServiceModel job,
  ) {
    if (workerLatitude == null ||
        workerLongitude == null) {
      return null;
    }

    if (job.latitude == 0 ||
        job.longitude == 0) {
      return null;
    }

    final double meters =
        Geolocator.distanceBetween(
      workerLatitude!,
      workerLongitude!,
      job.latitude,
      job.longitude,
    );

    return meters / 1000;
  }

  // ============================================================
  // FETCH AVAILABLE SERVICES
  // ============================================================

  Future<void> fetchJobs() async {
    try {
      if (mounted) {
        setState(() {
          loading = true;
          jobs = [];
        });
      }

      debugPrint(
        "======================================",
      );

      debugPrint(
        "🔥 FETCHING AVAILABLE JOBS",
      );

      final User? currentUser =
          FirebaseAuth.instance.currentUser;

      debugPrint(
        "CURRENT USER: ${currentUser?.uid}",
      );

      debugPrint(
        "======================================",
      );

      final DatabaseEvent event =
          await servicesRef.once();

      final List<ServiceModel> temp = [];

      if (!event.snapshot.exists) {
        debugPrint(
          "❌ SERVICES NODE DOES NOT EXIST",
        );

        if (!mounted) {
          return;
        }

        setState(() {
          jobs = [];
          loading = false;
        });

        return;
      }

      final dynamic rawData =
          event.snapshot.value;

      if (rawData is! Map) {
        debugPrint(
          "❌ SERVICES DATA IS NOT A MAP",
        );

        if (!mounted) {
          return;
        }

        setState(() {
          jobs = [];
          loading = false;
        });

        return;
      }

      if (currentUser == null) {
        debugPrint(
          "❌ NO LOGGED-IN USER",
        );

        if (!mounted) {
          return;
        }

        setState(() {
          jobs = [];
          loading = false;
        });

        return;
      }

      final String currentUid =
          currentUser.uid;

      final Map<String, dynamic> services =
          Map<String, dynamic>.from(
        rawData,
      );

      debugPrint(
        "🔥 TOTAL SERVICES: ${services.length}",
      );

      services.forEach(
        (key, value) {
          if (value is! Map) {
            debugPrint(
              "❌ INVALID SERVICE DATA: $key",
            );

            return;
          }

          final Map<String, dynamic> service =
              Map<String, dynamic>.from(
            value,
          );

          final String serviceId =
              key.toString();

          final String customerId =
              service["customerId"]
                      ?.toString() ??
                  "";

          final String serviceName =
              service["serviceName"]
                      ?.toString() ??
                  "";

          final String status =
              service["status"]
                      ?.toString()
                      .trim()
                      .toLowerCase() ??
                  "pending";

          final String urgency =
              service["urgency"]
                      ?.toString()
                      .trim()
                      .toLowerCase() ??
                  "normal";

          debugPrint(
            "--------------------------------------",
          );

          debugPrint(
            "SERVICE ID: $serviceId",
          );

          debugPrint(
            "SERVICE NAME: $serviceName",
          );

          debugPrint(
            "CUSTOMER ID: $customerId",
          );

          debugPrint(
            "CURRENT USER: $currentUid",
          );

          debugPrint(
            "STATUS: $status",
          );

          debugPrint(
            "URGENCY: $urgency",
          );

          // ----------------------------------------------------
          // DON'T SHOW OWN SERVICE
          // ----------------------------------------------------

          if (customerId == currentUid) {
            debugPrint(
              "❌ SKIPPED: OWN SERVICE",
            );

            return;
          }

          // ----------------------------------------------------
          // SHOW ONLY PENDING SERVICES
          // ----------------------------------------------------

          if (status != "pending") {
            debugPrint(
              "❌ SKIPPED: STATUS = $status",
            );

            return;
          }

          // ----------------------------------------------------
          // CONVERT TO MODEL
          // ----------------------------------------------------
// ----------------------------------------------------
// CONVERT TO MODEL
// ----------------------------------------------------

try {
  final ServiceModel model =
      ServiceModel.fromMap(
    service,
    serviceId,
  );

  // --------------------------------------------------
  // 10 KM RADIUS CHECK
  // --------------------------------------------------

  final double? distance =
      calculateDistance(model);

  if (distance == null) {
    debugPrint(
      "❌ SKIPPED: LOCATION UNAVAILABLE - ${model.serviceName}",
    );
    return;
  }

  debugPrint(
    "📍 DISTANCE: ${model.serviceName} = "
    "${distance.toStringAsFixed(2)} KM",
  );

  if (distance > 10) {
    debugPrint(
      "❌ SKIPPED: MORE THAN 10 KM - "
      "${model.serviceName} (${distance.toStringAsFixed(2)} KM)",
    );
    return;
  }

  temp.add(model);

  debugPrint(
    "✅ JOB ADDED WITHIN 10 KM: "
    "${model.serviceName} (${distance.toStringAsFixed(2)} KM)",
  );
} catch (e, stackTrace) {
  debugPrint(
    "❌ MODEL CONVERSION ERROR",
  );

  debugPrint(
    "SERVICE: $service",
  );

  debugPrint(
    "ERROR: $e",
  );

  debugPrint(
    stackTrace.toString(),
  );
}
        },
      );

      // Newest jobs first
      temp.sort(
        (a, b) =>
            b.serviceId.compareTo(
          a.serviceId,
        ),
      );

      debugPrint(
        "======================================",
      );

      debugPrint(
        "🔥 FINAL JOB COUNT: ${temp.length}",
      );

      debugPrint(
        "======================================");

      if (!mounted) {
        return;
      }

      setState(() {
        jobs = temp;
        loading = false;
      });
    } catch (e, stackTrace) {
      debugPrint(
        "❌ FETCH JOBS ERROR: $e",
      );

      debugPrint(
        stackTrace.toString(),
      );

      if (!mounted) {
        return;
      }

      setState(() {
        jobs = [];
        loading = false;
      });

      showError(
        "Unable to load available jobs.",
      );
    }
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      backgroundColor: background,

      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildPremiumHeader(),

            Expanded(
              child: loading
                  ? _buildLoadingState()
                  : jobs.isEmpty
                      ? _emptyJobs()
                      : RefreshIndicator(
                          color: primaryBlue,
                          backgroundColor:
                              Colors.white,
                          onRefresh: fetchJobs,
                          child: ListView.builder(
                            physics:
                                const BouncingScrollPhysics(
                              parent:
                                  AlwaysScrollableScrollPhysics(),
                            ),
                            padding:
                                const EdgeInsets.fromLTRB(
                              16,
                              12,
                              16,
                              35,
                            ),
                            itemCount: jobs.length,
                            itemBuilder:
                                (context, index) {
                              return _jobCard(
                                jobs[index],
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
  // PREMIUM HEADER
  // ============================================================

  Widget _buildPremiumHeader() {
    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.fromLTRB(
        20,
        18,
        20,
        28,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xff2563EB),
            Color(0xff1D4ED8),
            Color(0xff0F3FAE),
          ],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft:
              Radius.circular(32),
          bottomRight:
              Radius.circular(32),
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _buildHeaderIcon(),

              const SizedBox(width: 14),

              const Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Available Jobs",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 25,
                        fontWeight:
                            FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      "Find your next service opportunity",
                      style: TextStyle(
                        color:
                            Colors.white70,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),

              _buildRefreshButton(),
            ],
          ),

          const SizedBox(height: 22),

          Row(
            children: [
              Expanded(
                child: _buildHeaderStat(
                  icon:
                      Icons.work_outline_rounded,
                  value:
                      "${jobs.length}",
                  label: "Available",
                ),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: _buildHeaderStat(
                  icon:
                      Icons.near_me_rounded,
                  value:
                      workerLatitude == null
                          ? "--"
                          : "GPS",
                  label: "Location",
                ),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: _buildHeaderStat(
                  icon:
                      Icons.verified_rounded,
                  value:
                      "${appliedServiceIds.length}",
                  label: "Applied",
                ),
              ),
            ],
          ),
        ],
      ),
    )
        .animate()
        .fadeIn(
          duration: 500.ms,
        )
        .slideY(
          begin: -0.08,
          end: 0,
          duration: 600.ms,
          curve: Curves.easeOutCubic,
        );
  }

  // ============================================================
  // HEADER ICON
  // ============================================================

  Widget _buildHeaderIcon() {
    return Container(
      height: 54,
      width: 54,
      decoration: BoxDecoration(
        color:
            Colors.white.withOpacity(0.16),
        borderRadius:
            BorderRadius.circular(18),
        border: Border.all(
          color:
              Colors.white.withOpacity(0.22),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black
                .withOpacity(0.16),
            blurRadius: 14,
            offset:
                const Offset(0, 7),
          ),
        ],
      ),
      child: const Icon(
        Icons.work_history_rounded,
        color: Colors.white,
        size: 29,
      ),
    );
  }

  // ============================================================
  // REFRESH BUTTON
  // ============================================================

  Widget _buildRefreshButton() {
    return Material(
      color:
          Colors.white.withOpacity(0.15),
      borderRadius:
          BorderRadius.circular(16),
      child: InkWell(
        borderRadius:
            BorderRadius.circular(16),
        onTap: fetchJobs,
        child: Container(
          height: 48,
          width: 48,
          decoration: BoxDecoration(
            borderRadius:
                BorderRadius.circular(16),
            border: Border.all(
              color:
                  Colors.white.withOpacity(
                0.22,
              ),
            ),
          ),
          child: const Icon(
            Icons.refresh_rounded,
            color: Colors.white,
            size: 24,
          ),
        ),
      ),
    );
  }

  // ============================================================
  // HEADER STAT
  // ============================================================

  Widget _buildHeaderStat({
    required IconData icon,
    required String value,
    required String label,
  }) {
    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 12,
      ),
      decoration: BoxDecoration(
        color:
            Colors.white.withOpacity(0.12),
        borderRadius:
            BorderRadius.circular(17),
        border: Border.all(
          color:
              Colors.white.withOpacity(0.14),
        ),
      ),
      child: Row(
        children: [
          Container(
            height: 34,
            width: 34,
            decoration: BoxDecoration(
              color: Colors.white
                  .withOpacity(0.13),
              borderRadius:
                  BorderRadius.circular(11),
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: 18,
            ),
          ),

          const SizedBox(width: 8),

          Expanded(
            child: Column(
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
                    fontWeight:
                        FontWeight.w800,
                  ),
                ),
                Text(
                  label,
                  maxLines: 1,
                  overflow:
                      TextOverflow.ellipsis,
                  style: const TextStyle(
                    color:
                        Colors.white70,
                    fontSize: 10,
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
  // JOB CARD
  // ============================================================

  Widget _jobCard(
    ServiceModel job,
    int index,
  ) {
    final double? distance =
        calculateDistance(job);

    final bool alreadyApplied =
        appliedServiceIds.contains(
      job.serviceId,
    );

    final String urgency =
        _getUrgency(job);

    final bool isUrgent =
        urgency == "urgent"||
    urgency == "emergency";

    return Container(
      margin:
          const EdgeInsets.only(
        bottom: 18,
      ),
      decoration: BoxDecoration(
        borderRadius:
            BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color:
                Colors.black.withOpacity(
              0.055,
            ),
            blurRadius: 24,
            spreadRadius: 1,
            offset:
                const Offset(0, 12),
          ),
          BoxShadow(
            color:
                primaryBlue.withOpacity(
              0.035,
            ),
            blurRadius: 8,
            offset:
                const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(28),
        clipBehavior:
            Clip.antiAlias,
        child: InkWell(
          onTap: alreadyApplied
              ? null
              : () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder:
                          (context) =>
                              JobDetailsScreen(
                        job: job,
                      ),
                    ),
                  );
                },
          child: Padding(
            padding:
                const EdgeInsets.all(17),
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                _buildJobTopSection(
                  job,
                  isUrgent,
                  alreadyApplied,
                ),

                const SizedBox(height: 17),

                _buildDescription(job),

                const SizedBox(height: 17),

                _buildInfoPanel(
                  job,
                  distance,
                ),

                const SizedBox(height: 17),

                _buildBottomSection(
                  job,
                  alreadyApplied,
                ),
              ],
            ),
          ),
        ),
      ),
    )
        .animate()
        .fadeIn(
          duration: 450.ms,
          delay:
              (index * 80).ms,
        )
        .slideY(
          begin: 0.10,
          end: 0,
          duration: 500.ms,
          delay:
              (index * 80).ms,
          curve:
              Curves.easeOutCubic,
        )
        .scale(
          begin:
              const Offset(0.97, 0.97),
          end:
              const Offset(1, 1),
          duration: 500.ms,
          delay:
              (index * 80).ms,
        );
  }

  // ============================================================
  // JOB TOP SECTION
  // ============================================================

  Widget _buildJobTopSection(
    ServiceModel job,
    bool isUrgent,
    bool alreadyApplied,
  ) {
    return Row(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        _buildServiceIcon(
          job,
          isUrgent,
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
                      job.serviceName.isEmpty
                          ? "Service Request"
                          : job.serviceName,
                      maxLines: 2,
                      overflow:
                          TextOverflow.ellipsis,
                      style:
                          const TextStyle(
                        fontSize: 18,
                        fontWeight:
                            FontWeight.w800,
                        color:
                            Color(0xff111827),
                        letterSpacing:
                            -0.3,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 5),

              Row(
                children: [
                  Container(
                    height: 6,
                    width: 6,
                    decoration:
                        const BoxDecoration(
                      color: Color(
                          0xff22C55E),
                      shape:
                          BoxShape.circle,
                    ),
                  ),

                  const SizedBox(width: 6),

                  const Text(
                    "Customer Request",
                    style: TextStyle(
                      color:
                          Color(0xff64748B),
                      fontSize: 12,
                      fontWeight:
                          FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(width: 8),

        _statusBadge(
          alreadyApplied,
          isUrgent,
        ),
      ],
    );
  }

  // ============================================================
  // SERVICE ICON
  // ============================================================

  Widget _buildServiceIcon(
    ServiceModel job,
    bool isUrgent,
  ) {
    return Container(
      height: 62,
      width: 62,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isUrgent
              ? const [
                  Color(0xffF97316),
                  Color(0xffDC2626),
                ]
              : const [
                  Color(0xff3B82F6),
                  Color(0xff1D4ED8),
                ],
        ),
        borderRadius:
            BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: isUrgent
                ? Colors.red
                    .withOpacity(0.20)
                : primaryBlue
                    .withOpacity(0.22),
            blurRadius: 14,
            offset:
                const Offset(0, 7),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            top: -8,
            right: -8,
            child: Container(
              height: 30,
              width: 30,
              decoration:
                  BoxDecoration(
                color: Colors.white
                    .withOpacity(0.12),
                shape:
                    BoxShape.circle,
              ),
            ),
          ),

          Center(
            child: Icon(
              _serviceIcon(
                job.serviceName,
              ),
              color: Colors.white,
              size: 30,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // SERVICE ICON SELECTOR
  // ============================================================

  IconData _serviceIcon(
    String serviceName,
  ) {
    final String name =
        serviceName.toLowerCase();

    if (name.contains("clean")) {
      return Icons.cleaning_services_rounded;
    }

    if (name.contains("electric")) {
      return Icons.electrical_services_rounded;
    }

    if (name.contains("plumb")) {
      return Icons.plumbing_rounded;
    }

    if (name.contains("garden")) {
      return Icons.yard_rounded;
    }

    if (name.contains("paint")) {
      return Icons.format_paint_rounded;
    }

    if (name.contains("car")) {
      return Icons.directions_car_rounded;
    }

    if (name.contains("bike")) {
      return Icons.two_wheeler_rounded;
    }

    if (name.contains("repair")) {
      return Icons.build_circle_rounded;
    }

    if (name.contains("appliance")) {
      return Icons.home_repair_service_rounded;
    }

    if (name.contains("tutor")) {
      return Icons.school_rounded;
    }

    if (name.contains("baby")) {
      return Icons.child_care_rounded;
    }

    if (name.contains("elder")) {
      return Icons.elderly_rounded;
    }

    if (name.contains("moving")) {
      return Icons.local_shipping_rounded;
    }

    return Icons.handyman_rounded;
  }

  // ============================================================
  // DESCRIPTION
  // ============================================================

  Widget _buildDescription(
    ServiceModel job,
  ) {
    final String description =
        job.description.isEmpty
            ? "No additional description provided."
            : job.description;

    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color:
            const Color(0xffF8FAFC),
        borderRadius:
            BorderRadius.circular(17),
        border: Border.all(
          color:
              const Color(0xffE8EEF7),
        ),
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Container(
            height: 34,
            width: 34,
            decoration: BoxDecoration(
              color:
                  const Color(0xffE0ECFF),
              borderRadius:
                  BorderRadius.circular(11),
            ),
            child: const Icon(
              Icons.notes_rounded,
              color: primaryBlue,
              size: 18,
            ),
          ),

          const SizedBox(width: 11),

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                const Text(
                  "REQUEST DETAILS",
                  style: TextStyle(
                    color:
                        Color(0xff64748B),
                    fontSize: 9,
                    fontWeight:
                        FontWeight.w800,
                    letterSpacing: 0.8,
                  ),
                ),

                const SizedBox(height: 4),

                Text(
                  description,
                  maxLines: 3,
                  overflow:
                      TextOverflow.ellipsis,
                  style:
                      const TextStyle(
                    color:
                        Color(0xff334155),
                    fontSize: 13,
                    height: 1.45,
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
  // INFORMATION PANEL
  // ============================================================

  Widget _buildInfoPanel(
    ServiceModel job,
    double? distance,
  ) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _modernInfoTile(
                icon:
                    Icons.location_on_rounded,
                title: "Location",
                value: job.location.isEmpty
                    ? "Not available"
                    : job.location,
              ),
            ),

            const SizedBox(width: 10),

            Expanded(
              child: _modernInfoTile(
                icon:
                    Icons.near_me_rounded,
                title: "Distance",
                value: distance == null
                    ? "Unavailable"
                    : "${distance.toStringAsFixed(1)} km",
              ),
            ),
          ],
        ),

        const SizedBox(height: 10),

        Row(
          children: [
            Expanded(
              child: _modernInfoTile(
                icon:
                    Icons.currency_rupee_rounded,
                title: "Budget",
                value:
                    "₹${job.budget.isEmpty ? "0" : job.budget}",
                highlighted: true,
              ),
            ),

            const SizedBox(width: 10),

            Expanded(
              child: _modernInfoTile(
                icon:
                    Icons.calendar_today_rounded,
                title: "Service Date",
                value:
                    job.date.isEmpty
                        ? "Not set"
                        : job.date,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ============================================================
  // MODERN INFO TILE
  // ============================================================

  Widget _modernInfoTile({
    required IconData icon,
    required String title,
    required String value,
    bool highlighted = false,
  }) {
    return Container(
      constraints:
          const BoxConstraints(
        minHeight: 72,
      ),
      padding:
          const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: highlighted
            ? const Color(0xffEFF6FF)
            : const Color(0xffF8FAFC),
        borderRadius:
            BorderRadius.circular(17),
        border: Border.all(
          color: highlighted
              ? const Color(0xffD7E7FF)
              : const Color(0xffE8EEF7),
        ),
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Container(
            height: 34,
            width: 34,
            decoration: BoxDecoration(
              gradient: highlighted
                  ? const LinearGradient(
                      colors: [
                        Color(0xff3B82F6),
                        Color(0xff2563EB),
                      ],
                    )
                  : null,
              color: highlighted
                  ? null
                  : const Color(0xffEAF2FF),
              borderRadius:
                  BorderRadius.circular(11),
            ),
            child: Icon(
              icon,
              size: 17,
              color: highlighted
                  ? Colors.white
                  : primaryBlue,
            ),
          ),

          const SizedBox(width: 8),

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow:
                      TextOverflow.ellipsis,
                  style: const TextStyle(
                    color:
                        Color(0xff94A3B8),
                    fontSize: 9,
                    fontWeight:
                        FontWeight.w700,
                    letterSpacing: 0.4,
                  ),
                ),

                const SizedBox(height: 4),

                Text(
                  value,
                  maxLines: 2,
                  overflow:
                      TextOverflow.ellipsis,
                  style: TextStyle(
                    color: highlighted
                        ? const Color(
                            0xff1D4ED8)
                        : const Color(
                            0xff334155),
                    fontSize:
                        highlighted
                            ? 15
                            : 12,
                    fontWeight:
                        highlighted
                            ? FontWeight.w800
                            : FontWeight.w600,
                    height: 1.2,
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
  // BOTTOM SECTION
  // ============================================================

  Widget _buildBottomSection(
    ServiceModel job,
    bool alreadyApplied,
  ) {
    return Row(
      children: [
        Expanded(
          child: _buildTrustIndicator(),
        ),

        const SizedBox(width: 10),

        SizedBox(
          height: 48,
          child: ElevatedButton(
            onPressed: alreadyApplied
                ? null
                : () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder:
                            (context) =>
                                JobDetailsScreen(
                          job: job,
                        ),
                      ),
                    );
                  },
            style:
                ElevatedButton.styleFrom(
              elevation:
                  alreadyApplied ? 0 : 5,
              shadowColor:
                  primaryBlue.withOpacity(
                0.30,
              ),
              backgroundColor:
                  alreadyApplied
                      ? const Color(
                          0xffCBD5E1)
                      : primaryBlue,
              foregroundColor:
                  Colors.white,
              padding:
                  const EdgeInsets.symmetric(
                horizontal: 17,
              ),
              shape:
                  RoundedRectangleBorder(
                borderRadius:
                    BorderRadius.circular(
                  15,
                ),
              ),
            ),
            child: Row(
              mainAxisSize:
                  MainAxisSize.min,
              children: [
                Text(
                  alreadyApplied
                      ? "Applied"
                      : "View Details",
                  style:
                      const TextStyle(
                    fontSize: 12,
                    fontWeight:
                        FontWeight.w800,
                  ),
                ),

                const SizedBox(width: 6),

                Icon(
                  alreadyApplied
                      ? Icons.check_rounded
                      : Icons.arrow_forward_rounded,
                  size: 17,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // TRUST INDICATOR
  // ============================================================

  Widget _buildTrustIndicator() {
    return Row(
      children: [
        Container(
          height: 32,
          width: 32,
          decoration: BoxDecoration(
            color:
                const Color(0xffECFDF5),
            borderRadius:
                BorderRadius.circular(10),
          ),
          child: const Icon(
            Icons.verified_rounded,
            color:
                Color(0xff16A34A),
            size: 17,
          ),
        ),

        const SizedBox(width: 8),

        const Expanded(
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Text(
                "Open request",
                style: TextStyle(
                  color:
                      Color(0xff334155),
                  fontSize: 10,
                  fontWeight:
                      FontWeight.w700,
                ),
              ),
              Text(
                "Ready for applications",
                maxLines: 1,
                overflow:
                    TextOverflow.ellipsis,
                style: TextStyle(
                  color:
                      Color(0xff94A3B8),
                  fontSize: 9,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ============================================================
  // STATUS BADGE
  // ============================================================

  Widget _statusBadge(
    bool applied,
    bool urgent,
  ) {
    if (urgent && !applied) {
      return Container(
        padding:
            const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 7,
        ),
        decoration: BoxDecoration(
          gradient:
              const LinearGradient(
            colors: [
              Color(0xffF97316),
              Color(0xffDC2626),
            ],
          ),
          borderRadius:
              BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color:
                  Colors.red.withOpacity(
                0.18,
              ),
              blurRadius: 8,
              offset:
                  const Offset(0, 3),
            ),
          ],
        ),
        child: const Row(
          mainAxisSize:
              MainAxisSize.min,
          children: [
            Icon(
              Icons.priority_high_rounded,
              color: Colors.white,
              size: 13,
            ),
            SizedBox(width: 3),
            Text(
              "URGENT",
              style: TextStyle(
                color: Colors.white,
                fontSize: 9,
                fontWeight:
                    FontWeight.w900,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 7,
      ),
      decoration: BoxDecoration(
        color: applied
            ? const Color(0xffFFF7ED)
            : const Color(0xffECFDF5),
        borderRadius:
            BorderRadius.circular(30),
        border: Border.all(
          color: applied
              ? const Color(0xffFED7AA)
              : const Color(0xffBBF7D0),
        ),
      ),
      child: Row(
        mainAxisSize:
            MainAxisSize.min,
        children: [
          Icon(
            applied
                ? Icons.schedule_rounded
                : Icons.check_circle_rounded,
            size: 12,
            color: applied
                ? const Color(0xffEA580C)
                : const Color(0xff16A34A),
          ),

          const SizedBox(width: 4),

          Text(
            applied
                ? "APPLIED"
                : "AVAILABLE",
            style: TextStyle(
              color: applied
                  ? const Color(0xffC2410C)
                  : const Color(0xff15803D),
              fontSize: 9,
              fontWeight:
                  FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // GET URGENCY
  // ============================================================

  String _getUrgency(
    ServiceModel job,
  ) {
    try {
      final dynamic value =
          (job as dynamic).urgency;

      return value
              ?.toString()
              .trim()
              .toLowerCase() ??
          "normal";
    } catch (_) {
      return "normal";
    }
  }

  // ============================================================
  // LOADING STATE
  // ============================================================

  Widget _buildLoadingState() {
    return ListView(
      physics:
          const NeverScrollableScrollPhysics(),
      padding:
          const EdgeInsets.fromLTRB(
        16,
        18,
        16,
        20,
      ),
      children: [
        _skeletonCard(),
        _skeletonCard(),
        _skeletonCard(),
      ],
    );
  }

  Widget _skeletonCard() {
    return Container(
      height: 275,
      margin:
          const EdgeInsets.only(
        bottom: 18,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color:
                Colors.black.withOpacity(
              0.045,
            ),
            blurRadius: 18,
            offset:
                const Offset(0, 8),
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
            Row(
              children: [
                _skeletonBox(
                  width: 62,
                  height: 62,
                  radius: 20,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    children: [
                      _skeletonBox(
                        width: double.infinity,
                        height: 16,
                        radius: 8,
                      ),
                      const SizedBox(height: 9),
                      _skeletonBox(
                        width: 120,
                        height: 10,
                        radius: 6,
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            _skeletonBox(
              width: double.infinity,
              height: 65,
              radius: 16,
            ),

            const SizedBox(height: 14),

            Row(
              children: [
                Expanded(
                  child: _skeletonBox(
                    width: double.infinity,
                    height: 60,
                    radius: 16,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _skeletonBox(
                    width: double.infinity,
                    height: 60,
                    radius: 16,
                  ),
                ),
              ],
            ),
          ],
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
  }

  Widget _skeletonBox({
    required double width,
    required double height,
    required double radius,
  }) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color:
            const Color(0xffE9EEF6),
        borderRadius:
            BorderRadius.circular(
          radius,
        ),
      ),
    );
  }

  // ============================================================
  // EMPTY JOB STATE
  // ============================================================

  Widget _emptyJobs() {
    return RefreshIndicator(
      color: primaryBlue,
      onRefresh: fetchJobs,
      child: ListView(
        physics:
            const AlwaysScrollableScrollPhysics(
          parent:
              BouncingScrollPhysics(),
        ),
        children: [
          SizedBox(
            height:
                MediaQuery.of(context)
                        .size
                        .height *
                    0.55,
            child: Center(
              child: Padding(
                padding:
                    const EdgeInsets.all(
                  30,
                ),
                child: Column(
                  mainAxisAlignment:
                      MainAxisAlignment.center,
                  children: [
                    _buildEmptyIllustration(),

                    const SizedBox(
                        height: 25),

                    const Text(
                      "No Jobs Available",
                      style: TextStyle(
                        fontSize: 23,
                        fontWeight:
                            FontWeight.w800,
                        color:
                            Color(0xff111827),
                      ),
                    ),

                    const SizedBox(
                        height: 10),

                    Text(
                      "There are no new customer requests\n"
                      "available for you right now.",
                      textAlign:
                          TextAlign.center,
                      style: TextStyle(
                        color:
                            Colors.grey.shade600,
                        fontSize: 14,
                        height: 1.5,
                      ),
                    ),

                    const SizedBox(
                        height: 25),

                    ElevatedButton.icon(
                      onPressed:
                          fetchJobs,
                      icon:
                          const Icon(
                        Icons.refresh_rounded,
                        color:
                            Colors.white,
                      ),
                      label:
                          const Text(
                        "Refresh Jobs",
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
                        elevation: 5,
                        shadowColor:
                            primaryBlue
                                .withOpacity(
                          0.3,
                        ),
                        padding:
                            const EdgeInsets
                                .symmetric(
                          horizontal: 24,
                          vertical: 14,
                        ),
                        shape:
                            RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius
                                  .circular(
                            15,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // EMPTY ILLUSTRATION
  // ============================================================

  Widget _buildEmptyIllustration() {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          height: 145,
          width: 145,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color:
                const Color(0xffE8F1FF),
            boxShadow: [
              BoxShadow(
                color:
                    primaryBlue.withOpacity(
                  0.12,
                ),
                blurRadius: 30,
                spreadRadius: 5,
              ),
            ],
          ),
        ),

        Container(
          height: 108,
          width: 108,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
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
            boxShadow: [
              BoxShadow(
                color:
                    primaryBlue.withOpacity(
                  0.28,
                ),
                blurRadius: 20,
                offset:
                    const Offset(0, 10),
              ),
            ],
          ),
          child: const Icon(
            Icons.work_off_rounded,
            color: Colors.white,
            size: 50,
          ),
        ),
      ],
    )
        .animate(
          onPlay: (controller) =>
              controller.repeat(
            reverse: true,
          ),
        )
        .scale(
          begin:
              const Offset(0.96, 0.96),
          end:
              const Offset(1.04, 1.04),
          duration: 1500.ms,
          curve:
              Curves.easeInOut,
        );
  }

  // ============================================================
  // ERROR MESSAGE
  // ============================================================

  void showError(
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
        backgroundColor:
            const Color(0xffDC2626),
        margin:
            const EdgeInsets.all(16),
        shape:
            RoundedRectangleBorder(
          borderRadius:
              BorderRadius.circular(15),
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
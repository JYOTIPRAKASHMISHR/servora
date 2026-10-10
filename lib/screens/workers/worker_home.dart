import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:servora/screens/vendor/vendor_accepted_batches_screen.dart';
import 'package:servora/screens/vendor/vendor_batch_details_screen.dart';
import 'package:servora/widgets/servora_logo.dart';

import 'package:servora/screens/notification_screen.dart';
import 'package:servora/screens/workers/available_jobs_screen.dart';
import 'package:servora/screens/workers/my_applications_screen.dart';
import 'package:servora/screens/workers/worker_active_jobs_screen.dart';
import 'package:servora/screens/workers/worker_profile_setup.dart';

import 'package:servora/screens/workers/worker_urgent_jobs_screen.dart';
import 'package:servora/screens/vendor/vendor_service_batches_screen.dart';

class WorkerHome extends StatefulWidget {
  const WorkerHome({super.key});

  @override
  State<WorkerHome> createState() => _WorkerHomeState();
}

class _WorkerHomeState extends State<WorkerHome> {
  final User? currentUser = FirebaseAuth.instance.currentUser;

  final DatabaseReference servicesRef =
      FirebaseDatabase.instance.ref("services");

  StreamSubscription? serviceSubscription;

  bool loading = true;

  bool profileCompleted = false;

  String workerName = "Worker";

  int activeJobs = 0;

  int completedJobs = 0;

  double earnings = 0;

  List<Map<String, dynamic>> recentJobs = [];

  bool availableForUrgent = false;

  bool updatingUrgentStatus = false;

  int selectedIndex = 0;

  @override
  void initState() {
    super.initState();

    loadWorker();
  }

  @override
  void dispose() {
    serviceSubscription?.cancel();

    super.dispose();
  }

  // ============================================================
  // URGENT JOB AVAILABILITY
  // ============================================================

  Future<void> toggleUrgentAvailability(bool value) async {
    if (currentUser == null) {
      return;
    }

    if (updatingUrgentStatus) {
      return;
    }

    setState(() {
      updatingUrgentStatus = true;
    });

    try {
      await FirebaseDatabase.instance
          .ref("workers")
          .child(currentUser!.uid)
          .update({
        "availableForUrgent": value,
      });

      if (!mounted) {
        return;
      }

      setState(() {
        availableForUrgent = value;
        updatingUrgentStatus = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            value
                ? "You are now ACTIVE for urgent jobs"
                : "You are now INACTIVE for urgent jobs",
          ),
          backgroundColor:
              value ? Colors.green : Colors.grey.shade700,
        ),
      );
    } catch (e) {
      debugPrint("Urgent availability error: $e");

      if (!mounted) {
        return;
      }

      setState(() {
        updatingUrgentStatus = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Unable to update availability"),
        ),
      );
    }
  }

  // ============================================================
  // LOAD WORKER
  // ============================================================

  Future<void> loadWorker() async {
    if (currentUser == null) {
      return;
    }

    try {
      DatabaseEvent event = await FirebaseDatabase.instance
          .ref("workers")
          .child(currentUser!.uid)
          .once();

      if (event.snapshot.exists) {
        Map data = Map.from(
          event.snapshot.value as Map,
        );

        workerName = data["name"] ?? "Worker";

        profileCompleted =
            data["profileCompleted"] ?? false;

        availableForUrgent =
            data["availableForUrgent"] == true;
      }

      listenServices();
    } catch (e) {
      debugPrint(e.toString());

      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  // ============================================================
  // LISTEN SERVICES
  // ============================================================

  void listenServices() {
    if (currentUser == null) {
      return;
    }

    serviceSubscription?.cancel();

    serviceSubscription = servicesRef.onValue.listen(
      (event) {
        if (!event.snapshot.exists) {
          if (mounted) {
            setState(() {
              loading = false;
            });
          }

          return;
        }

        int active = 0;

        int complete = 0;

        double money = 0;

        List<Map<String, dynamic>> jobs = [];

        Map data = Map.from(
          event.snapshot.value as Map,
        );

        data.forEach((key, value) {
          Map service =
              Map<String, dynamic>.from(value);

          if (service["assignedWorkerId"] ==
              currentUser!.uid) {
            String status =
                service["status"] ?? "assigned";

            // ==========================================
            // ACTIVE JOBS
            // ==========================================

            if (status != "completed") {
              active++;

              jobs.add({
                "serviceId": key,
                ...service,
              });
            }

            // ==========================================
            // COMPLETED JOBS + EARNINGS
            // ==========================================

            if (status == "completed") {
              complete++;

              money +=
                  double.tryParse(
                    service["finalPrice"].toString(),
                  ) ??
                  0;
            }
          }
        });

        // ==========================================
        // SORT RECENT JOBS
        // ==========================================

        jobs.sort(
          (a, b) => b["assignedAt"]
              .toString()
              .compareTo(
                a["assignedAt"].toString(),
              ),
        );

        if (mounted) {
          setState(() {
            activeJobs = active;

            completedJobs = complete;

            earnings = money;

            recentJobs =
                jobs.take(3).toList();

            loading = false;
          });
        }
      },
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffF8FAFC),

      body: SafeArea(
        child: loading
            ? const Center(
                child: CircularProgressIndicator(),
              )
            : Column(
                children: [
                  buildHeader(),

                  Expanded(
                    child: buildBody(),
                  ),
                ],
              ),
      ),

      bottomNavigationBar: buildBottomBar(),
    );
  }

  // ============================================================
  // HEADER
  // ============================================================

  Widget buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        20,
        16,
        20,
        14,
      ),
      child: Row(
        children: [
          // ==================================================
          // LOGO
          // ==================================================

          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(.08),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        const AdminVendorBatchesScreen(
                      batch: {},
                    ),
                  ),
                );
              },
              child: const ServoraLogo(
                size: 50,
              ),
            ),
          ),

          const SizedBox(width: 12),

          // ==================================================
          // GREETING
          // ==================================================

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  "Hello, $workerName 👋",
                  maxLines: 1,
                  overflow:
                      TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -.3,
                  ),
                ),

                const SizedBox(height: 3),

                Text(
                  "Ready for new bookings?",
                  maxLines: 1,
                  overflow:
                      TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.grey.shade500,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 8),

          // ==================================================
          // ACTIVE SWITCH
          // ==================================================

          Container(
            height: 43,
            padding:
                const EdgeInsets.symmetric(
              horizontal: 5,
            ),
            decoration: BoxDecoration(
              color: availableForUrgent
                  ? Colors.green.shade50
                  : Colors.grey.shade100,
              borderRadius:
                  BorderRadius.circular(22),
              border: Border.all(
                color: availableForUrgent
                    ? Colors.green.shade200
                    : Colors.grey.shade200,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  height: 8,
                  width: 8,
                  decoration: BoxDecoration(
                    color: availableForUrgent
                        ? Colors.green
                        : Colors.grey,
                    shape: BoxShape.circle,
                  ),
                ),

                const SizedBox(width: 4),

                Text(
                  availableForUrgent
                      ? "ON"
                      : "OFF",
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: availableForUrgent
                        ? Colors.green.shade700
                        : Colors.grey.shade600,
                  ),
                ),

                SizedBox(
                  width: 32,
                  height: 35,
                  child: FittedBox(
                    child: Switch(
                      value: availableForUrgent,
                      activeThumbColor:
                          Colors.green,
                      onChanged:
                          updatingUrgentStatus
                              ? null
                              : toggleUrgentAvailability,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 7),

          // ==================================================
          // NOTIFICATION
          // ==================================================

          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      const NotificationScreen(),
                ),
              );
            },
            child: Container(
              height: 45,
              width: 45,
              decoration: BoxDecoration(
                gradient:
                    const LinearGradient(
                  colors: [
                    Color(0xff2563EB),
                    Color(0xff38BDF8),
                  ],
                ),
                borderRadius:
                    BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.blue
                        .withOpacity(.18),
                    blurRadius: 12,
                    offset:
                        const Offset(0, 6),
                  ),
                ],
              ),
              child: const Icon(
                Icons
                    .notifications_none_rounded,
                color: Colors.white,
                size: 23,
              ),
            ),
          ),
        ],
      ),
    )
        .animate()
        .fade(duration: 450.ms)
        .slideY(
          begin: -.12,
          curve: Curves.easeOut,
        );
  }

  // ============================================================
  // BODY
  //
  // ORDER:
  //
  // 1. Earnings
  // 2. Society Service Batches
  // 3. Urgent Jobs
  // 4. Recent Jobs
  // ============================================================

  Widget buildBody() {
    if (!profileCompleted) {
      return buildProfileRequired();
    }

    return SingleChildScrollView(
      physics:
          const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        20,
        4,
        20,
        100,
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          // ==================================================
          // 1️⃣ TOTAL EARNINGS
          //
          // Active + Completed remain INSIDE this card.
          // ==================================================

          buildEarningCard(),

          const SizedBox(height: 18),

          // ==================================================
          // 2️⃣ SOCIETY SERVICE BATCHES
          // ==================================================

          _buildVendorBatchesCard(),

          const SizedBox(height: 14),

          // ==================================================
          // 3️⃣ URGENT JOBS
          // ==================================================

          _buildUrgentJobsCard(),

          const SizedBox(height: 28),

          // ==================================================
          // 4️⃣ RECENT JOBS TITLE
          // ==================================================

          Row(
            children: [
              const Expanded(
                child: Text(
                  "Recent Jobs",
                  style: TextStyle(
                    fontSize: 21,
                    fontWeight:
                        FontWeight.w800,
                  ),
                ),
              ),

              if (recentJobs.isNotEmpty)
                Text(
                  "View all",
                  style: TextStyle(
                    color:
                        Colors.blue.shade600,
                    fontSize: 11,
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),
            ],
          ),

          const SizedBox(height: 15),

          // ==================================================
          // RECENT JOBS
          // ==================================================

          recentJobs.isEmpty
              ? emptyRecentJobs()
              : Column(
                  children: recentJobs
                      .map(
                        (job) =>
                            jobCard(job),
                      )
                      .toList(),
                ),
        ],
      ),
    );
  }

  // ============================================================
  // EARNINGS CARD
  // ============================================================

  Widget buildEarningCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius:
            BorderRadius.circular(30),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xff1D4ED8),
            Color(0xff2563EB),
            Color(0xff38BDF8),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xff2563EB)
                .withOpacity(0.28),
            blurRadius: 28,
            offset:
                const Offset(0, 15),
          ),
        ],
      ),
      child: Stack(
        children: [
          // ==================================================
          // BACKGROUND 3D CIRCLES
          // ==================================================

          Positioned(
            right: -45,
            top: -45,
            child: Container(
              height: 150,
              width: 150,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color:
                    Colors.white.withOpacity(
                  0.08,
                ),
              ),
            ),
          ),

          Positioned(
            right: 25,
            bottom: -65,
            child: Container(
              height: 130,
              width: 130,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color:
                    Colors.white.withOpacity(
                  0.06,
                ),
              ),
            ),
          ),

          Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              // ==================================================
              // EARNINGS TITLE
              // ==================================================

              Row(
                children: [
                  Container(
                    height: 42,
                    width: 42,
                    decoration: BoxDecoration(
                      color:
                          Colors.white.withOpacity(
                        0.15,
                      ),
                      borderRadius:
                          BorderRadius.circular(
                        14,
                      ),
                      border: Border.all(
                        color: Colors.white
                            .withOpacity(
                          0.20,
                        ),
                      ),
                    ),
                    child: const Icon(
                      Icons
                          .account_balance_wallet_rounded,
                      color: Colors.white,
                      size: 21,
                    ),
                  ),

                  const SizedBox(width: 11),

                  const Text(
                    "TOTAL EARNINGS",
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                      fontWeight:
                          FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 18),

              // ==================================================
              // EARNINGS AMOUNT
              // ==================================================

              TweenAnimationBuilder<double>(
                tween: Tween(
                  begin: 0,
                  end: earnings,
                ),
                duration:
                    const Duration(
                  milliseconds: 1200,
                ),
                curve:
                    Curves.easeOutCubic,
                builder: (
                  context,
                  value,
                  child,
                ) {
                  return Text(
                    "₹ ${value.toStringAsFixed(0)}",
                    style:
                        const TextStyle(
                      color: Colors.white,
                      fontSize: 36,
                      fontWeight:
                          FontWeight.w800,
                      letterSpacing: -1,
                    ),
                  );
                },
              ),

              const SizedBox(height: 8),

              // ==================================================
              // TREND
              // ==================================================

              Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets
                            .symmetric(
                      horizontal: 9,
                      vertical: 5,
                    ),
                    decoration:
                        BoxDecoration(
                      color: Colors.white
                          .withOpacity(
                        0.14,
                      ),
                      borderRadius:
                          BorderRadius.circular(
                        20,
                      ),
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          Icons
                              .trending_up_rounded,
                          color:
                              Colors.white,
                          size: 15,
                        ),
                        SizedBox(width: 4),
                        Text(
                          "Growing earnings",
                          style: TextStyle(
                            color:
                                Colors.white,
                            fontSize: 10,
                            fontWeight:
                                FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 25),

              // ==================================================
              // ACTIVE + COMPLETED
              //
              // They stay inside Earnings card.
              // ==================================================

              Row(
                children: [
                  Expanded(
                    child:
                        _buildHeroMiniStat(
                      icon: Icons
                          .work_outline_rounded,
                      label: "Active",
                      value:
                          activeJobs.toString(),
                    ),
                  ),

                  const SizedBox(width: 10),

                  Expanded(
                    child:
                        _buildHeroMiniStat(
                      icon: Icons
                          .check_circle_outline_rounded,
                      label: "Completed",
                      value:
                          completedJobs
                              .toString(),
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
        .fade(duration: 500.ms)
        .slideY(
          begin: .15,
          curve: Curves.easeOut,
        );
  }

  // ============================================================
  // EARNINGS MINI STAT
  // ============================================================

  Widget _buildHeroMiniStat({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 13,
        vertical: 11,
      ),
      decoration: BoxDecoration(
        color: Colors.white
            .withOpacity(0.12),
        borderRadius:
            BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white
              .withOpacity(0.12),
        ),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: Colors.white,
            size: 18,
          ),

          const SizedBox(width: 8),

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style:
                      const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),

                Text(
                  label,
                  style:
                      const TextStyle(
                    color: Colors.white70,
                    fontSize: 9,
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

  Widget jobCard(
    Map<String, dynamic> job,
  ) {
    final status =
        job["status"]?.toString() ??
            "assigned";

    return _build3DCard(
      padding:
          const EdgeInsets.all(16),
      onTap: () {
        // Existing functionality preserved.
        // Add your existing job navigation here
        // if you already had one.
      },
      child: Column(
        children: [
          Row(
            children: [
              // ==================================================
              // 3D ICON
              // ==================================================

              Container(
                height: 58,
                width: 58,
                decoration: BoxDecoration(
                  gradient:
                      const LinearGradient(
                    begin:
                        Alignment.topLeft,
                    end:
                        Alignment.bottomRight,
                    colors: [
                      Color(0xffDBEAFE),
                      Color(0xffBFDBFE),
                    ],
                  ),
                  borderRadius:
                      BorderRadius.circular(
                    18,
                  ),
                  boxShadow:
                      const [
                    BoxShadow(
                      color:
                          Color(0x22000000),
                      blurRadius: 8,
                      offset:
                          Offset(0, 5),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons
                      .handyman_rounded,
                  color:
                      Color(0xff2563EB),
                  size: 28,
                ),
              ),

              const SizedBox(width: 14),

              // ==================================================
              // JOB INFORMATION
              // ==================================================

              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment
                          .start,
                  children: [
                    Text(
                      job["title"] ??
                          "Service Request",
                      maxLines: 1,
                      overflow:
                          TextOverflow
                              .ellipsis,
                      style:
                          const TextStyle(
                        fontSize: 15,
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),

                    const SizedBox(
                      height: 6,
                    ),

                    Text(
                      "₹ ${job["finalPrice"] ?? 0}",
                      style:
                          const TextStyle(
                        color:
                            Colors.green,
                        fontWeight:
                            FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),

              // ==================================================
              // ARROW
              // ==================================================

              Container(
                height: 38,
                width: 38,
                decoration:
                    BoxDecoration(
                  color:
                      Colors.grey.shade100,
                  shape:
                      BoxShape.circle,
                ),
                child:
                    const Icon(
                  Icons
                      .arrow_forward_rounded,
                  size: 18,
                  color: Colors.grey,
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // ==================================================
          // STATUS
          // ==================================================

          Row(
            children: [
              Container(
                height: 8,
                width: 8,
                decoration:
                    const BoxDecoration(
                  color:
                      Colors.orange,
                  shape:
                      BoxShape.circle,
                ),
              ),

              const SizedBox(width: 7),

              Text(
                status.toUpperCase(),
                style:
                    const TextStyle(
                  color:
                      Colors.orange,
                  fontSize: 10,
                  fontWeight:
                      FontWeight.bold,
                  letterSpacing: .5,
                ),
              ),

              const Spacer(),

              Text(
                "View job",
                style:
                    TextStyle(
                  color:
                      Colors.grey.shade500,
                  fontSize: 10,
                  fontWeight:
                      FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    )
        .animate()
        .fade(delay: 200.ms)
        .slideX(
          begin: .08,
          curve: Curves.easeOut,
        );
  }

  // ============================================================
  // EMPTY RECENT JOBS
  // ============================================================

  Widget emptyRecentJobs() {
    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.all(25),
      alignment: Alignment.center,
      child: const Text(
        "No active jobs yet",
        style:
            TextStyle(color: Colors.grey),
      ),
    );
  }

  // ============================================================
  // PROFILE REQUIRED
  // ============================================================

  Widget buildProfileRequired() {
    return Center(
      child: Padding(
        padding:
            const EdgeInsets.all(25),
        child: Container(
          padding:
              const EdgeInsets.all(25),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius:
                BorderRadius.circular(25),
            boxShadow: [
              BoxShadow(
                color: Colors.black
                    .withOpacity(.06),
                blurRadius: 20,
                offset:
                    const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize:
                MainAxisSize.min,
            children: [
              // ==================================================
              // ICON
              // ==================================================

              Container(
                height: 85,
                width: 85,
                decoration:
                    BoxDecoration(
                  gradient:
                      const LinearGradient(
                    colors: [
                      Color(0xffDBEAFE),
                      Color(0xffEFF6FF),
                    ],
                  ),
                  shape:
                      BoxShape.circle,
                ),
                child: const Icon(
                  Icons
                      .person_add_alt,
                  size: 45,
                  color:
                      Color(0xff2563EB),
                ),
              ),

              const SizedBox(height: 20),

              const Text(
                "Complete Worker Profile",
                textAlign:
                    TextAlign.center,
                style:
                    TextStyle(
                  fontSize: 22,
                  fontWeight:
                      FontWeight.bold,
                ),
              ),

              const SizedBox(height: 10),

              const Text(
                "Add skills, location and experience before applying jobs",
                textAlign:
                    TextAlign.center,
                style:
                    TextStyle(
                  color: Colors.grey,
                ),
              ),

              const SizedBox(height: 25),

              SizedBox(
                width: double.infinity,
                child:
                    ElevatedButton(
                  style:
                      ElevatedButton.styleFrom(
                    backgroundColor:
                        const Color(
                      0xff2563EB,
                    ),
                    foregroundColor:
                        Colors.white,
                    padding:
                        const EdgeInsets
                            .all(15),
                    shape:
                        RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius
                              .circular(
                        15,
                      ),
                    ),
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder:
                            (context) =>
                                const WorkerProfileSetup(),
                      ),
                    ).then((value) {
                      loadWorker();
                    });
                  },
                  child:
                      const Text(
                    "Complete Profile",
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
        ),
      ),
    )
        .animate()
        .fade(duration: 400.ms)
        .scale(
          begin:
              const Offset(.95, .95),
          end:
              const Offset(1, 1),
        );
  }

  // ============================================================
  // BOTTOM NAVIGATION
  // ============================================================

  Widget buildBottomBar() {
    return BottomNavigationBar(
      currentIndex:
          selectedIndex,

      type:
          BottomNavigationBarType.fixed,

      selectedItemColor:
          const Color(0xff2563EB),

      unselectedItemColor:
          Colors.grey,

      onTap: (index) {
        setState(() {
          selectedIndex =
              index;
        });

        switch (index) {
          // ==================================================
          // JOBS
          // ==================================================

          case 1:
            Navigator.push(
              context,
              MaterialPageRoute(
                builder:
                    (context) =>
                        const AvailableJobsScreen(),
              ),
            );

            break;

          // ==================================================
          // APPLICATIONS
          // ==================================================

          case 2:
            Navigator.push(
              context,
              MaterialPageRoute(
                builder:
                    (context) =>
                        const MyApplicationsScreen(),
              ),
            );

            break;

          // ==================================================
          // ACTIVE JOBS
          // ==================================================

          case 3:
            Navigator.push(
              context,
              MaterialPageRoute(
                builder:
                    (context) =>
                        const WorkerActiveJobsScreen(),
              ),
            );

            break;

          // ==================================================
          // PROFILE
          // ==================================================

          case 4:
            Navigator.push(
              context,
              MaterialPageRoute(
                builder:
                    (context) =>
                        const WorkerProfileSetup(),
              ),
            );

            break;
        }
      },

      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.home),
          label: "Home",
        ),

        BottomNavigationBarItem(
          icon: Icon(Icons.search),
          label: "Jobs",
        ),

        BottomNavigationBarItem(
          icon: Icon(Icons.assignment),
          label: "Applications",
        ),

        BottomNavigationBarItem(
          icon: Icon(Icons.work),
          label: "Active",
        ),

        BottomNavigationBarItem(
          icon: Icon(Icons.person),
          label: "Profile",
        ),
      ],
    );
  }

  // ============================================================
  // URGENT JOBS CARD
  // ============================================================

  Widget _buildUrgentJobsCard() {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder:
                (context) =>
                    const WorkerUrgentJobsScreen(),
          ),
        );
      },
      child: Container(
        padding:
            const EdgeInsets.all(20),
        decoration:
            BoxDecoration(
          borderRadius:
              BorderRadius.circular(25),
          gradient:
              const LinearGradient(
            begin:
                Alignment.topLeft,
            end:
                Alignment.bottomRight,
            colors: [
              Color(0xffEF4444),
              Color(0xffF97316),
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.red
                  .withOpacity(.20),
              blurRadius: 18,
              offset:
                  const Offset(0, 9),
            ),
          ],
        ),
        child: Row(
          children: [
            // ==================================================
            // ICON
            // ==================================================

            Container(
              height: 52,
              width: 52,
              decoration:
                  BoxDecoration(
                color: Colors.white
                    .withOpacity(.15),
                borderRadius:
                    BorderRadius.circular(
                  17,
                ),
                border: Border.all(
                  color: Colors.white
                      .withOpacity(.20),
                ),
              ),
              child:
                  const Icon(
                Icons.bolt_rounded,
                color:
                    Colors.white,
                size: 29,
              ),
            ),

            const SizedBox(width: 14),

            // ==================================================
            // TEXT
            // ==================================================

            const Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment
                        .start,
                children: [
                  Text(
                    "Urgent Jobs",
                    style:
                        TextStyle(
                      color:
                          Colors.white,
                      fontSize: 18,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),

                  SizedBox(height: 4),

                  Text(
                    "Accept emergency requests nearby",
                    style:
                        TextStyle(
                      color:
                          Colors.white70,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),

            // ==================================================
            // ARROW
            // ==================================================

            Container(
              height: 40,
              width: 40,
              decoration:
                  const BoxDecoration(
                color: Colors.white,
                shape:
                    BoxShape.circle,
              ),
              child:
                  const Icon(
                Icons
                    .arrow_forward_rounded,
                color:
                    Colors.red,
                size: 19,
              ),
            ),
          ],
        ),
      ),
    )
        .animate()
        .fade(delay: 300.ms)
        .slideX(
          begin: .1,
          curve: Curves.easeOut,
        );
  }

  // ============================================================
  // SOCIETY SERVICE BATCHES CARD
  // ============================================================

  Widget _buildVendorBatchesCard() {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                const VendorServiceBatchesScreen(),
          ),
        );
      },
      child: Container(
        width: double.infinity,
        padding:
            const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius:
              BorderRadius.circular(25),
          gradient:
              const LinearGradient(
            begin:
                Alignment.topLeft,
            end:
                Alignment.bottomRight,
            colors: [
              Colors.white,
              Color(0xffEFF6FF),
            ],
          ),
          border: Border.all(
            color:
                const Color(0xffDBEAFE),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.blue
                  .withOpacity(.08),
              blurRadius: 18,
              offset:
                  const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            // ==================================================
            // APARTMENT ICON
            // ==================================================

            Container(
              height: 58,
              width: 58,
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
                  18,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.blue
                        .withOpacity(.20),
                    blurRadius: 10,
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
                Icons.apartment_rounded,
                color:
                    Colors.white,
                size: 30,
              ),
            ),

            const SizedBox(width: 15),

            // ==================================================
            // TEXT
            // ==================================================

            const Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment
                        .start,
                children: [
                  Text(
                    "Society Service Batches",
                    style:
                        TextStyle(
                      fontSize: 17,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),

                  SizedBox(height: 5),

                  Text(
                    "Find apartment demand and grow your bookings.",
                    maxLines: 2,
                    overflow:
                        TextOverflow
                            .ellipsis,
                    style:
                        TextStyle(
                      color:
                          Colors.grey,
                      fontSize: 11,
                      height: 1.4,
                    ),
                  ),

                  SizedBox(height: 8),

                  Text(
                    "Explore opportunities →",
                    style:
                        TextStyle(
                      color:
                          Color(0xff2563EB),
                      fontSize: 11,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 8),

            // ==================================================
            // ARROW
            // ==================================================

            Container(
              height: 40,
              width: 40,
              decoration:
                  const BoxDecoration(
                color:
                    Color(0xff2563EB),
                shape:
                    BoxShape.circle,
              ),
              child:
                  const Icon(
                Icons
                    .arrow_forward_rounded,
                color:
                    Colors.white,
                size: 19,
              ),
            ),
          ],
        ),
      ),
    )
        .animate()
        .fade(delay: 200.ms)
        .slideX(
          begin: .1,
          curve: Curves.easeOut,
        );
  }

  // ============================================================
  // 3D CARD
  // ============================================================

  Widget _build3DCard({
    required Widget child,
    EdgeInsetsGeometry padding =
        const EdgeInsets.all(18),
    VoidCallback? onTap,
  }) {
    final card = Container(
      decoration:
          BoxDecoration(
        borderRadius:
            BorderRadius.circular(26),
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black
                .withOpacity(0.06),
            blurRadius: 20,
            offset:
                const Offset(0, 10),
          ),
          BoxShadow(
            color: Colors.white
                .withOpacity(0.8),
            blurRadius: 4,
            offset:
                const Offset(-2, -2),
          ),
        ],
      ),
      child: Container(
        margin:
            const EdgeInsets.only(
          top: 2,
          left: 1,
          right: 1,
          bottom: 4,
        ),
        padding: padding,
        decoration:
            BoxDecoration(
          borderRadius:
              BorderRadius.circular(25),
          gradient:
              const LinearGradient(
            begin:
                Alignment.topLeft,
            end:
                Alignment.bottomRight,
            colors: [
              Colors.white,
              Color(0xffF8FAFC),
            ],
          ),
        ),
        child: child,
      ),
    );

    if (onTap == null) {
      return card;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius:
            BorderRadius.circular(26),
        onTap: onTap,
        child: card,
      ),
    );
  }
}
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'package:servora/screens/workers/worker_home.dart';
import 'worker_identity_verification.dart';
import '../../screens/login_screen.dart';

class WorkerProfileSetup extends StatefulWidget {
  const WorkerProfileSetup({super.key});

  @override
  State<WorkerProfileSetup> createState() =>
      _WorkerProfileSetupState();
}

class _WorkerProfileSetupState extends State<WorkerProfileSetup>
    with SingleTickerProviderStateMixin {
  // ============================================================
  // CONTROLLERS
  // ============================================================

  final TextEditingController nameController =
      TextEditingController();

  final TextEditingController skillController =
      TextEditingController();

  final TextEditingController aboutController =
      TextEditingController();

  // ============================================================
  // FIREBASE
  // ============================================================

  final FirebaseAuth auth = FirebaseAuth.instance;

  final DatabaseReference workerRef =
      FirebaseDatabase.instance.ref("workers");

  // ============================================================
  // PROFILE DATA
  // ============================================================

  String experience = "";

  List<String> selectedSkills = [];

  String currentAddress = "";

  double? latitude;
  double? longitude;

  bool locationLoading = false;
  bool savingProfile = false;

  // ============================================================
  // ANIMATION CONTROLLER
  // ============================================================

  AnimationController? _floatingController;

  // ============================================================
  // DEFAULT SKILLS
  // ============================================================

  final List<String> skills = [
    "AC Repair",
    "Electrician",
    "Plumbing",
    "Cleaning",
    "Painting",
    "Car Repair",
    "Gardening",
    "Moving Service",
  ];

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();

    _floatingController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat(reverse: true);

    loadUserData();
    loadWorkerProfile();
    getCurrentLocation();
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    _floatingController?.dispose();

    nameController.dispose();
    skillController.dispose();
    aboutController.dispose();

    super.dispose();
  }

  // ============================================================
  // LOGOUT
  // ============================================================

  Future<void> logout() async {
    try {
      await auth.signOut();

      if (!mounted) return;

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (context) => const LoginScreen(),
        ),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;

      _showMessage(
        e.toString(),
        Colors.red,
      );
    }
  }

  // ============================================================
  // LOAD USER DATA
  // ============================================================

  Future<void> loadUserData() async {
    try {
      final User? user = auth.currentUser;

      if (user == null) return;

      final DatabaseEvent event =
          await FirebaseDatabase.instance
              .ref("users/${user.uid}")
              .once();

      if (!event.snapshot.exists) return;

      final dynamic rawData = event.snapshot.value;

      if (rawData is! Map) return;

      final Map data = Map.from(rawData);

      if (!mounted) return;

      final String userName =
          (data["name"] ?? "").toString().trim();

      if (userName.isNotEmpty) {
        setState(() {
          nameController.text = userName;
        });
      }
    } catch (e) {
      debugPrint("loadUserData error: $e");
    }
  }

  // ============================================================
  // LOAD EXISTING WORKER PROFILE
  // ============================================================

  Future<void> loadWorkerProfile() async {
    try {
      final User? user = auth.currentUser;

      if (user == null) return;

      final DatabaseEvent event =
          await workerRef.child(user.uid).once();

      if (!event.snapshot.exists) return;

      final dynamic rawData = event.snapshot.value;

      if (rawData is! Map) return;

      final Map data = Map.from(rawData);

      final dynamic storedSkills = data["skills"];

      List<String> loadedSkills = [];

      if (storedSkills is List) {
        loadedSkills = storedSkills
            .map((e) => e.toString())
            .where(
              (e) => e.trim().isNotEmpty,
            )
            .toList();
      } else if (storedSkills is Map) {
        loadedSkills = storedSkills.values
            .map((e) => e.toString())
            .where(
              (e) => e.trim().isNotEmpty,
            )
            .toList();
      }

      if (!mounted) return;

      setState(() {
        final String storedName =
            (data["name"] ?? "").toString();

        if (storedName.trim().isNotEmpty) {
          nameController.text = storedName;
        }

        aboutController.text =
            (data["about"] ?? "").toString();

        experience =
            (data["experience"] ?? "").toString();

        selectedSkills = loadedSkills;

        currentAddress =
            (data["location"] ?? "").toString();

        latitude = data["latitude"] != null
            ? double.tryParse(
                data["latitude"].toString(),
              )
            : null;

        longitude = data["longitude"] != null
            ? double.tryParse(
                data["longitude"].toString(),
              )
            : null;
      });
    } catch (e) {
      debugPrint(
        "loadWorkerProfile error: $e",
      );
    }
  }

  // ============================================================
  // LOCATION
  // ============================================================

  Future<void> getCurrentLocation() async {
    if (!mounted) return;

    setState(() {
      locationLoading = true;
    });

    try {
      LocationPermission permission =
          await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission =
            await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        if (!mounted) return;

        setState(() {
          locationLoading = false;
        });

        _showMessage(
          "Location permission is required.",
          Colors.orange,
        );

        return;
      }

      if (permission ==
          LocationPermission.deniedForever) {
        if (!mounted) return;

        setState(() {
          locationLoading = false;
        });

        _showMessage(
          "Location permission is permanently denied. Please enable it from Settings.",
          Colors.orange,
        );

        return;
      }

      final bool serviceEnabled =
          await Geolocator.isLocationServiceEnabled();

      if (!serviceEnabled) {
        if (!mounted) return;

        setState(() {
          locationLoading = false;
        });

        _showMessage(
          "Please turn on your device location.",
          Colors.orange,
        );

        return;
      }

      final Position position =
          await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      final double newLatitude =
          position.latitude;

      final double newLongitude =
          position.longitude;

      final List<Placemark> places =
          await placemarkFromCoordinates(
        newLatitude,
        newLongitude,
      );

      if (!mounted) return;

      latitude = newLatitude;
      longitude = newLongitude;

      if (places.isEmpty) {
        setState(() {
          locationLoading = false;
        });

        return;
      }

      final Placemark place = places.first;

      final List<String> addressParts = [
        place.name,
        place.street,
        place.subLocality,
        place.locality,
        place.administrativeArea,
        place.country,
      ]
          .where(
            (value) =>
                value != null &&
                value.trim().isNotEmpty,
          )
          .map(
            (value) => value!.trim(),
          )
          .toList();

      setState(() {
        currentAddress =
            addressParts.join(", ");

        locationLoading = false;
      });
    } catch (e) {
      debugPrint(
        "Location error: $e",
      );

      if (!mounted) return;

      setState(() {
        locationLoading = false;
      });

      _showMessage(
        "Unable to detect location. Please try again.",
        Colors.red,
      );
    }
  }

  // ============================================================
  // SAVE PROFILE
  // ============================================================

  Future<void> saveWorkerProfile() async {
    if (nameController.text.trim().isEmpty) {
      _showMessage(
        "Please enter your name.",
        Colors.red,
      );
      return;
    }

    if (selectedSkills.isEmpty) {
      _showMessage(
        "Please select at least one skill.",
        Colors.red,
      );
      return;
    }

    if (experience.isEmpty) {
      _showMessage(
        "Please select your experience.",
        Colors.red,
      );
      return;
    }

    if (currentAddress.trim().isEmpty) {
      _showMessage(
        "Please add your location.",
        Colors.red,
      );
      return;
    }

    if (savingProfile) return;

    setState(() {
      savingProfile = true;
    });

    try {
      final User? user =
          FirebaseAuth.instance.currentUser;

      if (user == null) {
        throw Exception(
          "User is not logged in.",
        );
      }

      final String uid = user.uid;

      await workerRef.child(uid).set({
        "workerId": uid,
        "name": nameController.text.trim(),
        "about": aboutController.text.trim(),
        "skills": selectedSkills,
        "experience": experience,
        "location": currentAddress,
        "latitude": latitude,
        "longitude": longitude,
        "verificationLevel": 0,
        "badge": "New Member",
        "profileCompleted": true,
        "createdAt":
            DateTime.now().toIso8601String(),
      });

      if (!mounted) return;

      _showMessage(
        "Worker profile created successfully!",
        Colors.green,
      );

      await Future.delayed(
        const Duration(
          milliseconds: 700,
        ),
      );

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) =>
              const WorkerHome(),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      _showMessage(
        e.toString(),
        Colors.red,
      );
    } finally {
      if (mounted) {
        setState(() {
          savingProfile = false;
        });
      }
    }
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
        .hideCurrentSnackBar();

    ScaffoldMessenger.of(context)
        .showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: color,
        behavior:
            SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
          borderRadius:
              BorderRadius.circular(16),
        ),
      ),
    );
  }

  // ============================================================
  // MAIN BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          const Color(0xffF4F7FC),
      extendBodyBehindAppBar: true,
      appBar: _buildAppBar(),
      body: Stack(
        children: [
          _buildAnimatedBackground(),

          SafeArea(
            child: SingleChildScrollView(
              physics:
                  const BouncingScrollPhysics(),
              padding:
                  const EdgeInsets.fromLTRB(
                18,
                20,
                18,
                40,
              ),
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  _buildHeroSection(),

                  const SizedBox(height: 24),

                  _sectionHeader(
                    "Profile Information",
                    "Tell customers who you are",
                    Icons.person_outline_rounded,
                  ),

                  const SizedBox(height: 14),

                  _buildProfileCard(),

                  const SizedBox(height: 26),

                  _sectionHeader(
                    "Your Skills",
                    "Select the services you provide",
                    Icons.handyman_outlined,
                  ),

                  const SizedBox(height: 14),

                  _buildSkillsCard(),

                  const SizedBox(height: 26),

                  _sectionHeader(
                    "Experience",
                    "Tell customers about your experience",
                    Icons.workspace_premium_outlined,
                  ),

                  const SizedBox(height: 14),

                  _buildExperienceCard(),

                  const SizedBox(height: 26),

                  _sectionHeader(
                    "Your Location",
                    "Used to connect you with nearby jobs",
                    Icons.location_on_outlined,
                  ),

                  const SizedBox(height: 14),

                  _buildLocationCard(),

                  const SizedBox(height: 26),

                  _sectionHeader(
                    "Trust & Verification",
                    "Build confidence with customers",
                    Icons.verified_user_outlined,
                  ),

                  const SizedBox(height: 14),

                  _buildVerificationCard(),

                  const SizedBox(height: 30),

                  _buildSubmitButton(),

                  const SizedBox(height: 12),

                  Center(
                    child: Text(
                      "Your information is securely stored with Servora.",
                      textAlign:
                          TextAlign.center,
                      style: TextStyle(
                        color:
                            Colors.grey.shade600,
                        fontSize: 12,
                      ),
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
  // APP BAR
  // ============================================================

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor:
          Colors.transparent,
      elevation: 0,
      foregroundColor: Colors.white,
      titleSpacing: 18,
      title: const Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Text(
            "Worker Profile",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            "Create your professional profile",
            style: TextStyle(
              fontSize: 11,
              color: Colors.white70,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
      actions: [
        Container(
          margin:
              const EdgeInsets.only(
            right: 12,
            top: 8,
            bottom: 8,
          ),
          decoration: BoxDecoration(
            color:
                Colors.white.withOpacity(.14),
            borderRadius:
                BorderRadius.circular(16),
            border: Border.all(
              color:
                  Colors.white.withOpacity(.18),
            ),
          ),
          child: IconButton(
            tooltip: "Logout",
            icon: const Icon(
              Icons.logout_rounded,
              color: Colors.white,
            ),
            onPressed:
                _showLogoutDialog,
          ),
        ),
      ],
    );
  }

  // ============================================================
  // ANIMATED BACKGROUND
  // ============================================================

  Widget _buildAnimatedBackground() {
    final AnimationController? controller =
        _floatingController;

    if (controller == null) {
      return Positioned.fill(
        child: Container(
          decoration:
              const BoxDecoration(
            gradient:
                LinearGradient(
              begin:
                  Alignment.topCenter,
              end:
                  Alignment.bottomCenter,
              colors: [
                Color(0xff0F2F73),
                Color(0xff1D4ED8),
                Color(0xffF4F7FC),
              ],
              stops: [
                0.0,
                0.28,
                0.55,
              ],
            ),
          ),
        ),
      );
    }

    return Positioned.fill(
      child: AnimatedBuilder(
        animation: controller,
        builder:
            (context, child) {
          final double value =
              controller.value;

          return Stack(
            children: [
              Container(
                decoration:
                    const BoxDecoration(
                  gradient:
                      LinearGradient(
                    begin:
                        Alignment.topCenter,
                    end:
                        Alignment.bottomCenter,
                    colors: [
                      Color(0xff0F2F73),
                      Color(0xff1D4ED8),
                      Color(0xffF4F7FC),
                    ],
                    stops: [
                      0.0,
                      0.28,
                      0.55,
                    ],
                  ),
                ),
              ),

              Positioned(
                top: 80 + (value * 25),
                right: -70,
                child: _glowCircle(
                  180,
                  Colors.cyanAccent
                      .withOpacity(.13),
                ),
              ),

              Positioned(
                top: 260 - (value * 20),
                left: -90,
                child: _glowCircle(
                  210,
                  Colors.blueAccent
                      .withOpacity(.12),
                ),
              ),

              Positioned(
                top: 430 + (value * 15),
                right: 20,
                child: _glowCircle(
                  100,
                  Colors.lightBlueAccent
                      .withOpacity(.08),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ============================================================
  // GLOW CIRCLE
  // ============================================================

  Widget _glowCircle(
    double size,
    Color color,
  ) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        boxShadow: [
          BoxShadow(
            color: color,
            blurRadius: 60,
            spreadRadius: 15,
          ),
        ],
      ),
    );
  }

  // ============================================================
  // HERO SECTION
  // ============================================================

  Widget _buildHeroSection() {
    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.fromLTRB(
        22,
        25,
        22,
        22,
      ),
      decoration: BoxDecoration(
        gradient:
            const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xff1E40AF),
            Color(0xff2563EB),
            Color(0xff0284C7),
          ],
        ),
        borderRadius:
            BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: const Color(
              0xff2563EB,
            ).withOpacity(.35),
            blurRadius: 30,
            offset:
                const Offset(0, 15),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            top: -50,
            right: -40,
            child: Container(
              width: 150,
              height: 150,
              decoration:
                  BoxDecoration(
                shape:
                    BoxShape.circle,
                color: Colors.white
                    .withOpacity(.07),
              ),
            ),
          ),

          Positioned(
            bottom: -70,
            left: -50,
            child: Container(
              width: 180,
              height: 180,
              decoration:
                  BoxDecoration(
                shape:
                    BoxShape.circle,
                color: Colors.white
                    .withOpacity(.05),
              ),
            ),
          ),

          Column(
            children: [
              Row(
                children: [
                  _build3DAvatar(),

                  const SizedBox(
                    width: 18,
                  ),

                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Welcome to Servora",
                          style:
                              TextStyle(
                            color:
                                Colors.white70,
                            fontSize: 13,
                            fontWeight:
                                FontWeight.w500,
                          ),
                        ),

                        const SizedBox(
                          height: 5,
                        ),

                        Text(
                          nameController
                                  .text
                                  .trim()
                                  .isEmpty
                              ? "New Worker"
                              : nameController
                                  .text
                                  .trim(),
                          maxLines: 1,
                          overflow:
                              TextOverflow
                                  .ellipsis,
                          style:
                              const TextStyle(
                            color:
                                Colors.white,
                            fontSize: 22,
                            fontWeight:
                                FontWeight.w900,
                          ),
                        ),

                        const SizedBox(
                          height: 8,
                        ),

                        Container(
                          padding:
                              const EdgeInsets
                                  .symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration:
                              BoxDecoration(
                            color: Colors
                                .white
                                .withOpacity(
                              .14,
                            ),
                            borderRadius:
                                BorderRadius
                                    .circular(
                              30,
                            ),
                            border:
                                Border.all(
                              color: Colors
                                  .white
                                  .withOpacity(
                                .15,
                              ),
                            ),
                          ),
                          child:
                              const Row(
                            mainAxisSize:
                                MainAxisSize
                                    .min,
                            children: [
                              Icon(
                                Icons
                                    .workspace_premium_rounded,
                                size: 15,
                                color: Colors
                                    .white,
                              ),
                              SizedBox(
                                width: 5,
                              ),
                              Text(
                                "New Member",
                                style:
                                    TextStyle(
                                  color:
                                      Colors
                                          .white,
                                  fontSize:
                                      11,
                                  fontWeight:
                                      FontWeight
                                          .w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(
                height: 24,
              ),

              Row(
                children: [
                  Expanded(
                    child: _heroStat(
                      Icons
                          .handyman_rounded,
                      "${selectedSkills.length}",
                      "Skills",
                    ),
                  ),

                  const SizedBox(
                    width: 10,
                  ),

                  Expanded(
                    child: _heroStat(
                      Icons
                          .timeline_rounded,
                      experience.isEmpty
                          ? "--"
                          : experience,
                      "Experience",
                    ),
                  ),

                  const SizedBox(
                    width: 10,
                  ),

                  Expanded(
                    child: _heroStat(
                      Icons
                          .location_on_rounded,
                      latitude == null
                          ? "Off"
                          : "On",
                      "Location",
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
          duration: 600.ms,
        )
        .slideY(
          begin: .15,
          end: 0,
          curve:
              Curves.easeOutCubic,
        );
  }

  // ============================================================
  // 3D AVATAR
  // ============================================================

  Widget _build3DAvatar() {
    final AnimationController? controller =
        _floatingController;

    if (controller == null) {
      return _staticAvatar();
    }

    return AnimatedBuilder(
      animation: controller,
      builder:
          (context, child) {
        final double rotation =
            math.sin(
                  controller.value *
                      math.pi *
                      2,
                ) *
                .04;

        return Transform(
          alignment:
              Alignment.center,
          transform:
              Matrix4.identity()
                ..setEntry(
                  3,
                  2,
                  0.002,
                )
                ..rotateY(rotation)
                ..rotateX(
                  rotation * .5,
                ),
          child: _staticAvatar(),
        );
      },
    );
  }

  // ============================================================
  // STATIC AVATAR
  // ============================================================

  Widget _staticAvatar() {
    return Container(
      width: 82,
      height: 82,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient:
            const LinearGradient(
          begin:
              Alignment.topLeft,
          end:
              Alignment.bottomRight,
          colors: [
            Colors.white,
            Color(0xffBFDBFE),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black
                .withOpacity(.20),
            blurRadius: 20,
            offset:
                const Offset(0, 10),
          ),
        ],
      ),
      child: Container(
        margin:
            const EdgeInsets.all(5),
        decoration:
            const BoxDecoration(
          shape:
              BoxShape.circle,
          gradient:
              LinearGradient(
            begin:
                Alignment.topLeft,
            end:
                Alignment.bottomRight,
            colors: [
              Color(0xffDBEAFE),
              Color(0xff93C5FD),
            ],
          ),
        ),
        child: const Icon(
          Icons.person_rounded,
          size: 48,
          color:
              Color(0xff1D4ED8),
        ),
      ),
    );
  }

  // ============================================================
  // HERO STAT
  // ============================================================

  Widget _heroStat(
    IconData icon,
    String value,
    String label,
  ) {
    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 12,
      ),
      decoration:
          BoxDecoration(
        color: Colors.white
            .withOpacity(.11),
        borderRadius:
            BorderRadius.circular(18),
        border: Border.all(
          color: Colors.white
              .withOpacity(.12),
        ),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            color: Colors.white,
            size: 19,
          ),
          const SizedBox(
            height: 5,
          ),
          Text(
            value,
            maxLines: 1,
            overflow:
                TextOverflow.ellipsis,
            textAlign:
                TextAlign.center,
            style:
                const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight:
                  FontWeight.w800,
            ),
          ),
          const SizedBox(
            height: 2,
          ),
          Text(
            label,
            style:
                const TextStyle(
              color: Colors.white60,
              fontSize: 9,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // SECTION HEADER
  // ============================================================

  Widget _sectionHeader(
    String title,
    String subtitle,
    IconData icon,
  ) {
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration:
              BoxDecoration(
            gradient:
                const LinearGradient(
              colors: [
                Color(0xffDBEAFE),
                Color(0xffEFF6FF),
              ],
            ),
            borderRadius:
                BorderRadius.circular(14),
          ),
          child: Icon(
            icon,
            color:
                const Color(0xff2563EB),
            size: 22,
          ),
        ),

        const SizedBox(
          width: 12,
        ),

        Expanded(
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style:
                    const TextStyle(
                  fontSize: 18,
                  fontWeight:
                      FontWeight.w900,
                  color:
                      Color(0xff0F172A),
                ),
              ),
              const SizedBox(
                height: 2,
              ),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color:
                      Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      ],
    ).animate().fadeIn(
          duration: 400.ms,
        );
  }

  // ============================================================
  // PROFILE CARD
  // ============================================================

  Widget _buildProfileCard() {
    return _glassCard(
      child: Column(
        children: [
          _inputField(
            nameController,
            "Full Name",
            Icons.person_rounded,
            enabled: false,
          ),

          const SizedBox(
            height: 14,
          ),

          _inputField(
            aboutController,
            "About your skills",
            Icons.description_rounded,
            maxLines: 4,
          ),
        ],
      ),
    )
        .animate()
        .fadeIn(
          delay: 100.ms,
        )
        .slideY(
          begin: .08,
          end: 0,
        );
  }

  // ============================================================
  // INPUT FIELD
  // ============================================================

  Widget _inputField(
    TextEditingController controller,
    String hint,
    IconData icon, {
    int maxLines = 1,
    bool enabled = true,
  }) {
    return TextField(
      controller: controller,
      enabled: enabled,
      maxLines: maxLines,
      style: TextStyle(
        color: enabled
            ? const Color(
                0xff0F172A,
              )
            : Colors.grey.shade600,
        fontWeight:
            FontWeight.w600,
      ),
      decoration:
          InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
          color:
              Colors.grey.shade500,
          fontSize: 13,
        ),
        prefixIcon:
            Container(
          margin:
              const EdgeInsets.all(
            10,
          ),
          decoration:
              BoxDecoration(
            color: enabled
                ? const Color(
                    0xffEFF6FF,
                  )
                : const Color(
                    0xffF1F5F9,
                  ),
            borderRadius:
                BorderRadius.circular(
              12,
            ),
          ),
          child: Icon(
            icon,
            color: enabled
                ? const Color(
                    0xff2563EB,
                  )
                : Colors.grey,
            size: 20,
          ),
        ),
        filled: true,
        fillColor: enabled
            ? const Color(
                0xffF8FAFC,
              )
            : const Color(
                0xffF1F5F9,
              ),
        contentPadding:
            const EdgeInsets.symmetric(
          horizontal: 15,
          vertical: 16,
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
        disabledBorder:
            OutlineInputBorder(
          borderRadius:
              BorderRadius.circular(
            18,
          ),
          borderSide:
              BorderSide.none,
        ),
      ),
    );
  }

  // ============================================================
  // SKILLS CARD
  // ============================================================

  Widget _buildSkillsCard() {
    return _glassCard(
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller:
                      skillController,
                  textCapitalization:
                      TextCapitalization
                          .words,
                  decoration:
                      InputDecoration(
                    hintText:
                        "Add your own skill",
                    hintStyle:
                        TextStyle(
                      color: Colors
                          .grey
                          .shade500,
                      fontSize: 13,
                    ),
                    prefixIcon:
                        const Icon(
                      Icons
                          .add_task_rounded,
                      color: Color(
                        0xff2563EB,
                      ),
                    ),
                    filled: true,
                    fillColor:
                        const Color(
                      0xffF8FAFC,
                    ),
                    border:
                        OutlineInputBorder(
                      borderRadius:
                          BorderRadius
                              .circular(
                        17,
                      ),
                      borderSide:
                          BorderSide.none,
                    ),
                  ),
                  onSubmitted: (_) {
                    _addCustomSkill();
                  },
                ),
              ),

              const SizedBox(
                width: 10,
              ),

              Material(
                color:
                    Colors.transparent,
                child: InkWell(
                  borderRadius:
                      BorderRadius.circular(
                    17,
                  ),
                  onTap:
                      _addCustomSkill,
                  child: Ink(
                    width: 52,
                    height: 52,
                    decoration:
                        BoxDecoration(
                      gradient:
                          const LinearGradient(
                        colors: [
                          Color(
                            0xff2563EB,
                          ),
                          Color(
                            0xff0284C7,
                          ),
                        ],
                      ),
                      borderRadius:
                          BorderRadius
                              .circular(
                        17,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color:
                              const Color(
                            0xff2563EB,
                          ).withOpacity(
                            .25,
                          ),
                          blurRadius: 12,
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
                      Icons.add_rounded,
                      color:
                          Colors.white,
                      size: 26,
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(
            height: 18,
          ),

          const Text(
            "Popular skills",
            style:
                TextStyle(
              fontSize: 13,
              fontWeight:
                  FontWeight.w800,
              color:
                  Color(0xff334155),
            ),
          ),

          const SizedBox(
            height: 12,
          ),

          Wrap(
            spacing: 9,
            runSpacing: 10,
            children:
                skills.map(
              (skill) {
                final bool selected =
                    selectedSkills
                        .contains(
                  skill,
                );

                return _skillChip(
                  skill,
                  selected,
                );
              },
            ).toList(),
          ),

          if (selectedSkills
              .where(
                (skill) =>
                    !skills.contains(
                  skill,
                ),
              )
              .isNotEmpty) ...[
            const SizedBox(
              height: 18,
            ),

            const Text(
              "Your added skills",
              style:
                  TextStyle(
                fontSize: 13,
                fontWeight:
                    FontWeight.w800,
                color:
                    Color(0xff334155),
              ),
            ),

            const SizedBox(
              height: 12,
            ),

            Wrap(
              spacing: 9,
              runSpacing: 10,
              children:
                  selectedSkills
                      .where(
                        (skill) =>
                            !skills
                                .contains(
                          skill,
                        ),
                      )
                      .map(
                        (skill) =>
                            _customSkillChip(
                          skill,
                        ),
                      )
                      .toList(),
            ),
          ],
        ],
      ),
    );
  }

  // ============================================================
  // SKILL CHIP
  // ============================================================

  Widget _skillChip(
    String skill,
    bool selected,
  ) {
    return GestureDetector(
      onTap: () {
        setState(() {
          if (selected) {
            selectedSkills
                .remove(skill);
          } else {
            selectedSkills.add(
              skill,
            );
          }
        });
      },
      child:
          AnimatedContainer(
        duration:
            const Duration(
          milliseconds: 220,
        ),
        padding:
            const EdgeInsets
                .symmetric(
          horizontal: 13,
          vertical: 10,
        ),
        decoration:
            BoxDecoration(
          gradient: selected
              ? const LinearGradient(
                  colors: [
                    Color(
                      0xff2563EB,
                    ),
                    Color(
                      0xff0284C7,
                    ),
                  ],
                )
              : null,
          color: selected
              ? null
              : const Color(
                  0xffF8FAFC,
                ),
          borderRadius:
              BorderRadius.circular(
            14,
          ),
          border: Border.all(
            color: selected
                ? Colors.transparent
                : const Color(
                    0xffE2E8F0,
                  ),
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color:
                        const Color(
                      0xff2563EB,
                    ).withOpacity(
                      .20,
                    ),
                    blurRadius: 10,
                    offset:
                        const Offset(
                      0,
                      5,
                    ),
                  ),
                ]
              : [],
        ),
        child: Row(
          mainAxisSize:
              MainAxisSize.min,
          children: [
            Icon(
              selected
                  ? Icons
                      .check_circle_rounded
                  : Icons
                      .add_circle_outline_rounded,
              size: 16,
              color: selected
                  ? Colors.white
                  : const Color(
                      0xff64748B,
                    ),
            ),
            const SizedBox(
              width: 6,
            ),
            Text(
              skill,
              style:
                  TextStyle(
                color: selected
                    ? Colors.white
                    : const Color(
                        0xff334155,
                      ),
                fontSize: 12,
                fontWeight:
                    FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // CUSTOM SKILL CHIP
  // ============================================================

  Widget _customSkillChip(
    String skill,
  ) {
    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 9,
      ),
      decoration:
          BoxDecoration(
        color:
            const Color(0xffEFF6FF),
        borderRadius:
            BorderRadius.circular(14),
        border: Border.all(
          color:
              const Color(0xffBFDBFE),
        ),
      ),
      child: Row(
        mainAxisSize:
            MainAxisSize.min,
        children: [
          const Icon(
            Icons
                .build_circle_rounded,
            size: 15,
            color:
                Color(0xff2563EB),
          ),
          const SizedBox(
            width: 6,
          ),
          Text(
            skill,
            style:
                const TextStyle(
              color:
                  Color(0xff1E40AF),
              fontSize: 12,
              fontWeight:
                  FontWeight.w700,
            ),
          ),
          const SizedBox(
            width: 5,
          ),
          GestureDetector(
            onTap: () {
              setState(() {
                selectedSkills
                    .remove(skill);
              });
            },
            child: const Icon(
              Icons.close_rounded,
              size: 16,
              color:
                  Color(0xff64748B),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // ADD CUSTOM SKILL
  // ============================================================

  void _addCustomSkill() {
    final String skill =
        skillController.text.trim();

    if (skill.isEmpty) return;

    final bool alreadyExists =
        selectedSkills.any(
      (item) =>
          item.toLowerCase() ==
          skill.toLowerCase(),
    );

    if (alreadyExists) {
      _showMessage(
        "This skill is already selected.",
        Colors.orange,
      );
      return;
    }

    setState(() {
      selectedSkills.add(skill);
      skillController.clear();
    });
  }

  // ============================================================
  // EXPERIENCE
  // ============================================================

  Widget _buildExperienceCard() {
    final List<String> experiences = [
      "0-1 Year",
      "1-3 Years",
      "3-5 Years",
      "5+ Years",
    ];

    return _glassCard(
      child: Wrap(
        spacing: 10,
        runSpacing: 12,
        children:
            experiences.map(
          (item) {
            final bool selected =
                experience == item;

            return GestureDetector(
              onTap: () {
                setState(() {
                  experience = item;
                });
              },
              child:
                  AnimatedContainer(
                duration:
                    const Duration(
                  milliseconds: 220,
                ),
                padding:
                    const EdgeInsets
                        .symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                decoration:
                    BoxDecoration(
                  gradient: selected
                      ? const LinearGradient(
                          colors: [
                            Color(
                              0xff2563EB,
                            ),
                            Color(
                              0xff0284C7,
                            ),
                          ],
                        )
                      : null,
                  color: selected
                      ? null
                      : const Color(
                          0xffF8FAFC,
                        ),
                  borderRadius:
                      BorderRadius
                          .circular(
                    17,
                  ),
                  border:
                      Border.all(
                    color: selected
                        ? Colors
                            .transparent
                        : const Color(
                            0xffE2E8F0,
                          ),
                  ),
                ),
                child: Row(
                  mainAxisSize:
                      MainAxisSize.min,
                  children: [
                    Icon(
                      selected
                          ? Icons
                              .check_circle_rounded
                          : Icons
                              .schedule_rounded,
                      size: 17,
                      color: selected
                          ? Colors.white
                          : const Color(
                              0xff64748B,
                            ),
                    ),
                    const SizedBox(
                      width: 7,
                    ),
                    Text(
                      item,
                      style:
                          TextStyle(
                        color: selected
                            ? Colors.white
                            : const Color(
                                0xff334155,
                              ),
                        fontSize: 12,
                        fontWeight:
                            FontWeight
                                .w800,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ).toList(),
      ),
    );
  }

  // ============================================================
  // LOCATION CARD
  // ============================================================

  Widget _buildLocationCard() {
    return GestureDetector(
      onTap: locationLoading
          ? null
          : getCurrentLocation,
      child: _glassCard(
        child: Row(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration:
                  BoxDecoration(
                gradient:
                    const LinearGradient(
                  colors: [
                    Color(0xffDBEAFE),
                    Color(0xffBAE6FD),
                  ],
                ),
                borderRadius:
                    BorderRadius
                        .circular(
                  18,
                ),
                boxShadow: [
                  BoxShadow(
                    color:
                        const Color(
                      0xff2563EB,
                    ).withOpacity(
                      .12,
                    ),
                    blurRadius: 12,
                  ),
                ],
              ),
              child: locationLoading
                  ? const Padding(
                      padding:
                          EdgeInsets.all(
                        16,
                      ),
                      child:
                          CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color:
                            Color(
                          0xff2563EB,
                        ),
                      ),
                    )
                  : const Icon(
                      Icons
                          .location_on_rounded,
                      color:
                          Color(
                        0xff2563EB,
                      ),
                      size: 28,
                    ),
            ),

            const SizedBox(
              width: 14,
            ),

            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment
                        .start,
                children: [
                  const Text(
                    "Current Location",
                    style:
                        TextStyle(
                      fontSize: 15,
                      fontWeight:
                          FontWeight
                              .w900,
                      color:
                          Color(
                        0xff0F172A,
                      ),
                    ),
                  ),

                  const SizedBox(
                    height: 5,
                  ),

                  Text(
                    locationLoading
                        ? "Detecting your current location..."
                        : currentAddress
                                .isEmpty
                            ? "Tap here to detect your location"
                            : currentAddress,
                    maxLines: 4,
                    overflow:
                        TextOverflow
                            .ellipsis,
                    style:
                        TextStyle(
                      fontSize: 12,
                      height: 1.5,
                      color: Colors
                          .grey
                          .shade600,
                    ),
                  ),

                  const SizedBox(
                    height: 10,
                  ),

                  Container(
                    padding:
                        const EdgeInsets
                            .symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration:
                        BoxDecoration(
                      color:
                          const Color(
                        0xffEFF6FF,
                      ),
                      borderRadius:
                          BorderRadius
                              .circular(
                        20,
                      ),
                    ),
                    child:
                        const Row(
                      mainAxisSize:
                          MainAxisSize
                              .min,
                      children: [
                        Icon(
                          Icons
                              .refresh_rounded,
                          size: 14,
                          color:
                              Color(
                            0xff2563EB,
                          ),
                        ),
                        SizedBox(
                          width: 5,
                        ),
                        Text(
                          "Tap to update",
                          style:
                              TextStyle(
                            color:
                                Color(
                              0xff2563EB,
                            ),
                            fontSize:
                                10,
                            fontWeight:
                                FontWeight
                                    .w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const Icon(
              Icons
                  .arrow_forward_ios_rounded,
              size: 15,
              color:
                  Color(0xff94A3B8),
            ),
          ],
        ),
      ),
    )
        .animate()
        .fadeIn(
          delay: 150.ms,
        )
        .slideX(
          begin: .06,
          end: 0,
        );
  }

  // ============================================================
  // VERIFICATION CARD
  // ============================================================

  Widget _buildVerificationCard() {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                const WorkerIdentityVerification(),
          ),
        );
      },
      child: _glassCard(
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 55,
                  height: 55,
                  decoration:
                      BoxDecoration(
                    gradient:
                        const LinearGradient(
                      colors: [
                        Color(0xffDCFCE7),
                        Color(0xffD1FAE5),
                      ],
                    ),
                    borderRadius:
                        BorderRadius
                            .circular(
                      18,
                    ),
                  ),
                  child: const Icon(
                    Icons
                        .verified_user_rounded,
                    color:
                        Color(0xff16A34A),
                    size: 28,
                  ),
                ),

                const SizedBox(
                  width: 14,
                ),

                const Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment
                            .start,
                    children: [
                      Text(
                        "Identity Verification",
                        style:
                            TextStyle(
                          fontSize:
                              16,
                          fontWeight:
                              FontWeight
                                  .w900,
                        ),
                      ),
                      SizedBox(
                        height: 4,
                      ),
                      Text(
                        "Level 1 Verification",
                        style:
                            TextStyle(
                          fontSize:
                              12,
                          color:
                              Color(
                            0xff64748B,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                Container(
                  padding:
                      const EdgeInsets
                          .all(
                    9,
                  ),
                  decoration:
                      BoxDecoration(
                    color:
                        const Color(
                      0xffF1F5F9,
                    ),
                    borderRadius:
                        BorderRadius
                            .circular(
                      12,
                    ),
                  ),
                  child:
                      const Icon(
                    Icons
                        .arrow_forward_ios_rounded,
                    size: 15,
                    color:
                        Color(
                      0xff64748B,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(
              height: 18,
            ),

            Container(
              width: double.infinity,
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
                    BorderRadius
                        .circular(
                  16,
                ),
              ),
              child:
                  const Row(
                children: [
                  Icon(
                    Icons
                        .info_outline_rounded,
                    color:
                        Color(
                      0xff2563EB,
                    ),
                    size: 18,
                  ),
                  SizedBox(
                    width: 10,
                  ),
                  Expanded(
                    child: Text(
                      "Verify your identity to build trust and confidence with customers.",
                      style:
                          TextStyle(
                        fontSize:
                            12,
                        height:
                            1.4,
                        color:
                            Color(
                          0xff475569,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(
              height: 15,
            ),

            Row(
              children: [
                Container(
                  width: 9,
                  height: 9,
                  decoration:
                      const BoxDecoration(
                    color:
                        Colors.green,
                    shape:
                        BoxShape.circle,
                  ),
                ),

                const SizedBox(
                  width: 8,
                ),

                const Text(
                  "Current Status: New Member",
                  style:
                      TextStyle(
                    fontSize: 12,
                    fontWeight:
                        FontWeight
                            .w700,
                    color:
                        Color(
                      0xff334155,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    )
        .animate()
        .fadeIn(
          delay: 200.ms,
        )
        .slideY(
          begin: .06,
          end: 0,
        );
  }

  // ============================================================
  // SUBMIT BUTTON
  // ============================================================

  Widget _buildSubmitButton() {
    return GestureDetector(
      onTap: savingProfile
          ? null
          : saveWorkerProfile,
      child:
          AnimatedContainer(
        duration:
            const Duration(
          milliseconds: 250,
        ),
        width: double.infinity,
        height: 62,
        decoration:
            BoxDecoration(
          gradient:
              const LinearGradient(
            begin:
                Alignment.centerLeft,
            end:
                Alignment.centerRight,
            colors: [
              Color(0xff1D4ED8),
              Color(0xff2563EB),
              Color(0xff0284C7),
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
                0xff2563EB,
              ).withOpacity(.35),
              blurRadius: 22,
              offset:
                  const Offset(
                0,
                10,
              ),
            ),
          ],
        ),
        child: Center(
          child: savingProfile
              ? const Row(
                  mainAxisAlignment:
                      MainAxisAlignment
                          .center,
                  children: [
                    SizedBox(
                      width: 22,
                      height: 22,
                      child:
                          CircularProgressIndicator(
                        strokeWidth:
                            2.5,
                        color:
                            Colors.white,
                      ),
                    ),
                    SizedBox(
                      width: 12,
                    ),
                    Text(
                      "Creating Profile...",
                      style:
                          TextStyle(
                        color:
                            Colors.white,
                        fontSize: 16,
                        fontWeight:
                            FontWeight
                                .w800,
                      ),
                    ),
                  ],
                )
              : const Row(
                  mainAxisAlignment:
                      MainAxisAlignment
                          .center,
                  children: [
                    Icon(
                      Icons
                          .rocket_launch_rounded,
                      color:
                          Colors.white,
                      size: 22,
                    ),
                    SizedBox(
                      width: 10,
                    ),
                    Text(
                      "Create Worker Profile",
                      style:
                          TextStyle(
                        color:
                            Colors.white,
                        fontSize: 16,
                        fontWeight:
                            FontWeight
                                .w900,
                      ),
                    ),
                    SizedBox(
                      width: 8,
                    ),
                    Icon(
                      Icons
                          .arrow_forward_rounded,
                      color:
                          Colors.white,
                      size: 20,
                    ),
                  ],
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
        .shimmer(
          duration: 2200.ms,
          delay: 1200.ms,
        );
  }

  // ============================================================
  // GLASS CARD
  // ============================================================

  Widget _glassCard({
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.all(18),
      decoration:
          BoxDecoration(
        color: Colors.white
            .withOpacity(.96),
        borderRadius:
            BorderRadius.circular(
          24,
        ),
        border: Border.all(
          color: Colors.white,
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black
                .withOpacity(.055),
            blurRadius: 24,
            offset:
                const Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );
  }

  // ============================================================
  // LOGOUT DIALOG
  // ============================================================

  void _showLogoutDialog() {
    showDialog(
      context: context,
      barrierColor:
          Colors.black.withOpacity(.55),
      builder: (context) {
        return Dialog(
          backgroundColor:
              Colors.transparent,
          insetPadding:
              const EdgeInsets
                  .symmetric(
            horizontal: 25,
          ),
          child: Container(
            padding:
                const EdgeInsets.all(
              24,
            ),
            decoration:
                BoxDecoration(
              color: Colors.white,
              borderRadius:
                  BorderRadius.circular(
                28,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black
                      .withOpacity(.20),
                  blurRadius: 30,
                  offset:
                      const Offset(
                    0,
                    15,
                  ),
                ),
              ],
            ),
            child: Column(
              mainAxisSize:
                  MainAxisSize.min,
              children: [
                Container(
                  width: 65,
                  height: 65,
                  decoration:
                      const BoxDecoration(
                    color:
                        Color(0xffFEE2E2),
                    shape:
                        BoxShape.circle,
                  ),
                  child:
                      const Icon(
                    Icons
                        .logout_rounded,
                    color:
                        Color(0xffDC2626),
                    size: 30,
                  ),
                ),

                const SizedBox(
                  height: 18,
                ),

                const Text(
                  "Logout?",
                  style:
                      TextStyle(
                    fontSize: 22,
                    fontWeight:
                        FontWeight
                            .w900,
                  ),
                ),

                const SizedBox(
                  height: 8,
                ),

                const Text(
                  "Are you sure you want to logout from your Servora worker account?",
                  textAlign:
                      TextAlign.center,
                  style:
                      TextStyle(
                    color:
                        Color(0xff64748B),
                    height: 1.5,
                    fontSize: 13,
                  ),
                ),

                const SizedBox(
                  height: 22,
                ),

                Row(
                  children: [
                    Expanded(
                      child:
                          OutlinedButton(
                        style:
                            OutlinedButton
                                .styleFrom(
                          minimumSize:
                              const Size(
                            0,
                            48,
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

                    const SizedBox(
                      width: 12,
                    ),

                    Expanded(
                      child:
                          ElevatedButton(
                        style:
                            ElevatedButton
                                .styleFrom(
                          backgroundColor:
                              const Color(
                            0xffDC2626,
                          ),
                          minimumSize:
                              const Size(
                            0,
                            48,
                          ),
                          elevation: 0,
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
                          Navigator.pop(
                            context,
                          );

                          logout();
                        },
                        child:
                            const Text(
                          "Logout",
                          style:
                              TextStyle(
                            color:
                                Colors.white,
                            fontWeight:
                                FontWeight
                                    .w800,
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
}
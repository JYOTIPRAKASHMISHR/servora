import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

import 'package:servora/screens/customer/customer_applications_screen.dart';
import 'package:servora/screens/customer/customer_history_screen.dart';
import 'package:servora/screens/customer/customer_profile_screen.dart';
import 'package:servora/screens/customer/customer_requests_screen.dart';
import 'package:servora/screens/customer/customer_service_tracking_screen.dart';
import 'package:servora/screens/notification_screen.dart';

import 'urgent_help_screen.dart';
import '../appartment/my_apartment_screen.dart';
import 'create_service_screen.dart';

// ================================================================
// SERVICE CATEGORY MODEL
// ================================================================

class ServiceCategory {
  final String name;
  final IconData icon;

  const ServiceCategory({
    required this.name,
    required this.icon,
  });
}

// ================================================================
// CUSTOMER HOME
// ================================================================

class CustomerHome extends StatefulWidget {
  const CustomerHome({super.key});

  @override
  State<CustomerHome> createState() => _CustomerHomeState();
}

// ================================================================
// STATE
// ================================================================

class _CustomerHomeState extends State<CustomerHome> {
  int _selectedIndex = 0;

  List<Map> myServices = [];

  StreamSubscription? serviceSubscription;

  // ==============================================================
  // COLORS
  // ==============================================================

  static const Color primaryColor =
      Color(0xff2563EB);

  static const Color secondaryColor =
      Color(0xff38BDF8);

  static const Color backgroundColor =
      Color(0xffF5F7FB);

  static const Color darkColor =
      Color(0xff0F172A);

  static const Color textColor =
      Color(0xff111827);

  static const Color mutedTextColor =
      Color(0xff64748B);

  static const Color iconBackground =
      Color(0xffDBEAFE);

  // ==============================================================
  // SERVICES
  // ==============================================================

  static const List<ServiceCategory> services = [
    ServiceCategory(
      name: "Home Cleaning",
      icon: Icons.cleaning_services_rounded,
    ),
    ServiceCategory(
      name: "Electrical Work",
      icon: Icons.electrical_services_rounded,
    ),
    ServiceCategory(
      name: "Plumbing",
      icon: Icons.plumbing_rounded,
    ),
    ServiceCategory(
      name: "Gardening",
      icon: Icons.grass_rounded,
    ),
    ServiceCategory(
      name: "Appliance Repair",
      icon: Icons.home_repair_service_rounded,
    ),
    ServiceCategory(
      name: "Babysitting",
      icon: Icons.child_care_rounded,
    ),
    ServiceCategory(
      name: "Elder Care",
      icon: Icons.elderly_rounded,
    ),
    ServiceCategory(
      name: "Tutors",
      icon: Icons.school_rounded,
    ),
    ServiceCategory(
      name: "Moving Service",
      icon: Icons.local_shipping_rounded,
    ),
    ServiceCategory(
      name: "Local Skilled Jobs",
      icon: Icons.handyman_rounded,
    ),
    ServiceCategory(
      name: "Painting",
      icon: Icons.format_paint_rounded,
    ),
    ServiceCategory(
      name: "Car Repair",
      icon: Icons.car_repair_rounded,
    ),
  ];

  // ==============================================================
  // INIT
  // ==============================================================

  @override
  void initState() {
    super.initState();

    fetchMyServices();
  }

  // ==============================================================
  // FETCH SERVICES
  // ==============================================================

  void fetchMyServices() {
    final User? user =
        FirebaseAuth.instance.currentUser;

    if (user == null) {
      return;
    }

    final String uid = user.uid;

    serviceSubscription = FirebaseDatabase
        .instance
        .ref("services")
        .onValue
        .listen((event) {
      if (!mounted) {
        return;
      }

      if (!event.snapshot.exists ||
          event.snapshot.value == null) {
        setState(() {
          myServices = [];
        });

        return;
      }

      final Map data =
          Map.from(event.snapshot.value as Map);

      final List<Map> temp = [];

      data.forEach((key, value) {
        if (value is! Map) {
          return;
        }

        final Map service =
            Map.from(value);

        if (service["customerId"] == uid) {
          temp.add({
            "serviceId": key,
            ...service,
          });
        }
      });

      temp.sort((a, b) {
        return b["createdAt"]
            .toString()
            .compareTo(
              a["createdAt"].toString(),
            );
      });

      setState(() {
        myServices = temp;
      });
    });
  }

  // ==============================================================
  // DISPOSE
  // ==============================================================

  @override
  void dispose() {
    serviceSubscription?.cancel();

    super.dispose();
  }

  // ==============================================================
  // BUILD
  // ==============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,

      body: SafeArea(
        child: Column(
          children: [
            buildHeader(),

            Expanded(
              child: buildBody(),
            ),
          ],
        ),
      ),

      bottomNavigationBar:
          _buildBottomBar(),
    );
  }

  // ==============================================================
  // HEADER
  // ==============================================================

  Widget buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        20,
        15,
        20,
        10,
      ),

      child: Row(
        children: [
          // ========================================================
          // SERVORA LOGO AREA
          // ========================================================

          Container(
            height: 54,
            width: 54,

            decoration: BoxDecoration(
              gradient:
                  const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  primaryColor,
                  secondaryColor,
                ],
              ),

              borderRadius:
                  BorderRadius.circular(18),

              boxShadow: [
                BoxShadow(
                  color: primaryColor
                      .withOpacity(0.25),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),

            child: const Center(
              child: Text(
                "S",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 30,
                  fontWeight:
                      FontWeight.w900,
                ),
              ),
            ),
          ),

          const SizedBox(
            width: 13,
          ),

          // ========================================================
          // GREETING
          // ========================================================

          const Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  "Hello Customer 👋",
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight:
                        FontWeight.w800,
                    color: textColor,
                  ),
                ),

                SizedBox(
                  height: 4,
                ),

                Text(
                  "What service do you need today?",
                  style: TextStyle(
                    fontSize: 12,
                    color:
                        mutedTextColor,
                    fontWeight:
                        FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

          // ========================================================
          // NOTIFICATION
          // ========================================================

          _AnimatedIconButton(
            icon: Icons.notifications_none_rounded,

            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      const NotificationScreen(),
                ),
              );
            },
          ),
        ],
      ),
    )
        .animateEntrance(
          delay: 50,
        );
  }

  // ==============================================================
  // BODY
  // ==============================================================

  Widget buildBody() {
    return SingleChildScrollView(
      physics:
          const BouncingScrollPhysics(),

      padding:
          const EdgeInsets.fromLTRB(
        20,
        8,
        20,
        30,
      ),

      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,

        children: [

          // ========================================================
          // 1. URGENT HELP
          // ========================================================

          buildEmergencyCard(),

          const SizedBox(
            height: 18,
          ),

          // ========================================================
          // 2. MY APARTMENT
          // ========================================================

          _buildMyApartmentCard(),

          const SizedBox(
            height: 18,
          ),

          // ========================================================
          // 3. CREATE SERVICE
          // ========================================================

          buildCreateServiceCard(),

          const SizedBox(
            height: 20,
          ),

          // ========================================================
          // 4. SEARCH
          // ========================================================

          buildSearch(),

          const SizedBox(
            height: 26,
          ),

          // ========================================================
          // 5. CATEGORIES
          // ========================================================

          _buildSectionHeader(
            title: "Service Categories",
            subtitle:
                "Choose a service you need",
          ),

          const SizedBox(
            height: 14,
          ),

          buildServiceGrid(),

          const SizedBox(
            height: 28,
          ),

          // ========================================================
          // 6. YOUR SERVICE REQUESTS
          // ========================================================

          _buildSectionHeader(
            title: "Your Service Requests",
            subtitle:
                "Track your ongoing services",
          ),

          const SizedBox(
            height: 14,
          ),

          _buildApplicationCard(),

          const SizedBox(
            height: 25,
          ),

          // ========================================================
          // 7. CUSTOM REQUEST
          // ========================================================

          _buildCustomRequestCard(),

          const SizedBox(
            height: 10,
          ),
        ],
      ),
    );
  }

  // ==============================================================
  // SECTION HEADER
  // ==============================================================

  Widget _buildSectionHeader({
    required String title,
    required String subtitle,
  }) {
    return Row(
      crossAxisAlignment:
          CrossAxisAlignment.end,

      children: [
        Expanded(
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,

            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight:
                      FontWeight.w800,
                  color: textColor,
                ),
              ),

              const SizedBox(
                height: 3,
              ),

              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 12,
                  color:
                      mutedTextColor,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ==============================================================
  // EMERGENCY CARD
  // ==============================================================

  Widget buildEmergencyCard() {
    return _AnimatedPressCard(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                const UrgentHelpScreen(),
          ),
        );
      },

      child: Container(
        width: double.infinity,

        padding:
            const EdgeInsets.all(18),

        decoration: BoxDecoration(
          gradient:
              const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xffDC2626),
              Color(0xffEF4444),
              Color(0xffF87171),
            ],
          ),

          borderRadius:
              BorderRadius.circular(25),

          boxShadow: [
            BoxShadow(
              color: const Color(0xffEF4444)
                  .withOpacity(0.25),
              blurRadius: 18,
              offset: const Offset(0, 9),
            ),
          ],
        ),

        child: Stack(
          children: [
            // ======================================================
            // DECORATIVE CIRCLE
            // ======================================================

            Positioned(
              right: -25,
              top: -30,

              child: Container(
                height: 120,
                width: 120,

                decoration:
                    BoxDecoration(
                  shape:
                      BoxShape.circle,
                  color: Colors.white
                      .withOpacity(0.08),
                ),
              ),
            ),

            Row(
              children: [

                // ==================================================
                // ICON
                // ==================================================

                Container(
                  height: 58,
                  width: 58,

                  decoration:
                      BoxDecoration(
                    color: Colors.white
                        .withOpacity(0.18),

                    borderRadius:
                        BorderRadius.circular(19),

                    border: Border.all(
                      color: Colors.white
                          .withOpacity(0.25),
                    ),
                  ),

                  child: const Icon(
                    Icons
                        .emergency_rounded,
                    color: Colors.white,
                    size: 31,
                  ),
                ),

                const SizedBox(
                  width: 14,
                ),

                // ==================================================
                // TEXT
                // ==================================================

                const Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,

                    children: [
                      Text(
                        "Emergency Help",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight:
                              FontWeight.w900,
                        ),
                      ),

                      SizedBox(
                        height: 5,
                      ),

                      Text(
                        "Need urgent assistance?",
                        style: TextStyle(
                          color:
                              Colors.white70,
                          fontSize: 12,
                          fontWeight:
                              FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),

                // ==================================================
                // HELP BUTTON
                // ==================================================

                Container(
                  padding:
                      const EdgeInsets.symmetric(
                    horizontal: 13,
                    vertical: 10,
                  ),

                  decoration:
                      BoxDecoration(
                    color: Colors.white,
                    borderRadius:
                        BorderRadius.circular(14),

                    boxShadow: [
                      BoxShadow(
                        color: Colors.black
                            .withOpacity(0.12),
                        blurRadius: 8,
                        offset:
                            const Offset(0, 4),
                      ),
                    ],
                  ),

                  child: const Row(
                    children: [
                      Icon(
                        Icons
                            .arrow_forward_rounded,
                        color:
                            Color(0xffDC2626),
                        size: 17,
                      ),

                      SizedBox(
                        width: 5,
                      ),

                      Text(
                        "HELP",
                        style: TextStyle(
                          color:
                              Color(0xffDC2626),
                          fontSize: 11,
                          fontWeight:
                              FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ).animateEntrance();
  }

  // ==============================================================
  // MY APARTMENT
  // ==============================================================

  Widget _buildMyApartmentCard() {
    return _AnimatedPressCard(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                const MyApartmentScreen(),
          ),
        );
      },

      child: Container(
        width: double.infinity,

        padding:
            const EdgeInsets.all(18),

        decoration: BoxDecoration(
          gradient:
              const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xff1D4ED8),
              Color(0xff2563EB),
              Color(0xff0EA5E9),
            ],
          ),

          borderRadius:
              BorderRadius.circular(25),

          boxShadow: [
            BoxShadow(
              color: primaryColor
                  .withOpacity(0.22),
              blurRadius: 18,
              offset:
                  const Offset(0, 8),
            ),
          ],
        ),

        child: Column(
          children: [

            Row(
              children: [

                // ==================================================
                // APARTMENT ICON
                // ==================================================

                Container(
                  height: 56,
                  width: 56,

                  decoration:
                      BoxDecoration(
                    color: Colors.white
                        .withOpacity(0.17),
                    borderRadius:
                        BorderRadius.circular(18),
                    border: Border.all(
                      color: Colors.white
                          .withOpacity(0.18),
                    ),
                  ),

                  child: const Icon(
                    Icons.apartment_rounded,
                    color: Colors.white,
                    size: 30,
                  ),
                ),

                const SizedBox(
                  width: 13,
                ),

                // ==================================================
                // TEXT
                // ==================================================

                const Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,

                    children: [
                      Text(
                        "My Apartment",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight:
                              FontWeight.w900,
                        ),
                      ),

                      SizedBox(
                        height: 4,
                      ),

                      Text(
                        "Save more with society services",
                        style: TextStyle(
                          color:
                              Colors.white70,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),

                const Icon(
                  Icons
                      .arrow_forward_ios_rounded,
                  color: Colors.white,
                  size: 17,
                ),
              ],
            ),

            const SizedBox(
              height: 15,
            ),

            // ======================================================
            // INFO
            // ======================================================

            Container(
              padding:
                  const EdgeInsets.all(12),

              decoration:
                  BoxDecoration(
                color: Colors.white
                    .withOpacity(0.11),

                borderRadius:
                    BorderRadius.circular(15),
              ),

              child: const Row(
                children: [

                  Icon(
                    Icons.groups_rounded,
                    color: Colors.white,
                    size: 21,
                  ),

                  SizedBox(
                    width: 9,
                  ),

                  Expanded(
                    child: Text(
                      "Join your neighbours and unlock lower service prices.",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        height: 1.3,
                        fontWeight:
                            FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(
              height: 12,
            ),

            Row(
              children: [
                _buildApartmentMiniInfo(
                  Icons.home_work_outlined,
                  "My Flat",
                ),

                const SizedBox(
                  width: 8,
                ),

                _buildApartmentMiniInfo(
                  Icons.local_offer_outlined,
                  "Group Deals",
                ),

                const SizedBox(
                  width: 8,
                ),

                _buildApartmentMiniInfo(
                  Icons.calendar_month_rounded,
                  "Slots",
                ),
              ],
            ),
          ],
        ),
      ),
    ).animateEntrance(
      delay: 100,
    );
  }

  // ==============================================================
  // APARTMENT MINI INFO
  // ==============================================================

  Widget _buildApartmentMiniInfo(
    IconData icon,
    String title,
  ) {
    return Expanded(
      child: Container(
        padding:
            const EdgeInsets.symmetric(
          vertical: 9,
          horizontal: 4,
        ),

        decoration:
            BoxDecoration(
          color: Colors.white
              .withOpacity(0.11),

          borderRadius:
              BorderRadius.circular(12),
        ),

        child: Column(
          children: [

            Icon(
              icon,
              color: Colors.white,
              size: 19,
            ),

            const SizedBox(
              height: 4,
            ),

            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 9,
                fontWeight:
                    FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==============================================================
  // CREATE SERVICE CARD
  // ==============================================================

  Widget buildCreateServiceCard() {
    return _AnimatedPressCard(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                const CreateServiceScreen(
              serviceName: null,
              isCustom: true,
            ),
          ),
        );
      },

      child: Container(
        width: double.infinity,

        padding:
            const EdgeInsets.all(18),

        decoration: BoxDecoration(
          color: Colors.white,

          borderRadius:
              BorderRadius.circular(23),

          border: Border.all(
            color: const Color(0xffE2E8F0),
          ),

          boxShadow: [
            BoxShadow(
              color: Colors.black
                  .withOpacity(0.05),
              blurRadius: 14,
              offset:
                  const Offset(0, 6),
            ),
          ],
        ),

        child: Row(
          children: [

            Container(
              height: 54,
              width: 54,

              decoration:
                  BoxDecoration(
                gradient:
                    const LinearGradient(
                  colors: [
                    primaryColor,
                    secondaryColor,
                  ],
                ),

                borderRadius:
                    BorderRadius.circular(17),

                boxShadow: [
                  BoxShadow(
                    color: primaryColor
                        .withOpacity(0.20),
                    blurRadius: 10,
                    offset:
                        const Offset(0, 5),
                  ),
                ],
              ),

              child: const Icon(
                Icons.add_rounded,
                color: Colors.white,
                size: 29,
              ),
            ),

            const SizedBox(
              width: 13,
            ),

            const Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,

                children: [
                  Text(
                    "Need Any Service?",
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight:
                          FontWeight.w800,
                      color: textColor,
                    ),
                  ),

                  SizedBox(
                    height: 4,
                  ),

                  Text(
                    "Create your own service request",
                    style: TextStyle(
                      fontSize: 11,
                      color:
                          mutedTextColor,
                    ),
                  ),
                ],
              ),
            ),

            Container(
              height: 38,
              width: 38,

              decoration:
                  BoxDecoration(
                color:
                    iconBackground,
                borderRadius:
                    BorderRadius.circular(12),
              ),

              child: const Icon(
                Icons.arrow_forward_rounded,
                color: primaryColor,
                size: 19,
              ),
            ),
          ],
        ),
      ),
    ).animateEntrance(
      delay: 150,
    );
  }

  // ==============================================================
  // SEARCH
  // ==============================================================

  Widget buildSearch() {
    return Container(
      height: 56,

      padding:
          const EdgeInsets.symmetric(
        horizontal: 16,
      ),

      decoration: BoxDecoration(
        color: Colors.white,

        borderRadius:
            BorderRadius.circular(18),

        border: Border.all(
          color: const Color(0xffE2E8F0),
        ),

        boxShadow: [
          BoxShadow(
            color: Colors.black
                .withOpacity(0.045),
            blurRadius: 12,
            offset:
                const Offset(0, 5),
          ),
        ],
      ),

      child: Row(
        children: [

          Container(
            height: 35,
            width: 35,

            decoration:
                BoxDecoration(
              color: iconBackground,
              borderRadius:
                  BorderRadius.circular(11),
            ),

            child: const Icon(
              Icons.search_rounded,
              color: primaryColor,
              size: 19,
            ),
          ),

          const SizedBox(
            width: 11,
          ),

          const Expanded(
            child: Text(
              "Search service...",
              style: TextStyle(
                color: mutedTextColor,
                fontSize: 13,
                fontWeight:
                    FontWeight.w500,
              ),
            ),
          ),

          const Icon(
            Icons.tune_rounded,
            color: mutedTextColor,
            size: 20,
          ),
        ],
      ),
    ).animateEntrance(
      delay: 200,
    );
  }

  // ==============================================================
  // SERVICE GRID
  // ==============================================================

  Widget buildServiceGrid() {
    return GridView.builder(
      shrinkWrap: true,

      physics:
          const NeverScrollableScrollPhysics(),

      gridDelegate:
          const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        childAspectRatio: 0.73,
        crossAxisSpacing: 10,
        mainAxisSpacing: 12,
      ),

      itemCount:
          services.length,

      itemBuilder:
          (context, index) {
        final service =
            services[index];

        return _AnimatedPressCard(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    CreateServiceScreen(
                  serviceName:
                      service.name,
                  isCustom: false,
                ),
              ),
            );
          },

          child: Container(
            decoration:
                BoxDecoration(
              color: Colors.white,

              borderRadius:
                  BorderRadius.circular(18),

              border: Border.all(
                color:
                    const Color(0xffE8EDF5),
              ),

              boxShadow: [
                BoxShadow(
                  color: Colors.black
                      .withOpacity(0.045),
                  blurRadius: 9,
                  offset:
                      const Offset(0, 4),
                ),
              ],
            ),

            child: Column(
              mainAxisAlignment:
                  MainAxisAlignment.center,

              children: [

                // ==================================================
                // ICON
                // ==================================================

                Container(
                  height: 47,
                  width: 47,

                  decoration:
                      BoxDecoration(
                    gradient:
                        const LinearGradient(
                      begin:
                          Alignment.topLeft,
                      end:
                          Alignment.bottomRight,
                      colors: [
                        Color(0xffEFF6FF),
                        Color(0xffDBEAFE),
                      ],
                    ),

                    shape:
                        BoxShape.circle,

                    boxShadow: [
                      BoxShadow(
                        color: primaryColor
                            .withOpacity(
                                0.08),
                        blurRadius: 7,
                        offset:
                            const Offset(0, 3),
                      ),
                    ],
                  ),

                  child: Icon(
                    service.icon,
                    color:
                        primaryColor,
                    size: 21,
                  ),
                ),

                const SizedBox(
                  height: 8,
                ),

                Padding(
                  padding:
                      const EdgeInsets
                          .symmetric(
                    horizontal: 3,
                  ),

                  child: Text(
                    service.name,

                    textAlign:
                        TextAlign.center,

                    maxLines: 2,

                    overflow:
                        TextOverflow.ellipsis,

                    style:
                        const TextStyle(
                      fontSize: 10,
                      height: 1.15,
                      fontWeight:
                          FontWeight.w700,
                      color:
                          textColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
        )
            .animateEntrance(
              delay:
                  250 + (index * 35),
            );
      },
    );
  }

  // ==============================================================
  // APPLICATION CARD
  // ==============================================================

  Widget _buildApplicationCard() {
    if (myServices.isEmpty) {
      return _buildEmptyRequestsCard();
    }

    return Column(
      children:
          myServices.map((service) {
        final String status =
            service["status"] ??
                "pending";

        return _buildServiceRequestCard(
          service,
          status,
        );
      }).toList(),
    );
  }

  // ==============================================================
  // SERVICE REQUEST CARD
  // ==============================================================

  Widget _buildServiceRequestCard(
    Map service,
    String status,
  ) {
    return _AnimatedPressCard(
      onTap: () {
        final String serviceId =
            service["serviceId"]
                .toString();

        if (status == "pending") {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  CustomerApplicationsScreen(
                serviceId: serviceId,
              ),
            ),
          );
        } else if (
            status == "assigned" ||
            status == "started") {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  CustomerServiceTrackingScreen(
                serviceId: serviceId,
              ),
            ),
          );
        }
      },

      child: Container(
        margin:
            const EdgeInsets.only(
          bottom: 13,
        ),

        padding:
            const EdgeInsets.all(15),

        decoration: BoxDecoration(
          color: Colors.white,

          borderRadius:
              BorderRadius.circular(21),

          border: Border.all(
            color:
                const Color(0xffE5EAF2),
          ),

          boxShadow: [
            BoxShadow(
              color: Colors.black
                  .withOpacity(0.05),
              blurRadius: 12,
              offset:
                  const Offset(0, 5),
            ),
          ],
        ),

        child: Row(
          children: [

            // ======================================================
            // SERVICE ICON
            // ======================================================

            Container(
              height: 55,
              width: 55,

              decoration:
                  BoxDecoration(
                color:
                    iconBackground,
                borderRadius:
                    BorderRadius.circular(17),
              ),

              child: Icon(
                _getServiceIcon(
                  service,
                ),
                color:
                    primaryColor,
                size: 26,
              ),
            ),

            const SizedBox(
              width: 13,
            ),

            // ======================================================
            // INFORMATION
            // ======================================================

            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,

                children: [

                  Text(
                    service["title"] ??
                        service[
                            "serviceName"] ??
                        "Service",

                    maxLines: 1,

                    overflow:
                        TextOverflow.ellipsis,

                    style:
                        const TextStyle(
                      fontSize: 15,
                      fontWeight:
                          FontWeight.w800,
                      color:
                          textColor,
                    ),
                  ),

                  const SizedBox(
                    height: 6,
                  ),

                  Container(
                    padding:
                        const EdgeInsets
                            .symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),

                    decoration:
                        BoxDecoration(
                      color:
                          _statusColor(
                        status,
                      ).withOpacity(
                        0.10,
                      ),

                      borderRadius:
                          BorderRadius.circular(
                        10,
                      ),
                    ),

                    child: Text(
                      _getServiceStatus(
                        service,
                      ),

                      style: TextStyle(
                        color:
                            _statusColor(
                          status,
                        ),

                        fontSize: 10,

                        fontWeight:
                            FontWeight.w800,
                      ),
                    ),
                  ),

                  const SizedBox(
                    height: 6,
                  ),

                  if (status ==
                      "assigned")
                    _buildAssignedWorker(
                      service,
                    ),
                ],
              ),
            ),

            const SizedBox(
              width: 5,
            ),

            // ======================================================
            // ARROW
            // ======================================================

            Container(
              height: 35,
              width: 35,

              decoration:
                  BoxDecoration(
                color:
                    const Color(0xffF1F5F9),
                borderRadius:
                    BorderRadius.circular(11),
              ),

              child: const Icon(
                Icons
                    .arrow_forward_ios_rounded,
                size: 14,
                color:
                    mutedTextColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==============================================================
  // EMPTY REQUEST
  // ==============================================================

  Widget _buildEmptyRequestsCard() {
    return Container(
      width: double.infinity,

      padding:
          const EdgeInsets.all(25),

      decoration: BoxDecoration(
        color: Colors.white,

        borderRadius:
            BorderRadius.circular(22),

        border: Border.all(
          color:
              const Color(0xffE5EAF2),
        ),
      ),

      child: Column(
        children: [

          Container(
            height: 60,
            width: 60,

            decoration:
                const BoxDecoration(
              color: iconBackground,
              shape:
                  BoxShape.circle,
            ),

            child: const Icon(
              Icons.assignment_outlined,
              color: primaryColor,
              size: 29,
            ),
          ),

          const SizedBox(
            height: 12,
          ),

          const Text(
            "No service requests yet",
            style: TextStyle(
              fontSize: 15,
              fontWeight:
                  FontWeight.w800,
              color: textColor,
            ),
          ),

          const SizedBox(
            height: 5,
          ),

          const Text(
            "Create a request and find the right worker.",
            textAlign:
                TextAlign.center,
            style: TextStyle(
              color:
                  mutedTextColor,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  // ==============================================================
  // STATUS COLOR
  // ==============================================================

  Color _statusColor(
    String status,
  ) {
    switch (status) {
      case "assigned":
      case "started":
        return const Color(
          0xff16A34A,
        );

      case "completed":
        return const Color(
          0xff2563EB,
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

  // ==============================================================
  // STATUS TEXT
  // ==============================================================

  String _getServiceStatus(
    Map service,
  ) {
    final String status =
        service["status"] ??
            "pending";

    switch (status) {
      case "assigned":
        return "✓ Worker Assigned";

      case "started":
        return "🚀 Worker Started";

      case "completed":
        return "✓ Service Completed";

      case "cancelled":
        return "✕ Service Cancelled";

      case "pending":
        return "⏳ Waiting for worker";

      default:
        return "⏳ Waiting for worker";
    }
  }

  // ==============================================================
  // SERVICE ICON
  // ==============================================================

  IconData _getServiceIcon(
    Map service,
  ) {
    if (service["status"] ==
        "assigned") {
      return Icons.person_rounded;
    }

    if (service["status"] ==
        "completed") {
      return Icons.check_circle_rounded;
    }

    return Icons.handyman_rounded;
  }

  // ==============================================================
  // ASSIGNED WORKER
  // ==============================================================

  Widget _buildAssignedWorker(
    Map service,
  ) {
    final String? workerId =
        service["assignedWorkerId"]
            ?.toString();

    if (workerId == null ||
        workerId.isEmpty) {
      return const SizedBox();
    }

    return FutureBuilder<
        DataSnapshot>(
      future: FirebaseDatabase
          .instance
          .ref("users")
          .child(workerId)
          .get(),

      builder:
          (context, snapshot) {
        if (!snapshot.hasData ||
            snapshot.data!.value ==
                null) {
          return const SizedBox();
        }

        final Map worker =
            Map.from(
          snapshot.data!.value
              as Map,
        );

        return Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,

          children: [

            Text(
              "👤 ${worker["name"] ?? "Worker"}",

              style:
                  const TextStyle(
                color:
                    Color(0xff16A34A),
                fontSize: 11,
                fontWeight:
                    FontWeight.w700,
              ),
            ),

            const SizedBox(
              height: 2,
            ),

            Text(
              "₹${service["finalPrice"] ?? service["budget"]}",

              style:
                  const TextStyle(
                color:
                    mutedTextColor,
                fontSize: 10,
                fontWeight:
                    FontWeight.w600,
              ),
            ),
          ],
        );
      },
    );
  }

  // ==============================================================
  // CUSTOM REQUEST
  // ==============================================================

  Widget _buildCustomRequestCard() {
    return _AnimatedPressCard(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                const CreateServiceScreen(
              serviceName: "",
            ),
          ),
        );
      },

      child: Container(
        width: double.infinity,

        padding:
            const EdgeInsets.all(19),

        decoration: BoxDecoration(
          gradient:
              const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xff0F172A),
              Color(0xff1E3A8A),
              Color(0xff172554),
            ],
          ),

          borderRadius:
              BorderRadius.circular(24),

          boxShadow: [
            BoxShadow(
              color: const Color(
                0xff0F172A,
              ).withOpacity(0.20),

              blurRadius: 16,

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
                  height: 48,
                  width: 48,

                  decoration:
                      BoxDecoration(
                    color: Colors.white
                        .withOpacity(0.12),
                    borderRadius:
                        BorderRadius.circular(15),
                  ),

                  child: const Icon(
                    Icons
                        .auto_awesome_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                ),

                const SizedBox(
                  width: 12,
                ),

                const Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,

                    children: [
                      Text(
                        "Can't find your service?",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight:
                              FontWeight.w900,
                        ),
                      ),

                      SizedBox(
                        height: 3,
                      ),

                      Text(
                        "Tell us what you need.",
                        style: TextStyle(
                          color:
                              Colors.white60,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(
              height: 15,
            ),

            SizedBox(
              width: double.infinity,
              height: 48,

              child: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder:
                          (context) =>
                              const CreateServiceScreen(
                        serviceName: "",
                      ),
                    ),
                  );
                },

                style:
                    ElevatedButton.styleFrom(
                  backgroundColor:
                      Colors.white,

                  foregroundColor:
                      primaryColor,

                  elevation: 5,

                  shadowColor:
                      Colors.black
                          .withOpacity(
                    0.25,
                  ),

                  shape:
                      RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(
                      15,
                    ),
                  ),
                ),

                child: const Row(
                  mainAxisAlignment:
                      MainAxisAlignment.center,

                  children: [

                    Icon(
                      Icons.add_rounded,
                      size: 19,
                    ),

                    SizedBox(
                      width: 6,
                    ),

                    Text(
                      "Create Custom Request",
                      style: TextStyle(
                        fontWeight:
                            FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ).animateEntrance(
      delay: 350,
    );
  }

  // ==============================================================
  // BOTTOM NAVIGATION
  // ==============================================================

  Widget _buildBottomBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,

        boxShadow: [
          BoxShadow(
            color: Colors.black
                .withOpacity(0.08),
            blurRadius: 18,
            offset:
                const Offset(0, -5),
          ),
        ],
      ),

      child: BottomNavigationBar(
        currentIndex:
            _selectedIndex,

        backgroundColor:
            Colors.white,

        selectedItemColor:
            primaryColor,

        unselectedItemColor:
            const Color(0xff94A3B8),

        selectedLabelStyle:
            const TextStyle(
          fontWeight:
              FontWeight.w700,
          fontSize: 11,
        ),

        unselectedLabelStyle:
            const TextStyle(
          fontSize: 10,
        ),

        type:
            BottomNavigationBarType
                .fixed,

        elevation: 0,

        onTap: (index) {
          if (index == 2) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    const CustomerHistoryScreen(),
              ),
            );

            return;
          }

          if (index == 1) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    const CustomerRequestsScreen(),
              ),
            );

            return;
          }

          if (index == 3) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    const CustomerProfileScreen(),
              ),
            );

            return;
          }

          setState(() {
            _selectedIndex =
                index;
          });
        },

        items: const [
          BottomNavigationBarItem(
            icon: Icon(
              Icons.home_outlined,
            ),
            activeIcon: Icon(
              Icons.home_rounded,
            ),
            label: "Home",
          ),

          BottomNavigationBarItem(
            icon: Icon(
              Icons.calendar_month_outlined,
            ),
            activeIcon: Icon(
              Icons.calendar_month_rounded,
            ),
            label: "Requests",
          ),

          BottomNavigationBarItem(
            icon: Icon(
              Icons.history_outlined,
            ),
            activeIcon: Icon(
              Icons.history_rounded,
            ),
            label: "History",
          ),

          BottomNavigationBarItem(
            icon: Icon(
              Icons.person_outline_rounded,
            ),
            activeIcon: Icon(
              Icons.person_rounded,
            ),
            label: "Profile",
          ),
        ],
      ),
    );
  }
}


// ==================================================================
// ANIMATED PRESS CARD
// ==================================================================

class _AnimatedPressCard
    extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;

  const _AnimatedPressCard({
    required this.child,
    required this.onTap,
  });

  @override
  State<_AnimatedPressCard> createState() =>
      _AnimatedPressCardState();
}

class _AnimatedPressCardState
    extends State<_AnimatedPressCard> {
  bool pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) {
        setState(() {
          pressed = true;
        });
      },

      onTapCancel: () {
        setState(() {
          pressed = false;
        });
      },

      onTapUp: (_) {
        setState(() {
          pressed = false;
        });

        widget.onTap();
      },

      child: AnimatedContainer(
        duration:
            const Duration(milliseconds: 130),

        curve: Curves.easeOut,

        transform:
            Matrix4.translationValues(
          0,
          pressed ? 4 : 0,
          0,
        ),

        child: widget.child,
      ),
    );
  }
}


// ==================================================================
// ANIMATED ICON BUTTON
// ==================================================================

class _AnimatedIconButton
    extends StatefulWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _AnimatedIconButton({
    required this.icon,
    required this.onTap,
  });

  @override
  State<_AnimatedIconButton> createState() =>
      _AnimatedIconButtonState();
}

class _AnimatedIconButtonState
    extends State<_AnimatedIconButton> {
  bool pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) {
        setState(() {
          pressed = true;
        });
      },

      onTapCancel: () {
        setState(() {
          pressed = false;
        });
      },

      onTapUp: (_) {
        setState(() {
          pressed = false;
        });

        widget.onTap();
      },

      child: AnimatedContainer(
        duration:
            const Duration(milliseconds: 120),

        transform:
            Matrix4.translationValues(
          0,
          pressed ? 3 : 0,
          0,
        ),

        height: 45,
        width: 45,

        decoration:
            BoxDecoration(
          color: Colors.white,

          borderRadius:
              BorderRadius.circular(15),

          boxShadow: [
            BoxShadow(
              color: Colors.black
                  .withOpacity(
                pressed ? 0.04 : 0.09,
              ),

              blurRadius:
                  pressed ? 5 : 10,

              offset: Offset(
                0,
                pressed ? 2 : 5,
              ),
            ),
          ],

          border: Border.all(
            color:
                const Color(0xffE5EAF2),
          ),
        ),

        child: Icon(
          widget.icon,
          color:
              const Color(0xff334155),
          size: 22,
        ),
      ),
    );
  }
}


// ==================================================================
// EXTENSION - ENTRANCE ANIMATION
// ==================================================================

extension _EntranceAnimation
    on Widget {
  Widget animateEntrance({
    int delay = 0,
  }) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(
        begin: 0,
        end: 1,
      ),

      duration:
          const Duration(milliseconds: 600),

      curve: Curves.easeOutBack,

      builder:
          (context, value, child) {
        return Opacity(
          opacity: value.clamp(
            0.0,
            1.0,
          ),

          child: Transform.translate(
            offset: Offset(
              0,
              18 * (1 - value),
            ),

            child: Transform.scale(
              scale:
                  0.96 +
                      (0.04 * value),

              child: child,
            ),
          ),
        );
      },

      child: this,
    );
  }
}
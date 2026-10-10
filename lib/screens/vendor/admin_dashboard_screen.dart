import 'dart:math' as math;

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen>
    with TickerProviderStateMixin {
  final DatabaseReference db = FirebaseDatabase.instance.ref();

  late AnimationController _animationController;
  late AnimationController _floatingController;

  int selectedMenu = 0;

  bool loading = true;

  bool _drawerOpen = false;
  // ============================================================
  // RAW DATA
  // ============================================================

  Map<String, dynamic> users = {};
  Map<String, dynamic> workers = {};
  Map<String, dynamic> services = {};
  Map<String, dynamic> societyBatches = {};

  // ============================================================
  // STATISTICS
  // ============================================================

  int totalUsers = 0;
  int totalCustomers = 0;
  int totalWorkers = 0;
  int totalVendors = 0;

  int totalApartments = 0;
  int totalFlats = 0;

  int totalServices = 0;
  int activeServices = 0;
  int completedServices = 0;
  int pendingServices = 0;

  int totalSocietyBatches = 0;
  int totalSocietyFlats = 0;
  int completedSocietyFlats = 0;

  int totalBids = 0;
  int selectedBids = 0;

  double totalRevenue = 0;
  double workerEarnings = 0;
  double societyBidValue = 0;

  int totalPayments = 0;
  int successfulPayments = 0;
  int pendingPayments = 0;

  List<Map<String, dynamic>> workerStatistics = [];
  List<Map<String, dynamic>> societyHistory = [];
  List<Map<String, dynamic>> recentServices = [];
  List<Map<String, dynamic>> recentBids = [];

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _floatingController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);

    _loadDashboard();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _floatingController.dispose();
    super.dispose();
  }

  // ============================================================
  // LOAD EVERYTHING
  // ============================================================

  Future<void> _loadDashboard() async {
    if (mounted) {
      setState(() {
        loading = true;
      });
    }

    try {
      final results = await Future.wait([
        db.child("users").get(),
        db.child("workers").get(),
        db.child("services").get(),
        db.child("societyServiceBatches").get(),
      ]);

      users = _mapFromSnapshot(results[0]);
      workers = _mapFromSnapshot(results[1]);
      services = _mapFromSnapshot(results[2]);
      societyBatches = _mapFromSnapshot(results[3]);

      _calculateEverything();

      if (mounted) {
        setState(() {
          loading = false;
        });

        _animationController.forward(from: 0);
      }
    } catch (e) {
      debugPrint("ADMIN DASHBOARD ERROR: $e");

      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  Map<String, dynamic> _mapFromSnapshot(DataSnapshot snapshot) {
    final value = snapshot.value;

    if (value is Map) {
      return Map<String, dynamic>.from(
        value.map((key, value) => MapEntry(key.toString(), value)),
      );
    }

    return {};
  }

  // ============================================================
  // CALCULATE ALL STATISTICS
  // ============================================================

  void _calculateEverything() {
    _calculateUsers();
    _calculateServices();
    _calculateSocieties();
    _calculateWorkers();
    _calculateRecentData();
  }

  // ============================================================
  // USERS
  // ============================================================

  void _calculateUsers() {
    totalUsers = users.length;
    totalCustomers = 0;
    totalWorkers = workers.length;
    totalVendors = 0;

    for (final entry in users.entries) {
      final data = _safeMap(entry.value);

      final role = data["role"]?.toString().toLowerCase() ?? "";

      if (role == "vendor") {
        totalVendors++;
      }

      if (role == "customer" || role == "user" || role.isEmpty) {
        totalCustomers++;
      }
    }
  }

  // ============================================================
  // SERVICES
  // ============================================================

  void _calculateServices() {
    totalServices = services.length;

    activeServices = 0;
    completedServices = 0;
    pendingServices = 0;

    totalRevenue = 0;
    totalPayments = 0;
    successfulPayments = 0;
    pendingPayments = 0;

    for (final entry in services.entries) {
      final service = _safeMap(entry.value);

      final status = service["status"]?.toString().toLowerCase() ?? "";

      if (status == "completed") {
        completedServices++;
      } else if (status == "pending" ||
          status == "available" ||
          status == "requested") {
        pendingServices++;
      } else {
        activeServices++;
      }

      final amount = _toDouble(
        service["finalPrice"] ??
            service["amount"] ??
            service["price"] ??
            service["serviceAmount"],
      );

      if (status == "completed") {
        totalRevenue += amount;
      }

      final paymentStatus = service["paymentStatus"]?.toString().toLowerCase();

      if (paymentStatus != null && paymentStatus.isNotEmpty) {
        totalPayments++;

        if (paymentStatus == "paid" ||
            paymentStatus == "success" ||
            paymentStatus == "successful" ||
            paymentStatus == "completed") {
          successfulPayments++;
        } else {
          pendingPayments++;
        }
      }
    }
  }

  // ============================================================
  // SOCIETY BATCHES
  // ============================================================

  void _calculateSocieties() {
    totalApartments = societyBatches.length;

    totalSocietyBatches = 0;
    totalFlats = 0;
    totalSocietyFlats = 0;
    completedSocietyFlats = 0;
    totalBids = 0;
    selectedBids = 0;
    societyBidValue = 0;

    societyHistory.clear();

    for (final apartmentEntry in societyBatches.entries) {
      final apartmentKey = apartmentEntry.key;

      final apartmentData = _safeMap(apartmentEntry.value);

      for (final serviceEntry in apartmentData.entries) {
        final serviceId = serviceEntry.key;

        final batch = _safeMap(serviceEntry.value);

        totalSocietyBatches++;

        final participants = _safeMap(batch["participants"]);

        final bids = _safeMap(batch["bids"]);

        totalSocietyFlats += participants.length;
        totalFlats += participants.length;

        int completed = 0;

        for (final participantEntry in participants.entries) {
          final participant = _safeMap(participantEntry.value);

          if (_isCompleted(participant)) {
            completed++;
          }
        }

        completedSocietyFlats += completed;

        for (final bidEntry in bids.entries) {
          final bid = _safeMap(bidEntry.value);

          totalBids++;

          final status = bid["status"]?.toString().toLowerCase();

          if (status == "selected") {
            selectedBids++;

            societyBidValue += _toDouble(bid["bidAmount"]);
          }

          recentBids.add({
            "apartmentKey": apartmentKey,
            "serviceId": serviceId,
            "serviceName": batch["serviceName"] ?? "Service",
            "apartmentName": batch["apartmentName"] ?? "Apartment",
            "vendorName": bid["vendorName"] ?? "Vendor",
            "vendorId": bid["vendorId"] ?? bidEntry.key,
            "bidAmount": _toDouble(bid["bidAmount"]),
            "status": bid["status"] ?? "pending",
          });
        }

        societyHistory.add({
          "apartmentKey": apartmentKey,
          "serviceId": serviceId,
          "serviceName": batch["serviceName"] ?? "Service",
          "apartmentName": batch["apartmentName"] ?? "Apartment",
          "address": batch["address"] ?? "",
          "status": batch["status"] ?? "pending",
          "selectedVendorId": batch["selectedVendorId"],
          "requestCount": batch["requestCount"] ?? participants.length,
          "completed": completed,
          "total": participants.length,
          "bidAmount": _selectedBidAmount(bids),
          "selectedVendorName": _selectedVendorName(
            bids,
            batch["selectedVendorId"],
          ),
          "participants": participants,
        });
      }
    }

    totalApartments = math.max(totalApartments, _discoverApartmentCount());

    societyHistory.sort(
      (a, b) => b["serviceId"].toString().compareTo(a["serviceId"].toString()),
    );
  }

  int _discoverApartmentCount() {
    final names = <String>{};

    for (final apartmentEntry in societyBatches.entries) {
      final apartment = _safeMap(apartmentEntry.value);

      for (final serviceEntry in apartment.entries) {
        final batch = _safeMap(serviceEntry.value);

        final name = batch["apartmentName"]?.toString();

        if (name != null && name.isNotEmpty) {
          names.add(name);
        }
      }
    }

    return names.length;
  }

  // ============================================================
  // WORKERS
  // ============================================================

  void _calculateWorkers() {
    workerStatistics.clear();
    workerEarnings = 0;

    for (final entry in workers.entries) {
      final workerId = entry.key;

      final worker = _safeMap(entry.value);

      int active = 0;
      int completed = 0;
      double earnings = 0;

      for (final serviceEntry in services.entries) {
        final service = _safeMap(serviceEntry.value);

        final assignedWorker = service["assignedWorkerId"]?.toString();

        if (assignedWorker != workerId) {
          continue;
        }

        final status = service["status"]?.toString().toLowerCase();

        if (status == "completed") {
          completed++;

          earnings += _toDouble(
            service["finalPrice"] ??
                service["workerAmount"] ??
                service["amount"],
          );
        } else {
          active++;
        }
      }

      workerEarnings += earnings;

      workerStatistics.add({
        "id": workerId,
        "name": worker["name"] ?? worker["workerName"] ?? "Worker",
        "phone": worker["phone"] ?? "",
        "email": worker["email"] ?? "",
        "active": active,
        "completed": completed,
        "earnings": earnings,
        "availableForUrgent": worker["availableForUrgent"] == true,
        "profileCompleted": worker["profileCompleted"] == true,
      });
    }

    workerStatistics.sort(
      (a, b) => _toDouble(b["earnings"]).compareTo(_toDouble(a["earnings"])),
    );
  }

  // ============================================================
  // RECENT DATA
  // ============================================================

  void _calculateRecentData() {
    recentServices.clear();

    for (final entry in services.entries) {
      final service = _safeMap(entry.value);

      recentServices.add({"id": entry.key, ...service});
    }

    recentServices.sort(
      (a, b) =>
          _timestamp(b["createdAt"]).compareTo(_timestamp(a["createdAt"])),
    );

    if (recentServices.length > 10) {
      recentServices = recentServices.take(10).toList();
    }

    if (recentBids.length > 10) {
      recentBids = recentBids.take(10).toList();
    }
  }

  // ============================================================
  // HELPERS
  // ============================================================

  Map<String, dynamic> _safeMap(dynamic value) {
    if (value is Map) {
      return Map<String, dynamic>.from(
        value.map((key, value) => MapEntry(key.toString(), value)),
      );
    }

    return {};
  }

  double _toDouble(dynamic value) {
    if (value == null) return 0;

    return double.tryParse(value.toString()) ?? 0;
  }

  int _timestamp(dynamic value) {
    return int.tryParse(value?.toString() ?? "") ?? 0;
  }

  bool _isCompleted(Map<String, dynamic> data) {
    return data["completed"] == true ||
        data["completionStatus"]?.toString().toLowerCase() == "completed" ||
        data["workStatus"]?.toString().toLowerCase() == "completed";
  }

  double _selectedBidAmount(Map<String, dynamic> bids) {
    for (final entry in bids.entries) {
      final bid = _safeMap(entry.value);

      if (bid["status"]?.toString().toLowerCase() == "selected") {
        return _toDouble(bid["bidAmount"]);
      }
    }

    return 0;
  }

  String _selectedVendorName(
    Map<String, dynamic> bids,
    dynamic selectedVendorId,
  ) {
    if (selectedVendorId != null) {
      final selectedId = selectedVendorId.toString();

      for (final entry in bids.entries) {
        final bid = _safeMap(entry.value);

        final vendorId = bid["vendorId"]?.toString() ?? entry.key;

        if (vendorId == selectedId) {
          return bid["vendorName"]?.toString() ?? "Selected Vendor";
        }
      }
    }

    for (final entry in bids.entries) {
      final bid = _safeMap(entry.value);

      if (bid["status"]?.toString().toLowerCase() == "selected") {
        return bid["vendorName"]?.toString() ?? "Selected Vendor";
      }
    }

    return "Not selected";
  }

  String _money(double amount) {
    if (amount >= 10000000) {
      return "₹${(amount / 10000000).toStringAsFixed(1)}Cr";
    }

    if (amount >= 100000) {
      return "₹${(amount / 100000).toStringAsFixed(1)}L";
    }

    if (amount >= 1000) {
      return "₹${(amount / 1000).toStringAsFixed(1)}K";
    }

    return "₹${amount.toStringAsFixed(0)}";
  }

  // ============================================================
  // BUILD
  // ============================================================

 @override
Widget build(BuildContext context) {
  return Scaffold(
    backgroundColor: const Color(0xfff5f7fb),

    drawer: MediaQuery.of(context).size.width < 800
        ? Drawer(
            width: 260,
            child: _buildSidebar(),
          )
        : null,

    body: LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = constraints.maxWidth;

        // MOBILE
        if (screenWidth < 800) {
          return Column(
            children: [
              _buildTopBar(),

              Expanded(
                child: _buildMainContent(),
              ),
            ],
          );
        }

        // DESKTOP
        return Row(
          children: [
            SizedBox(
              width: 260,
              child: _buildSidebar(),
            ),

            Expanded(
              child: Column(
                children: [
                  _buildTopBar(),

                  Expanded(
                    child: _buildMainContent(),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    ),
  );
}
  // ============================================================
  // LOADING
  // ============================================================

  Widget _buildLoading() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xff08111f), Color(0xff111d33), Color(0xff172b49)],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                color: Colors.white.withOpacity(.08),
                border: Border.all(color: Colors.white.withOpacity(.12)),
              ),
              child: const Icon(
                Icons.dashboard_rounded,
                color: Colors.white,
                size: 42,
              ),
            ),
            const SizedBox(height: 25),
            const Text(
              "SERVORA",
              style: TextStyle(
                color: Colors.white,
                fontSize: 25,
                fontWeight: FontWeight.w900,
                letterSpacing: 3,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Loading Admin Command Center...",
              style: TextStyle(color: Colors.white.withOpacity(.6)),
            ),
            const SizedBox(height: 25),
            const SizedBox(width: 180, child: LinearProgressIndicator()),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // SIDEBAR
  // ============================================================

  Widget _buildSidebar() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xff0b1424),
        boxShadow: [
          BoxShadow(blurRadius: 30, color: Colors.black.withOpacity(.12)),
        ],
      ),
      child: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 25),

            // LOGO
            Row(
              children: [
                const SizedBox(width: 22),
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(15),
                    gradient: const LinearGradient(
                      colors: [Color(0xff4f8cff), Color(0xff7357ff)],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xff4f8cff).withOpacity(.35),
                        blurRadius: 20,
                      ),
                    ],
                  ),
                  child: const Icon(Icons.auto_awesome, color: Colors.white),
                ),
                const SizedBox(width: 13),
                const Text(
                  "SERVORA",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 45),

            _sidebarItem(0, Icons.dashboard_rounded, "Dashboard"),

            _sidebarItem(1, Icons.people_alt_rounded, "Users"),

            _sidebarItem(2, Icons.apartment_rounded, "Apartments"),

            _sidebarItem(3, Icons.handyman_rounded, "Services"),

            _sidebarItem(4, Icons.groups_rounded, "Workers"),

            _sidebarItem(5, Icons.gavel_rounded, "Vendor Bids"),

            _sidebarItem(6, Icons.account_balance_wallet_rounded, "Payments"),

            const Spacer(),

            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: Colors.white.withOpacity(.05),
                border: Border.all(color: Colors.white.withOpacity(.07)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(.08),
                    ),
                    child: const Icon(
                      Icons.admin_panel_settings,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Administrator",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 3),
                        Text(
                          "Control Center",
                          style: TextStyle(color: Colors.white54, fontSize: 10),
                        ),
                      ],
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

  Widget _sidebarItem(int index, IconData icon, String title) {
    final selected = selectedMenu == index;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          setState(() {
            selectedMenu = index;
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: selected
                ? const LinearGradient(
                    colors: [Color(0xff426dff), Color(0xff684cff)],
                  )
                : null,
            color: selected ? null : Colors.transparent,
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 20,
                color: selected ? Colors.white : Colors.white54,
              ),

              const SizedBox(width: 13),

              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: selected ? Colors.white : Colors.white60,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  // ============================================================
  // TOP BAR
  // ============================================================

  Widget _buildTopBar() {
    return Container(
      height: 82,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;

          // ============================================================
          // VERY SMALL WIDTH
          // ============================================================
          if (width < 350) {
  return Row(
    children: [
      Builder(
        builder: (context) {
          return GestureDetector(
            onTap: () {
              Scaffold.of(context).openDrawer();
            },
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xfff6f8fc),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.menu_rounded,
                color: Color(0xff475467),
                size: 21,
              ),
            ),
          );
        },
      ),

      const SizedBox(width: 8),

      Expanded(
        child: Text(
          _pageTitle(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w900,
            color: Color(0xff101828),
          ),
        ),
        
      ),

      
      const SizedBox(height: 3),

                      Text(
                        _pageSubtitle(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.grey.shade500,
                          fontSize: 10,
                        ),
                      ),
                      const SizedBox(width: 8),

      GestureDetector(
        onTap: _loadDashboard,
        child: _buildTopBarIcon(
          icon: Icons.refresh_rounded,
        ),
      ),
    ],
  );
}

          // ============================================================
          // MEDIUM WIDTH
          // ============================================================
          if (width < 650) {
  return Row(
    children: [
      Builder(
        builder: (context) {
          return GestureDetector(
            onTap: () {
              Scaffold.of(context).openDrawer();
            },
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: const Color(0xfff6f8fc),
                borderRadius: BorderRadius.circular(13),
              ),
              child: const Icon(
                Icons.menu_rounded,
                color: Color(0xff475467),
                size: 22,
              ),
            ),
          );
        },
      ),

      const SizedBox(width: 10),

      Expanded(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _pageTitle(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: Color(0xff101828),
              ),
            ),

            const SizedBox(height: 3),

            Text(
              _pageSubtitle(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.grey.shade500,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),

      const SizedBox(width: 8),

      _buildTopBarIcon(
        icon: Icons.notifications_none_rounded,
      ),

      const SizedBox(width: 8),

      GestureDetector(
        onTap: _loadDashboard,
        child: _buildTopBarIcon(
          icon: Icons.refresh_rounded,
        ),
      ),
    ],
  );
}

          // ============================================================
          // LARGE WIDTH
          // ============================================================
          return Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _pageTitle(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 23,
                        fontWeight: FontWeight.w900,
                        color: Color(0xff101828),
                      ),
                    ),

                    const SizedBox(height: 3),

                    Text(
                      _pageSubtitle(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 15),

              SizedBox(
                width: width >= 900 ? 220 : 150,
                height: 42,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xfff6f8fc),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.search_rounded,
                        color: Colors.grey.shade500,
                        size: 20,
                      ),

                      const SizedBox(width: 8),

                      Expanded(
                        child: Text(
                          "Search dashboard...",
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.grey.shade400,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(width: 12),

              _buildTopBarIcon(icon: Icons.notifications_none_rounded),

              const SizedBox(width: 10),

              GestureDetector(
                onTap: _loadDashboard,
                child: _buildTopBarIcon(icon: Icons.refresh_rounded),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTopBarIcon({required IconData icon}) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: const Color(0xfff6f8fc),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Icon(icon, color: const Color(0xff475467), size: 21),
    );
  }

  String _pageTitle() {
    switch (selectedMenu) {
      case 1:
        return "Users";
      case 2:
        return "Apartments";
      case 3:
        return "Services";
      case 4:
        return "Workers";
      case 5:
        return "Vendor Bids";
      case 6:
        return "Payments";
      default:
        return "Admin Command Center";
    }
  }

  String _pageSubtitle() {
    switch (selectedMenu) {
      case 1:
        return "Manage customers, vendors and platform users";
      case 2:
        return "Monitor apartments, societies and flats";
      case 3:
        return "Track every service across Servora";
      case 4:
        return "Worker performance and earnings";
      case 5:
        return "Monitor vendor bidding activity";
      case 6:
        return "Revenue and payment overview";
      default:
        return "Complete real-time overview of your Servora platform";
    }
  }

  // ============================================================
  // MAIN CONTENT
  // ============================================================

  Widget _buildMainContent() {
    return RefreshIndicator(
      onRefresh: _loadDashboard,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(30, 28, 30, 50),
        child: _buildPage(),
      ),
    );
  }

  Widget _buildPage() {
    switch (selectedMenu) {
      case 1:
        return _buildUsersPage();
      case 2:
        return _buildApartmentsPage();
      case 3:
        return _buildServicesPage();
      case 4:
        return _buildWorkersPage();
      case 5:
        return _buildBidsPage();
      case 6:
        return _buildPaymentsPage();
      default:
        return _buildDashboardPage();
    }
  }

  // ============================================================
  // DASHBOARD
  // ============================================================

  Widget _buildDashboardPage() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHero(),

        const SizedBox(height: 25),

        _buildStatGrid(),

        const SizedBox(height: 25),

        _buildRevenueAndServiceSection(),

        const SizedBox(height: 25),

        _buildSocietySection(),

        const SizedBox(height: 25),

        _buildWorkerSection(),

        const SizedBox(height: 25),

        _buildRecentServicesSection(),
      ],
    );
  }

  // ============================================================
  // HERO
  // ============================================================

  Widget _buildHero() {
    return AnimatedBuilder(
      animation: _floatingController,
      builder: (context, child) {
        final offset = math.sin(_floatingController.value * math.pi * 2) * 4;

        return Transform.translate(
          offset: Offset(0, offset),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xff101d36),
                  Color(0xff1e3470),
                  Color(0xff4631a8),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: Color(0xff304fff),
                  blurRadius: 35,
                  offset: Offset(0, 18),
                ),
              ],
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // =====================================================
                // BACKGROUND DECORATION - TOP RIGHT
                // =====================================================
                Positioned(
                  right: -70,
                  top: -90,
                  child: IgnorePointer(
                    child: Container(
                      width: 220,
                      height: 220,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withOpacity(.05),
                      ),
                    ),
                  ),
                ),

                // =====================================================
                // BACKGROUND DECORATION - BOTTOM RIGHT
                // =====================================================
                Positioned(
                  right: 100,
                  bottom: -120,
                  child: IgnorePointer(
                    child: Container(
                      width: 220,
                      height: 220,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withOpacity(.04),
                      ),
                    ),
                  ),
                ),

                // =====================================================
                // MAIN CONTENT
                // =====================================================
                LayoutBuilder(
                  builder: (context, constraints) {
                    final double availableWidth = constraints.maxWidth;

                    // -------------------------------------------------
                    // NARROW SCREEN
                    // -------------------------------------------------
                    if (availableWidth < 600) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // -------------------------------------------
                          // LIVE SYSTEM BADGE
                          // -------------------------------------------
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(.10),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.fiber_manual_record,
                                  color: Colors.greenAccent,
                                  size: 9,
                                ),
                                SizedBox(width: 6),
                                Text(
                                  "LIVE SYSTEM",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 18),

                          // -------------------------------------------
                          // GREETING
                          // -------------------------------------------
                          const Text(
                            "Good morning, Admin 👋",
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                              height: 1.15,
                            ),
                          ),

                          const SizedBox(height: 10),

                          // -------------------------------------------
                          // SUBTITLE
                          // -------------------------------------------
                          Text(
                            "Here is everything happening across "
                            "Servora today.",
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white.withOpacity(.65),
                              fontSize: 13,
                              height: 1.5,
                            ),
                          ),

                          const SizedBox(height: 24),

                          // -------------------------------------------
                          // ADMIN ICON
                          // -------------------------------------------
                          Container(
                            width: 90,
                            height: 90,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(28),
                              color: Colors.white.withOpacity(.08),
                              border: Border.all(
                                color: Colors.white.withOpacity(.10),
                              ),
                            ),
                            child: const Icon(
                              Icons.admin_panel_settings_rounded,
                              color: Colors.white,
                              size: 45,
                            ),
                          ),
                        ],
                      );
                    }

                    // -------------------------------------------------
                    // LARGE SCREEN
                    // -------------------------------------------------
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // =============================================
                        // LEFT CONTENT
                        // =============================================
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // ---------------------------------------
                              // LIVE SYSTEM BADGE
                              // ---------------------------------------
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(.10),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.fiber_manual_record,
                                      color: Colors.greenAccent,
                                      size: 9,
                                    ),
                                    SizedBox(width: 6),
                                    Text(
                                      "LIVE SYSTEM",
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 1,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 16),

                              // ---------------------------------------
                              // GREETING
                              // ---------------------------------------
                              const Text(
                                "Good morning, Admin 👋",
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 28,
                                  fontWeight: FontWeight.w900,
                                  height: 1.15,
                                ),
                              ),

                              const SizedBox(height: 8),

                              // ---------------------------------------
                              // SUBTITLE
                              // ---------------------------------------
                              Text(
                                "Here is everything happening across "
                                "Servora today.",
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.white.withOpacity(.65),
                                  fontSize: 13,
                                  height: 1.5,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(width: 30),

                        // =============================================
                        // ADMIN ICON
                        // =============================================
                        Container(
                          width: 115,
                          height: 115,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(32),
                            color: Colors.white.withOpacity(.08),
                            border: Border.all(
                              color: Colors.white.withOpacity(.10),
                            ),
                          ),
                          child: const Icon(
                            Icons.admin_panel_settings_rounded,
                            color: Colors.white,
                            size: 58,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
  // ============================================================
  // STAT GRID
  // ============================================================

 Widget _buildStatGrid() {
  return LayoutBuilder(
    builder: (context, constraints) {
      final width = constraints.maxWidth;

      final crossAxisCount = width > 1100
          ? 4
          : width > 700
              ? 2
              : 1;

      return GridView.count(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,

         // IMPORTANT:
        // Give the cards a fixed minimum height.
         childAspectRatio: crossAxisCount == 1 ? 2.5 : 1.7,

        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),

        children: [
          _statCard(
            title: "Total Users",
            value: totalUsers.toString(),
            subtitle: "$totalCustomers customers",
            icon: Icons.people_alt_rounded,
            gradient: const [
              Color(0xff4776ff),
              Color(0xff6d4dff),
            ],
          ),

          _statCard(
            title: "Workers",
            value: totalWorkers.toString(),
            subtitle:
                "${workerStatistics.where((e) => e["active"] > 0).length} active",
            icon: Icons.engineering_rounded,
            gradient: const [
              Color(0xff00a6a6),
              Color(0xff008bba),
            ],
          ),

          _statCard(
            title: "Apartments",
            value: totalApartments.toString(),
            subtitle: "$totalFlats flats",
            icon: Icons.apartment_rounded,
            gradient: const [
              Color(0xffff8a3d),
              Color(0xffff526f),
            ],
          ),

          _statCard(
            title: "Revenue",
            value: _money(totalRevenue),
            subtitle: "$successfulPayments successful payments",
            icon: Icons.payments_rounded,
            gradient: const [
              Color(0xff18a558),
              Color(0xff0b8f72),
            ],
          ),
        ],
      );
    },
  );
}
  Widget _statCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required List<Color> gradient,
  }) {
    return Container(
      padding: const EdgeInsets.all(15),
      
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.045),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 55,
            height: 55,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(17),
              gradient: LinearGradient(colors: gradient),
              boxShadow: [
                BoxShadow(
                  color: gradient.first.withOpacity(.25),
                  blurRadius: 15,
                  offset: const Offset(0, 7),
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 27),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.grey.shade500,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xff101828),
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 10),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // REVENUE + SERVICES
  // ============================================================

  Widget _buildRevenueAndServiceSection() {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 800) {
          return Column(
            children: [
              _buildRevenueCard(),

              const SizedBox(height: 18),

              _buildServiceOverview(),
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 5, child: _buildRevenueCard()),

            const SizedBox(width: 18),

            Expanded(flex: 4, child: _buildServiceOverview()),
          ],
        );
      },
    );
  }

  Widget _buildRevenueCard() {
    return _panel(
      title: "Revenue Overview",
      subtitle: "Platform financial performance",
      icon: Icons.trending_up_rounded,
      child: Column(
        children: [
          Row(
            children: [
              Text(
                _money(totalRevenue),
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const Spacer(),
              _smallBadge("Live", Icons.circle),
            ],
          ),
          const SizedBox(height: 25),
          SizedBox(
            height: 150,
            child: CustomPaint(
              painter: _RevenuePainter(
                completed: completedServices,
                active: activeServices,
                pending: pendingServices,
              ),
              child: Container(),
            ),
          ),
          const SizedBox(height: 15),
          Row(
            children: [
              _legend("Completed", completedServices),
              const SizedBox(width: 22),
              _legend("Active", activeServices),
              const SizedBox(width: 22),
              _legend("Pending", pendingServices),
            ],
          ),
        ],
      ),
    );
  }

  Widget _legend(String title, int value) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(color: Colors.grey.shade500, fontSize: 10),
          ),
          const SizedBox(height: 4),
          Text(
            value.toString(),
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildServiceOverview() {
    final total = math.max(totalServices, 1);

    final completedRatio = completedServices / total;

    final activeRatio = activeServices / total;

    final pendingRatio = pendingServices / total;

    return _panel(
      title: "Service Overview",
      subtitle: "$totalServices total service requests",
      icon: Icons.handyman_rounded,
      child: Column(
        children: [
          _progressRow(
            "Completed",
            completedServices,
            completedRatio,
            const Color(0xff18a558),
          ),
          const SizedBox(height: 18),
          _progressRow(
            "Active",
            activeServices,
            activeRatio,
            const Color(0xff4776ff),
          ),
          const SizedBox(height: 18),
          _progressRow(
            "Pending",
            pendingServices,
            pendingRatio,
            const Color(0xffff9f43),
          ),
          const SizedBox(height: 22),
          Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: const Color(0xfff6f8fc),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.auto_graph_rounded,
                  color: Color(0xff4776ff),
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    "$totalSocietyBatches society batches are being monitored.",
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _progressRow(String title, int value, double ratio, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 11),
            ),
            const Spacer(),
            Text(
              value.toString(),
              style: TextStyle(color: color, fontWeight: FontWeight.w900),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: LinearProgressIndicator(
            value: ratio.clamp(0, 1),
            minHeight: 7,
            backgroundColor: Colors.grey.shade100,
            valueColor: AlwaysStoppedAnimation(color),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // SOCIETY SECTION
  // ============================================================

  Widget _buildSocietySection() {
    return _panel(
      title: "Society Service Batches",
      subtitle: "Apartment-wide service operations",
      icon: Icons.apartment_rounded,
      action: "$totalSocietyBatches batches",
      child: societyHistory.isEmpty
          ? _empty(Icons.apartment_outlined, "No society batches found")
          : Column(
              children: societyHistory
                  .take(6)
                  .map((batch) => _societyHistoryTile(batch))
                  .toList(),
            ),
    );
  }

  Widget _societyHistoryTile(Map<String, dynamic> batch) {
    final total = batch["total"] as int? ?? 0;

    final completed = batch["completed"] as int? ?? 0;

    final percentage = total == 0 ? 0.0 : completed / total;

    return InkWell(
      onTap: () => _showSocietyDetails(batch),
      borderRadius: BorderRadius.circular(17),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: const Color(0xfff8f9fc),
          borderRadius: BorderRadius.circular(17),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                gradient: const LinearGradient(
                  colors: [Color(0xff5b7cff), Color(0xff7154ff)],
                ),
              ),
              child: const Icon(Icons.apartment_rounded, color: Colors.white),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    batch["serviceName"].toString(),
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    batch["apartmentName"].toString(),
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 10),
                  ),
                  const SizedBox(height: 9),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: LinearProgressIndicator(
                      value: percentage.clamp(0, 1),
                      minHeight: 5,
                      backgroundColor: Colors.grey.shade200,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 20),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  "$completed/$total",
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  "flats",
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 9),
                ),
                const SizedBox(height: 5),
                Text(
                  _money(_toDouble(batch["bidAmount"])),
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right_rounded, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // WORKER SECTION
  // ============================================================

  Widget _buildWorkerSection() {
    return _panel(
      title: "Top Worker Performance",
      subtitle: "Workers ranked by completed earnings",
      icon: Icons.engineering_rounded,
      action: "$totalWorkers workers",
      child: workerStatistics.isEmpty
          ? _empty(Icons.engineering_outlined, "No workers found")
          : Column(
              children: workerStatistics
                  .take(5)
                  .map((worker) => _workerTile(worker))
                  .toList(),
            ),
    );
  }

  Widget _workerTile(Map<String, dynamic> worker) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: const Color(0xfff8f9fc),
        borderRadius: BorderRadius.circular(17),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [Color(0xff4f8cff), Color(0xff7556ff)],
              ),
            ),
            child: const Icon(Icons.person_rounded, color: Colors.white),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  worker["name"].toString(),
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "${worker["completed"]} completed • ${worker["active"]} active",
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 10),
                ),
              ],
            ),
          ),
          if (worker["availableForUrgent"] == true)
            Container(
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(.10),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                "URGENT",
                style: TextStyle(
                  color: Colors.green,
                  fontSize: 8,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          Text(
            _money(_toDouble(worker["earnings"])),
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // RECENT SERVICES
  // ============================================================

  Widget _buildRecentServicesSection() {
    return _panel(
      title: "Recent Services",
      subtitle: "Latest activity across Servora",
      icon: Icons.history_rounded,
      action: "$totalServices total",
      child: recentServices.isEmpty
          ? _empty(Icons.history, "No services found")
          : Column(
              children: recentServices
                  .take(7)
                  .map((service) => _serviceTile(service))
                  .toList(),
            ),
    );
  }

  Widget _serviceTile(Map<String, dynamic> service) {
    final status = service["status"]?.toString() ?? "unknown";

    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: const Color(0xfff8f9fc),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(13),
              color: const Color(0xff4776ff).withOpacity(.10),
            ),
            child: const Icon(
              Icons.handyman_rounded,
              color: Color(0xff4776ff),
              size: 21,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  service["serviceName"]?.toString() ??
                      service["category"]?.toString() ??
                      "Service",
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  service["customerName"]?.toString() ??
                      service["location"]?.toString() ??
                      "Customer service",
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 10),
                ),
              ],
            ),
          ),
          _statusBadge(status),
          const SizedBox(width: 15),
          Text(
            _money(_toDouble(service["finalPrice"] ?? service["amount"])),
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // USERS PAGE
  // ============================================================

  Widget _buildUsersPage() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader("Platform Users", "Complete user directory"),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: _miniMetric(
                "Customers",
                totalCustomers,
                Icons.person_rounded,
              ),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: _miniMetric(
                "Workers",
                totalWorkers,
                Icons.engineering_rounded,
              ),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: _miniMetric(
                "Vendors",
                totalVendors,
                Icons.storefront_rounded,
              ),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: _miniMetric("Total", totalUsers, Icons.groups_rounded),
            ),
          ],
        ),
        const SizedBox(height: 25),
        _panel(
          title: "All Users",
          subtitle: "Users registered in Servora",
          icon: Icons.people_alt_rounded,
          child: users.isEmpty
              ? _empty(Icons.people_outline, "No users found")
              : Column(
                  children: users.entries
                      .take(30)
                      .map(
                        (entry) => _userTile(entry.key, _safeMap(entry.value)),
                      )
                      .toList(),
                ),
        ),
      ],
    );
  }

  Widget _userTile(String id, Map<String, dynamic> user) {
    final role = user["role"]?.toString() ?? "customer";

    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xfff8f9fc),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: const Color(0xff4776ff).withOpacity(.10),
            child: const Icon(Icons.person, color: Color(0xff4776ff)),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user["name"]?.toString() ??
                      user["username"]?.toString() ??
                      "User",
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 3),
                Text(
                  user["email"]?.toString() ?? user["phone"]?.toString() ?? id,
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 10),
                ),
              ],
            ),
          ),
          _statusBadge(role),
        ],
      ),
    );
  }

  // ============================================================
  // APARTMENTS PAGE
  // ============================================================

  Widget _buildApartmentsPage() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader("Apartments & Flats", "Society-wide service management"),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: _miniMetric(
                "Apartments",
                totalApartments,
                Icons.apartment_rounded,
              ),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: _miniMetric(
                "Total Flats",
                totalFlats,
                Icons.home_work_rounded,
              ),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: _miniMetric(
                "Completed",
                completedSocietyFlats,
                Icons.check_circle_rounded,
              ),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: _miniMetric(
                "Remaining",
                totalSocietyFlats - completedSocietyFlats,
                Icons.pending_actions_rounded,
              ),
            ),
          ],
        ),
        const SizedBox(height: 25),
        _buildSocietySection(),
      ],
    );
  }

  // ============================================================
  // SERVICES PAGE
  // ============================================================

  Widget _buildServicesPage() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader("Services", "Every individual and service request"),
        const SizedBox(height: 20),
        _buildStatGrid(),
        const SizedBox(height: 25),
        _buildRecentServicesSection(),
      ],
    );
  }

  // ============================================================
  // WORKERS PAGE
  // ============================================================

  Widget _buildWorkersPage() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader("Worker Analytics", "Performance, jobs and earnings"),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: _miniMetric(
                "Workers",
                totalWorkers,
                Icons.engineering_rounded,
              ),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: _miniMetric(
                "Completed Jobs",
                workerStatistics.fold<int>(
                  0,
                  (sum, item) => sum + (item["completed"] as int? ?? 0),
                ),
                Icons.task_alt_rounded,
              ),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: _miniMetric(
                "Worker Earnings",
                null,
                Icons.payments_rounded,
                displayValue: _money(workerEarnings),
              ),
            ),
          ],
        ),
        const SizedBox(height: 25),
        _panel(
          title: "Worker Leaderboard",
          subtitle: "Who earned the most from completed services",
          icon: Icons.emoji_events_rounded,
          child: Column(
            children: workerStatistics
                .map((worker) => _workerTile(worker))
                .toList(),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // BIDS PAGE
  // ============================================================

  Widget _buildBidsPage() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader("Vendor Bidding", "Monitor vendor bids and selections"),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: _miniMetric("Total Bids", totalBids, Icons.gavel_rounded),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: _miniMetric(
                "Selected",
                selectedBids,
                Icons.verified_rounded,
              ),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: _miniMetric(
                "Bid Value",
                null,
                Icons.currency_rupee_rounded,
                displayValue: _money(societyBidValue),
              ),
            ),
          ],
        ),
        const SizedBox(height: 25),
        _panel(
          title: "Recent Vendor Bids",
          subtitle: "Vendor bidding activity",
          icon: Icons.gavel_rounded,
          child: recentBids.isEmpty
              ? _empty(Icons.gavel_outlined, "No bids found")
              : Column(
                  children: recentBids.map((bid) => _bidTile(bid)).toList(),
                ),
        ),
      ],
    );
  }

  Widget _bidTile(Map<String, dynamic> bid) {
    final status = bid["status"]?.toString().toLowerCase();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: const Color(0xfff8f9fc),
        borderRadius: BorderRadius.circular(17),
      ),
      child: Row(
        children: [
          Container(
            width: 45,
            height: 45,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: const Color(0xffff9f43).withOpacity(.12),
            ),
            child: const Icon(
              Icons.storefront_rounded,
              color: Color(0xffff8a3d),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  bid["vendorName"].toString(),
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "${bid["serviceName"]} • ${bid["apartmentName"]}",
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 10),
                ),
              ],
            ),
          ),
          Text(
            _money(_toDouble(bid["bidAmount"])),
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
          ),
          const SizedBox(width: 15),
          _statusBadge(status ?? "pending"),
        ],
      ),
    );
  }

  // ============================================================
  // PAYMENTS PAGE
  // ============================================================

  Widget _buildPaymentsPage() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader("Payments & Revenue", "Financial overview of Servora"),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: _miniMetric(
                "Revenue",
                null,
                Icons.currency_rupee_rounded,
                displayValue: _money(totalRevenue),
              ),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: _miniMetric(
                "Payments",
                totalPayments,
                Icons.receipt_long_rounded,
              ),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: _miniMetric(
                "Successful",
                successfulPayments,
                Icons.check_circle_rounded,
              ),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: _miniMetric(
                "Pending",
                pendingPayments,
                Icons.pending_rounded,
              ),
            ),
          ],
        ),
        const SizedBox(height: 25),
        _buildRevenueCard(),
      ],
    );
  }

  // ============================================================
  // MINI METRIC
  // ============================================================

  Widget _miniMetric(
    String title,
    int? numericValue,
    IconData icon, {
    String? displayValue,
  }) {
    final shownValue = displayValue ?? numericValue?.toString() ?? "0";

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.035),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 43,
            height: 43,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(13),
              color: const Color(0xff4776ff).withOpacity(.10),
            ),
            child: Icon(icon, color: const Color(0xff4776ff), size: 21),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 10),
                ),
                const SizedBox(height: 4),
                Text(
                  shownValue,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
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
  // GENERIC PANEL
  // ============================================================

  Widget _panel({
    required String title,
    required String subtitle,
    required IconData icon,
    required Widget child,
    String? action,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(23),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.04),
            blurRadius: 25,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: const Color(0xff4776ff).withOpacity(.10),
                ),
                child: Icon(icon, color: const Color(0xff4776ff), size: 20),
              ),

              const SizedBox(width: 11),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),

                    const SizedBox(height: 3),

                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),

              if (action != null) ...[
                const SizedBox(width: 8),

                Flexible(
                  child: Text(
                    action,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      color: Color(0xff4776ff),
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ],
          ),

          const SizedBox(height: 20),

          child,
        ],
      ),
    );
  }
  // ============================================================
  // SECTION HEADER
  // ============================================================

  Widget _sectionHeader(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 25,
            fontWeight: FontWeight.w900,
            color: Color(0xff101828),
          ),
        ),
        const SizedBox(height: 5),
        Text(
          subtitle,
          style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
        ),
      ],
    );
  }

  // ============================================================
  // BADGES
  // ============================================================

  Widget _statusBadge(String status) {
    Color color;

    switch (status.toLowerCase()) {
      case "completed":
      case "selected":
      case "paid":
      case "success":
      case "successful":
        color = const Color(0xff18a558);
        break;

      case "active":
      case "started":
      case "in_progress":
        color = const Color(0xff4776ff);
        break;

      case "pending":
      case "requested":
        color = const Color(0xffff9f43);
        break;

      case "cancelled":
      case "rejected":
        color = const Color(0xffef476f);
        break;

      default:
        color = const Color(0xff667085);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(.10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status.replaceAll("_", " ").toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 8,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Widget _smallBadge(String text, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(.08),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 8, color: Colors.green),
          const SizedBox(width: 5),
          Text(
            text,
            style: const TextStyle(
              color: Colors.green,
              fontSize: 9,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _empty(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 35),
      child: Center(
        child: Column(
          children: [
            Icon(icon, size: 40, color: Colors.grey.shade300),
            const SizedBox(height: 10),
            Text(text, style: TextStyle(color: Colors.grey.shade500)),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // SOCIETY DETAIL
  // ============================================================

  void _showSocietyDetails(Map<String, dynamic> batch) {
    final apartmentKey = batch["apartmentKey"].toString();

    final serviceId = batch["serviceId"].toString();

    final participantsRef = db
        .child("societyServiceBatches")
        .child(apartmentKey)
        .child(serviceId)
        .child("participants");

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * .88,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
          ),
          child: StreamBuilder<DatabaseEvent>(
            stream: participantsRef.onValue,
            builder: (context, snapshot) {
              Map<String, dynamic> participants = {};

              if (snapshot.hasData) {
                final value = snapshot.data!.snapshot.value;

                if (value is Map) {
                  participants = Map<String, dynamic>.from(
                    value.map((key, value) => MapEntry(key.toString(), value)),
                  );
                }
              }

              int completed = 0;
              int started = 0;

              for (final entry in participants.entries) {
                final participant = _safeMap(entry.value);

                if (_isCompleted(participant)) {
                  completed++;
                } else if (_isStarted(participant)) {
                  started++;
                }
              }

              final total = participants.length;

              return Column(
                children: [
                  const SizedBox(height: 12),

                  Container(
                    width: 45,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),

                  Padding(
                    padding: const EdgeInsets.all(22),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xff4776ff),
                                    Color(0xff7357ff),
                                  ],
                                ),
                              ),
                              child: const Icon(
                                Icons.apartment_rounded,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 13),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    batch["serviceName"].toString(),
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    batch["apartmentName"].toString(),
                                    style: TextStyle(
                                      color: Colors.grey.shade500,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              onPressed: () => Navigator.pop(context),
                              icon: const Icon(Icons.close_rounded),
                            ),
                          ],
                        ),

                        const SizedBox(height: 20),

                        Row(
                          children: [
                            _detailStat(
                              "Completed",
                              completed.toString(),
                              Colors.green,
                            ),
                            const SizedBox(width: 10),
                            _detailStat(
                              "In Progress",
                              started.toString(),
                              Colors.blue,
                            ),
                            const SizedBox(width: 10),
                            _detailStat(
                              "Pending",
                              (total - completed - started)
                                  .clamp(0, total)
                                  .toString(),
                              Colors.orange,
                            ),
                          ],
                        ),

                        const SizedBox(height: 20),

                        Row(
                          children: [
                            Text(
                              "$completed/$total Flats Completed",
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 12,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              _money(_toDouble(batch["bidAmount"])),
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 9),

                        ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: LinearProgressIndicator(
                            value: total == 0 ? 0 : completed / total,
                            minHeight: 8,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const Divider(height: 1),

                  Expanded(
                    child: participants.isEmpty
                        ? _empty(
                            Icons.home_work_outlined,
                            "No participants found",
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(20),
                            itemCount: participants.length,
                            itemBuilder: (context, index) {
                              final entry = participants.entries.elementAt(
                                index,
                              );

                              final participant = _safeMap(entry.value);

                              return _participantTile(entry.key, participant);
                            },
                          ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  bool _isStarted(Map<String, dynamic> p) {
    return p["workStarted"] == true ||
        p["workVerified"] == true ||
        p["workStatus"]?.toString().toLowerCase() == "started" ||
        p["workStatus"]?.toString().toLowerCase() == "in_progress";
  }

  Widget _detailStat(String title, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(.07),
          borderRadius: BorderRadius.circular(15),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                color: color,
                fontSize: 9,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              value,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
          ],
        ),
      ),
    );
  }

  Widget _participantTile(String id, Map<String, dynamic> participant) {
    final completed = _isCompleted(participant);

    final started = _isStarted(participant);

    String status;

    if (completed) {
      status = "Completed";
    } else if (started) {
      status = "In Progress";
    } else {
      status = "Not Started";
    }

    Color statusColor;

    if (completed) {
      statusColor = const Color(0xff18a558);
    } else if (started) {
      statusColor = const Color(0xff4776ff);
    } else {
      statusColor = const Color(0xffff9f43);
    }

    final flat =
        participant["flatNumber"]?.toString() ??
        participant["flat"]?.toString() ??
        id;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: const Color(0xfff8f9fc),
        borderRadius: BorderRadius.circular(17),
      ),
      child: Row(
        children: [
          Container(
            width: 45,
            height: 45,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(13),
              color: statusColor.withOpacity(.10),
            ),
            child: Icon(
              completed
                  ? Icons.check_rounded
                  : started
                  ? Icons.play_arrow_rounded
                  : Icons.schedule_rounded,
              color: statusColor,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Flat $flat",
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  participant["customerName"]?.toString() ??
                      participant["userName"]?.toString() ??
                      "Resident",
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 10),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(.10),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              status,
              style: TextStyle(
                color: statusColor,
                fontSize: 9,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ================================================================
// REVENUE PAINTER
// ================================================================

class _RevenuePainter extends CustomPainter {
  final int completed;
  final int active;
  final int pending;

  _RevenuePainter({
    required this.completed,
    required this.active,
    required this.pending,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final values = [
      completed.toDouble(),
      active.toDouble(),
      pending.toDouble(),
    ];

    final total = values.fold(0.0, (a, b) => a + b);

    final maxValue = math.max(total, 1);

    final paint = Paint()
      ..strokeWidth = 16
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final baseY = size.height - 25;

    final chartHeight = size.height - 45;

    final barWidth = 34.0;

    for (int i = 0; i < values.length; i++) {
      final x = 50 + (i * 95);

      final height = chartHeight * (values[i] / maxValue);

      paint.color = i == 0
          ? const Color(0xff18a558)
          : i == 1
          ? const Color(0xff4776ff)
          : const Color(0xffff9f43);

      canvas.drawLine(
        Offset(x.toDouble(), baseY),
        Offset(x.toDouble(), baseY - height),
        paint,
      );

      final textPainter = TextPainter(
        text: TextSpan(
          text: values[i].toInt().toString(),
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            color: Color(0xff344054),
          ),
        ),
        textDirection: TextDirection.ltr,
      );

      textPainter.layout();

      textPainter.paint(
        canvas,
        Offset(x - textPainter.width / 2, baseY - height - 22),
      );
    }

    // Ground line
    final groundPaint = Paint()
      ..color = const Color(0xffeaecf0)
      ..strokeWidth = 1;

    canvas.drawLine(
      Offset(20, baseY + 8),
      Offset(size.width - 10, baseY + 8),
      groundPaint,
    );

    // Avoid unused warning
    final _ = barWidth;
  }

  @override
  bool shouldRepaint(covariant _RevenuePainter oldDelegate) {
    return oldDelegate.completed != completed ||
        oldDelegate.active != active ||
        oldDelegate.pending != pending;
  }
}

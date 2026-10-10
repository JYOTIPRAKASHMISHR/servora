import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:servora/screens/vendor/admin_dashboard_screen.dart';

/// ===============================================================
/// SERVORA ADMIN - VENDOR BATCH MANAGEMENT
/// ===============================================================
///
/// This file contains:
///
/// 1. AdminVendorBatchesScreen
///    -> Shows batch cards
///
/// 2. AdminVendorBatchDetailsScreen
///    -> Shows complete batch details
///    -> Flats
///    -> Residents
///    -> Vendor bids
///    -> Select vendor
///
/// 3. AdminAcceptedVendorsScreen
///    -> Shows vendors selected by Admin
///
/// IMPORTANT:
/// Vendor selection is performed ONLY by Servora Admin.
/// Customer does NOT select the vendor.
///
/// Firebase main node:
///
/// societyServiceBatches
///
/// Example:
///
/// societyServiceBatches
///   └── green_valley
///        └── ac_service
///             ├── apartmentKey
///             ├── apartmentName
///             ├── serviceId
///             ├── serviceName
///             ├── status
///             ├── requestCount
///             ├── participants
///             └── bids
///
/// ===============================================================

class AdminVendorBatchesScreen extends StatefulWidget {
  const AdminVendorBatchesScreen({
    super.key,
    Map<dynamic, dynamic> batch = const {},
  });

  @override
  State<AdminVendorBatchesScreen> createState() =>
      _AdminVendorBatchesScreenState();
}

class _AdminVendorBatchesScreenState extends State<AdminVendorBatchesScreen> {
  static const Color primaryColor = Color(0xff2563EB);
  static const Color backgroundColor = Color(0xffF8FAFC);

  final DatabaseReference database = FirebaseDatabase.instance.ref();

  bool loading = true;

  List<Map<String, dynamic>> batches = [];

  @override
  void initState() {
    super.initState();
    _loadBatches();
  }

  /// =============================================================
  /// LOAD ALL SOCIETY SERVICE BATCHES
  /// =============================================================

  Future<void> _loadBatches() async {
    try {
      final snapshot = await database.child("societyServiceBatches").get();

      final List<Map<String, dynamic>> result = [];

      if (snapshot.exists && snapshot.value is Map) {
        final societies = Map<String, dynamic>.from(snapshot.value as Map);

        societies.forEach((apartmentKey, servicesValue) {
          if (servicesValue is! Map) return;

          final services = Map<String, dynamic>.from(servicesValue);

          services.forEach((serviceId, batchValue) {
            if (batchValue is! Map) return;

            final data = Map<String, dynamic>.from(batchValue);

            data["apartmentKey"] =
                data["apartmentKey"]?.toString() ?? apartmentKey.toString();

            data["serviceId"] =
                data["serviceId"]?.toString() ?? serviceId.toString();

            result.add(data);
          });
        });
      }

      if (!mounted) return;

      setState(() {
        batches = result;
        loading = false;
      });
    } catch (e) {
      debugPrint("LOAD BATCHES ERROR: $e");

      if (!mounted) return;

      setState(() {
        loading = false;
      });

      _showMessage("Unable to load service batches.", Colors.red);
    }
  }

  /// =============================================================
  /// OPEN BATCH DETAILS
  /// =============================================================

  void _openBatch(Map<String, dynamic> batch) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AdminVendorBatchDetailsScreen(batch: batch),
      ),
    ).then((_) {
      _loadBatches();
    });
  }

  /// BUILD
  /// =============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,

      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          "Service Batches",
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            onPressed: _loadBatches,
            icon: const Icon(Icons.refresh, color: Colors.black),
          ),
        ],
      ),

      body: loading
          ? const Center(child: CircularProgressIndicator(color: primaryColor))
          : batches.isEmpty
          ? _emptyView()
          : RefreshIndicator(
              onRefresh: _loadBatches,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: batches.length,
                itemBuilder: (context, index) {
                  return _batchCard(batches[index]);
                },
              ),
            ),

      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  /// =============================================================
  /// BATCH CARD
  /// =============================================================

  Widget _batchCard(Map<String, dynamic> batch) {
    final String serviceName = batch["serviceName"]?.toString() ?? "Service";

    final String apartmentName =
        batch["apartmentName"]?.toString() ?? "Apartment";

    final String address =
        batch["address"]?.toString() ?? "Address not available";

    final String status = batch["status"]?.toString() ?? "collecting";

    int flatCount = 0;

    final participants = batch["participants"];

    if (participants is Map) {
      flatCount = participants.length;
    }

    int bidCount = 0;

    final bids = batch["bids"];

    if (bids is Map) {
      bidCount = bids.length;
    }

    return GestureDetector(
      onTap: () => _openBatch(batch),

      child: Container(
        margin: const EdgeInsets.only(bottom: 16),

        padding: const EdgeInsets.all(18),

        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),

          boxShadow: const [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,

          children: [
            /// SERVICE + ICON
            Row(
              children: [
                Container(
                  height: 54,
                  width: 54,

                  decoration: BoxDecoration(
                    color: primaryColor.withOpacity(.10),
                    borderRadius: BorderRadius.circular(16),
                  ),

                  child: const Icon(
                    Icons.build_circle_outlined,
                    color: primaryColor,
                    size: 30,
                  ),
                ),

                const SizedBox(width: 13),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,

                    children: [
                      Text(
                        serviceName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 4),

                      Text(
                        apartmentName,
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),

                _statusChip(status),
              ],
            ),

            const SizedBox(height: 15),

            /// ADDRESS
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,

              children: [
                const Icon(
                  Icons.location_on_outlined,
                  color: primaryColor,
                  size: 20,
                ),

                const SizedBox(width: 7),

                Expanded(
                  child: Text(
                    address,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,

                    style: const TextStyle(
                      color: Colors.grey,
                      height: 1.35,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            /// STATS
            Row(
              children: [
                Expanded(
                  child: _cardStat(Icons.home_outlined, "$flatCount", "Flats"),
                ),

                const SizedBox(width: 10),

                Expanded(child: _cardStat(Icons.gavel, "$bidCount", "Bids")),

                const SizedBox(width: 10),

                Expanded(
                  child: _cardStat(
                    Icons.people_outline,
                    "${batch["requestCount"] ?? flatCount}",
                    "Requests",
                  ),
                ),
              ],
            ),

            const SizedBox(height: 15),

            /// OPEN DETAILS
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 11),

              decoration: BoxDecoration(
                color: primaryColor.withOpacity(.07),
                borderRadius: BorderRadius.circular(12),
              ),

              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,

                children: [
                  Text(
                    "View Batch Details",
                    style: TextStyle(
                      color: primaryColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  SizedBox(width: 6),

                  Icon(Icons.arrow_forward, size: 18, color: primaryColor),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _cardStat(IconData icon, String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),

      decoration: BoxDecoration(
        color: const Color(0xffF8FAFC),
        borderRadius: BorderRadius.circular(12),
      ),

      child: Column(
        children: [
          Icon(icon, size: 19, color: primaryColor),

          const SizedBox(height: 4),

          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),

          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 10)),
        ],
      ),
    );
  }

  Widget _statusChip(String status) {
    Color color = Colors.orange;

    if (status == "vendor_selected") {
      color = Colors.blue;
    } else if (status == "completed") {
      color = Colors.green;
    } else if (status == "cancelled") {
      color = Colors.red;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),

      decoration: BoxDecoration(
        color: color.withOpacity(.10),
        borderRadius: BorderRadius.circular(10),
      ),

      child: Text(
        status.replaceAll("_", " ").toUpperCase(),

        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _emptyView() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,

        children: [
          Icon(Icons.inventory_2_outlined, size: 60, color: Colors.grey),

          SizedBox(height: 12),

          Text(
            "No service batches found",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  /// =============================================================
  /// ADMIN BOTTOM NAVIGATION
  /// =============================================================

  Widget _buildBottomNavigationBar() {
    return BottomNavigationBar(
      currentIndex: 1,

      type: BottomNavigationBarType.fixed,

      selectedItemColor: primaryColor,

      unselectedItemColor: Colors.grey,

      onTap: (index) {
        if (index == 1) {
          return;
        }

        if (index == 2) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const AdminAcceptedVendorsScreen(),
            ),
          );
        }
        if (index == 0) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const AdminDashboardScreen(),
            ),
          );
        }
      },

      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.dashboard_outlined),
          label: "Dashboard",
        ),

        BottomNavigationBarItem(
          icon: Icon(Icons.inventory_2_outlined),
          label: "Batches",
        ),

        BottomNavigationBarItem(
          icon: Icon(Icons.handshake_outlined),
          label: "Accepted",
        ),
      ],
    );
  }

  void _showMessage(String message, Color color) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message), backgroundColor: color));
  }
}

/// =================================================================
/// ADMIN VENDOR BATCH DETAILS
/// =================================================================

class AdminVendorBatchDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> batch;

  const AdminVendorBatchDetailsScreen({super.key, required this.batch});

  @override
  State<AdminVendorBatchDetailsScreen> createState() =>
      _AdminVendorBatchDetailsScreenState();
}

class _AdminVendorBatchDetailsScreenState
    extends State<AdminVendorBatchDetailsScreen> {
  static const Color primaryColor = Color(0xff2563EB);

  static const Color secondaryColor = Color(0xff0EA5E9);

  static const Color backgroundColor = Color(0xffF8FAFC);

  final DatabaseReference database = FirebaseDatabase.instance.ref();

  bool loading = true;

  bool selectingVendor = false;

  Map<String, dynamic> batch = {};

  List<Map<String, dynamic>> participants = [];

  List<Map<String, dynamic>> bids = [];

  @override
  void initState() {
    super.initState();

    batch = Map<String, dynamic>.from(widget.batch);

    _loadBatch();
  }
  Future<void> _loadParticipantDetails(
  Map<String, dynamic> participant,
) async {
  final uid = participant["uid"]?.toString();

  if (uid == null || uid.isEmpty) {
    _showMessage(
      "Resident UID is missing.",
      Colors.red,
    );
    return;
  }

  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) {
      return const Center(
        child: CircularProgressIndicator(
          color: primaryColor,
        ),
      );
    },
  );

  try {
    final snapshot = await database
        .child("users")
        .child(uid)
        .get();

    if (!mounted) return;

    Navigator.pop(context);

    debugPrint("======================================");
    debugPrint("Participant UID: $uid");
    debugPrint("User exists: ${snapshot.exists}");
    debugPrint("User value: ${snapshot.value}");
    debugPrint("======================================");

    if (!snapshot.exists || snapshot.value == null) {
      _showMessage(
        "No user found for UID: $uid",
        Colors.red,
      );
      return;
    }

    if (snapshot.value is! Map) {
      _showMessage(
        "Invalid user data for UID: $uid",
        Colors.red,
      );
      return;
    }

    final userData = Map<String, dynamic>.from(
      snapshot.value as Map,
    );

    debugPrint("USER DATA = $userData");

    debugPrint(
      "NAME = ${userData["name"]}",
    );

    debugPrint(
      "PHONE = ${userData["phone"]}",
    );

    debugPrint(
      "EMAIL = ${userData["email"]}",
    );

    _showParticipantDetails(
      participant,
      userData,
    );
  } catch (e) {
    if (mounted) {
      Navigator.pop(context);

      _showMessage(
        "Error loading resident details: $e",
        Colors.red,
      );
    }

    debugPrint(
      "ERROR FETCHING USER DETAILS: $e",
    );
  }
} /// =============================================================
 

  /// =============================================================
  /// BATCH REFERENCE
  /// =============================================================

  DatabaseReference get batchRef {
    final apartmentKey = batch["apartmentKey"]?.toString() ?? "";

    final serviceId = batch["serviceId"]?.toString() ?? "";

    return database
        .child("societyServiceBatches")
        .child(apartmentKey)
        .child(serviceId);
  }

  /// =============================================================
  /// LOAD COMPLETE BATCH
  /// =============================================================

  Future<void> _loadBatch() async {
    try {
      final snapshot = await batchRef.get();

      if (!snapshot.exists || snapshot.value == null) {
        if (!mounted) return;

        setState(() {
          loading = false;
        });

        return;
      }

      final data = Map<String, dynamic>.from(snapshot.value as Map);

      final participantList = <Map<String, dynamic>>[];

      final participantData = data["participants"];

      if (participantData is Map) {
        participantData.forEach((uid, value) {
          if (value is Map) {
            participantList.add({
              "uid": uid.toString(),
              ...Map<String, dynamic>.from(value),
            });
          }
        });
      }

      final bidList = <Map<String, dynamic>>[];

      final bidData = data["bids"];

      if (bidData is Map) {
        bidData.forEach((vendorId, value) {
          if (value is Map) {
            bidList.add({
              "vendorId": vendorId.toString(),

              ...Map<String, dynamic>.from(value),
            });
          }
        });
      }

      /// Sort lowest bid first
      bidList.sort((a, b) {
        final amountA =
            double.tryParse(a["bidAmount"]?.toString() ?? "") ??
            double.infinity;

        final amountB =
            double.tryParse(b["bidAmount"]?.toString() ?? "") ??
            double.infinity;

        return amountA.compareTo(amountB);
      });

      if (!mounted) return;

      setState(() {
        batch = data;

        participants = participantList;

        bids = bidList;

        loading = false;
      });
    } catch (e) {
      debugPrint("LOAD BATCH DETAILS ERROR: $e");

      if (!mounted) return;

      setState(() {
        loading = false;
      });
    }
  }

  /// =============================================================
  /// SELECT VENDOR
  /// =============================================================

  Future<void> _selectVendor(Map<String, dynamic> bid) async {
    final vendorId = bid["vendorId"]?.toString();

    if (vendorId == null || vendorId.isEmpty) {
      _showMessage("Vendor ID not found.", Colors.red);

      return;
    }

    final vendorName = bid["vendorName"]?.toString().trim();

    final confirm = await showDialog<bool>(
      context: context,

      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),

          title: const Text(
            "Select Vendor?",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),

          content: Column(
            mainAxisSize: MainAxisSize.min,

            crossAxisAlignment: CrossAxisAlignment.start,

            children: [
              Text(
                "You are selecting:",
                style: const TextStyle(color: Colors.grey),
              ),

              const SizedBox(height: 8),

              Text(
                vendorName == null || vendorName.isEmpty
                    ? "Vendor"
                    : vendorName,

                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 15),

              Text("Bid Amount: ₹${bid["bidAmount"] ?? "0"}"),

              const SizedBox(height: 5),

              Text(
                "Completion: "
                "${bid["completionDate"] ?? "N/A"}",
              ),

              const SizedBox(height: 5),

              Text(
                "Time: "
                "${bid["completionTime"] ?? "N/A"}",
              ),

              const SizedBox(height: 15),

              const Text(
                "All other vendor bids will be rejected.",
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),

          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },

              child: const Text("Cancel"),
            ),

            ElevatedButton(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },

              style: ElevatedButton.styleFrom(backgroundColor: primaryColor),

              child: const Text(
                "Select Vendor",
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    setState(() {
      selectingVendor = true;
    });

    try {
      /// ---------------------------------------------------------
      /// IMPORTANT
      /// We use Firebase multi-location update.
      /// This keeps the batch state consistent.
      /// ---------------------------------------------------------

      final updates = <String, dynamic>{};

      final apartmentKey = batch["apartmentKey"]?.toString() ?? "";

      final serviceId = batch["serviceId"]?.toString() ?? "";

      final batchPath =
          "societyServiceBatches/"
          "$apartmentKey/"
          "$serviceId";

      /// ---------------------------------------------------------
      /// SELECTED VENDOR DATA
      /// ---------------------------------------------------------

      updates["$batchPath/selectedVendor"] = {
        "vendorId": vendorId,

        "vendorName": bid["vendorName"] ?? "",

        "phone": bid["phone"] ?? "",

        "email": bid["email"] ?? "",

        "bidAmount": bid["bidAmount"] ?? 0,

        "completionDate": bid["completionDate"] ?? "",

        "completionTime": bid["completionTime"] ?? "",

        "message": bid["message"] ?? "",

        "selectedAt": ServerValue.timestamp,

        "status": "waiting_vendor_acceptance",
      };

      /// ---------------------------------------------------------
      /// UPDATE SELECTED BID
      /// ---------------------------------------------------------

      updates["$batchPath/bids/$vendorId/status"] = "selected";

      updates["$batchPath/bids/$vendorId/selectedAt"] = ServerValue.timestamp;

      /// ---------------------------------------------------------
      /// REJECT EVERY OTHER BID
      /// ---------------------------------------------------------

      for (final otherBid in bids) {
        final otherVendorId = otherBid["vendorId"]?.toString();

        if (otherVendorId == null || otherVendorId.isEmpty) {
          continue;
        }

        if (otherVendorId != vendorId) {
          updates["$batchPath/bids/"
                  "$otherVendorId/status"] =
              "rejected";

          updates["$batchPath/bids/"
                  "$otherVendorId/rejectedAt"] =
              ServerValue.timestamp;
        }
      }

      /// ---------------------------------------------------------
      /// UPDATE BATCH
      /// ---------------------------------------------------------

      updates["$batchPath/status"] = "vendor_selected";

      updates["$batchPath/selectedVendorId"] = vendorId;

      updates["$batchPath/updatedAt"] = ServerValue.timestamp;

      /// ---------------------------------------------------------
      /// VENDOR ACCEPTANCE RECORD
      /// ---------------------------------------------------------

      final acceptanceId = "${apartmentKey}_$serviceId";

      updates["vendorAcceptedBatches/"
          "$vendorId/"
          "$acceptanceId"] = {
        "batchId": "$apartmentKey-$serviceId",

        "apartmentKey": apartmentKey,

        "serviceId": serviceId,

        "serviceName": batch["serviceName"] ?? "",

        "apartmentName": batch["apartmentName"] ?? "",

        "address": batch["address"] ?? "",

        "latitude": batch["latitude"] ?? 0,

        "longitude": batch["longitude"] ?? 0,

        "vendorId": vendorId,

        "vendorName": bid["vendorName"] ?? "",

        "phone": bid["phone"] ?? "",

        "email": bid["email"] ?? "",

        "bidAmount": bid["bidAmount"] ?? 0,

        "completionDate": bid["completionDate"] ?? "",

        "completionTime": bid["completionTime"] ?? "",

        "message": bid["message"] ?? "",

        "status": "waiting_vendor_acceptance",

        "createdAt": ServerValue.timestamp,

        "updatedAt": ServerValue.timestamp,
      };

      /// ---------------------------------------------------------
      /// WRITE EVERYTHING
      /// ---------------------------------------------------------

      await database.update(updates);

      if (!mounted) return;

      setState(() {
        selectingVendor = false;
      });

      _showMessage("Vendor selected successfully.", Colors.green);

      await _loadBatch();
    } catch (e) {
      debugPrint("SELECT VENDOR ERROR: $e");

      if (!mounted) return;

      setState(() {
        selectingVendor = false;
      });

      _showMessage("Unable to select vendor.", Colors.red);
    }
  }

  /// =============================================================
  /// BUILD
  /// =============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,

      appBar: AppBar(
        backgroundColor: Colors.white,

        elevation: 0,

        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),

          onPressed: () {
            Navigator.pop(context);
          },
        ),

        title: const Text(
          "Batch Details",
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
      ),

      body: loading
          ? const Center(child: CircularProgressIndicator(color: primaryColor))
          : RefreshIndicator(
              onRefresh: _loadBatch,

              child: ListView(
                padding: const EdgeInsets.all(16),

                children: [
                  /// SERVICE INFORMATION
                  _buildServiceCard(),

                  const SizedBox(height: 16),

                  /// BATCH SUMMARY
                  _buildSummaryCard(),

                  const SizedBox(height: 16),

                  /// FLATS
                  _buildParticipants(),

                  const SizedBox(height: 16),

                  /// BIDS
                  _buildBids(),

                  const SizedBox(height: 25),
                ],
              ),
            ),

      bottomNavigationBar: _buildBottomNavigation(),
    );
  }

  /// =============================================================
  /// SERVICE CARD
  /// =============================================================

  Widget _buildServiceCard() {
    return Container(
      padding: const EdgeInsets.all(20),

      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [primaryColor, secondaryColor]),

        borderRadius: BorderRadius.circular(24),
      ),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          Row(
            children: [
              Container(
                height: 52,
                width: 52,

                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(15),
                ),

                child: const Icon(
                  Icons.build_circle,
                  color: Colors.white,
                  size: 30,
                ),
              ),

              const SizedBox(width: 13),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,

                  children: [
                    const Text(
                      "SERVICE BATCH",
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 4),

                    Text(
                      batch["serviceName"]?.toString() ?? "Service",

                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 23,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          Text(
            batch["apartmentName"]?.toString() ?? "Apartment",

            style: const TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w600,
            ),
          ),

          const SizedBox(height: 8),

          Row(
            crossAxisAlignment: CrossAxisAlignment.start,

            children: [
              const Icon(Icons.location_on, color: Colors.white70, size: 18),

              const SizedBox(width: 6),

              Expanded(
                child: Text(
                  batch["address"]?.toString() ?? "Address not available",

                  style: const TextStyle(
                    color: Colors.white70,
                    height: 1.4,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// =============================================================
  /// SUMMARY
  /// =============================================================

  Widget _buildSummaryCard() {
    return _sectionCard(
      title: "Batch Overview",

      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _overviewStat(
                  Icons.home_outlined,
                  participants.length.toString(),
                  "Flats",
                ),
              ),

              Expanded(
                child: _overviewStat(
                  Icons.people_outline,
                  participants.length.toString(),
                  "Residents",
                ),
              ),

              Expanded(
                child: _overviewStat(
                  Icons.gavel,
                  bids.length.toString(),
                  "Vendor Bids",
                ),
              ),
            ],
          ),

          const SizedBox(height: 15),

          const Divider(),

          const SizedBox(height: 8),

          Row(
            children: [
              const Icon(Icons.info_outline, color: Colors.grey, size: 18),

              const SizedBox(width: 8),

              Expanded(
                child: Text(
                  "Batch status: "
                  "${batch["status"] ?? "collecting"}",

                  style: const TextStyle(color: Colors.grey, fontSize: 13),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _overviewStat(IconData icon, String value, String label) {
    return Column(
      children: [
        Icon(icon, color: primaryColor, size: 25),

        const SizedBox(height: 5),

        Text(
          value,
          style: const TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
        ),

        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 11)),
      ],
    );
  }

  /// =============================================================
  /// PARTICIPANTS / FLATS
  /// =============================================================

  Widget _buildParticipants() {
    return _sectionCard(
      title: "Requested Flats (${participants.length})",

      child: participants.isEmpty
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 15),

              child: Text(
                "No flat information available.",
                style: TextStyle(color: Colors.grey),
              ),
            )
          : Column(
              children: participants.map((participant) {
                return _participantCard(participant);
              }).toList(),
            ),
    );
  }

  Widget _participantCard(Map<String, dynamic> participant) {
    final flatNumber =
        participant["flatNumber"]?.toString() ??
        participant["flatNo"]?.toString() ??
        participant["flat"]?.toString() ??
        "N/A";
    final residentName =
        participant["name"]?.toString() ??
        participant["userName"]?.toString() ??
        participant["residentName"]?.toString() ??
        "Resident";

    return InkWell(
       onTap: () => _loadParticipantDetails(participant),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xffF8FAFC),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xffE2E8F0)),
        ),
        child: Row(
          children: [
            const Icon(Icons.home_outlined, color: primaryColor),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Flat $flatNumber",
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    residentName,
                    style: const TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  void _showParticipantDetails(
    Map<String, dynamic> participant,
    Map<String, dynamic> userData,
  ) {
    // =========================================================
    // PARTICIPANT DATA
    // =========================================================

    final flatNumber =
        participant["flatNumber"]?.toString() ??
        participant["flatNo"]?.toString() ??
        participant["flat"]?.toString() ??
        userData["apartment"]?["flatNumber"]?.toString() ??
        "N/A";

    final address =
        participant["address"]?.toString() ??
        userData["apartment"]?["address"]?.toString() ??
        "Not available";

    final selectedDate =
        participant["selectedDate"]?.toString() ?? "Not selected";

    final timeSlot = participant["timeSlot"]?.toString() ?? "Not selected";

    final serviceName =
        participant["serviceName"]?.toString() ??
        participant["service"]?.toString() ??
        "Service";

    // =========================================================
    // USER DATA
    // =========================================================

   final residentName =
    userData["name"]?.toString().trim().isNotEmpty == true
        ? userData["name"].toString()
        : "Resident";
   final phone =
    userData["phone"]?.toString().trim().isNotEmpty == true
        ? userData["phone"].toString()
        : "Not available";

  final email =
    userData["email"]?.toString().trim().isNotEmpty == true
        ? userData["email"].toString()
        : "Not available";

    final job = userData["job"]?.toString() ?? "Not available";

    final userUid =
        userData["uid"]?.toString() ?? participant["uid"]?.toString() ?? "N/A";

    // =========================================================
    // MODAL
    // =========================================================

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,

      builder: (sheetContext) {
        return Container(
          height: MediaQuery.of(sheetContext).size.height * 0.85,

          decoration: const BoxDecoration(
            color: Colors.white,

            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(28),
              topRight: Radius.circular(28),
            ),
          ),

          child: Column(
            children: [
              // =================================================
              // HANDLE
              // =================================================
              const SizedBox(height: 10),

              Container(
                height: 4,
                width: 45,

                decoration: BoxDecoration(
                  color: const Color(0xffCBD5E1),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),

              const SizedBox(height: 18),

              // =================================================
              // HEADER
              // =================================================
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),

                child: Row(
                  children: [
                    // Resident avatar
                    Container(
                      height: 58,
                      width: 58,

                      decoration: BoxDecoration(
                        color: const Color(0xffDBEAFE),

                        borderRadius: BorderRadius.circular(18),
                      ),

                      child: const Icon(
                        Icons.person_rounded,
                        color: primaryColor,
                        size: 30,
                      ),
                    ),

                    const SizedBox(width: 14),

                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,

                        children: [
                          Text(
                            residentName,

                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Color(0xff0F172A),
                            ),
                          ),

                          const SizedBox(height: 4),

                          Text(
                            "Flat $flatNumber",

                            style: const TextStyle(
                              fontSize: 13,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Close
                    GestureDetector(
                      onTap: () {
                        Navigator.pop(sheetContext);
                      },

                      child: Container(
                        height: 38,
                        width: 38,

                        decoration: BoxDecoration(
                          color: const Color(0xffF1F5F9),

                          borderRadius: BorderRadius.circular(12),
                        ),

                        child: const Icon(
                          Icons.close,
                          size: 19,
                          color: Color(0xff475569),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // =================================================
              // CONTENT
              // =================================================
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 30),

                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,

                    children: [
                      // =================================================
                      // RESIDENT INFORMATION
                      // =================================================
                      const Text(
                        "Resident Information",

                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xff0F172A),
                        ),
                      ),

                      const SizedBox(height: 12),

                      _detailCard(
                        icon: Icons.person_outline,
                        title: "Resident Name",
                        value: residentName,
                      ),

                      _detailCard(
                        icon: Icons.phone_outlined,
                        title: "Phone Number",
                        value: phone,
                      ),

                      _detailCard(
                        icon: Icons.email_outlined,
                        title: "Email Address",
                        value: email,
                      ),

                      if (job != "Not available")
                        _detailCard(
                          icon: Icons.work_outline,
                          title: "Occupation",
                          value: job,
                        ),

                      // =================================================
                      // FLAT INFORMATION
                      // =================================================
                      const SizedBox(height: 12),

                      const Text(
                        "Flat Information",

                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xff0F172A),
                        ),
                      ),

                      const SizedBox(height: 12),

                      _detailCard(
                        icon: Icons.home_outlined,
                        title: "Flat Number",
                        value: flatNumber,
                      ),

                      _detailCard(
                        icon: Icons.location_on_outlined,
                        title: "Address",
                        value: address,
                        isLongText: true,
                      ),

                      // =================================================
                      // SERVICE INFORMATION
                      // =================================================
                      const SizedBox(height: 12),

                      const Text(
                        "Service Request",

                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xff0F172A),
                        ),
                      ),

                      const SizedBox(height: 12),

                      _detailCard(
                        icon: Icons.build_outlined,
                        title: "Service",
                        value: serviceName,
                      ),

                      Row(
                        children: [
                          Expanded(
                            child: _smallInfoCard(
                              icon: Icons.calendar_today_outlined,
                              title: "Date",
                              value: selectedDate,
                            ),
                          ),

                          const SizedBox(width: 10),

                          Expanded(
                            child: _smallInfoCard(
                              icon: Icons.access_time_outlined,
                              title: "Time",
                              value: timeSlot,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 18),

                      // =================================================
                      // PARTICIPATION STATUS
                      // =================================================
                      Container(
                        width: double.infinity,

                        padding: const EdgeInsets.all(15),

                        decoration: BoxDecoration(
                          color: const Color(0xffF0FDF4),

                          borderRadius: BorderRadius.circular(16),

                          border: Border.all(color: const Color(0xffBBF7D0)),
                        ),

                        child: Row(
                          children: [
                            Container(
                              height: 40,
                              width: 40,

                              decoration: BoxDecoration(
                                color: const Color(0xffDCFCE7),

                                borderRadius: BorderRadius.circular(11),
                              ),

                              child: const Icon(
                                Icons.check_circle_outline,
                                color: Colors.green,
                                size: 22,
                              ),
                            ),

                            const SizedBox(width: 12),

                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,

                                children: [
                                  Text(
                                    "Participating in this batch",

                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      color: Color(0xff166534),
                                    ),
                                  ),

                                  SizedBox(height: 3),

                                  Text(
                                    "This resident has requested this service.",

                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Color(0xff15803D),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // =================================================
                      // UID - OPTIONAL
                      // =================================================
                      Container(
                        width: double.infinity,

                        padding: const EdgeInsets.all(12),

                        decoration: BoxDecoration(
                          color: const Color(0xffF8FAFC),

                          borderRadius: BorderRadius.circular(12),
                        ),

                        child: Text(
                          "Resident ID: $userUid",

                          style: const TextStyle(
                            fontSize: 10,
                            color: Colors.grey,
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
      },
    );
  }

  bool _hasValue(dynamic value) {
    return value != null && value.toString().trim().isNotEmpty;
  }

  Widget _detailCard({
    required IconData icon,
    required String title,
    required String value,
    bool isLongText = false,
  }) {
    return Container(
      width: double.infinity,

      margin: const EdgeInsets.only(bottom: 10),

      padding: const EdgeInsets.all(14),

      decoration: BoxDecoration(
        color: const Color(0xffF8FAFC),

        borderRadius: BorderRadius.circular(15),

        border: Border.all(color: const Color(0xffE2E8F0)),
      ),

      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          Container(
            height: 40,
            width: 40,

            decoration: BoxDecoration(
              color: const Color(0xffDBEAFE),

              borderRadius: BorderRadius.circular(11),
            ),

            child: Icon(icon, color: primaryColor, size: 20),
          ),

          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,

              children: [
                Text(
                  title,

                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),

                const SizedBox(height: 4),

                Text(
                  value,

                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xff0F172A),
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

  Widget _smallInfoCard({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),

      decoration: BoxDecoration(
        color: const Color(0xffF8FAFC),

        borderRadius: BorderRadius.circular(15),

        border: Border.all(color: const Color(0xffE2E8F0)),
      ),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          Icon(icon, color: primaryColor, size: 21),

          const SizedBox(height: 8),

          Text(title, style: const TextStyle(fontSize: 10, color: Colors.grey)),

          const SizedBox(height: 3),

          Text(
            value,

            maxLines: 2,
            overflow: TextOverflow.ellipsis,

            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  /// =============================================================
  /// BIDS
  /// =============================================================

  Widget _buildBids() {
    return _sectionCard(
      title: "Vendor Bids (${bids.length})",

      child: bids.isEmpty
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),

              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.gavel, size: 45, color: Colors.grey),

                    SizedBox(height: 8),

                    Text(
                      "No vendors have submitted bids yet.",
                      textAlign: TextAlign.center,

                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
            )
          : Column(
              children: bids.map((bid) {
                return _bidCard(bid);
              }).toList(),
            ),
    );
  }

  /// =============================================================
  /// BID CARD
  /// =============================================================

  Widget _bidCard(Map<String, dynamic> bid) {
    final status = bid["status"]?.toString() ?? "pending";

    final vendorName = bid["vendorName"]?.toString().trim().isEmpty ?? true
        ? "Vendor"
        : bid["vendorName"].toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 14),

      padding: const EdgeInsets.all(16),

      decoration: BoxDecoration(
        color: Colors.white,

        borderRadius: BorderRadius.circular(18),

        border: Border.all(color: const Color(0xffE2E8F0)),

        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 5)],
      ),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          /// VENDOR HEADER
          Row(
            children: [
              CircleAvatar(
                radius: 24,

                backgroundColor: const Color(0xffDBEAFE),

                child: const Icon(
                  Icons.storefront_outlined,
                  color: primaryColor,
                ),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,

                  children: [
                    Text(
                      vendorName,

                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),

                    const SizedBox(height: 3),

                    Text(
                      "Vendor ID: "
                      "${bid["vendorId"] ?? "N/A"}",

                      style: const TextStyle(color: Colors.grey, fontSize: 10),
                    ),
                  ],
                ),
              ),

              Column(
                crossAxisAlignment: CrossAxisAlignment.end,

                children: [
                  const Text(
                    "BID",
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  Text(
                    "₹${bid["bidAmount"] ?? "0"}",

                    style: const TextStyle(
                      color: primaryColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 21,
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 14),

          const Divider(),

          const SizedBox(height: 10),

          /// PHONE
          _bidInfoRow(
            Icons.phone_outlined,
            "Phone",
            bid["phone"]?.toString() ?? "Not available",
          ),

          const SizedBox(height: 9),

          /// EMAIL
          _bidInfoRow(
            Icons.email_outlined,
            "Email",
            bid["email"]?.toString() ?? "Not available",
          ),

          const SizedBox(height: 9),

          /// DATE
          _bidInfoRow(
            Icons.calendar_month_outlined,
            "Completion Date",
            bid["completionDate"]?.toString() ?? "Not available",
          ),

          const SizedBox(height: 9),

          /// TIME
          _bidInfoRow(
            Icons.access_time_outlined,
            "Completion Time",
            bid["completionTime"]?.toString() ?? "Not available",
          ),

          if ((bid["message"]?.toString() ?? "").trim().isNotEmpty) ...[
            const SizedBox(height: 12),

            Container(
              width: double.infinity,

              padding: const EdgeInsets.all(12),

              decoration: BoxDecoration(
                color: const Color(0xffF8FAFC),
                borderRadius: BorderRadius.circular(12),
              ),

              child: Text(
                bid["message"].toString(),
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ),
          ],

          const SizedBox(height: 13),

          _bidStatus(status),

          /// SELECT BUTTON
          if (status == "pending") ...[
            const SizedBox(height: 13),

            SizedBox(
              width: double.infinity,
              height: 48,

              child: ElevatedButton.icon(
                onPressed: selectingVendor
                    ? null
                    : () {
                        _selectVendor(bid);
                      },

                icon: selectingVendor
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(
                        Icons.check_circle_outline,
                        color: Colors.white,
                      ),

                label: Text(
                  selectingVendor ? "Selecting..." : "Select This Vendor",

                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,

                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(13),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _bidInfoRow(IconData icon, String title, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,

      children: [
        Icon(icon, size: 18, color: Colors.grey),

        const SizedBox(width: 9),

        SizedBox(
          width: 105,

          child: Text(
            title,
            style: const TextStyle(color: Colors.grey, fontSize: 12),
          ),
        ),

        Expanded(
          child: Text(
            value,

            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }

  Widget _bidStatus(String status) {
    Color color;

    switch (status) {
      case "selected":
        color = Colors.green;
        break;

      case "rejected":
      case "not_selected":
        color = Colors.red;
        break;

      default:
        color = Colors.orange;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),

      decoration: BoxDecoration(
        color: color.withOpacity(.10),

        borderRadius: BorderRadius.circular(8),
      ),

      child: Text(
        status.replaceAll("_", " ").toUpperCase(),

        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 9,
        ),
      ),
    );
  }

  /// =============================================================
  /// SECTION CARD
  /// =============================================================

  Widget _sectionCard({required String title, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(17),

      decoration: BoxDecoration(
        color: Colors.white,

        borderRadius: BorderRadius.circular(20),

        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          Text(
            title,

            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 14),

          child,
        ],
      ),
    );
  }

  /// =============================================================
  /// ADMIN BOTTOM NAV
  /// =============================================================

  Widget _buildBottomNavigation() {
    return BottomNavigationBar(
      currentIndex: 1,

      type: BottomNavigationBarType.fixed,

      selectedItemColor: primaryColor,

      unselectedItemColor: Colors.grey,

      onTap: (index) {
        if (index == 2) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => const AdminAcceptedVendorsScreen(),
            ),
          );
        }
      },

      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.dashboard_outlined),
          label: "Dashboard",
        ),

        BottomNavigationBarItem(
          icon: Icon(Icons.inventory_2_outlined),
          label: "Batches",
        ),

        BottomNavigationBarItem(
          icon: Icon(Icons.handshake_outlined),
          label: "Accepted",
        ),
      ],
    );
  }

  void _showMessage(String message, Color color) {
    if (!mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message), backgroundColor: color));
  }
}

/// =================================================================
/// ADMIN ACCEPTED VENDORS SCREEN
/// =================================================================
///
/// This page shows vendors selected by Servora Admin.
///
/// Firebase:
///
/// vendorAcceptedBatches
///   └── vendorId
///        └── apartment_service
///             ├── serviceName
///             ├── apartmentName
///             ├── bidAmount
///             ├── completionDate
///             ├── completionTime
///             └── status
///
/// =================================================================

class AdminAcceptedVendorsScreen extends StatefulWidget {
  const AdminAcceptedVendorsScreen({super.key});

  @override
  State<AdminAcceptedVendorsScreen> createState() =>
      _AdminAcceptedVendorsScreenState();
}

class _AdminAcceptedVendorsScreenState
    extends State<AdminAcceptedVendorsScreen> {
  static const Color primaryColor = Color(0xff2563EB);

  static const Color backgroundColor = Color(0xffF8FAFC);

  final DatabaseReference database = FirebaseDatabase.instance.ref();

  bool loading = true;

  List<Map<String, dynamic>> acceptedVendors = [];

  @override
  void initState() {
    super.initState();

    _loadAcceptedVendors();
  }

  /// =============================================================
  /// LOAD ACCEPTED VENDORS
  /// =============================================================

  Future<void> _loadAcceptedVendors() async {
    try {
      final snapshot = await database.child("vendorAcceptedBatches").get();

      final result = <Map<String, dynamic>>[];

      if (snapshot.exists && snapshot.value is Map) {
        final vendorData = Map<String, dynamic>.from(snapshot.value as Map);

        vendorData.forEach((vendorId, batchesValue) {
          if (batchesValue is! Map) {
            return;
          }

          final batches = Map<String, dynamic>.from(batchesValue);

          batches.forEach((batchId, value) {
            if (value is Map) {
              result.add({
                "vendorId": vendorId.toString(),

                "batchId": batchId.toString(),

                ...Map<String, dynamic>.from(value),
              });
            }
          });
        });
      }

      result.sort((a, b) {
        final aTime = int.tryParse(a["updatedAt"]?.toString() ?? "") ?? 0;

        final bTime = int.tryParse(b["updatedAt"]?.toString() ?? "") ?? 0;

        return bTime.compareTo(aTime);
      });

      if (!mounted) return;

      setState(() {
        acceptedVendors = result;

        loading = false;
      });
    } catch (e) {
      debugPrint("LOAD ACCEPTED VENDORS ERROR: $e");

      if (!mounted) return;

      setState(() {
        loading = false;
      });
    }
  }

  /// =============================================================
  /// BUILD
  /// =============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,

      appBar: AppBar(
        backgroundColor: Colors.white,

        elevation: 0,

        title: const Text(
          "Accepted Vendors",
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),

        actions: [
          IconButton(
            onPressed: _loadAcceptedVendors,

            icon: const Icon(Icons.refresh, color: Colors.black),
          ),
        ],
      ),

      body: loading
          ? const Center(child: CircularProgressIndicator(color: primaryColor))
          : acceptedVendors.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,

                children: [
                  Icon(Icons.handshake_outlined, size: 60, color: Colors.grey),

                  SizedBox(height: 12),

                  Text(
                    "No vendors selected yet.",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadAcceptedVendors,

              child: ListView.builder(
                padding: const EdgeInsets.all(16),

                itemCount: acceptedVendors.length,

                itemBuilder: (context, index) {
                  return _acceptedCard(acceptedVendors[index]);
                },
              ),
            ),

      bottomNavigationBar: _bottomNavigation(),
    );
  }

  /// =============================================================
  /// ACCEPTED VENDOR CARD
  /// =============================================================

  Widget _acceptedCard(Map<String, dynamic> data) {
    final status = data["status"]?.toString() ?? "waiting_vendor_acceptance";

    Color statusColor = Colors.orange;

    if (status == "accepted") {
      statusColor = Colors.green;
    } else if (status == "rejected") {
      statusColor = Colors.red;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 15),

      padding: const EdgeInsets.all(17),

      decoration: BoxDecoration(
        color: Colors.white,

        borderRadius: BorderRadius.circular(20),

        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 7)],
      ),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 25,

                backgroundColor: const Color(0xffDBEAFE),

                child: const Icon(
                  Icons.storefront_outlined,
                  color: primaryColor,
                ),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,

                  children: [
                    Text(
                      data["vendorName"]?.toString() ?? "Vendor",

                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),

                    const SizedBox(height: 3),

                    Text(
                      data["phone"]?.toString() ?? "Phone unavailable",

                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ],
                ),
              ),

              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),

                decoration: BoxDecoration(
                  color: statusColor.withOpacity(.10),

                  borderRadius: BorderRadius.circular(9),
                ),

                child: Text(
                  status.replaceAll("_", " ").toUpperCase(),

                  style: TextStyle(
                    color: statusColor,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 15),

          Text(
            data["serviceName"]?.toString() ?? "Service",

            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 4),

          Text(
            data["apartmentName"]?.toString() ?? "Apartment",

            style: const TextStyle(color: Colors.grey),
          ),

          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: _acceptedInfo(
                  Icons.currency_rupee,
                  "Bid",
                  "₹${data["bidAmount"] ?? "0"}",
                ),
              ),

              Expanded(
                child: _acceptedInfo(
                  Icons.calendar_month,
                  "Date",
                  data["completionDate"]?.toString() ?? "N/A",
                ),
              ),

              Expanded(
                child: _acceptedInfo(
                  Icons.access_time,
                  "Time",
                  data["completionTime"]?.toString() ?? "N/A",
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _acceptedInfo(IconData icon, String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,

      children: [
        Icon(icon, size: 17, color: primaryColor),

        const SizedBox(height: 4),

        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 10)),

        const SizedBox(height: 2),

        Text(
          value,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,

          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 11),
        ),
      ],
    );
  }

  /// =============================================================
  /// BOTTOM NAVIGATION
  /// =============================================================

  Widget _bottomNavigation() {
    return BottomNavigationBar(
      currentIndex: 2,

      type: BottomNavigationBarType.fixed,

      selectedItemColor: primaryColor,

      unselectedItemColor: Colors.grey,

      onTap: (index) {
        if (index == 1) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const AdminVendorBatchesScreen()),
          );
        }
      },

      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.dashboard_outlined),
          label: "Dashboard",
        ),

        BottomNavigationBarItem(
          icon: Icon(Icons.inventory_2_outlined),
          label: "Batches",
        ),

        BottomNavigationBarItem(
          icon: Icon(Icons.handshake_outlined),
          label: "Accepted",
        ),
      ],
    );
  }
}

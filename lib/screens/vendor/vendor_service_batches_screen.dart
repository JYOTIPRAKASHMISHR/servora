import 'dart:async';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:servora/screens/vendor/vendor_requests_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'vendor_history_screen.dart';

class VendorServiceBatchesScreen extends StatefulWidget {
  const VendorServiceBatchesScreen({
    super.key,
  });

  @override
  State<VendorServiceBatchesScreen> createState() =>
      _VendorServiceBatchesScreenState();
}

class _VendorServiceBatchesScreenState
    extends State<VendorServiceBatchesScreen> {

      bool _hasVendorAlreadyApplied(
  Map<String, dynamic> batch,
) {
  final currentUser = FirebaseAuth.instance.currentUser;

  if (currentUser == null) {
    return false;
  }

  final uid = currentUser.uid;
  final bids = batch["bids"];

  if (bids == null || bids is! Map) {
    return false;
  }

  return bids.containsKey(uid);
}
  // ============================================================
  // COLORS
  // ============================================================

  static const Color primaryColor =
      Color(0xff2563EB);

  static const Color secondaryColor =
      Color(0xff0EA5E9);

  static const Color backgroundColor =
      Color(0xffF8FAFC);

  // ============================================================
  // FIREBASE
  // ============================================================

  final DatabaseReference batchesRef =
      FirebaseDatabase.instance.ref(
    "societyServiceBatches",
  );

  StreamSubscription<DatabaseEvent>?
      batchSubscription;

  // ============================================================
  // STATE
  // ============================================================

  bool loading = true;

  int _selectedIndex = 0;

  String selectedCategory = "All";
  static const double vendorBatchRadiusKm = 20.0;

  List<Map<String, dynamic>> allBatches = [];
  double? vendorLatitude;
double? vendorLongitude;
bool locationLoading = true;

  // ============================================================
  // SERVICES
  // ============================================================

  final List<Map<String, dynamic>> categories = [
    {
      "id": "all",
      "name": "All",
      "icon": Icons.apps,
    },
    {
      "id": "ac_service",
      "name": "AC Service",
      "icon": Icons.ac_unit,
    },
    {
      "id": "ac_repair",
      "name": "AC Repair",
      "icon": Icons.build,
    },
    {
      "id": "plumbing",
      "name": "Plumbing",
      "icon": Icons.plumbing,
    },
    {
      "id": "electrical",
      "name": "Electrical",
      "icon": Icons.electrical_services,
    },
    {
      "id": "home_cleaning",
      "name": "Home Cleaning",
      "icon": Icons.cleaning_services,
    },
    {
      "id": "deep_cleaning",
      "name": "Deep Cleaning",
      "icon": Icons.cleaning_services_outlined,
    },
    {
      "id": "pest_control",
      "name": "Pest Control",
      "icon": Icons.bug_report,
    },
    {
      "id": "ro_service",
      "name": "RO Service",
      "icon": Icons.water_drop,
    },
    {
      "id": "appliance_repair",
      "name": "Appliance Repair",
      "icon": Icons.home_repair_service,
    },
    {
      "id": "painting",
      "name": "Painting",
      "icon": Icons.format_paint,
    },
    {
      "id": "car_wash",
      "name": "Car Wash",
      "icon": Icons.local_car_wash,
    },
    {
      "id": "bike_service",
      "name": "Bike Service",
      "icon": Icons.two_wheeler,
    },
    {
      "id": "massage",
      "name": "Massage",
      "icon": Icons.spa,
    },
    {
      "id": "elder_care",
      "name": "Elder Care",
      "icon": Icons.elderly,
    },
    {
      "id": "babysitting",
      "name": "Babysitting",
      "icon": Icons.child_care,
    },
    {
      "id": "home_tutor",
      "name": "Home Tutor",
      "icon": Icons.school,
    },
  ];

  // ============================================================
  // INIT
  // ============================================================

 @override
void initState() {
  super.initState();

  _initializeVendorBatches();
}
Future<void> _initializeVendorBatches() async {
  await _getVendorLocation();

  if (!mounted) return;

  listenToBatches();
}
 Future<void> _getVendorLocation() async {
  try {
    bool serviceEnabled =
        await Geolocator.isLocationServiceEnabled();

    if (!serviceEnabled) {
      debugPrint(
        "Location service is disabled.",
      );

      if (mounted) {
        setState(() {
          locationLoading = false;
        });
      }

      return;
    }

    LocationPermission permission =
        await Geolocator.checkPermission();

    if (permission ==
        LocationPermission.denied) {
      permission =
          await Geolocator.requestPermission();
    }

    if (permission ==
            LocationPermission.denied ||
        permission ==
            LocationPermission.deniedForever) {
      debugPrint(
        "Location permission denied.",
      );

      if (mounted) {
        setState(() {
          locationLoading = false;
        });
      }

      return;
    }

    final position =
        await Geolocator.getCurrentPosition(
      desiredAccuracy:
          LocationAccuracy.high,
    );

    if (!mounted) return;

    setState(() {
      vendorLatitude =
          position.latitude;

      vendorLongitude =
          position.longitude;

      locationLoading = false;
    });

    debugPrint(
      "======================================",
    );

    debugPrint(
      "VENDOR LOCATION",
    );

    debugPrint(
      "Latitude: $vendorLatitude",
    );

    debugPrint(
      "Longitude: $vendorLongitude",
    );

    debugPrint(
      "======================================",
    );
  } catch (e) {
    debugPrint(
      "GET VENDOR LOCATION ERROR: $e",
    );

    if (!mounted) return;

    setState(() {
      locationLoading = false;
    });
  }
}

double? _calculateDistanceKm({
  required double? societyLatitude,
  required double? societyLongitude,
}) {
  if (vendorLatitude == null ||
      vendorLongitude == null ||
      societyLatitude == null ||
      societyLongitude == null) {
    return null;
  }

  final distanceMeters =
      Geolocator.distanceBetween(
    vendorLatitude!,
    vendorLongitude!,
    societyLatitude,
    societyLongitude,
  );

  return distanceMeters / 1000;
}

// ============================================================
// SERVORA BATCH PRICING
// ============================================================

// Pricing rule:
// 1-5 flats   -> starting price
// 6-10 flats  -> 5% reduction
// 11-20 flats -> 10% reduction
// 21+ flats   -> 15% reduction
// The calculated price can NEVER go below the vendor minimum price.
double _calculateBatchPrice({
  required int flats,
  required double startingPrice,
  required double minimumPrice,
}) {
  if (startingPrice <= 0 || minimumPrice <= 0) {
    return 0;
  }

  if (minimumPrice > startingPrice) {
    return 0;
  }

  double price = startingPrice;

  if (flats > 20) {
    price = startingPrice * 0.85;
  } else if (flats > 10) {
    price = startingPrice * 0.90;
  } else if (flats > 5) {
    price = startingPrice * 0.95;
  }

  return price < minimumPrice ? minimumPrice : price;
}

// Recalculate THIS vendor's bid when the number of participating flats
// changes. Once the batch/this bid is locked, the price is never changed.
Future<void> _syncVendorBidPrice(
  Map<String, dynamic> batch,
) async {
  final authUser = FirebaseAuth.instance.currentUser;
  if (authUser == null) return;

  final apartmentKey = batch["apartmentKey"]?.toString() ?? "";
  final serviceId = batch["serviceId"]?.toString() ?? "";

  if (apartmentKey.isEmpty || serviceId.isEmpty) return;

  // ------------------------------------------------------------
  // 1. If batch price is already locked, DON'T change the price
  // ------------------------------------------------------------
  final bool batchPriceLocked =
      batch["priceLocked"] == true;

  if (batchPriceLocked) {
    return;
  }

  // ------------------------------------------------------------
  // 2. Get vendor bids
  // ------------------------------------------------------------
  final bids = batch["bids"];

  if (bids is! Map || !bids.containsKey(authUser.uid)) {
    return;
  }

  final rawBid = bids[authUser.uid];

  if (rawBid is! Map) {
    return;
  }

  final Map<String, dynamic> bid =
      Map<String, dynamic>.from(rawBid);

  // ------------------------------------------------------------
  // 3. If this vendor's bid is locked, don't change it
  // ------------------------------------------------------------
  if (bid["priceLocked"] == true) {
    return;
  }

  // ------------------------------------------------------------
  // 4. Read vendor's ORIGINAL pricing settings
  // ------------------------------------------------------------
  final double startingPrice =
      double.tryParse(
            bid["startingPrice"]?.toString() ?? "0",
          ) ??
          0;

  final double minimumPrice =
      double.tryParse(
            bid["minimumPrice"]?.toString() ?? "0",
          ) ??
          0;

  if (startingPrice <= 0 ||
      minimumPrice <= 0 ||
      minimumPrice > startingPrice) {
    return;
  }

  // ------------------------------------------------------------
  // 5. Get LATEST participant count
  // ------------------------------------------------------------
  final participants = batch["participants"];

  final int participantCount =
      participants is Map
          ? participants.length
          : int.tryParse(
                batch["requestCount"]?.toString() ?? "0",
              ) ??
              0;

  if (participantCount <= 0) {
    return;
  }

  // ------------------------------------------------------------
  // 6. CALCULATE PRICE
  //
  // IMPORTANT:
  // Customer does NOT calculate this.
  // Vendor side is the source of truth.
  // ------------------------------------------------------------
  final double currentPrice =
      _calculateBatchPrice(
    flats: participantCount,
    startingPrice: startingPrice,
    minimumPrice: minimumPrice,
  );

  if (currentPrice <= 0) {
    return;
  }

  // ------------------------------------------------------------
  // 7. Check old price
  // ------------------------------------------------------------
  final double oldPrice =
      double.tryParse(
            bid["currentPrice"]?.toString() ?? "0",
          ) ??
          0;

  // No Firebase update if price has not changed
  if ((oldPrice - currentPrice).abs() < 0.01) {
    return;
  }

  // ------------------------------------------------------------
  // 8. Save NEW current price
  // ------------------------------------------------------------
  try {
    await FirebaseDatabase.instance
        .ref(
          "societyServiceBatches/"
          "$apartmentKey/"
          "$serviceId/"
          "bids/${authUser.uid}",
        )
        .update({
      "currentPrice": currentPrice,
      "bidAmount": currentPrice,
      "updatedAt": ServerValue.timestamp,
    });

    debugPrint(
      "💰 PRICE UPDATED: "
      "$participantCount flats → ₹$currentPrice",
    );
  } catch (e) {
    debugPrint(
      "SYNC BID PRICE ERROR: $e",
    );
  }
}
// ============================================================
// SUBMIT VENDOR BID
// ============================================================

Future<void> _submitBid({
  required Map<String, dynamic> batch,
  required double bidAmount,
  required double startingPrice,
  required double minimumPrice,
  required DateTime completionDate,
  required String completionTime,
  required String message,
}) async {
  final authUser = FirebaseAuth.instance.currentUser;

  if (authUser == null) {
    _showMessage(
      "Please login first.",
      Colors.red,
    );
    return;
  }

  final vendorId = authUser.uid;

  final apartmentKey =
      batch["apartmentKey"]?.toString() ?? "";

  final serviceId =
      batch["serviceId"]?.toString() ?? "";

  if (apartmentKey.isEmpty || serviceId.isEmpty) {
    _showMessage(
      "Invalid batch information.",
      Colors.red,
    );
    return;
  }

  final bidRef = FirebaseDatabase.instance.ref(
    "societyServiceBatches/"
    "$apartmentKey/"
    "$serviceId/"
    "bids/"
    "$vendorId",
  );

  try {
    // ==========================================================
    // READ THE LATEST BATCH BEFORE SAVING
    // This prevents submitting a stale price if more flats joined
    // while the vendor was filling the form.
    // ==========================================================

    final batchRef = FirebaseDatabase.instance.ref(
      "societyServiceBatches/"
      "$apartmentKey/"
      "$serviceId",
    );

    final latestBatchSnapshot = await batchRef.get();

    if (!latestBatchSnapshot.exists ||
        latestBatchSnapshot.value is! Map) {
      _showMessage(
        "Batch information is no longer available.",
        Colors.red,
      );
      return;
    }

    final latestBatch = Map<String, dynamic>.from(
      latestBatchSnapshot.value as Map,
    );

    if (latestBatch["priceLocked"] == true) {
      _showMessage(
        "Work has already started. The batch price is locked.",
        Colors.orange,
      );
      return;
    }

    // ==========================================================
    // CHECK EXISTING BID
    // ==========================================================

    final existingBid = await bidRef.get();

    if (existingBid.exists) {
      _showMessage(
        "You have already submitted a bid for this batch.",
        Colors.orange,
      );
      return;
    }

    // ==========================================================
    // CALCULATE THE LATEST PRICE
    // ==========================================================

    final participants = latestBatch["participants"];
    final latestFlatCount = participants is Map
        ? participants.length
        : (int.tryParse(
              latestBatch["requestCount"]?.toString() ?? "0",
            ) ??
            0);

    final double latestBidAmount = _calculateBatchPrice(
      flats: latestFlatCount,
      startingPrice: startingPrice,
      minimumPrice: minimumPrice,
    );

    if (latestBidAmount <= 0) {
      _showMessage(
        "Unable to calculate a valid batch price.",
        Colors.red,
      );
      return;
    }

    // ==========================================================
    // GET VENDOR DETAILS FROM users/{vendorId}
    // ==========================================================

    String vendorName = "Vendor";
    String vendorEmail = "";
    String vendorPhone = "";

    final vendorSnapshot = await FirebaseDatabase.instance
        .ref("users")
        .child(vendorId)
        .get();

    if (vendorSnapshot.exists &&
        vendorSnapshot.value is Map) {
      final vendorData = Map<String, dynamic>.from(
        vendorSnapshot.value as Map,
      );

      vendorName =
          vendorData["name"]?.toString() ?? "Vendor";

      vendorEmail =
          vendorData["email"]?.toString() ?? "";

      vendorPhone =
          vendorData["phone"]?.toString() ?? "";

      debugPrint(
        "======================================",
      );
      debugPrint(
        "VENDOR ID: $vendorId",
      );
      debugPrint(
        "VENDOR NAME: $vendorName",
      );
      debugPrint(
        "VENDOR PHONE: $vendorPhone",
      );
      debugPrint(
        "VENDOR EMAIL: $vendorEmail",
      );
      debugPrint(
        "======================================",
      );
    } else {
      debugPrint(
        "Vendor data not found at users/$vendorId",
      );

      _showMessage(
        "Vendor profile not found.",
        Colors.red,
      );

      return;
    }

    // ==========================================================
    // SAVE BID
    // ==========================================================

   await bidRef.set({
  "vendorId": vendorId,
  "vendorName": vendorName,
  "phone": vendorPhone,
  "email": vendorEmail,

  // Vendor pricing
  "startingPrice": startingPrice,
  "minimumPrice": minimumPrice,
  "currentPrice": latestBidAmount,

  // Bid price at the time of bidding
  "bidAmount": latestBidAmount,

  "completionDate": _firebaseDate(completionDate),
  "completionTime": completionTime,
  "message": message,

  "status": "pending",

  "priceLocked": false,
  "lockedPrice": null,

  "createdAt": ServerValue.timestamp,
  "updatedAt": ServerValue.timestamp,
});
    // ==========================================================
    // UPDATE BATCH STATUS
    // ==========================================================

    await FirebaseDatabase.instance
        .ref(
          "societyServiceBatches/"
          "$apartmentKey/"
          "$serviceId",
        )
        .update({
      "status": "bidding",
      "updatedAt": ServerValue.timestamp,
    });

    if (!mounted) return;

    _showMessage(
      "Your bid has been submitted successfully!",
      Colors.green,
    );
  } catch (e) {
    debugPrint(
      "SUBMIT BID ERROR: $e",
    );

    if (!mounted) return;

    _showMessage(
      "Unable to submit bid. Please try again.",
      Colors.red,
    );
  }
}
// ============================================================
// OPEN SOCIETY LOCATION
// ============================================================

Future<void> _openLocation(
  double latitude,
  double longitude,
) async {
  final uri = Uri.parse(
    "https://www.google.com/maps/search/?api=1&query=$latitude,$longitude",
  );

  try {
    final launched =
        await launchUrl(
      uri,
      mode:
          LaunchMode.externalApplication,
    );

    if (!launched && mounted) {
      _showMessage(
        "Unable to open Google Maps.",
        Colors.red,
      );
    }
  } catch (e) {
    debugPrint(
      "OPEN LOCATION ERROR: $e",
    );

    if (!mounted) return;

    _showMessage(
      "Unable to open location.",
      Colors.red,
    );
  }
}

  // ============================================================
  // LISTEN TO ALL SOCIETY BATCHES
  // ============================================================

 // ============================================================
// LISTEN TO SOCIETY BATCHES WITH 20 KM RADIUS FILTER
// ============================================================

void listenToBatches() {
  batchSubscription?.cancel();

  batchSubscription =
      batchesRef.onValue.listen((event) {
    if (!mounted) return;

    if (!event.snapshot.exists ||
        event.snapshot.value == null) {
      setState(() {
        allBatches = [];
        loading = false;
      });

      return;
    }

    final raw = event.snapshot.value;

    if (raw is! Map) {
      setState(() {
        allBatches = [];
        loading = false;
      });

      return;
    }

    // ========================================================
    // IMPORTANT:
    // Vendor location must be available before
    // filtering society batches.
    // ========================================================

    if (vendorLatitude == null ||
        vendorLongitude == null) {
      debugPrint(
        "Vendor location not available yet. "
        "Cannot filter society batches.",
      );

      setState(() {
        allBatches = [];
        loading = true;
      });

      return;
    }

    final Map<String, dynamic> societies =
        Map<String, dynamic>.from(raw);

    final List<Map<String, dynamic>> batches = [];

    // ========================================================
    // SOCIETY
    // ========================================================

    societies.forEach(
      (apartmentKey, apartmentValue) {
        if (apartmentValue is! Map) {
          return;
        }

        final services =
            Map<String, dynamic>.from(
          apartmentValue,
        );

        // ====================================================
        // SERVICE BATCH
        // ====================================================

        services.forEach(
          (serviceId, serviceValue) {
            if (serviceValue is! Map) {
              return;
            }

            final batch =
                Map<String, dynamic>.from(
              serviceValue,
            );

            // ==================================================
            // GET SOCIETY LOCATION
            // ==================================================

            final double? latitude =
                _toDouble(batch["latitude"]);

            final double? longitude =
                _toDouble(batch["longitude"]);

            // ==================================================
            // LOCATION REQUIRED
            //
            // If society location is missing,
            // don't show this batch.
            // ==================================================

            if (latitude == null ||
                longitude == null) {
              debugPrint(
                "Skipping batch $serviceId: "
                "society location missing.",
              );

              return;
            }

            // ==================================================
            // CALCULATE DISTANCE
            // ==================================================

            final double? distanceKm =
                _calculateDistanceKm(
              societyLatitude: latitude,
              societyLongitude: longitude,
            );

            if (distanceKm == null) {
              return;
            }

            // ==================================================
            // 20 KM RADIUS FILTER
            //
            // Only batches within 20 KM are shown.
            // ==================================================

            if (distanceKm >
                vendorBatchRadiusKm) {
              debugPrint(
                "Skipping batch $serviceId: "
                "${distanceKm.toStringAsFixed(2)} KM away "
                "(outside 20 KM).",
              );

              return;
            }

            // ==================================================
            // PARTICIPANT COUNT
            // ==================================================

            final participants =
                batch["participants"];

            int participantCount = 0;

            if (participants is Map) {
              participantCount =
                  participants.length;
            }

            // Prefer participant count
            // over stored requestCount.
            final storedCount =
                int.tryParse(
                      batch["requestCount"]
                              ?.toString() ??
                          "0",
                    ) ??
                    0;

            final count =
                participantCount > 0
                    ? participantCount
                    : storedCount;

            // ==================================================
            // ADD ONLY 20 KM BATCHES
            // ==================================================

            batches.add({
              "batchId":
                  "$apartmentKey-$serviceId",

              "apartmentKey":
                  apartmentKey,

              "serviceId":
                  batch["serviceId"] ??
                      serviceId,

              "serviceName":
                  batch["serviceName"] ??
                      "Service",

              "apartmentName":
                  batch["apartmentName"] ??
                      apartmentKey,

              "address":
                  batch["address"] ??
                      "Address not available",

              "latitude":
                  latitude,

              "longitude":
                  longitude,

              "requestCount":
                  count,

              "status":
                  batch["status"] ??
                      "collecting",

              "createdAt":
                  batch["createdAt"],

              "updatedAt":
                  batch["updatedAt"],

              "priceLocked":
                  batch["priceLocked"] == true,

              "lockedPrice":
                  batch["lockedPrice"],

              "workStarted":
                  batch["workStarted"] == true,

              "participants":
                  participants,

              "bids":
                  batch["bids"],

              // Save distance for UI/debugging
              "distanceKm":
                  distanceKm,
            });

            // ==================================================
            // SYNC THIS VENDOR'S BID PRICE
            // ==================================================

            unawaited(
              _syncVendorBidPrice(
                batches.last,
              ),
            );
          },
        );
      },
    );

    // ========================================================
    // SORT BY NUMBER OF REQUESTS
    // ========================================================

    batches.sort(
      (a, b) {
        final countA =
            int.tryParse(
                  a["requestCount"]
                          ?.toString() ??
                      "0",
                ) ??
                0;

        final countB =
            int.tryParse(
                  b["requestCount"]
                          ?.toString() ??
                      "0",
                ) ??
                0;

        return countB.compareTo(countA);
      },
    );

    // ========================================================
    // UPDATE UI
    // ========================================================

    setState(() {
      allBatches = batches;
      loading = false;
    });

    debugPrint(
      "======================================",
    );

    debugPrint(
      "TOTAL SOCIETY BATCHES WITHIN "
      "${vendorBatchRadiusKm.toStringAsFixed(0)} KM: "
      "${batches.length}",
    );

    debugPrint(
      "======================================",
    );
  });
}
  // ============================================================
  // FILTER
  // ============================================================

  List<Map<String, dynamic>>
      get filteredBatches {
    if (selectedCategory == "All") {
      return allBatches;
    }

    return allBatches.where(
      (batch) {
        return batch["serviceId"]
                ?.toString() ==
            selectedCategory;
      },
    ).toList();
  }

  // ============================================================
  // BUILD
  // ============================================================

 @override
Widget build(BuildContext context) {
  return Scaffold(
    backgroundColor: backgroundColor,

    appBar: AppBar(
      backgroundColor: Colors.white,
      elevation: 0,

      leading: IconButton(
        icon: const Icon(
          Icons.arrow_back,
          color: Colors.black,
        ),
        onPressed: () {
          Navigator.pop(context);
        },
      ),

      title: const Text(
        "Society Service Batches",
        style: TextStyle(
          color: Colors.black,
          fontWeight: FontWeight.bold,
        ),
      ),
    ),

    body: loading
        ? const Center(
            child: CircularProgressIndicator(
              color: primaryColor,
            ),
          )
        : Column(
            children: [
              _buildHeader(),

              _buildCategoryList(),

              const SizedBox(
                height: 10,
              ),

              Expanded(
                child: _buildBatchList(),
              ),
            ],
          ),

    // =========================================================
    // BOTTOM NAVIGATION
    // =========================================================

    bottomNavigationBar: BottomNavigationBar(
      currentIndex: _selectedIndex,

      type: BottomNavigationBarType.fixed,

      backgroundColor: Colors.white,

      selectedItemColor: primaryColor,

      unselectedItemColor: Colors.grey,

      elevation: 10,

      onTap: (index) {
        setState(() {
          _selectedIndex = index;
        });

        switch (index) {
          case 0:
            // Home
            Navigator.pop(context);
            break;

         case 1:
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => const VendorRequestsScreen(),
    ),
  );
  break;

          case 2:
           Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => const VendorHistoryScreen(),
    ),
  );
            break;

          case 3:
            // Earn
            // TODO: Navigate to Earn screen
            break;
        }
      },

      items: const [
        BottomNavigationBarItem(
          icon: Icon(
            Icons.home_outlined,
          ),
          activeIcon: Icon(
            Icons.home,
          ),
          label: "Home",
        ),

        BottomNavigationBarItem(
          icon: Icon(
            Icons.assignment_outlined,
          ),
          activeIcon: Icon(
            Icons.assignment,
          ),
          label: "Your Requests",
        ),

        BottomNavigationBarItem(
          icon: Icon(
            Icons.history_outlined,
          ),
          activeIcon: Icon(
            Icons.history,
          ),
          label: "History",
        ),

        BottomNavigationBarItem(
          icon: Icon(
            Icons.account_balance_wallet_outlined,
          ),
          activeIcon: Icon(
            Icons.account_balance_wallet,
          ),
          label: "Earn",
        ),
      ],
    ),
  );
}
  // ============================================================
  // HEADER
  // ============================================================

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      margin:
          const EdgeInsets.fromLTRB(
        20,
        15,
        20,
        10,
      ),
      padding:
          const EdgeInsets.all(20),
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
            BorderRadius.circular(
          24,
        ),
      ),
      child: Row(
        children: [
          Container(
            height: 55,
            width: 55,
            decoration:
                BoxDecoration(
              color: Colors.white
                  .withOpacity(.18),
              borderRadius:
                  BorderRadius.circular(
                17,
              ),
            ),
            child: const Icon(
              Icons.groups,
              color: Colors.white,
              size: 30,
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
                  "Find Society Opportunities",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),

                const SizedBox(
                  height: 5,
                ),

                Text(
                  "${allBatches.length} active service batches available",
                  style:
                      const TextStyle(
                    color:
                        Colors.white70,
                    fontSize: 12,
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
  // CATEGORY LIST
  // ============================================================

  Widget _buildCategoryList() {
    return SizedBox(
      height: 105,
      child: ListView.separated(
        padding:
            const EdgeInsets.symmetric(
          horizontal: 20,
        ),

        scrollDirection:
            Axis.horizontal,

        itemCount:
            categories.length,

        separatorBuilder:
            (context, index) =>
                const SizedBox(
          width: 10,
        ),

        itemBuilder:
            (context, index) {
          final category =
              categories[index];

          final id =
              category["id"]
                  .toString();

          final name =
              category["name"]
                  .toString();

          final selected =
              selectedCategory ==
                  (id == "all"
                      ? "All"
                      : id);

          return GestureDetector(
            onTap: () {
              setState(() {
                selectedCategory =
                    id == "all"
                        ? "All"
                        : id;
              });
            },

            child: AnimatedContainer(
              duration:
                  const Duration(
                milliseconds: 200,
              ),

              width: 85,

              padding:
                  const EdgeInsets
                      .symmetric(
                horizontal: 8,
                vertical: 10,
              ),

              decoration:
                  BoxDecoration(
                color: selected
                    ? primaryColor
                    : Colors.white,

                borderRadius:
                    BorderRadius
                        .circular(
                  17,
                ),

                border:
                    Border.all(
                  color: selected
                      ? primaryColor
                      : const Color(
                          0xffE2E8F0,
                        ),
                ),
              ),

              child: Column(
                mainAxisAlignment:
                    MainAxisAlignment
                        .center,

                children: [
                  Icon(
                    category[
                        "icon"],
                    size: 27,
                    color: selected
                        ? Colors.white
                        : primaryColor,
                  ),

                  const SizedBox(
                    height: 7,
                  ),

                  Text(
                    name,
                    textAlign:
                        TextAlign.center,
                    maxLines: 2,
                    overflow:
                        TextOverflow
                            .ellipsis,
                    style:
                        TextStyle(
                      fontSize: 10,
                      fontWeight:
                          FontWeight.w600,
                      color: selected
                          ? Colors.white
                          : Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ============================================================
  // BATCH LIST
  // ============================================================

  Widget _buildBatchList() {
    final batches =
        filteredBatches;

    if (batches.isEmpty) {
      return _buildEmpty();
    }

    return RefreshIndicator(
      onRefresh: () async {
        listenToBatches();

        await Future.delayed(
          const Duration(
            milliseconds: 500,
          ),
        );
      },

      child: ListView.builder(
        physics:
            const AlwaysScrollableScrollPhysics(),

        padding:
            const EdgeInsets.fromLTRB(
          20,
          5,
          20,
          30,
        ),

        itemCount:
            batches.length,

        itemBuilder:
            (context, index) {
          return _buildBatchCard(
            batches[index],
          );
        },
      ),
    );
  }

  // ============================================================
  // BATCH CARD
  // ============================================================

  Widget _buildBatchCard(
    Map<String, dynamic> batch,
  ) {
    final serviceName =
        batch["serviceName"]
                ?.toString() ??
            "Service";

    final serviceId =
        batch["serviceId"]
                ?.toString() ??
            "";

    final apartmentName =
        batch["apartmentName"]
                ?.toString() ??
            "Apartment";

    final address =
        batch["address"]
                ?.toString() ??
            "Address not available";
        final latitude =
          _toDouble(batch["latitude"]);

        final longitude =
          _toDouble(batch["longitude"]);

        final double? distanceKm =
    _calculateDistanceKm(
  societyLatitude: latitude,
  societyLongitude: longitude,
);

    final count =
        int.tryParse(
              batch["requestCount"]
                      ?.toString() ??
                  "0",
            ) ??
            0;

    final status =
        batch["status"]
                ?.toString() ??
            "collecting";
   
    final alreadyApplied =
    _hasVendorAlreadyApplied(batch);        

    final category =
        _getCategory(serviceId);

    return GestureDetector(
      onTap: () {
        _showBatchDetails(
          batch,
        );
      },

      child: Container(
        margin:
            const EdgeInsets.only(
          bottom: 16,
        ),

        padding:
            const EdgeInsets.all(
          18,
        ),

        decoration:
            BoxDecoration(
          color: Colors.white,

          borderRadius:
              BorderRadius.circular(
            23,
          ),

          boxShadow: const [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 8,
              offset: Offset(0, 3),
            ),
          ],
        ),

        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,

          children: [
            // ==================================================
            // TOP
            // ==================================================

            Row(
              children: [
                Container(
                  height: 54,
                  width: 54,

                  decoration:
                      BoxDecoration(
                    color:
                        const Color(
                      0xffDBEAFE,
                    ),

                    borderRadius:
                        BorderRadius
                            .circular(
                      16,
                    ),
                  ),

                  child: Icon(
                    category[
                        "icon"],
                    color:
                        primaryColor,
                    size: 28,
                  ),
                ),

                const SizedBox(
                  width: 13,
                ),

                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment
                            .start,
                    children: [
                      Text(
                        serviceName,
                        style:
                            const TextStyle(
                          fontSize: 17,
                          fontWeight:
                              FontWeight.bold,
                        ),
                      ),

                      const SizedBox(
                        height: 4,
                      ),

                      Text(
                        apartmentName,
                        maxLines: 1,
                        overflow:
                            TextOverflow
                                .ellipsis,
                        style:
                            const TextStyle(
                          color:
                              Colors.grey,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),

                _statusBadge(
                  status,
                ),
              ],
            ),

            const SizedBox(
              height: 16,
            ),

            // ==================================================
            // LOCATION
            // ==================================================

          Container(
  padding: const EdgeInsets.all(13),

  decoration: BoxDecoration(
    color: const Color(0xffF8FAFC),
    borderRadius: BorderRadius.circular(14),
  ),

  child: Row(
    crossAxisAlignment: CrossAxisAlignment.start,

    children: [
      const Icon(
        Icons.location_on,
        color: primaryColor,
        size: 20,
      ),

      const SizedBox(width: 8),

      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              address,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.black87,
                height: 1.4,
              ),
            ),

            const SizedBox(height: 5),

            if (latitude != null &&
                longitude != null)
              Row(
                children: [
                  const Icon(
                    Icons.gps_fixed,
                    size: 13,
                    color: Colors.green,
                  ),

                  const SizedBox(width: 5),

                  const Text(
                    "Location coordinates available",
                    style: TextStyle(
                      color: Colors.green,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              )
            else
              const Text(
                "Exact location not available",
                style: TextStyle(
                  color: Colors.orange,
                  fontSize: 10,
                ),
              ),

            // ==================================================
            // DISTANCE
            // ==================================================

            if (distanceKm != null) ...[
              const SizedBox(height: 5),

              Row(
                children: [
                  const Icon(
                    Icons.near_me_rounded,
                    size: 13,
                    color: primaryColor,
                  ),

                  const SizedBox(width: 5),

                  Text(
                    distanceKm < 1
                        ? "${(distanceKm * 1000).round()} m away"
                        : "${distanceKm.toStringAsFixed(1)} km away",
                    style: const TextStyle(
                      color: primaryColor,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    ],
  ),
),
            const SizedBox(
              height: 14,
            ),

SizedBox(
  width: double.infinity,
  height: 46,
  child: OutlinedButton.icon(
    style: OutlinedButton.styleFrom(
      foregroundColor:
          primaryColor,
      side: const BorderSide(
        color: primaryColor,
      ),
      shape:
          RoundedRectangleBorder(
        borderRadius:
            BorderRadius.circular(13),
      ),
    ),

    onPressed:
        latitude != null &&
                longitude != null
            ? () {
                _openLocation(
                  latitude,
                  longitude,
                );
              }
            : null,

    icon: const Icon(
      Icons.map_outlined,
      size: 20,
    ),

    label: const Text(
      "View Society Location",
      style: TextStyle(
        fontWeight:
            FontWeight.bold,
      ),
    ),
  ),
),
            // ==================================================
            // REQUEST COUNT
            // ==================================================

            Row(
              children: [
                Expanded(
                  child:
                      _statItem(
                    Icons.home,
                    "$count Flats",
                    "Requested",
                  ),
                ),

                Container(
                  height: 40,
                  width: 1,
                  color:
                      const Color(
                    0xffE2E8F0,
                  ),
                ),

                Expanded(
                  child:
                      _statItem(
                    Icons.groups,
                    count == 1
                        ? "1 Resident"
                        : "$count Residents",
                    "Interested",
                  ),
                ),
              ],
            ),

            const SizedBox(
              height: 15,
            ),

            // ==================================================
            // ACTION
            // ==================================================

            SizedBox(
  width: double.infinity,
  height: 45,
  child: ElevatedButton(
    style: ElevatedButton.styleFrom(
      backgroundColor: alreadyApplied
          ? Colors.grey.shade300
          : primaryColor,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius:
            BorderRadius.circular(13),
      ),
    ),

    onPressed: () {
      if (alreadyApplied) {
        _showMessage(
          "You are already applied for this batch.",
          Colors.orange,
        );
        return;
      }

      _showBatchDetails(batch);
    },

    child: Row(
      mainAxisAlignment:
          MainAxisAlignment.center,
      children: [
        Icon(
          alreadyApplied
              ? Icons.check_circle_outline
              : Icons.arrow_forward,
          color: alreadyApplied
              ? Colors.grey.shade700
              : Colors.white,
          size: 18,
        ),

        const SizedBox(width: 8),

        Text(
          alreadyApplied
              ? "Already Applied"
              : "View Batch Details",
          style: TextStyle(
            color: alreadyApplied
                ? Colors.grey.shade700
                : Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    ),
  ),
),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // STAT ITEM
  // ============================================================

  Widget _statItem(
    IconData icon,
    String value,
    String label,
  ) {
    return Row(
      mainAxisAlignment:
          MainAxisAlignment.center,

      children: [
        Icon(
          icon,
          size: 21,
          color:
              primaryColor,
        ),

        const SizedBox(
          width: 8,
        ),

        Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style:
                  const TextStyle(
                fontWeight:
                    FontWeight.bold,
                fontSize: 13,
              ),
            ),

            Text(
              label,
              style:
                  const TextStyle(
                color:
                    Colors.grey,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ============================================================
  // STATUS
  // ============================================================

  Widget _statusBadge(
    String status,
  ) {
    String text;

    Color color;

    switch (status) {
      case "vendor_selected":
        text = "VENDOR SELECTED";
        color = Colors.blue;
        break;

      case "scheduled":
        text = "SCHEDULED";
        color = Colors.purple;
        break;

      case "in_progress":
        text = "IN PROGRESS";
        color = Colors.orange;
        break;

      case "completed":
        text = "COMPLETED";
        color = Colors.green;
        break;

      default:
        text = "COLLECTING";
        color = Colors.orange;
    }

    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 6,
      ),

      decoration:
          BoxDecoration(
        color:
            color.withOpacity(.10),

        borderRadius:
            BorderRadius.circular(
          10,
        ),
      ),

      child: Text(
        text,
        style:
            TextStyle(
          color: color,
          fontSize: 8,
          fontWeight:
              FontWeight.bold,
        ),
      ),
    );
  }

  // ============================================================
  // EMPTY
  // ============================================================

  Widget _buildEmpty() {
    return Center(
      child: SingleChildScrollView(
        padding:
            const EdgeInsets.all(
          30,
        ),

        child: Column(
          mainAxisAlignment:
              MainAxisAlignment.center,

          children: [
            Container(
              height: 100,
              width: 100,

              decoration:
                  BoxDecoration(
                color:
                    const Color(
                  0xffDBEAFE,
                ),
                borderRadius:
                    BorderRadius.circular(
                  30,
                ),
              ),

              child: const Icon(
                Icons.groups_outlined,
                size: 50,
                color:
                    primaryColor,
              ),
            ),

            const SizedBox(
              height: 20,
            ),

            const Text(
              "No Service Batches Found",
              textAlign:
                  TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight:
                    FontWeight.bold,
              ),
            ),

            const SizedBox(
              height: 8,
            ),

            Text(
              selectedCategory ==
                      "All"
                  ? "There are no active society service requests at the moment."
                  : "No ${_getCategory(selectedCategory)["name"]} batches are currently available.",
              textAlign:
                  TextAlign.center,
              style:
                  const TextStyle(
                color:
                    Colors.grey,
                fontSize: 13,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // DETAILS
  // ============================================================

  void _showBatchDetails(
    Map<String, dynamic> batch,
  ) {
    final participants =
        batch["participants"];
        final latitude =
    _toDouble(batch["latitude"]);

final longitude =
    _toDouble(batch["longitude"]);

final address =
    batch["address"]?.toString() ??
        "Address not available";

final apartmentName =
    batch["apartmentName"]?.toString() ??
        "Apartment";

    final participantList =
        <Map<String, dynamic>>[];

    if (participants is Map) {
      participants.forEach(
        (key, value) {
          if (value is Map) {
            participantList.add({
              "uid": key,
              ...Map<String, dynamic>.from(
                value,
              ),
            });
          }
        },
      );
    }

    showModalBottomSheet(
      context: context,

      isScrollControlled: true,

      backgroundColor:
          Colors.transparent,

      builder: (context) {
        return Container(
          height:
              MediaQuery.of(context)
                      .size
                      .height *
                  .82,

          decoration:
              const BoxDecoration(
            color: Colors.white,

            borderRadius:
                BorderRadius.vertical(
              top: Radius.circular(
                30,
              ),
            ),
          ),

          child: Column(
            children: [
              const SizedBox(
                height: 12,
              ),

              Container(
                height: 5,
                width: 45,

                decoration:
                    BoxDecoration(
                  color: Colors
                      .grey
                      .shade300,

                  borderRadius:
                      BorderRadius.circular(
                    10,
                  ),
                ),
              ),

              const SizedBox(
                height: 18,
              ),

              Expanded(
                child:
                    SingleChildScrollView(
                  padding:
                      const EdgeInsets
                          .fromLTRB(
                    20,
                    0,
                    20,
                    30,
                  ),

                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment
                            .start,

                    children: [
                      // ========================================
                      // TITLE
                      // ========================================

                      Row(
                        children: [
                          Container(
                            height: 55,
                            width: 55,

                            decoration:
                                const BoxDecoration(
                              color:
                                  Color(
                                0xffDBEAFE,
                              ),
                              shape:
                                  BoxShape
                                      .circle,
                            ),

                            child:
                                Icon(
                              _getCategory(
                                batch["serviceId"]
                                        ?.toString() ??
                                    "",
                              )["icon"],
                              color:
                                  primaryColor,
                            ),
                          ),

                          const SizedBox(
                            width: 13,
                          ),

                          Expanded(
                            child:
                                Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment
                                      .start,

                              children: [
                                Text(
                                  batch["serviceName"]
                                          ?.toString() ??
                                      "Service",
                                  style:
                                      const TextStyle(
                                    fontSize:
                                        21,
                                    fontWeight:
                                        FontWeight
                                            .bold,
                                  ),
                                ),

                                const SizedBox(
                                  height: 4,
                                ),

                                Text(
                                  "Society Service Batch",
                                  style:
                                      const TextStyle(
                                    color:
                                        Colors.grey,
                                    fontSize:
                                        12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(
                        height: 22,
                      ),

                      // ========================================
                      // APARTMENT
                      // ========================================

                      const Text(
                        "Service Location",
                        style:
                            TextStyle(
                          fontSize: 16,
                          fontWeight:
                              FontWeight.bold,
                        ),
                      ),

                      const SizedBox(
                        height: 10,
                      ),

                      Container(
                        width:
                            double.infinity,

                        padding:
                            const EdgeInsets
                                .all(
                          16,
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
                            Column(
                          crossAxisAlignment:
                              CrossAxisAlignment
                                  .start,

                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons
                                      .apartment,
                                  color:
                                      primaryColor,
                                ),

                                const SizedBox(
                                  width:
                                      10,
                                ),

                                Expanded(
                                  child:
                                      Text(
                                    batch["apartmentName"]
                                            ?.toString() ??
                                        "Apartment",
                                    style:
                                        const TextStyle(
                                      fontWeight:
                                          FontWeight
                                              .bold,
                                      fontSize:
                                          15,
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(
                              height: 10,
                            ),

                            Row(
                              crossAxisAlignment:
                                  CrossAxisAlignment
                                      .start,

                              children: [
                                const Icon(
                                  Icons
                                      .location_on_outlined,
                                  size:
                                      19,
                                  color:
                                      Colors.grey,
                                ),

                                const SizedBox(
                                  width:
                                      10,
                                ),

                                Expanded(
                                  child:
                                      Text(
                                    batch["address"]
                                            ?.toString() ??
                                        "Address not available",
                                    style:
                                        const TextStyle(
                                      color:
                                          Colors.grey,
                                      fontSize:
                                          13,
                                      height:
                                          1.4,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(
                        height: 22,
                      ),

                      // ========================================
                      // DEMAND
                      // ========================================

                      const Text(
                        "Batch Demand",
                        style:
                            TextStyle(
                          fontSize: 16,
                          fontWeight:
                              FontWeight.bold,
                        ),
                      ),

                      const SizedBox(
                        height: 10,
                      ),

                      Row(
                        children: [
                          Expanded(
                            child:
                                _detailStat(
                              Icons.home,
                              "${batch["requestCount"] ?? 0}",
                              "Flats Needed",
                            ),
                          ),

                          const SizedBox(
                            width: 10,
                          ),

                          Expanded(
                            child:
                                _detailStat(
                              Icons.groups,
                              "${participantList.length}",
                              "Residents",
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(
                        height: 25,
                      ),

                      // ========================================
                      // RESIDENTS
                      // ========================================

                      const Text(
                        "Requested Flats",
                        style:
                            TextStyle(
                          fontSize: 16,
                          fontWeight:
                              FontWeight.bold,
                        ),
                      ),

                      const SizedBox(
                        height: 10,
                      ),

                      if (participantList
                          .isEmpty)
                        const Text(
                          "No participant details available.",
                          style:
                              TextStyle(
                            color:
                                Colors.grey,
                          ),
                        )
                      else
                        ...participantList.map(
                          (participant) {
                            return _participantCard(
                              participant,
                            );
                          },
                        ),

                      const SizedBox(
                        height: 15,
                      ),

                      // ========================================
                      // ACTION
                      // ========================================

                     SizedBox(
  width: double.infinity,
  height: 52,
  child: ElevatedButton(
    style: ElevatedButton.styleFrom(
      backgroundColor: primaryColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
    ),

    onPressed: () {
      Navigator.pop(context);

      _showBidDialog(batch);
    },

    child: const Text(
      "Consider This Batch",
      style: TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.bold,
        fontSize: 16,
      ),
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

  // ============================================================
  // DETAIL STAT
  // ============================================================

  Widget _detailStat(
    IconData icon,
    String value,
    String label,
  ) {
    return Container(
      padding:
          const EdgeInsets.all(
        16,
      ),

      decoration:
          BoxDecoration(
        color:
            const Color(
          0xffEFF6FF,
        ),

        borderRadius:
            BorderRadius.circular(
          17,
        ),
      ),

      child: Column(
        children: [
          Icon(
            icon,
            color:
                primaryColor,
            size: 26,
          ),

          const SizedBox(
            height: 8,
          ),

          Text(
            value,
            style:
                const TextStyle(
              fontSize: 22,
              fontWeight:
                  FontWeight.bold,
            ),
          ),

          Text(
            label,
            style:
                const TextStyle(
              color:
                  Colors.grey,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // PARTICIPANT CARD
  // ============================================================

  Widget _participantCard(
    Map<String, dynamic>
        participant,
  ) {
    return Container(
      margin:
          const EdgeInsets.only(
        bottom: 10,
      ),

      padding:
          const EdgeInsets.all(
        14,
      ),

      decoration:
          BoxDecoration(
        color: Colors.white,

        borderRadius:
            BorderRadius.circular(
          15,
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
          Container(
            height: 42,
            width: 42,

            decoration:
                const BoxDecoration(
              color:
                  Color(0xffDBEAFE),
              shape:
                  BoxShape.circle,
            ),

            child: const Icon(
              Icons.home,
              color:
                  primaryColor,
            ),
          ),

          const SizedBox(
            width: 12,
          ),

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment
                      .start,

              children: [
                Text(
                  "Flat ${participant["flatNumber"] ?? "N/A"}",
                  style:
                      const TextStyle(
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),

                const SizedBox(
                  height: 4,
                ),

                Text(
                  "${participant["selectedDate"] ?? "Date not selected"} • ${participant["timeSlot"] ?? "Time not selected"}",
                  style:
                      const TextStyle(
                    color:
                        Colors.grey,
                    fontSize: 11,
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
  // DATE & DOUBLE HELPERS
  // ============================================================

 
  String _formatDate(DateTime date) {
  return "${date.day.toString().padLeft(2, '0')}/"
      "${date.month.toString().padLeft(2, '0')}/"
      "${date.year}";
}


 String _firebaseDate(
  DateTime date,
) {
  return "${date.year}-"
      "${date.month.toString().padLeft(2, '0')}-"
      "${date.day.toString().padLeft(2, '0')}";
}

  double? _toDouble(dynamic value) {
    if (value == null) {
      return null;
    }

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(
      value.toString(),
    );
  }
  // ============================================================
  // CATEGORY HELPER
  // ============================================================

  Map<String, dynamic>
      _getCategory(String id) {
    for (final category
        in categories) {
      if (category["id"]
              .toString() ==
          id) {
        return category;
      }
    }

    return {
      "id": id,
      "name": "Service",
      "icon": Icons.handyman,
    };
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
        .showSnackBar(
      SnackBar(
        content:
            Text(message),
        backgroundColor:
            color,
      ),
    );
  }
 // ============================================================
// SHOW BID FORM
// ============================================================


void _showBidDialog(
  Map<String, dynamic> batch,
) {
  final TextEditingController startingPriceController =
      TextEditingController();
  final TextEditingController minimumPriceController =
      TextEditingController();
  final TextEditingController messageController =
      TextEditingController();

  DateTime selectedCompletionDate =
      DateTime.now().add(const Duration(days: 1));

  String selectedCompletionTime = "10:00 AM - 12:00 PM";

  final timeSlots = [
    "8:00 AM - 10:00 AM",
    "10:00 AM - 12:00 PM",
    "12:00 PM - 2:00 PM",
    "2:00 PM - 4:00 PM",
    "4:00 PM - 6:00 PM",
    "6:00 PM - 8:00 PM",
  ];

  final bool batchAlreadyLocked = batch["priceLocked"] == true;

  if (batchAlreadyLocked) {
    _showMessage(
      "This batch has already started. Its price is locked.",
      Colors.orange,
    );
    return;
  }

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setModalState) {
          final int flatCount =
              int.tryParse(batch["requestCount"]?.toString() ?? "0") ?? 0;

          final double startingPrice =
              double.tryParse(startingPriceController.text.trim()) ?? 0;
          final double minimumPrice =
              double.tryParse(minimumPriceController.text.trim()) ?? 0;

          final bool pricesValid =
              startingPrice > 0 &&
              minimumPrice > 0 &&
              minimumPrice <= startingPrice;

          final double currentPrice = pricesValid
              ? _calculateBatchPrice(
                  flats: flatCount,
                  startingPrice: startingPrice,
                  minimumPrice: minimumPrice,
                )
              : 0;

          final double finalTotal = currentPrice * flatCount;

          return Container(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(context).viewInsets.bottom + 20,
            ),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(30),
              ),
            ),
            child: SafeArea(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 45,
                        height: 5,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    const Text(
                      "Submit Your Bid",
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      batch["serviceName"]?.toString() ?? "Service",
                      style: const TextStyle(
                        color: Colors.grey,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // ==================================================
                    // BATCH SUMMARY
                    // ==================================================
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xffEFF6FF),
                            Color(0xffF0F9FF),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(17),
                        border: Border.all(
                          color: const Color(0xffDBEAFE),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 45,
                            height: 45,
                            decoration: BoxDecoration(
                              color: primaryColor,
                              borderRadius: BorderRadius.circular(13),
                            ),
                            child: const Icon(
                              Icons.groups,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  batch["apartmentName"]?.toString() ??
                                      "Apartment",
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  "$flatCount flats are requesting this service",
                                  style: const TextStyle(
                                    color: Colors.grey,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 22),

                    // ==================================================
                    // STARTING PRICE
                    // ==================================================
                    const Text(
                      "Starting Price Per Flat",
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: startingPriceController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      onChanged: (_) => setModalState(() {}),
                      decoration: InputDecoration(
                        prefixText: "₹ ",
                        hintText: "Enter starting price per flat",
                        filled: true,
                        fillColor: const Color(0xffF8FAFC),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),

                    const SizedBox(height: 14),

                    // ==================================================
                    // MINIMUM PRICE
                    // ==================================================
                    const Text(
                      "Minimum Price Per Flat",
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: minimumPriceController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      onChanged: (_) => setModalState(() {}),
                      decoration: InputDecoration(
                        prefixText: "₹ ",
                        hintText: "Enter minimum acceptable price",
                        filled: true,
                        fillColor: const Color(0xffF8FAFC),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      "The price can decrease as more flats join, but it will never go below your minimum price.",
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 11,
                        height: 1.4,
                      ),
                    ),

                    const SizedBox(height: 18),

                    // ==================================================
                    // LIVE PRICE PREVIEW
                    // ==================================================
                    if (startingPrice > 0 && minimumPrice > 0)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xffEFF6FF),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: const Color(0xffBFDBFE),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  "Current price",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                                Text(
                                  pricesValid
                                      ? "₹${currentPrice.toStringAsFixed(0)} / flat"
                                      : "Check prices",
                                  style: const TextStyle(
                                    color: primaryColor,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 17,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              pricesValid
                                  ? "$flatCount flats × ₹${currentPrice.toStringAsFixed(0)} = ₹${finalTotal.toStringAsFixed(0)} total"
                                  : minimumPrice > startingPrice
                                      ? "Minimum price cannot be higher than starting price."
                                      : "Enter both prices to see the batch price.",
                              style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),

                    const SizedBox(height: 22),

                    // ==================================================
                    // COMPLETION DATE
                    // ==================================================
                    const Text(
                      "Completion Date",
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(
                            const Duration(days: 60),
                          ),
                          initialDate: selectedCompletionDate,
                        );

                        if (picked != null) {
                          setModalState(() {
                            selectedCompletionDate = picked;
                          });
                        }
                      },
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xffF8FAFC),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: const Color(0xffE2E8F0),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.calendar_month,
                              color: primaryColor,
                            ),
                            const SizedBox(width: 10),
                            Text(_formatDate(selectedCompletionDate)),
                            const Spacer(),
                            const Icon(
                              Icons.keyboard_arrow_down,
                              color: Colors.grey,
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // ==================================================
                    // COMPLETION TIME
                    // ==================================================
                    const Text(
                      "Completion Time",
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: timeSlots.map((slot) {
                        final selected =
                            selectedCompletionTime == slot;

                        return GestureDetector(
                          onTap: () {
                            setModalState(() {
                              selectedCompletionTime = slot;
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 11,
                            ),
                            decoration: BoxDecoration(
                              color: selected
                                  ? primaryColor
                                  : const Color(0xffF8FAFC),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: selected
                                    ? primaryColor
                                    : const Color(0xffE2E8F0),
                              ),
                            ),
                            child: Text(
                              slot,
                              style: TextStyle(
                                color: selected
                                    ? Colors.white
                                    : Colors.black87,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 20),

                    // ==================================================
                    // MESSAGE
                    // ==================================================
                    const Text(
                      "Message to Customer",
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: messageController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        hintText:
                            "Explain your service, warranty, timing, etc.",
                        filled: true,
                        fillColor: const Color(0xffF8FAFC),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),

                    const SizedBox(height: 25),

                    // ==================================================
                    // SUBMIT
                    // ==================================================
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                        ),
                        onPressed: () async {
                          final double startingPrice =
                              double.tryParse(
                                    startingPriceController.text.trim(),
                                  ) ??
                                  0;

                          final double minimumPrice =
                              double.tryParse(
                                    minimumPriceController.text.trim(),
                                  ) ??
                                  0;

                          if (startingPrice <= 0 || minimumPrice <= 0) {
                            _showMessage(
                              "Please enter valid starting and minimum prices.",
                              Colors.red,
                            );
                            return;
                          }

                          if (minimumPrice > startingPrice) {
                            _showMessage(
                              "Minimum price cannot be higher than starting price.",
                              Colors.red,
                            );
                            return;
                          }

                          final int currentFlatCount =
                              int.tryParse(
                                    batch["requestCount"]?.toString() ?? "0",
                                  ) ??
                                  0;

                          if (currentFlatCount <= 0) {
                            _showMessage(
                              "This batch has no participating flats.",
                              Colors.red,
                            );
                            return;
                          }

                          // Always calculate from the latest count immediately
                          // before submitting the bid.
                          final double currentPrice = _calculateBatchPrice(
                            flats: currentFlatCount,
                            startingPrice: startingPrice,
                            minimumPrice: minimumPrice,
                          );

                          if (currentPrice <= 0) {
                            _showMessage(
                              "Unable to calculate the batch price.",
                              Colors.red,
                            );
                            return;
                          }

                          final double finalTotal =
                              currentPrice * currentFlatCount;

                          final String bidMessage =
                              messageController.text.trim();

                          Navigator.pop(context);

                          final confirmed = await _showBidConfirmation(
                            batch: batch,
                            flatCount: currentFlatCount,
                            startingPrice: startingPrice,
                            minimumPrice: minimumPrice,
                            currentPrice: currentPrice,
                            totalAmount: finalTotal,
                          );

                          if (confirmed != true) {
                            return;
                          }

                          await _submitBid(
                            batch: batch,
                            startingPrice: startingPrice,
                            minimumPrice: minimumPrice,
                            bidAmount: currentPrice,
                            completionDate: selectedCompletionDate,
                            completionTime: selectedCompletionTime,
                            message: bidMessage,
                          );

                          if (!mounted) return;

                          _showBidSuccessMessage(
                            batch: batch,
                            flatCount: currentFlatCount,
                            finalPrice: currentPrice,
                          );
                        },
                        child: const Text(
                          "Review & Submit Bid",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    },
  );
  //.whenComplete(() {
  //   startingPriceController.dispose();
  //   minimumPriceController.dispose();
  //   messageController.dispose();
  // });
}


// ============================================================
// BID CONFIRMATION
// ============================================================

Future<bool?> _showBidConfirmation({
  required Map<String, dynamic> batch,
  required int flatCount,
  required double startingPrice,
  required double minimumPrice,
  required double currentPrice,
  required double totalAmount,
}) {
  return showDialog<bool>(
    context: context,
    builder: (context) {
      return AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        contentPadding: const EdgeInsets.all(22),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 65,
              height: 65,
              decoration: const BoxDecoration(
                color: Color(0xffDCFCE7),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle_outline,
                color: Color(0xff16A34A),
                size: 38,
              ),
            ),
            const SizedBox(height: 15),
            const Text(
              "Review Your Bid",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              "Please confirm the pricing before submitting your offer.",
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.grey,
                fontSize: 12,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xffF8FAFC),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: const Color(0xffE2E8F0),
                ),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Starting price",
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        "₹${startingPrice.toStringAsFixed(0)} / flat",
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Minimum price",
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        "₹${minimumPrice.toStringAsFixed(0)} / flat",
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Divider(),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Current price",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        "₹${currentPrice.toStringAsFixed(0)} / flat",
                        style: const TextStyle(
                          color: primaryColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 17,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Total batch value",
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: 11,
                        ),
                      ),
                      Text(
                        "₹${totalAmount.toStringAsFixed(0)}",
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xffEFF6FF),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Text(
                "The price will decrease automatically when more flats join, but it will never go below your minimum price. Once work starts, the current price is locked for the batch.",
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xff1E40AF),
                  fontSize: 11,
                  height: 1.4,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),

            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(13),
                  ),
                ),
                onPressed: () {
                  Navigator.pop(context, true);
                },
                child: const Text(
                  "Confirm & Submit Bid",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () {
                Navigator.pop(context, false);
              },
              child: const Text(
                "Edit Bid",
                style: TextStyle(color: Colors.grey),
              ),
            ),
          ],
        ),
      );
    },
  );
}


// ============================================================
// SUCCESS MESSAGE
// ============================================================

void _showBidSuccessMessage({
  required Map<String, dynamic> batch,
  required int flatCount,
  required double finalPrice,
}) {
  final String apartment =
      batch["apartmentName"]
              ?.toString() ??
          "the society";

  showDialog(
    context: context,
    builder: (context) {
      return AlertDialog(
        shape:
            RoundedRectangleBorder(
          borderRadius:
              BorderRadius.circular(
            24,
          ),
        ),
        contentPadding:
            const EdgeInsets.all(
          24,
        ),
        content: Column(
          mainAxisSize:
              MainAxisSize.min,
          children: [

            Container(
              width: 70,
              height: 70,
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
                    .check_circle,
                color:
                    Color(0xff16A34A),
                size: 42,
              ),
            ),

            const SizedBox(
              height: 16,
            ),

            const Text(
              "Bid Submitted!",
              style:
                  TextStyle(
                fontSize: 22,
                fontWeight:
                    FontWeight.bold,
              ),
            ),

            const SizedBox(
              height: 8,
            ),

            Text(
              "Your offer for $apartment has been successfully submitted.",
              textAlign:
                  TextAlign.center,
              style:
                  const TextStyle(
                color:
                    Colors.grey,
                fontSize:
                    13,
                height:
                    1.5,
              ),
            ),

            const SizedBox(
              height: 18,
            ),

            Container(
              width:
                  double.infinity,
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
                  14,
                ),
              ),
              child:
                  Column(
                children: [

                  Text(
                    "$flatCount flats",
                    style:
                        const TextStyle(
                      fontSize:
                          18,
                      fontWeight:
                          FontWeight
                              .bold,
                    ),
                  ),

                  const SizedBox(
                    height: 3,
                  ),

                  const Text(
                    "Batch size",
                    style:
                        TextStyle(
                      color:
                          Colors.grey,
                      fontSize:
                          11,
                    ),
                  ),

                  const SizedBox(
                    height: 12,
                  ),

                  Text(
                    "₹${finalPrice.toStringAsFixed(0)} / flat",
                    style:
                        const TextStyle(
                      color:
                          primaryColor,
                      fontSize:
                          18,
                      fontWeight:
                          FontWeight
                              .bold,
                    ),
                  ),

                  const SizedBox(
                    height: 3,
                  ),

                  const Text(
                    "Submitted bid price",
                    style:
                        TextStyle(
                      color:
                          Colors.grey,
                      fontSize:
                          11,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(
              height: 18,
            ),

            const Text(
              "The society will review all vendor bids. You will be notified when the customer selects a vendor.",
              textAlign:
                  TextAlign.center,
              style:
                  TextStyle(
                color:
                    Colors.grey,
                fontSize:
                    11,
                height:
                    1.5,
              ),
            ),

            const SizedBox(
              height: 18,
            ),

            SizedBox(
              width:
                  double.infinity,
              height: 46,
              child:
                  ElevatedButton(
                style:
                    ElevatedButton
                        .styleFrom(
                  backgroundColor:
                      primaryColor,
                  shape:
                      RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(
                      13,
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
                  "Done",
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
      );
    },
  );
}

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    batchSubscription?.cancel();

    super.dispose();
  }
}
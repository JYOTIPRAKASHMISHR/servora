import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:servora/screens/customer/location_picker_screen.dart';
import 'package:servora/services/payment_service.dart';
import 'package:servora/services/payment_api_service.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class MyApartmentScreen extends StatefulWidget {
  const MyApartmentScreen({super.key});

  @override
  State<MyApartmentScreen> createState() => _MyApartmentScreenState();
}

class _MyApartmentScreenState extends State<MyApartmentScreen> {
  // ============================================================
  // COLORS
  // ============================================================

  static const Color primaryColor = Color(0xff2563EB);
  static const Color secondaryColor = Color(0xff0EA5E9);
  static const Color backgroundColor = Color(0xffF8FAFC);
  double? selectedLatitude;
  double? selectedLongitude;

  String? selectedAddress;

  // ============================================================
  // FIREBASE
  // ============================================================

  final DatabaseReference _database = FirebaseDatabase.instance.ref();

  StreamSubscription<DatabaseEvent>? _apartmentSubscription;
  StreamSubscription<DatabaseEvent>? _batchSubscription;

  // ============================================================
  // STATE
  // ============================================================

  bool loading = true;
  bool savingApartment = false;

  bool hasApartment = false;

  String apartmentName = "";
  String flatNumber = "";
  String apartmentAddress = "";

  final TextEditingController addressController = TextEditingController();

  int selectedBottomIndex = 0;

  List<Map<String, dynamic>> societyBatches = [];

  // ============================================================
  // SERVICES
  // ============================================================

  final PaymentService paymentService = PaymentService();
  final PaymentApiService paymentApiService = PaymentApiService();

  final List<Map<String, dynamic>> services = [
    {
      "id": "ac_service",
      "name": "AC Service",
      "icon": Icons.ac_unit,
      "description": "AC servicing, cleaning and maintenance",
    },
    {
      "id": "ac_repair",
      "name": "AC Repair",
      "icon": Icons.build,
      "description": "AC repair and technical problems",
    },
    {
      "id": "plumbing",
      "name": "Plumbing",
      "icon": Icons.plumbing,
      "description": "Pipe, tap, leakage and bathroom work",
    },
    {
      "id": "electrical",
      "name": "Electrical",
      "icon": Icons.electrical_services,
      "description": "Electrical repair and installation",
    },
    {
      "id": "home_cleaning",
      "name": "Home Cleaning",
      "icon": Icons.cleaning_services,
      "description": "Complete home cleaning services",
    },
    {
      "id": "deep_cleaning",
      "name": "Deep Cleaning",
      "icon": Icons.cleaning_services_outlined,
      "description": "Deep cleaning for your apartment",
    },
    {
      "id": "pest_control",
      "name": "Pest Control",
      "icon": Icons.bug_report,
      "description": "Pest control and prevention",
    },
    {
      "id": "ro_service",
      "name": "RO Service",
      "icon": Icons.water_drop,
      "description": "RO servicing and maintenance",
    },
    {
      "id": "appliance_repair",
      "name": "Appliance Repair",
      "icon": Icons.home_repair_service,
      "description": "Repair household appliances",
    },
    {
      "id": "painting",
      "name": "Painting",
      "icon": Icons.format_paint,
      "description": "Home painting and wall work",
    },
    {
      "id": "car_wash",
      "name": "Car Wash",
      "icon": Icons.local_car_wash,
      "description": "Car cleaning inside the society",
    },
    {
      "id": "bike_service",
      "name": "Bike Service",
      "icon": Icons.two_wheeler,
      "description": "Bike servicing and maintenance",
    },
    {
      "id": "massage",
      "name": "Massage",
      "icon": Icons.spa,
      "description": "At-home wellness service",
    },
    {
      "id": "elder_care",
      "name": "Elder Care",
      "icon": Icons.elderly,
      "description": "Care services for senior citizens",
    },
    {
      "id": "babysitting",
      "name": "Babysitting",
      "icon": Icons.child_care,
      "description": "Trusted babysitting service",
    },
    {
      "id": "home_tutor",
      "name": "Home Tutor",
      "icon": Icons.school,
      "description": "Home tutoring and academic support",
    },
  ];

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();

    loadApartment();
  }

  Future<int> _getVendorBidAmount(Map<String, dynamic> batch) async {
    try {
      final String apartmentKey = batch["apartmentKey"]?.toString() ?? "";

      final String serviceId = batch["serviceId"]?.toString() ?? "";

      debugPrint("====================================");
      debugPrint("🔍 Looking for LIVE vendor price");
      debugPrint("apartmentKey: $apartmentKey");
      debugPrint("serviceId: $serviceId");
      debugPrint("====================================");

      if (apartmentKey.isEmpty || serviceId.isEmpty) {
        debugPrint("❌ apartmentKey or serviceId is missing");
        return 0;
      }

      // ============================================================
      // READ THE SAME LOCATION THAT VENDOR UPDATES
      // ============================================================

      final DatabaseReference bidsRef = FirebaseDatabase.instance.ref(
        "societyServiceBatches/"
        "$apartmentKey/"
        "$serviceId/"
        "bids",
      );

      final DataSnapshot snapshot = await bidsRef.get();

      if (!snapshot.exists || snapshot.value is! Map) {
        debugPrint("❌ No vendor bids found");
        return 0;
      }

      // ============================================================
      // FIND A VALID VENDOR BID
      // ============================================================

      for (final DataSnapshot vendorSnapshot in snapshot.children) {
        final dynamic value = vendorSnapshot.value;

        if (value is! Map) {
          continue;
        }

        final Map<String, dynamic> bid = Map<String, dynamic>.from(value);

        final String status = bid["status"]?.toString().toLowerCase() ?? "";

        // ----------------------------------------------------------
        // Use selected/active vendor bid
        // ----------------------------------------------------------

        if (status != "selected" && status != "pending") {
          continue;
        }

        // ==========================================================
        // CURRENT PRICE
        // ==========================================================

        final double currentPrice =
            double.tryParse(bid["currentPrice"]?.toString() ?? "0") ?? 0;

        // Fallback for old records
        final double bidAmount =
            double.tryParse(bid["bidAmount"]?.toString() ?? "0") ?? 0;

        final double finalPrice = currentPrice > 0 ? currentPrice : bidAmount;

        if (finalPrice <= 0) {
          continue;
        }

        debugPrint("====================================");

        debugPrint("✅ LIVE VENDOR PRICE FOUND");

        debugPrint("vendorId: ${vendorSnapshot.key}");

        debugPrint("startingPrice: ${bid["startingPrice"]}");

        debugPrint("minimumPrice: ${bid["minimumPrice"]}");

        debugPrint("currentPrice: ₹$finalPrice");

        debugPrint("bidAmount: ₹$bidAmount");

        debugPrint("====================================");

        return finalPrice.round();
      }

      debugPrint("❌ No valid vendor bid found");

      return 0;
    } catch (e, stackTrace) {
      debugPrint("❌ Error reading vendor current price: $e");

      debugPrint(stackTrace.toString());

      return 0;
    }
  }

  Future<void> _openLocationPicker(
    TextEditingController addressController,
    void Function(void Function()) setModalState,
  ) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const LocationPickerScreen()),
    );

    if (result == null) {
      return;
    }

    if (!mounted) {
      return;
    }

    final address = result["address"]?.toString() ?? "";

    final latitude = double.tryParse(result["latitude"]?.toString() ?? "");

    final longitude = double.tryParse(result["longitude"]?.toString() ?? "");

    // Update the controller that is actually displayed
    addressController.text = address;

    // Update modal UI
    setModalState(() {});

    // Also store location in your State
    setState(() {
      selectedAddress = address;
      selectedLatitude = latitude;
      selectedLongitude = longitude;
    });
  }
  // ============================================================
  // LOAD APARTMENT
  // ============================================================

  void loadApartment() {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      setState(() {
        loading = false;
      });
      return;
    }

    _apartmentSubscription = _database
        .child("users/${user.uid}/apartment")
        .onValue
        .listen((event) {
          if (!mounted) return;

          if (!event.snapshot.exists || event.snapshot.value == null) {
            setState(() {
              hasApartment = false;
              loading = false;
            });

            _batchSubscription?.cancel();
            return;
          }

          final raw = event.snapshot.value;

          if (raw is! Map) {
            setState(() {
              hasApartment = false;
              loading = false;
            });
            return;
          }

          final data = Map<String, dynamic>.from(raw);

          setState(() {
            apartmentName = data["apartmentName"]?.toString() ?? "";

            flatNumber = data["flatNumber"]?.toString() ?? "";

            apartmentAddress = data["address"]?.toString() ?? "";

            selectedLatitude = double.tryParse(
              data["latitude"]?.toString() ?? "",
            );

            selectedLongitude = double.tryParse(
              data["longitude"]?.toString() ?? "",
            );

            hasApartment =
                apartmentName.trim().isNotEmpty &&
                flatNumber.trim().isNotEmpty &&
                apartmentAddress.trim().isNotEmpty;

            loading = false;
          });

          if (hasApartment) {
            listenToSocietyBatches();
          }
        });
  }

  // ============================================================
  // CREATE APARTMENT KEY
  // ============================================================

  String get apartmentKey {
    final value = apartmentName
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');

    return value.isEmpty ? "my_apartment" : value;
  }

  // ============================================================
  // REALTIME SOCIETY BATCH LISTENER
  // ============================================================

  void listenToSocietyBatches() {
    _batchSubscription?.cancel();

    _batchSubscription = _database
        .child("societyServiceBatches/$apartmentKey")
        .onValue
        .listen((event) {
          if (!mounted) return;

          if (!event.snapshot.exists || event.snapshot.value == null) {
            setState(() {
              societyBatches = [];
            });

            return;
          }

          final raw = event.snapshot.value;

          if (raw is! Map) {
            setState(() {
              societyBatches = [];
            });

            return;
          }

          final data = Map<String, dynamic>.from(raw);

          final List<Map<String, dynamic>> batches = [];

          data.forEach((key, value) {
            if (value is Map) {
              final batch = Map<String, dynamic>.from(value);

              batches.add({"batchId": key, ...batch});
            }
          });

          setState(() {
            societyBatches = batches;
          });
        });
  }

  // ============================================================
  // SAVE APARTMENT
  // ============================================================

  Future<void> saveApartment({
    required String name,
    required String flat,
    required String address,
  }) async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      _showMessage("Please login first", Colors.red);
      return;
    }

    if (name.trim().isEmpty || flat.trim().isEmpty || address.trim().isEmpty) {
      _showMessage("All apartment fields are mandatory", Colors.red);
      return;
    }

    setState(() {
      savingApartment = true;
    });

    try {
      await _database.child("users/${user.uid}/apartment").set({
        "apartmentName": name.trim(),
        "flatNumber": flat.trim(),
        "address": address.trim(),
        "latitude": selectedLatitude,
        "longitude": selectedLongitude,
        "updatedAt": ServerValue.timestamp,
      });

      await _database.child("apartmentMembers/$apartmentKey/${user.uid}").set({
        "uid": user.uid,
        "flatNumber": flat.trim(),
        "apartmentName": name.trim(),
        "joinedAt": ServerValue.timestamp,
      });

      if (!mounted) return;

      setState(() {
        apartmentName = name.trim();
        flatNumber = flat.trim();
        apartmentAddress = address.trim();
        hasApartment = true;
        savingApartment = false;
      });

      listenToSocietyBatches();

      Navigator.pop(context);

      _showMessage("Apartment added successfully", Colors.green);
    } catch (e) {
      if (!mounted) return;

      setState(() {
        savingApartment = false;
      });

      _showMessage("Failed to save apartment", Colors.red);
    }
  }

  // ============================================================
  // ADD / EDIT APARTMENT DIALOG
  // ============================================================

  void showApartmentForm({bool edit = false}) {
    final nameController = TextEditingController(text: apartmentName);

    final flatController = TextEditingController(text: flatNumber);

    final addressController = TextEditingController(text: apartmentAddress);

    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
              ),
              child: SingleChildScrollView(
                child: Form(
                  key: formKey,
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

                      Text(
                        edit ? "Edit My Apartment" : "Add Your Apartment",
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 8),

                      const Text(
                        "Add your apartment details to access society group services.",
                        style: TextStyle(color: Colors.grey, height: 1.4),
                      ),

                      const SizedBox(height: 25),

                      _buildTextField(
                        controller: nameController,
                        label: "Apartment / Society Name",
                        hint: "e.g. Green Valley Residency",
                        icon: Icons.apartment,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return "Apartment name is required";
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 15),

                      _buildTextField(
                        controller: flatController,
                        label: "Flat / Room Number",
                        hint: "e.g. A-1204",
                        icon: Icons.door_front_door,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return "Flat / Room number is required";
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 15),

                      // ============================================================
                      // COMPLETE ADDRESS / LOCATION PICKER
                      // ============================================================
                      GestureDetector(
                        onTap: () {
                          _openLocationPicker(addressController, setModalState);
                        },
                        child: AbsorbPointer(
                          child: _buildTextField(
                            controller: addressController,
                            label: "Complete Address",
                            hint: "Tap to select your address on map",
                            icon: Icons.location_on,
                            maxLines: 3,
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return "Please select your address";
                              }
                              return null;
                            },
                          ),
                        ),
                      ),

                      const SizedBox(height: 8),

                      Row(
                        children: [
                          const Icon(
                            Icons.info_outline,
                            size: 16,
                            color: Colors.grey,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              addressController.text.isEmpty
                                  ? "Tap above to select your exact location"
                                  : "Location selected successfully",
                              style: TextStyle(
                                fontSize: 12,
                                color: addressController.text.isEmpty
                                    ? Colors.grey
                                    : Colors.green,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Small helper text
                      Row(
                        children: [
                          const Icon(
                            Icons.info_outline,
                            size: 16,
                            color: Colors.grey,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              addressController.text.isEmpty
                                  ? "Tap above to select your exact location"
                                  : "Location selected successfully",
                              style: TextStyle(
                                fontSize: 12,
                                color: addressController.text.isEmpty
                                    ? Colors.grey
                                    : Colors.green,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 25),

                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          onPressed: savingApartment
                              ? null
                              : () async {
                                  if (!formKey.currentState!.validate()) {
                                    return;
                                  }

                                  setModalState(() {});

                                  await saveApartment(
                                    name: nameController.text,
                                    flat: flatController.text,
                                    address: addressController.text,
                                  );
                                },
                          child: savingApartment
                              ? const SizedBox(
                                  height: 22,
                                  width: 22,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(
                                  edit ? "Update Apartment" : "Save & Continue",
                                  style: const TextStyle(
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
  }

  // ============================================================
  // TEXT FIELD
  // ============================================================

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    String? Function(String?)? validator,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: primaryColor),
        filled: true,
        fillColor: const Color(0xffF8FAFC),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: primaryColor, width: 1.5),
        ),
      ),
    );
  }

  // ============================================================
  // MAIN UI
  // ============================================================

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
          "My Apartment",
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),

        actions: [
          if (hasApartment)
            IconButton(
              onPressed: () {
                showApartmentForm(edit: true);
              },
              icon: const Icon(Icons.edit_outlined, color: primaryColor),
            ),
        ],
      ),

      body: loading
          ? const Center(child: CircularProgressIndicator(color: primaryColor))
          : !hasApartment
          ? _buildApartmentRequired()
          : _buildMainContent(),

      bottomNavigationBar: hasApartment ? _buildBottomNavigation() : null,
    );
  }

  // ============================================================
  // APARTMENT REQUIRED SCREEN
  // ============================================================

  Widget _buildApartmentRequired() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(25),
        child: Column(
          children: [
            Container(
              height: 110,
              width: 110,
              decoration: BoxDecoration(
                color: const Color(0xffDBEAFE),
                borderRadius: BorderRadius.circular(35),
              ),
              child: const Icon(Icons.apartment, size: 60, color: primaryColor),
            ),

            const SizedBox(height: 25),

            const Text(
              "Add Your Apartment",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 10),

            const Text(
              "To access Society Demand, Group Services and Batch Booking, first add your apartment details.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 14, height: 1.5),
            ),

            const SizedBox(height: 30),

            _buildRequiredItem(Icons.apartment, "Apartment / Society Name"),

            _buildRequiredItem(Icons.door_front_door, "Flat / Room Number"),

            _buildRequiredItem(Icons.location_on, "Complete Address"),

            const SizedBox(height: 25),

            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: () {
                  showApartmentForm();
                },
                icon: const Icon(Icons.add, color: Colors.white),
                label: const Text(
                  "Add My Apartment",
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
    );
  }

  Widget _buildRequiredItem(IconData icon, String title) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            height: 42,
            width: 42,
            decoration: const BoxDecoration(
              color: Color(0xffDBEAFE),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: primaryColor),
          ),

          const SizedBox(width: 12),

          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),

          const Icon(Icons.check_circle_outline, color: Colors.grey),
        ],
      ),
    );
  }

  // ============================================================
  // MAIN CONTENT
  // ============================================================

  Widget _buildMainContent() {
    switch (selectedBottomIndex) {
      case 0:
        return _buildSocietyHome();

      case 1:
        return _buildBatchScreen();

      case 2:
        return _buildStatusScreen();

      case 3:
        return _buildHistoryScreen();

      default:
        return _buildSocietyHome();
    }
  }

  // ============================================================
  // SOCIETY HOME
  // ============================================================

  Widget _buildSocietyHome() {
    return RefreshIndicator(
      onRefresh: () async {
        listenToSocietyBatches();
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildApartmentHeader(),

            const SizedBox(height: 25),

            _buildChooseServiceCard(),

            const SizedBox(height: 25),

            _buildDemandHeader(),

            const SizedBox(height: 15),

            _buildDemandList(),

            const SizedBox(height: 25),

            _buildHowItWorks(),

            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // APARTMENT HEADER
  // ============================================================

  Widget _buildApartmentHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [primaryColor, secondaryColor]),
        borderRadius: BorderRadius.circular(25),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                height: 60,
                width: 60,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.20),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(
                  Icons.apartment,
                  color: Colors.white,
                  size: 32,
                ),
              ),

              const SizedBox(width: 15),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      apartmentName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 19,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 5),

                    Text(
                      "Flat $flatNumber",
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 15),

          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.location_on, color: Colors.white70, size: 18),

              const SizedBox(width: 7),

              Expanded(
                child: Text(
                  apartmentAddress,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Row(
              children: [
                Icon(Icons.groups, color: Colors.white),

                SizedBox(width: 10),

                Expanded(
                  child: Text(
                    "Join your neighbours to create a service batch and get better group service opportunities.",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      height: 1.4,
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

  // ============================================================
  // CHOOSE SERVICE
  // ============================================================

  Widget _buildChooseServiceCard() {
    return GestureDetector(
      onTap: () {
        _showServicesModal();
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: const [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 6,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              height: 55,
              width: 55,
              decoration: BoxDecoration(
                color: const Color(0xffDBEAFE),
                borderRadius: BorderRadius.circular(17),
              ),
              child: const Icon(
                Icons.add_business,
                color: primaryColor,
                size: 28,
              ),
            ),

            const SizedBox(width: 15),

            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Need a Service?",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),

                  SizedBox(height: 5),

                  Text(
                    "Choose a service and join a society batch",
                    style: TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                ],
              ),
            ),

            Container(
              height: 42,
              width: 42,
              decoration: const BoxDecoration(
                color: primaryColor,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.arrow_forward, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // SERVICES MODAL
  // ============================================================

  void _showServicesModal({Map<String, dynamic>? batch}) {
    final bool isBatchJoin = batch != null;

    final String batchServiceName = batch?["serviceName"]?.toString() ?? "";

    final selectedBatchService = batchServiceName.isNotEmpty
        ? _findService(batchServiceName)
        : null;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black54,
      builder: (modalContext) {
        return _AnimatedServicesModal(
          services: services,

          // NEW
          selectedService: selectedBatchService,

          // NEW
          isLocked: isBatchJoin,

          onServiceSelected: (service) {
            Navigator.pop(modalContext);

            Future.delayed(const Duration(milliseconds: 150), () {
              if (!mounted) {
                return;
              }

              if (isBatchJoin) {
                // IMPORTANT:
                // Pass the ORIGINAL BATCH,
                // not only the service.
                _showBookingDialog(service, batch);
              } else {
                // Existing normal flow
                _showBookingDialog(service, null);
              }
            });
          },
        );
      },
    );
  }
  // ============================================================
  // DATE + TIME BOOKING
  // ============================================================

  void _showBookingDialog(
    Map<String, dynamic> service,
    Map<String, dynamic>? batch,
  ) {
    DateTime selectedDate = DateTime.now().add(const Duration(days: 1));

    String selectedTimeSlot = "08:00 AM - 09:00 AM";

    final timeSlots = [
      "08:00 AM - 09:00 AM",
      "09:00 AM - 10:00 AM",
      "10:00 AM - 11:00 AM",
      "11:00 AM - 12:00 PM",
      "12:00 PM - 01:00 PM",
      "02:00 PM - 03:00 PM",
      "03:00 PM - 04:00 PM",
      "04:00 PM - 05:00 PM",
      "05:00 PM - 06:00 PM",
    ];
    String monthName(int month) {
      const months = [
        "JAN",
        "FEB",
        "MAR",
        "APR",
        "MAY",
        "JUN",
        "JUL",
        "AUG",
        "SEP",
        "OCT",
        "NOV",
        "DEC",
      ];

      return months[month - 1];
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(0.65),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.88,
              decoration: const BoxDecoration(
                color: Color(0xffF8FAFC),
                borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
              ),
              child: SafeArea(
                child: Column(
                  children: [
                    // =====================================================
                    // TOP HANDLE
                    // =====================================================
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Container(
                        width: 48,
                        height: 5,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                    ),

                    // =====================================================
                    // SCROLLABLE CONTENT
                    // =====================================================
                    Expanded(
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // =================================================
                            // HEADER
                            // =================================================
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                // 3D SERVICE ICON
                                Transform(
                                  transform: Matrix4.identity()
                                    ..setEntry(3, 2, 0.001)
                                    ..rotateX(-0.08)
                                    ..rotateY(0.08),
                                  alignment: Alignment.center,
                                  child: Container(
                                    height: 68,
                                    width: 68,
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: [
                                          Color(0xffE0F2FE),
                                          Color(0xffBFDBFE),
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(22),
                                      boxShadow: [
                                        BoxShadow(
                                          color: primaryColor.withOpacity(0.18),
                                          blurRadius: 14,
                                          offset: const Offset(0, 8),
                                        ),
                                      ],
                                    ),
                                    child: Icon(
                                      service["icon"],
                                      color: primaryColor,
                                      size: 32,
                                    ),
                                  ),
                                ),

                                const SizedBox(width: 15),

                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        service["name"]?.toString() ??
                                            "Service",
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 22,
                                          fontWeight: FontWeight.w800,
                                          color: Color(0xff0F172A),
                                        ),
                                      ),

                                      const SizedBox(height: 5),

                                      Text(
                                        service["description"]?.toString() ??
                                            "Book this service for your apartment",
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: Colors.grey.shade600,
                                          fontSize: 12,
                                          height: 1.35,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 25),

                            // =================================================
                            // APARTMENT BATCH INFO
                            // =================================================
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xffEFF6FF),
                                    Color(0xffF0F9FF),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: const Color(0xffDBEAFE),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.blue.withOpacity(0.06),
                                    blurRadius: 15,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    height: 42,
                                    width: 42,
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(14),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.blue.withOpacity(0.10),
                                          blurRadius: 8,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: const Icon(
                                      Icons.apartment_rounded,
                                      color: primaryColor,
                                      size: 23,
                                    ),
                                  ),

                                  const SizedBox(width: 12),

                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          "Society Service Batch",
                                          style: TextStyle(
                                            fontWeight: FontWeight.w800,
                                            fontSize: 14,
                                            color: Color(0xff1E3A8A),
                                          ),
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          apartmentName,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: Colors.blueGrey.shade600,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  const Icon(
                                    Icons.groups_rounded,
                                    color: primaryColor,
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 27),

                            // =================================================
                            // DATE SECTION
                            // =================================================
                            const Text(
                              "Service Date",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: Color(0xff0F172A),
                              ),
                            ),

                            const SizedBox(height: 5),

                            Text(
                              "Choose a day that works for you",
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),

                            const SizedBox(height: 13),

                            // =================================================
                            // 3D DATE CARD
                            // =================================================
                            GestureDetector(
                              onTap: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  firstDate: DateTime.now(),
                                  lastDate: DateTime.now().add(
                                    const Duration(days: 30),
                                  ),
                                  initialDate: selectedDate,
                                );

                                if (picked != null) {
                                  setModalState(() {
                                    selectedDate = picked;
                                  });
                                }
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 250),
                                padding: const EdgeInsets.all(17),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [Colors.white, Color(0xffF1F5F9)],
                                  ),
                                  borderRadius: BorderRadius.circular(22),
                                  border: Border.all(
                                    color: const Color(0xffDBEAFE),
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: primaryColor.withOpacity(0.10),
                                      blurRadius: 18,
                                      offset: const Offset(0, 8),
                                    ),
                                    const BoxShadow(
                                      color: Colors.white,
                                      blurRadius: 2,
                                      offset: Offset(-2, -2),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  children: [
                                    // DAY
                                    Container(
                                      height: 58,
                                      width: 58,
                                      decoration: BoxDecoration(
                                        gradient: const LinearGradient(
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                          colors: [
                                            primaryColor,
                                            Color(0xff2563EB),
                                          ],
                                        ),
                                        borderRadius: BorderRadius.circular(18),
                                        boxShadow: [
                                          BoxShadow(
                                            color: primaryColor.withOpacity(
                                              0.25,
                                            ),
                                            blurRadius: 10,
                                            offset: const Offset(0, 6),
                                          ),
                                        ],
                                      ),
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            selectedDate.day.toString(),
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 22,
                                              fontWeight: FontWeight.w900,
                                            ),
                                          ),
                                          Text(
                                            monthName(selectedDate.month),
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 9,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),

                                    const SizedBox(width: 15),

                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            _formatDate(selectedDate),
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            "Tap to change date",
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.grey.shade600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),

                                    Container(
                                      height: 38,
                                      width: 38,
                                      decoration: const BoxDecoration(
                                        color: Color(0xffEFF6FF),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.calendar_month_rounded,
                                        color: primaryColor,
                                        size: 20,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            const SizedBox(height: 27),

                            // =================================================
                            // TIME SECTION
                            // =================================================
                            const Text(
                              "Time Slot",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: Color(0xff0F172A),
                              ),
                            ),

                            const SizedBox(height: 5),

                            Text(
                              "Pick a convenient time for the service",
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),

                            const SizedBox(height: 14),

                            // =================================================
                            // TIME SLOTS
                            // =================================================

                            // ===============================================================
                            // SERVORA - PREMIUM TIME SLOT SELECTOR
                            // ===============================================================
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: const Color(0xffF8FAFC),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: const Color(0xffE2E8F0),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // -----------------------------------------------------------
                                  // HEADER
                                  // -----------------------------------------------------------
                                  Row(
                                    children: [
                                      Container(
                                        width: 38,
                                        height: 38,
                                        decoration: BoxDecoration(
                                          color: primaryColor.withOpacity(0.10),
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        child: const Icon(
                                          Icons.schedule_rounded,
                                          color: primaryColor,
                                          size: 20,
                                        ),
                                      ),

                                      const SizedBox(width: 11),

                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            const Text(
                                              "Choose a time",
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w800,
                                                color: Color(0xff0F172A),
                                              ),
                                            ),

                                            const SizedBox(height: 3),

                                            Text(
                                              "Select your preferred service time",
                                              style: TextStyle(
                                                fontSize: 10.5,
                                                fontWeight: FontWeight.w500,
                                                color: Colors.blueGrey.shade400,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),

                                      // Selected time badge
                                      AnimatedSwitcher(
                                        duration: const Duration(
                                          milliseconds: 250,
                                        ),
                                        transitionBuilder: (child, animation) {
                                          return ScaleTransition(
                                            scale: animation,
                                            child: FadeTransition(
                                              opacity: animation,
                                              child: child,
                                            ),
                                          );
                                        },
                                        child: Container(
                                          key: ValueKey(selectedTimeSlot),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 9,
                                            vertical: 6,
                                          ),
                                          decoration: BoxDecoration(
                                            color: primaryColor.withOpacity(
                                              0.09,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                          ),
                                          child: Text(
                                            selectedTimeSlot.split(" - ").first,
                                            style: const TextStyle(
                                              color: primaryColor,
                                              fontSize: 10,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),

                                  const SizedBox(height: 16),

                                  // -----------------------------------------------------------
                                  // TIME GRID
                                  // -----------------------------------------------------------
                                  GridView.builder(
                                    shrinkWrap: true,
                                    physics:
                                        const NeverScrollableScrollPhysics(),
                                    padding: EdgeInsets.zero,
                                    itemCount: timeSlots.length,
                                    gridDelegate:
                                        const SliverGridDelegateWithFixedCrossAxisCount(
                                          crossAxisCount: 2,
                                          crossAxisSpacing: 10,
                                          mainAxisSpacing: 10,
                                          mainAxisExtent: 52,
                                        ),
                                    itemBuilder: (context, index) {
                                      final String slot = timeSlots[index];
                                      final bool isSelected =
                                          selectedTimeSlot == slot;

                                      final List<String> parts = slot.split(
                                        " - ",
                                      );

                                      final String startTime = parts.isNotEmpty
                                          ? parts[0]
                                          : slot;

                                      final String endTime = parts.length > 1
                                          ? parts[1]
                                          : "";

                                      return GestureDetector(
                                        onTap: () {
                                          setModalState(() {
                                            selectedTimeSlot = slot;
                                          });
                                        },
                                        child: AnimatedScale(
                                          scale: isSelected ? 1.025 : 1.0,
                                          duration: const Duration(
                                            milliseconds: 180,
                                          ),
                                          curve: Curves.easeOutBack,
                                          child: AnimatedContainer(
                                            duration: const Duration(
                                              milliseconds: 280,
                                            ),
                                            curve: Curves.easeOutCubic,

                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 11,
                                              vertical: 8,
                                            ),

                                            decoration: BoxDecoration(
                                              gradient: isSelected
                                                  ? const LinearGradient(
                                                      begin: Alignment.topLeft,
                                                      end:
                                                          Alignment.bottomRight,
                                                      colors: [
                                                        primaryColor,
                                                        Color(0xff2563EB),
                                                      ],
                                                    )
                                                  : null,

                                              color: isSelected
                                                  ? null
                                                  : Colors.white,

                                              borderRadius:
                                                  BorderRadius.circular(15),

                                              border: Border.all(
                                                width: isSelected ? 1.3 : 1,
                                                color: isSelected
                                                    ? primaryColor
                                                    : const Color(0xffE2E8F0),
                                              ),

                                              boxShadow: isSelected
                                                  ? [
                                                      BoxShadow(
                                                        color: primaryColor
                                                            .withOpacity(0.24),
                                                        blurRadius: 12,
                                                        offset: const Offset(
                                                          0,
                                                          5,
                                                        ),
                                                      ),
                                                    ]
                                                  : [
                                                      BoxShadow(
                                                        color: Colors.black
                                                            .withOpacity(0.025),
                                                        blurRadius: 5,
                                                        offset: const Offset(
                                                          0,
                                                          2,
                                                        ),
                                                      ),
                                                    ],
                                            ),

                                            child: Row(
                                              children: [
                                                // =================================================
                                                // CLOCK / CHECK ICON
                                                // =================================================
                                                AnimatedContainer(
                                                  duration: const Duration(
                                                    milliseconds: 220,
                                                  ),

                                                  width: 32,
                                                  height: 32,

                                                  decoration: BoxDecoration(
                                                    color: isSelected
                                                        ? Colors.white
                                                              .withOpacity(0.18)
                                                        : primaryColor
                                                              .withOpacity(
                                                                0.08,
                                                              ),

                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          10,
                                                        ),
                                                  ),

                                                  child: AnimatedSwitcher(
                                                    duration: const Duration(
                                                      milliseconds: 200,
                                                    ),

                                                    transitionBuilder:
                                                        (child, animation) {
                                                          return ScaleTransition(
                                                            scale: animation,
                                                            child:
                                                                FadeTransition(
                                                                  opacity:
                                                                      animation,
                                                                  child: child,
                                                                ),
                                                          );
                                                        },

                                                    child: Icon(
                                                      isSelected
                                                          ? Icons.check_rounded
                                                          : Icons
                                                                .access_time_rounded,

                                                      key: ValueKey(isSelected),

                                                      size: 17,

                                                      color: isSelected
                                                          ? Colors.white
                                                          : primaryColor,
                                                    ),
                                                  ),
                                                ),

                                                const SizedBox(width: 8),

                                                // =================================================
                                                // TIME
                                                // =================================================
                                                Expanded(
                                                  child: Row(
                                                    children: [
                                                      Flexible(
                                                        child: Text(
                                                          startTime,
                                                          maxLines: 1,
                                                          overflow: TextOverflow
                                                              .ellipsis,

                                                          style: TextStyle(
                                                            color: isSelected
                                                                ? Colors.white
                                                                : const Color(
                                                                    0xff1E293B,
                                                                  ),

                                                            fontSize: 10.5,
                                                            fontWeight:
                                                                FontWeight.w800,
                                                          ),
                                                        ),
                                                      ),

                                                      Padding(
                                                        padding:
                                                            const EdgeInsets.symmetric(
                                                              horizontal: 3,
                                                            ),
                                                        child: Text(
                                                          "–",
                                                          style: TextStyle(
                                                            color: isSelected
                                                                ? Colors.white
                                                                      .withOpacity(
                                                                        0.65,
                                                                      )
                                                                : const Color(
                                                                    0xffCBD5E1,
                                                                  ),
                                                            fontSize: 10,
                                                            fontWeight:
                                                                FontWeight.w700,
                                                          ),
                                                        ),
                                                      ),

                                                      Flexible(
                                                        child: Text(
                                                          endTime,
                                                          maxLines: 1,
                                                          overflow: TextOverflow
                                                              .ellipsis,

                                                          style: TextStyle(
                                                            color: isSelected
                                                                ? Colors.white
                                                                      .withOpacity(
                                                                        0.78,
                                                                      )
                                                                : const Color(
                                                                    0xff64748B,
                                                                  ),

                                                            fontSize: 9.5,
                                                            fontWeight:
                                                                FontWeight.w600,
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),

                                                const SizedBox(width: 5),

                                                // =================================================
                                                // RADIO INDICATOR
                                                // =================================================
                                                AnimatedSwitcher(
                                                  duration: const Duration(
                                                    milliseconds: 220,
                                                  ),

                                                  transitionBuilder:
                                                      (child, animation) {
                                                        return ScaleTransition(
                                                          scale: CurvedAnimation(
                                                            parent: animation,
                                                            curve: Curves
                                                                .easeOutBack,
                                                          ),
                                                          child: child,
                                                        );
                                                      },

                                                  child: isSelected
                                                      ? const Icon(
                                                          Icons
                                                              .radio_button_checked_rounded,
                                                          key: ValueKey(
                                                            "checked",
                                                          ),
                                                          size: 16,
                                                          color: Colors.white,
                                                        )
                                                      : const Icon(
                                                          Icons
                                                              .radio_button_unchecked_rounded,
                                                          key: ValueKey(
                                                            "unchecked",
                                                          ),
                                                          size: 16,
                                                          color: Color(
                                                            0xffCBD5E1,
                                                          ),
                                                        ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 27),

                            // =================================================
                            // FINAL INFORMATION CARD
                            // =================================================
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: const Color(0xffF0FDF4),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: const Color(0xffBBF7D0),
                                ),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    height: 40,
                                    width: 40,
                                    decoration: const BoxDecoration(
                                      color: Colors.white,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.check_circle_rounded,
                                      color: Color(0xff16A34A),
                                      size: 23,
                                    ),
                                  ),

                                  const SizedBox(width: 11),

                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          "Joining your society batch",
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w800,
                                            color: Color(0xff166534),
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          "Your request will be grouped with other residents requesting the same service.",
                                          style: TextStyle(
                                            fontSize: 11,
                                            height: 1.4,
                                            color: Colors.green.shade700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 25),

                            // =================================================
                            // JOIN BUTTON
                            // =================================================
                            SizedBox(
                              width: double.infinity,
                              height: 56,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  elevation: 8,
                                  shadowColor: primaryColor.withOpacity(0.35),
                                  backgroundColor: primaryColor,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                ),
                                onPressed: () async {
                                  Navigator.pop(sheetContext);

                                  await _joinBatch(
                                    service: service,
                                    selectedDate: selectedDate,
                                    selectedTimeSlot: selectedTimeSlot,
                                  );
                                },
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(
                                      Icons.groups_rounded,
                                      color: Colors.white,
                                    ),
                                    const SizedBox(width: 9),
                                    const Text(
                                      "Join Society Batch",
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 16,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    const Icon(
                                      Icons.arrow_forward_rounded,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                  ],
                                ),
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
          },
        );
      },
    );
  }
  // ============================================================
  // JOIN BATCH
  // ============================================================

  Future<void> _joinBatch({
    required Map<String, dynamic> service,
    Map<String, dynamic>? batch,
    required DateTime selectedDate,
    required String selectedTimeSlot,
  }) async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      _showMessage("Please login first", Colors.red);
      return;
    }

    // ============================================================
    // CHECK APARTMENT DATA
    // ============================================================

    if (apartmentName.trim().isEmpty ||
        flatNumber.trim().isEmpty ||
        apartmentAddress.trim().isEmpty) {
      _showMessage("Please complete your apartment details first.", Colors.red);
      return;
    }

    // ============================================================
    // CHECK LOCATION
    // ============================================================

    if (selectedLatitude == null || selectedLongitude == null) {
      _showMessage(
        "Please select your apartment location on the map first.",
        Colors.red,
      );
      return;
    }

    // ============================================================
    // GET SERVICE INFORMATION
    // ============================================================

    final String serviceId = batch?["serviceId"]?.toString().isNotEmpty == true
        ? batch!["serviceId"].toString()
        : service["id"]?.toString() ?? "";

    final String serviceName =
        batch?["serviceName"]?.toString().isNotEmpty == true
        ? batch!["serviceName"].toString()
        : service["name"]?.toString() ?? "";

    if (serviceId.isEmpty || serviceName.isEmpty) {
      _showMessage("Unable to identify this service batch.", Colors.red);
      return;
    }

    // ============================================================
    // APARTMENT KEY
    // ============================================================

    final String targetApartmentKey =
        batch?["apartmentKey"]?.toString().isNotEmpty == true
        ? batch!["apartmentKey"].toString()
        : apartmentKey;

    // ============================================================
    // BATCH REFERENCE
    //
    // societyServiceBatches/
    //     {apartmentKey}/
    //         {serviceId}
    // ============================================================

    final DatabaseReference batchRef = _database
        .child("societyServiceBatches")
        .child(targetApartmentKey)
        .child(serviceId);

    try {
      // ============================================================
      // GET EXISTING BATCH
      // ============================================================

      final DataSnapshot existing = await batchRef.get();

      Map<String, dynamic>? existingData;

      int currentCount = 0;

      if (existing.exists && existing.value is Map) {
        existingData = Map<String, dynamic>.from(existing.value as Map);

        currentCount =
            int.tryParse(existingData["requestCount"]?.toString() ?? "0") ?? 0;
      }

      // ============================================================
      // CHECK WHETHER THIS IS A NEW BATCH
      //
      // IMPORTANT:
      // This MUST be outside the above if block.
      // ============================================================

      final bool isNewBatch = existingData == null;

      debugPrint("Society batch exists: ${existing.exists}");

      debugPrint("Is new society batch: $isNewBatch");

      // ============================================================
      // IMPORTANT:
      // CHECK IF PRICE IS ALREADY LOCKED
      //
      // Once worker starts work:
      //
      // priceLocked = true
      // lockedPrice = current price
      //
      // Nobody can join after this.
      // ============================================================

      if (existingData != null && existingData["priceLocked"] == true) {
        _showMessage(
          "This batch is already locked because work has started. "
          "You cannot join now.",
          Colors.orange,
        );
        return;
      }

      // ============================================================
      // IF USER IS JOINING AN EXISTING BATCH,
      // THAT BATCH MUST STILL EXIST
      // ============================================================

      if (batch != null && !existing.exists) {
        _showMessage(
          "This service batch is no longer available.",
          Colors.orange,
        );
        return;
      }

      // ============================================================
      // CHECK IF USER ALREADY JOINED
      // ============================================================

      final DatabaseReference participantRef = batchRef
          .child("participants")
          .child(user.uid);

      final DataSnapshot alreadyJoined = await participantRef.get();

      if (alreadyJoined.exists) {
        _showMessage(
          "You have already joined this service batch.",
          Colors.orange,
        );
        return;
      }

      // ============================================================
      // NEW PARTICIPANT COUNT
      // ============================================================

      final int newCount = currentCount + 1;

      // ============================================================
      // BATCH DATA
      //
      // IMPORTANT:
      // DO NOT SET priceLocked = false HERE.
      //
      // If the batch is already locked, we already returned above.
      // ============================================================

      final Map<String, dynamic> batchData = {
        "serviceId": serviceId,
        "serviceName": serviceName,
        "apartmentName": apartmentName,
        "apartmentKey": targetApartmentKey,
        "address": apartmentAddress,
        "latitude": selectedLatitude,
        "longitude": selectedLongitude,
        "requestCount": newCount,
        "status": "collecting",
        "updatedAt": ServerValue.timestamp,
      };

      // ============================================================
      // CREATE TIME ONLY FOR NEW BATCH
      // ============================================================

      if (!existing.exists) {
        batchData["createdAt"] = ServerValue.timestamp;
      }

      // ============================================================
      // UPDATE BATCH
      // ============================================================

      await batchRef.update(batchData);

      // ============================================================
      // ADD PARTICIPANT
      // ============================================================

      await participantRef.set({
        "uid": user.uid,
        "flatNumber": flatNumber,
        "apartmentName": apartmentName,
        "address": apartmentAddress,
        "latitude": selectedLatitude,
        "longitude": selectedLongitude,

        // ========================================================
        // SERVICE INFORMATION
        // ========================================================
        "serviceId": serviceId,
        "serviceName": serviceName,

        // ========================================================
        // BOOKING INFORMATION
        // ========================================================
        "selectedDate": _firebaseDate(selectedDate),

        "timeSlot": selectedTimeSlot,

        // ========================================================
        // STATUS
        // ========================================================
        "joinedAt": ServerValue.timestamp,

        "status": "joined",
      });

      // ============================================================
      // 🔔 NOTIFY NEARBY VENDORS
      //
      // ONLY WHEN A COMPLETELY NEW BATCH IS CREATED.
      //
      // New batch  → notify vendors within 20 KM
      // Existing   → don't notify again
      // ============================================================

      if (isNewBatch) {
        try {
          await _notifyNearbyVendorsAboutSocietyBatch(
            batchId: serviceId,
            serviceId: serviceId,
            serviceName: serviceName,
            apartmentName: apartmentName,
            apartmentKey: targetApartmentKey,
            latitude: selectedLatitude!,
            longitude: selectedLongitude!,
            requestCount: newCount,
          );

          debugPrint("Nearby vendors notified about new society batch.");
        } catch (e) {
          // IMPORTANT:
          // Batch creation should NOT fail just because
          // notification API failed.

          debugPrint("Society batch notification error: $e");
        }
      }

      // ============================================================
      // SUCCESS
      // ============================================================

      if (!mounted) {
        return;
      }

      _showMessage("You joined the $serviceName batch!", Colors.green);

      setState(() {
        selectedBottomIndex = 1;
      });
    } catch (e) {
      debugPrint("JOIN BATCH ERROR: $e");

      if (!mounted) {
        return;
      }

      _showMessage("Unable to join batch. Please try again.", Colors.red);
    }
  }
  // ============================================================
  // SOCIETY DEMAND
  // ============================================================

  Widget _buildDemandHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "🔥 Society Demand",
              style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
            ),

            SizedBox(height: 5),

            Text(
              "See what your neighbours are requesting",
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),

        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: const Color(0xffDCFCE7),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Row(
            children: [
              Icon(Icons.circle, size: 7, color: Colors.green),
              SizedBox(width: 5),
              Text(
                "LIVE",
                style: TextStyle(
                  color: Colors.green,
                  fontWeight: FontWeight.bold,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDemandList() {
    if (societyBatches.isEmpty) {
      return _buildEmptyDemand();
    }

    return Column(
      children: societyBatches.map((batch) {
        return _buildDemandCard(batch);
      }).toList(),
    );
  }

  // ============================================================
  // DEMAND CARD
  // ============================================================
  Widget _buildDemandCard(Map<String, dynamic> batch) {
    final String apartmentKey = batch["apartmentKey"]?.toString() ?? "";

    final String serviceId = batch["serviceId"]?.toString() ?? "";

    if (apartmentKey.isEmpty || serviceId.isEmpty) {
      return _buildDemandCardContent(batch, 0);
    }

    final DatabaseReference bidsRef = FirebaseDatabase.instance.ref(
      "societyServiceBatches/"
      "$apartmentKey/"
      "$serviceId/"
      "bids",
    );

    return StreamBuilder<DatabaseEvent>(
      stream: bidsRef.onValue,
      builder: (context, snapshot) {
        int currentVendorPrice = 0;

        if (snapshot.hasData && snapshot.data!.snapshot.exists) {
          final dynamic value = snapshot.data!.snapshot.value;

          if (value is Map) {
            for (final child in snapshot.data!.snapshot.children) {
              final dynamic childValue = child.value;

              if (childValue is! Map) {
                continue;
              }

              final Map<String, dynamic> bid = Map<String, dynamic>.from(
                childValue,
              );

              final String status =
                  bid["status"]?.toString().toLowerCase() ?? "";

              // Use the active/selected vendor
              if (status != "selected" && status != "pending") {
                continue;
              }

              final double currentPrice =
                  double.tryParse(bid["currentPrice"]?.toString() ?? "0") ?? 0;

              final double bidAmount =
                  double.tryParse(bid["bidAmount"]?.toString() ?? "0") ?? 0;

              final double finalPrice = currentPrice > 0
                  ? currentPrice
                  : bidAmount;

              if (finalPrice > 0) {
                currentVendorPrice = finalPrice.round();

                break;
              }
            }
          }
        }

        debugPrint("💰 LIVE CUSTOMER PRICE = ₹$currentVendorPrice");

        return _buildDemandCardContent(batch, currentVendorPrice);
      },
    );
  }

  Widget _buildDemandCardContent(
    Map<String, dynamic> batch,
    int currentVendorPrice,
  ) {
    // ------------------------------------------------------------
    // BASIC BATCH DATA
    // ------------------------------------------------------------

    final int count =
        int.tryParse(batch["requestCount"]?.toString() ?? "0") ?? 0;

    final String serviceName = batch["serviceName"]?.toString() ?? "Service";

    final String apartmentName =
        batch["apartmentName"]?.toString() ?? "Apartment";

    final String address =
        batch["address"]?.toString() ??
        batch["apartmentAddress"]?.toString() ??
        "Address not available";

    final String status = batch["status"]?.toString() ?? "collecting";

    final String currentUserId = FirebaseAuth.instance.currentUser?.uid ?? "";

    final Map<String, dynamic> participants = Map<String, dynamic>.from(
      batch["participants"] ?? {},
    );

    final bool hasJoined =
        currentUserId.isNotEmpty && participants.containsKey(currentUserId);

    final service = _findService(serviceName);

    final IconData icon = service?["icon"] ?? Icons.handyman;

    // ------------------------------------------------------------
    // PRICE LOCK
    // ------------------------------------------------------------

    final bool priceLocked = batch["priceLocked"] == true;

    final double lockedPrice =
        double.tryParse(batch["lockedPrice"]?.toString() ?? "0") ?? 0;

    // ------------------------------------------------------------
    // VENDOR CURRENT PRICE
    //
    // This price comes directly from:
    //
    // societyServiceBatches
    //   -> apartmentKey
    //   -> serviceId
    //   -> bids
    //   -> vendorId
    //   -> currentPrice
    //
    // NO ₹50 CALCULATION HERE.
    // ------------------------------------------------------------

    final double vendorCurrentPrice = currentVendorPrice.toDouble();

    // ------------------------------------------------------------
    // FINAL DISPLAY PRICE
    //
    // Before work starts:
    //     vendor currentPrice
    //
    // After work starts:
    //     lockedPrice
    // ------------------------------------------------------------

    final double displayPrice = priceLocked && lockedPrice > 0
        ? lockedPrice
        : vendorCurrentPrice;

    // ------------------------------------------------------------
    // PROGRESS
    // ------------------------------------------------------------

    const int targetFlats = 20;

    final double progress = (count / targetFlats).clamp(0.0, 1.0);

    return GestureDetector(
      onTap: () {
        _showBatchDetails(batch);
      },
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: const [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 7,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ====================================================
            // TOP SECTION
            // ====================================================
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // SERVICE ICON
                Container(
                  height: 54,
                  width: 54,
                  decoration: BoxDecoration(
                    color: const Color(0xffDBEAFE),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(icon, color: primaryColor, size: 27),
                ),

                const SizedBox(width: 13),

                // SERVICE + APARTMENT
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

                      const SizedBox(height: 5),

                      Row(
                        children: [
                          const Icon(
                            Icons.apartment,
                            size: 15,
                            color: Colors.grey,
                          ),

                          const SizedBox(width: 5),

                          Expanded(
                            child: Text(
                              apartmentName,
                              style: const TextStyle(
                                fontSize: 13,
                                color: Colors.grey,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // STATUS
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xffDCFCE7),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    status.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                      fontSize: 9,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // ====================================================
            // ADDRESS
            // ====================================================
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.location_on_outlined,
                  size: 18,
                  color: Colors.grey,
                ),

                const SizedBox(width: 6),

                Expanded(
                  child: Text(
                    address,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 18),

            // ====================================================
            // CURRENT DEMAND + CURRENT PRICE
            // ====================================================
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xffF8FAFC),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Row(
                children: [
                  Container(
                    height: 42,
                    width: 42,
                    decoration: BoxDecoration(
                      color: const Color(0xffDBEAFE),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.groups_outlined,
                      color: primaryColor,
                    ),
                  ),

                  const SizedBox(width: 11),

                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "$count flats joined",
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                        const SizedBox(height: 3),

                        Text(
                          priceLocked
                              ? "Price locked at ₹${displayPrice.toStringAsFixed(0)} per flat"
                              : "Current vendor price • More flats may reduce the price",
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // CURRENT PRICE
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        priceLocked ? "LOCKED PRICE" : "CURRENT",
                        style: TextStyle(
                          fontSize: 8,
                          color: priceLocked ? Colors.orange : Colors.grey,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 2),

                      Text(
                        displayPrice > 0
                            ? "₹${displayPrice.toStringAsFixed(0)}"
                            : "Price pending",
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: primaryColor,
                        ),
                      ),

                      const Text(
                        "/ flat",
                        style: TextStyle(fontSize: 9, color: Colors.grey),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ====================================================
            // GROUP PRICING TITLE
            // ====================================================
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Group pricing",
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),

                Text(
                  "$count / $targetFlats flats",
                  style: const TextStyle(
                    fontSize: 11,
                    color: Colors.grey,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),

            // ====================================================
            // PROGRESS BAR
            // ====================================================
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  height: 7,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: const Color(0xffE5E7EB),
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),

                FractionallySizedBox(
                  widthFactor: progress,
                  child: Container(
                    height: 7,
                    decoration: BoxDecoration(
                      color: primaryColor,
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),

                Positioned(
                  left: progress == 0
                      ? 0
                      : progress >= 1
                      ? null
                      : MediaQuery.of(context).size.width * progress - 36,
                  right: progress >= 1 ? 0 : null,
                  top: -5,
                  child: Container(
                    height: 17,
                    width: 17,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: priceLocked ? Colors.orange : primaryColor,
                        width: 4,
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            // ====================================================
            // PRICE STATUS
            // ====================================================
            priceLocked
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.lock_rounded,
                        size: 16,
                        color: Colors.orange,
                      ),

                      const SizedBox(width: 6),

                      Text(
                        "Price locked: ₹${displayPrice.toStringAsFixed(0)} / flat",
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange,
                        ),
                      ),
                    ],
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.trending_down,
                        size: 16,
                        color: primaryColor,
                      ),

                      const SizedBox(width: 6),

                      Text(
                        displayPrice > 0
                            ? "Current price: ₹${displayPrice.toStringAsFixed(0)} / flat"
                            : "Waiting for vendor price",
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: primaryColor,
                        ),
                      ),
                    ],
                  ),

            const SizedBox(height: 16),

            // ====================================================
            // NEXT LEVEL MESSAGE
            // ====================================================
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
              decoration: BoxDecoration(
                color: const Color(0xffEFF6FF),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    priceLocked ? Icons.lock_rounded : Icons.trending_down,
                    size: 19,
                    color: primaryColor,
                  ),

                  const SizedBox(width: 8),

                  Expanded(
                    child: Text(
                      priceLocked
                          ? "Price locked at ₹${displayPrice.toStringAsFixed(0)} per flat. This price will remain the same for all participating flats."
                          : "The current vendor price is ₹${displayPrice.toStringAsFixed(0)} per flat. As more flats join, the vendor may reduce the price.",
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: primaryColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 15),

            // ====================================================
            // JOIN THIS BATCH
            // ====================================================
            if (!hasJoined && !priceLocked)
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () {
                    _showServicesModal(batch: batch);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.group_add_rounded, size: 20),

                      SizedBox(width: 8),

                      Text(
                        "JOIN THIS BATCH",
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.3,
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

  Widget _buildPricePoint(String flats, String price) {
    return Column(
      children: [
        Text(
          flats,
          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 2),
        Text(price, style: const TextStyle(fontSize: 10, color: Colors.grey)),
      ],
    );
  }
  // ============================================================
  // BATCH SCREEN
  // ============================================================

  Widget _buildBatchScreen() {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Center(child: Text("Please login"));
    }

    final myBatches = societyBatches.where((batch) {
      final participants = batch["participants"];

      if (participants is! Map) {
        return false;
      }

      return participants.containsKey(user.uid);
    }).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "My Batches",
            style: TextStyle(fontSize: 25, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 6),

          const Text(
            "Services you joined in your apartment",
            style: TextStyle(color: Colors.grey),
          ),

          const SizedBox(height: 20),

          if (myBatches.isEmpty)
            _buildNoData(
              Icons.groups_outlined,
              "No batches joined",
              "Choose a service and join your society batch.",
            )
          else
            ...myBatches.map((batch) {
              return _buildMyBatchCard(batch);
            }),
        ],
      ),
    );
  }

  Widget _buildMyBatchCard(Map<String, dynamic> batch) {
    final participants = batch["participants"];

    final user = FirebaseAuth.instance.currentUser;

    Map<String, dynamic>? myData;

    if (participants is Map && user != null && participants[user.uid] is Map) {
      myData = Map<String, dynamic>.from(participants[user.uid]);
    }

    final service = _findService(batch["serviceName"]?.toString() ?? "");

    return GestureDetector(
      onTap: () {
        _showMyBatchDetails(batch);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 15),
        padding: const EdgeInsets.all(18),

        // ========================================================
        // CARD DESIGN
        // ========================================================
        decoration: BoxDecoration(
          color: const Color(0xffF7F9FC),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xffE2E8F0), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ====================================================
            // HEADER
            // ====================================================
            Row(
              children: [
                // SERVICE ICON
                Container(
                  height: 50,
                  width: 50,
                  decoration: BoxDecoration(
                    color: const Color(0xffE0ECFF),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    service?["icon"] ?? Icons.handyman,
                    color: primaryColor,
                    size: 25,
                  ),
                ),

                const SizedBox(width: 12),

                // SERVICE NAME
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        batch["serviceName"] ?? "Service",
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: Color(0xff172033),
                        ),
                      ),

                      const SizedBox(height: 4),

                      Text(
                        "Society service batch",
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
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
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xffE2E8F0)),
                  ),
                  child: const Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 16,
                    color: Color(0xff64748B),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // ====================================================
            // FLATS COUNT
            // ====================================================
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xffECFDF5),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.groups_outlined,
                    size: 17,
                    color: Color(0xff16A34A),
                  ),

                  const SizedBox(width: 6),

                  Text(
                    "${batch["requestCount"] ?? 0} flats joined",
                    style: const TextStyle(
                      color: Color(0xff15803D),
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 15),

            // ====================================================
            // CUSTOMER DETAILS
            // ====================================================
            if (myData != null) ...[
              Container(
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xffE5E7EB)),
                ),
                child: Column(
                  children: [
                    _infoRow(
                      Icons.calendar_today_outlined,
                      "Date",
                      myData["selectedDate"] ?? "Not selected",
                    ),

                    const SizedBox(height: 10),

                    _infoRow(
                      Icons.access_time_outlined,
                      "Time",
                      myData["timeSlot"] ?? "Not selected",
                    ),

                    const SizedBox(height: 10),

                    _infoRow(
                      Icons.home_outlined,
                      "Flat",
                      myData["flatNumber"] ?? flatNumber,
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 14),

            // ====================================================
            // VIEW DETAILS
            // ====================================================
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  "View details",
                  style: TextStyle(
                    color: primaryColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),

                const SizedBox(width: 5),

                Icon(
                  Icons.arrow_forward_rounded,
                  size: 17,
                  color: primaryColor,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showMyBatchDetails(Map<String, dynamic> batch) async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return;
    }

    final apartmentKey = batch["apartmentKey"]?.toString();

    final serviceId = batch["serviceId"]?.toString();

    if (apartmentKey == null || serviceId == null) {
      _showMessage("Batch information is missing.", Colors.red);
      return;
    }

    // ---------------------------------------------------------
    // CURRENT USER PARTICIPANT DATA
    // ---------------------------------------------------------

    Map<String, dynamic> myData = {};

    final participants = batch["participants"];

    if (participants is Map && participants[user.uid] is Map) {
      myData = Map<String, dynamic>.from(participants[user.uid]);
    }

    // ---------------------------------------------------------
    // SELECTED VENDOR
    // ---------------------------------------------------------

    Map<String, dynamic> vendorData = {};

    final selectedVendor = batch["selectedVendor"];

    if (selectedVendor is Map) {
      vendorData = Map<String, dynamic>.from(selectedVendor);
    }

    // ---------------------------------------------------------
    // VENDOR ID
    // ---------------------------------------------------------

    final vendorId =
        batch["selectedVendorId"]?.toString() ??
        vendorData["vendorId"]?.toString() ??
        vendorData["uid"]?.toString();

    // ---------------------------------------------------------
    // IF selectedVendor DOES NOT CONTAIN PHONE/NAME,
    // FETCH THE VENDOR FROM users
    // ---------------------------------------------------------

    if (vendorId != null && vendorId.isNotEmpty) {
      try {
        final vendorSnapshot = await FirebaseDatabase.instance
            .ref()
            .child("users")
            .child(vendorId)
            .get();

        if (vendorSnapshot.exists && vendorSnapshot.value is Map) {
          final firebaseVendor = Map<String, dynamic>.from(
            vendorSnapshot.value as Map,
          );

          // Firebase data becomes fallback.
          vendorData = {...firebaseVendor, ...vendorData};
        }
      } catch (e) {
        debugPrint("Vendor fetch error: $e");
      }
    }

    if (!mounted) return;

    _showVendorWorkModal(batch: batch, myData: myData, vendorData: vendorData);
  }

  void _showVendorWorkModal({
    required Map<String, dynamic> batch,
    required Map<String, dynamic> myData,
    required Map<String, dynamic> vendorData,
  }) {

    final currentUser = FirebaseAuth.instance.currentUser;

  if (currentUser == null) {
    return;
  }

  final userId = currentUser.uid;

  final serviceId =
      batch["serviceId"]?.toString() ?? "";
    final vendorName =
        vendorData["name"]?.toString() ??
        vendorData["vendorName"]?.toString() ??
        vendorData["fullName"]?.toString() ??
        "Vendor";

    final vendorPhone =
        vendorData["phone"]?.toString() ??
        vendorData["phoneNumber"]?.toString() ??
        "Phone not available";

    final batchStatus =
        batch["status"]?.toString().toLowerCase() ?? "collecting";

    // ============================================================
    // WORK OTP
    // ============================================================

    final workOtp =
        myData["workOtp"]?.toString() ??
        myData["workOTP"]?.toString() ??
        myData["otp"]?.toString();

    final completionOtp =
        myData["completionOtp"]?.toString() ??
        myData["completionOTP"]?.toString();

    // ============================================================
    // WORK STARTED
    // ============================================================

    final isStarted =
        myData["workStarted"] == true ||
        myData["workVerified"] == true ||
        myData["workStatus"]?.toString().toLowerCase() == "started" ||
        myData["workStatus"]?.toString().toLowerCase() == "in_progress" ||
        batchStatus == "started" ||
        batchStatus == "work_started" ||
        batchStatus == "in_progress";

    // ============================================================
    // WORK COMPLETED
    // ============================================================

    final isCompleted =
        myData["completed"] == true ||
        myData["completionStatus"]?.toString().toLowerCase() == "completed" ||
        myData["workStatus"]?.toString().toLowerCase() == "completed" ||
        batchStatus == "completed";

    // ============================================================
    // GET AMOUNT FROM SELECTED VENDOR BID
    // ============================================================

    double serviceAmount = 0.0;

    final selectedVendorId = batch["selectedVendorId"]?.toString();

    final bids = batch["bids"];

    if (bids is Map) {
      // ----------------------------------------------------------
      // FIRST: selectedVendorId
      // ----------------------------------------------------------

      if (selectedVendorId != null && selectedVendorId.isNotEmpty) {
        final selectedBid = bids[selectedVendorId];

        if (selectedBid is Map) {
          serviceAmount =
              double.tryParse(selectedBid["bidAmount"]?.toString() ?? "0") ??
              0.0;
        }
      }

      // ----------------------------------------------------------
      // SECOND: FIND status = selected
      // ----------------------------------------------------------

      if (serviceAmount == 0.0) {
        for (final entry in bids.entries) {
          final bid = entry.value;

          if (bid is Map) {
            final status = bid["status"]?.toString().toLowerCase();

            if (status == "selected") {
              serviceAmount =
                  double.tryParse(bid["bidAmount"]?.toString() ?? "0") ?? 0.0;

              break;
            }
          }
        }
      }
    }

    // ============================================================
    // PAYMENT STATUS
    // ============================================================

    final isPaid =
        myData["isPaid"] == true ||
        myData["paymentStatus"]?.toString().toLowerCase() == "paid" ||
        batch["isPaid"] == true ||
        batch["paymentStatus"]?.toString().toLowerCase() == "paid";

    // ============================================================
    // SHOW MODAL
    // ============================================================
    showModalBottomSheet(
      context: context,

      isScrollControlled: true,

      backgroundColor: Colors.transparent,

      builder: (context) {
        return SafeArea(
          child: Container(
            constraints: const BoxConstraints(maxHeight: 700),

            decoration: const BoxDecoration(
              color: Colors.white,

              borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
            ),

            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 25),

              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,

                children: [
                  // ==================================================
                  // DRAG HANDLE
                  // ==================================================
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

                  const SizedBox(height: 22),

                  // ==================================================
                  // HEADER
                  // ==================================================
                  Row(
                    children: [
                      Container(
                        height: 58,
                        width: 58,

                        decoration: BoxDecoration(
                          color: const Color(0xffDBEAFE),
                          borderRadius: BorderRadius.circular(18),
                        ),

                        child: const Icon(
                          Icons.home_repair_service_rounded,
                          color: primaryColor,
                          size: 29,
                        ),
                      ),

                      const SizedBox(width: 13),

                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              batch["serviceName"]?.toString() ?? "Service",

                              style: const TextStyle(
                                fontSize: 19,
                                fontWeight: FontWeight.bold,
                              ),
                            ),

                            const SizedBox(height: 4),

                            Text(
                              batch["apartmentName"]?.toString() ?? "Apartment",

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

                  const SizedBox(height: 25),

                  // ==================================================
                  // VENDOR CARD
                  // ==================================================
                  Container(
                    padding: const EdgeInsets.all(17),

                    decoration: BoxDecoration(
                      color: const Color(0xffF8FAFC),

                      borderRadius: BorderRadius.circular(20),

                      border: Border.all(color: const Color(0xffE2E8F0)),
                    ),

                    child: Column(
                      children: [
                        Row(
                          children: [
                            Container(
                              height: 55,
                              width: 55,

                              decoration: const BoxDecoration(
                                color: Color(0xffDCFCE7),
                                shape: BoxShape.circle,
                              ),

                              child: const Icon(
                                Icons.person_rounded,
                                color: Colors.green,
                                size: 29,
                              ),
                            ),

                            const SizedBox(width: 13),

                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    "Assigned Vendor",
                                    style: TextStyle(
                                      color: Colors.grey,
                                      fontSize: 11,
                                    ),
                                  ),

                                  const SizedBox(height: 3),

                                  Text(
                                    vendorName,

                                    maxLines: 1,

                                    overflow: TextOverflow.ellipsis,

                                    style: const TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 15),

                        // PHONE
                        Container(
                          width: double.infinity,

                          padding: const EdgeInsets.all(13),

                          decoration: BoxDecoration(
                            color: Colors.white,

                            borderRadius: BorderRadius.circular(13),
                          ),

                          child: Row(
                            children: [
                              const Icon(
                                Icons.phone,
                                color: primaryColor,
                                size: 20,
                              ),

                              const SizedBox(width: 10),

                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      "Phone",
                                      style: TextStyle(
                                        color: Colors.grey,
                                        fontSize: 10,
                                      ),
                                    ),

                                    const SizedBox(height: 2),

                                    Text(
                                      vendorPhone,

                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              if (vendorPhone != "Phone not available")
                                IconButton(
                                  onPressed: () {
                                    // Add url_launcher call here
                                  },

                                  icon: const Icon(
                                    Icons.call_rounded,
                                    color: Colors.green,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 18),

                  // ==================================================
                  // WORK STATUS
                  // ==================================================
                  _buildWorkStatusCard(batchStatus),

                  const SizedBox(height: 18),

                  // ==================================================
                  // OTP
                  // ==================================================
                  _buildWorkOtpCard(
  workOtp: workOtp,
  completionOtp: completionOtp,
  isStarted: isStarted,
  isCompleted: isCompleted,
  amount: serviceAmount,
  isPaid: isPaid,
  apartmentKey: apartmentKey,
  serviceId: serviceId,
  userId: userId,
),
                  const SizedBox(height: 18),

                  // ==================================================
                  // USER BOOKING INFORMATION
                  // ==================================================
                  Container(
                    padding: const EdgeInsets.all(16),

                    decoration: BoxDecoration(
                      color: const Color(0xffF8FAFC),

                      borderRadius: BorderRadius.circular(18),
                    ),

                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Your Service Details",
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                        const SizedBox(height: 14),

                        _modalInfoRow(
                          Icons.calendar_today_outlined,
                          "Date",
                          myData["selectedDate"]?.toString(),
                        ),

                        const SizedBox(height: 10),

                        _modalInfoRow(
                          Icons.access_time_rounded,
                          "Time",
                          myData["timeSlot"]?.toString(),
                        ),

                        const SizedBox(height: 10),

                        _modalInfoRow(
                          Icons.home_outlined,
                          "Flat",
                          myData["flatNumber"]?.toString(),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ==================================================
                  // CLOSE BUTTON
                  // ==================================================
                  SizedBox(
                    width: double.infinity,

                    height: 50,

                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                      },

                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,

                        elevation: 0,

                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),

                      child: const Text(
                        "Close",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
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
  }

  Widget _buildWorkStatusCard(String status) {
    String title;
    String message;
    Color color;
    IconData icon;

    if (status == "completed") {
      title = "Work Completed";
      message = "The service has been completed.";
      color = Colors.green;
      icon = Icons.check_circle_rounded;
    } else if (status == "started" ||
        status == "work_started" ||
        status == "in_progress") {
      title = "Vendor Has Started";
      message = "The vendor has started working on your service.";
      color = Colors.blue;
      icon = Icons.engineering_rounded;
    } else if (status == "vendor_selected") {
      title = "Vendor Assigned";
      message = "Your vendor has been selected. Waiting for work to start.";
      color = Colors.orange;
      icon = Icons.person_pin_circle_rounded;
    } else {
      title = "Waiting for Vendor";
      message = "A vendor has not started the service yet.";
      color = Colors.orange;
      icon = Icons.hourglass_top_rounded;
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),

      width: double.infinity,

      padding: const EdgeInsets.all(16),

      decoration: BoxDecoration(
        color: color.withOpacity(0.08),

        borderRadius: BorderRadius.circular(18),

        border: Border.all(color: color.withOpacity(0.18)),
      ),

      child: Row(
        children: [
          Container(
            height: 45,
            width: 45,

            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              shape: BoxShape.circle,
            ),

            child: Icon(icon, color: color, size: 24),
          ),

          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: color,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 4),

                Text(
                  message,
                  style: const TextStyle(
                    color: Colors.black54,
                    fontSize: 11,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _startApartmentPayment({
  required double amount,
  required String apartmentKey,
  required String serviceId,
  required String userId,
}) async {
  try {
    if (amount <= 0) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Invalid payment amount."),
          backgroundColor: Colors.red,
        ),
      );

      return;
    }

    debugPrint("========================================");
    debugPrint("APARTMENT PAYMENT START");
    debugPrint("Amount: ₹$amount");
    debugPrint("Apartment: $apartmentKey");
    debugPrint("Service: $serviceId");
    debugPrint("User: $userId");
    debugPrint("========================================");

    // ============================================================
    // 1. CREATE RAZORPAY ORDER
    // ============================================================

    final orderData = await paymentApiService.createOrder(
      amount: amount,
    );

    final orderId = orderData["id"]?.toString();

    if (orderId == null || orderId.isEmpty) {
      throw Exception("Razorpay Order ID not received.");
    }

    // ============================================================
    // 2. PAYMENT SUCCESS CALLBACK
    // ============================================================

    paymentService.onPaymentSuccess = (response) async {
      try {
        debugPrint("========================================");
        debugPrint("APARTMENT PAYMENT VERIFIED");
        debugPrint("Payment ID: ${response.paymentId}");
        debugPrint("Order ID: ${response.orderId}");
        debugPrint("Signature: ${response.signature}");
        debugPrint("========================================");

        // ========================================================
        // SAVE PAYMENT AGAINST THIS FLAT / PARTICIPANT
        // ========================================================

        final participantRef = _database
            .child("societyServiceBatches")
            .child(apartmentKey)
            .child(serviceId)
            .child("participants")
            .child(userId);

        await participantRef.update({
          "paymentStatus": "paid",
          "isPaid": true,
          "paymentAmount": amount,
          "paymentCurrency": "INR",
          "paymentId": response.paymentId ?? "",
          "paymentOrderId": response.orderId ?? orderId,
          "paymentSignature": response.signature ?? "",
          "paymentCompletedAt": ServerValue.timestamp,
        });

        debugPrint(
          "APARTMENT PAYMENT SAVED SUCCESSFULLY",
        );

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "Payment completed successfully.",
            ),
            backgroundColor: Colors.green,
          ),
        );

        // Refresh screen data
        setState(() {});
      } catch (e) {
        debugPrint(
          "APARTMENT PAYMENT SAVE ERROR: $e",
        );

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "Payment verified, but payment details could not be saved.",
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    };

    // ============================================================
    // 3. PAYMENT ERROR CALLBACK
    // ============================================================

    paymentService.onPaymentError = (response) {
      debugPrint(
        "APARTMENT PAYMENT FAILED: ${response.message}",
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            response.message ?? "Payment failed.",
          ),
          backgroundColor: Colors.red,
        ),
      );
    };

    // ============================================================
    // 4. OPEN RAZORPAY
    // ============================================================

    final amountInPaise = (amount * 100).round();

    paymentService.openCheckout(
      keyId: "rzp_test_TSI2EhlZvprEF7",
      amountInPaise: amountInPaise,
      orderId: orderId,
      description: "Servora Apartment Service Payment",
    );
  } catch (e) {
    debugPrint(
      "APARTMENT PAYMENT ERROR: $e",
    );

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          "Unable to start payment. Please try again.",
        ),
        backgroundColor: Colors.red,
      ),
    );
  }
}
Widget _buildWorkOtpCard({
  required String? workOtp,
  required String? completionOtp,
  required bool isStarted,
  required bool isCompleted,
  required double amount,
  required bool isPaid,
  required String apartmentKey,
  required String serviceId,
  required String userId,
}) {
    final hasWorkOtp = workOtp != null && workOtp.isNotEmpty;

    final hasCompletionOtp = completionOtp != null && completionOtp.isNotEmpty;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 500),
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xffEFF6FF), Color(0xffF8FAFC)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: primaryColor.withOpacity(0.15)),
      ),
      child: Column(
        children: [
          // =====================================================
          // HEADER
          // =====================================================
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.verified_user_rounded,
                color: primaryColor,
                size: 20,
              ),

              const SizedBox(width: 7),

              const Text(
                "Service Verification",
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: primaryColor,
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          Text(
            isCompleted
                ? "Your service has been completed successfully."
                : isStarted
                ? "Use the completion code after the vendor finishes the work."
                : "Use the start code when the vendor arrives to begin the work.",
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 10,
              height: 1.4,
            ),
          ),

          const SizedBox(height: 18),

          // =====================================================
          // WORK START OTP
          // =====================================================
          _buildOtpSection(
            title: "Work Start OTP",
            subtitle: isStarted
                ? "Used to verify and start your service"
                : "Give this code to the vendor when work starts",
            otp: workOtp,
            icon: Icons.play_circle_fill_rounded,
            color: primaryColor,
            emptyText: "Waiting for vendor to start work",
          ),

          // =====================================================
          // COMPLETION OTP
          // =====================================================
          if (isStarted || hasCompletionOtp || hasCompletionOtp) ...[
            const SizedBox(height: 18),

            Container(
              height: 1,
              width: double.infinity,
              color: const Color(0xffE2E8F0),
            ),

            const SizedBox(height: 18),

            _buildOtpSection(
              title: "Work Completion OTP",
              subtitle: isCompleted
                  ? "This code was used to complete the service"
                  : "Give this code to the vendor after work is finished",
              otp: completionOtp,
              icon: Icons.task_alt_rounded,
              color: Colors.green,
              emptyText: "Completion code will appear here",
            ),
          ],

          // =====================================================
          // COMPLETED MESSAGE
          // =====================================================
          if (isCompleted) ...[
            const SizedBox(height: 18),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xffECFDF5), Color(0xffF0FDF4)],
                ),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.green.withOpacity(0.20)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.green.withOpacity(0.06),
                    blurRadius: 12,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Completed icon
                  Container(
                    height: 52,
                    width: 52,
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      color: Colors.green,
                      size: 30,
                    ),
                  ),

                  const SizedBox(height: 10),

                  const Text(
                    "Service Completed",
                    style: TextStyle(
                      color: Colors.green,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 5),

                  const Text(
                    "Your service has been completed successfully.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 11,
                      height: 1.4,
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Payment amount
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 15,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.green.withOpacity(0.12)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          height: 40,
                          width: 40,
                          decoration: BoxDecoration(
                            color: primaryColor.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(11),
                          ),
                          child: const Icon(
                            Icons.currency_rupee_rounded,
                            color: primaryColor,
                            size: 21,
                          ),
                        ),

                        const SizedBox(width: 11),

                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Amount to Pay",
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 10,
                                ),
                              ),
                              SizedBox(height: 3),
                              Text(
                                "Service Payment",
                                style: TextStyle(
                                  color: Colors.black87,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),

                        Text(
                          "₹${amount.toStringAsFixed(2)}",
                          style: const TextStyle(
                            color: Colors.black87,
                            fontSize: 19,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Payment button
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: isPaid
    ? null
    : () {
        _startApartmentPayment(
          amount: amount,
          apartmentKey: apartmentKey,
          serviceId: serviceId,
          userId: userId,
        );
      },
                      icon: Icon(
                        isPaid
                            ? Icons.check_circle_rounded
                            : Icons.payment_rounded,
                      ),
                      label: Text(
                        isPaid
                            ? "Payment Completed"
                            : "Pay ₹${amount.toStringAsFixed(2)}",
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isPaid ? Colors.green : primaryColor,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: Colors.green,
                        disabledForegroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildOtpSection({
    required String title,
    required String subtitle,
    required String? otp,
    required IconData icon,
    required Color color,
    required String emptyText,
  }) {
    final hasOtp = otp != null && otp.isNotEmpty;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.75),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.12)),
      ),
      child: Column(
        children: [
          // =================================================
          // TITLE
          // =================================================
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 19),

              const SizedBox(width: 7),

              Text(
                title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),

          const SizedBox(height: 6),

          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 10,
              height: 1.35,
            ),
          ),

          const SizedBox(height: 14),

          // =================================================
          // OTP
          // =================================================
          if (hasOtp)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: otp.split("").map((digit) {
                return Container(
                  height: 48,
                  width: 40,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(11),
                    border: Border.all(color: color.withOpacity(0.25)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 7,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      digit,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                  ),
                );
              }).toList(),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
              decoration: BoxDecoration(
                color: const Color(0xffF8FAFC),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Text(
                emptyText,
                style: const TextStyle(
                  color: Colors.grey,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _modalInfoRow(IconData icon, String title, String? value) {
    return Row(
      children: [
        Icon(icon, size: 18, color: primaryColor),

        const SizedBox(width: 10),

        Expanded(
          child: Text(
            title,
            style: const TextStyle(color: Colors.grey, fontSize: 12),
          ),
        ),

        Text(
          value == null || value.isEmpty ? "Not available" : value,

          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  // ============================================================
  // STATUS SCREEN
  // ============================================================

  Widget _buildStatusScreen() {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Center(child: Text("Please login"));
    }

    final myBatches = societyBatches.where((batch) {
      final participants = batch["participants"];

      if (participants is! Map) {
        return false;
      }

      return participants.containsKey(user.uid);
    }).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Service Status",
            style: TextStyle(fontSize: 25, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 6),

          const Text(
            "Track your apartment service requests",
            style: TextStyle(color: Colors.grey, fontSize: 14),
          ),

          const SizedBox(height: 20),

          if (myBatches.isEmpty)
            _buildNoData(
              Icons.track_changes,
              "No active service",
              "Your joined service batches will appear here.",
            )
          else
            ...myBatches.map((batch) => _buildStatusCard(batch)),
        ],
      ),
    );
  }

  Widget _buildStatusCard(Map<String, dynamic> batch) {
    final rawStatus = batch["status"];

    final status = rawStatus?.toString().toLowerCase().trim() ?? "collecting";

    final count = batch["requestCount"] ?? 0;

    IconData statusIcon;
    String statusText;
    Color statusColor;

    switch (status) {
      case "vendor_selected":
      case "vendor selected":
        statusIcon = Icons.verified_rounded;
        statusText = "Vendor Selected";
        statusColor = Colors.blue;
        break;

      case "scheduled":
        statusIcon = Icons.calendar_month_rounded;
        statusText = "Service Scheduled";
        statusColor = Colors.purple;
        break;

      case "started":
      case "work_started":
      case "in_progress":
      case "work_in_progress":
        statusIcon = Icons.engineering_rounded;
        statusText = "Work In Progress";
        statusColor = Colors.orange;
        break;

      case "completed":
        statusIcon = Icons.check_circle_rounded;
        statusText = "Completed";
        statusColor = Colors.green;
        break;

      default:
        statusIcon = Icons.groups_rounded;
        statusText = "Collecting Residents";
        statusColor = Colors.orange;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),

          // ⭐ CLICK CARD
          onTap: () {
            _showUserServiceStatus(batch);
          },

          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                // STATUS ICON
                Container(
                  height: 54,
                  width: 54,
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(statusIcon, color: statusColor, size: 27),
                ),

                const SizedBox(width: 14),

                // SERVICE INFORMATION
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        batch["serviceName"]?.toString() ?? "Service",
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),

                      const SizedBox(height: 6),

                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.10),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          statusText,
                          style: TextStyle(
                            color: statusColor,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ),

                      const SizedBox(height: 6),

                      Text(
                        "$count flats in this batch",
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),

                // ARROW
                Container(
                  height: 38,
                  width: 38,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 15,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showUserServiceStatus(Map<String, dynamic> batch) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return;
    }

    final participants = batch["participants"];

    if (participants is! Map) {
      return;
    }

    final rawMyData = participants[user.uid];

    final Map<String, dynamic> myData = rawMyData is Map
        ? Map<String, dynamic>.from(rawMyData)
        : <String, dynamic>{};

    // ============================================================
    // BASIC DATA
    // ============================================================

    final serviceName = batch["serviceName"]?.toString() ?? "Service";

    final apartmentName = batch["apartmentName"]?.toString() ?? "Apartment";

    final flatNumber = myData["flatNumber"]?.toString() ?? "N/A";

    final timeSlot = myData["timeSlot"]?.toString() ?? "";

    final selectedDate = myData["selectedDate"]?.toString() ?? "";

    final batchStatus =
        batch["status"]?.toString().toLowerCase().trim() ?? "collecting";

    // ============================================================
    // FIND SELECTED VENDOR
    // ============================================================

    bool vendorSelected = false;

    final selectedVendorId = batch["selectedVendorId"]?.toString();

    final bids = batch["bids"];

    if (selectedVendorId != null && selectedVendorId.isNotEmpty) {
      vendorSelected = true;
    }

    if (bids is Map) {
      for (final entry in bids.entries) {
        final bid = entry.value;

        if (bid is Map) {
          final bidStatus =
              bid["status"]?.toString().toLowerCase().trim() ?? "";

          if (bidStatus == "selected") {
            vendorSelected = true;
            break;
          }
        }
      }
    }

    // Batch status can also tell us that vendor has been selected.
    if ([
      "vendor_selected",
      "scheduled",
      "started",
      "work_started",
      "in_progress",
      "work_in_progress",
      "completed",
    ].contains(batchStatus)) {
      vendorSelected = true;
    }

    // ============================================================
    // SCHEDULED
    // ============================================================

    final scheduled =
        batchStatus == "scheduled" ||
        batchStatus == "started" ||
        batchStatus == "work_started" ||
        batchStatus == "in_progress" ||
        batchStatus == "work_in_progress" ||
        batchStatus == "completed" ||
        (selectedDate.isNotEmpty && timeSlot.isNotEmpty);

    // ============================================================
    // WORK STARTED
    // ============================================================

    final workStatus =
        myData["workStatus"]?.toString().toLowerCase().trim() ?? "";

    final completionStatus =
        myData["completionStatus"]?.toString().toLowerCase().trim() ?? "";

    final isStarted =
        myData["workStarted"] == true ||
        myData["workVerified"] == true ||
        workStatus == "started" ||
        workStatus == "in_progress" ||
        workStatus == "work_started" ||
        workStatus == "completed" ||
        completionStatus == "completed";

    // ============================================================
    // COMPLETED
    // ============================================================

    final isCompleted =
        myData["completed"] == true ||
        completionStatus == "completed" ||
        workStatus == "completed";

    // ============================================================
    // PAYMENT
    // ============================================================

    final paymentStatus =
        myData["paymentStatus"]?.toString().toLowerCase().trim() ?? "";

    final isPaid =
        myData["isPaid"] == true ||
        paymentStatus == "paid" ||
        paymentStatus == "completed" ||
        paymentStatus == "success" ||
        paymentStatus == "successful";

    // ============================================================
    // GET BID AMOUNT
    // ============================================================

    double serviceAmount = 0.0;

    if (bids is Map) {
      // First try selectedVendorId.
      if (selectedVendorId != null && selectedVendorId.isNotEmpty) {
        final selectedBid = bids[selectedVendorId];

        if (selectedBid is Map) {
          serviceAmount =
              double.tryParse(selectedBid["bidAmount"]?.toString() ?? "0") ??
              0.0;
        }
      }

      // If still 0, find bid whose status is selected.
      if (serviceAmount == 0.0) {
        for (final entry in bids.entries) {
          final bid = entry.value;

          if (bid is Map) {
            final bidStatus =
                bid["status"]?.toString().toLowerCase().trim() ?? "";

            if (bidStatus == "selected") {
              serviceAmount =
                  double.tryParse(bid["bidAmount"]?.toString() ?? "0") ?? 0.0;

              break;
            }
          }
        }
      }
    }

    // Fallback to participant payment amount if available.
    if (serviceAmount == 0.0) {
      serviceAmount =
          double.tryParse(
            (myData["paymentAmount"] ??
                    myData["serviceAmount"] ??
                    myData["amount"] ??
                    0)
                .toString(),
          ) ??
          0.0;
    }

    // ============================================================
    // OTP
    // ============================================================

    final workOtp = myData["workOtp"]?.toString();

    final completionOtp = myData["completionOtp"]?.toString();

    // ============================================================
    // STATUS LABEL
    // ============================================================

    String currentStatus;

    if (isPaid) {
      currentStatus = "Payment Completed";
    } else if (isCompleted) {
      currentStatus = "Service Completed";
    } else if (isStarted) {
      currentStatus = "Work In Progress";
    } else if (scheduled) {
      currentStatus = "Service Scheduled";
    } else if (vendorSelected) {
      currentStatus = "Vendor Selected";
    } else {
      currentStatus = "Request Submitted";
    }

    // ============================================================
    // BOTTOM SHEET
    // ============================================================

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return SafeArea(
          child: Container(
            constraints: const BoxConstraints(maxHeight: 780),
            decoration: const BoxDecoration(
              color: Color(0xffF8F9FB),
              borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
            ),
            child: Column(
              children: [
                // ==================================================
                // HEADER
                // ==================================================
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                  child: Column(
                    children: [
                      Container(
                        width: 45,
                        height: 5,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),

                      const SizedBox(height: 18),

                      Row(
                        children: [
                          Container(
                            height: 48,
                            width: 48,
                            decoration: BoxDecoration(
                              color: Colors.blue.withOpacity(0.10),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.home_repair_service_rounded,
                              color: Colors.blue,
                            ),
                          ),

                          const SizedBox(width: 12),

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

                                const SizedBox(height: 3),

                                Text(
                                  "$apartmentName • Flat $flatNumber",
                                  style: const TextStyle(
                                    color: Colors.grey,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: isPaid
                                  ? Colors.green.withOpacity(0.10)
                                  : isCompleted
                                  ? Colors.green.withOpacity(0.10)
                                  : Colors.orange.withOpacity(0.10),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              currentStatus,
                              style: TextStyle(
                                color: isPaid || isCompleted
                                    ? Colors.green
                                    : Colors.orange,
                                fontWeight: FontWeight.w600,
                                fontSize: 10,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const Divider(height: 1),

                // ==================================================
                // SCROLLABLE CONTENT
                // ==================================================
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // =================================================
                        // SCHEDULE INFORMATION
                        // =================================================
                        if (scheduled &&
                            (selectedDate.isNotEmpty || timeSlot.isNotEmpty))
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(15),
                            margin: const EdgeInsets.only(bottom: 22),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  height: 42,
                                  width: 42,
                                  decoration: BoxDecoration(
                                    color: Colors.purple.withOpacity(0.10),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.calendar_month_rounded,
                                    color: Colors.purple,
                                    size: 21,
                                  ),
                                ),

                                const SizedBox(width: 12),

                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        "Scheduled Service",
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                        ),
                                      ),

                                      const SizedBox(height: 4),

                                      Text(
                                        [
                                          if (selectedDate.isNotEmpty)
                                            selectedDate,
                                          if (timeSlot.isNotEmpty) timeSlot,
                                        ].join(" • "),
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

                        const Text(
                          "Service Progress",
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                        const SizedBox(height: 18),

                        // =================================================
                        // ANIMATED VERTICAL TIMELINE
                        // =================================================
                        TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0, end: 1),
                          duration: const Duration(milliseconds: 900),
                          curve: Curves.easeOutCubic,
                          builder: (context, animationValue, child) {
                            return Column(
                              children: [
                                // REQUEST
                                _buildTimelineStep(
                                  title: "Request Submitted",
                                  subtitle:
                                      "You joined the apartment service batch",
                                  icon: Icons.check_circle_rounded,
                                  completed: true,
                                  active: !vendorSelected,
                                  animationValue: animationValue,
                                  isLast: false,
                                ),

                                // VENDOR
                                _buildTimelineStep(
                                  title: "Vendor Selected",
                                  subtitle: vendorSelected
                                      ? "A vendor has been selected for this service"
                                      : "Waiting for admin to select a vendor",
                                  icon: Icons.verified_rounded,
                                  completed: vendorSelected,
                                  active: vendorSelected && !scheduled,
                                  animationValue: animationValue,
                                  isLast: false,
                                ),

                                // SCHEDULED
                                _buildTimelineStep(
                                  title: "Service Scheduled",
                                  subtitle: scheduled
                                      ? "Your service has been scheduled"
                                      : "Waiting for service scheduling",
                                  icon: Icons.calendar_month_rounded,
                                  completed: scheduled,
                                  active: scheduled && !isStarted,
                                  animationValue: animationValue,
                                  isLast: false,
                                ),

                                // WORK STARTED
                                _buildTimelineStep(
                                  title: "Work Started",
                                  subtitle: isStarted
                                      ? "Vendor has started the work"
                                      : "Waiting for vendor to start work",
                                  icon: Icons.play_circle_fill_rounded,
                                  completed: isStarted,
                                  active: isStarted && !isCompleted,
                                  animationValue: animationValue,
                                  isLast: false,
                                ),

                                // COMPLETED
                                _buildTimelineStep(
                                  title: "Service Completed",
                                  subtitle: isCompleted
                                      ? "Your service has been completed"
                                      : "Service is not completed yet",
                                  icon: Icons.task_alt_rounded,
                                  completed: isCompleted,
                                  active: isCompleted && !isPaid,
                                  animationValue: animationValue,
                                  isLast: false,
                                ),

                                // PAYMENT
                                _buildTimelineStep(
                                  title: isPaid
                                      ? "Payment Completed"
                                      : "Payment Pending",
                                  subtitle: isPaid
                                      ? "Payment successfully completed"
                                      : isCompleted
                                      ? "Complete payment to finish the process"
                                      : "Payment will be available after service completion",
                                  icon: isPaid
                                      ? Icons.payments_rounded
                                      : Icons.payment_rounded,
                                  completed: isPaid,
                                  active: isCompleted && !isPaid,
                                  animationValue: animationValue,
                                  isLast: true,
                                ),
                              ],
                            );
                          },
                        ),

                        // =================================================
                        // WORK START OTP
                        // =================================================
                        if (isStarted && workOtp != null && workOtp.isNotEmpty)
                          Container(
                            width: double.infinity,
                            margin: const EdgeInsets.only(top: 12),
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      height: 42,
                                      width: 42,
                                      decoration: BoxDecoration(
                                        color: Colors.blue.withOpacity(0.10),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.lock_open_rounded,
                                        color: Colors.blue,
                                      ),
                                    ),

                                    const SizedBox(width: 12),

                                    const Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            "Work Start OTP",
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                            ),
                                          ),
                                          SizedBox(height: 3),
                                          Text(
                                            "Used to verify the beginning of your service",
                                            style: TextStyle(
                                              color: Colors.grey,
                                              fontSize: 11,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 15),

                                Center(
                                  child: Text(
                                    workOtp,
                                    style: const TextStyle(
                                      fontSize: 30,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 10,
                                      color: Colors.blue,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                        // =================================================
                        // COMPLETION OTP
                        // =================================================
                        if (isStarted &&
                            completionOtp != null &&
                            completionOtp.isNotEmpty)
                          Container(
                            width: double.infinity,
                            margin: const EdgeInsets.only(top: 12),
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: Colors.green.withOpacity(0.25),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      height: 42,
                                      width: 42,
                                      decoration: BoxDecoration(
                                        color: Colors.green.withOpacity(0.10),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.task_alt_rounded,
                                        color: Colors.green,
                                      ),
                                    ),

                                    const SizedBox(width: 12),

                                    const Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            "Work Completion OTP",
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                            ),
                                          ),
                                          SizedBox(height: 3),
                                          Text(
                                            "Give this OTP to the vendor after your work is finished",
                                            style: TextStyle(
                                              color: Colors.grey,
                                              fontSize: 11,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 15),

                                Center(
                                  child: Text(
                                    completionOtp,
                                    style: const TextStyle(
                                      fontSize: 30,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 10,
                                      color: Colors.green,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                        // =================================================
                        // COMPLETED + PAYMENT
                        // =================================================
                        if (isCompleted)
                          Container(
                            width: double.infinity,
                            margin: const EdgeInsets.only(top: 18),
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(22),
                              border: Border.all(
                                color: Colors.green.withOpacity(0.20),
                              ),
                            ),
                            child: Column(
                              children: [
                                Container(
                                  height: 58,
                                  width: 58,
                                  decoration: BoxDecoration(
                                    color: Colors.green.withOpacity(0.10),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.check_circle_rounded,
                                    color: Colors.green,
                                    size: 34,
                                  ),
                                ),

                                const SizedBox(height: 12),

                                const Text(
                                  "Service Completed",
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),

                                const SizedBox(height: 5),

                                Text(
                                  isPaid
                                      ? "Payment has also been completed."
                                      : "Your service has been successfully completed.",
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Colors.grey,
                                    fontSize: 12,
                                  ),
                                ),

                                const SizedBox(height: 18),

                                // AMOUNT
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(15),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade50,
                                    borderRadius: BorderRadius.circular(15),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.currency_rupee_rounded,
                                        color: Colors.green,
                                      ),

                                      const SizedBox(width: 8),

                                      const Expanded(
                                        child: Text(
                                          "Service Amount",
                                          style: TextStyle(
                                            color: Colors.grey,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ),

                                      Text(
                                        "₹${serviceAmount.toStringAsFixed(2)}",
                                        style: const TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                const SizedBox(height: 15),

                                // PAYMENT BUTTON
                                SizedBox(
                                  width: double.infinity,
                                  height: 52,
                                  child: ElevatedButton.icon(
                                    onPressed: isPaid || serviceAmount <= 0
    ? null
    : () {
        final currentUser = FirebaseAuth.instance.currentUser;

        if (currentUser == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Please login again to make payment."),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }

        final serviceId =
            batch["serviceId"]?.toString() ?? "";

        _startApartmentPayment(
          amount: serviceAmount,
          apartmentKey: apartmentKey,
          serviceId: serviceId,
          userId: currentUser.uid,
        );
      },
                                    icon: Icon(
                                      isPaid
                                          ? Icons.check_circle
                                          : Icons.payment_rounded,
                                    ),
                                    label: Text(
                                      isPaid
                                          ? "Payment Completed"
                                          : serviceAmount <= 0
                                          ? "Amount Not Available"
                                          : "Pay ₹${serviceAmount.toStringAsFixed(2)}",
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green,
                                      foregroundColor: Colors.white,
                                      disabledBackgroundColor:
                                          Colors.grey.shade300,
                                      disabledForegroundColor:
                                          Colors.grey.shade600,
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(15),
                                      ),
                                    ),
                                  ),
                                ),

                                if (!isPaid && serviceAmount > 0)
                                  const Padding(
                                    padding: EdgeInsets.only(top: 10),
                                    child: Text(
                                      "You will be redirected to secure Razorpay checkout.",
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: Colors.grey,
                                        fontSize: 10,
                                      ),
                                    ),
                                  ),
                              ],
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
      },
    );
  }

  Widget _buildTimelineStep({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool completed,
    required bool active,
    required double animationValue,
    required bool isLast,
  }) {
    final Color stepColor = completed
        ? Colors.green
        : active
        ? Colors.blue
        : Colors.grey.shade400;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: animationValue),
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOut,
      builder: (context, value, child) {
        return Opacity(
          opacity: value.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, 15 * (1 - value)),
            child: Padding(
              padding: const EdgeInsets.only(bottom: 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ============================================
                  // LEFT TIMELINE
                  // ============================================
                  SizedBox(
                    width: 48,
                    child: Column(
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 350),
                          height: 42,
                          width: 42,
                          decoration: BoxDecoration(
                            color: stepColor.withOpacity(
                              completed || active ? 0.12 : 0.06,
                            ),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: stepColor,
                              width: completed || active ? 2 : 1,
                            ),
                          ),
                          child: Icon(
                            completed ? Icons.check_rounded : icon,
                            color: stepColor,
                            size: 21,
                          ),
                        ),

                        if (!isLast)
                          Container(
                            width: 2,
                            height: 70,
                            margin: const EdgeInsets.only(top: 3),
                            decoration: BoxDecoration(
                              color: completed
                                  ? Colors.green
                                  : Colors.grey.shade300,
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 12),

                  // ============================================
                  // RIGHT CONTENT
                  // ============================================
                  Expanded(
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 20),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: completed || active
                              ? stepColor.withOpacity(0.18)
                              : Colors.grey.shade200,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  title,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: completed || active
                                        ? Colors.black
                                        : Colors.grey.shade600,
                                  ),
                                ),
                              ),

                              if (completed)
                                const Icon(
                                  Icons.check_circle_rounded,
                                  color: Colors.green,
                                  size: 18,
                                )
                              else if (active)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 7,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.withOpacity(0.10),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Text(
                                    "CURRENT",
                                    style: TextStyle(
                                      color: Colors.blue,
                                      fontSize: 8,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                            ],
                          ),

                          const SizedBox(height: 5),

                          Text(
                            subtitle,
                            style: TextStyle(
                              color: completed || active
                                  ? Colors.grey
                                  : Colors.grey.shade400,
                              fontSize: 11,
                              height: 1.35,
                            ),
                          ),
                        ],
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
  }
  // ============================================================
  // HISTORY SCREEN
  // ============================================================

  Widget _buildHistoryScreen() {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Center(child: Text("Please login"));
    }

    // Get only services completed by the CURRENT USER.
    final completedServices = <Map<String, dynamic>>[];

    for (final batch in societyBatches) {
      final participants = batch["participants"];

      if (participants is! Map) {
        continue;
      }

      final rawMyData = participants[user.uid];

      if (rawMyData is! Map) {
        continue;
      }

      final myData = Map<String, dynamic>.from(rawMyData);

      final completionStatus =
          myData["completionStatus"]?.toString().toLowerCase().trim() ?? "";

      final workStatus =
          myData["workStatus"]?.toString().toLowerCase().trim() ?? "";

      final isCompleted =
          myData["completed"] == true ||
          completionStatus == "completed" ||
          workStatus == "completed";

      if (!isCompleted) {
        continue;
      }

      completedServices.add({"batch": batch, "myData": myData});
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Service History",
            style: TextStyle(fontSize: 25, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 6),

          const Text(
            "Your completed apartment services",
            style: TextStyle(color: Colors.grey, fontSize: 14),
          ),

          const SizedBox(height: 20),

          if (completedServices.isEmpty)
            _buildNoData(
              Icons.history_rounded,
              "No service history",
              "Completed society services will appear here.",
            )
          else
            ...completedServices.map((item) {
              final batch = item["batch"] as Map<String, dynamic>;

              final myData = item["myData"] as Map<String, dynamic>;

              return _buildHistoryCard(batch, myData);
            }),
        ],
      ),
    );
  }

  Widget _buildHistoryCard(
    Map<String, dynamic> batch,
    Map<String, dynamic> myData,
  ) {
    final serviceName = batch["serviceName"]?.toString() ?? "Service";

    final apartmentName = batch["apartmentName"]?.toString() ?? "Apartment";

    final flatNumber = myData["flatNumber"]?.toString() ?? "N/A";

    // ============================================================
    // COMPLETION DATE
    // ============================================================

    String completionDate = "Completed";

    final completedAt = myData["completedAt"];

    if (completedAt != null) {
      try {
        if (completedAt is int) {
          final date = DateTime.fromMillisecondsSinceEpoch(completedAt);

          completionDate =
              "${date.day.toString().padLeft(2, '0')}/"
              "${date.month.toString().padLeft(2, '0')}/"
              "${date.year}";
        } else {
          completionDate = completedAt.toString();
        }
      } catch (_) {
        completionDate = completedAt.toString();
      }
    }

    // ============================================================
    // PAYMENT STATUS
    // ============================================================

    final paymentStatus =
        myData["paymentStatus"]?.toString().toLowerCase().trim() ?? "";

    final isPaid =
        myData["isPaid"] == true ||
        paymentStatus == "paid" ||
        paymentStatus == "completed" ||
        paymentStatus == "success" ||
        paymentStatus == "successful";

    // ============================================================
    // FIND SELECTED VENDOR + AMOUNT
    // ============================================================

    String vendorName = "Vendor";

    double amount = 0.0;

    final selectedVendorId = batch["selectedVendorId"]?.toString();

    final bids = batch["bids"];

    if (bids is Map) {
      // First use selectedVendorId.
      if (selectedVendorId != null && selectedVendorId.isNotEmpty) {
        final selectedBid = bids[selectedVendorId];

        if (selectedBid is Map) {
          vendorName = selectedBid["vendorName"]?.toString() ?? "Vendor";

          amount =
              double.tryParse(selectedBid["bidAmount"]?.toString() ?? "0") ??
              0.0;
        }
      }

      // If selectedVendorId did not work,
      // find bid with status == selected.
      if (amount == 0.0 || vendorName == "Vendor") {
        for (final entry in bids.entries) {
          final bid = entry.value;

          if (bid is Map) {
            final status = bid["status"]?.toString().toLowerCase().trim() ?? "";

            if (status == "selected") {
              vendorName = bid["vendorName"]?.toString() ?? "Vendor";

              amount =
                  double.tryParse(bid["bidAmount"]?.toString() ?? "0") ?? 0.0;

              break;
            }
          }
        }
      }
    }

    // Fallback to participant payment amount.
    if (amount == 0.0) {
      amount =
          double.tryParse(
            (myData["paymentAmount"] ??
                    myData["serviceAmount"] ??
                    myData["amount"] ??
                    0)
                .toString(),
          ) ??
          0.0;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 15,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(22),

          // ======================================================
          // CLICK HISTORY CARD
          // ======================================================
          onTap: () {
            _showHistoryDetails(batch, myData);
          },

          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              children: [
                // ==================================================
                // TOP
                // ==================================================
                Row(
                  children: [
                    Container(
                      height: 52,
                      width: 52,
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.10),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check_circle_rounded,
                        color: Colors.green,
                        size: 28,
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
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),

                          const SizedBox(height: 5),

                          Text(
                            "$apartmentName • Flat $flatNumber",
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 16,
                      color: Colors.grey,
                    ),
                  ],
                ),

                const SizedBox(height: 17),

                const Divider(height: 1),

                const SizedBox(height: 15),

                // ==================================================
                // VENDOR + DATE
                // ==================================================
                Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Icon(
                            Icons.person_outline_rounded,
                            size: 18,
                            color: Colors.grey.shade600,
                          ),

                          const SizedBox(width: 7),

                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  "Vendor",
                                  style: TextStyle(
                                    color: Colors.grey,
                                    fontSize: 9,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  vendorName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    Expanded(
                      child: Row(
                        children: [
                          Icon(
                            Icons.calendar_today_rounded,
                            size: 17,
                            color: Colors.grey.shade600,
                          ),

                          const SizedBox(width: 7),

                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  "Completed",
                                  style: TextStyle(
                                    color: Colors.grey,
                                    fontSize: 9,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  completionDate,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
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

                const SizedBox(height: 15),

                // ==================================================
                // AMOUNT + PAYMENT
                // ==================================================
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.currency_rupee_rounded,
                              size: 18,
                              color: Colors.green.shade700,
                            ),

                            const SizedBox(width: 5),

                            Text(
                              amount.toStringAsFixed(2),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(width: 10),

                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 11,
                        vertical: 9,
                      ),
                      decoration: BoxDecoration(
                        color: isPaid
                            ? Colors.green.withOpacity(0.10)
                            : Colors.orange.withOpacity(0.10),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isPaid
                                ? Icons.check_circle_rounded
                                : Icons.schedule_rounded,
                            size: 15,
                            color: isPaid ? Colors.green : Colors.orange,
                          ),

                          const SizedBox(width: 5),

                          Text(
                            isPaid ? "Paid" : "Payment Pending",
                            style: TextStyle(
                              color: isPaid ? Colors.green : Colors.orange,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
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
        ),
      ),
    );
  }

  void _showHistoryDetails(
    Map<String, dynamic> batch,
    Map<String, dynamic> myData,
  ) {
    final serviceName = batch["serviceName"]?.toString() ?? "Service";

    final apartmentName = batch["apartmentName"]?.toString() ?? "Apartment";

    final flatNumber = myData["flatNumber"]?.toString() ?? "N/A";

    final selectedDate = myData["selectedDate"]?.toString() ?? "";

    final timeSlot = myData["timeSlot"]?.toString() ?? "";

    final paymentStatus =
        myData["paymentStatus"]?.toString().toLowerCase().trim() ?? "";

    final isPaid =
        myData["isPaid"] == true ||
        paymentStatus == "paid" ||
        paymentStatus == "completed" ||
        paymentStatus == "success" ||
        paymentStatus == "successful";

    // ============================================================
    // COMPLETION DATE
    // ============================================================

    String completionDate = "Not available";

    final completedAt = myData["completedAt"];

    if (completedAt != null) {
      try {
        if (completedAt is int) {
          final date = DateTime.fromMillisecondsSinceEpoch(completedAt);

          completionDate =
              "${date.day.toString().padLeft(2, '0')}/"
              "${date.month.toString().padLeft(2, '0')}/"
              "${date.year}";
        } else {
          completionDate = completedAt.toString();
        }
      } catch (_) {
        completionDate = completedAt.toString();
      }
    }

    // ============================================================
    // VENDOR + AMOUNT
    // ============================================================

    String vendorName = "Vendor";
    String vendorPhone = "";

    double amount = 0.0;

    final selectedVendorId = batch["selectedVendorId"]?.toString();

    final bids = batch["bids"];

    if (bids is Map) {
      // First selected vendor.
      if (selectedVendorId != null && selectedVendorId.isNotEmpty) {
        final selectedBid = bids[selectedVendorId];

        if (selectedBid is Map) {
          vendorName = selectedBid["vendorName"]?.toString() ?? "Vendor";

          vendorPhone = selectedBid["phone"]?.toString() ?? "";

          amount =
              double.tryParse(selectedBid["bidAmount"]?.toString() ?? "0") ??
              0.0;
        }
      }

      // Fallback: selected bid.
      if (amount == 0.0 || vendorName == "Vendor") {
        for (final entry in bids.entries) {
          final bid = entry.value;

          if (bid is Map) {
            final status = bid["status"]?.toString().toLowerCase().trim() ?? "";

            if (status == "selected") {
              vendorName = bid["vendorName"]?.toString() ?? "Vendor";

              vendorPhone = bid["phone"]?.toString() ?? "";

              amount =
                  double.tryParse(bid["bidAmount"]?.toString() ?? "0") ?? 0.0;

              break;
            }
          }
        }
      }
    }

    // Fallback amount.
    if (amount == 0.0) {
      amount =
          double.tryParse(
            (myData["paymentAmount"] ??
                    myData["serviceAmount"] ??
                    myData["amount"] ??
                    0)
                .toString(),
          ) ??
          0.0;
    }

    // ============================================================
    // PAYMENT ID
    // ============================================================

    final paymentId = myData["paymentId"]?.toString() ?? "";

    // ============================================================
    // BOTTOM SHEET
    // ============================================================

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return SafeArea(
          child: Container(
            constraints: const BoxConstraints(maxHeight: 760),
            decoration: const BoxDecoration(
              color: Color(0xffF8F9FB),
              borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
            ),
            child: Column(
              children: [
                // ==================================================
                // HEADER
                // ==================================================
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 18),
                  child: Column(
                    children: [
                      Container(
                        width: 45,
                        height: 5,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),

                      const SizedBox(height: 18),

                      Row(
                        children: [
                          Container(
                            height: 50,
                            width: 50,
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.10),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.check_circle_rounded,
                              color: Colors.green,
                              size: 28,
                            ),
                          ),

                          const SizedBox(width: 12),

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
                                  "$apartmentName • Flat $flatNumber",
                                  style: const TextStyle(
                                    color: Colors.grey,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.10),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Text(
                              "COMPLETED",
                              style: TextStyle(
                                color: Colors.green,
                                fontWeight: FontWeight.bold,
                                fontSize: 9,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const Divider(height: 1),

                // ==================================================
                // CONTENT
                // ==================================================
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // =================================================
                        // COMPLETION CARD
                        // =================================================
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.07),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.green.withOpacity(0.15),
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                height: 45,
                                width: 45,
                                decoration: BoxDecoration(
                                  color: Colors.green,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.check_rounded,
                                  color: Colors.white,
                                ),
                              ),

                              const SizedBox(width: 12),

                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      "Service Completed",
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                      ),
                                    ),

                                    const SizedBox(height: 4),

                                    Text(
                                      completionDate,
                                      style: const TextStyle(
                                        color: Colors.grey,
                                        fontSize: 11,
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
                        // SERVICE DETAILS
                        // =================================================
                        const Text(
                          "Service Details",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                        const SizedBox(height: 12),

                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(17),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Column(
                            children: [
                              _buildHistoryInfoRow(
                                Icons.home_rounded,
                                "Apartment",
                                apartmentName,
                              ),

                              const Divider(height: 22),

                              _buildHistoryInfoRow(
                                Icons.meeting_room_rounded,
                                "Flat",
                                flatNumber,
                              ),

                              if (selectedDate.isNotEmpty ||
                                  timeSlot.isNotEmpty) ...[
                                const Divider(height: 22),

                                _buildHistoryInfoRow(
                                  Icons.calendar_month_rounded,
                                  "Scheduled",
                                  [
                                    if (selectedDate.isNotEmpty) selectedDate,
                                    if (timeSlot.isNotEmpty) timeSlot,
                                  ].join(" • "),
                                ),
                              ],

                              const Divider(height: 22),

                              _buildHistoryInfoRow(
                                Icons.calendar_today_rounded,
                                "Completed",
                                completionDate,
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 20),

                        // =================================================
                        // VENDOR DETAILS
                        // =================================================
                        const Text(
                          "Vendor",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                        const SizedBox(height: 12),

                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(17),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Row(
                            children: [
                              Container(
                                height: 46,
                                width: 46,
                                decoration: BoxDecoration(
                                  color: Colors.blue.withOpacity(0.10),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.person_rounded,
                                  color: Colors.blue,
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
                                        fontSize: 14,
                                      ),
                                    ),

                                    if (vendorPhone.isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        vendorPhone,
                                        style: const TextStyle(
                                          color: Colors.grey,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 20),

                        // =================================================
                        // PAYMENT DETAILS
                        // =================================================
                        const Text(
                          "Payment",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                        const SizedBox(height: 12),

                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  const Expanded(
                                    child: Text(
                                      "Service Amount",
                                      style: TextStyle(
                                        color: Colors.grey,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),

                                  Text(
                                    "₹${amount.toStringAsFixed(2)}",
                                    style: const TextStyle(
                                      fontSize: 19,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 14),

                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 11,
                                  horizontal: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: isPaid
                                      ? Colors.green.withOpacity(0.08)
                                      : Colors.orange.withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      isPaid
                                          ? Icons.check_circle_rounded
                                          : Icons.schedule_rounded,
                                      size: 18,
                                      color: isPaid
                                          ? Colors.green
                                          : Colors.orange,
                                    ),

                                    const SizedBox(width: 8),

                                    Text(
                                      isPaid
                                          ? "Payment Completed"
                                          : "Payment Pending",
                                      style: TextStyle(
                                        color: isPaid
                                            ? Colors.green
                                            : Colors.orange,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              if (paymentId.isNotEmpty) ...[
                                const SizedBox(height: 12),

                                Row(
                                  children: [
                                    const Expanded(
                                      child: Text(
                                        "Payment ID",
                                        style: TextStyle(
                                          color: Colors.grey,
                                          fontSize: 10,
                                        ),
                                      ),
                                    ),

                                    Flexible(
                                      child: Text(
                                        paymentId,
                                        textAlign: TextAlign.end,
                                        style: const TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),

                        const SizedBox(height: 25),

                        // =================================================
                        // CLOSE BUTTON
                        // =================================================
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.pop(context);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.black87,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(15),
                              ),
                            ),
                            child: const Text(
                              "Done",
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
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
      },
    );
  }

  Widget _buildHistoryInfoRow(IconData icon, String title, String value) {
    return Row(
      children: [
        Container(
          height: 38,
          width: 38,
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 19, color: Colors.grey.shade700),
        ),

        const SizedBox(width: 11),

        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(color: Colors.grey, fontSize: 10),
              ),

              const SizedBox(height: 3),

              Text(
                value,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
  // ============================================================
  // HOW IT WORKS
  // ============================================================

  Widget _buildHowItWorks() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xffE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "How Society Service Works",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 18),

          _buildStep(
            "1",
            "Add your apartment",
            "Enter apartment name, flat number and complete address.",
          ),

          _buildStep(
            "2",
            "Choose a service",
            "Select AC, plumbing, electrical, cleaning or another service.",
          ),

          _buildStep(
            "3",
            "Choose date & time",
            "Select your preferred service date and appointment slot.",
          ),

          _buildStep(
            "4",
            "Join the batch",
            "Your request is added to the society service batch.",
          ),

          _buildStep(
            "5",
            "Society demand grows",
            "Other residents can join the same service.",
          ),

          _buildStep(
            "6",
            "Vendor handles the batch",
            "Servora can later select a vendor and schedule all flats efficiently.",
          ),
        ],
      ),
    );
  }

  Widget _buildStep(String number, String title, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 32,
            width: 32,
            decoration: const BoxDecoration(
              color: Color(0xffDBEAFE),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number,
                style: const TextStyle(
                  color: primaryColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),

          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),

                const SizedBox(height: 3),

                Text(
                  description,
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 12,
                    height: 1.4,
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
  // BOTTOM NAVIGATION
  // ============================================================

  Widget _buildBottomNavigation() {
    return BottomNavigationBar(
      currentIndex: selectedBottomIndex,
      type: BottomNavigationBarType.fixed,
      selectedItemColor: primaryColor,
      unselectedItemColor: Colors.grey,
      backgroundColor: Colors.white,
      onTap: (index) {
        setState(() {
          selectedBottomIndex = index;
        });
      },
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.apartment), label: "Society"),

        BottomNavigationBarItem(icon: Icon(Icons.groups), label: "Batches"),

        BottomNavigationBarItem(
          icon: Icon(Icons.track_changes),
          label: "Status",
        ),

        BottomNavigationBarItem(icon: Icon(Icons.history), label: "History"),
      ],
    );
  }

  // ============================================================
  // BATCH DETAILS
  // ============================================================

  void _showBatchDetails(Map<String, dynamic> batch) {
    final participants = batch["participants"];

    int participantCount = 0;

    if (participants is Map) {
      participantCount = participants.length;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    height: 5,
                    width: 45,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                Text(
                  batch["serviceName"] ?? "Service Batch",
                  style: const TextStyle(
                    fontSize: 23,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 15),

                _infoRow(
                  Icons.groups,
                  "Society Demand",
                  "$participantCount flats",
                ),

                const SizedBox(height: 10),

                _infoRow(
                  Icons.info_outline,
                  "Status",
                  batch["status"] ?? "Collecting",
                ),

                const SizedBox(height: 10),

                const _BatchInfoMessage(),

                const SizedBox(height: 20),

                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    child: const Text(
                      "Close",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ============================================================
  // HELPERS
  // ============================================================

  Map<String, dynamic>? _findService(String name) {
    for (final service in services) {
      if (service["name"].toString().toLowerCase() == name.toLowerCase()) {
        return service;
      }
    }

    return null;
  }

  String _formatDate(DateTime date) {
    const months = [
      "Jan",
      "Feb",
      "Mar",
      "Apr",
      "May",
      "Jun",
      "Jul",
      "Aug",
      "Sep",
      "Oct",
      "Nov",
      "Dec",
    ];

    return "${date.day} ${months[date.month - 1]} ${date.year}";
  }

  String _firebaseDate(DateTime date) {
    final month = date.month.toString().padLeft(2, "0");

    final day = date.day.toString().padLeft(2, "0");

    return "${date.year}-$month-$day";
  }

  Widget _infoRow(IconData icon, String title, String value) {
    return Row(
      children: [
        Icon(icon, size: 18, color: primaryColor),

        const SizedBox(width: 8),

        Text(
          "$title: ",
          style: const TextStyle(color: Colors.grey, fontSize: 13),
        ),

        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
        ),
      ],
    );
  }

  Widget _buildNoData(IconData icon, String title, String description) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Icon(icon, size: 50, color: Colors.grey),

          const SizedBox(height: 12),

          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
          ),

          const SizedBox(height: 6),

          Text(
            description,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 13,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyDemand() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Column(
        children: [
          Icon(Icons.groups_outlined, size: 50, color: Colors.grey),

          SizedBox(height: 12),

          Text(
            "No Society Demand Yet",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
          ),

          SizedBox(height: 6),

          Text(
            "Be the first resident to request a service.",
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey, fontSize: 13),
          ),
        ],
      ),
    );
  }

  void _showMessage(String message, Color color) {
    if (!mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message), backgroundColor: color));
  }

  Future<void> _notifyNearbyVendorsAboutSocietyBatch({
    required String batchId,
    required String serviceId,
    required String serviceName,
    required String apartmentName,
    required String apartmentKey,
    required double latitude,
    required double longitude,
    required int requestCount,
  }) async {
    try {
      final response = await http.post(
        Uri.parse(
          "http://127.0.0.1:8080/api/notifications/society-batch-created",
        ),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "batchId": batchId,
          "serviceId": serviceId,
          "serviceName": serviceName,
          "apartmentName": apartmentName,
          "apartmentKey": apartmentKey,
          "latitude": latitude,
          "longitude": longitude,
          "requestCount": requestCount,
        }),
      );

      debugPrint(
        "Society batch notification response: "
        "${response.statusCode} ${response.body}",
      );

      if (response.statusCode != 200) {
        throw Exception("Society batch notification failed: ${response.body}");
      }
    } catch (e) {
      debugPrint("Error notifying nearby vendors about society batch: $e");

      rethrow;
    }
  }
  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    _apartmentSubscription?.cancel();

    _batchSubscription?.cancel();

    super.dispose();
  }
}

// ================================================================
// BATCH INFO MESSAGE
// ================================================================

class _BatchInfoMessage extends StatelessWidget {
  const _BatchInfoMessage();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xffEFF6FF),
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lightbulb_outline, color: Color(0xff2563EB)),

          SizedBox(width: 10),

          Expanded(
            child: Text(
              "Servora groups residents requesting the same service. Vendor availability and pricing can be handled at the batch level.",
              style: TextStyle(
                color: Color(0xff1E40AF),
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AnimatedServicesModal extends StatefulWidget {
  final List<Map<String, dynamic>> services;
  final Function(Map<String, dynamic>) onServiceSelected;

  final Map<String, dynamic>? selectedService;
  final bool isLocked;

  const _AnimatedServicesModal({
    required this.services,
    required this.onServiceSelected,
    this.selectedService,
    this.isLocked = false,
  });

  @override
  State<_AnimatedServicesModal> createState() => _AnimatedServicesModalState();
}

class _AnimatedServicesModalState extends State<_AnimatedServicesModal>
    with TickerProviderStateMixin {
  late AnimationController _headerController;
  late AnimationController _cardsController;
  late AnimationController _floatingController;

  late Animation<double> _headerFade;
  late Animation<Offset> _headerSlide;
  late Animation<double> _floatingAnimation;
  static const Color primaryColor = Color(0xff2563EB);
  static const Color secondaryColor = Color(0xff0EA5E9);
  static const Color backgroundColor = Color(0xffF8FAFC);

  int? pressedIndex;

  @override
  void initState() {
    super.initState();

    // ==========================================================
    // HEADER ANIMATION
    // ==========================================================

    _headerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );

    _headerFade = CurvedAnimation(
      parent: _headerController,
      curve: Curves.easeOut,
    );

    _headerSlide = Tween<Offset>(begin: const Offset(0, 0.25), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _headerController,
            curve: Curves.easeOutCubic,
          ),
        );

    // ==========================================================
    // CARD ANIMATION
    // ==========================================================

    _cardsController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    // ==========================================================
    // FLOATING ANIMATION
    // ==========================================================

    _floatingController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );

    _floatingAnimation = Tween<double>(begin: -3, end: 3).animate(
      CurvedAnimation(parent: _floatingController, curve: Curves.easeInOut),
    );

    _headerController.forward();

    Future.delayed(const Duration(milliseconds: 180), () {
      if (mounted) {
        _cardsController.forward();
      }
    });

    _floatingController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _headerController.dispose();
    _cardsController.dispose();
    _floatingController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    return Container(
      height: screenHeight * 0.88,
      decoration: const BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        child: Stack(
          children: [
            // ==================================================
            // BACKGROUND GLOW
            // ==================================================
            Positioned(
              top: -100,
              right: -80,
              child: IgnorePointer(
                child: Container(
                  height: 240,
                  width: 240,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        primaryColor.withOpacity(0.12),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),

            Positioned(
              top: 180,
              left: -100,
              child: IgnorePointer(
                child: Container(
                  height: 220,
                  width: 220,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        const Color(0xff60A5FA).withOpacity(0.08),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // ==================================================
            // MAIN CONTENT
            // ==================================================
            Column(
              children: [
                const SizedBox(height: 12),

                // =================================================
                // DRAG HANDLE
                // =================================================
                Container(
                  height: 5,
                  width: 46,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),

                const SizedBox(height: 22),

                // =================================================
                // HEADER
                // =================================================
                FadeTransition(
                  opacity: _headerFade,
                  child: SlideTransition(
                    position: _headerSlide,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // HEADER ICON
                          AnimatedBuilder(
                            animation: _floatingAnimation,
                            builder: (context, child) {
                              return Transform.translate(
                                offset: Offset(0, _floatingAnimation.value),
                                child: child,
                              );
                            },
                            child: Container(
                              height: 54,
                              width: 54,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(17),
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    primaryColor,
                                    primaryColor.withOpacity(0.75),
                                  ],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: primaryColor.withOpacity(0.30),
                                    blurRadius: 18,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.home_repair_service_rounded,
                                color: Colors.white,
                                size: 28,
                              ),
                            ),
                          ),

                          const SizedBox(width: 14),

                          // TITLE
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Choose a Service",
                                  style: TextStyle(
                                    fontSize: 23,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.4,
                                  ),
                                ),

                                SizedBox(height: 4),

                                Text(
                                  "Select what you need in your apartment",
                                  style: TextStyle(
                                    color: Colors.grey,
                                    fontSize: 12.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // =================================================
                // SMALL INFO BAR
                // =================================================
                FadeTransition(
                  opacity: _headerFade,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 11,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(color: Colors.grey.shade200),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black12,
                            blurRadius: 5,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            height: 30,
                            width: 30,
                            decoration: BoxDecoration(
                              color: const Color(0xffDBEAFE),
                              borderRadius: BorderRadius.circular(9),
                            ),
                            child: const Icon(
                              Icons.groups_rounded,
                              color: primaryColor,
                              size: 18,
                            ),
                          ),

                          const SizedBox(width: 10),

                          const Expanded(
                            child: Text(
                              "Join with your neighbours and unlock group pricing",
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                            ),
                          ),

                          const Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 12,
                            color: Colors.grey,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 8),

                // =================================================
                // SERVICES
                // =================================================
                Expanded(
                  child: GridView.builder(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 30),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 14,
                          mainAxisSpacing: 14,
                          childAspectRatio: 0.82,
                        ),
                    itemCount: widget.services.length,
                    itemBuilder: (context, index) {
                      final service = widget.services[index];

                      final double start = (index * 0.10).clamp(0.0, 0.65);

                      final animation = CurvedAnimation(
                        parent: _cardsController,
                        curve: Interval(
                          start,
                          0.75 + (index * 0.04).clamp(0.0, 0.25),
                          curve: Curves.easeOutBack,
                        ),
                      );

                      return AnimatedBuilder(
                        animation: animation,
                        builder: (context, child) {
                          final value = animation.value;

                          return Opacity(
                            opacity: value.clamp(0.0, 1.0),
                            child: Transform.translate(
                              offset: Offset(0, 35 * (1 - value)),
                              child: Transform.scale(
                                scale: 0.90 + (0.10 * value),
                                child: child,
                              ),
                            ),
                          );
                        },
                        child: _buildPremiumServiceCard(service, index),
                      );
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // =============================================================
  // PREMIUM SERVICE CARD
  // =============================================================

  Widget _buildPremiumServiceCard(Map<String, dynamic> service, int index) {
    final bool isPressed = pressedIndex == index;

    // ==============================================================
    // CHECK WHETHER THIS IS THE SERVICE BELONGING TO THE BATCH
    // ==============================================================

    final bool isLockedService =
        widget.isLocked &&
        widget.selectedService != null &&
        widget.selectedService!["name"]?.toString() ==
            service["name"]?.toString();

    // In batch join mode:
    // - selected service = enabled
    // - all other services = disabled
    final bool isDisabled = widget.isLocked && !isLockedService;

    return GestureDetector(
      // ============================================================
      // TAP DOWN
      // ============================================================
      onTapDown: isDisabled
          ? null
          : (_) {
              setState(() {
                pressedIndex = index;
              });
            },

      // ============================================================
      // TAP CANCEL
      // ============================================================
      onTapCancel: isDisabled
          ? null
          : () {
              setState(() {
                pressedIndex = null;
              });
            },

      // ============================================================
      // TAP UP
      // ============================================================
      onTapUp: isDisabled
          ? null
          : (_) {
              setState(() {
                pressedIndex = null;
              });

              Future.delayed(const Duration(milliseconds: 70), () {
                if (!mounted) return;

                // ==================================================
                // BATCH JOIN MODE
                // ==================================================

                if (widget.isLocked) {
                  if (widget.selectedService == null) {
                    return;
                  }

                  final selectedName = widget.selectedService!["name"]
                      ?.toString();

                  final tappedName = service["name"]?.toString();

                  // Only the batch's actual service can continue
                  if (selectedName == tappedName) {
                    widget.onServiceSelected(widget.selectedService!);
                  }

                  return;
                }

                // ==================================================
                // NORMAL MODE
                // ==================================================

                widget.onServiceSelected(service);
              });
            },

      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 150),
        opacity: isDisabled ? 0.42 : 1.0,

        child: AnimatedScale(
          scale: isPressed && !isDisabled ? 0.94 : 1.0,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,

          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(23),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(isPressed ? 0.08 : 0.12),
                  blurRadius: isPressed ? 8 : 16,
                  offset: Offset(0, isPressed ? 3 : 7),
                ),
              ],
            ),

            child: ClipRRect(
              borderRadius: BorderRadius.circular(23),

              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(23),

                  border: Border.all(
                    color: isLockedService
                        ? primaryColor.withOpacity(0.35)
                        : Colors.white,
                    width: isLockedService ? 1.5 : 1.2,
                  ),
                ),

                child: Stack(
                  children: [
                    // =================================================
                    // TOP GLOW
                    // =================================================
                    Positioned(
                      top: -35,
                      right: -30,
                      child: Container(
                        height: 100,
                        width: 100,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: primaryColor.withOpacity(0.055),
                        ),
                      ),
                    ),

                    // =================================================
                    // SHINE EFFECT
                    // =================================================
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        height: 2,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.transparent,
                              primaryColor.withOpacity(0.35),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),

                    // =================================================
                    // CONTENT
                    // =================================================
                    Padding(
                      padding: const EdgeInsets.all(15),

                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,

                        children: [
                          // ===========================================
                          // 3D ICON
                          // ===========================================
                          _build3DIcon(service["icon"]),

                          const SizedBox(height: 13),

                          // ===========================================
                          // SERVICE NAME
                          // ===========================================
                          Text(
                            service["name"],
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,

                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                              letterSpacing: -0.15,
                            ),
                          ),

                          const SizedBox(height: 8),

                          // ===========================================
                          // JOIN BATCH PILL
                          // ===========================================
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 11,
                              vertical: 6,
                            ),

                            decoration: BoxDecoration(
                              color: const Color(0xffEFF6FF),

                              borderRadius: BorderRadius.circular(30),

                              border: Border.all(
                                color: const Color(0xffDBEAFE),
                              ),
                            ),

                            child: Row(
                              mainAxisSize: MainAxisSize.min,

                              children: [
                                const Icon(
                                  Icons.groups_rounded,
                                  size: 13,
                                  color: primaryColor,
                                ),

                                const SizedBox(width: 5),

                                Text(
                                  isLockedService
                                      ? "Selected Batch"
                                      : "Join Batch",

                                  style: TextStyle(
                                    color: primaryColor,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 8),

                          // ===========================================
                          // ARROW / STATUS
                          // ===========================================
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,

                            children: [
                              Text(
                                isDisabled
                                    ? "Not available"
                                    : "Tap to continue",

                                style: TextStyle(
                                  color: Colors.grey.shade500,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),

                              const SizedBox(width: 4),

                              Icon(
                                isDisabled
                                    ? Icons.lock_outline_rounded
                                    : Icons.arrow_forward_rounded,

                                size: 13,

                                color: Colors.grey.shade500,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
  // =============================================================
  // 3D ICON
  // =============================================================

  Widget _build3DIcon(IconData icon) {
    return Container(
      height: 65,
      width: 65,
      decoration: BoxDecoration(
        shape: BoxShape.circle,

        // Shadow underneath gives
        // a floating / 3D effect.
        boxShadow: [
          BoxShadow(
            color: primaryColor.withOpacity(0.20),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),

      child: Stack(
        alignment: Alignment.center,
        children: [
          // ==============================================
          // DARKER BACK LAYER
          // ==============================================
          Container(
            height: 58,
            width: 58,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xffBFDBFE),
            ),
          ),

          // ==============================================
          // MAIN CIRCLE
          // ==============================================
          Positioned(
            top: 0,
            child: Container(
              height: 58,
              width: 58,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xffEFF6FF), Color(0xffDBEAFE)],
                ),
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: Icon(icon, color: primaryColor, size: 29),
            ),
          ),

          // ==============================================
          // SMALL HIGHLIGHT
          // ==============================================
          Positioned(
            top: 9,
            left: 17,
            child: Container(
              height: 8,
              width: 17,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: Colors.white.withOpacity(0.65),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

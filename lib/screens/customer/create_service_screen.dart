import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'location_picker_screen.dart';

class CreateServiceScreen extends StatefulWidget {
  final String? serviceName;
  final bool isCustom;

  const CreateServiceScreen({
    super.key,
    this.serviceName,
    this.isCustom = false,
  });

  @override
  State<CreateServiceScreen> createState() =>
      _CreateServiceScreenState();
}

class _CreateServiceScreenState
    extends State<CreateServiceScreen>
    with SingleTickerProviderStateMixin {
  // ============================================================
  // CONTROLLERS
  // ============================================================

  late final TextEditingController serviceNameController;

  final TextEditingController descriptionController =
      TextEditingController();

  final TextEditingController locationController =
      TextEditingController();

  final TextEditingController budgetController =
      TextEditingController();

  // ============================================================
  // FIREBASE
  // ============================================================

  final DatabaseReference databaseReference =
      FirebaseDatabase.instance.ref().child('services');

  // ============================================================
  // VARIABLES
  // ============================================================

  String selectedCategory = "Home Cleaning";

  DateTime? selectedDate;

  String selectedAddress = "";

  double? selectedLatitude;

  double? selectedLongitude;

  bool isCreating = false;

  // ============================================================
  // ANIMATION
  // ============================================================

  late final AnimationController animationController;

  late final Animation<double> fadeAnimation;

  late final Animation<Offset> slideAnimation;

  // ============================================================
  // CATEGORIES
  // ============================================================

  final List<String> categories = [
    "Home Cleaning",
    "Electrical Work",
    "Plumbing",
    "Gardening",
    "Appliance Repair",
    "AC Repair",
    "Painting",
    "Car Repair",
    "Moving Service",
    "Babysitting",
    "Elder Care",
    "Tutors",
    "Local Skilled Jobs",
    "Other",
  ];

  // ============================================================
  // COLORS
  // ============================================================

  static const Color primaryColor =
      Color(0xff2563EB);

  static const Color secondaryColor =
      Color(0xff38BDF8);

  static const Color backgroundColor =
      Color(0xffF4F7FB);

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();

    // ----------------------------------------------------------
    // SERVICE NAME CONTROLLER
    // ----------------------------------------------------------

    serviceNameController =
        TextEditingController(
      text: widget.serviceName ?? "",
    );

    // ----------------------------------------------------------
    // ANIMATION CONTROLLER
    // ----------------------------------------------------------

    animationController =
        AnimationController(
      vsync: this,
      duration:
          const Duration(milliseconds: 900),
    );

    // ----------------------------------------------------------
    // FADE ANIMATION
    // ----------------------------------------------------------

    fadeAnimation =
        CurvedAnimation(
      parent: animationController,
      curve: Curves.easeOut,
    );

    // ----------------------------------------------------------
    // SLIDE ANIMATION
    // ----------------------------------------------------------

    slideAnimation =
        Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: animationController,
        curve: Curves.easeOutCubic,
      ),
    );

    // ----------------------------------------------------------
    // START ANIMATION
    // ----------------------------------------------------------

    animationController.forward();
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    serviceNameController.dispose();

    descriptionController.dispose();

    locationController.dispose();

    budgetController.dispose();

    animationController.dispose();

    super.dispose();
  }

  // ============================================================
  // SELECT DATE
  // ============================================================

  Future<void> selectDate() async {
    final DateTime now = DateTime.now();

    final DateTime? date =
        await showDatePicker(
      context: context,
      firstDate: now,
      lastDate: DateTime(2035),
      initialDate:
          selectedDate ?? now,
      builder: (
        BuildContext context,
        Widget? child,
      ) {
        return Theme(
          data:
              Theme.of(context).copyWith(
            colorScheme:
                const ColorScheme.light(
              primary: primaryColor,
              surface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (date != null && mounted) {
      setState(() {
        selectedDate = date;
      });
    }
  }

  // ============================================================
  // LOCATION PICKER
  // ============================================================

  Future<void> pickLocation() async {
    final dynamic result =
        await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            const LocationPickerScreen(),
      ),
    );

    if (result == null || !mounted) {
      return;
    }

    setState(() {
      selectedAddress =
          result["address"]?.toString() ??
              "";

      selectedLatitude =
          (result["latitude"] as num?)
              ?.toDouble();

      selectedLongitude =
          (result["longitude"] as num?)
              ?.toDouble();
    });
  }

  // ============================================================
  // CREATE REQUEST
  // ============================================================

  Future<void> createRequest() async {
    FocusScope.of(context).unfocus();

    // ----------------------------------------------------------
    // PREVENT DOUBLE CLICK
    // ----------------------------------------------------------

    if (isCreating) {
      return;
    }

    // ----------------------------------------------------------
    // SERVICE NAME
    // ----------------------------------------------------------

    if (serviceNameController.text
        .trim()
        .isEmpty) {
      _showMessage(
        "Please enter the service name.",
        Colors.red,
      );
      return;
    }

    // ----------------------------------------------------------
    // DESCRIPTION
    // ----------------------------------------------------------

    if (descriptionController.text
        .trim()
        .isEmpty) {
      _showMessage(
        "Please describe your problem.",
        Colors.red,
      );
      return;
    }

    // ----------------------------------------------------------
    // LOCATION
    // ----------------------------------------------------------

    if (selectedAddress.isEmpty ||
        selectedLatitude == null ||
        selectedLongitude == null) {
      _showMessage(
        "Please select your service location.",
        Colors.red,
      );
      return;
    }

    // ----------------------------------------------------------
    // DATE
    // ----------------------------------------------------------

    if (selectedDate == null) {
      _showMessage(
        "Please select your preferred date.",
        Colors.red,
      );
      return;
    }

    // ----------------------------------------------------------
    // BUDGET
    // ----------------------------------------------------------

    if (budgetController.text
        .trim()
        .isEmpty) {
      _showMessage(
        "Please enter your expected budget.",
        Colors.red,
      );
      return;
    }

    final double? budget =
        double.tryParse(
      budgetController.text.trim(),
    );

    if (budget == null ||
        budget <= 0) {
      _showMessage(
        "Please enter a valid budget.",
        Colors.red,
      );
      return;
    }

    // ----------------------------------------------------------
    // AUTHENTICATION
    // ----------------------------------------------------------

    final User? currentUser =
        FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      _showMessage(
        "User not logged in.",
        Colors.red,
      );
      return;
    }

    // ----------------------------------------------------------
    // SHOW LOADING
    // ----------------------------------------------------------

    setState(() {
      isCreating = true;
    });

    try {
      // ========================================================
      // CREATE NEW SERVICE
      // ========================================================

      final DatabaseReference newService =
          databaseReference.push();

      final String serviceId =
          newService.key ?? "";

      if (serviceId.isEmpty) {
        throw Exception(
          "Unable to generate service ID.",
        );
      }

      // ========================================================
      // SAVE SERVICE TO FIREBASE
      // ========================================================

      await newService.set({
        "serviceId": serviceId,

        "customerId":
            currentUser.uid,

        "serviceName":
            serviceNameController
                .text
                .trim(),

        "description":
            descriptionController
                .text
                .trim(),

        "location":
            selectedAddress,

        "latitude":
            selectedLatitude,

        "longitude":
            selectedLongitude,

        "budget":
            budgetController
                .text
                .trim(),

        "categoryType":
            widget.isCustom
                ? "custom"
                : "normal",

        "date":
            "${selectedDate!.day}-"
            "${selectedDate!.month}-"
            "${selectedDate!.year}",

        "status":
            "pending",

        "urgency":
            "normal",

        "createdAt":
            ServerValue.timestamp,
      });
     // ========================================================
// NOTIFY NEARBY WORKERS
// ========================================================

try {
  final response = await http.post(
    Uri.parse(
      "http://127.0.0.1:8080/api/notifications/service-created",
    ),
    headers: {
      "Content-Type": "application/json",
    },
    body: jsonEncode({
      "serviceId": serviceId,
      "customerId": currentUser.uid,
      "serviceName":
          serviceNameController.text.trim(),
      "latitude": selectedLatitude,
      "longitude": selectedLongitude,
    }),
  );

  debugPrint(
    "Nearby worker notification status: "
    "${response.statusCode}",
  );

  debugPrint(
    "Nearby worker notification response: "
    "${response.body}",
  );
} catch (e) {
  debugPrint(
    "Nearby worker notification error: $e",
  );
}
      // ========================================================
      // SUCCESS
      // ========================================================

      if (!mounted) {
        return;
      }

      _showMessage(
        "Service request created successfully!",
        Colors.green,
      );

      await Future.delayed(
        const Duration(
          milliseconds: 500,
        ),
      );

      if (!mounted) {
        return;
      }

      Navigator.pop(context);
    } catch (e) {
      // ========================================================
      // ERROR
      // ========================================================

      debugPrint(
        "CREATE SERVICE ERROR: $e",
      );

      if (!mounted) {
        return;
      }

      _showMessage(
        "Unable to create service request. Please try again.",
        Colors.red,
      );
    } finally {
      if (mounted) {
        setState(() {
          isCreating = false;
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
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                color == Colors.green
                    ? Icons
                        .check_circle_rounded
                    : Icons.error_rounded,
                color: Colors.white,
              ),

              const SizedBox(
                width: 10,
              ),

              Expanded(
                child: Text(
                  message,
                  style:
                      const TextStyle(
                    fontWeight:
                        FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: color,
          behavior:
              SnackBarBehavior.floating,
          margin:
              const EdgeInsets.all(16),
          shape:
              RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(14),
          ),
        ),
      );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      backgroundColor:
          backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),

            Expanded(
              child: FadeTransition(
                opacity:
                    fadeAnimation,
                child:
                    SlideTransition(
                  position:
                      slideAnimation,
                  child:
                      _buildBody(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // HEADER
  // ============================================================

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.fromLTRB(
        18,
        14,
        18,
        22,
      ),
      decoration:
          const BoxDecoration(
        gradient:
            LinearGradient(
          begin:
              Alignment.topLeft,
          end:
              Alignment.bottomRight,
          colors: [
            primaryColor,
            Color(0xff1D4ED8),
            secondaryColor,
          ],
        ),
        borderRadius:
            BorderRadius.only(
          bottomLeft:
              Radius.circular(30),
          bottomRight:
              Radius.circular(30),
        ),
        boxShadow: [
          BoxShadow(
            color:
                Color(0x332563EB),
            blurRadius: 20,
            offset:
                Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              _buildBackButton(),

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
                      "Create Service",
                      style:
                          TextStyle(
                        color:
                            Colors.white,
                        fontSize: 22,
                        fontWeight:
                            FontWeight.w800,
                        letterSpacing:
                            -0.4,
                      ),
                    ),

                    SizedBox(
                      height: 3,
                    ),

                    Text(
                      "Tell us what you need",
                      style:
                          TextStyle(
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

              _buildHeaderIcon(),
            ],
          ),

          const SizedBox(
            height: 20,
          ),

          _buildHeaderProgress(),
        ],
      ),
    );
  }

  // ============================================================
  // BACK BUTTON
  // ============================================================

  Widget _buildBackButton() {
    return Material(
      color: Colors.white
          .withOpacity(0.16),
      borderRadius:
          BorderRadius.circular(15),
      child: InkWell(
        borderRadius:
            BorderRadius.circular(15),
        onTap: () {
          Navigator.pop(context);
        },
        child: const SizedBox(
          height: 46,
          width: 46,
          child: Icon(
            Icons
                .arrow_back_rounded,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  // ============================================================
  // HEADER ICON
  // ============================================================

  Widget _buildHeaderIcon() {
    return Container(
      height: 50,
      width: 50,
      decoration:
          BoxDecoration(
        color: Colors.white
            .withOpacity(0.16),
        borderRadius:
            BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white
              .withOpacity(0.20),
        ),
      ),
      child: const Icon(
        Icons.handyman_rounded,
        color: Colors.white,
        size: 25,
      ),
    );
  }

  // ============================================================
  // HEADER PROGRESS
  // ============================================================

  Widget _buildHeaderProgress() {
    return Row(
      children: [
        _progressCircle(
          "1",
          "Service",
          true,
        ),

        _progressLine(),

        _progressCircle(
          "2",
          "Location",
          selectedAddress
              .isNotEmpty,
        ),

        _progressLine(),

        _progressCircle(
          "3",
          "Schedule",
          selectedDate != null,
        ),
      ],
    );
  }

  // ============================================================
  // PROGRESS CIRCLE
  // ============================================================

  Widget _progressCircle(
    String number,
    String title,
    bool active,
  ) {
    return Expanded(
      child: Column(
        children: [
          Container(
            height: 30,
            width: 30,
            decoration:
                BoxDecoration(
              color: active
                  ? Colors.white
                  : Colors.white
                      .withOpacity(
                          0.22),
              shape:
                  BoxShape.circle,
              boxShadow: active
                  ? const [
                      BoxShadow(
                        color:
                            Color(
                                0x33000000),
                        blurRadius: 8,
                        offset:
                            Offset(
                          0,
                          3,
                        ),
                      ),
                    ]
                  : null,
            ),
            alignment:
                Alignment.center,
            child: Text(
              number,
              style:
                  TextStyle(
                color: active
                    ? primaryColor
                    : Colors.white70,
                fontWeight:
                    FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),

          const SizedBox(
            height: 5,
          ),

          Text(
            title,
            style:
                const TextStyle(
              color: Colors.white,
              fontSize: 9,
              fontWeight:
                  FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // PROGRESS LINE
  // ============================================================

  Widget _progressLine() {
    return Container(
      height: 2,
      width: 25,
      margin:
          const EdgeInsets.only(
        bottom: 17,
      ),
      color: Colors.white
          .withOpacity(0.35),
    );
  }

  // ============================================================
  // BODY
  // ============================================================

  Widget _buildBody() {
    return SingleChildScrollView(
      physics:
          const BouncingScrollPhysics(),
      padding:
          const EdgeInsets.fromLTRB(
        18,
        20,
        18,
        30,
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment
                .start,
        children: [
          _buildIntroCard(),

          const SizedBox(
            height: 18,
          ),

          _sectionTitle(
            "Service Details",
            Icons
                .home_repair_service_rounded,
          ),

          const SizedBox(
            height: 10,
          ),

          _buildServiceCard(),

          const SizedBox(
            height: 20,
          ),

          _sectionTitle(
            "Service Location",
            Icons
                .location_on_rounded,
          ),

          const SizedBox(
            height: 10,
          ),

          _buildLocationCard(),

          const SizedBox(
            height: 20,
          ),

          _sectionTitle(
            "Schedule & Budget",
            Icons
                .event_available_rounded,
          ),

          const SizedBox(
            height: 10,
          ),

          _buildScheduleCard(),

          const SizedBox(
            height: 25,
          ),

          _buildSubmitButton(),
        ],
      ),
    );
  }

  // ============================================================
  // INTRO CARD
  // ============================================================

  Widget _buildIntroCard() {
    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.all(18),
      decoration:
          BoxDecoration(
        gradient:
            const LinearGradient(
          colors: [
            Colors.white,
            Color(0xffEFF6FF),
          ],
        ),
        borderRadius:
            BorderRadius.circular(22),
        border: Border.all(
          color:
              const Color(
                  0xffDBEAFE),
        ),
        boxShadow: const [
          BoxShadow(
            color:
                Color(0x12000000),
            blurRadius: 15,
            offset:
                Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            height: 52,
            width: 52,
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
                16,
              ),
              boxShadow:
                  const [
                BoxShadow(
                  color:
                      Color(0x332563EB),
                  blurRadius: 12,
                  offset:
                      Offset(0, 5),
                ),
              ],
            ),
            child: const Icon(
              Icons
                  .auto_awesome_rounded,
              color:
                  Colors.white,
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
                  "Let's get your service started",
                  style:
                      TextStyle(
                    fontSize: 15,
                    fontWeight:
                        FontWeight.w800,
                  ),
                ),

                SizedBox(
                  height: 4,
                ),

                Text(
                  "Provide a few details so the right professional can help you.",
                  style:
                      TextStyle(
                    fontSize: 11,
                    height: 1.4,
                    color:
                        Colors.grey,
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
  // SECTION TITLE
  // ============================================================

  Widget _sectionTitle(
    String title,
    IconData icon,
  ) {
    return Row(
      children: [
        Container(
          height: 30,
          width: 30,
          decoration:
              BoxDecoration(
            color:
                const Color(
                    0xffDBEAFE),
            borderRadius:
                BorderRadius.circular(
                    9),
          ),
          child: Icon(
            icon,
            size: 17,
            color: primaryColor,
          ),
        ),

        const SizedBox(
          width: 9,
        ),

        Text(
          title,
          style:
              const TextStyle(
            fontSize: 16,
            fontWeight:
                FontWeight.w800,
          ),
        ),
      ],
    );
  }

  // ============================================================
  // SERVICE CARD
  // ============================================================

  Widget _buildServiceCard() {
    return _card(
      child: Column(
        children: [
          _field(
            controller:
                serviceNameController,
            hint:
                "Service Name",
            icon: Icons
                .home_repair_service_rounded,
            enabled:
                widget.isCustom,
          ),

          const SizedBox(
            height: 14,
          ),

          _field(
            controller:
                descriptionController,
            hint:
                "Describe your problem",
            icon: Icons
                .description_outlined,
            maxLines: 4,
          ),
        ],
      ),
    );
  }

  // ============================================================
  // LOCATION CARD
  // ============================================================

  Widget _buildLocationCard() {
    return GestureDetector(
      onTap: pickLocation,
      child: _card(
        padding:
            const EdgeInsets.all(15),
        child: Row(
          children: [
            Container(
              height: 52,
              width: 52,
              decoration:
                  BoxDecoration(
                gradient:
                    LinearGradient(
                  colors: [
                    primaryColor
                        .withOpacity(
                            0.12),
                    secondaryColor
                        .withOpacity(
                            0.18),
                  ],
                ),
                borderRadius:
                    BorderRadius.circular(
                        16),
              ),
              child: Icon(
                selectedAddress
                        .isEmpty
                    ? Icons
                        .location_searching_rounded
                    : Icons
                        .location_on_rounded,
                color:
                    primaryColor,
                size: 26,
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
                    selectedAddress
                            .isEmpty
                        ? "Select Service Location"
                        : "Service Location",
                    style:
                        const TextStyle(
                      fontSize: 14,
                      fontWeight:
                          FontWeight.w800,
                    ),
                  ),

                  const SizedBox(
                    height: 5,
                  ),

                  Text(
                    selectedAddress
                            .isEmpty
                        ? "Choose your location on the map"
                        : selectedAddress,
                    maxLines: 2,
                    overflow:
                        TextOverflow
                            .ellipsis,
                    style:
                        const TextStyle(
                      fontSize: 11,
                      height: 1.4,
                      color:
                          Colors.grey,
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
                    const Color(
                        0xffEFF6FF),
                borderRadius:
                    BorderRadius.circular(
                        12),
              ),
              child: const Icon(
                Icons
                    .arrow_forward_ios_rounded,
                size: 15,
                color:
                    primaryColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // SCHEDULE CARD
  // ============================================================

  Widget _buildScheduleCard() {
    return _card(
      child: Column(
        children: [
          GestureDetector(
            onTap: selectDate,
            child: Container(
              padding:
                  const EdgeInsets.all(
                      15),
              decoration:
                  BoxDecoration(
                color:
                    const Color(
                        0xffF8FAFC),
                borderRadius:
                    BorderRadius.circular(
                        16),
                border: Border.all(
                  color:
                      const Color(
                          0xffE5E7EB),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    height: 45,
                    width: 45,
                    decoration:
                        BoxDecoration(
                      color:
                          const Color(
                              0xffDBEAFE),
                      borderRadius:
                          BorderRadius
                              .circular(
                                  13),
                    ),
                    child:
                        const Icon(
                      Icons
                          .calendar_month_rounded,
                      color:
                          primaryColor,
                    ),
                  ),

                  const SizedBox(
                    width: 12,
                  ),

                  Expanded(
                    child:
                        Column(
                      crossAxisAlignment:
                          CrossAxisAlignment
                              .start,
                      children: [
                        const Text(
                          "Preferred Date",
                          style:
                              TextStyle(
                            fontSize:
                                11,
                            color:
                                Colors
                                    .grey,
                            fontWeight:
                                FontWeight
                                    .w600,
                          ),
                        ),

                        const SizedBox(
                          height: 3,
                        ),

                        Text(
                          selectedDate ==
                                  null
                              ? "Select a date"
                              : "${selectedDate!.day}-"
                                  "${selectedDate!.month}-"
                                  "${selectedDate!.year}",
                          style:
                              const TextStyle(
                            fontSize:
                                14,
                            fontWeight:
                                FontWeight
                                    .w800,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const Icon(
                    Icons
                        .keyboard_arrow_down_rounded,
                    color:
                        Colors.grey,
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(
            height: 14,
          ),

          _field(
            controller:
                budgetController,
            hint:
                "Expected Budget",
            icon: Icons
                .currency_rupee_rounded,
            keyboard:
                TextInputType.number,
          ),
        ],
      ),
    );
  }

  // ============================================================
  // CARD
  // ============================================================

  Widget _card({
    required Widget child,
    EdgeInsetsGeometry padding =
        const EdgeInsets.all(16),
  }) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration:
          BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(22),
        border: Border.all(
          color:
              const Color(
                  0xffE8EEF7),
        ),
        boxShadow: const [
          BoxShadow(
            color:
                Color(0x10000000),
            blurRadius: 18,
            offset:
                Offset(0, 7),
          ),
          BoxShadow(
            color:
                Color(0x08000000),
            blurRadius: 3,
            offset:
                Offset(0, 1),
          ),
        ],
      ),
      child: child,
    );
  }

  // ============================================================
  // FIELD
  // ============================================================

 
Widget _field({
  required TextEditingController controller,
  required String hint,
  required IconData icon,
  int maxLines = 1,
  TextInputType keyboard = TextInputType.text,
  bool enabled = true,
}) {
  return TextField(
    controller: controller,
    maxLines: maxLines,
    enabled: enabled,

    // FIX: Multiline fields must use multiline keyboard type
    keyboardType:
        maxLines > 1
            ? TextInputType.multiline
            : keyboard,

    textInputAction:
        maxLines > 1
            ? TextInputAction.newline
            : TextInputAction.next,

    style: const TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w600,
    ),

    decoration: InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(
        color: Color(0xff9CA3AF),
        fontSize: 13,
        fontWeight: FontWeight.w500,
      ),

      prefixIcon: Padding(
        padding: const EdgeInsets.only(
          left: 5,
          right: 5,
        ),
        child: Icon(
          icon,
          color: primaryColor,
          size: 21,
        ),
      ),

      prefixIconConstraints: const BoxConstraints(
        minWidth: 48,
      ),

      filled: true,
      fillColor: const Color(0xffF8FAFC),

      contentPadding: const EdgeInsets.symmetric(
        horizontal: 15,
        vertical: 16,
      ),

      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(
          color: Color(0xffE5E7EB),
        ),
      ),

      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(
          color: Color(0xffE5E7EB),
        ),
      ),

      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(
          color: primaryColor,
          width: 1.5,
        ),
      ),

      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(
          color: Color(0xffE5E7EB),
        ),
      ),
    ),
  );
}


  // ============================================================
  // SUBMIT BUTTON
  // ============================================================

  Widget _buildSubmitButton() {
    return AnimatedContainer(
      duration:
          const Duration(
        milliseconds: 250,
      ),
      width: double.infinity,
      height: 58,
      decoration:
          BoxDecoration(
        gradient:
            const LinearGradient(
          begin:
              Alignment.centerLeft,
          end:
              Alignment.centerRight,
          colors: [
            primaryColor,
            Color(0xff1D4ED8),
            secondaryColor,
          ],
        ),
        borderRadius:
            BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color:
                Color(0x402563EB),
            blurRadius: 18,
            offset:
                Offset(0, 8),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed:
            isCreating
                ? null
                : createRequest,
        style:
            ElevatedButton.styleFrom(
          backgroundColor:
              Colors.transparent,
          disabledBackgroundColor:
              Colors.transparent,
          shadowColor:
              Colors.transparent,
          shape:
              RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(
                    18),
          ),
        ),
        child:
            AnimatedSwitcher(
          duration:
              const Duration(
            milliseconds: 200,
          ),
          child: isCreating
              ? const SizedBox(
                  key: ValueKey(
                      "loading"),
                  height: 24,
                  width: 24,
                  child:
                      CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor:
                        AlwaysStoppedAnimation<
                            Color>(
                      Colors.white,
                    ),
                  ),
                )
              : const Row(
                  key: ValueKey(
                      "button"),
                  mainAxisAlignment:
                      MainAxisAlignment
                          .center,
                  children: [
                    Icon(
                      Icons
                          .rocket_launch_rounded,
                      color:
                          Colors.white,
                      size: 21,
                    ),

                    SizedBox(
                      width: 9,
                    ),

                    Text(
                      "CREATE SERVICE REQUEST",
                      style:
                          TextStyle(
                        color:
                            Colors.white,
                        fontSize: 14,
                        fontWeight:
                            FontWeight
                                .w800,
                        letterSpacing:
                            0.4,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:servora/screens/vendor/vendor_batch_work_dialog.dart';

const Color primaryColor = Color(0xff2563EB);
const Color backgroundColor = Color(0xffF8FAFC);

class VendorRequestsScreen extends StatefulWidget {
  const VendorRequestsScreen({super.key});

  @override
  State<VendorRequestsScreen> createState() =>
      _VendorRequestsScreenState();
}

class _VendorRequestsScreenState
    extends State<VendorRequestsScreen>
    with SingleTickerProviderStateMixin {
  final DatabaseReference database =
      FirebaseDatabase.instance.ref();

  final FirebaseAuth auth =
      FirebaseAuth.instance;

  bool loading = true;

  List<Map<String, dynamic>> allRequests = [];

  late AnimationController _animationController;

  String selectedFilter = "All";

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(
        milliseconds: 700,
      ),
    );

    _loadVendorRequests();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }
void _openBatchWorkDialog(
  Map<String, dynamic> request,
) {
  final batch = {
    ...request,
  };

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: const Color.from(alpha: 0, red: 0, green: 0, blue: 0),
    builder: (context) {
      return VendorBatchWorkDialog(
        batch: batch,
      );
    },
  );
}
  // =========================================================
  // LOAD CURRENT VENDOR REQUESTS
  // =========================================================

  Future<void> _loadVendorRequests() async {
    if (!mounted) return;

    setState(() {
      loading = true;
    });

    try {
      final currentUser = auth.currentUser;

      if (currentUser == null) {
        if (!mounted) return;

        setState(() {
          allRequests = [];
          loading = false;
        });

        return;
      }

      final vendorId = currentUser.uid;

      debugPrint(
        "======================================",
      );

      debugPrint(
        "CURRENT VENDOR ID: $vendorId",
      );

      debugPrint(
        "Loading vendor requests...",
      );

      debugPrint(
        "======================================",
      );

      final snapshot = await database
          .child("societyServiceBatches")
          .get();

      if (!snapshot.exists ||
          snapshot.value == null) {
        if (!mounted) return;

        setState(() {
          allRequests = [];
          loading = false;
        });

        return;
      }

      final List<Map<String, dynamic>> requests = [];

      final rootData =
          Map<String, dynamic>.from(
        snapshot.value as Map,
      );

      // =====================================================
      // apartmentKey
      // =====================================================

      for (final apartmentEntry
          in rootData.entries) {
        final apartmentKey =
            apartmentEntry.key.toString();

        final apartmentData =
            apartmentEntry.value;

        if (apartmentData is! Map) {
          continue;
        }

        final apartmentMap =
            Map<String, dynamic>.from(
          apartmentData,
        );

        // ===================================================
        // serviceId
        // ===================================================

        for (final serviceEntry
            in apartmentMap.entries) {
          final serviceId =
              serviceEntry.key.toString();

          final serviceData =
              serviceEntry.value;

          if (serviceData is! Map) {
            continue;
          }

          final batch =
              Map<String, dynamic>.from(
            serviceData,
          );

          // =================================================
          // BIDS
          // =================================================

          final bids = batch["bids"];

          if (bids == null || bids is! Map) {
            continue;
          }

          final bidsMap =
              Map<String, dynamic>.from(
            bids,
          );

          // =================================================
          // FIND CURRENT VENDOR'S BID
          // =================================================

          for (final bidEntry
              in bidsMap.entries) {
            final bidId =
                bidEntry.key.toString();

            final bidValue =
                bidEntry.value;

            if (bidValue is! Map) {
              continue;
            }

            final bid =
                Map<String, dynamic>.from(
              bidValue,
            );

            // -----------------------------------------------
            // Vendor ID
            // -----------------------------------------------

            final bidVendorId =
                bid["vendorId"]?.toString() ??
                    bid["vendorUID"]?.toString() ??
                    bid["uid"]?.toString();

            if (bidVendorId != vendorId) {
              continue;
            }

            // =================================================
            // CREATE REQUEST OBJECT
            // =================================================

            requests.add({
              "apartmentKey": apartmentKey,
              "serviceId": serviceId,
              "bidId": bidId,

              // Batch information
              "serviceName":
                  batch["serviceName"] ??
                      "Service",

              "apartmentName":
                  batch["apartmentName"] ??
                      "Apartment",

              "address":
                  batch["address"] ??
                      "Address not available",

              "latitude":
                  batch["latitude"],

              "longitude":
                  batch["longitude"],

              "requestCount":
                  batch["requestCount"] ??
                      0,

              "batchStatus":
                  batch["status"] ??
                      "collecting",

              // Bid information
              "bidAmount":
                  bid["bidAmount"] ??
                      bid["amount"] ??
                      0,

              "bidStatus":
                  bid["status"] ??
                      "pending",

              "submittedAt":
                  bid["submittedAt"] ??
                      bid["createdAt"] ??
                      bid["timestamp"],

              "vendorId":
                  bidVendorId,
            });

            debugPrint(
              "Vendor bid found: $bidId",
            );
          }
        }
      }

      // =====================================================
      // SORT — LATEST FIRST
      // =====================================================

      requests.sort((a, b) {
        final aTime =
            int.tryParse(
                  a["submittedAt"]
                          ?.toString() ??
                      "0",
                ) ??
                0;

        final bTime =
            int.tryParse(
                  b["submittedAt"]
                          ?.toString() ??
                      "0",
                ) ??
                0;

        return bTime.compareTo(aTime);
      });

      if (!mounted) return;

      setState(() {
        allRequests = requests;
        loading = false;
      });

      _animationController.forward(
        from: 0,
      );
    } catch (e) {
      debugPrint(
        "ERROR LOADING VENDOR REQUESTS: $e",
      );

      if (!mounted) return;

      setState(() {
        loading = false;
      });

      _showMessage(
        "Unable to load your requests.",
        Colors.red,
      );
    }
  }

  // =========================================================
  // FILTER
  // =========================================================

  List<Map<String, dynamic>>
      get filteredRequests {
    if (selectedFilter == "All") {
      return allRequests;
    }

    return allRequests.where((request) {
      final status =
          _normalizeStatus(
        request["bidStatus"],
      );

      return status ==
          selectedFilter.toLowerCase();
    }).toList();
  }

  // =========================================================
  // STATUS NORMALIZER
  // =========================================================

  String _normalizeStatus(dynamic value) {
    final status =
        value?.toString().toLowerCase().trim() ??
            "pending";

    if (status.contains("select")) {
      return "selected";
    }

    if (status.contains("reject")) {
      return "rejected";
    }

    if (status.contains("pending")) {
      return "pending";
    }

    return status;
  }

  // =========================================================
  // STATUS COLOR
  // =========================================================

  Color _statusColor(String status) {
    switch (status) {
      case "selected":
        return Colors.green;

      case "rejected":
        return Colors.red;

      default:
        return Colors.orange;
    }
  }

  // =========================================================
  // STATUS ICON
  // =========================================================

  IconData _statusIcon(String status) {
    switch (status) {
      case "selected":
        return Icons.check_circle;

      case "rejected":
        return Icons.cancel;

      default:
        return Icons.hourglass_top_rounded;
    }
  }

  // =========================================================
  // STATUS TEXT
  // =========================================================

  String _statusText(String status) {
    switch (status) {
      case "selected":
        return "Selected";

      case "rejected":
        return "Rejected";

      default:
        return "Pending";
    }
  }

  // =========================================================
  // FORMAT AMOUNT
  // =========================================================

  String _formatAmount(dynamic value) {
    final amount =
        double.tryParse(
              value?.toString() ?? "0",
            ) ??
            0;

    if (amount == amount.roundToDouble()) {
      return "₹${amount.toInt()}";
    }

    return "₹${amount.toStringAsFixed(2)}";
  }

  // =========================================================
  // FORMAT DATE
  // =========================================================

  String _formatDate(dynamic value) {
    if (value == null) {
      return "Recently";
    }

    final timestamp =
        int.tryParse(
      value.toString(),
    );

    if (timestamp == null ||
        timestamp <= 0) {
      return "Recently";
    }

    final date =
        DateTime.fromMillisecondsSinceEpoch(
      timestamp,
    );

    final day =
        date.day.toString().padLeft(2, "0");

    final month =
        date.month.toString().padLeft(2, "0");

    final year =
        date.year.toString();

    return "$day/$month/$year";
  }

  // =========================================================
  // REQUEST CARD
  // =========================================================

  Widget _buildRequestCard(
    Map<String, dynamic> request,
    int index,
  ) {
    final status =
        _normalizeStatus(
      request["bidStatus"],
    );

    final statusColor =
        _statusColor(status);

    final serviceName =
        request["serviceName"]
                ?.toString() ??
            "Service";

    final apartmentName =
        request["apartmentName"]
                ?.toString() ??
            "Apartment";

    final address =
        request["address"]
                ?.toString() ??
            "Address not available";

    final amount =
        _formatAmount(
      request["bidAmount"],
    );

    final requestCount =
        request["requestCount"]
                ?.toString() ??
            "0";

    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        final start =
            (index * 0.10).clamp(
          0.0,
          0.7,
        );

        final end =
            (start + 0.3).clamp(
          0.0,
          1.0,
        );

        final animation =
            CurvedAnimation(
          parent:
              _animationController,
          curve: Interval(
            start,
            end,
            curve:
                Curves.easeOutCubic,
          ),
        );

        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position:
                Tween<Offset>(
              begin:
                  const Offset(
                0,
                0.12,
              ),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          ),
        );
      },

      child: Container(
        margin:
            const EdgeInsets.only(
          bottom: 16,
        ),

        decoration:
            BoxDecoration(
          color: Colors.white,

          borderRadius:
              BorderRadius.circular(
            22,
          ),

          boxShadow: [
            BoxShadow(
              color:
                  Colors.black.withOpacity(
                0.06,
              ),
              blurRadius: 18,
              offset:
                  const Offset(0, 7),
            ),
          ],
        ),

        child: Column(
          children: [
            // =================================================
            // TOP SECTION
            // =================================================

            Padding(
              padding:
                  const EdgeInsets.fromLTRB(
                18,
                18,
                18,
                14,
              ),

              child: Row(
                crossAxisAlignment:
                    CrossAxisAlignment
                        .start,

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

                    child: const Icon(
                      Icons.home_work_rounded,
                      color:
                          primaryColor,
                      size: 27,
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
                          maxLines: 1,
                          overflow:
                              TextOverflow
                                  .ellipsis,
                          style:
                              const TextStyle(
                            fontSize: 17,
                            fontWeight:
                                FontWeight
                                    .bold,
                          ),
                        ),

                        const SizedBox(
                          height: 5,
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

                  const SizedBox(
                    width: 8,
                  ),

                  Container(
                    padding:
                        const EdgeInsets
                            .symmetric(
                      horizontal: 10,
                      vertical: 7,
                    ),

                    decoration:
                        BoxDecoration(
                      color:
                          statusColor
                              .withOpacity(
                        0.10,
                      ),

                      borderRadius:
                          BorderRadius
                              .circular(
                        20,
                      ),
                    ),

                    child: Row(
                      mainAxisSize:
                          MainAxisSize
                              .min,

                      children: [
                        Icon(
                          _statusIcon(
                            status,
                          ),
                          size: 14,
                          color:
                              statusColor,
                        ),

                        const SizedBox(
                          width: 5,
                        ),

                        Text(
                          _statusText(
                            status,
                          ),
                          style:
                              TextStyle(
                            color:
                                statusColor,
                            fontSize: 11,
                            fontWeight:
                                FontWeight
                                    .bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // =================================================
            // LOCATION
            // =================================================

            Container(
              margin:
                  const EdgeInsets
                      .symmetric(
                horizontal: 18,
              ),

              padding:
                  const EdgeInsets.all(
                13,
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
                  14,
                ),
              ),

              child: Row(
                crossAxisAlignment:
                    CrossAxisAlignment
                        .start,

                children: [
                  const Icon(
                    Icons.location_on,
                    color:
                        primaryColor,
                    size: 19,
                  ),

                  const SizedBox(
                    width: 8,
                  ),

                  Expanded(
                    child: Text(
                      address,
                      maxLines: 2,
                      overflow:
                          TextOverflow
                              .ellipsis,
                      style:
                          const TextStyle(
                        fontSize: 12,
                        color:
                            Colors.black87,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(
              height: 15,
            ),

            // =================================================
            // BID INFORMATION
            // =================================================

            Padding(
              padding:
                  const EdgeInsets
                      .symmetric(
                horizontal: 18,
              ),

              child: Row(
                children: [
                  Expanded(
                    child:
                        _infoItem(
                      Icons.currency_rupee,
                      "Your Bid",
                      amount,
                      primaryColor,
                    ),
                  ),

                  Container(
                    height: 42,
                    width: 1,
                    color:
                        const Color(
                      0xffE2E8F0,
                    ),
                  ),

                  Expanded(
                    child:
                        _infoItem(
                      Icons.people_alt_outlined,
                      "Requests",
                      requestCount,
                      Colors.deepPurple,
                    ),
                  ),

                  Container(
                    height: 42,
                    width: 1,
                    color:
                        const Color(
                      0xffE2E8F0,
                    ),
                  ),

                  Expanded(
                    child:
                        _infoItem(
                      Icons.calendar_today_outlined,
                      "Applied",
                      _formatDate(
                        request[
                            "submittedAt"],
                      ),
                      Colors.teal,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(
              height: 15,
            ),

            // =================================================
            // STATUS MESSAGE
            // =================================================

            Container(
              width: double.infinity,

              margin:
                  const EdgeInsets
                      .fromLTRB(
                18,
                0,
                18,
                18,
              ),

              padding:
                  const EdgeInsets.all(
                13,
              ),

              decoration:
                  BoxDecoration(
                color:
                    statusColor
                        .withOpacity(
                  0.07,
                ),

                borderRadius:
                    BorderRadius
                        .circular(
                  13,
                ),

                border:
                    Border.all(
                  color:
                      statusColor
                          .withOpacity(
                    0.15,
                  ),
                ),
              ),

              child: Row(
                children: [
                  Icon(
                    _statusIcon(
                      status,
                    ),
                    color:
                        statusColor,
                    size: 19,
                  ),

                  const SizedBox(
                    width: 9,
                  ),

                  Expanded(
                    child: Text(
                      status == "selected"
                          ? "Congratulations! Your bid has been selected."
                          : status == "rejected"
                              ? "Your bid was not selected for this batch."
                              : "Your bid has been submitted. Waiting for the admin's decision.",
                      style:
                          TextStyle(
                        color:
                            statusColor
                                .withOpacity(
                          0.95,
                        ),
                        fontSize: 12,
                        fontWeight:
                            FontWeight
                                .w600,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          
// START WORK BUTTON

if (status == "selected") ...[
  Padding(
    padding: const EdgeInsets.fromLTRB(
      18,
      0,
      18,
      18,
    ),
    child: SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton.icon(
        onPressed: () {
          _openBatchWorkDialog(request);
        },
        icon: const Icon(
          Icons.play_arrow_rounded,
        ),
        label: const Text(
          "Start Work",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
        ),
      ),
    ),
  ),
],


          ],
        ),
      ),
    );
  }

  // =========================================================
  // INFO ITEM
  // =========================================================

  Widget _infoItem(
    IconData icon,
    String title,
    String value,
    Color color,
  ) {
    return Column(
      children: [
        Icon(
          icon,
          color: color,
          size: 20,
        ),

        const SizedBox(
          height: 5,
        ),

        Text(
          value,
          maxLines: 1,
          overflow:
              TextOverflow.ellipsis,
          style:
              const TextStyle(
            fontSize: 14,
            fontWeight:
                FontWeight.bold,
          ),
        ),

        const SizedBox(
          height: 2,
        ),

        Text(
          title,
          maxLines: 1,
          overflow:
              TextOverflow.ellipsis,
          style:
              const TextStyle(
            fontSize: 9,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }

  // =========================================================
  // HEADER
  // =========================================================

  Widget _buildHeader() {
    final total =
        allRequests.length;

    final pending =
        allRequests.where(
      (request) =>
          _normalizeStatus(
            request["bidStatus"],
          ) ==
          "pending",
    ).length;

    final selected =
        allRequests.where(
      (request) =>
          _normalizeStatus(
            request["bidStatus"],
          ) ==
          "selected",
    ).length;

    return Container(
      width: double.infinity,

      margin:
          const EdgeInsets.fromLTRB(
        16,
        16,
        16,
        12,
      ),

      padding:
          const EdgeInsets.all(
        20,
      ),

      decoration:
          BoxDecoration(
        gradient:
            const LinearGradient(
          begin:
              Alignment.topLeft,
          end:
              Alignment.bottomRight,
          colors: [
            Color(0xff2563EB),
            Color(0xff1D4ED8),
          ],
        ),

        borderRadius:
            BorderRadius.circular(
          24,
        ),

        boxShadow: [
          BoxShadow(
            color:
                primaryColor
                    .withOpacity(
              0.25,
            ),
            blurRadius: 18,
            offset:
                const Offset(0, 8),
          ),
        ],
      ),

      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,

        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment
                          .start,
                  children: [
                    const Text(
                      "Your Requests",
                      style:
                          TextStyle(
                        color:
                            Colors.white,
                        fontSize: 22,
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),

                    const SizedBox(
                      height: 5,
                    ),

                    Text(
                      "Track all your submitted bids",
                      style:
                          TextStyle(
                        color: Colors.white
                            .withOpacity(
                          0.8,
                        ),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),

              Container(
                height: 52,
                width: 52,

                decoration:
                    BoxDecoration(
                  color: Colors.white
                      .withOpacity(
                    0.15,
                  ),
                  shape:
                      BoxShape.circle,
                ),

                child: const Icon(
                  Icons.assignment_rounded,
                  color:
                      Colors.white,
                  size: 27,
                ),
              ),
            ],
          ),

          const SizedBox(
            height: 20,
          ),

          Row(
            children: [
              _headerStat(
                total.toString(),
                "Total",
              ),

              _headerDivider(),

              _headerStat(
                pending.toString(),
                "Pending",
              ),

              _headerDivider(),

              _headerStat(
                selected.toString(),
                "Selected",
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _headerStat(
    String value,
    String label,
  ) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style:
                const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight:
                  FontWeight.bold,
            ),
          ),

          const SizedBox(
            height: 2,
          ),

          Text(
            label,
            style:
                TextStyle(
              color: Colors.white
                  .withOpacity(
                0.75,
              ),
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  Widget _headerDivider() {
    return Container(
      height: 30,
      width: 1,
      color:
          Colors.white.withOpacity(
        0.25,
      ),
    );
  }

  // =========================================================
  // FILTER
  // =========================================================

  Widget _buildFilters() {
    final filters = [
      "All",
      "Pending",
      "Selected",
      "Rejected",
    ];

    return SizedBox(
      height: 45,

      child: ListView.separated(
        padding:
            const EdgeInsets
                .symmetric(
          horizontal: 16,
        ),

        scrollDirection:
            Axis.horizontal,

        itemCount:
            filters.length,

        separatorBuilder:
            (_, __) =>
                const SizedBox(
          width: 9,
        ),

        itemBuilder:
            (context, index) {
          final filter =
              filters[index];

          final isSelected =
              selectedFilter ==
                  filter;

          return GestureDetector(
            onTap: () {
              setState(() {
                selectedFilter =
                    filter;
              });
            },

            child: AnimatedContainer(
              duration:
                  const Duration(
                milliseconds: 250,
              ),

              padding:
                  const EdgeInsets
                      .symmetric(
                horizontal: 18,
              ),

              decoration:
                  BoxDecoration(
                color: isSelected
                    ? primaryColor
                    : Colors.white,

                borderRadius:
                    BorderRadius
                        .circular(
                  22,
                ),

                border:
                    Border.all(
                  color: isSelected
                      ? primaryColor
                      : const Color(
                          0xffE2E8F0,
                        ),
                ),
              ),

              child: Center(
                child: Text(
                  filter,
                  style:
                      TextStyle(
                    color: isSelected
                        ? Colors.white
                        : Colors.grey
                            .shade700,
                    fontSize: 12,
                    fontWeight:
                        FontWeight.w600,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // =========================================================
  // EMPTY STATE
  // =========================================================

  Widget _buildEmptyState() {
    String title =
        "No Requests Yet";

    String message =
        "You haven't submitted any bids yet.";

    if (selectedFilter != "All") {
      title =
          "No $selectedFilter Requests";

      message =
          "There are no $selectedFilter bids to show.";
    }

    return Center(
      child: Padding(
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
                shape:
                    BoxShape.circle,
              ),

              child: const Icon(
                Icons.assignment_outlined,
                color:
                    primaryColor,
                size: 48,
              ),
            ),

            const SizedBox(
              height: 20,
            ),

            Text(
              title,
              style:
                  const TextStyle(
                fontSize: 19,
                fontWeight:
                    FontWeight.bold,
              ),
            ),

            const SizedBox(
              height: 8,
            ),

            Text(
              message,
              textAlign:
                  TextAlign.center,
              style:
                  const TextStyle(
                color: Colors.grey,
                fontSize: 13,
                height: 1.5,
              ),
            ),

            const SizedBox(
              height: 20,
            ),

            OutlinedButton.icon(
              onPressed:
                  _loadVendorRequests,

              icon: const Icon(
                Icons.refresh,
              ),

              label:
                  const Text(
                "Refresh",
              ),

              style:
                  OutlinedButton
                      .styleFrom(
                foregroundColor:
                    primaryColor,
                side:
                    const BorderSide(
                  color:
                      primaryColor,
                ),
                shape:
                    RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(
                    12,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================
  // MESSAGE
  // =========================================================

  void _showMessage(
    String message,
    Color color,
  ) {
    if (!mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(
      SnackBar(
        content:
            Text(message),
        backgroundColor:
            color,
        behavior:
            SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(
          borderRadius:
              BorderRadius.circular(
            12,
          ),
        ),
      ),
    );
  }

  // =========================================================
  // BUILD
  // =========================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    final requests =
        filteredRequests;

    return Scaffold(
      backgroundColor:
          backgroundColor,

      appBar: AppBar(
        backgroundColor:
            backgroundColor,

        elevation: 0,

        leading:
            IconButton(
          icon:
              const Icon(
            Icons.arrow_back,
            color:
                Colors.black,
          ),

          onPressed: () {
            Navigator.pop(
              context,
            );
          },
        ),

        title:
            const Text(
          "Your Requests",
          style:
              TextStyle(
            color:
                Colors.black,
            fontWeight:
                FontWeight.bold,
          ),
        ),

        actions: [
          IconButton(
            onPressed:
                _loadVendorRequests,

            icon:
                const Icon(
              Icons.refresh_rounded,
              color:
                  Colors.black,
            ),
          ),
        ],
      ),

      body: RefreshIndicator(
        color:
            primaryColor,

        onRefresh:
            _loadVendorRequests,

        child: loading
            ? const Center(
                child:
                    CircularProgressIndicator(
                  color:
                      primaryColor,
                ),
              )
            : Column(
                children: [
                  _buildHeader(),

                  _buildFilters(),

                  const SizedBox(
                    height: 14,
                  ),

                  Expanded(
                    child:
                        requests.isEmpty
                            ? _buildEmptyState()
                            : ListView.builder(
                                physics:
                                    const AlwaysScrollableScrollPhysics(),

                                padding:
                                    const EdgeInsets.fromLTRB(
                                  16,
                                  0,
                                  16,
                                  30,
                                ),

                                itemCount:
                                    requests.length,

                                itemBuilder:
                                    (context,
                                        index) {
                                  return _buildRequestCard(
                                    requests[
                                        index],
                                    index,
                                  );
                                },
                              ),
                  ),
                ],
              ),
      ),
    );
  }
}

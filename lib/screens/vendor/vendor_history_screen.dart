import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_animate/flutter_animate.dart';

class VendorHistoryScreen extends StatefulWidget {
  const VendorHistoryScreen({super.key});

  @override
  State<VendorHistoryScreen> createState() =>
      _VendorHistoryScreenState();
}

class _VendorHistoryScreenState extends State<VendorHistoryScreen> {
  final User? currentUser =
      FirebaseAuth.instance.currentUser;

  final DatabaseReference servicesRef =
      FirebaseDatabase.instance.ref("services");

  final DatabaseReference societyBatchesRef =
      FirebaseDatabase.instance.ref("societyServiceBatches");

  bool loading = true;

  List<Map<String, dynamic>> history = [];
  List<Map<String, dynamic>> filteredHistory = [];

  String selectedType = "All";
  String selectedPayment = "All";

  final TextEditingController searchController =
      TextEditingController();

  double totalEarnings = 0;
  double thisMonthEarnings = 0;

  int completedJobs = 0;

  @override
  void initState() {
    super.initState();

    searchController.addListener(() {
      _applyFilters();
    });

    _loadHistory();
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  // ============================================================
  // LOAD ALL HISTORY
  // ============================================================

  Future<void> _loadHistory() async {
    if (currentUser == null) {
      if (!mounted) return;

      setState(() {
        loading = false;
      });

      return;
    }

    if (mounted) {
      setState(() {
        loading = true;
      });
    }

    try {
      final vendorId = currentUser!.uid;

      final servicesSnapshot =
          await servicesRef.get();

      final societySnapshot =
          await societyBatchesRef.get();

      final List<Map<String, dynamic>> allHistory = [];

      // ========================================================
      // INDIVIDUAL SERVICES
      // ========================================================

      if (servicesSnapshot.exists &&
          servicesSnapshot.value is Map) {
        final services =
            Map<dynamic, dynamic>.from(
          servicesSnapshot.value as Map,
        );

        services.forEach((serviceId, rawService) {
          if (rawService is! Map) {
            return;
          }

          final service =
              Map<String, dynamic>.from(rawService);

          final assignedWorkerId =
              service["assignedWorkerId"]?.toString();

          final status =
              service["status"]
                  ?.toString()
                  .toLowerCase();

          // Only this vendor's services.
          if (assignedWorkerId != vendorId) {
            return;
          }

          // Individual history only contains completed jobs.
          if (status != "completed") {
            return;
          }

          final workerCharge =
              _toDouble(
            service["workerServiceCharge"],
          );

          final finalPrice =
              _toDouble(
            service["finalPrice"],
          );

          final paymentAmount =
              _toDouble(
            service["paymentAmount"],
          );

          final earning =
              workerCharge > 0
                  ? workerCharge
                  : finalPrice;

          allHistory.add({
            "type": "Individual",
            "id": serviceId.toString(),

            "serviceName":
                service["serviceName"]?.toString() ??
                    "Service",

            "description":
                service["description"]?.toString() ??
                    "",

            "location":
                service["location"]?.toString() ??
                    "Location not available",

            "urgency":
                service["urgency"]?.toString() ??
                    "normal",

            "priority":
                service["priority"]?.toString() ??
                    "normal",

            "customerId":
                service["customerId"]?.toString() ??
                    "",

            "assignedWorkerId":
                assignedWorkerId,

            "finalPrice":
                finalPrice,

            "workerServiceCharge":
                workerCharge,

            "paymentAmount":
                paymentAmount,

            "earning":
                earning,

            "paymentStatus":
                service["paymentStatus"]?.toString() ??
                    "pending",

            "paymentId":
                service["paymentId"]?.toString() ??
                    "",

            "paymentOrderId":
                service["paymentOrderId"]?.toString() ??
                    "",

            "paymentCurrency":
                service["paymentCurrency"]?.toString() ??
                    "INR",

            "assignedAt":
                service["assignedAt"],

            "createdAt":
                service["createdAt"],

            "completedAt":
                service["completedAt"],

            "updatedAt":
                service["updatedAt"],

            "customerConfirmed":
                service["customerConfirmed"] == true,

            "bookingLocked":
                service["bookingLocked"] == true,

            "rawData":
                service,
          });
        });
      }

      // ========================================================
      // SOCIETY / APARTMENT SERVICE BATCHES
      // ========================================================

      if (societySnapshot.exists &&
          societySnapshot.value is Map) {
        final apartments =
            Map<dynamic, dynamic>.from(
          societySnapshot.value as Map,
        );

        apartments.forEach(
          (apartmentKey, apartmentRaw) {
            if (apartmentRaw is! Map) {
              return;
            }

            final apartmentServices =
                Map<dynamic, dynamic>.from(
              apartmentRaw,
            );

            apartmentServices.forEach(
              (serviceId, rawBatch) {
                if (rawBatch is! Map) {
                  return;
                }

                final batch =
                    Map<String, dynamic>.from(
                  rawBatch,
                );

                // ------------------------------------------------
                // SELECTED VENDOR
                // ------------------------------------------------

                final selectedVendorId =
                    batch["selectedVendorId"]
                        ?.toString();

                /*
                 * IMPORTANT:
                 *
                 * A society batch should appear in history
                 * when THIS vendor is selected.
                 *
                 * We do NOT require:
                 *
                 * batch.status == "completed"
                 *
                 * because the batch may currently be:
                 *
                 * 2/10 completed
                 * 5/10 completed
                 * 9/10 completed
                 *
                 * and should still appear in history.
                 */

                if (selectedVendorId != vendorId) {
                  return;
                }

                // ------------------------------------------------
                // BIDS
                // ------------------------------------------------

                final rawBids =
                    batch["bids"];

                Map<String, dynamic>? vendorBid;

                if (rawBids is Map) {
                  final bids =
                      Map<dynamic, dynamic>.from(
                    rawBids,
                  );

                  bids.forEach(
                    (bidVendorId, rawBid) {
                      if (rawBid is! Map) {
                        return;
                      }

                      final bid =
                          Map<String, dynamic>.from(
                        rawBid,
                      );

                      final bidVendor =
                          bid["vendorId"]?.toString() ??
                              bidVendorId.toString();

                      if (bidVendor == vendorId) {
                        vendorBid = bid;
                      }
                    },
                  );
                }

                /*
                 * Normally the selected vendor should also have
                 * a bid.
                 *
                 * If the bid is temporarily unavailable but
                 * selectedVendorId is correct, we still don't want
                 * to lose the batch from history.
                 */
                vendorBid ??= {
                  "vendorId": vendorId,
                  "vendorName": "",
                  "phone": "",
                  "email": "",
                  "bidAmount": 0,
                };

                // ------------------------------------------------
                // PARTICIPANTS
                // ------------------------------------------------

                int totalParticipants = 0;
                int completedParticipants = 0;
                int startedParticipants = 0;

                final rawParticipants =
                    batch["participants"];

                if (rawParticipants is Map) {
                  final participants =
                      Map<dynamic, dynamic>.from(
                    rawParticipants,
                  );

                  totalParticipants =
                      participants.length;

                  participants.forEach(
                    (customerId, rawParticipant) {
                      if (rawParticipant is! Map) {
                        return;
                      }

                      final participant =
                          Map<String, dynamic>.from(
                        rawParticipant,
                      );

                      final completed =
                          participant["completed"] == true ||
                          participant["completionStatus"]
                                  ?.toString()
                                  .toLowerCase() ==
                              "completed" ||
                          participant["workStatus"]
                                  ?.toString()
                                  .toLowerCase() ==
                              "completed";

                      if (completed) {
                        completedParticipants++;
                        return;
                      }

                      final started =
                          participant["workStarted"] == true ||
                          participant["workVerified"] == true ||
                          participant["workStatus"]
                                  ?.toString()
                                  .toLowerCase() ==
                              "started" ||
                          participant["workStatus"]
                                  ?.toString()
                                  .toLowerCase() ==
                              "in_progress";

                      if (started) {
                        startedParticipants++;
                      }
                    },
                  );
                }

                // ------------------------------------------------
                // BATCH STATUS
                // ------------------------------------------------

                final rawBatchStatus =
                    batch["status"]
                        ?.toString()
                        .toLowerCase() ??
                    "";

                final isCompleted =
                    rawBatchStatus == "completed" ||
                    batch["completed"] == true ||
                    batch["completionStatus"]
                            ?.toString()
                            .toLowerCase() ==
                        "completed" ||
                    (totalParticipants > 0 &&
                        completedParticipants ==
                            totalParticipants);

                final displayBatchStatus =
                    isCompleted
                        ? "Completed"
                        : "In Progress";

                // ------------------------------------------------
                // BID AMOUNT
                // ------------------------------------------------

                final bidAmount =
                    _toDouble(
                  vendorBid!["bidAmount"],
                );

                // ------------------------------------------------
                // PAYMENT
                // ------------------------------------------------

                final paymentStatus =
                    batch["paymentStatus"]?.toString() ??
                        vendorBid!["paymentStatus"]
                            ?.toString() ??
                        "pending";

                // ------------------------------------------------
                // SOCIETY HISTORY ITEM
                // ------------------------------------------------

                allHistory.add({
                  "type": "Society",

                  "id":
                      serviceId.toString(),

                  "apartmentKey":
                      apartmentKey.toString(),

                  "serviceId":
                      serviceId.toString(),

                  "serviceName":
                      batch["serviceName"]?.toString() ??
                          "Society Service",

                  "apartmentName":
                      batch["apartmentName"]?.toString() ??
                          "Apartment",

                  "address":
                      batch["address"]?.toString() ??
                          "",

                  "latitude":
                      batch["latitude"],

                  "longitude":
                      batch["longitude"],

                  "requestCount":
                      _toInt(
                    batch["requestCount"],
                  ),

                  "totalParticipants":
                      totalParticipants,

                  "completedParticipants":
                      completedParticipants,

                  "startedParticipants":
                      startedParticipants,

                  "pendingParticipants":
                      totalParticipants -
                          completedParticipants,

                  "bidAmount":
                      bidAmount,

                  "earning":
                      bidAmount,

                  "paymentStatus":
                      paymentStatus,

                  "paymentId":
                      batch["paymentId"]?.toString() ??
                          vendorBid!["paymentId"]
                              ?.toString() ??
                          "",

                  "paymentOrderId":
                      batch["paymentOrderId"]?.toString() ??
                          vendorBid!["paymentOrderId"]
                              ?.toString() ??
                          "",

                  "selectedVendorId":
                      selectedVendorId,

                  "vendorName":
                      vendorBid!["vendorName"]
                              ?.toString() ??
                          "",

                  "vendorPhone":
                      vendorBid!["phone"]
                              ?.toString() ??
                          "",

                  "vendorEmail":
                      vendorBid!["email"]
                              ?.toString() ??
                          "",

                  "completionDate":
                      vendorBid!["completionDate"]
                              ?.toString() ??
                          "",

                  "completionTime":
                      vendorBid!["completionTime"]
                              ?.toString() ??
                          "",

                  "createdAt":
                      batch["createdAt"],

                  "completedAt":
                      batch["completedAt"],

                  "updatedAt":
                      batch["updatedAt"],

                  "batchStatus":
                      rawBatchStatus,

                  "displayStatus":
                      displayBatchStatus,

                  "isCompleted":
                      isCompleted,

                  "rawData":
                      batch,
                });
              },
            );
          },
        );
      }

      // ========================================================
      // SORT NEWEST FIRST
      // ========================================================

      allHistory.sort((a, b) {
        final aDate =
            _getHistoryDate(a);

        final bDate =
            _getHistoryDate(b);

        return bDate.compareTo(aDate);
      });

      if (!mounted) {
        return;
      }

      setState(() {
        history = allHistory;

        filteredHistory =
            List<Map<String, dynamic>>.from(
          allHistory,
        );

        _calculateStatistics();

        loading = false;
      });

      _applyFilters();
    } catch (e) {
      debugPrint(
        "Vendor history error: $e",
      );

      if (!mounted) {
        return;
      }

      setState(() {
        loading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Unable to load history: $e",
          ),
        ),
      );
    }
  }

  // ============================================================
  // STATISTICS
  // ============================================================

  void _calculateStatistics() {
    double earnings = 0;
    double monthEarnings = 0;

    int completed = 0;

    final now = DateTime.now();

    for (final item in history) {
      final isSociety =
          item["type"] == "Society";

      final isCompleted =
          isSociety
              ? item["isCompleted"] == true
              : true;

      /*
       * Only completed work counts as completed jobs.
       *
       * A society batch that is 5/10 should appear in History,
       * but it should NOT be counted as completed yet.
       */
      if (isCompleted) {
        completed++;
      }

      /*
       * For earnings:
       *
       * Individual:
       * workerServiceCharge / fallback finalPrice
       *
       * Society:
       * vendor bid amount
       *
       * We count society earning only after the whole batch
       * is completed.
       */
      if (isCompleted) {
        final earning =
            _toDouble(item["earning"]);

        earnings += earning;

        final completedAt =
            _getHistoryDate(item);

        if (completedAt.year == now.year &&
            completedAt.month == now.month) {
          monthEarnings += earning;
        }
      }
    }

    totalEarnings = earnings;
    thisMonthEarnings = monthEarnings;
    completedJobs = completed;
  }

  // ============================================================
  // FILTERS
  // ============================================================

  void _applyFilters() {
    final search =
        searchController.text
            .trim()
            .toLowerCase();

    List<Map<String, dynamic>> result =
        List<Map<String, dynamic>>.from(
      history,
    );

    // ----------------------------------------------------------
    // TYPE
    // ----------------------------------------------------------

    if (selectedType != "All") {
      result = result.where((item) {
        return item["type"]
                ?.toString()
                .toLowerCase() ==
            selectedType.toLowerCase();
      }).toList();
    }

    // ----------------------------------------------------------
    // PAYMENT
    // ----------------------------------------------------------

    if (selectedPayment != "All") {
      result = result.where((item) {
        final status =
            item["paymentStatus"]
                    ?.toString()
                    .toLowerCase() ??
                "pending";

        final paid =
            _isPaid(status);

        if (selectedPayment == "Paid") {
          return paid;
        }

        return !paid;
      }).toList();
    }

    // ----------------------------------------------------------
    // SEARCH
    // ----------------------------------------------------------

    if (search.isNotEmpty) {
      result = result.where((item) {
        final serviceName =
            item["serviceName"]
                    ?.toString()
                    .toLowerCase() ??
                "";

        final location =
            item["location"]
                    ?.toString()
                    .toLowerCase() ??
                "";

        final apartmentName =
            item["apartmentName"]
                    ?.toString()
                    .toLowerCase() ??
                "";

        final address =
            item["address"]
                    ?.toString()
                    .toLowerCase() ??
                "";

        return serviceName.contains(search) ||
            location.contains(search) ||
            apartmentName.contains(search) ||
            address.contains(search);
      }).toList();
    }

    if (!mounted) {
      return;
    }

    setState(() {
      filteredHistory = result;
    });
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          const Color(0xffF8FAFC),

      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        surfaceTintColor:
            Colors.transparent,
        foregroundColor:
            const Color(0xff0F172A),

        title: const Text(
          "History",
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
          ),
        ),

        actions: [
          IconButton(
            onPressed: _loadHistory,
            icon: const Icon(
              Icons.refresh_rounded,
            ),
          ),
        ],
      ),

      body: loading
          ? const Center(
              child:
                  CircularProgressIndicator(),
            )
          : RefreshIndicator(
              onRefresh: _loadHistory,

              child: SingleChildScrollView(
                physics:
                    const AlwaysScrollableScrollPhysics(
                  parent:
                      BouncingScrollPhysics(),
                ),

                padding:
                    const EdgeInsets.fromLTRB(
                  20,
                  10,
                  20,
                  40,
                ),

                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,

                  children: [
                    _buildSummaryCard(),

                    const SizedBox(height: 20),

                    _buildSearchBar(),

                    const SizedBox(height: 14),

                    _buildTypeFilter(),

                    const SizedBox(height: 12),

                    _buildPaymentFilter(),

                    const SizedBox(height: 24),

                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            "Service History",
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight:
                                  FontWeight.w800,
                              color:
                                  Color(0xff0F172A),
                            ),
                          ),
                        ),

                        Text(
                          "${filteredHistory.length}",
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight:
                                FontWeight.bold,
                            color:
                                Colors.blue.shade600,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    if (filteredHistory.isEmpty)
                      _buildEmptyState()
                    else
                      Column(
                        children:
                            filteredHistory
                                .asMap()
                                .entries
                                .map(
                                  (entry) {
                                    return _buildHistoryCard(
                                      entry.value,
                                      entry.key,
                                    );
                                  },
                                )
                                .toList(),
                      ),
                  ],
                ),
              ),
            ),
    );
  }

  // ============================================================
  // SUMMARY
  // ============================================================

  Widget _buildSummaryCard() {
    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.all(20),

      decoration: BoxDecoration(
        gradient:
            const LinearGradient(
          begin:
              Alignment.topLeft,
          end:
              Alignment.bottomRight,
          colors: [
            Color(0xff0F172A),
            Color(0xff1E293B),
          ],
        ),

        borderRadius:
            BorderRadius.circular(24),

        boxShadow: [
          BoxShadow(
            color:
                Colors.black.withOpacity(
              0.12,
            ),
            blurRadius: 20,
            offset:
                const Offset(0, 10),
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
                width: 46,
                height: 46,

                decoration:
                    BoxDecoration(
                  color:
                      Colors.white.withOpacity(
                    0.12,
                  ),
                  borderRadius:
                      BorderRadius.circular(
                    14,
                  ),
                ),

                child: const Icon(
                  Icons
                      .account_balance_wallet_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),

              const SizedBox(width: 14),

              const Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Your Earnings",
                      style: TextStyle(
                        color:
                            Colors.white70,
                        fontSize: 13,
                        fontWeight:
                            FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      "Completed work",
                      style: TextStyle(
                        color:
                            Colors.white,
                        fontSize: 19,
                        fontWeight:
                            FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 22),

          Text(
            "₹${totalEarnings.toStringAsFixed(0)}",
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight:
                  FontWeight.w900,
            ),
          ),

          const SizedBox(height: 20),

          Row(
            children: [
              Expanded(
                child: _summaryItem(
                  Icons
                      .check_circle_rounded,
                  "$completedJobs",
                  "Completed",
                ),
              ),

              Container(
                width: 1,
                height: 42,
                color: Colors.white24,
              ),

              Expanded(
                child: _summaryItem(
                  Icons
                      .calendar_month_rounded,
                  "₹${thisMonthEarnings.toStringAsFixed(0)}",
                  "This Month",
                ),
              ),
            ],
          ),
        ],
      ),
    )
        .animate()
        .fadeIn()
        .slideY(
          begin: 0.08,
          end: 0,
        );
  }

  Widget _summaryItem(
    IconData icon,
    String value,
    String label,
  ) {
    return Padding(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 8,
      ),

      child: Row(
        children: [
          Icon(
            icon,
            color:
                Colors.white70,
            size: 20,
          ),

          const SizedBox(width: 8),

          Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style:
                    const TextStyle(
                  color:
                      Colors.white,
                  fontSize: 15,
                  fontWeight:
                      FontWeight.w800,
                ),
              ),

              const SizedBox(height: 2),

              Text(
                label,
                style:
                    const TextStyle(
                  color:
                      Colors.white60,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ============================================================
  // SEARCH
  // ============================================================

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(17),
        boxShadow: [
          BoxShadow(
            color:
                Colors.black.withOpacity(
              0.045,
            ),
            blurRadius: 15,
            offset:
                const Offset(0, 5),
          ),
        ],
      ),

      child: TextField(
        controller:
            searchController,

        decoration:
            InputDecoration(
          hintText:
              "Search service or apartment...",

          hintStyle:
              const TextStyle(
            color: Colors.grey,
            fontSize: 13,
          ),

          prefixIcon:
              const Icon(
            Icons.search_rounded,
            color: Colors.grey,
          ),

          suffixIcon:
              searchController
                      .text
                      .isNotEmpty
                  ? IconButton(
                      onPressed: () {
                        searchController
                            .clear();
                      },
                      icon:
                          const Icon(
                        Icons
                            .close_rounded,
                      ),
                    )
                  : null,

          border:
              InputBorder.none,

          contentPadding:
              const EdgeInsets.symmetric(
            vertical: 17,
          ),
        ),
      ),
    );
  }

  // ============================================================
  // TYPE FILTER
  // ============================================================

  Widget _buildTypeFilter() {
    return SingleChildScrollView(
      scrollDirection:
          Axis.horizontal,

      child: Row(
        children: [
          _filterChip(
            "All",
            selectedType == "All",
            () {
              setState(() {
                selectedType =
                    "All";
              });

              _applyFilters();
            },
          ),

          const SizedBox(width: 8),

          _filterChip(
            "Individual",
            selectedType ==
                "Individual",
            () {
              setState(() {
                selectedType =
                    "Individual";
              });

              _applyFilters();
            },
          ),

          const SizedBox(width: 8),

          _filterChip(
            "Society",
            selectedType ==
                "Society",
            () {
              setState(() {
                selectedType =
                    "Society";
              });

              _applyFilters();
            },
          ),
        ],
      ),
    );
  }

  // ============================================================
  // PAYMENT FILTER
  // ============================================================

  Widget _buildPaymentFilter() {
    return SingleChildScrollView(
      scrollDirection:
          Axis.horizontal,

      child: Row(
        children: [
          const Text(
            "Payment:",
            style: TextStyle(
              fontSize: 12,
              fontWeight:
                  FontWeight.w700,
              color:
                  Color(0xff475569),
            ),
          ),

          const SizedBox(width: 8),

          _smallFilterChip(
            "All",
            selectedPayment ==
                "All",
            () {
              setState(() {
                selectedPayment =
                    "All";
              });

              _applyFilters();
            },
          ),

          const SizedBox(width: 7),

          _smallFilterChip(
            "Paid",
            selectedPayment ==
                "Paid",
            () {
              setState(() {
                selectedPayment =
                    "Paid";
              });

              _applyFilters();
            },
          ),

          const SizedBox(width: 7),

          _smallFilterChip(
            "Pending",
            selectedPayment ==
                "Pending",
            () {
              setState(() {
                selectedPayment =
                    "Pending";
              });

              _applyFilters();
            },
          ),
        ],
      ),
    );
  }

  Widget _filterChip(
    String title,
    bool selected,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,

      child:
          AnimatedContainer(
        duration:
            const Duration(
          milliseconds: 200,
        ),

        padding:
            const EdgeInsets.symmetric(
          horizontal: 17,
          vertical: 10,
        ),

        decoration:
            BoxDecoration(
          color: selected
              ? const Color(
                  0xff2563EB,
                )
              : Colors.white,

          borderRadius:
              BorderRadius.circular(
            14,
          ),

          border:
              Border.all(
            color: selected
                ? const Color(
                    0xff2563EB,
                  )
                : const Color(
                    0xffE2E8F0,
                  ),
          ),
        ),

        child: Text(
          title,
          style: TextStyle(
            color: selected
                ? Colors.white
                : const Color(
                    0xff475569,
                  ),
            fontSize: 12,
            fontWeight:
                FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _smallFilterChip(
    String title,
    bool selected,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,

      child:
          AnimatedContainer(
        duration:
            const Duration(
          milliseconds: 200,
        ),

        padding:
            const EdgeInsets.symmetric(
          horizontal: 13,
          vertical: 7,
        ),

        decoration:
            BoxDecoration(
          color: selected
              ? const Color(
                  0xffE0ECFF,
                )
              : Colors.white,

          borderRadius:
              BorderRadius.circular(
            10,
          ),

          border:
              Border.all(
            color: selected
                ? const Color(
                    0xff2563EB,
                  )
                : const Color(
                    0xffE2E8F0,
                  ),
          ),
        ),

        child: Text(
          title,
          style: TextStyle(
            color: selected
                ? const Color(
                    0xff2563EB,
                  )
                : const Color(
                    0xff64748B,
                  ),
            fontSize: 11,
            fontWeight:
                FontWeight.w700,
          ),
        ),
      ),
    );
  }

  // ============================================================
  // HISTORY CARD
  // ============================================================

  Widget _buildHistoryCard(
    Map<String, dynamic> item,
    int index,
  ) {
    final isSociety =
        item["type"] == "Society";

    final serviceName =
        item["serviceName"]
                ?.toString() ??
            "Service";

    final earning =
        _toDouble(
      item["earning"],
    );

    final paymentStatus =
        item["paymentStatus"]
                ?.toString() ??
            "pending";

    final paid =
        _isPaid(paymentStatus);

    final date =
        _getHistoryDate(item);

    final isCompleted =
        isSociety
            ? item["isCompleted"] == true
            : true;

    final totalFlats =
        _toInt(
      item["totalParticipants"],
    );

    final completedFlats =
        _toInt(
      item["completedParticipants"],
    );

    final progress =
        totalFlats > 0
            ? completedFlats /
                totalFlats
            : 0.0;

    return GestureDetector(
      onTap: () {
        _showHistoryDetails(item);
      },

      child: Container(
        width: double.infinity,

        margin:
            const EdgeInsets.only(
          bottom: 14,
        ),

        padding:
            const EdgeInsets.all(
          17,
        ),

        decoration:
            BoxDecoration(
          color: Colors.white,

          borderRadius:
              BorderRadius.circular(
            20,
          ),

          boxShadow: [
            BoxShadow(
              color:
                  Colors.black.withOpacity(
                0.045,
              ),
              blurRadius: 16,
              offset:
                  const Offset(0, 6),
            ),
          ],
        ),

        child: Column(
          children: [
            Row(
              crossAxisAlignment:
                  CrossAxisAlignment.start,

              children: [
                Container(
                  width: 48,
                  height: 48,

                  decoration:
                      BoxDecoration(
                    color: isSociety
                        ? const Color(
                            0xffEEF2FF,
                          )
                        : const Color(
                            0xffEFF6FF,
                          ),

                    borderRadius:
                        BorderRadius.circular(
                      14,
                    ),
                  ),

                  child: Icon(
                    isSociety
                        ? Icons
                            .apartment_rounded
                        : _serviceIcon(
                            serviceName,
                          ),

                    color: isSociety
                        ? const Color(
                            0xff6366F1,
                          )
                        : const Color(
                            0xff2563EB,
                          ),

                    size: 24,
                  ),
                ),

                const SizedBox(
                  width: 13,
                ),

                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,

                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              serviceName,
                              maxLines: 1,
                              overflow:
                                  TextOverflow
                                      .ellipsis,

                              style:
                                  const TextStyle(
                                fontSize: 15,
                                fontWeight:
                                    FontWeight
                                        .w800,
                                color:
                                    Color(
                                  0xff0F172A,
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(
                            width: 6,
                          ),

                          _statusBadge(
                            isSociety
                                ? (isCompleted
                                    ? "Completed"
                                    : "In Progress")
                                : "Completed",
                            isCompleted,
                          ),
                        ],
                      ),

                      const SizedBox(
                        height: 6,
                      ),

                      Text(
                        isSociety
                            ? item["apartmentName"]
                                    ?.toString() ??
                                "Apartment"
                            : item["location"]
                                    ?.toString() ??
                                "Location unavailable",

                        maxLines: 1,
                        overflow:
                            TextOverflow
                                .ellipsis,

                        style:
                            const TextStyle(
                          color:
                              Color(
                            0xff64748B,
                          ),
                          fontSize: 11,
                        ),
                      ),

                      const SizedBox(
                        height: 5,
                      ),

                      Row(
                        children: [
                          Icon(
                            Icons
                                .calendar_today_rounded,
                            size: 12,
                            color:
                                Colors.grey
                                    .shade500,
                          ),

                          const SizedBox(
                            width: 5,
                          ),

                          Text(
                            _formatDate(
                              date,
                            ),

                            style:
                                const TextStyle(
                              color:
                                  Color(
                                0xff64748B,
                              ),
                              fontSize: 10,
                              fontWeight:
                                  FontWeight
                                      .w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(
              height: 15,
            ),

            Container(
              height: 1,
              color:
                  const Color(
                0xffF1F5F9,
              ),
            ),

            const SizedBox(
              height: 13,
            ),

            // ==================================================
            // SOCIETY PROGRESS
            // ==================================================

            if (isSociety) ...[
              Row(
                children: [
                  const Icon(
                    Icons
                        .home_work_rounded,
                    size: 17,
                    color:
                        Color(
                      0xff6366F1,
                    ),
                  ),

                  const SizedBox(
                    width: 7,
                  ),

                  Expanded(
                    child: Text(
                      "$completedFlats / $totalFlats Flats Completed",

                      style:
                          const TextStyle(
                        fontSize: 12,
                        fontWeight:
                            FontWeight
                                .w800,
                        color:
                            Color(
                          0xff334155,
                        ),
                      ),
                    ),
                  ),

                  Text(
                    totalFlats > 0
                        ? "${(progress * 100).toInt()}%"
                        : "0%",

                    style:
                        const TextStyle(
                      fontSize: 11,
                      fontWeight:
                          FontWeight
                              .w800,
                      color:
                          Color(
                        0xff6366F1,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(
                height: 9,
              ),

              ClipRRect(
                borderRadius:
                    BorderRadius.circular(
                  20,
                ),

                child:
                    LinearProgressIndicator(
                  value:
                      progress,
                  minHeight: 7,
                  backgroundColor:
                      const Color(
                    0xffEEF2FF,
                  ),
                  valueColor:
                      const AlwaysStoppedAnimation<
                          Color>(
                    Color(
                      0xff6366F1,
                    ),
                  ),
                ),
              ),

              const SizedBox(
                height: 14,
              ),
            ],

            // ==================================================
            // MINI INFO
            // ==================================================

            Row(
              children: [
                if (isSociety)
                  Expanded(
                    child:
                        _miniInfo(
                      Icons
                          .pending_actions_rounded,
                      "${item["pendingParticipants"] ?? 0}",
                      "Pending",
                    ),
                  )
                else
                  Expanded(
                    child:
                        _miniInfo(
                      Icons
                          .person_outline_rounded,
                      "Individual",
                      "Type",
                    ),
                  ),

                Expanded(
                  child:
                      _miniInfo(
                    paid
                        ? Icons
                            .payments_rounded
                        : Icons
                            .pending_actions_rounded,
                    paid
                        ? "Paid"
                        : "Pending",
                    "Payment",
                  ),
                ),

                Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.end,
                  children: [
                    Text(
                      isSociety
                          ? "Bid"
                          : "Earning",

                      style:
                          const TextStyle(
                        color:
                            Color(
                          0xff94A3B8,
                        ),
                        fontSize: 9,
                        fontWeight:
                            FontWeight
                                .w600,
                      ),
                    ),

                    const SizedBox(
                      height: 3,
                    ),

                    Text(
                      "₹${earning.toStringAsFixed(0)}",

                      style:
                          const TextStyle(
                        color:
                            Color(
                          0xff16A34A,
                        ),
                        fontSize: 16,
                        fontWeight:
                            FontWeight
                                .w900,
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(
              height: 11,
            ),

            Row(
              mainAxisAlignment:
                  MainAxisAlignment.end,
              children: [
                Text(
                  isSociety
                      ? "View flats"
                      : "View details",

                  style: TextStyle(
                    color:
                        Colors.blue.shade600,
                    fontSize: 10,
                    fontWeight:
                        FontWeight.w700,
                  ),
                ),

                const SizedBox(
                  width: 3,
                ),

                Icon(
                  Icons
                      .arrow_forward_ios_rounded,
                  size: 10,
                  color:
                      Colors.blue.shade600,
                ),
              ],
            ),
          ],
        ),
      ),
    )
        .animate()
        .fadeIn(
          delay: Duration(
            milliseconds:
                index * 50,
          ),
        )
        .slideY(
          begin: 0.05,
          end: 0,
        );
  }

  // ============================================================
  // MINI INFO
  // ============================================================

  Widget _miniInfo(
    IconData icon,
    String value,
    String label,
  ) {
    return Row(
      children: [
        Icon(
          icon,
          size: 16,
          color:
              const Color(
            0xff64748B,
          ),
        ),

        const SizedBox(
          width: 6,
        ),

        Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style:
                  const TextStyle(
                fontSize: 11,
                fontWeight:
                    FontWeight.w800,
                color:
                    Color(
                  0xff334155,
                ),
              ),
            ),

            Text(
              label,
              style:
                  const TextStyle(
                fontSize: 8,
                color:
                    Color(
                  0xff94A3B8,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ============================================================
  // STATUS BADGE
  // ============================================================

  Widget _statusBadge(
    String text,
    bool success,
  ) {
    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 5,
      ),

      decoration:
          BoxDecoration(
        color: success
            ? const Color(
                0xffDCFCE7,
              )
            : const Color(
                0xffFEF3C7,
              ),

        borderRadius:
            BorderRadius.circular(
          8,
        ),
      ),

      child: Text(
        text,
        style: TextStyle(
          color: success
              ? const Color(
                  0xff15803D,
                )
              : const Color(
                  0xffB45309,
                ),
          fontSize: 8,
          fontWeight:
              FontWeight.w800,
        ),
      ),
    );
  }

  // ============================================================
  // EMPTY
  // ============================================================

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,

      padding:
          const EdgeInsets.symmetric(
        vertical: 55,
        horizontal: 25,
      ),

      decoration:
          BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(
          22,
        ),
      ),

      child: Column(
        children: [
          Container(
            width: 70,
            height: 70,

            decoration:
                BoxDecoration(
              color:
                  const Color(
                0xffEFF6FF,
              ),
              borderRadius:
                  BorderRadius.circular(
                22,
              ),
            ),

            child: const Icon(
              Icons.history_rounded,
              size: 34,
              color:
                  Color(
                0xff2563EB,
              ),
            ),
          ),

          const SizedBox(
            height: 16,
          ),

          const Text(
            "No history found",
            style: TextStyle(
              fontSize: 17,
              fontWeight:
                  FontWeight.w800,
              color:
                  Color(
                0xff0F172A,
              ),
            ),
          ),

          const SizedBox(
            height: 6,
          ),

          const Text(
            "Completed individual services and selected society batches will appear here.",
            textAlign:
                TextAlign.center,
            style: TextStyle(
              color:
                  Color(
                0xff64748B,
              ),
              fontSize: 12,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // HISTORY DETAILS
  // ============================================================

  void _showHistoryDetails(
    Map<String, dynamic> item,
  ) {
    final isSociety =
        item["type"] == "Society";

    if (isSociety) {
      _showSocietyHistoryDetails(
        item,
      );

      return;
    }

    _showIndividualHistoryDetails(
      item,
    );
  }

  // ============================================================
  // SOCIETY DETAILS
  // ============================================================

  void _showSocietyHistoryDetails(
    Map<String, dynamic> item,
  ) {
    final apartmentKey =
        item["apartmentKey"]
            ?.toString();

    final serviceId =
        item["serviceId"]
            ?.toString();

    if (apartmentKey == null ||
        apartmentKey.isEmpty ||
        serviceId == null ||
        serviceId.isEmpty) {
      return;
    }

    final batchRef =
        societyBatchesRef
            .child(apartmentKey)
            .child(serviceId);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor:
          Colors.transparent,

      builder: (sheetContext) {
        return Container(
          constraints:
              BoxConstraints(
            maxHeight:
                MediaQuery.of(
                  sheetContext,
                ).size.height *
                0.90,
          ),

          decoration:
              const BoxDecoration(
            color: Colors.white,
            borderRadius:
                BorderRadius.vertical(
              top: Radius.circular(
                28,
              ),
            ),
          ),

          child:
              StreamBuilder<
                  DatabaseEvent>(
            stream:
                batchRef.onValue,

            builder:
                (
              context,
              snapshot,
            ) {
              if (snapshot
                  .connectionState ==
                  ConnectionState.waiting) {
                return const Center(
                  child:
                      Padding(
                    padding:
                        EdgeInsets.all(
                      50,
                    ),
                    child:
                        CircularProgressIndicator(),
                  ),
                );
              }

              if (!snapshot.hasData ||
                  snapshot.data!.snapshot
                      .value ==
                      null) {
                return _buildDetailsNotFound();
              }

              final rawValue =
                  snapshot.data!
                      .snapshot.value;

              if (rawValue is! Map) {
                return _buildDetailsNotFound();
              }

              final batch =
                  Map<String, dynamic>.from(
                rawValue,
              );

              return _buildLiveSocietyDetails(
                batch,
                item,
              );
            },
          ),
        );
      },
    );
  }

  // ============================================================
  // LIVE SOCIETY DETAILS
  // ============================================================

  Widget _buildLiveSocietyDetails(
    Map<String, dynamic> batch,
    Map<String, dynamic> item,
  ) {
    final serviceName =
        batch["serviceName"]?.toString() ??
            item["serviceName"]
                ?.toString() ??
            "Society Service";

    final apartmentName =
        batch["apartmentName"]
                ?.toString() ??
            item["apartmentName"]
                ?.toString() ??
            "Apartment";

    final address =
        batch["address"]?.toString() ??
            item["address"]
                ?.toString() ??
            "Address unavailable";

    final selectedVendorId =
        batch["selectedVendorId"]
            ?.toString() ??
        item["selectedVendorId"]
            ?.toString();

    final vendorBid =
        _findVendorBid(
      batch["bids"],
      selectedVendorId,
    );

    final bidAmount =
        _toDouble(
      vendorBid?["bidAmount"] ??
          item["bidAmount"],
    );

    final rawParticipants =
        batch["participants"];

    final List<Map<String, dynamic>>
        participants = [];

    if (rawParticipants is Map) {
      final map =
          Map<dynamic, dynamic>.from(
        rawParticipants,
      );

      map.forEach(
        (customerId, rawParticipant) {
          if (rawParticipant is! Map) {
            return;
          }

          final participant =
              Map<String, dynamic>.from(
            rawParticipant,
          );

          participant["_customerId"] =
              customerId.toString();

          participants.add(
            participant,
          );
        },
      );
    }

    // ----------------------------------------------------------
    // SORT FLATS
    // ----------------------------------------------------------

    participants.sort(
      (a, b) {
        final flatA =
            a["flatNumber"]
                    ?.toString() ??
                "";

        final flatB =
            b["flatNumber"]
                    ?.toString() ??
                "";

        return flatA.compareTo(
          flatB,
        );
      },
    );

    // ----------------------------------------------------------
    // COUNTS
    // ----------------------------------------------------------

    int completed = 0;
    int started = 0;

    for (final participant
        in participants) {
      final isCompleted =
          _isParticipantCompleted(
        participant,
      );

      if (isCompleted) {
        completed++;
      } else if (_isParticipantStarted(
        participant,
      )) {
        started++;
      }
    }

    final total =
        participants.length;

    final pending =
        total - completed;

    final isBatchCompleted =
        batch["status"]
                ?.toString()
                .toLowerCase() ==
            "completed" ||
        batch["completed"] == true ||
        batch["completionStatus"]
                ?.toString()
                .toLowerCase() ==
            "completed" ||
        (total > 0 &&
            completed == total);

    final progress =
        total > 0
            ? completed / total
            : 0.0;

    return Column(
      children: [
        // ======================================================
        // HEADER
        // ======================================================

        Padding(
          padding:
              const EdgeInsets.fromLTRB(
            22,
            14,
            22,
            0,
          ),

          child: Column(
            children: [
              Center(
                child: Container(
                  width: 45,
                  height: 5,

                  decoration:
                      BoxDecoration(
                    color:
                        Colors.grey.shade300,
                    borderRadius:
                        BorderRadius.circular(
                      20,
                    ),
                  ),
                ),
              ),

              const SizedBox(
                height: 22,
              ),

              Row(
                children: [
                  Container(
                    width: 54,
                    height: 54,

                    decoration:
                        BoxDecoration(
                      color:
                          const Color(
                        0xffEEF2FF,
                      ),
                      borderRadius:
                          BorderRadius.circular(
                        16,
                      ),
                    ),

                    child:
                        const Icon(
                      Icons
                          .apartment_rounded,
                      color:
                          Color(
                        0xff6366F1,
                      ),
                      size: 27,
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
                        Text(
                          serviceName,
                          maxLines: 1,
                          overflow:
                              TextOverflow
                                  .ellipsis,

                          style:
                              const TextStyle(
                            fontSize: 20,
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
                                Color(
                              0xff64748B,
                            ),
                            fontSize: 11,
                            fontWeight:
                                FontWeight
                                .w600,
                          ),
                        ),
                      ],
                    ),
                  ),

                  _statusBadge(
                    isBatchCompleted
                        ? "Completed"
                        : "In Progress",
                    isBatchCompleted,
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(
          height: 22,
        ),

        Expanded(
          child:
              SingleChildScrollView(
            physics:
                const BouncingScrollPhysics(),

            padding:
                const EdgeInsets.fromLTRB(
              22,
              0,
              22,
              35,
            ),

            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,

              children: [
                // ==================================================
                // PROGRESS CARD
                // ==================================================

                Container(
                  width:
                      double.infinity,

                  padding:
                      const EdgeInsets.all(
                    18,
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
                        Color(
                          0xffEEF2FF,
                        ),
                        Color(
                          0xffF8FAFC,
                        ),
                      ],
                    ),

                    borderRadius:
                        BorderRadius.circular(
                      20,
                    ),

                    border:
                        Border.all(
                      color:
                          const Color(
                        0xffE0E7FF,
                      ),
                    ),
                  ),

                  child: Column(
                    children: [
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              "Service Progress",
                              style:
                                  TextStyle(
                                fontSize:
                                    15,
                                fontWeight:
                                    FontWeight
                                        .w800,
                                color:
                                    Color(
                                  0xff0F172A,
                                ),
                              ),
                            ),
                          ),

                          Text(
                            "$completed / $total",

                            style:
                                const TextStyle(
                              fontSize:
                                  17,
                              fontWeight:
                                  FontWeight
                                      .w900,
                              color:
                                  Color(
                                0xff6366F1,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(
                        height: 6,
                      ),

                      const Align(
                        alignment:
                            Alignment.centerLeft,
                        child: Text(
                          "Flats completed",
                          style:
                              TextStyle(
                            fontSize: 10,
                            color:
                                Color(
                              0xff64748B,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(
                        height: 14,
                      ),

                      ClipRRect(
                        borderRadius:
                            BorderRadius
                                .circular(
                          20,
                        ),

                        child:
                            LinearProgressIndicator(
                          value:
                              progress,
                          minHeight:
                              9,
                          backgroundColor:
                              Colors.white,
                          valueColor:
                              const AlwaysStoppedAnimation<
                                  Color>(
                            Color(
                              0xff6366F1,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(
                        height: 14,
                      ),

                      Row(
                        children: [
                          Expanded(
                            child:
                                _progressMiniStat(
                              Icons
                                  .check_circle_rounded,
                              "$completed",
                              "Completed",
                              const Color(
                                0xff16A34A,
                              ),
                            ),
                          ),

                          Expanded(
                            child:
                                _progressMiniStat(
                              Icons
                                  .play_circle_rounded,
                              "$started",
                              "Started",
                              const Color(
                                0xff2563EB,
                              ),
                            ),
                          ),

                          Expanded(
                            child:
                                _progressMiniStat(
                              Icons
                                  .schedule_rounded,
                              "$pending",
                              "Pending",
                              const Color(
                                0xffD97706,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(
                  height: 20,
                ),

                // ==================================================
                // APARTMENT INFO
                // ==================================================

                _detailSection(
                  "Batch Information",
                  [
                    _detailRow(
                      Icons
                          .apartment_rounded,
                      "Apartment",
                      apartmentName,
                    ),

                    _detailRow(
                      Icons
                          .location_on_rounded,
                      "Address",
                      address.isEmpty
                          ? "N/A"
                          : address,
                    ),

                    _detailRow(
                      Icons
                          .payments_rounded,
                      "Vendor Bid",
                      "₹${bidAmount.toStringAsFixed(0)}",
                    ),

                    _detailRow(
                      Icons
                          .info_outline_rounded,
                      "Status",
                      isBatchCompleted
                          ? "Completed"
                          : "In Progress",
                    ),
                  ],
                ),

                const SizedBox(
                  height: 22,
                ),

                // ==================================================
                // FLATS
                // ==================================================

                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        "Flat-wise Status",
                        style:
                            TextStyle(
                          fontSize: 15,
                          fontWeight:
                              FontWeight
                                  .w800,
                          color:
                              Color(
                            0xff0F172A,
                          ),
                        ),
                      ),
                    ),

                    Text(
                      "$completed/$total",

                      style:
                          const TextStyle(
                        fontSize: 12,
                        fontWeight:
                            FontWeight
                                .w800,
                        color:
                            Color(
                          0xff6366F1,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(
                  height: 11,
                ),

                if (participants.isEmpty)
                  Container(
                    width:
                        double.infinity,

                    padding:
                        const EdgeInsets.all(
                      25,
                    ),

                    decoration:
                        BoxDecoration(
                      color:
                          const Color(
                        0xffF8FAFC,
                      ),
                      borderRadius:
                          BorderRadius.circular(
                        17,
                      ),
                    ),

                    child:
                        const Column(
                      children: [
                        Icon(
                          Icons
                              .home_work_outlined,
                          size: 32,
                          color:
                              Color(
                            0xff94A3B8,
                          ),
                        ),
                        SizedBox(
                          height: 8,
                        ),
                        Text(
                          "No flats found",
                          style:
                              TextStyle(
                            fontSize:
                                13,
                            fontWeight:
                                FontWeight
                                    .w700,
                            color:
                                Color(
                              0xff64748B,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  Column(
                    children:
                        participants
                            .asMap()
                            .entries
                            .map(
                              (entry) {
                                return _buildFlatStatusCard(
                                  entry.value,
                                  entry.key,
                                );
                              },
                            )
                            .toList(),
                  ),

                const SizedBox(
                  height: 20,
                ),

                // ==================================================
                // NOTE
                // ==================================================

                Container(
                  width:
                      double.infinity,

                  padding:
                      const EdgeInsets.all(
                    15,
                  ),

                  decoration:
                      BoxDecoration(
                    color:
                        const Color(
                      0xffF8FAFC,
                    ),
                    borderRadius:
                        BorderRadius.circular(
                      16,
                    ),
                  ),

                  child: Row(
                    crossAxisAlignment:
                        CrossAxisAlignment
                            .start,

                    children: [
                      const Icon(
                        Icons
                            .info_outline_rounded,
                        size: 18,
                        color:
                            Color(
                          0xff64748B,
                        ),
                      ),

                      const SizedBox(
                        width: 9,
                      ),

                      const Expanded(
                        child: Text(
                          "This page shows the latest flat status directly from the society service batch.",
                          style:
                              TextStyle(
                            fontSize:
                                10,
                            height:
                                1.5,
                            color:
                                Color(
                              0xff64748B,
                            ),
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
    );
  }

  // ============================================================
  // FLAT STATUS CARD
  // ============================================================

  Widget _buildFlatStatusCard(
    Map<String, dynamic> participant,
    int index,
  ) {
    final flatNumber =
        participant["flatNumber"]
                ?.toString() ??
            participant["flatNo"]
                ?.toString() ??
            "Flat";

    final customerName =
        participant["customerName"]
                ?.toString() ??
            participant["name"]
                ?.toString() ??
            "";

    final completed =
        _isParticipantCompleted(
      participant,
    );

    final started =
        _isParticipantStarted(
      participant,
    );

    final workStatus =
        participant["workStatus"]
                ?.toString()
                .toLowerCase() ??
            "";

    String statusText;
    IconData statusIcon;
    Color statusColor;
    Color backgroundColor;

    if (completed) {
      statusText = "Completed";
      statusIcon =
          Icons.check_circle_rounded;
      statusColor =
          const Color(0xff16A34A);
      backgroundColor =
          const Color(0xffF0FDF4);
    } else if (started ||
        workStatus ==
            "in_progress") {
      statusText = "Work Started";
      statusIcon =
          Icons.play_circle_rounded;
      statusColor =
          const Color(0xff2563EB);
      backgroundColor =
          const Color(0xffEFF6FF);
    } else {
      statusText = "Pending";
      statusIcon =
          Icons.schedule_rounded;
      statusColor =
          const Color(0xffD97706);
      backgroundColor =
          const Color(0xffFFFBEB);
    }

    return Container(
      width: double.infinity,

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
        color:
            backgroundColor,

        borderRadius:
            BorderRadius.circular(
          16,
        ),

        border:
            Border.all(
          color:
              statusColor.withOpacity(
            0.15,
          ),
        ),
      ),

      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,

            decoration:
                BoxDecoration(
              color:
                  statusColor.withOpacity(
                0.10,
              ),
              borderRadius:
                  BorderRadius.circular(
                12,
              ),
            ),

            child: Icon(
              Icons
                  .home_work_rounded,
              color:
                  statusColor,
              size: 21,
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
                  flatNumber
                          .toLowerCase()
                          .startsWith("flat")
                      ? flatNumber
                      : "Flat $flatNumber",

                  style:
                      const TextStyle(
                    fontSize: 13,
                    fontWeight:
                        FontWeight.w800,
                    color:
                        Color(
                      0xff0F172A,
                    ),
                  ),
                ),

                if (customerName
                    .trim()
                    .isNotEmpty) ...[
                  const SizedBox(
                    height: 3,
                  ),

                  Text(
                    customerName,
                    maxLines: 1,
                    overflow:
                        TextOverflow
                            .ellipsis,

                    style:
                        const TextStyle(
                      fontSize: 9,
                      color:
                          Color(
                        0xff64748B,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(
            width: 8,
          ),

          Container(
            padding:
                const EdgeInsets.symmetric(
              horizontal: 9,
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
                  BorderRadius.circular(
                10,
              ),
            ),

            child: Row(
              mainAxisSize:
                  MainAxisSize.min,

              children: [
                Icon(
                  statusIcon,
                  size: 14,
                  color:
                      statusColor,
                ),

                const SizedBox(
                  width: 5,
                ),

                Text(
                  statusText,
                  style:
                      TextStyle(
                    color:
                        statusColor,
                    fontSize: 9,
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
    )
        .animate()
        .fadeIn(
          delay: Duration(
            milliseconds:
                index * 30,
          ),
        )
        .slideX(
          begin: 0.03,
          end: 0,
        );
  }

  // ============================================================
  // INDIVIDUAL DETAILS
  // ============================================================

  void _showIndividualHistoryDetails(
    Map<String, dynamic> item,
  ) {
    final earning =
        _toDouble(
      item["earning"],
    );

    final completedAt =
        _getHistoryDate(item);

    final paymentStatus =
        item["paymentStatus"]
                ?.toString() ??
            "pending";

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor:
          Colors.transparent,

      builder: (context) {
        return Container(
          constraints:
              BoxConstraints(
            maxHeight:
                MediaQuery.of(
                  context,
                ).size.height *
                0.82,
          ),

          decoration:
              const BoxDecoration(
            color: Colors.white,
            borderRadius:
                BorderRadius.vertical(
              top: Radius.circular(
                28,
              ),
            ),
          ),

          child:
              SingleChildScrollView(
            padding:
                const EdgeInsets.fromLTRB(
              22,
              14,
              22,
              30,
            ),

            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,

              children: [
                Center(
                  child: Container(
                    width: 45,
                    height: 5,

                    decoration:
                        BoxDecoration(
                      color:
                          Colors.grey.shade300,
                      borderRadius:
                          BorderRadius.circular(
                        20,
                      ),
                    ),
                  ),
                ),

                const SizedBox(
                  height: 22,
                ),

                Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,

                      decoration:
                          BoxDecoration(
                        color:
                            const Color(
                          0xffEFF6FF,
                        ),
                        borderRadius:
                            BorderRadius.circular(
                          15,
                        ),
                      ),

                      child: Icon(
                        _serviceIcon(
                          item["serviceName"]
                                  ?.toString() ??
                              "",
                        ),
                        color:
                            const Color(
                          0xff2563EB,
                        ),
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
                          Text(
                            item["serviceName"]
                                    ?.toString() ??
                                "Service",

                            style:
                                const TextStyle(
                              fontSize: 20,
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
                            height: 4,
                          ),

                          const Text(
                            "Individual Service",
                            style:
                                TextStyle(
                              color:
                                  Color(
                                0xff64748B,
                              ),
                              fontSize: 11,
                              fontWeight:
                                  FontWeight
                                      .w600,
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

                _detailSection(
                  "Service Information",
                  [
                    _detailRow(
                      Icons
                          .location_on_rounded,
                      "Location",
                      item["location"]
                              ?.toString() ??
                          "N/A",
                    ),

                    _detailRow(
                      Icons
                          .person_rounded,
                      "Customer ID",
                      item["customerId"]
                              ?.toString() ??
                          "N/A",
                    ),

                    _detailRow(
                      Icons
                          .currency_rupee_rounded,
                      "Customer Paid",
                      "₹${_toDouble(item["paymentAmount"]).toStringAsFixed(0)}",
                    ),

                    _detailRow(
                      Icons
                          .work_rounded,
                      "Worker Charge",
                      "₹${_toDouble(item["workerServiceCharge"]).toStringAsFixed(0)}",
                    ),

                    _detailRow(
                      Icons
                          .priority_high_rounded,
                      "Priority",
                      item["urgency"]
                              ?.toString() ??
                          "normal",
                    ),
                  ],
                ),

                const SizedBox(
                  height: 20,
                ),

                _detailSection(
                  "Completion",
                  [
                    _detailRow(
                      Icons
                          .check_circle_rounded,
                      "Status",
                      "Completed",
                    ),

                    _detailRow(
                      Icons
                          .calendar_month_rounded,
                      "Completed At",
                      _formatDateTime(
                        completedAt,
                      ),
                    ),
                  ],
                ),

                const SizedBox(
                  height: 20,
                ),

                _detailSection(
                  "Payment",
                  [
                    _detailRow(
                      Icons
                          .account_balance_wallet_rounded,
                      "Payment Status",
                      paymentStatus
                          .toUpperCase(),
                    ),

                    if ((item["paymentId"]
                                ?.toString() ??
                            "")
                        .isNotEmpty)
                      _detailRow(
                        Icons
                            .receipt_long_rounded,
                        "Payment ID",
                        item["paymentId"]
                            .toString(),
                      ),

                    if ((item["paymentOrderId"]
                                ?.toString() ??
                            "")
                        .isNotEmpty)
                      _detailRow(
                        Icons
                            .confirmation_number_rounded,
                        "Order ID",
                        item["paymentOrderId"]
                            .toString(),
                      ),
                  ],
                ),

                const SizedBox(
                  height: 20,
                ),

                Container(
                  width:
                      double.infinity,

                  padding:
                      const EdgeInsets.all(
                    18,
                  ),

                  decoration:
                      BoxDecoration(
                    color:
                        const Color(
                      0xffF0FDF4,
                    ),

                    borderRadius:
                        BorderRadius.circular(
                      18,
                    ),

                    border:
                        Border.all(
                      color:
                          const Color(
                        0xffBBF7D0,
                      ),
                    ),
                  ),

                  child: Row(
                    children: [
                      const Icon(
                        Icons
                            .account_balance_wallet_rounded,
                        color:
                            Color(
                          0xff16A34A,
                        ),
                      ),

                      const SizedBox(
                        width: 12,
                      ),

                      const Expanded(
                        child: Text(
                          "Your Earnings",
                          style:
                              TextStyle(
                            color:
                                Color(
                              0xff166534,
                            ),
                            fontSize: 13,
                            fontWeight:
                                FontWeight
                                    .w700,
                          ),
                        ),
                      ),

                      Text(
                        "₹${earning.toStringAsFixed(0)}",

                        style:
                            const TextStyle(
                          color:
                              Color(
                            0xff15803D,
                          ),
                          fontSize: 21,
                          fontWeight:
                              FontWeight
                                  .w900,
                        ),
                      ),
                    ],
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
  // DETAIL SECTION
  // ============================================================

  Widget _detailSection(
    String title,
    List<Widget> children,
  ) {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,

      children: [
        Text(
          title,
          style:
              const TextStyle(
            fontSize: 14,
            fontWeight:
                FontWeight.w800,
            color:
                Color(
              0xff0F172A,
            ),
          ),
        ),

        const SizedBox(
          height: 10,
        ),

        Container(
          width: double.infinity,

          padding:
              const EdgeInsets.symmetric(
            horizontal: 15,
            vertical: 5,
          ),

          decoration:
              BoxDecoration(
            color:
                const Color(
              0xffF8FAFC,
            ),
            borderRadius:
                BorderRadius.circular(
              16,
            ),
          ),

          child: Column(
            children: children,
          ),
        ),
      ],
    );
  }

  Widget _detailRow(
    IconData icon,
    String title,
    String value,
  ) {
    return Padding(
      padding:
          const EdgeInsets.symmetric(
        vertical: 10,
      ),

      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,

        children: [
          Icon(
            icon,
            size: 18,
            color:
                const Color(
              0xff64748B,
            ),
          ),

          const SizedBox(
            width: 10,
          ),

          SizedBox(
            width: 100,

            child: Text(
              title,
              style:
                  const TextStyle(
                color:
                    Color(
                  0xff64748B,
                ),
                fontSize: 11,
                fontWeight:
                    FontWeight.w600,
              ),
            ),
          ),

          const SizedBox(
            width: 8,
          ),

          Expanded(
            child: Text(
              value,
              textAlign:
                  TextAlign.right,

              style:
                  const TextStyle(
                color:
                    Color(
                  0xff0F172A,
                ),
                fontSize: 11,
                fontWeight:
                    FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // PROGRESS MINI STAT
  // ============================================================

  Widget _progressMiniStat(
    IconData icon,
    String value,
    String label,
    Color color,
  ) {
    return Column(
      children: [
        Icon(
          icon,
          size: 18,
          color: color,
        ),

        const SizedBox(
          height: 4,
        ),

        Text(
          value,
          style:
              const TextStyle(
            fontSize: 13,
            fontWeight:
                FontWeight.w900,
            color:
                Color(
              0xff0F172A,
            ),
          ),
        ),

        Text(
          label,
          style:
              const TextStyle(
            fontSize: 8,
            color:
                Color(
              0xff64748B,
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // DETAILS NOT FOUND
  // ============================================================

  Widget _buildDetailsNotFound() {
    return const Center(
      child: Padding(
        padding:
            EdgeInsets.all(40),

        child: Column(
          mainAxisSize:
              MainAxisSize.min,

          children: [
            Icon(
              Icons
                  .error_outline_rounded,
              size: 45,
              color:
                  Color(
                0xff94A3B8,
              ),
            ),

            SizedBox(
              height: 12,
            ),

            Text(
              "Batch details not found",
              style:
                  TextStyle(
                fontSize: 15,
                fontWeight:
                    FontWeight.w800,
                color:
                    Color(
                  0xff0F172A,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // FIND VENDOR BID
  // ============================================================

  Map<String, dynamic>? _findVendorBid(
    dynamic rawBids,
    String? vendorId,
  ) {
    if (rawBids is! Map ||
        vendorId == null ||
        vendorId.isEmpty) {
      return null;
    }

    final bids =
        Map<dynamic, dynamic>.from(
      rawBids,
    );

    Map<String, dynamic>? result;

    bids.forEach(
      (bidVendorId, rawBid) {
        if (rawBid is! Map) {
          return;
        }

        final bid =
            Map<String, dynamic>.from(
          rawBid,
        );

        final bidVendor =
            bid["vendorId"]?.toString() ??
                bidVendorId.toString();

        if (bidVendor == vendorId) {
          result = bid;
        }
      },
    );

    return result;
  }

  // ============================================================
  // PARTICIPANT STATUS
  // ============================================================

  bool _isParticipantCompleted(
    Map<String, dynamic> participant,
  ) {
    return participant["completed"] ==
            true ||
        participant["completionStatus"]
                ?.toString()
                .toLowerCase() ==
            "completed" ||
        participant["workStatus"]
                ?.toString()
                .toLowerCase() ==
            "completed";
  }

  bool _isParticipantStarted(
    Map<String, dynamic> participant,
  ) {
    return participant["workStarted"] ==
            true ||
        participant["workVerified"] ==
            true ||
        participant["workStatus"]
                ?.toString()
                .toLowerCase() ==
            "started" ||
        participant["workStatus"]
                ?.toString()
                .toLowerCase() ==
            "in_progress";
  }

  // ============================================================
  // ICON
  // ============================================================

  IconData _serviceIcon(
    String serviceName,
  ) {
    final name =
        serviceName.toLowerCase();

    if (name.contains("electric")) {
      return Icons
          .electrical_services_rounded;
    }

    if (name.contains("clean")) {
      return Icons
          .cleaning_services_rounded;
    }

    if (name.contains("plumb")) {
      return Icons
          .plumbing_rounded;
    }

    if (name.contains("paint")) {
      return Icons
          .format_paint_rounded;
    }

    if (name.contains("garden")) {
      return Icons.yard_rounded;
    }

    if (name.contains("repair")) {
      return Icons.build_rounded;
    }

    if (name.contains("ac")) {
      return Icons.ac_unit_rounded;
    }

    return Icons
        .handyman_rounded;
  }

  // ============================================================
  // HELPERS
  // ============================================================

  double _toDouble(
    dynamic value,
  ) {
    if (value == null) {
      return 0.0;
    }

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(
          value.toString(),
        ) ??
        0.0;
  }

  int _toInt(
    dynamic value,
  ) {
    if (value == null) {
      return 0;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(
          value.toString(),
        ) ??
        0;
  }

  DateTime _parseDate(
    dynamic value,
  ) {
    if (value == null) {
      return DateTime(2000);
    }

    if (value is int) {
      return DateTime
          .fromMillisecondsSinceEpoch(
        value,
      );
    }

    if (value is double) {
      return DateTime
          .fromMillisecondsSinceEpoch(
        value.toInt(),
      );
    }

    final stringValue =
        value.toString();

    final parsed =
        DateTime.tryParse(
      stringValue,
    );

    if (parsed != null) {
      return parsed;
    }

    final number =
        int.tryParse(
      stringValue,
    );

    if (number != null) {
      return DateTime
          .fromMillisecondsSinceEpoch(
        number,
      );
    }

    return DateTime(2000);
  }

  // ============================================================
  // GET HISTORY DATE
  // ============================================================

  DateTime _getHistoryDate(
    Map<String, dynamic> item,
  ) {
    /*
     * For completed individual jobs:
     * completedAt is preferred.
     *
     * For society batches that are still in progress:
     * completedAt may not exist, so use updatedAt,
     * then createdAt.
     */

    final completedAt =
        _parseDate(
      item["completedAt"],
    );

    if (completedAt.year !=
        2000) {
      return completedAt;
    }

    final updatedAt =
        _parseDate(
      item["updatedAt"],
    );

    if (updatedAt.year !=
        2000) {
      return updatedAt;
    }

    return _parseDate(
      item["createdAt"],
    );
  }

  // ============================================================
  // DATE FORMAT
  // ============================================================

  String _formatDate(
    DateTime date,
  ) {
    if (date.year == 2000) {
      return "Date unavailable";
    }

    final day =
        date.day
            .toString()
            .padLeft(
              2,
              "0",
            );

    final month =
        date.month
            .toString()
            .padLeft(
              2,
              "0",
            );

    return "$day/$month/${date.year}";
  }

  String _formatDateTime(
    DateTime date,
  ) {
    if (date.year == 2000) {
      return "Date unavailable";
    }

    final day =
        date.day
            .toString()
            .padLeft(
              2,
              "0",
            );

    final month =
        date.month
            .toString()
            .padLeft(
              2,
              "0",
            );

    final hour =
        date.hour == 0
            ? 12
            : date.hour > 12
                ? date.hour - 12
                : date.hour;

    final minute =
        date.minute
            .toString()
            .padLeft(
              2,
              "0",
            );

    final period =
        date.hour >= 12
            ? "PM"
            : "AM";

    return "$day/$month/${date.year} • "
        "$hour:$minute $period";
  }

  // ============================================================
  // PAYMENT
  // ============================================================

  bool _isPaid(
    String status,
  ) {
    final value =
        status.toLowerCase();

    return value == "paid" ||
        value == "success" ||
        value == "successful" ||
        value == "completed";
  }
}
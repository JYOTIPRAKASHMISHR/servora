import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'package:servora/models/service_model.dart';
import 'package:servora/screens/workers/apply_job_screen.dart';

class JobDetailsScreen extends StatefulWidget {
  final ServiceModel job;

  const JobDetailsScreen({
    super.key,
    required this.job,
  });

  @override
  State<JobDetailsScreen> createState() =>
      _JobDetailsScreenState();
}

class _JobDetailsScreenState
    extends State<JobDetailsScreen> {
  // ============================================================
  // COLORS
  // ============================================================

  static const Color primaryBlue =
      Color(0xff2563EB);

  static const Color darkBlue =
      Color(0xff1D4ED8);

  static const Color skyBlue =
      Color(0xff38BDF8);

  static const Color background =
      Color(0xffF4F7FC);


   String get jobUrgency {
    return widget.job.urgency
        .trim()
        .toLowerCase();
  }

  bool get isUrgentOrEmergency {
    return jobUrgency == "urgent" ||
        jobUrgency == "emergency";
  }

  bool get isEmergency {
    return jobUrgency == "emergency";
  }
    

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,

      body: CustomScrollView(
        physics:
            const BouncingScrollPhysics(),
        slivers: [
          _buildAppBar(),

          SliverToBoxAdapter(
            child: Padding(
              padding:
                  const EdgeInsets.fromLTRB(
                16,
                16,
                16,
                120,
              ),
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  _serviceHeader(),

                  const SizedBox(height: 16),

                  _buildQuickStats(),

                  const SizedBox(height: 16),

                  _sectionCard(
                    title:
                        "Customer Requirement",
                    subtitle:
                        "What the customer needs",
                    icon:
                        Icons.description_rounded,
                    child:
                        _buildRequirementContent(),
                  ),

                  const SizedBox(height: 16),

                  _buildLocationCard(),

                  const SizedBox(height: 16),

                  _buildPricingSection(),

                  const SizedBox(height: 16),

                  _buildScheduleCard(),

                  const SizedBox(height: 16),

                  _trustCard(),

                  const SizedBox(height: 20),

                  _buildBottomInformation(),
                ],
              ),
            ),
          ),
        ],
      ),

      bottomSheet:
          _applyButton(),
    );
  }

  // ============================================================
  // PREMIUM APP BAR
  // ============================================================

  Widget _buildAppBar() {
    return SliverAppBar(
      expandedHeight: 225,
      pinned: true,
      elevation: 0,
      backgroundColor: primaryBlue,

      leading: Padding(
        padding:
            const EdgeInsets.only(
          left: 10,
        ),
        child: _circleButton(
          icon:
              Icons.arrow_back_rounded,
          onTap: () {
            Navigator.pop(context);
          },
        ),
      ),

      actions: [
        Padding(
          padding:
              const EdgeInsets.only(
            right: 12,
          ),
          child: _circleButton(
            icon:
                Icons.more_horiz_rounded,
            onTap: () {},
          ),
        ),
      ],

      flexibleSpace:
          FlexibleSpaceBar(
        collapseMode:
            CollapseMode.parallax,

        titlePadding:
            const EdgeInsets.only(
          left: 62,
          bottom: 16,
          right: 60,
        ),

        title: Text(
          widget.job.serviceName.isEmpty
              ? "Service Details"
              : widget.job.serviceName,
          maxLines: 1,
          overflow:
              TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight:
                FontWeight.w800,
            letterSpacing: -0.3,
          ),
        ),

        background:
            _buildHeroBackground(),
      ),
    );
  }

  // ============================================================
  // HERO BACKGROUND
  // ============================================================

  Widget _buildHeroBackground() {
    return Stack(
      fit: StackFit.expand,
      children: [
        Container(
          decoration:
              const BoxDecoration(
            gradient:
                LinearGradient(
              begin:
                  Alignment.topLeft,
              end:
                  Alignment.bottomRight,
              colors: [
                Color(0xff2563EB),
                Color(0xff1D4ED8),
                Color(0xff0F3FAE),
              ],
            ),
          ),
        ),

        // Decorative circles
        Positioned(
          top: -70,
          right: -45,
          child: Container(
            height: 190,
            width: 190,
            decoration:
                BoxDecoration(
              color: Colors.white
                  .withOpacity(0.08),
              shape: BoxShape.circle,
            ),
          ),
        ),

        Positioned(
          top: 55,
          right: 40,
          child: Container(
            height: 90,
            width: 90,
            decoration:
                BoxDecoration(
              color: Colors.white
                  .withOpacity(0.07),
              shape: BoxShape.circle,
            ),
          ),
        ),

        Positioned(
          bottom: -80,
          left: -50,
          child: Container(
            height: 190,
            width: 190,
            decoration:
                BoxDecoration(
              color: skyBlue
                  .withOpacity(0.12),
              shape: BoxShape.circle,
            ),
          ),
        ),

        // Hero content
        Positioned(
          left: 24,
          right: 24,
          bottom: 70,
          child: Row(
            children: [
              _buildHeroIcon(),

              const SizedBox(width: 16),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.job.serviceName
                              .isEmpty
                          ? "Service Request"
                          : widget.job.serviceName,
                      maxLines: 2,
                      overflow:
                          TextOverflow.ellipsis,
                      style:
                          const TextStyle(
                        color: Colors.white,
                        fontSize: 25,
                        fontWeight:
                            FontWeight.w900,
                        height: 1.05,
                        letterSpacing: -0.7,
                      ),
                    ),

                    const SizedBox(height: 7),

                    Row(
                      children: [
                        const Icon(
                          Icons
                              .verified_rounded,
                          color:
                              Colors.white70,
                          size: 16,
                        ),
                        const SizedBox(
                            width: 5),
                        Text(
                          widget.job.categoryType
                                  .isEmpty
                              ? "Professional Service"
                              : widget.job.categoryType,
                          style:
                              const TextStyle(
                            color:
                                Colors.white70,
                            fontSize: 12,
                            fontWeight:
                                FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    )
        .animate()
        .fadeIn(
          duration: 600.ms,
        );
  }

  // ============================================================
  // HERO ICON
  // ============================================================

  Widget _buildHeroIcon() {
    return Container(
      height: 76,
      width: 76,
      decoration:
          BoxDecoration(
        gradient:
            const LinearGradient(
          begin:
              Alignment.topLeft,
          end:
              Alignment.bottomRight,
          colors: [
            Colors.white,
            Color(0xffDBEAFE),
          ],
        ),
        borderRadius:
            BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: Colors.black
                .withOpacity(0.22),
            blurRadius: 22,
            offset:
                const Offset(0, 12),
          ),
        ],
      ),
      child: Icon(
        _serviceIcon(
          widget.job.serviceName,
        ),
        color: primaryBlue,
        size: 38,
      ),
    )
        .animate(
          onPlay: (controller) =>
              controller.repeat(
            reverse: true,
          ),
        )
        .moveY(
          begin: 0,
          end: -5,
          duration: 1800.ms,
          curve:
              Curves.easeInOut,
        );
  }

  // ============================================================
  // CIRCLE BUTTON
  // ============================================================

  Widget _circleButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Material(
      color:
          Colors.black.withOpacity(
        0.16,
      ),
      shape:
          const CircleBorder(),
      child: InkWell(
        customBorder:
            const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          height: 42,
          width: 42,
          child: Icon(
            icon,
            color: Colors.white,
            size: 22,
          ),
        ),
      ),
    );
  }

  // ============================================================
  // SERVICE HEADER
  // ============================================================

  Widget _serviceHeader() {
    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.all(18),
      decoration:
          BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: Colors.black
                .withOpacity(0.055),
            blurRadius: 25,
            offset:
                const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _buildServiceIconBox(),

              const SizedBox(width: 14),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.job.serviceName
                              .isEmpty
                          ? "Service Request"
                          : widget.job.serviceName,
                      maxLines: 2,
                      overflow:
                          TextOverflow.ellipsis,
                      style:
                          const TextStyle(
                        fontSize: 20,
                        fontWeight:
                            FontWeight.w800,
                        color:
                            Color(0xff111827),
                      ),
                    ),

                    const SizedBox(height: 5),

                    Text(
                      widget.job.categoryType
                              .isEmpty
                          ? "Professional Service"
                          : widget.job.categoryType,
                      style:
                          const TextStyle(
                        color:
                            Color(0xff64748B),
                        fontSize: 13,
                        fontWeight:
                            FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),

              _buildStatusBadge(),
            ],
          ),

          const SizedBox(height: 17),

          Container(
            height: 1,
            color:
                const Color(0xffEEF2F7),
          ),

          const SizedBox(height: 15),

          Row(
            children: [
              const Icon(
                Icons.access_time_rounded,
                size: 17,
                color:
                    Color(0xff64748B),
              ),

              const SizedBox(width: 7),

              const Text(
                "New customer request",
                style:
                    TextStyle(
                  color:
                      Color(0xff64748B),
                  fontSize: 12,
                  fontWeight:
                      FontWeight.w600,
                ),
              ),

              const Spacer(),

              Container(
                padding:
                    const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration:
                    BoxDecoration(
                  color:
                      const Color(0xffECFDF5),
                  borderRadius:
                      BorderRadius.circular(
                    20,
                  ),
                ),
                child:
                    const Text(
                  "OPEN",
                  style:
                      TextStyle(
                    color:
                        Color(0xff15803D),
                    fontSize: 9,
                    fontWeight:
                        FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    )
        .animate()
        .fadeIn(
          duration: 500.ms,
        )
        .slideY(
          begin: 0.08,
          end: 0,
          duration: 550.ms,
          curve:
              Curves.easeOutCubic,
        );
  }

  // ============================================================
  // SERVICE ICON BOX
  // ============================================================

  Widget _buildServiceIconBox() {
    return Container(
      height: 62,
      width: 62,
      decoration:
          BoxDecoration(
        gradient:
            const LinearGradient(
          begin:
              Alignment.topLeft,
          end:
              Alignment.bottomRight,
          colors: [
            Color(0xff3B82F6),
            Color(0xff1D4ED8),
          ],
        ),
        borderRadius:
            BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: primaryBlue
                .withOpacity(0.25),
            blurRadius: 15,
            offset:
                const Offset(0, 8),
          ),
        ],
      ),
      child: Icon(
        _serviceIcon(
          widget.job.serviceName,
        ),
        color: Colors.white,
        size: 30,
      ),
    );
  }

  // ============================================================
  // STATUS BADGE
  // ============================================================

   // ============================================================
  // STATUS / URGENCY BADGE
  // ============================================================

  Widget _buildStatusBadge() {
    if (isEmergency) {
      return Container(
        padding:
            const EdgeInsets.symmetric(
          horizontal: 9,
          vertical: 7,
        ),
        decoration: BoxDecoration(
          gradient:
              const LinearGradient(
            colors: [
              Color(0xffDC2626),
              Color(0xff991B1B),
            ],
          ),
          borderRadius:
              BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: Colors.red
                  .withOpacity(0.18),
              blurRadius: 8,
              offset:
                  const Offset(0, 3),
            ),
          ],
        ),
        child: const Row(
          mainAxisSize:
              MainAxisSize.min,
          children: [
            Icon(
              Icons.warning_rounded,
              color: Colors.white,
              size: 12,
            ),
            SizedBox(width: 4),
            Text(
              "EMERGENCY",
              style: TextStyle(
                color: Colors.white,
                fontSize: 8,
                fontWeight:
                    FontWeight.w900,
              ),
            ),
          ],
        ),
      );
    }

    if (jobUrgency == "urgent") {
      return Container(
        padding:
            const EdgeInsets.symmetric(
          horizontal: 9,
          vertical: 7,
        ),
        decoration: BoxDecoration(
          gradient:
              const LinearGradient(
            colors: [
              Color(0xffF97316),
              Color(0xffEA580C),
            ],
          ),
          borderRadius:
              BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: Colors.orange
                  .withOpacity(0.18),
              blurRadius: 8,
              offset:
                  const Offset(0, 3),
            ),
          ],
        ),
        child: const Row(
          mainAxisSize:
              MainAxisSize.min,
          children: [
            Icon(
              Icons.priority_high_rounded,
              color: Colors.white,
              size: 12,
            ),
            SizedBox(width: 4),
            Text(
              "URGENT",
              style: TextStyle(
                color: Colors.white,
                fontSize: 9,
                fontWeight:
                    FontWeight.w900,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 7,
      ),
      decoration: BoxDecoration(
        color:
            const Color(0xffECFDF5),
        borderRadius:
            BorderRadius.circular(30),
        border: Border.all(
          color:
              const Color(0xffBBF7D0),
        ),
      ),
      child: const Row(
        mainAxisSize:
            MainAxisSize.min,
        children: [
          Icon(
            Icons.circle,
            color:
                Color(0xff16A34A),
            size: 8,
          ),
          SizedBox(width: 5),
          Text(
            "NEW",
            style: TextStyle(
              color:
                  Color(0xff15803D),
              fontSize: 9,
              fontWeight:
                  FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

    // ============================================================
  // URGENCY INFORMATION CARD
  // ============================================================

  Widget _buildUrgencyCard() {
    final bool emergency = isEmergency;

    final Color mainColor = emergency
        ? const Color(0xffDC2626)
        : const Color(0xffEA580C);

    final Color lightColor = emergency
        ? const Color(0xffFEF2F2)
        : const Color(0xffFFF7ED);

    final String title = emergency
        ? "Emergency Service Request"
        : "Urgent Service Request";

    final String message = emergency
        ? "This customer needs emergency service. "
          "Enter the amount you are willing to complete "
          "this service for before applying."
        : "This is an urgent service request. "
          "Enter your service price before applying.";

    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: lightColor,
        borderRadius:
            BorderRadius.circular(22),
        border: Border.all(
          color:
              mainColor.withOpacity(0.20),
        ),
        boxShadow: [
          BoxShadow(
            color:
                mainColor.withOpacity(0.07),
            blurRadius: 18,
            offset:
                const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Container(
            height: 46,
            width: 46,
            decoration: BoxDecoration(
              color:
                  mainColor.withOpacity(0.12),
              borderRadius:
                  BorderRadius.circular(14),
            ),
            child: Icon(
              emergency
                  ? Icons.warning_rounded
                  : Icons.priority_high_rounded,
              color: mainColor,
              size: 25,
            ),
          ),

          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: mainColor,
                    fontSize: 15,
                    fontWeight:
                        FontWeight.w800,
                  ),
                ),

                const SizedBox(height: 5),

                Text(
                  message,
                  style: const TextStyle(
                    color:
                        Color(0xff475569),
                    fontSize: 12,
                    height: 1.45,
                    fontWeight:
                        FontWeight.w500,
                  ),
                ),

                const SizedBox(height: 10),

                Row(
                  children: [
                    Icon(
                      Icons.currency_rupee_rounded,
                      color: mainColor,
                      size: 15,
                    ),

                    const SizedBox(width: 5),

                    Text(
                      "Your bid is required",
                      style: TextStyle(
                        color: mainColor,
                        fontSize: 11,
                        fontWeight:
                            FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    )
        .animate()
        .fadeIn(
          delay: 150.ms,
          duration: 450.ms,
        )
        .slideY(
          begin: 0.06,
          end: 0,
          delay: 150.ms,
          duration: 500.ms,
        );
  }
  // ============================================================
  // QUICK STATS
  // ============================================================

  Widget _buildQuickStats() {
    return Row(
      children: [
        Expanded(
          child: _quickStat(
            icon:
                Icons.currency_rupee_rounded,
            title: "Budget",
            value:
                "₹${widget.job.budget.isEmpty ? "0" : widget.job.budget}",
            highlighted: true,
          ),
        ),

        const SizedBox(width: 10),

        Expanded(
          child: _quickStat(
            icon:
                Icons.calendar_today_rounded,
            title: "Service Date",
            value:
                widget.job.date.isEmpty
                    ? "Not set"
                    : widget.job.date,
          ),
        ),

        const SizedBox(width: 10),

        Expanded(
          child: _quickStat(
            icon:
                Icons.location_on_rounded,
            title: "Location",
            value: "Provided",
          ),
        ),
      ],
    )
        .animate()
        .fadeIn(
          delay: 150.ms,
          duration: 450.ms,
        )
        .slideY(
          begin: 0.08,
          end: 0,
          delay: 150.ms,
          duration: 500.ms,
        );
  }

  Widget _quickStat({
    required IconData icon,
    required String title,
    required String value,
    bool highlighted = false,
  }) {
    return Container(
      padding:
          const EdgeInsets.all(12),
      decoration:
          BoxDecoration(
        color: highlighted
            ? const Color(0xffEFF6FF)
            : Colors.white,
        borderRadius:
            BorderRadius.circular(19),
        border: Border.all(
          color: highlighted
              ? const Color(0xffD6E6FF)
              : const Color(0xffE8EEF7),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black
                .withOpacity(0.035),
            blurRadius: 12,
            offset:
                const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Container(
            height: 32,
            width: 32,
            decoration:
                BoxDecoration(
              gradient: highlighted
                  ? const LinearGradient(
                      colors: [
                        Color(0xff3B82F6),
                        Color(0xff2563EB),
                      ],
                    )
                  : null,
              color: highlighted
                  ? null
                  : const Color(0xffEFF6FF),
              borderRadius:
                  BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              size: 16,
              color: highlighted
                  ? Colors.white
                  : primaryBlue,
            ),
          ),

          const SizedBox(height: 9),

          Text(
            title,
            maxLines: 1,
            overflow:
                TextOverflow.ellipsis,
            style:
                const TextStyle(
              color:
                  Color(0xff94A3B8),
              fontSize: 9,
              fontWeight:
                  FontWeight.w700,
            ),
          ),

          const SizedBox(height: 3),

          Text(
            value,
            maxLines: 2,
            overflow:
                TextOverflow.ellipsis,
            style: TextStyle(
              color: highlighted
                  ? darkBlue
                  : const Color(
                      0xff334155),
              fontSize:
                  highlighted ? 14 : 11,
              fontWeight:
                  FontWeight.w800,
              height: 1.15,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // REQUIREMENT SECTION
  // ============================================================

  Widget _buildRequirementContent() {
    final String description =
        widget.job.description.isEmpty
            ? "No description provided by the customer."
            : widget.job.description;

    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.all(16),
      decoration:
          BoxDecoration(
        color:
            const Color(0xffF8FAFC),
        borderRadius:
            BorderRadius.circular(18),
        border: Border.all(
          color:
              const Color(0xffE7EDF5),
        ),
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Container(
            height: 38,
            width: 38,
            decoration:
                BoxDecoration(
              color:
                  const Color(0xffE0ECFF),
              borderRadius:
                  BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.notes_rounded,
              color: primaryBlue,
              size: 20,
            ),
          ),

          const SizedBox(width: 12),

          Expanded(
            child: Text(
              description,
              style:
                  const TextStyle(
                color:
                    Color(0xff334155),
                fontSize: 14,
                height: 1.55,
                fontWeight:
                    FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // LOCATION CARD
  // ============================================================

  Widget _buildLocationCard() {
    return _sectionCard(
      title: "Service Location",
      subtitle:
          "Customer service address",
      icon:
          Icons.location_on_rounded,
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding:
                const EdgeInsets.all(14),
            decoration:
                BoxDecoration(
              color:
                  const Color(0xffF8FAFC),
              borderRadius:
                  BorderRadius.circular(17),
              border: Border.all(
                color:
                    const Color(0xffE7EDF5),
              ),
            ),
            child: Row(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Container(
                  height: 38,
                  width: 38,
                  decoration:
                      BoxDecoration(
                    color:
                        const Color(0xffE0ECFF),
                    borderRadius:
                        BorderRadius.circular(
                      12,
                    ),
                  ),
                  child: const Icon(
                    Icons.place_rounded,
                    color:
                        primaryBlue,
                    size: 20,
                  ),
                ),

                const SizedBox(
                    width: 11),

                Expanded(
                  child: Text(
                    widget.job.location
                            .isEmpty
                        ? "Location not available"
                        : widget.job.location,
                    style:
                        const TextStyle(
                      color:
                          Color(0xff334155),
                      fontSize: 14,
                      height: 1.4,
                      fontWeight:
                          FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          Container(
            height: 145,
            width: double.infinity,
            decoration:
                BoxDecoration(
              borderRadius:
                  BorderRadius.circular(20),
              gradient:
                  const LinearGradient(
                begin:
                    Alignment.topLeft,
                end:
                    Alignment.bottomRight,
                colors: [
                  Color(0xffE0ECFF),
                  Color(0xffEFF6FF),
                ],
              ),
              border: Border.all(
                color:
                    const Color(0xffD7E5FA),
              ),
            ),
            child: Stack(
              alignment:
                  Alignment.center,
              children: [
                Positioned(
                  top: 15,
                  left: 25,
                  child: _mapDot(
                    45,
                  ),
                ),

                Positioned(
                  top: 50,
                  right: 45,
                  child: _mapDot(
                    30,
                  ),
                ),

                Positioned(
                  bottom: 20,
                  left: 80,
                  child: _mapDot(
                    25,
                  ),
                ),

                Container(
                  height: 62,
                  width: 62,
                  decoration:
                      BoxDecoration(
                    gradient:
                        const LinearGradient(
                      colors: [
                        Color(0xff3B82F6),
                        Color(0xff1D4ED8),
                      ],
                    ),
                    shape:
                        BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: primaryBlue
                            .withOpacity(
                          0.30,
                        ),
                        blurRadius: 20,
                        offset:
                            const Offset(
                          0,
                          8,
                        ),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.location_on_rounded,
                    color: Colors.white,
                    size: 30,
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
          delay: 250.ms,
          duration: 500.ms,
        )
        .slideY(
          begin: 0.06,
          end: 0,
          delay: 250.ms,
          duration: 500.ms,
        );
  }

  // ============================================================
  // MAP DOT
  // ============================================================

  Widget _mapDot(
    double size,
  ) {
    return Container(
      height: size,
      width: size,
      decoration:
          BoxDecoration(
        color:
            primaryBlue.withOpacity(
          0.08,
        ),
        shape: BoxShape.circle,
        border: Border.all(
          color:
              primaryBlue.withOpacity(
            0.10,
          ),
        ),
      ),
    );
  }

  // ============================================================
  // PRICING SECTION
  // ============================================================

    // ============================================================
  // PRICING SECTION
  // ============================================================

  Widget _buildPricingSection() {
    final bool biddingRequired =
        isUrgentOrEmergency;

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
            Color(0xff1D4ED8),
            Color(0xff2563EB),
            Color(0xff38BDF8),
          ],
        ),
        borderRadius:
            BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: primaryBlue
                .withOpacity(0.22),
            blurRadius: 22,
            offset:
                const Offset(0, 11),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            height: 58,
            width: 58,
            decoration:
                BoxDecoration(
              color: Colors.white
                  .withOpacity(0.14),
              borderRadius:
                  BorderRadius.circular(18),
              border: Border.all(
                color: Colors.white
                    .withOpacity(0.18),
              ),
            ),
            child: Icon(
              biddingRequired
                  ? Icons.gavel_rounded
                  : Icons.currency_rupee_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),

          const SizedBox(width: 14),

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  biddingRequired
                      ? "CUSTOMER BUDGET • YOUR BID REQUIRED"
                      : "CUSTOMER BUDGET",
                  style:
                      const TextStyle(
                    color:
                        Colors.white70,
                    fontSize: 9,
                    fontWeight:
                        FontWeight.w800,
                    letterSpacing: 0.7,
                  ),
                ),

                const SizedBox(height: 4),

                Text(
                  "₹${widget.job.budget.isEmpty ? "0" : widget.job.budget}",
                  style:
                      const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight:
                        FontWeight.w900,
                    letterSpacing: -0.7,
                  ),
                ),

                if (biddingRequired) ...[
                  const SizedBox(height: 4),

                  const Text(
                    "Enter your price on the next screen",
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 10,
                      fontWeight:
                          FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),

          Container(
            padding:
                const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 7,
            ),
            decoration:
                BoxDecoration(
              color:
                  Colors.white.withOpacity(
                0.14,
              ),
              borderRadius:
                  BorderRadius.circular(30),
            ),
            child: Row(
              mainAxisSize:
                  MainAxisSize.min,
              children: [
                Icon(
                  biddingRequired
                      ? Icons.gavel_rounded
                      : Icons.payments_rounded,
                  color: Colors.white,
                  size: 15,
                ),
                const SizedBox(width: 4),
                Text(
                  biddingRequired
                      ? "BID"
                      : "INR",
                  style:
                      const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight:
                        FontWeight.w900,
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
          delay: 350.ms,
          duration: 500.ms,
        )
        .scale(
          begin:
              const Offset(0.97, 0.97),
          end:
              const Offset(1, 1),
          delay: 350.ms,
          duration: 500.ms,
        );
  }
  // ============================================================
  // SCHEDULE CARD
  // ============================================================

  Widget _buildScheduleCard() {
    return _sectionCard(
      title: "Service Schedule",
      subtitle:
          "Requested service date",
      icon:
          Icons.calendar_month_rounded,
      child: Row(
        children: [
          Container(
            height: 58,
            width: 58,
            decoration:
                BoxDecoration(
              color:
                  const Color(0xffEFF6FF),
              borderRadius:
                  BorderRadius.circular(17),
            ),
            child: const Icon(
              Icons.event_available_rounded,
              color: primaryBlue,
              size: 28,
            ),
          ),

          const SizedBox(width: 13),

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                const Text(
                  "Requested Date",
                  style:
                      TextStyle(
                    color:
                        Color(0xff94A3B8),
                    fontSize: 10,
                    fontWeight:
                        FontWeight.w700,
                  ),
                ),

                const SizedBox(height: 4),

                Text(
                  widget.job.date.isEmpty
                      ? "Date not specified"
                      : widget.job.date,
                  style:
                      const TextStyle(
                    color:
                        Color(0xff1E293B),
                    fontSize: 16,
                    fontWeight:
                        FontWeight.w800,
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
          delay: 450.ms,
          duration: 500.ms,
        )
        .slideY(
          begin: 0.06,
          end: 0,
          delay: 450.ms,
          duration: 500.ms,
        );
  }

  // ============================================================
  // TRUST CARD
  // ============================================================

  Widget _trustCard() {
    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.all(19),
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
        borderRadius:
            BorderRadius.circular(24),
        border: Border.all(
          color:
              const Color(0xffCFE0FA),
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                height: 43,
                width: 43,
                decoration:
                    BoxDecoration(
                  color: Colors.white
                      .withOpacity(0.75),
                  borderRadius:
                      BorderRadius.circular(
                    14,
                  ),
                ),
                child: const Icon(
                  Icons.shield_rounded,
                  color: primaryBlue,
                  size: 23,
                ),
              ),

              const SizedBox(width: 11),

              const Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Servora Protection",
                      style:
                          TextStyle(
                        color:
                            Color(0xff1E3A8A),
                        fontSize: 17,
                        fontWeight:
                            FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      "Built for a safer service experience",
                      style:
                          TextStyle(
                        color:
                            Color(0xff64748B),
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 17),

          _trustItem(
            Icons.verified_user_rounded,
            "Verified service request",
          ),

          const SizedBox(height: 10),

          _trustItem(
            Icons.payments_rounded,
            "Secure payment process",
          ),

          const SizedBox(height: 10),

          _trustItem(
            Icons.support_agent_rounded,
            "Servora service support",
          ),
        ],
      ),
    )
        .animate()
        .fadeIn(
          delay: 550.ms,
          duration: 500.ms,
        )
        .slideY(
          begin: 0.06,
          end: 0,
          delay: 550.ms,
          duration: 500.ms,
        );
  }

  // ============================================================
  // TRUST ITEM
  // ============================================================

  Widget _trustItem(
    IconData icon,
    String text,
  ) {
    return Row(
      children: [
        Container(
          height: 30,
          width: 30,
          decoration:
              BoxDecoration(
            color:
                Colors.white.withOpacity(
              0.8,
            ),
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            color:
                const Color(0xff2563EB),
            size: 16,
          ),
        ),

        const SizedBox(width: 9),

        Expanded(
          child: Text(
            text,
            style:
                const TextStyle(
              color:
                  Color(0xff334155),
              fontSize: 12,
              fontWeight:
                  FontWeight.w600,
            ),
          ),
        ),

        const Icon(
          Icons.check_circle_rounded,
          color:
              Color(0xff16A34A),
          size: 17,
        ),
      ],
    );
  }

  // ============================================================
  // SECTION CARD
  // ============================================================

  Widget _sectionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.all(18),
      decoration:
          BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black
                .withOpacity(0.045),
            blurRadius: 20,
            offset:
                const Offset(0, 9),
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
                height: 42,
                width: 42,
                decoration:
                    BoxDecoration(
                  color:
                      const Color(0xffEFF6FF),
                  borderRadius:
                      BorderRadius.circular(
                    13,
                  ),
                ),
                child: Icon(
                  icon,
                  color: primaryBlue,
                  size: 21,
                ),
              ),

              const SizedBox(width: 11),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style:
                          const TextStyle(
                        color:
                            Color(0xff111827),
                        fontSize: 17,
                        fontWeight:
                            FontWeight.w800,
                      ),
                    ),

                    const SizedBox(height: 2),

                    Text(
                      subtitle,
                      style:
                          const TextStyle(
                        color:
                            Color(0xff94A3B8),
                        fontSize: 10,
                        fontWeight:
                            FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          child,
        ],
      ),
    );
  }

  // ============================================================
  // BOTTOM INFORMATION
  // ============================================================

  Widget _buildBottomInformation() {
    return Row(
      mainAxisAlignment:
          MainAxisAlignment.center,
      children: [
        const Icon(
          Icons.lock_outline_rounded,
          size: 14,
          color:
              Color(0xff94A3B8),
        ),

        const SizedBox(width: 5),

        Text(
          "Your application is securely processed by Servora",
          textAlign:
              TextAlign.center,
          style:
              const TextStyle(
            color:
                Color(0xff94A3B8),
            fontSize: 10,
            fontWeight:
                FontWeight.w500,
          ),
        ),
      ],
    );
  }

  // ============================================================
  // APPLY BUTTON
  // ============================================================

  Widget _applyButton() {
    return Container(
      padding:
          const EdgeInsets.fromLTRB(
        16,
        12,
        16,
        15,
      ),
      decoration:
          BoxDecoration(
        color: Colors.white,
        borderRadius:
            const BorderRadius.only(
          topLeft:
              Radius.circular(25),
          topRight:
              Radius.circular(25),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black
                .withOpacity(0.12),
            blurRadius: 25,
            offset:
                const Offset(0, -8),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 58,
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder:
                      (context) =>
                          ApplyJobScreen(
                    job: widget.job,
                  ),
                ),
              );
            },
            style:
                ElevatedButton.styleFrom(
              elevation: 7,
              shadowColor:
                  primaryBlue.withOpacity(
                0.35,
              ),
              backgroundColor:
                  primaryBlue,
              foregroundColor:
                  Colors.white,
              shape:
                  RoundedRectangleBorder(
                borderRadius:
                    BorderRadius.circular(
                  18,
                ),
              ),
            ),
          child: Row(
  mainAxisAlignment:
      MainAxisAlignment.center,
  children: [
    Icon(
      isUrgentOrEmergency
          ? Icons.gavel_rounded
          : Icons.send_rounded,
      size: 20,
    ),

    const SizedBox(width: 9),

    Text(
      isEmergency
          ? "Submit Emergency Bid"
          : isUrgentOrEmergency
              ? "Submit Your Bid"
              : "Apply For This Job",
      style: const TextStyle(
        color: Colors.white,
        fontSize: 16,
        fontWeight: FontWeight.w800,
      ),
    ),

    const SizedBox(width: 9),

             

                Container(
                  height: 26,
                  width: 26,
                  decoration:
                      BoxDecoration(
                    color: Colors.white
                        .withOpacity(0.15),
                    shape:
                        BoxShape.circle,
                  ),
                  child:
                      const Icon(
                    Icons.arrow_forward_rounded,
                    size: 15,
                    color:
                        Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    )
        .animate()
        .fadeIn(
          duration: 450.ms,
        )
        .slideY(
          begin: 0.3,
          end: 0,
          duration: 500.ms,
          curve:
              Curves.easeOutCubic,
        );
  }

  // ============================================================
  // SERVICE ICON
  // ============================================================

  IconData _serviceIcon(
    String serviceName,
  ) {
    final String name =
        serviceName.toLowerCase();

    if (name.contains("clean")) {
      return Icons
          .cleaning_services_rounded;
    }

    if (name.contains("electric")) {
      return Icons
          .electrical_services_rounded;
    }

    if (name.contains("plumb")) {
      return Icons.plumbing_rounded;
    }

    if (name.contains("garden")) {
      return Icons.yard_rounded;
    }

    if (name.contains("paint")) {
      return Icons
          .format_paint_rounded;
    }

    if (name.contains("car")) {
      return Icons
          .directions_car_rounded;
    }

    if (name.contains("bike")) {
      return Icons.two_wheeler_rounded;
    }

    if (name.contains("repair")) {
      return Icons
          .build_circle_rounded;
    }

    if (name.contains("appliance")) {
      return Icons
          .home_repair_service_rounded;
    }

    if (name.contains("tutor")) {
      return Icons.school_rounded;
    }

    if (name.contains("baby")) {
      return Icons.child_care_rounded;
    }

    if (name.contains("elder")) {
      return Icons.elderly_rounded;
    }

    if (name.contains("moving")) {
      return Icons
          .local_shipping_rounded;
    }

    if (name.contains("massage")) {
      return Icons.spa_rounded;
    }

    return Icons.handyman_rounded;
  }
}
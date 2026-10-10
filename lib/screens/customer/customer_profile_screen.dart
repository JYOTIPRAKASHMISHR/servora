import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:servora/screens/customer/customer_requests_screen.dart';
import 'package:servora/screens/customer/customer_history_screen.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:servora/screens/customer/customer_account_settings_screen.dart';

import '../login_screen.dart';

class CustomerProfileScreen extends StatefulWidget {
  const CustomerProfileScreen({
    super.key,
  });

  @override
  State<CustomerProfileScreen> createState() =>
      _CustomerProfileScreenState();
}

class _CustomerProfileScreenState extends State<CustomerProfileScreen>
    with SingleTickerProviderStateMixin {
  final FirebaseAuth auth = FirebaseAuth.instance;

  final DatabaseReference userRef =
      FirebaseDatabase.instance.ref("users");

  String name = "";
  String email = "";
  String phone = "";

  bool loading = true;

  late AnimationController _floatingController;

  @override
  void initState() {
    super.initState();

    _floatingController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);

    loadProfile();
  }

  @override
  void dispose() {
    _floatingController.dispose();
    super.dispose();
  }

  // ============================================================
  // LOAD PROFILE
  // ============================================================

  Future<void> loadProfile() async {
    try {
      final User? user = auth.currentUser;

      if (user == null) {
        if (mounted) {
          setState(() {
            loading = false;
          });
        }
        return;
      }

      final DatabaseEvent event = await userRef.child(user.uid).once();

      if (!mounted) return;

      if (event.snapshot.exists && event.snapshot.value is Map) {
        final Map<dynamic, dynamic> data =
            Map<dynamic, dynamic>.from(
          event.snapshot.value as Map,
        );

        setState(() {
          name = data["name"]?.toString().trim().isNotEmpty == true
              ? data["name"].toString()
              : "Customer";

          email = data["email"]?.toString().trim().isNotEmpty == true
              ? data["email"].toString()
              : user.email ?? "";

          phone = data["phone"]?.toString() ?? "";

          loading = false;
        });
      } else {
        setState(() {
          name = "Customer";
          email = user.email ?? "";
          phone = "";
          loading = false;
        });
      }
    } catch (e) {
      debugPrint("Profile loading error: $e");

      if (!mounted) return;

      setState(() {
        name = "Customer";
        email = auth.currentUser?.email ?? "";
        phone = "";
        loading = false;
      });
    }
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

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Logout failed: $e",
          ),
        ),
      );
    }
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffF4F7FC),

      body: loading
          ? _buildLoadingScreen()
          : SafeArea(
              child: Stack(
                children: [
                  _buildBackground(),

                  SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),

                    padding: const EdgeInsets.fromLTRB(
                      18,
                      14,
                      18,
                      35,
                    ),

                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildTopBar(),

                        const SizedBox(height: 18),

                        _buildProfileHero(),

                        const SizedBox(height: 24),

                        _buildSectionTitle(
                          "Personal Information",
                          "Your account details",
                        ),

                        const SizedBox(height: 12),

                        _profileInfoCard(),

                        const SizedBox(height: 24),

                        _buildSectionTitle(
                          "Account",
                          "Manage your Servora account",
                        ),

                        const SizedBox(height: 12),

                        _menuCard(),

                        const SizedBox(height: 24),

                        _logoutButton(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  // ============================================================
  // BACKGROUND
  // ============================================================

  Widget _buildBackground() {
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned(
            top: -100,
            right: -80,
            child: AnimatedBuilder(
              animation: _floatingController,
              builder: (context, child) {
                final double value =
                    _floatingController.value * 20;

                return Transform.translate(
                  offset: Offset(0, value),
                  child: child,
                );
              },

              child: Container(
                height: 240,
                width: 240,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xff38BDF8).withOpacity(.20),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),

          Positioned(
            bottom: 100,
            left: -100,
            child: Container(
              height: 220,
              width: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xff6366F1).withOpacity(.10),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // TOP BAR
  // ============================================================

  Widget _buildTopBar() {
    return Row(
      children: [
        Container(
          height: 48,
          width: 48,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),

            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(.07),
                blurRadius: 18,
                offset: const Offset(0, 7),
              ),
            ],
          ),

          child: IconButton(
            onPressed: () {
              Navigator.pop(context);
            },

            icon: const Icon(
              Icons.arrow_back_ios_new_rounded,
              size: 19,
              color: Color(0xff172033),
            ),
          ),
        ),

        const SizedBox(width: 14),

        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "My Profile",
                style: TextStyle(
                  fontSize: 25,
                  fontWeight: FontWeight.w800,
                  color: Color(0xff172033),
                  letterSpacing: -.5,
                ),
              ),

              SizedBox(height: 2),

              Text(
                "Manage your Servora account",
                style: TextStyle(
                  fontSize: 13,
                  color: Color(0xff7A8499),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),

        _buildSecureBadge(),
      ],
    )
        .animate()
        .fadeIn(duration: 500.ms)
        .slideY(
          begin: -.2,
          end: 0,
          curve: Curves.easeOut,
        );
  }

  // ============================================================
  // SECURITY BADGE
  // ============================================================

  Widget _buildSecureBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 11,
        vertical: 9,
      ),

      decoration: BoxDecoration(
        color: const Color(0xffECFDF5),
        borderRadius: BorderRadius.circular(14),

        border: Border.all(
          color: const Color(0xffA7F3D0),
        ),
      ),

      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.verified_user_rounded,
            size: 16,
            color: Color(0xff059669),
          ),

          SizedBox(width: 5),

          Text(
            "Secure",
            style: TextStyle(
              color: Color(0xff047857),
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    )
        .animate()
        .fadeIn(
          delay: 300.ms,
          duration: 500.ms,
        )
        .scale(
          begin: const Offset(.8, .8),
          end: const Offset(1, 1),
        );
  }

  // ============================================================
  // PROFILE HERO
  // ============================================================

  Widget _buildProfileHero() {
    return Container(
      width: double.infinity,

      padding: const EdgeInsets.fromLTRB(
        22,
        26,
        22,
        24,
      ),

      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),

        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,

          colors: [
            Color(0xff172554),
            Color(0xff1D4ED8),
            Color(0xff2563EB),
            Color(0xff0891B2),
          ],
        ),

        boxShadow: [
          BoxShadow(
            color: const Color(0xff2563EB).withOpacity(.28),
            blurRadius: 30,
            offset: const Offset(0, 15),
          ),
        ],
      ),

      child: Stack(
        children: [
          Positioned(
            top: -50,
            right: -40,
            child: Container(
              height: 150,
              width: 150,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(.08),
              ),
            ),
          ),

          Positioned(
            bottom: -70,
            left: -45,
            child: Container(
              height: 170,
              width: 170,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(.06),
              ),
            ),
          ),

          Column(
            children: [
              _build3DAvatar(),

              const SizedBox(height: 17),

              Text(
                name.isEmpty ? "Customer" : name,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,

                style: const TextStyle(
                  fontSize: 25,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: -.4,
                ),
              ),

              const SizedBox(height: 6),

              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 7,
                ),

                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(.14),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                    color: Colors.white.withOpacity(.16),
                  ),
                ),

                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.person_rounded,
                      color: Colors.white,
                      size: 15,
                    ),

                    SizedBox(width: 6),

                    Text(
                      "SERVORA CUSTOMER",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              _buildProfileStats(),
            ],
          ),
        ],
      ),
    )
        .animate()
        .fadeIn(
          duration: 650.ms,
        )
        .slideY(
          begin: .15,
          end: 0,
          duration: 650.ms,
          curve: Curves.easeOutCubic,
        )
        .scale(
          begin: const Offset(.96, .96),
          end: const Offset(1, 1),
          duration: 650.ms,
          curve: Curves.easeOutCubic,
        );
  }

  // ============================================================
  // 3D AVATAR
  // ============================================================

  Widget _build3DAvatar() {
    return AnimatedBuilder(
      animation: _floatingController,

      builder: (context, child) {
        final double movement =
            (_floatingController.value - .5) * 6;

        return Transform(
          alignment: Alignment.center,

          transform: Matrix4.identity()
            ..setEntry(3, 2, .001)
            ..rotateX(movement * .01)
            ..rotateY(movement * .015),

          child: child,
        );
      },

      child: Container(
        height: 105,
        width: 105,

        decoration: BoxDecoration(
          shape: BoxShape.circle,

          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,

            colors: [
              Colors.white,
              Color(0xffE0F2FE),
            ],
          ),

          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(.25),
              blurRadius: 20,
              offset: const Offset(0, 12),
            ),

            BoxShadow(
              color: Colors.white.withOpacity(.25),
              blurRadius: 8,
              offset: const Offset(-5, -5),
            ),
          ],
        ),

        child: Container(
          margin: const EdgeInsets.all(7),

          decoration: BoxDecoration(
            shape: BoxShape.circle,

            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,

              colors: [
                Color(0xffEFF6FF),
                Color(0xffDBEAFE),
              ],
            ),

            border: Border.all(
              color: Colors.white,
              width: 2,
            ),
          ),

          child: const Icon(
            Icons.person_rounded,
            size: 60,
            color: Color(0xff2563EB),
          ),
        ),
      ),
    )
        .animate(
          onPlay: (controller) =>
              controller.repeat(reverse: true),
        )
        .moveY(
          begin: 0,
          end: -6,
          duration: 2200.ms,
          curve: Curves.easeInOut,
        );
  }

  // ============================================================
  // PROFILE STATS
  // ============================================================

  Widget _buildProfileStats() {
    return Container(
      padding: const EdgeInsets.symmetric(
        vertical: 14,
        horizontal: 10,
      ),

      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.10),
        borderRadius: BorderRadius.circular(20),

        border: Border.all(
          color: Colors.white.withOpacity(.12),
        ),
      ),

      child: Row(
        children: [
          Expanded(
            child: _statItem(
              Icons.verified_rounded,
              "Account",
              "Active",
            ),
          ),

          Container(
            height: 35,
            width: 1,
            color: Colors.white.withOpacity(.15),
          ),

          Expanded(
            child: _statItem(
              Icons.security_rounded,
              "Security",
              "Protected",
            ),
          ),

          Container(
            height: 35,
            width: 1,
            color: Colors.white.withOpacity(.15),
          ),

          Expanded(
            child: _statItem(
              Icons.support_agent_rounded,
              "Support",
              "Servora",
            ),
          ),
        ],
      ),
    );
  }

  Widget _statItem(
    IconData icon,
    String title,
    String value,
  ) {
    return Column(
      children: [
        Icon(
          icon,
          size: 18,
          color: Colors.white,
        ),

        const SizedBox(height: 5),

        Text(
          title,
          style: TextStyle(
            color: Colors.white.withOpacity(.65),
            fontSize: 10,
            fontWeight: FontWeight.w500,
          ),
        ),

        const SizedBox(height: 2),

        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }

  // ============================================================
  // SECTION TITLE
  // ============================================================

  Widget _buildSectionTitle(
    String title,
    String subtitle,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                  color: Color(0xff172033),
                  letterSpacing: -.3,
                ),
              ),

              const SizedBox(height: 3),

              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xff8791A5),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),

        Container(
          height: 7,
          width: 7,
          decoration: const BoxDecoration(
            color: Color(0xff2563EB),
            shape: BoxShape.circle,
          ),
        ),
      ],
    )
        .animate()
        .fadeIn(
          delay: 200.ms,
          duration: 500.ms,
        )
        .slideX(
          begin: -.08,
          end: 0,
        );
  }

  // ============================================================
  // PROFILE INFO CARD
  // ============================================================

  Widget _profileInfoCard() {
    return Container(
      width: double.infinity,

      padding: const EdgeInsets.all(17),

      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25),

        border: Border.all(
          color: const Color(0xffE8EDF5),
        ),

        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.055),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),

      child: Column(
        children: [
          _infoTile(
            Icons.person_rounded,
            "Full Name",
            name.isEmpty ? "Customer" : name,
            const Color(0xff2563EB),
          ),

          _divider(),

          _infoTile(
            Icons.email_rounded,
            "Email Address",
            email.isEmpty ? "Not Added" : email,
            const Color(0xff7C3AED),
          ),

          _divider(),

          _infoTile(
            Icons.phone_rounded,
            "Phone Number",
            phone.isEmpty ? "Not Added" : phone,
            const Color(0xff059669),
          ),
        ],
      ),
    )
        .animate()
        .fadeIn(
          delay: 350.ms,
          duration: 550.ms,
        )
        .slideY(
          begin: .12,
          end: 0,
          curve: Curves.easeOut,
        );
  }

  // ============================================================
  // DIVIDER
  // ============================================================

  Widget _divider() {
    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: 3,
      ),

      child: Divider(
        height: 1,
        color: Colors.grey.shade100,
      ),
    );
  }

  // ============================================================
  // INFO TILE
  // ============================================================

  Widget _infoTile(
    IconData icon,
    String title,
    String value,
    Color color,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: 9,
      ),

      child: Row(
        children: [
          Container(
            height: 52,
            width: 52,

            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,

                colors: [
                  color.withOpacity(.16),
                  color.withOpacity(.06),
                ],
              ),

              borderRadius: BorderRadius.circular(17),

              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(.08),
                  blurRadius: 12,
                  offset: const Offset(0, 5),
                ),
              ],
            ),

            child: Icon(
              icon,
              color: color,
              size: 23,
            ),
          ),

          const SizedBox(width: 15),

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,

              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xff8A94A8),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),

                const SizedBox(height: 4),

                Text(
                  value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,

                  style: const TextStyle(
                    color: Color(0xff172033),
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),

          Icon(
            Icons.check_circle_rounded,
            size: 18,
            color: color.withOpacity(.65),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // MENU CARD
  // ============================================================

  Widget _menuCard() {
    return Container(
      width: double.infinity,

      padding: const EdgeInsets.all(9),

      decoration: BoxDecoration(
        color: Colors.white,

        borderRadius: BorderRadius.circular(25),

        border: Border.all(
          color: const Color(0xffE8EDF5),
        ),

        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.055),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),

      child: Column(
        children: [
          _menuItem(
            icon: Icons.history_rounded,
            title: "Service History",
            subtitle: "View your completed services",
            color: const Color(0xff2563EB),
            tap: () {
             Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const CustomerHistoryScreen(),
                ),
              );
            },
          ),

          _menuItem(
            icon: Icons.assignment_rounded,
            title: "My Applications",
            subtitle: "Manage your service applications",
            color: const Color(0xff7C3AED),
            tap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const CustomerRequestsScreen(),
                ),
              );
            },
          ),

          _menuItem(
            icon: Icons.settings_rounded,
            title: "Account Settings",
            subtitle: "Manage account preferences",
            color: const Color(0xff0891B2),
             tap: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            const CustomerAccountSettingsScreen(),
      ),
    );
  },
          ),
        ],
      ),
    )
        .animate()
        .fadeIn(
          delay: 450.ms,
          duration: 550.ms,
        )
        .slideY(
          begin: .12,
          end: 0,
        );
  }

  // ============================================================
  // MENU ITEM
  // ============================================================

  Widget _menuItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback tap,
  }) {
    return Material(
      color: Colors.transparent,

      child: InkWell(
        onTap: tap,

        borderRadius: BorderRadius.circular(19),

        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 8,
            vertical: 8,
          ),

          child: Row(
            children: [
              Container(
                height: 53,
                width: 53,

                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,

                    colors: [
                      color.withOpacity(.17),
                      color.withOpacity(.06),
                    ],
                  ),

                  borderRadius:
                      BorderRadius.circular(17),

                  boxShadow: [
                    BoxShadow(
                      color: color.withOpacity(.08),
                      blurRadius: 12,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),

                child: Icon(
                  icon,
                  color: color,
                  size: 23,
                ),
              ),

              const SizedBox(width: 14),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,

                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Color(0xff172033),
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),

                    const SizedBox(height: 4),

                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,

                      style: const TextStyle(
                        color: Color(0xff8A94A8),
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),

              Container(
                height: 34,
                width: 34,

                decoration: BoxDecoration(
                  color: const Color(0xffF5F7FB),
                  borderRadius: BorderRadius.circular(11),
                ),

                child: const Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 14,
                  color: Color(0xff64748B),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // LOGOUT BUTTON
  // ============================================================

  Widget _logoutButton() {
    return Container(
      width: double.infinity,

      height: 60,

      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,

          colors: [
            Color(0xffDC2626),
            Color(0xffEF4444),
          ],
        ),

        borderRadius: BorderRadius.circular(20),

        boxShadow: [
          BoxShadow(
            color: const Color(0xffEF4444)
                .withOpacity(.22),
            blurRadius: 20,
            offset: const Offset(0, 9),
          ),
        ],
      ),

      child: Material(
        color: Colors.transparent,

        child: InkWell(
          onTap: logout,

          borderRadius: BorderRadius.circular(20),

          child: const Row(
            mainAxisAlignment:
                MainAxisAlignment.center,

            children: [
              Icon(
                Icons.logout_rounded,
                color: Colors.white,
                size: 22,
              ),

              SizedBox(width: 10),

              Text(
                "Logout from Servora",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  letterSpacing: .2,
                ),
              ),
            ],
          ),
        ),
      ),
    )
        .animate()
        .fadeIn(
          delay: 600.ms,
          duration: 500.ms,
        )
        .slideY(
          begin: .15,
          end: 0,
        )
        .shimmer(
          delay: 1200.ms,
          duration: 1800.ms,
        );
  }

  // ============================================================
  // LOADING SCREEN
  // ============================================================

  Widget _buildLoadingScreen() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,

          colors: [
            Color(0xff172554),
            Color(0xff2563EB),
            Color(0xff0891B2),
          ],
        ),
      ),

      child: Center(
        child: Column(
          mainAxisAlignment:
              MainAxisAlignment.center,

          children: [
            Container(
              height: 90,
              width: 90,

              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,

                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(.20),
                    blurRadius: 30,
                    offset: const Offset(0, 15),
                  ),
                ],
              ),

              child: const Icon(
                Icons.person_rounded,
                size: 48,
                color: Color(0xff2563EB),
              ),
            )
                .animate(
                  onPlay: (controller) =>
                      controller.repeat(reverse: true),
                )
                .scale(
                  begin: const Offset(.9, .9),
                  end: const Offset(1.08, 1.08),
                  duration: 900.ms,
                ),

            const SizedBox(height: 25),

            const Text(
              "Loading Profile",
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),

            const SizedBox(height: 7),

            Text(
              "Preparing your Servora account...",
              style: TextStyle(
                color: Colors.white.withOpacity(.70),
                fontSize: 13,
              ),
            ),

            const SizedBox(height: 25),

            SizedBox(
              width: 130,

              child: ClipRRect(
                borderRadius:
                    BorderRadius.circular(20),

                child:
                    const LinearProgressIndicator(
                  minHeight: 5,
                  backgroundColor:
                      Colors.white24,
                  valueColor:
                      AlwaysStoppedAnimation<Color>(
                    Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
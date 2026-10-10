import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CustomerAccountSettingsScreen extends StatefulWidget {
  const CustomerAccountSettingsScreen({super.key});

  @override
  State<CustomerAccountSettingsScreen> createState() =>
      _CustomerAccountSettingsScreenState();
}

class _CustomerAccountSettingsScreenState
    extends State<CustomerAccountSettingsScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _floatingController;

  static const Color primaryBlue = Color(0xff2563EB);
  static const Color secondaryBlue = Color(0xff38BDF8);
  static const Color background = Color(0xffF4F7FC);

  @override
  void initState() {
    super.initState();

    _floatingController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _floatingController.dispose();
    super.dispose();
  }

  // ============================================================
  // SUPPORT CALL
  // ============================================================

  Future<void> _callSupport() async {
    const String phone = "8847892002";

    final Uri uri = Uri.parse("tel:$phone");

    try {
      final bool launched = await launchUrl(uri);

      if (!launched && mounted) {
        _showMessage("Unable to open phone dialer.", Colors.red);
      }
    } catch (e) {
      if (mounted) {
        _showMessage("Unable to call support.", Colors.red);
      }
    }
  }

  // ============================================================
  // WHATSAPP SUPPORT
  // ============================================================

  Future<void> _openWhatsApp() async {
    const String phone = "918847892002";

    final Uri uri = Uri.parse(
      "https://wa.me/$phone?text=Hello%20Servora%20Support,%20I%20need%20help.",
    );

    try {
      final bool launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      if (!launched && mounted) {
        _showMessage("WhatsApp is not available.", Colors.orange);
      }
    } catch (e) {
      if (mounted) {
        _showMessage("Unable to open WhatsApp.", Colors.red);
      }
    }
  }

  // ============================================================
  // SHARE APP
  // ============================================================

  Future<void> _shareApp() async {
    const String message = """
🚀 Discover Servora

Your trusted platform for home and local services.

Book services, connect with service professionals, track your service and manage everything from one place.

Try Servora today!

#Servora #HomeServices #ServiceMarketplace
""";

    try {
      final Uri shareUri = Uri.https('wa.me', '/', <String, String>{
        'text': message,
      });
      final bool launched = await launchUrl(
        shareUri,
        mode: LaunchMode.externalApplication,
      );

      if (!launched && mounted) {
        _showMessage("Unable to share Servora.", Colors.red);
      }
    } catch (e) {
      if (mounted) {
        _showMessage("Unable to share Servora.", Colors.red);
      }
    }
  }

  // ============================================================
  // MESSAGE
  // ============================================================

  void _showMessage(String message, Color color) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: color,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Row(
          children: [
            const Icon(Icons.info_outline_rounded, color: Colors.white),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,

      body: SafeArea(
        child: Stack(
          children: [
            _buildAnimatedBackground(),

            Column(
              children: [
                _buildTopBar(),

                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),

                    padding: const EdgeInsets.fromLTRB(18, 14, 18, 40),

                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,

                      children: [
                        _buildHero(),

                        const SizedBox(height: 25),

                        _sectionTitle(
                          "Legal & Privacy",
                          "Understand how Servora works",
                        ),

                        const SizedBox(height: 12),

                        _buildSettingsCard(
                              children: [
                                _settingsItem(
                                  icon: Icons.description_rounded,
                                  title: "Terms & Conditions",
                                  subtitle:
                                      "Rules and conditions for using Servora",
                                  color: const Color(0xff2563EB),
                                  onTap: _showTerms,
                                ),

                                _itemDivider(),

                                _settingsItem(
                                  icon: Icons.privacy_tip_rounded,
                                  title: "Privacy Policy",
                                  subtitle:
                                      "Learn how your information is handled",
                                  color: const Color(0xff7C3AED),
                                  onTap: _showPrivacyPolicy,
                                ),
                              ],
                            )
                            .animate()
                            .fadeIn(duration: 500.ms)
                            .slideY(begin: .10, end: 0),

                        const SizedBox(height: 25),

                        _sectionTitle(
                          "Help & Support",
                          "We're here when you need us",
                        ),

                        const SizedBox(height: 12),

                        _buildSupportCard(),

                        const SizedBox(height: 25),

                        _sectionTitle("More", "Additional Servora options"),

                        const SizedBox(height: 12),

                        _buildSettingsCard(
                              children: [
                                _settingsItem(
                                  icon: Icons.share_rounded,
                                  title: "Share Servora",
                                  subtitle:
                                      "Share Servora with friends and family",
                                  color: const Color(0xff0891B2),
                                  onTap: _shareApp,
                                ),

                                _itemDivider(),

                                _settingsItem(
                                  icon: Icons.info_rounded,
                                  title: "About Servora",
                                  subtitle: "Learn more about Servora",
                                  color: const Color(0xff059669),
                                  onTap: _showAbout,
                                ),
                              ],
                            )
                            .animate()
                            .fadeIn(delay: 300.ms, duration: 500.ms)
                            .slideY(begin: .10, end: 0),

                        const SizedBox(height: 25),

                        _buildSecurityCard(),

                        const SizedBox(height: 20),

                        _buildVersion(),

                        const SizedBox(height: 18),

                        _buildLogoutButton(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // ANIMATED BACKGROUND
  // ============================================================

  Widget _buildAnimatedBackground() {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _floatingController,

        builder: (context, child) {
          final double value = _floatingController.value;

          return Stack(
            children: [
              Positioned(
                top: -80 + (value * 25),
                right: -90,
                child: Container(
                  width: 240,
                  height: 240,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        secondaryBlue.withOpacity(.18),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),

              Positioned(
                top: 330 - (value * 30),
                left: -120,
                child: Container(
                  width: 240,
                  height: 240,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        primaryBlue.withOpacity(.08),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),

              Positioned(
                bottom: -100 + (value * 20),
                right: -80,
                child: Container(
                  width: 220,
                  height: 220,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        const Color(0xff7C3AED).withOpacity(.07),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ============================================================
  // TOP BAR
  // ============================================================

  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.94),
        border: const Border(bottom: BorderSide(color: Color(0xffE7EDF5))),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.025),
            blurRadius: 18,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Row(
        children: [
          _topButton(
            icon: Icons.arrow_back_ios_new_rounded,
            onTap: () {
              Navigator.pop(context);
            },
          ),

          const SizedBox(width: 14),

          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Account Settings",
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: Color(0xff172033),
                    letterSpacing: -.4,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  "Manage your Servora experience",
                  style: TextStyle(
                    fontSize: 11.5,
                    color: Color(0xff7A8499),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),

          _topButton(
            icon: Icons.settings_rounded,
            isSettings: true,
            onTap: () {},
          ),
        ],
      ),
    ).animate().fadeIn(duration: 450.ms).slideY(begin: -.08, end: 0);
  }

  Widget _topButton({
    required IconData icon,
    required VoidCallback onTap,
    bool isSettings = false,
  }) {
    return Container(
      height: 45,
      width: 45,
      decoration: BoxDecoration(
        gradient: isSettings
            ? const LinearGradient(colors: [primaryBlue, secondaryBlue])
            : null,
        color: isSettings ? null : Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: isSettings
                ? primaryBlue.withOpacity(.20)
                : Colors.black.withOpacity(.06),
            blurRadius: 16,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: IconButton(
        onPressed: onTap,
        icon: Icon(
          icon,
          size: 19,
          color: isSettings ? Colors.white : const Color(0xff172033),
        ),
      ),
    );
  }

  // ============================================================
  // HERO
  // ============================================================

  Widget _buildHero() {
    return Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, .001)
            ..rotateX(.002)
            ..rotateY(-.002),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(23),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(30),
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
                  color: primaryBlue.withOpacity(.27),
                  blurRadius: 32,
                  offset: const Offset(0, 16),
                ),
              ],
            ),
            child: Stack(
              children: [
                Positioned(
                  right: -45,
                  top: -55,
                  child: Container(
                    width: 155,
                    height: 155,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(.07),
                    ),
                  ),
                ),

                Positioned(
                  left: -50,
                  bottom: -80,
                  child: Container(
                    width: 180,
                    height: 180,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(.05),
                    ),
                  ),
                ),

                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _heroIcon(Icons.settings_rounded),

                        const SizedBox(width: 14),

                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "SERVORA",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 2,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                "Account & Preferences",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 19,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    Text(
                      "Everything you need to manage your account, privacy, support and Servora experience.",
                      style: TextStyle(
                        color: Colors.white.withOpacity(.76),
                        fontSize: 12.5,
                        height: 1.55,
                        fontWeight: FontWeight.w600,
                      ),
                    ),

                    const SizedBox(height: 20),

                    Row(
                      children: [
                        _heroBadge(Icons.shield_rounded, "Secure"),
                        const SizedBox(width: 8),
                        _heroBadge(Icons.verified_rounded, "Trusted"),
                        const SizedBox(width: 8),
                        _heroBadge(Icons.support_agent_rounded, "Support"),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        )
        .animate()
        .fadeIn(duration: 600.ms)
        .slideY(
          begin: .12,
          end: 0,
          duration: 600.ms,
          curve: Curves.easeOutCubic,
        )
        .scale(
          begin: const Offset(.97, .97),
          end: const Offset(1, 1),
          duration: 600.ms,
        );
  }

  Widget _heroIcon(IconData icon) {
    return Container(
      height: 58,
      width: 58,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.13),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(.18)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.12),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Icon(icon, color: Colors.white, size: 29),
    );
  }

  Widget _heroBadge(IconData icon, String text) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 6),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(.10),
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: Colors.white.withOpacity(.10)),
        ),
        child: Column(
          children: [
            Icon(icon, color: Colors.white, size: 17),
            const SizedBox(height: 4),
            Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 9,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // SECTION TITLE
  // ============================================================

  Widget _sectionTitle(String title, String subtitle) {
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
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: Color(0xff172033),
                  letterSpacing: -.3,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 11.5,
                  color: Color(0xff8791A5),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        Container(
          width: 7,
          height: 7,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: primaryBlue,
          ),
        ),
      ],
    );
  }

  // ============================================================
  // SETTINGS CARD
  // ============================================================

  Widget _buildSettingsCard({required List<Widget> children}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: const Color(0xffE7EDF5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.055),
            blurRadius: 24,
            offset: const Offset(0, 11),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }

  // ============================================================
  // SETTINGS ITEM
  // ============================================================

  Widget _settingsItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(19),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
          child: Row(
            children: [
              Container(
                height: 53,
                width: 53,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [color.withOpacity(.17), color.withOpacity(.06)],
                  ),
                  borderRadius: BorderRadius.circular(17),
                  boxShadow: [
                    BoxShadow(
                      color: color.withOpacity(.08),
                      blurRadius: 13,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Icon(icon, color: color, size: 24),
              ),

              const SizedBox(width: 14),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: Color(0xff172033),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        height: 1.35,
                        fontWeight: FontWeight.w600,
                        color: Color(0xff8791A5),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              Container(
                height: 34,
                width: 34,
                decoration: BoxDecoration(
                  color: const Color(0xffF5F7FB),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: const Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 13,
                  color: Color(0xff64748B),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _itemDivider() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Divider(height: 1, color: Colors.grey.shade100),
    );
  }

  // ============================================================
  // SUPPORT CARD
  // ============================================================

  Widget _buildSupportCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(27),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xff0F172A), Color(0xff172554), Color(0xff1E3A8A)],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.13),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -45,
            top: -55,
            child: Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(.035),
              ),
            ),
          ),

          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    height: 51,
                    width: 51,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(.10),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.support_agent_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),

                  const SizedBox(width: 13),

                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Servora Support",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          "Need help? Contact our support team.",
                          style: TextStyle(
                            color: Colors.white60,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),

                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xff22C55E).withOpacity(.13),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.circle, color: Color(0xff4ADE80), size: 7),
                        SizedBox(width: 5),
                        Text(
                          "HELP",
                          style: TextStyle(
                            color: Color(0xff86EFAC),
                            fontSize: 8,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 18),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(.07),
                  borderRadius: BorderRadius.circular(17),
                  border: Border.all(color: Colors.white.withOpacity(.08)),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.phone_in_talk_rounded,
                      color: secondaryBlue,
                      size: 21,
                    ),
                    SizedBox(width: 11),
                    Text(
                      "8847892002",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 13),

              Row(
                children: [
                  Expanded(
                    child: _supportButton(
                      icon: Icons.call_rounded,
                      title: "Call Support",
                      onTap: _callSupport,
                    ),
                  ),

                  const SizedBox(width: 10),

                  Expanded(
                    child: _supportButton(
                      icon: Icons.chat_rounded,
                      title: "WhatsApp",
                      onTap: _openWhatsApp,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(duration: 550.ms).slideY(begin: .10, end: 0);
  }

  Widget _supportButton({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white.withOpacity(.10),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 13),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: 18),
              const SizedBox(width: 7),
              Flexible(
                child: Text(
                  title,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
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
  // SECURITY CARD
  // ============================================================

  Widget _buildSecurityCard() {
    return Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xffECFDF5),
            borderRadius: BorderRadius.circular(23),
            border: Border.all(color: const Color(0xffA7F3D0)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xff10B981).withOpacity(.07),
                blurRadius: 20,
                offset: const Offset(0, 9),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                height: 50,
                width: 50,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xff10B981).withOpacity(.10),
                      blurRadius: 12,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.verified_user_rounded,
                  color: Color(0xff059669),
                  size: 25,
                ),
              ),

              const SizedBox(width: 13),

              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Your account is protected",
                      style: TextStyle(
                        color: Color(0xff065F46),
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      "Servora uses secure authentication and protected services to help keep your account safe.",
                      style: TextStyle(
                        color: Color(0xff047857),
                        fontSize: 10.5,
                        height: 1.45,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        )
        .animate()
        .fadeIn(delay: 450.ms, duration: 500.ms)
        .scale(begin: const Offset(.97, .97), end: const Offset(1, 1));
  }

  // ============================================================
  // VERSION
  // ============================================================

  Widget _buildVersion() {
    return Center(
      child: Column(
        children: [
          const Text(
            "SERVORA",
            style: TextStyle(
              fontSize: 11,
              letterSpacing: 2,
              fontWeight: FontWeight.w900,
              color: Color(0xff94A3B8),
            ),
          ),
          const SizedBox(height: 5),
          const Text(
            "Version 1.0.0",
            style: TextStyle(
              fontSize: 10,
              color: Color(0xffA0AABC),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // LOGOUT
  // ============================================================

  Widget _buildLogoutButton() {
    return Container(
          height: 60,
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xffDC2626), Color(0xffEF4444)],
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: const Color(0xffEF4444).withOpacity(.20),
                blurRadius: 20,
                offset: const Offset(0, 9),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _logout,
              borderRadius: BorderRadius.circular(20),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.logout_rounded, color: Colors.white, size: 22),
                  SizedBox(width: 9),
                  Text(
                    "Logout from Servora",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          ),
        )
        .animate()
        .fadeIn(delay: 550.ms, duration: 500.ms)
        .slideY(begin: .12, end: 0);
  }

  // ============================================================
  // LOGOUT DIALOG
  // ============================================================

  Future<void> _logout() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(.15),
                  blurRadius: 35,
                  offset: const Offset(0, 15),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  height: 70,
                  width: 70,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [Color(0xffDC2626), Color(0xffEF4444)],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.red.withOpacity(.20),
                        blurRadius: 20,
                        offset: const Offset(0, 9),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.logout_rounded,
                    color: Colors.white,
                    size: 32,
                  ),
                ),

                const SizedBox(height: 20),

                const Text(
                  "Logout from Servora?",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: Color(0xff172033),
                  ),
                ),

                const SizedBox(height: 9),

                const Text(
                  "You will need to login again to access your account.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.5,
                    color: Color(0xff64748B),
                    fontWeight: FontWeight.w500,
                  ),
                ),

                const SizedBox(height: 23),

                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context, false),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: const BorderSide(color: Color(0xffCBD5E1)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                        ),
                        child: const Text(
                          "Cancel",
                          style: TextStyle(
                            color: Color(0xff334155),
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(width: 11),

                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context, true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xffEF4444),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                        ),
                        child: const Text(
                          "Logout",
                          style: TextStyle(fontWeight: FontWeight.w900),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );

    if (confirm != true) {
      return;
    }

    try {
      await FirebaseAuth.instance.signOut();

      if (!mounted) return;

      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (e) {
      if (mounted) {
        _showMessage("Logout failed. Please try again.", Colors.red);
      }
    }
  }

  // ============================================================
  // TERMS & CONDITIONS
  // ============================================================

  void _showTerms() {
    _showDocument(
      title: "Terms & Conditions",
      icon: Icons.description_rounded,
      sections: [
        _doc(
          "1. Acceptance of Terms",
          "By using Servora, you agree to these Terms & Conditions. "
              "If you do not agree with these terms, please do not use the application.",
        ),
        _doc(
          "2. Servora Platform",
          "Servora provides a digital platform that connects customers with "
              "service professionals for home, apartment and local service requirements. "
              "Servora may facilitate service requests, communication, tracking and payments.",
        ),
        _doc(
          "3. Customer Responsibilities",
          "Customers must provide accurate information about the requested service, "
              "contact information and service location. Customers should provide reasonable "
              "access to the service location when the professional arrives.",
        ),
        _doc(
          "4. Service Professionals",
          "Service professionals are responsible for carrying out the agreed service. "
              "Service availability, pricing, completion time and service quality may depend "
              "on the nature of the service and the assigned professional.",
        ),
        _doc(
          "5. Pricing & Payments",
          "Prices may depend on the selected service, service requirements, vendor offers "
              "and applicable pricing rules. Where digital payment is available, customers "
              "should verify the final amount before completing payment.",
        ),
        _doc(
          "6. Apartment & Group Services",
          "For apartment or society services, multiple customers may participate in a common "
              "service batch. Pricing may change according to participation and vendor offers. "
              "Where applicable, once work has started for a particular flat, its applicable "
              "service price may become locked.",
        ),
        _doc(
          "7. Prohibited Activities",
          "Users must not use Servora for unlawful activities, fraudulent requests, harassment, "
              "abuse, unauthorized access or activities that may harm other users, service "
              "professionals or the Servora platform.",
        ),
        _doc(
          "8. Service Problems",
          "If there is a problem with a service, customers should contact Servora Support "
              "as soon as possible and provide the relevant service details so the issue "
              "can be reviewed.",
        ),
        _doc(
          "9. Platform Availability",
          "Servora aims to provide reliable service but does not guarantee uninterrupted "
              "availability. The application may occasionally be unavailable because of "
              "maintenance, technical problems, network issues or third-party services.",
        ),
        _doc(
          "10. Changes to Terms",
          "Servora may update these Terms & Conditions when required. Updated terms may "
              "be made available inside the application or through official Servora communication.",
        ),
      ],
    );
  }

  // ============================================================
  // PRIVACY POLICY
  // ============================================================

  void _showPrivacyPolicy() {
    _showDocument(
      title: "Privacy Policy",
      icon: Icons.privacy_tip_rounded,
      sections: [
        _doc(
          "1. Information We Collect",
          "Servora may collect information required to provide services, "
              "including your name, phone number, email address, service address, "
              "service requests, booking information and account information.",
        ),
        _doc(
          "2. Location Information",
          "Location information may be used for service discovery, address selection, "
              "distance calculation, service assignment, navigation and other location-based "
              "features when those features are used.",
        ),
        _doc(
          "3. Service Information",
          "Information about service requests, selected categories, service status, "
              "assigned professionals, pricing and payment status may be stored to operate "
              "and improve the service experience.",
        ),
        _doc(
          "4. Payment Information",
          "Payments may be processed by third-party payment providers. Servora may receive "
              "transaction information such as payment status, order information and transaction "
              "identifiers. Sensitive payment credentials are handled by the applicable payment provider.",
        ),
        _doc(
          "5. How Information Is Used",
          "Information may be used to create accounts, process service requests, communicate "
              "with users, provide service tracking, facilitate payments, improve the platform, "
              "prevent fraud and provide customer support.",
        ),
        _doc(
          "6. Data Security",
          "Servora uses reasonable technical and organizational measures to protect information. "
              "However, no internet-based system can guarantee absolute security.",
        ),
        _doc(
          "7. Third-Party Services",
          "Servora may use third-party infrastructure and services for authentication, database "
              "hosting, payments, maps, communication and other platform functionality. "
              "Those services may process information according to their own policies.",
        ),
        _doc(
          "8. Data Sharing",
          "Information may be shared when necessary to provide a requested service, facilitate "
              "communication, process payments, provide support, comply with legal requirements "
              "or protect the safety and security of users and the platform.",
        ),
        _doc(
          "9. Account Deletion",
          "If you want to request account or personal data deletion, please contact Servora Support. "
              "Certain information may need to be retained where required for legal, security or "
              "transaction-record purposes.",
        ),
        _doc(
          "10. Policy Updates",
          "This Privacy Policy may be updated from time to time. Users are encouraged to review "
              "the policy periodically for changes.",
        ),
      ],
    );
  }

  // ============================================================
  // DOCUMENT SHEET
  // ============================================================

  void _showDocument({
    required String title,
    required IconData icon,
    required List<_DocumentSection> sections,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: .88,
          minChildSize: .55,
          maxChildSize: .96,
          expand: false,
          builder: (context, scrollController) {
            return Container(
              decoration: const BoxDecoration(
                color: background,
                borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 12),

                  Container(
                    width: 45,
                    height: 5,
                    decoration: BoxDecoration(
                      color: const Color(0xffCBD5E1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),

                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
                    child: Row(
                      children: [
                        Container(
                          width: 51,
                          height: 51,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [primaryBlue, secondaryBlue],
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: primaryBlue.withOpacity(.22),
                                blurRadius: 17,
                                offset: const Offset(0, 7),
                              ),
                            ],
                          ),
                          child: Icon(icon, color: Colors.white, size: 25),
                        ),

                        const SizedBox(width: 13),

                        Expanded(
                          child: Text(
                            title,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              color: Color(0xff172033),
                            ),
                          ),
                        ),

                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(
                            Icons.close_rounded,
                            color: Color(0xff475569),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const Divider(height: 1, color: Color(0xffE2E8F0)),

                  Expanded(
                    child: ListView.builder(
                      controller: scrollController,
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 35),
                      itemCount: sections.length,
                      itemBuilder: (context, index) {
                        final section = sections[index];

                        return _documentCard(
                          section.title,
                          section.content,
                          index,
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _documentCard(String title, String content, int index) {
    return Container(
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xffE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(.035),
                blurRadius: 18,
                offset: const Offset(0, 7),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: primaryBlue,
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                content,
                style: const TextStyle(
                  color: Color(0xff475569),
                  fontSize: 12.5,
                  height: 1.65,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        )
        .animate()
        .fadeIn(
          duration: 350.ms,
          delay: Duration(milliseconds: index * 40),
        )
        .slideY(begin: .06, end: 0, duration: 350.ms);
  }

  _DocumentSection _doc(String title, String content) {
    return _DocumentSection(title: title, content: content);
  }

  // ============================================================
  // ABOUT SERVORA
  // ============================================================

  void _showAbout() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.fromLTRB(24, 30, 24, 35),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                height: 80,
                width: 80,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(25),
                  gradient: const LinearGradient(
                    colors: [primaryBlue, secondaryBlue],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: primaryBlue.withOpacity(.25),
                      blurRadius: 25,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.home_repair_service_rounded,
                  color: Colors.white,
                  size: 40,
                ),
              ).animate().scale(duration: 500.ms, curve: Curves.easeOutBack),

              const SizedBox(height: 18),

              const Text(
                "SERVORA",
                style: TextStyle(
                  fontSize: 25,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                  color: Color(0xff172033),
                ),
              ),

              const SizedBox(height: 6),

              const Text(
                "Your trusted service marketplace",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xff64748B),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),

              const SizedBox(height: 20),

              const Text(
                "Servora connects customers with service professionals "
                "for convenient home, apartment and local services.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xff475569),
                  fontSize: 13,
                  height: 1.6,
                ),
              ),

              const SizedBox(height: 20),

              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xffEFF6FF),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Text(
                  "Servora v1.0.0",
                  style: TextStyle(
                    color: primaryBlue,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ================================================================
// DOCUMENT MODEL
// ================================================================

class _DocumentSection {
  final String title;
  final String content;

  _DocumentSection({required this.title, required this.content});
}

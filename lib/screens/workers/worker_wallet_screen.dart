import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

class WorkerWalletScreen extends StatelessWidget {
  const WorkerWalletScreen({super.key});

  static const Color primaryBlue = Color(0xFF2563EB);
  static const Color secondaryBlue = Color(0xFF38BDF8);
  static const Color backgroundColor = Color(0xFFF5F8FF);
  static const Color borderColor = Color(0xFFE5EAF5);

  // All amounts are stored in paise in Firebase.
  // Example: 231210 paise = ₹2,312.10.
  String formatRupees(num paise) {
    return '₹${(paise / 100).toStringAsFixed(2)}';
  }

  Map<String, dynamic> toMap(Object? value) {
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }
    return <String, dynamic>{};
  }

  num toNumber(Object? value) {
    return value is num ? value : 0;
  }

  String formatDate(Object? timestamp) {
    final milliseconds = toNumber(timestamp).toInt();

    if (milliseconds <= 0) {
      return 'Date unavailable';
    }

    final date = DateTime.fromMillisecondsSinceEpoch(
      milliseconds,
    ).toLocal();

    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');

    return '$day/$month/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(
        backgroundColor: backgroundColor,
        body: Center(
          child: Text('Please log in to view your earnings.'),
        ),
      );
    }

    final workerUid = user.uid;

    final walletRef = FirebaseDatabase.instance.ref(
      'workerWallets/$workerUid',
    );

    // Only retrieve earnings belonging to the signed-in worker.
    final earningsQuery = FirebaseDatabase.instance
        .ref('workerEarnings')
        .orderByChild('workerUid')
        .equalTo(workerUid);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: const Text(
          'My Wallet',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: primaryBlue,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: StreamBuilder<DatabaseEvent>(
        stream: walletRef.onValue,
        builder: (context, walletSnapshot) {
          if (walletSnapshot.hasError) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Unable to load your wallet. Please check your '
                  'connection and database permissions.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          if (walletSnapshot.connectionState ==
                  ConnectionState.waiting &&
              !walletSnapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(
                color: primaryBlue,
              ),
            );
          }

          final wallet = toMap(
            walletSnapshot.data?.snapshot.value,
          );

          final availableBalance = toNumber(
            wallet['availableBalancePaise'],
          );

          final totalEarned = toNumber(
            wallet['totalEarnedPaise'],
          );

          return RefreshIndicator(
            color: primaryBlue,
            onRefresh: () async {
              await Future.wait([
                walletRef.get(),
                earningsQuery.get(),
              ]);
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              children: [
                // Available balance.
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [
                        primaryBlue,
                        secondaryBlue,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: [
                      BoxShadow(
                        color: primaryBlue.withValues(alpha: 0.20),
                        blurRadius: 14,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(
                            Icons.account_balance_wallet_outlined,
                            color: Colors.white,
                            size: 26,
                          ),
                          SizedBox(width: 10),
                          Text(
                            'Available Balance',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      Text(
                        formatRupees(availableBalance),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 34,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Your earnings recorded in Servora',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 18),

                // Total earned.
                _summaryCard(
                  icon: Icons.trending_up,
                  iconBackground: const Color(0xFFE8F5E9),
                  iconColor: Colors.green,
                  title: 'Total Earned',
                  amount: formatRupees(totalEarned),
                ),

                const SizedBox(height: 26),

                const Text(
                  'Earnings History',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF172033),
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Your earnings from paid services',
                  style: TextStyle(
                    color: Colors.black54,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 14),

                // Earnings records.
                StreamBuilder<DatabaseEvent>(
                  stream: earningsQuery.onValue,
                  builder: (context, earningsSnapshot) {
                    if (earningsSnapshot.hasError) {
                      return _messageCard(
                        icon: Icons.error_outline,
                        title: 'Unable to load earnings history',
                        message:
                            'Check your internet connection and '
                            'Firebase database permissions.',
                      );
                    }

                    if (earningsSnapshot.connectionState ==
                            ConnectionState.waiting &&
                        !earningsSnapshot.hasData) {
                      return const Padding(
                        padding: EdgeInsets.all(28),
                        child: Center(
                          child: CircularProgressIndicator(
                            color: primaryBlue,
                          ),
                        ),
                      );
                    }

                    final rawValue =
                        earningsSnapshot.data?.snapshot.value;

                    if (rawValue == null) {
                      return _messageCard(
                        icon: Icons.receipt_long_outlined,
                        title: 'No earnings yet',
                        message:
                            'Your credited service earnings will '
                            'appear here after payment is processed.',
                      );
                    }

                    final records = toMap(rawValue).entries.toList();

                    // Most recent earnings first.
                    records.sort((a, b) {
                      final aTime = toNumber(
                        toMap(a.value)['createdAt'],
                      );
                      final bTime = toNumber(
                        toMap(b.value)['createdAt'],
                      );

                      return bTime.compareTo(aTime);
                    });

                    if (records.isEmpty) {
                      return _messageCard(
                        icon: Icons.receipt_long_outlined,
                        title: 'No earnings yet',
                        message:
                            'Your credited service earnings will '
                            'appear here after payment is processed.',
                      );
                    }

                    return Column(
                      children: records.map((entry) {
                        final earning = toMap(entry.value);

                        final amount = toNumber(
                          earning['workerAmountPaise'],
                        );

                        final commission = toNumber(
                          earning['commissionPaise'],
                        );

                        final gross = toNumber(
                          earning['grossAmountPaise'],
                        );

                        final status =
                            (earning['status'] ?? 'available')
                                .toString();

                        final serviceId = (earning['serviceId'] ??
                                entry.key)
                            .toString();

                        final shortServiceId =
                            serviceId.length > 8
                                ? serviceId.substring(0, 8)
                                : serviceId;

                        final dateText = formatDate(
                          earning['createdAt'],
                        );

                        return Card(
                          color: Colors.white,
                          elevation: 0,
                          margin: const EdgeInsets.only(bottom: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: const BorderSide(
                              color: borderColor,
                            ),
                          ),
                          child: ExpansionTile(
                            key: PageStorageKey<String>(
                              'earning_$serviceId',
                            ),
                            tilePadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 6,
                            ),
                            childrenPadding:
                                const EdgeInsets.fromLTRB(
                              16,
                              0,
                              16,
                              16,
                            ),
                            leading: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE8F5E9),
                                borderRadius:
                                    BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.check_circle_outline,
                                color: Colors.green,
                              ),
                            ),
                            title: Text(
                              'Service $shortServiceId',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                            subtitle: Text(
                              '$dateText • ${_displayStatus(status)}',
                            ),
                            trailing: Text(
                              '+${formatRupees(amount)}',
                              style: const TextStyle(
                                color: Colors.green,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            children: [
                              const Divider(
                                color: borderColor,
                              ),
                              _detailRow(
                                'Gross payment',
                                formatRupees(gross),
                              ),
                              _detailRow(
                                'Servora commission',
                                formatRupees(commission),
                              ),
                              _detailRow(
                                'Your earnings',
                                formatRupees(amount),
                                highlight: true,
                              ),
                              _detailRow(
                                'Payment ID',
                                _shortPaymentId(
                                  earning['paymentId']?.toString(),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),

                const SizedBox(height: 24),

                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: const Color(0xFFDBEAFE),
                    ),
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: primaryBlue,
                        size: 20,
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'This balance tracks your earnings inside '
                          'Servora. It does not mean that money has '
                          'already been transferred to your bank '
                          'account or UPI.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF334155),
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  static Widget _summaryCard({
    required IconData icon,
    required Color iconBackground,
    required Color iconColor,
    required String title,
    required String amount,
  }) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: borderColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: iconBackground,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                icon,
                color: iconColor,
                size: 28,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.black54,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    amount,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
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

  static Widget _messageCard({
    required IconData icon,
    required String title,
    required String message,
  }) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: borderColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(
              icon,
              size: 42,
              color: Colors.grey,
            ),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.black54,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _detailRow(
    String label,
    String value, {
    bool highlight = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.black54,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: highlight ? Colors.green : Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _displayStatus(String status) {
    if (status.isEmpty) return 'Available';

    return status
        .replaceAll('_', ' ')
        .split(' ')
        .map(
          (word) => word.isEmpty
              ? word
              : '${word[0].toUpperCase()}${word.substring(1)}',
        )
        .join(' ');
  }

  static String _shortPaymentId(String? paymentId) {
    if (paymentId == null || paymentId.isEmpty) {
      return 'Not available';
    }

    if (paymentId.length <= 16) {
      return paymentId;
    }

    return '${paymentId.substring(0, 8)}...'
        '${paymentId.substring(paymentId.length - 5)}';
  }
}

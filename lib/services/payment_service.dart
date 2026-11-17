
import 'package:flutter/foundation.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'payment_api_service.dart';

class PaymentService {
  final Razorpay _razorpay = Razorpay();
  final PaymentApiService _paymentApiService = PaymentApiService();

  String? _currentServiceId;

  Function(PaymentSuccessResponse response)? onPaymentSuccess;
  Function(PaymentFailureResponse response)? onPaymentError;
  Function(ExternalWalletResponse response)? onExternalWallet;

  PaymentService() {
    _razorpay.on(
      Razorpay.EVENT_PAYMENT_SUCCESS,
      _handlePaymentSuccess,
    );

    _razorpay.on(
      Razorpay.EVENT_PAYMENT_ERROR,
      _handlePaymentError,
    );

    _razorpay.on(
      Razorpay.EVENT_EXTERNAL_WALLET,
      _handleExternalWallet,
    );
  }

  void openCheckout({
    required String keyId,
    required int amountInPaise,
    required String orderId,
    required String serviceId,
    String? customerName,
    String? customerEmail,
    String? customerPhone,
    String description = 'Servora Service Payment',
  }) {
    _currentServiceId = serviceId;

    final Map<String, dynamic> options = {
      'key': keyId,
      'amount': amountInPaise,
      'currency': 'INR',
      'name': 'Servora',
      'description': description,
      'order_id': orderId,
      'prefill': {
        if (customerName != null && customerName.isNotEmpty)
          'name': customerName,
        if (customerEmail != null && customerEmail.isNotEmpty)
          'email': customerEmail,
        if (customerPhone != null && customerPhone.isNotEmpty)
          'contact': customerPhone,
      },
      'theme': {
        'color': '#2563EB',
      },
      'retry': {
        'enabled': true,
        'max_count': 4,
      },
      'timeout': 300,
    };

    debugPrint('SERVORA PAYMENT');
    debugPrint('Service ID: $serviceId');
    debugPrint('Amount: ₹${amountInPaise / 100}');
    debugPrint('Order ID: $orderId');

    try {
      _razorpay.open(options);
    } catch (e) {
      debugPrint('RAZORPAY OPEN ERROR: $e');

      onPaymentError?.call(
        PaymentFailureResponse(
          0,
          'Unable to open Razorpay Checkout',
          null,
        ),
      );
    }
  }

  Future<void> _handlePaymentSuccess(
    PaymentSuccessResponse response,
  ) async {
    debugPrint('RAZORPAY CHECKOUT REPORTED SUCCESS');

    final serviceId = _currentServiceId;

    if (serviceId == null || serviceId.isEmpty) {
      debugPrint('PAYMENT ERROR: Service ID is missing');

      onPaymentError?.call(
        PaymentFailureResponse(
          0,
          'Service ID is missing',
          null,
        ),
      );
      return;
    }

    try {
      final verified = await _paymentApiService.verifyPayment(
        serviceId: serviceId,
        paymentId: response.paymentId ?? '',
        orderId: response.orderId ?? '',
        signature: response.signature ?? '',
      );

      if (verified) {
        debugPrint('BACKEND SIGNATURE VERIFICATION PASSED');
        onPaymentSuccess?.call(response);
      } else {
        debugPrint('BACKEND PAYMENT VERIFICATION FAILED');

        onPaymentError?.call(
          PaymentFailureResponse(
            0,
            'Payment could not be verified',
            null,
          ),
        );
      }
    } catch (e) {
      debugPrint('PAYMENT VERIFICATION ERROR: $e');

      onPaymentError?.call(
        PaymentFailureResponse(
          0,
          'Unable to verify payment with server',
          null,
        ),
      );
    }
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    debugPrint('PAYMENT FAILED: ${response.message}');
    onPaymentError?.call(response);
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    debugPrint('EXTERNAL WALLET: ${response.walletName}');
    onExternalWallet?.call(response);
  }

  void dispose() {
    _razorpay.clear();
  }
}


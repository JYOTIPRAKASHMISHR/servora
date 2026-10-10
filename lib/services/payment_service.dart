import 'package:flutter/foundation.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'payment_api_service.dart';
/// ===============================================================
/// SERVORA PAYMENT SERVICE
/// ===============================================================
///
/// This class handles the Flutter-side Razorpay Checkout.
///
/// IMPORTANT:
/// - Do NOT put Razorpay Secret Key here.
/// - Only Razorpay Key ID belongs in the Flutter app.
/// - Razorpay Order ID must be created by your backend.
/// - Payment signature must be verified by your backend.
///
class PaymentService {

  // =============================================================
  // RAZORPAY INSTANCE
  // =============================================================

  final Razorpay _razorpay = Razorpay();

  final PaymentApiService _paymentApiService = PaymentApiService();


  // =============================================================
  // CALLBACKS
  // =============================================================

  Function(PaymentSuccessResponse response)? onPaymentSuccess;

  Function(PaymentFailureResponse response)? onPaymentError;

  Function(ExternalWalletResponse response)? onExternalWallet;


  // =============================================================
  // INITIALIZE
  // =============================================================

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


  // =============================================================
  // OPEN RAZORPAY CHECKOUT
  // =============================================================

  void openCheckout({

    required String keyId,

    required int amountInPaise,

    required String orderId,

    String? customerName,

    String? customerEmail,

    String? customerPhone,

    String description = "Servora Service Payment",

  }) {

    // -----------------------------------------------------------
    // RAZORPAY CHECKOUT OPTIONS
    // -----------------------------------------------------------

    final Map<String, dynamic> options = {

      // Razorpay Key ID
      "key": keyId,


      // Amount must be in paise.
      //
      // Example:
      // ₹699 = 69900 paise
      //
      "amount": amountInPaise,


      // Currency
      "currency": "INR",


      // Servora name
      "name": "Servora",


      // Payment description
      "description": description,


      // VERY IMPORTANT:
      // This must come from your backend.
      "order_id": orderId,


      // Customer information
      "prefill": {

        "name": ?customerName,

        "email": ?customerEmail,

        "contact": ?customerPhone,

      },


      // Checkout theme
      "theme": {

        "color": "#2563EB",

      },


      // Allow customer to retry payment
      "retry": {

        "enabled": true,

        "max_count": 4,

      },


      // Checkout timeout
      "timeout": 300,

    };


    // -----------------------------------------------------------
    // DEBUG
    // -----------------------------------------------------------

    debugPrint(
      "========================================",
    );

    debugPrint(
      "SERVORA PAYMENT",
    );

    debugPrint(
      "Amount : ₹${amountInPaise / 100}",
    );

    debugPrint(
      "Order ID : $orderId",
    );

    debugPrint(
      "========================================",
    );


    // -----------------------------------------------------------
    // OPEN RAZORPAY
    // -----------------------------------------------------------

    try {

      _razorpay.open(options);

    }

    catch (e) {

      debugPrint(
        "RAZORPAY OPEN ERROR : $e",
      );

    }

  }


  // =============================================================
  // PAYMENT SUCCESS
  // =============================================================

 Future<void> _handlePaymentSuccess(
  PaymentSuccessResponse response,
) async {

  debugPrint("PAYMENT SUCCESS");

  try {

    final verified =
        await _paymentApiService.verifyPayment(
      paymentId: response.paymentId ?? "",
      orderId: response.orderId ?? "",
      signature: response.signature ?? "",
    );

    if (verified) {

      debugPrint("PAYMENT VERIFIED BY SERVER");

      if (onPaymentSuccess != null) {
        onPaymentSuccess!(response);
      }

    } else {

      debugPrint("PAYMENT VERIFICATION FAILED");

      if (onPaymentError != null) {
        onPaymentError!(
          PaymentFailureResponse(
            0,
            "Payment verification failed",
            null,
          ),
        );
      }
    }

  } catch (e) {

    debugPrint(
      "PAYMENT VERIFICATION ERROR",
    );

    if (onPaymentError != null) {
      onPaymentError!(
        PaymentFailureResponse(
          0,
          "Payment verification error",
          null,
        ),
      );
    }
  }
}
  // =============================================================
  // PAYMENT ERROR
  // =============================================================

  void _handlePaymentError(
      PaymentFailureResponse response,
      ) {

    debugPrint(
      "========================================",
    );

    debugPrint(
      "PAYMENT FAILED",
    );

    debugPrint(
      "Code : ${response.code}",
    );

    debugPrint(
      "Message : ${response.message}",
    );

    debugPrint(
      "========================================",
    );


    // Send result back to the screen
    if (onPaymentError != null) {

      onPaymentError!(
        response,
      );

    }

  }


  // =============================================================
  // EXTERNAL WALLET
  // =============================================================

  void _handleExternalWallet(
      ExternalWalletResponse response,
      ) {

    debugPrint(
      "========================================",
    );

    debugPrint(
      "EXTERNAL WALLET SELECTED",
    );

    debugPrint(
      "Wallet : ${response.walletName}",
    );

    debugPrint(
      "========================================",
    );


    if (onExternalWallet != null) {

      onExternalWallet!(
        response,
      );

    }

  }


  // =============================================================
  // CLEAR RAZORPAY LISTENERS
  // =============================================================

  void dispose() {

    _razorpay.clear();

  }

}

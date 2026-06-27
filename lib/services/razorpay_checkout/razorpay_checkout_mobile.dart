import 'dart:async';
import 'dart:io';

import 'package:razorpay_flutter/razorpay_flutter.dart';

import 'razorpay_checkout_models.dart';

class GlowanteRazorpayCheckout {
  GlowanteRazorpayCheckout();

  Razorpay? _razorpay;
  Completer<RazorpayCheckoutResult>? _activePayment;

  bool get isSupported => Platform.isAndroid || Platform.isIOS;

  Future<RazorpayCheckoutResult> open(RazorpayCheckoutRequest request) async {
    if (!isSupported) {
      return RazorpayCheckoutResult.failure(
        'Razorpay checkout is available only on Android and iOS.',
      );
    }
    if (_activePayment != null && !_activePayment!.isCompleted) {
      return RazorpayCheckoutResult.failure(
        'A payment is already in progress.',
      );
    }

    final completer = Completer<RazorpayCheckoutResult>();
    _activePayment = completer;

    final razorpay = _razorpay ??= Razorpay();
    razorpay.clear();
    razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);

    try {
      razorpay.open(<String, dynamic>{
        'key': request.key,
        'amount': request.amountMinor,
        'currency': request.currency,
        'name': request.name,
        'description': request.description,
        if (request.orderId != null && request.orderId!.isNotEmpty)
          'order_id': request.orderId,
        'prefill': <String, dynamic>{
          if (request.contact != null && request.contact!.isNotEmpty)
            'contact': request.contact,
          if (request.email != null && request.email!.isNotEmpty)
            'email': request.email,
        },
      });
    } catch (error) {
      _completeActivePayment(RazorpayCheckoutResult.failure(error.toString()));
    }

    return completer.future;
  }

  void _handlePaymentSuccess(dynamic response) {
    if (response is! PaymentSuccessResponse) {
      _completeActivePayment(
        RazorpayCheckoutResult.failure('Invalid Razorpay success response.'),
      );
      return;
    }

    final paymentId = response.paymentId?.trim() ?? '';
    if (paymentId.isEmpty) {
      _completeActivePayment(
        RazorpayCheckoutResult.failure('Payment completed without payment id.'),
      );
      return;
    }

    _completeActivePayment(
      RazorpayCheckoutResult.success(
        paymentId: paymentId,
        orderId: response.orderId,
        signature: response.signature,
      ),
    );
  }

  void _handlePaymentError(dynamic response) {
    if (response is! PaymentFailureResponse) {
      _completeActivePayment(
        RazorpayCheckoutResult.failure('Invalid Razorpay error response.'),
      );
      return;
    }

    final message = response.message?.trim() ?? 'Payment failed.';
    if (response.code == Razorpay.PAYMENT_CANCELLED) {
      _completeActivePayment(RazorpayCheckoutResult.cancelled(message));
      return;
    }

    _completeActivePayment(RazorpayCheckoutResult.failure(message));
  }

  void _handleExternalWallet(dynamic response) {
    if (response is! ExternalWalletResponse) {
      _completeActivePayment(
        RazorpayCheckoutResult.failure(
          'Invalid Razorpay external wallet response.',
        ),
      );
      return;
    }

    _completeActivePayment(
      RazorpayCheckoutResult.failure(
        'External wallet selected: ${response.walletName ?? 'unknown'}',
      ),
    );
  }

  void _completeActivePayment(RazorpayCheckoutResult result) {
    final completer = _activePayment;
    _activePayment = null;
    _razorpay?.clear();
    if (completer != null && !completer.isCompleted) {
      completer.complete(result);
    }
  }

  void dispose() {
    _razorpay?.clear();
    _razorpay = null;
    _activePayment = null;
  }
}

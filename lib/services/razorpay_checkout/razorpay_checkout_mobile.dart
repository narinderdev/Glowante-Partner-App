import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';

import 'razorpay_checkout_models.dart';

class GlowanteRazorpayCheckout {
  GlowanteRazorpayCheckout();

  static const MethodChannel _channel = MethodChannel('razorpay_flutter');
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

    try {
      final response = await _channel.invokeMethod<dynamic>('open', {
        'key': request.key,
        'amount': request.amountMinor,
        'currency': request.currency,
        'name': request.name,
        'description': request.description,
        'prefill': <String, dynamic>{
          if (request.contact != null && request.contact!.isNotEmpty)
            'contact': request.contact,
          if (request.email != null && request.email!.isNotEmpty)
            'email': request.email,
        },
      });
      _completeActivePayment(_resultFromPlatformResponse(response));
    } on MissingPluginException {
      _completeActivePayment(
        RazorpayCheckoutResult.failure(
          'Razorpay checkout is unavailable. Fully stop and reinstall the app after adding the payment plugin.',
        ),
      );
    } catch (error) {
      _completeActivePayment(
        RazorpayCheckoutResult.failure(error.toString()),
      );
    }

    return completer.future;
  }

  RazorpayCheckoutResult _resultFromPlatformResponse(dynamic response) {
    if (response is! Map) {
      return RazorpayCheckoutResult.failure('Invalid Razorpay response.');
    }

    final data = response['data'];
    if (response['type'] == 0 && data is Map) {
      final paymentId = data['razorpay_payment_id']?.toString() ?? '';
      if (paymentId.isEmpty) {
        return RazorpayCheckoutResult.failure(
          'Payment completed without payment id.',
        );
      }
      return RazorpayCheckoutResult.success(
        paymentId: paymentId,
        orderId: data['razorpay_order_id']?.toString(),
        signature: data['razorpay_signature']?.toString(),
      );
    }

    if (response['type'] == 1 && data is Map) {
      final message = data['message']?.toString() ?? 'Payment failed.';
      if (data['code'] == 2) {
        return RazorpayCheckoutResult.cancelled(message);
      }
      return RazorpayCheckoutResult.failure(message);
    }

    if (response['type'] == 2 && data is Map) {
      return RazorpayCheckoutResult.failure(
        'External wallet selected: ${data['external_wallet'] ?? 'unknown'}',
      );
    }

    return RazorpayCheckoutResult.failure('Payment failed.');
  }

  void _completeActivePayment(RazorpayCheckoutResult result) {
    final completer = _activePayment;
    _activePayment = null;
    if (completer != null && !completer.isCompleted) {
      completer.complete(result);
    }
  }

  void dispose() {}
}

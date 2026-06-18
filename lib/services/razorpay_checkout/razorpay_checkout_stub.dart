import 'razorpay_checkout_models.dart';

class GlowanteRazorpayCheckout {
  bool get isSupported => false;

  Future<RazorpayCheckoutResult> open(RazorpayCheckoutRequest request) async {
    return RazorpayCheckoutResult.failure(
      'Razorpay checkout is not supported on this platform.',
    );
  }

  void dispose() {}
}

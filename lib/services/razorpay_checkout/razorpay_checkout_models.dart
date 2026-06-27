class RazorpayCheckoutRequest {
  const RazorpayCheckoutRequest({
    required this.key,
    required this.amountMinor,
    required this.currency,
    required this.name,
    required this.description,
    this.orderId,
    this.contact,
    this.email,
  });

  final String key;
  final int amountMinor;
  final String currency;
  final String name;
  final String description;
  final String? orderId;
  final String? contact;
  final String? email;
}

class RazorpayCheckoutResult {
  const RazorpayCheckoutResult._({
    required this.status,
    this.paymentId,
    this.orderId,
    this.signature,
    this.message,
  });

  factory RazorpayCheckoutResult.success({
    required String paymentId,
    String? orderId,
    String? signature,
  }) {
    return RazorpayCheckoutResult._(
      status: RazorpayCheckoutStatus.success,
      paymentId: paymentId,
      orderId: orderId,
      signature: signature,
    );
  }

  factory RazorpayCheckoutResult.cancelled([String? message]) {
    return RazorpayCheckoutResult._(
      status: RazorpayCheckoutStatus.cancelled,
      message: message,
    );
  }

  factory RazorpayCheckoutResult.failure(String message) {
    return RazorpayCheckoutResult._(
      status: RazorpayCheckoutStatus.failure,
      message: message,
    );
  }

  final RazorpayCheckoutStatus status;
  final String? paymentId;
  final String? orderId;
  final String? signature;
  final String? message;
}

enum RazorpayCheckoutStatus {
  success,
  cancelled,
  failure,
}

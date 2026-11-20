/// Result of the `cancel_booking` RPC.
class CancelResult {
  const CancelResult({required this.status, required this.refundEligible});

  factory CancelResult.fromJson(Map<String, dynamic> json) {
    return CancelResult(
      status: (json['status'] as String?) ?? 'cancelled',
      refundEligible: (json['refund_eligible'] as bool?) ?? false,
    );
  }

  final String status;
  final bool refundEligible;
}

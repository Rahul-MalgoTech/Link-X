class BossyLoginModel {
  final String phoneNumber;
  final String? firstName;
  final String? identity;

  const BossyLoginModel({
    required this.phoneNumber,
    this.firstName,
    this.identity,
  });

  BossyLoginModel copyWith({
    String? phoneNumber,
    String? firstName,
    String? identity,
  }) {
    return BossyLoginModel(
      phoneNumber: phoneNumber ?? this.phoneNumber,
      firstName: firstName ?? this.firstName,
      identity: identity ?? this.identity,
    );
  }
}

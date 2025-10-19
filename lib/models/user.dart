class UserInfo {
  final int id;
  final String name;
  final String? username;
  final String? phoneNumber;
  final DateTime loadedAt;

  const UserInfo({
    required this.id,
    required this.name,
    this.username,
    this.phoneNumber,
    required this.loadedAt,
  });

  bool get isStale {
    return DateTime.now().difference(loadedAt) > const Duration(hours: 1);
  }
}
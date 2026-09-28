class User {
  final int? id;
  final String username;
  final String password;
  final String name;
  final double weight;
  final double height;
  final DateTime createdAt;

  User({
    this.id,
    required this.username,
    required this.password,
    required this.name,
    required this.weight,
    required this.height,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory User.fromMap(Map<String, dynamic> map) {
    return User(
      id: map['id'],
      username: map['username'],
      password: map['password'],
      name: map['name'],
      weight: (map['weight'] ?? 0).toDouble(),
      height: (map['height'] ?? 0).toDouble(),
      createdAt: DateTime.parse(map['createdAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'username': username,
      'password': password,
      'name': name,
      'weight': weight,
      'height': height,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  User copyWith({
    int? id,
    String? username,
    String? password,
    String? name,
    double? weight,
    double? height,
    DateTime? createdAt,
  }) {
    return User(
      id: id ?? this.id,
      username: username ?? this.username,
      password: password ?? this.password,
      name: name ?? this.name,
      weight: weight ?? this.weight,
      height: height ?? this.height,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

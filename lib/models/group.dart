class Group {
  final String id;
  final String name;
  final String? description;
  final String visibility;
  final String creatorId;
  final int memberCount;
  final String? membershipStatus;
  final DateTime? createdAt;

  Group({
    required this.id,
    required this.name,
    this.description,
    required this.visibility,
    required this.creatorId,
    required this.memberCount,
    this.membershipStatus,
    this.createdAt,
  });

  factory Group.fromJson(Map<String, dynamic> json) {
    return Group(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Unnamed group',
      description: json['description']?.toString(),
      visibility: json['visibility']?.toString() ?? 'PUBLIC',
      creatorId: json['creator_id']?.toString() ?? '',
      memberCount: (json['member_count'] as num?)?.toInt() ?? 0,
      membershipStatus: json['membership_status']?.toString(),
      createdAt: json['created_at'] == null
          ? null
          : DateTime.tryParse(json['created_at'].toString()),
    );
  }
}

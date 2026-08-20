/// Mirrors the `announcements` table + Announcement type in
/// src/contexts/SubmissionsContext.tsx.
class Announcement {
  final String id;
  final String content;
  final String createdAt;
  final bool isActive;

  const Announcement({required this.id, required this.content, required this.createdAt, required this.isActive});

  factory Announcement.fromMap(Map<String, dynamic> map) {
    return Announcement(
      id: map['id'].toString(),
      content: (map['content'] ?? '') as String,
      createdAt: (map['created_at'] ?? '') as String,
      isActive: (map['is_active'] ?? false) as bool,
    );
  }
}

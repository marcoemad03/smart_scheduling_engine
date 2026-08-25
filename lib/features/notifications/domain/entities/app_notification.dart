import 'package:cloud_firestore/cloud_firestore.dart';

class AppNotification {
  final String id;
  final String userId;
  final String title;
  final String body;
  final String type;
  final bool isRead;
  final DateTime createdAt;

  AppNotification({
    required this.id,
    required this.userId,
    required this.title,
    required this.body,
    this.type = 'general',
    this.isRead = false,
    required this.createdAt,
  });

  factory AppNotification.fromDoc(String id, Map<String, dynamic> data) {
    return AppNotification(
      id: id,
      userId: data['userId'] as String? ?? '',
      title: data['title'] as String? ?? '',
      body: data['body'] as String? ?? '',
      type: data['type'] as String? ?? 'general',
      isRead: data['isRead'] as bool? ?? false,
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
        'userId': userId,
        'title': title,
        'body': body,
        'type': type,
        'isRead': isRead,
        'createdAt': Timestamp.fromDate(createdAt),
      };
}

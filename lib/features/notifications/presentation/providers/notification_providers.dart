import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reception_workforce_scheduler/core/providers.dart';
import 'package:reception_workforce_scheduler/features/notifications/domain/entities/app_notification.dart';

final myNotificationsProvider =
    StreamProvider<List<AppNotification>>((ref) {
  final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
  return ref
      .watch(firebaseFirestoreProvider)
      .collection('notifications')
      .where('userId', isEqualTo: uid)
      .orderBy('createdAt', descending: true)
      .limit(50)
      .snapshots()
      .map((s) =>
          s.docs.map((d) => AppNotification.fromDoc(d.id, d.data())).toList());
});

final unreadNotificationCountProvider = Provider<int>((ref) {
  return ref.watch(myNotificationsProvider).when(
        data: (list) => list.where((n) => !n.isRead).length,
        loading: () => 0,
        error: (_, __) => 0,
      );
});

class NotificationRepository {
  final FirebaseFirestore firestore;
  NotificationRepository({required this.firestore});

  Future<void> send({
    required String userId,
    required String title,
    required String body,
    String type = 'general',
  }) async {
    await firestore.collection('notifications').add(AppNotification(
          id: '',
          userId: userId,
          title: title,
          body: body,
          type: type,
          createdAt: DateTime.now(),
        ).toMap());
  }

  Future<void> markRead(String notificationId) async {
    await firestore
        .collection('notifications')
        .doc(notificationId)
        .update({'isRead': true});
  }
}

final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  return NotificationRepository(firestore: ref.watch(firebaseFirestoreProvider));
});

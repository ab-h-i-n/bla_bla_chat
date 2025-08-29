import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class FcmHandler {
  final _firebaseMessaging = FirebaseMessaging.instance;
  final _supabase = Supabase.instance.client;

  Future<void> initNotifications() async {
    await _firebaseMessaging.requestPermission();

    final fcmToken = await _firebaseMessaging.getToken();
    debugPrint('FCM Token: $fcmToken');

    if (fcmToken == null) {
      debugPrint('Could not get FCM token.');
      return;
    }

    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        debugPrint('No user logged in. Skipping token save.');
        return;
      }

      await _supabase
          .from('profiles')
          .update({'fcm_token': fcmToken})
          .eq('id', userId);

      debugPrint('FCM token ($fcmToken) saved to Supabase for user $userId');

    } catch (e) {
      debugPrint('Error saving FCM token to Supabase: $e');
    }
  }
}

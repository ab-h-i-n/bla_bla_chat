import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:googleapis_auth/auth_io.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';


final _serviceAccountCredentialsJson = dotenv.env['SERVICE_ACCOUNT_JSON'] ?? '';

Future<http.Client> _getAuthenticatedClient() async {
  final credentials = ServiceAccountCredentials.fromJson(jsonDecode(_serviceAccountCredentialsJson));
  final scopes = ['https://www.googleapis.com/auth/firebase.messaging'];
  
  // Get the authenticated client
  final client = await clientViaServiceAccount(credentials, scopes);
  return client;
}

Future<void> sendNotificationToUser({
  required String userId,
  required String title,
  required String body,
}) async {
  print('Attempting to send notification to user: $userId');


  //get token from Supabase
  final supabase = Supabase.instance.client;
  final response = await supabase
      .from('profiles')
      .select('fcm_token')
      .eq('id', userId)
      .single();

  final fcmToken = response['fcm_token'] ?? '';

  if (fcmToken.isEmpty) {
    print('Error: FCM token is empty for user $userId. Aborting.');
    return;
  }

  try {
    final httpClient = await _getAuthenticatedClient();

    final fcmEndpoint = 'https://fcm.googleapis.com/v1/projects/blabla-470016/messages:send';
    final messagePayload = {
      'message': {
        'token': fcmToken,
        'notification': {
          'title': title,
          'body': body,
        },
        'android': {
          'priority': 'high',
        },
      },
    };

    // The authenticated client automatically adds the 'Authorization: Bearer <OAUTH_TOKEN>' header.
    final httpResponse = await httpClient.post(
      Uri.parse(fcmEndpoint),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(messagePayload),
    );

    if (httpResponse.statusCode == 200) {
      print('✅ Notification sent successfully to user $userId.');
    } else {
      print('❌ Failed to send notification.');
      print('Status Code: ${httpResponse.statusCode}');
      print('Response Body: ${httpResponse.body}');
    }

    // Close the client when you're done
    httpClient.close();

  } catch (e) {
    print('An error occurred: $e');
  }
}
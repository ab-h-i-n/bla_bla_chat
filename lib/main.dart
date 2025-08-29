import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'login_page.dart';
import 'home_page.dart';
import 'services/update.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';


@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint("Handling a background message: ${message.messageId}");
}


Future<void> main() async {
   await dotenv.load(fileName: ".env");
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://tbwmusnyjkisbnktvrlb.supabase.co',
    anonKey: 'sb_publishable_uhRxDVMbnSrGdXKNC6x1wA_d7AjLr5-',
  );

  await Firebase.initializeApp();

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  runApp(MyApp());
}

final supabase = Supabase.instance.client;

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'BlaBla',
      theme: ThemeData.dark().copyWith(
        primaryColor: Colors.black,
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(foregroundColor: Colors.black),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            foregroundColor: Colors.white,
            backgroundColor: Colors.black,
          ),
        ),
      ),
      home: const AuthHandler(),
    );
  }
}

class AuthHandler extends StatelessWidget {
  const AuthHandler({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: supabase.auth.onAuthStateChange,
      builder: (context, snapshot) {
        if (snapshot.hasData && snapshot.data?.session != null) {
          // When the user is logged in, wrap the HomePage with the UpdateChecker.
          // The update check will be triggered when HomePage is shown.
          return const UpdateChecker(child: HomePage());
        } else {
          return const LoginPage();
        }
      },
    );
  }
}

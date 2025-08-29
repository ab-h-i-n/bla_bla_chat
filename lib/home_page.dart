import 'package:bla_bla/features/home/chat_section.dart';
import 'package:bla_bla/features/home/requests_section.dart';
import 'package:bla_bla/features/home/users_section.dart';
import 'package:bla_bla/handlers/fcm_handler.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final supabase = Supabase.instance.client;

  // Add the initState method here
  @override
  void initState() {
    super.initState();
    // Create an instance of FcmHandler and call the initialization method
    FcmHandler().initNotifications();

 
  }

  @override
  Widget build(BuildContext context) {
    // We return to using DefaultTabController to easily sync the TabBar and TabBarView.
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          title: const Text('BlaBla', style: TextStyle(color: Colors.white)),
          actions: [
            IconButton(
              icon: const Icon(Icons.logout, color: Colors.white),
              onPressed: () async {
                await supabase.auth.signOut();
              },
            ),
          ],
        ),
        // Using TabBarView brings back the swipe gesture between tabs.
        // To keep each tab's state alive, you will need to modify each
        // of the section widgets (ChatsSection, etc.) as explained below.
        body: const TabBarView(
          children: [ChatsSection(), RequestsSection(), UsersSection()],
        ),
        bottomNavigationBar: const Material(
          color: Colors.black,
          child: TabBar(
            padding: EdgeInsets.fromLTRB(0, 0, 0, 20),
            indicatorColor: Colors.white,
            unselectedLabelColor: Colors.grey,
            labelColor: Colors.white,
            tabs: [
              Tab(icon: Icon(Icons.chat_bubble)),
              Tab(icon: Icon(Icons.person_add)),
              Tab(icon: Icon(Icons.people)),
            ],
          ),
        ),
      ),
    );
  }
}

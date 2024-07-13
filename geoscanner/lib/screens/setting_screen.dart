import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SettingScreen extends StatefulWidget {
  const SettingScreen({super.key});

  @override
  State<SettingScreen> createState() => _SettingScreenState();
}

class _SettingScreenState extends State<SettingScreen> {
  late String userName = 'Loading...';
  late String userEmail = 'Loading...';

  @override
  void initState() {
    super.initState();
    loadUserData();
  }

  void loadUserData() async {
    User? user = FirebaseAuth.instance.currentUser;

    if (user != null) {
      DocumentSnapshot<Map<String, dynamic>> snapshot = await FirebaseFirestore
          .instance
          .collection('users')
          .doc(user.uid)
          .get();

      setState(() {
        userName = snapshot.exists
            ? snapshot.data()!['username'] ?? 'No User Name'
            : 'No User Name';
        userEmail = user.email ?? 'No User Email';
      });
    } else {
      setState(() {
        userName = 'No User Name';
        userEmail = 'No User Email';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            color: Colors.white,
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            child: Padding(
              padding: const EdgeInsets.only(left: 30, top: 0, right: 0, bottom: 5),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ListTile(
                    leading: const Icon(Icons.email,size: 25,),
                    title: const Text(
                      'Email',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(userEmail),
                  ),
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.person,size: 25,),
                    title: const Text(
                      'User',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(userName),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () {
              FirebaseAuth.instance.signOut();
            },
            icon: const Icon(Icons.logout, color: Colors.black),
            label: const Text('Logout',style: TextStyle(color: Colors.black),),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color.fromARGB(255, 243, 243, 243),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

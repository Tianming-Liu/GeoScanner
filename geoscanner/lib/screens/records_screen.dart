// lib/records_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:geoscanner/widgets/expandable_fab.dart';
import 'package:geoscanner/screens/record_detail_screen.dart';

class RecordsScreen extends StatefulWidget {
  const RecordsScreen({Key? key}) : super(key: key);

  @override
  State<RecordsScreen> createState() => _RecordsScreenState();
}

class _RecordsScreenState extends State<RecordsScreen> {
  late CollectionReference userRecords;
  String userId = '';
  String _sortField = 'startTime';
  bool _isDescending = true;

  @override
  void initState() {
    super.initState();
    _initializeUserRecords();
  }

  Future<void> _initializeUserRecords() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      userId = user.uid;
      userRecords = FirebaseFirestore.instance
          .collection('data')
          .doc(userId)
          .collection('records');
      setState(() {}); // Refresh the UI after initializing userRecords
    }
  }

  Future<void> _deleteRecord(String recordId) async {
    await userRecords.doc(recordId).delete();
  }

  String formatTime(String time) {
    List<String> parts = time.split('_');
    String datePart = parts[0];
    List<String> timePart = parts[1].split(':');
    String formattedTime =
        timePart.map((part) => part.padLeft(2, '0')).join(':');
    return '$datePart $formattedTime';
  }

  void _setSortField(String field) {
    setState(() {
      _sortField = field;
    });
  }

  void _toggleSortOrder() {
    setState(() {
      _isDescending = !_isDescending;
    });
  }

  void _navigateToDetailScreen(Map<String, dynamic> recordData) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RecordDetailScreen(recordData: recordData),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        userId.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : StreamBuilder<QuerySnapshot>(
                stream: userRecords
                    .orderBy(_sortField, descending: _isDescending)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}'));
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Center(child: Text('No records found.'));
                  }

                  final records = snapshot.data!.docs;

                  return ListView.builder(
                    itemCount: records.length,
                    itemBuilder: (context, index) {
                      final record = records[index];
                      final recordData = record.data() as Map<String, dynamic>;

                      return Slidable(
                        key: ValueKey(record.id),
                        endActionPane: ActionPane(
                          extentRatio: 0.25,
                          motion: const DrawerMotion(),
                          children: [
                            SlidableAction(
                              onPressed: (context) {
                                _deleteRecord(record.id);
                              },
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                              icon: Icons.delete,
                              label: 'Delete',
                              borderRadius: BorderRadius.circular(10),
                              spacing: 8.0,
                            ),
                          ],
                        ),
                        child: GestureDetector(
                          onTap: () {
                            _navigateToDetailScreen(recordData);
                          },
                          child: Card(
                            color: Colors.white,
                            elevation: 2,
                            margin: const EdgeInsets.symmetric(
                                vertical: 5, horizontal: 5),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 2.0),
                              child: ListTile(
                                leading:
                                    const Icon(Icons.article, color: Colors.blue),
                                title: Text(
                                  'Record ID: ${record.id.substring(record.id.length - 12)}',
                                  style: TextStyle(
                                      fontFamily: GoogleFonts.roboto().fontFamily,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14),
                                ),
                                subtitle: Text(
                                  'Start Time: ${formatTime(recordData['startTime'])}\nEnd Time: ${formatTime(recordData['endTime'])}',
                                  style: TextStyle(
                                      fontFamily: GoogleFonts.roboto().fontFamily,
                                      fontSize: 12),
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
        Positioned(
          bottom: 30.0,
          right: 36.0,
          child: ExpandableFab(
            distance: 110.0,
            children: [
              ActionButton(
                onPressed: _toggleSortOrder,
                icon: const Icon(Icons.trending_down),
              ),
              ActionButton(
                onPressed: _toggleSortOrder,
                icon: const Icon(Icons.trending_up),
              ),
              ActionButton(
                onPressed: () => _setSortField('startTime'),
                icon: const Icon(Icons.access_time),
              ),
              ActionButton(
                onPressed: () => _setSortField('sensorData'),
                icon: const Icon(Icons.dynamic_form),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

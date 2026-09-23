import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class TournamentsScreen extends StatelessWidget {
  const TournamentsScreen({Key? key}) : super(key: key);

  // एडमिन द्वारा नया मैच जोड़ने के लिए पॉप-अप डायलॉग बॉक्स
  void _showAddMatchDialog(BuildContext context) {
    final TextEditingController gameController = TextEditingController();
    final TextEditingController titleController = TextEditingController();
    final TextEditingController timeController = TextEditingController();
    final TextEditingController prizeController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add New Match (Admin Panel)'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: gameController,
                  decoration: const InputDecoration(labelText: 'Game Name (e.g. BGMI / Free Fire)'),
                ),
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(labelText: 'Match Title (e.g. Squad Erangel)'),
                ),
                TextField(
                  controller: timeController,
                  decoration: const InputDecoration(labelText: 'Match Timing (e.g. 8:00 PM)'),
                ),
                TextField(
                  controller: prizeController,
                  decoration: const InputDecoration(labelText: 'Prize Pool (e.g. ₹1000)'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple),
              onPressed: () async {
                if (gameController.text.isNotEmpty && titleController.text.isNotEmpty) {
                  await FirebaseFirestore.instance.collection('tournaments').add({
                    'gameName': gameController.text.trim(),
                    'title': titleController.text.trim(),
                    'matchTime': timeController.text.trim(),
                    'prizePool': prizeController.text.trim(),
                    'createdAt': FieldValue.serverTimestamp(),
                  });
                  if (!context.mounted) return;
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Match Added Successfully!')),
                  );
                }
              },
              child: const Text('Add Match', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ProEsportsArena Tournaments'),
        backgroundColor: Colors.deepPurple,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('tournaments')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text(
                'No matches available right now.\nClick the + button below to add a match.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            );
          }

          var matches = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(12.0),
            itemCount: matches.length,
            itemBuilder: (context, index) {
              var matchData = matches[index].data() as Map<String, dynamic>;
              String gameName = matchData['gameName'] ?? 'BGMI / Free Fire';
              String matchTitle = matchData['title'] ?? 'Custom Match';
              String matchTime = matchData['matchTime'] ?? 'TBA';
              String prizePool = matchData['prizePool'] ?? '₹500';

              return Card(
                elevation: 4,
                margin: const EdgeInsets.symmetric(vertical: 8.0),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Chip(
                            label: Text(gameName, style: const TextStyle(color: Colors.white)),
                            backgroundColor: Colors.deepPurpleAccent,
                          ),
                          Text(
                            'Prize: $prizePool',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Colors.green,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        matchTitle,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.access_time, size: 18, color: Colors.grey),
                          const SizedBox(width: 6),
                          Text(
                            'Timing: $matchTime',
                            style: const TextStyle(fontSize: 15, color: Colors.black87),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.deepPurple,
                          ),
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Successfully Registered for the Match!')),
                            );
                          },
                          child: const Text('Join Match', style: TextStyle(color: Colors.white)),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      // एडमिन के लिए स्क्रीन पर नीचे (+) बटन दिया गया है जिससे नया मैच जोड़ सकते हैं
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.deepPurple,
        onPressed: () => _showAddMatchDialog(context),
        child: const Icon(Icons.add, color: Colors.white),
        tooltip: 'Add Match (Admin)',
      ),
    );
  }
}
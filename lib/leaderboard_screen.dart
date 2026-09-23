import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class LeaderboardScreen extends StatelessWidget {
  const LeaderboardScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ProEsportsArena Leaderboard'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .orderBy('points', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No players found on leaderboard.'));
          }

          var userDocs = snapshot.data!.docs;

          return ListView.builder(
            itemCount: userDocs.length,
            itemBuilder: (context, index) {
              var userData = userDocs[index].data() as Map<String, dynamic>;
              String username = userData['username'] ?? 'Gamer';
              var points = userData['points'] ?? 0;
              int rank = index + 1;

              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: rank == 1 ? Colors.amber : Colors.blueGrey,
                  child: Text('$rank', style: const TextStyle(color: Colors.white)),
                ),
                title: Text(username, style: const TextStyle(fontWeight: FontWeight.bold)),
                trailing: Text('$points pts', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blue)),
              );
            },
          );
        },
      ),
    );
  }
}
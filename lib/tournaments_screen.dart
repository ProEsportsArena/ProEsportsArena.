import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:convert';
import 'dart:typed_data';

// ==========================================
// 1. TOURNAMENTS SCREEN (PLAYERS VIEW)
// ==========================================
class TournamentsScreen extends StatefulWidget {
  const TournamentsScreen({Key? key}) : super(key: key);

  @override
  State<TournamentsScreen> createState() => _TournamentsScreenState();
}

class _TournamentsScreenState extends State<TournamentsScreen> {
  String selectedGame = 'Free Fire';
  final List<String> gamesList = ['Free Fire', 'BGMI', 'Call of Duty', 'Valorant'];

  Widget _buildBannerImage(String? bannerUrl) {
    if (bannerUrl != null && bannerUrl.isNotEmpty) {
      if (bannerUrl.startsWith('data:image')) {
        try {
          String base64String = bannerUrl.split(',').last;
          Uint8List decodedBytes = base64Decode(base64String);
          return Image.memory(decodedBytes, fit: BoxFit.cover, height: 140, width: double.infinity);
        } catch (e) {
          return Container(height: 140, color: Colors.deepPurple.shade100, child: const Icon(Icons.sports_esports, size: 50, color: Colors.deepPurple));
        }
      } else {
        return Image.network(
          bannerUrl,
          fit: BoxFit.cover,
          height: 140,
          width: double.infinity,
          errorBuilder: (context, error, stackTrace) => Container(height: 140, color: Colors.deepPurple.shade100, child: const Icon(Icons.sports_esports, size: 50, color: Colors.deepPurple)),
        );
      }
    }
    return Container(height: 140, color: Colors.deepPurple.shade100, child: const Icon(Icons.sports_esports, size: 50, color: Colors.deepPurple));
  }

  void _showSecureRoomDetails(BuildContext context, String roomId, String roomPassword) {
    bool isNotProvided = roomId == 'Not Provided Yet' || roomId.isEmpty || roomPassword == 'Not Provided Yet' || roomPassword.isEmpty;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: Row(
          children: [
            Icon(isNotProvided ? Icons.access_time_filled : Icons.lock_open, color: isNotProvided ? Colors.orange : Colors.green),
            const SizedBox(width: 8),
            const Text('Room Credentials', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: isNotProvided
            ? const Padding(
                padding: EdgeInsets.symmetric(vertical: 10.0),
                child: Text(
                  '⏳ Admin ne abhi Room ID aur Password update nahi kiya hai!\n\nMatch shuru hone se 10 minute pehle yahin par asli ID aur Password dikhne lagega.',
                  style: TextStyle(fontSize: 14, height: 1.4, color: Colors.black87),
                  textAlign: TextAlign.center,
                ),
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Match shuru hone se 10 minute pehle room me enter karein:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 15),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Room ID: $roomId', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.blue)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Password: $roomPassword', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.red)),
                      ],
                    ),
                  ),
                ],
              ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close', style: TextStyle(color: Colors.deepPurple, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> joinTournament(String tournamentId, double entryFee, int maxSlots, List participants) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pehle login karein!')));
      return;
    }

    if (participants.length >= maxSlots) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sorry! Tournament slots are full.')));
      return;
    }

    final userRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
    final tournamentRef = FirebaseFirestore.instance.collection('tournaments').doc(tournamentId);

    try {
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        DocumentSnapshot snapshot = await transaction.get(userRef);
        if (!snapshot.exists) throw Exception("User data nahi mila!");

        double currentBalance = double.tryParse((snapshot.data() as Map<String, dynamic>)['walletBalance']?.toString() ?? '0') ?? 0.0;

        if (currentBalance < entryFee) {
          throw Exception("Wallet mein paryapt balance nahi hai!");
        }

        transaction.update(userRef, {'walletBalance': currentBalance - entryFee});
        transaction.update(tournamentRef, {
          'participants': FieldValue.arrayUnion([user.uid])
        });
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Successfully Joined! Entry fee deducted.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tournaments & Room Details'),
        backgroundColor: Colors.deepPurple,
        actions: [
          IconButton(
            icon: const Icon(Icons.admin_panel_settings, color: Colors.amber),
            tooltip: 'Admin Panel',
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const AdminPanelScreen()));
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // ⚠️ Strict Warning Notice Banner Added Here
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              border: Border.all(color: Colors.red.shade300),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Strict Rule: Match ke dauran hacking, mod ya virus ka use karne par ID turant ban kar diya jayega!',
                    style: TextStyle(
                      color: Colors.red.shade800,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),

          Container(
            height: 60,
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: gamesList.length,
              itemBuilder: (context, index) {
                String game = gamesList[index];
                bool isSelected = selectedGame == game;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: ChoiceChip(
                    label: Text(game),
                    selected: isSelected,
                    selectedColor: Colors.deepPurple,
                    labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.black, fontWeight: FontWeight.bold),
                    onSelected: (selected) {
                      setState(() {
                        selectedGame = game;
                      });
                    },
                  ),
                );
              },
            ),
          ),
          const Divider(),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('tournaments').where('game', isEqualTo: selectedGame).snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(child: Text('$selectedGame ke liye koi tournament uplabdh nahi hai.', style: const TextStyle(fontSize: 15, color: Colors.grey)));
                }

                var tournaments = snapshot.data!.docs;

                return ListView.builder(
                  itemCount: tournaments.length,
                  itemBuilder: (context, index) {
                    var doc = tournaments[index];
                    var data = doc.data() as Map<String, dynamic>;
                    
                    String title = data['title']?.toString() ?? 'Tournament';
                    double entryFee = double.tryParse(data['entryFee']?.toString() ?? '0') ?? 0.0;
                    String prizePool = data['prizePool']?.toString() ?? '0';
                    int maxSlots = int.tryParse(data['maxSlots']?.toString() ?? '48') ?? 48;
                    String roomId = data['roomId']?.toString() ?? 'Not Provided Yet';
                    String roomPassword = data['roomPassword']?.toString() ?? 'Not Provided Yet';
                    String bannerUrl = data['bannerUrl']?.toString() ?? '';

                    List participants = data['participants'] ?? [];
                    bool hasJoined = currentUserId != null && participants.contains(currentUserId);
                    bool isFull = participants.length >= maxSlots;

                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      elevation: 4,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildBannerImage(bannerUrl),
                          Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 2),
                                Text('Slots: ${participants.length}/$maxSlots', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isFull ? Colors.red : Colors.green)),
                                const SizedBox(height: 5),
                                Text('Entry Fee: ₹$entryFee | Prize Pool: ₹$prizePool', style: const TextStyle(fontWeight: FontWeight.w500)),
                                const Divider(height: 20),
                                hasJoined
                                    ? SizedBox(
                                        width: double.infinity,
                                        child: ElevatedButton.icon(
                                          style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                                          icon: const Icon(Icons.lock_open),
                                          label: const Text('View Room ID & Password'),
                                          onPressed: () => _showSecureRoomDetails(context, roomId, roomPassword),
                                        ),
                                      )
                                    : SizedBox(
                                        width: double.infinity,
                                        child: ElevatedButton(
                                          style: ElevatedButton.styleFrom(backgroundColor: isFull ? Colors.grey : Colors.deepPurple),
                                          onPressed: isFull ? null : () => joinTournament(doc.id, entryFee, maxSlots, participants),
                                          child: Text(isFull ? 'Tournament Full' : 'Join Tournament (Fee: ₹$entryFee)', style: const TextStyle(color: Colors.white)),
                                        ),
                                      ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// 2. ADMIN PANEL SCREEN (PUBLISH & UPDATE ROOM ID)
// ==========================================
class AdminPanelScreen extends StatefulWidget {
  const AdminPanelScreen({Key? key}) : super(key: key);

  @override
  State<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends State<AdminPanelScreen> {
  final _titleController = TextEditingController();
  final _entryFeeController = TextEditingController();
  final _prizePoolController = TextEditingController();
  final _maxSlotsController = TextEditingController(text: '48');
  String _selectedGameForPublish = 'Free Fire';

  Future<void> _publishTournament() async {
    if (_titleController.text.isEmpty || _entryFeeController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sabhi fields bharein!')));
      return;
    }

    try {
      await FirebaseFirestore.instance.collection('tournaments').add({
        'title': _titleController.text,
        'game': _selectedGameForPublish,
        'entryFee': double.parse(_entryFeeController.text),
        'prizePool': _prizePoolController.text,
        'maxSlots': int.parse(_maxSlotsController.text),
        'roomId': 'Not Provided Yet',
        'roomPassword': 'Not Provided Yet',
        'participants': [],
        'createdAt': FieldValue.serverTimestamp(),
      });

      _titleController.clear();
      _entryFeeController.clear();
      _prizePoolController.clear();
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tournament Successfully Published!')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  void _showUpdateRoomDialog(String tournamentId, String currentRoomId, String currentPass) {
    final roomIdController = TextEditingController(text: currentRoomId == 'Not Provided Yet' ? '' : currentRoomId);
    final roomPassController = TextEditingController(text: currentPass == 'Not Provided Yet' ? '' : currentPass);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Update Room Credentials'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: roomIdController, decoration: const InputDecoration(labelText: 'Room ID')),
            const SizedBox(height: 10),
            TextField(controller: roomPassController, decoration: const InputDecoration(labelText: 'Room Password')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple),
            onPressed: () async {
              await FirebaseFirestore.instance.collection('tournaments').doc(tournamentId).update({
                'roomId': roomIdController.text.trim(),
                'roomPassword': roomPassController.text.trim(),
              });
              if (!mounted) return;
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Room ID & Password Updated!')));
            },
            child: const Text('Save', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Admin Panel - Manage Tournaments'), backgroundColor: Colors.deepPurple),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Naya Tournament Publish Karein', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: _selectedGameForPublish,
              items: ['Free Fire', 'BGMI', 'Call of Duty', 'Valorant'].map((game) => DropdownMenuItem(value: game, child: Text(game))).toList(),
              onChanged: (val) => setState(() => _selectedGameForPublish = val!),
              decoration: const InputDecoration(labelText: 'Select Game', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 10),
            TextField(controller: _titleController, decoration: const InputDecoration(labelText: 'Tournament Title (jaise: FF Solo #1)', border: OutlineInputBorder())),
            const SizedBox(height: 10),
            TextField(controller: _entryFeeController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Entry Fee (₹)', border: OutlineInputBorder())),
            const SizedBox(height: 10),
            TextField(controller: _prizePoolController, decoration: const InputDecoration(labelText: 'Prize Pool (₹)', border: OutlineInputBorder())),
            const SizedBox(height: 10),
            TextField(controller: _maxSlotsController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Max Slots', border: OutlineInputBorder())),
            const SizedBox(height: 15),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple, padding: const EdgeInsets.all(14)),
                onPressed: _publishTournament,
                child: const Text('Publish Tournament', style: TextStyle(color: Colors.white, fontSize: 16)),
              ),
            ),
            const Divider(height: 40),
            const Text('Existing Tournaments (Room ID Update Karein)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('tournaments').orderBy('createdAt', descending: true).snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const CircularProgressIndicator();
                var docs = snapshot.data!.docs;
                if (docs.isEmpty) return const Text('Koi tournament available nahi hai.');

                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    var data = docs[index].data() as Map<String, dynamic>;
                    String docId = docs[index].id;
                    return Card(
                      child: ListTile(
                        title: Text(data['title'] ?? 'Tournament'),
                        subtitle: Text('Game: ${data['game']} | Room ID: ${data['roomId']}'),
                        trailing: IconButton(
                          icon: const Icon(Icons.edit, color: Colors.deepPurple),
                          onPressed: () => _showUpdateRoomDialog(docId, data['roomId'] ?? '', data['roomPassword'] ?? ''),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
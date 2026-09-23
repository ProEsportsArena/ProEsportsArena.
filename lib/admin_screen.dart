import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:convert';
import 'dart:typed_data';

class AdminScreen extends StatefulWidget {
  const AdminScreen({Key? key}) : super(key: key);

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Tournament Controllers
  final _titleController = TextEditingController();
  final _entryFeeController = TextEditingController();
  final _prizePoolController = TextEditingController();
  final _maxSlotsController = TextEditingController();
  
  String _selectedGame = 'BGMI';
  String _selectedMap = 'Bermuda';
  String? _selectedImageBase64;
  bool _isLoading = false;

  final List<String> _gameList = ['BGMI', 'PUBG Mobile', 'Free Fire', 'COD Mobile', 'Valorant'];
  final List<String> _mapList = ['Bermuda', 'Purgatory', 'Kalahari', 'Alpine', 'Erangel'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this); // अब 3 टैब हैं
  }

  @override
  void dispose() {
    _tabController.dispose();
    _titleController.dispose();
    _entryFeeController.dispose();
    _prizePoolController.dispose();
    _maxSlotsController.dispose();
    super.dispose();
  }

  // गैलरी से बैनर इमेज चुनने का फंक्शन
  Future<void> _pickBannerImage() async {
    final ImagePicker picker = ImagePicker();
    try {
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 50,
      );

      if (image != null) {
        Uint8List bytes = await image.readAsBytes();
        String base64Image = base64Encode(bytes);
        setState(() {
          _selectedImageBase64 = 'data:image/jpeg;base64,$base64Image';
        });

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Banner Image Selected Successfully! / बैनर फोटो चुन ली गई है!')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking image: $e')),
      );
    }
  }

  // 1. Create Tournament Logic (गेम और Base64 इमेज के साथ)
  Future<void> _createTournament() async {
    if (_titleController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter tournament title! / कृपया टूर्नामेंट का नाम दर्ज करें!')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await FirebaseFirestore.instance.collection('tournaments').add({
        'title': _titleController.text.trim(),
        'game': _selectedGame, // यहाँ गेम का नाम सेव होगा (BGMI/PUBG आदि)
        'entryFee': double.tryParse(_entryFeeController.text.trim()) ?? 0.0,
        'prizePool': double.tryParse(_prizePoolController.text.trim()) ?? 0.0,
        'maxSlots': int.tryParse(_maxSlotsController.text.trim()) ?? 50,
        'map': _selectedMap,
        'bannerUrl': _selectedImageBase64 ?? '',
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tournament Published Successfully! / टूर्नामेंट पब्लिश हो गया!')),
      );

      _titleController.clear();
      _entryFeeController.clear();
      _prizePoolController.clear();
      _maxSlotsController.clear();
      setState(() {
        _selectedImageBase64 = null;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // 2. Delete Tournament Logic (टूर्नामेंट डिलीट करने का फंक्शन)
  Future<void> _deleteTournament(String docId) async {
    try {
      await FirebaseFirestore.instance.collection('tournaments').doc(docId).delete();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tournament Deleted Successfully! / टूर्नामेंट डिलीट हो गया!')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete: $e')),
      );
    }
  }

  // 3. Wallet Request Approve / Reject Logic
  Future<void> _updateWalletRequest(String docId, String userId, double amount, String type, String status) async {
    try {
      await FirebaseFirestore.instance.collection('wallet_requests').doc(docId).update({
        'status': status,
      });

      if (status == 'approved' && type == 'Deposit') {
        final userRef = FirebaseFirestore.instance.collection('users').doc(userId);
        await FirebaseFirestore.instance.runTransaction((transaction) async {
          final snapshot = await transaction.get(userRef);
          if (snapshot.exists) {
            double currentWallet = (snapshot.data()?['walletBalance'] ?? 0.0).toDouble();
            transaction.update(userRef, {'walletBalance': currentWallet + amount});
          }
        });
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Request $status successfully! / अनुरोध सफलतापूर्वक अपडेट हुआ!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Admin Panel / एडमिन पैनल',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.deepPurple,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.amber,
          indicatorWeight: 4.0,
          isScrollable: true,
          tabs: const [
            Tab(child: Text('Create / नया बनाएं', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold))),
            Tab(child: Text('Manage / डिलीट करें', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold))),
            Tab(child: Text('Wallet / वॉलेट', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold))),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // TAB 1: Create Tournament
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Center(
              child: SizedBox(
                width: 600,
                child: ListView(
                  children: [
                    const SizedBox(height: 10),
                    const Text(
                      'Create New eSports Tournament / नया टूर्नामेंट बनाएं',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.deepPurple),
                    ),
                    const SizedBox(height: 20),
                    
                    // Game Selector Dropdown
                    DropdownButtonFormField<String>(
                      value: _selectedGame,
                      decoration: const InputDecoration(
                        labelText: 'Select Game / गेम चुनें (BGMI / PUBG आदि)',
                        border: OutlineInputBorder(),
                      ),
                      items: _gameList.map((String game) {
                        return DropdownMenuItem<String>(
                          value: game,
                          child: Text(game, style: const TextStyle(fontWeight: FontWeight.bold)),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        if (newValue != null) {
                          setState(() => _selectedGame = newValue);
                        }
                      },
                    ),
                    const SizedBox(height: 15),

                    TextField(
                      controller: _titleController,
                      decoration: const InputDecoration(
                        labelText: 'Tournament Title / टूर्नामेंट का नाम',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 15),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _entryFeeController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Entry Fee (₹) / एंट्री फीस',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 15),
                        Expanded(
                          child: TextField(
                            controller: _prizePoolController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Prize Pool (₹) / प्राइज पूल',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 15),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _maxSlotsController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Max Slots / अधिकतम स्लॉट',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 15),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _selectedMap,
                            decoration: const InputDecoration(
                              labelText: 'Select Map / मैप चुनें',
                              border: OutlineInputBorder(),
                            ),
                            items: _mapList.map((String map) {
                              return DropdownMenuItem<String>(
                                value: map,
                                child: Text(map),
                              );
                            }).toList(),
                            onChanged: (String? newValue) {
                              if (newValue != null) {
                                setState(() => _selectedMap = newValue);
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    
                    // Gallery Image Picker Button
                    Row(
                      children: [
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple),
                          onPressed: _pickBannerImage,
                          icon: const Icon(Icons.image, color: Colors.white),
                          label: const Text('Pick Banner Image / बैनर फोटो', style: TextStyle(color: Colors.white)),
                        ),
                        const SizedBox(width: 15),
                        if (_selectedImageBase64 != null)
                          const Text('Image Selected ✓', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold))
                        else
                          const Text('No image chosen', style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                    const SizedBox(height: 30),
                    _isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : SizedBox(
                            height: 50,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple),
                              onPressed: _createTournament,
                              child: const Text(
                                'Publish Tournament / टूर्नामेंट पब्लिश करें',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                            ),
                          ),
                  ],
                ),
              ),
            ),
          ),

          // TAB 2: Manage / Delete Tournaments (टूर्नामेंट्स देखने और डिलीट करने के लिए)
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('tournaments').orderBy('createdAt', descending: true).snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Center(child: Text('No tournaments found to manage.'));
              }

              final docs = snapshot.data!.docs;

              return ListView.builder(
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final data = docs[index].data() as Map<String, dynamic>;
                  final docId = docs[index].id;
                  final title = data['title'] ?? 'Tournament';
                  final game = data['game'] ?? 'BGMI';
                  final prize = data['prizePool'] ?? 0.0;

                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.deepPurple.shade100,
                        child: const Icon(Icons.sports_esports, color: Colors.deepPurple),
                      ),
                      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('Game: $game | Prize: ₹$prize'),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _deleteTournament(docId), // डिलीट बटन
                        tooltip: 'Delete Tournament',
                      ),
                    ),
                  );
                },
              );
            },
          ),

          // TAB 3: Wallet Approvals
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('wallet_requests').where('status', isEqualTo: 'pending').snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Center(child: Text('No pending wallet requests / कोई अनुरोध नहीं है'));
              }

              final docs = snapshot.data!.docs;

              return ListView.builder(
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final data = docs[index].data() as Map<String, dynamic>;
                  final docId = docs[index].id;
                  final userName = data['userName'] ?? 'User';
                  final amount = (data['amount'] ?? 0.0).toDouble();
                  final type = data['type'] ?? 'Deposit';
                  final userId = data['userId'] ?? '';
                  final details = data['details'] ?? 'N/A';

                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    elevation: 3,
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: type == 'Deposit' ? Colors.green.shade100 : Colors.orange.shade100,
                        child: Icon(
                          type == 'Deposit' ? Icons.arrow_downward : Icons.arrow_upward,
                          color: type == 'Deposit' ? Colors.green : Colors.orange,
                        ),
                      ),
                      title: Text('$type Request: ₹$amount', style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('User: $userName\nDetails: $details'),
                      isThreeLine: true,
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.check_circle, color: Colors.green, size: 30),
                            onPressed: () => _updateWalletRequest(docId, userId, amount, type, 'approved'),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.cancel, color: Colors.red, size: 30),
                            onPressed: () => _updateWalletRequest(docId, userId, amount, type, 'rejected'),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}
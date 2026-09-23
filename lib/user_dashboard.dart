import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'tournaments_screen.dart';
import 'wallet_referral_screen.dart';
import 'admin_screen.dart';
import 'countdown_timer_widget.dart';

class UserDashboard extends StatelessWidget {
  const UserDashboard({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'ProEsportsArena Dashboard',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
            letterSpacing: 0.5,
          ),
        ),
        backgroundColor: Colors.deepPurple.shade900,
        elevation: 4,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            tooltip: 'Logout',
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance.collection('users').doc(user?.uid).snapshots(),
          builder: (context, snapshot) {
            double balance = 0.0;
            String referralCode = 'LOADING...';
            
            if (snapshot.hasData && snapshot.data!.exists) {
              var data = snapshot.data!.data() as Map<String, dynamic>;
              balance = (data['walletBalance'] ?? 0.0).toDouble();
              referralCode = data['referralCode'] ?? user?.uid.substring(0, 6).toUpperCase() ?? 'ESPORTS123';
            }

            // Check if current logged-in user is admin
            bool isAdmin = user?.email == 'amit839026@gmail.com';

            return ListView(
              children: [
                // 1. User Profile & Wallet Banner
                Card(
                  elevation: 4,
                  color: Colors.deepPurple.shade50,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user?.email ?? 'User',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.deepPurple),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Wallet: ₹$balance', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.green)),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (context) => const WalletReferralScreen()),
                                );
                              },
                              icon: const Icon(Icons.account_balance_wallet, size: 16, color: Colors.white),
                              label: const Text('Wallet / Add Funds', style: TextStyle(color: Colors.white)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // 2. My Joined Matches & History
                const Text(
                  '🎮 My Joined Matches & History',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.deepPurple),
                ),
                const SizedBox(height: 10),

                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('tournaments')
                      .where('participants', arrayContains: user?.uid)
                      .snapshots(),
                  builder: (context, matchSnapshot) {
                    if (matchSnapshot.hasError) {
                      return Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Text(
                          'Error: ${matchSnapshot.error}',
                          style: const TextStyle(color: Colors.red, fontSize: 12),
                        ),
                      );
                    }

                    if (matchSnapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(20.0),
                          child: CircularProgressIndicator(),
                        ),
                      );
                    }

                    if (!matchSnapshot.hasData || matchSnapshot.data!.docs.isEmpty) {
                      return Card(
                        elevation: 1,
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Text(
                            'Aapne abhi tak koi match join nahi kiya hai!',
                            style: TextStyle(color: Colors.grey.shade600, fontStyle: FontStyle.italic),
                          ),
                        ),
                      );
                    }

                    var joinedMatches = matchSnapshot.data!.docs;

                    return ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: joinedMatches.length,
                      itemBuilder: (context, index) {
                        var matchData = joinedMatches[index].data() as Map<String, dynamic>;
                        String matchTitle = matchData['title'] ?? 'Tournament Match';
                        String gameName = matchData['game'] ?? 'Free Fire';
                        String prizePool = matchData['prizePool']?.toString() ?? '0';
                        String prizeWon = matchData['prizeWon']?.toString() ?? '0';

                        DateTime matchTime = matchData['scheduleTime'] != null
                            ? (matchData['scheduleTime'] as Timestamp).toDate()
                            : DateTime.now().add(const Duration(hours: 1));

                        return Card(
                          elevation: 3,
                          margin: const EdgeInsets.only(bottom: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          child: Padding(
                            padding: const EdgeInsets.all(14.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        matchTitle,
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                      ),
                                    ),
                                    CountdownTimerWidget(matchTime: matchTime),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Chip(
                                      label: Text(gameName),
                                      backgroundColor: Colors.deepPurple.shade100,
                                      labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                    ),
                                    Text(
                                      'Prize Pool: ₹$prizePool',
                                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
                                    ),
                                  ],
                                ),
                                const Divider(height: 16),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      '🏆 Won Prize / History:',
                                      style: TextStyle(fontWeight: FontWeight.bold, color: Colors.deepOrange),
                                    ),
                                    Text(
                                      '₹$prizeWon',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.amber),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
                const SizedBox(height: 20),

                // 3. Play eSports Tournaments Card
                Card(
                  elevation: 3,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(16),
                    leading: const CircleAvatar(
                      backgroundColor: Colors.deepPurple,
                      child: Icon(Icons.sports_esports, color: Colors.white),
                    ),
                    title: const Text('Play eSports Tournaments', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    subtitle: const Text('Join matches, win cash prizes & trigger bonus!'),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const TournamentsScreen()),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 15),

                // 4. In-Game Profile / UID Setup Card
                Card(
                  elevation: 3,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(16),
                    leading: const CircleAvatar(
                      backgroundColor: Colors.blue,
                      child: Icon(Icons.person_add, color: Colors.white),
                    ),
                    title: const Text('Set In-Game Profile (UID)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    subtitle: const Text('Apni Free Fire/BGMI UID aur IGN yahan save karein'),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () {
                      _showProfileDialog(context, user?.uid);
                    },
                  ),
                ),
                const SizedBox(height: 15),

                // 5. Refer & Earn Card
                Card(
                  elevation: 3,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(16),
                    leading: const CircleAvatar(
                      backgroundColor: Colors.amber,
                      child: Icon(Icons.card_giftcard, color: Colors.white),
                    ),
                    title: const Text('Refer & Earn ₹5', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    subtitle: const Text('Share code, friends add funds & play to get bonus!'),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () {
                      _showReferralDialog(context, referralCode);
                    },
                  ),
                ),
                const SizedBox(height: 15),

                // 6. Top Players Leaderboard Card
                Card(
                  elevation: 3,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '🔥 Top Players Leaderboard',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.deepPurple),
                        ),
                        const SizedBox(height: 12),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const CircleAvatar(backgroundColor: Colors.amber, child: Text('1', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                          title: const Text('Pro_Gamer_99', style: TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: const Text('Total Winnings: ₹2,500'),
                          trailing: const Text('👑', style: TextStyle(fontSize: 20)),
                        ),
                        const Divider(height: 12),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const CircleAvatar(backgroundColor: Colors.grey, child: Text('2', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                          title: const Text('Shadow_Sniper', style: TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: const Text('Total Winnings: ₹1,800'),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 15),

                // 7. Help & Support Card
                Card(
                  elevation: 3,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(16),
                    leading: const CircleAvatar(
                      backgroundColor: Colors.teal,
                      child: Icon(Icons.support_agent, color: Colors.white),
                    ),
                    title: const Text('Help & Support', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    subtitle: const Text('Koi samasya hai? Humse support par contact karein'),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('📞 Contact Support'),
                          content: const Text('Agar aapko match join karne ya wallet me paisa add karne me koi dikkat aa rahi hai, toh aap humein support email ya WhatsApp par message kar sakte hain.\n\nEmail: support@proesports.com'),
                          actions: [
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
                              onPressed: () => Navigator.pop(context),
                              child: const Text('OK', style: TextStyle(color: Colors.white)),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),

                // 8. Admin Panel Button (Visible ONLY to Admin Email)
                if (isAdmin) ...[
                  const SizedBox(height: 25),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade700,
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const AdminScreen()),
                        );
                      },
                      child: const Text(
                        'Admin Panel (Only for You)',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  // Referral Dialog popup
  void _showReferralDialog(BuildContext context, String referralCode) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('🎁 Refer & Earn ₹5'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Apna unique referral code dosto ke sath share karein. Jab dost app join karke funds add karenge, aapko bonus milega!'),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.deepPurple),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    referralCode,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1.2),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy, color: Colors.deepPurple),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: referralCode));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Referral Code Copied to Clipboard!')),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple),
            onPressed: () => Navigator.pop(context),
            child: const Text('Close', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // In-Game Profile Setup Dialog popup
  void _showProfileDialog(BuildContext context, String? userId) {
    final TextEditingController ignController = TextEditingController();
    final TextEditingController uidController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('🎮 In-Game Profile Setup'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: ignController,
              decoration: const InputDecoration(labelText: 'In-Game Name (IGN)'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: uidController,
              decoration: const InputDecoration(labelText: 'Game UID (e.g. 123456789)'),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple),
            onPressed: () async {
              if (ignController.text.isNotEmpty && uidController.text.isNotEmpty) {
                await FirebaseFirestore.instance.collection('users').doc(userId).update({
                  'ingameName': ignController.text,
                  'gameUid': uidController.text,
                });
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Profile Saved Successfully!')),
                );
              }
            },
            child: const Text('Save', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
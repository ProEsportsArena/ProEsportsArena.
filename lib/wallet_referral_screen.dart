import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';

class WalletReferralScreen extends StatefulWidget {
  const WalletReferralScreen({Key? key}) : super(key: key);

  @override
  State<WalletReferralScreen> createState() => _WalletReferralScreenState();
}

class _WalletReferralScreenState extends State<WalletReferralScreen> {
  // Controllers
  final TextEditingController _referralCodeController = TextEditingController();
  final TextEditingController _addAmountController = TextEditingController();
  final TextEditingController _utrController = TextEditingController();
  final TextEditingController _withdrawAmountController = TextEditingController();
  final TextEditingController _upiIdController = TextEditingController();
  final TextEditingController _accountNumberController = TextEditingController();
  final TextEditingController _ifscController = TextEditingController();

  String _withdrawType = 'upi'; // 'upi' or 'bank'
  final User? currentUser = FirebaseAuth.instance.currentUser;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _checkAndCreateUserDocument();
    _fetchLastUsedPayoutDetails();
  }

  @override
  void dispose() {
    _referralCodeController.dispose();
    _addAmountController.dispose();
    _utrController.dispose();
    _withdrawAmountController.dispose();
    _upiIdController.dispose();
    _accountNumberController.dispose();
    _ifscController.dispose();
    super.dispose();
  }

  // Yadi database me user ka document nahi hai, toh naya bana dega
  Future<void> _checkAndCreateUserDocument() async {
    if (currentUser == null) return;
    
    try {
      final userRef = FirebaseFirestore.instance.collection('users').doc(currentUser!.uid);
      final docSnapshot = await userRef.get();

      if (!docSnapshot.exists) {
        String generatedCode = 'REF${currentUser!.uid.substring(0, 6).toUpperCase()}';
        await userRef.set({
          'email': currentUser!.email ?? 'User',
          'walletBalance': 0.0,
          'referralCode': generatedCode,
          'referredBy': '',
          'hasPlayedFirstMatch': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      debugPrint('Error: $e');
    }
  }

  // User ke pichle add fund ya withdrawal se UPI / Bank details auto-fetch karna
  Future<void> _fetchLastUsedPayoutDetails() async {
    if (currentUser == null) return;
    try {
      var userDoc = await FirebaseFirestore.instance.collection('users').doc(currentUser!.uid).get();
      if (userDoc.exists) {
        var data = userDoc.data() as Map<String, dynamic>;
        if (data.containsKey('lastUpiId') && data['lastUpiId'] != null) {
          setState(() {
            _upiIdController.text = data['lastUpiId'];
          });
        }
      }

      var query = await FirebaseFirestore.instance
          .collection('withdrawal_requests')
          .where('userId', isEqualTo: currentUser!.uid)
          .orderBy('timestamp', descending: true)
          .limit(1)
          .get();

      if (query.docs.isNotEmpty) {
        var wData = query.docs.first.data();
        var payout = wData['payoutDetails'] as Map<String, dynamic>?;
        if (payout != null) {
          if (payout['type'] == 'upi' && payout['upiId'] != null) {
            setState(() {
              _withdrawType = 'upi';
              _upiIdController.text = payout['upiId'];
            });
          } else if (payout['type'] == 'bank') {
            setState(() {
              _withdrawType = 'bank';
              _accountNumberController.text = payout['accountNumber'] ?? '';
              _ifscController.text = payout['ifsc'] ?? '';
            });
          }
        }
      }
    } catch (e) {
      debugPrint('Auto-fetch error: $e');
    }
  }

  // Cross-Platform UPI Intent Function (Android & iOS dono ke liye)
  Future<void> _openUpiAppForPayment() async {
    double? amount = double.tryParse(_addAmountController.text.trim());
    if (amount == null || amount < 20) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kripya minimum ₹20 enter karein! / Minimum ₹20')),
      );
      return;
    }

    String upiUrl = 'upi://pay?pa=Proesportsarena@axl&pn=ProEsportsArena&am=$amount&cu=INR';
    Uri uri = Uri.parse(upiUrl);

    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Koi UPI App nahi mila! / No UPI App found')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  // Referral code apply karne ka function
  Future<void> _applyReferralCode() async {
    String code = _referralCodeController.text.trim().toUpperCase();
    if (code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kripya sahi referral code / Coupon code daalein!')),
      );
      return;
    }

    if (currentUser == null) return;

    setState(() => _isLoading = true);
    try {
      DocumentReference userRef = FirebaseFirestore.instance.collection('users').doc(currentUser!.uid);
      DocumentSnapshot userSnapshot = await userRef.get();

      if (userSnapshot.exists) {
        var data = userSnapshot.data() as Map<String, dynamic>;
        
        if (data.containsKey('referredBy') && data['referredBy'] != null && data['referredBy'].toString().isNotEmpty) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Aapne pehle hi ek referral code use kar liya hai!')),
          );
          setState(() => _isLoading = false);
          return;
        }

        if (data['referralCode'] == code) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Aap apna khud ka code use nahi kar sakte!')),
          );
          setState(() => _isLoading = false);
          return;
        }

        var referrerQuery = await FirebaseFirestore.instance
            .collection('users')
            .where('referralCode', isEqualTo: code)
            .get();

        if (referrerQuery.docs.isEmpty) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Yeh referral code galat hai! / Invalid Code')),
          );
          setState(() => _isLoading = false);
          return;
        }

        await userRef.update({
          'referredBy': code,
          'hasPlayedFirstMatch': false,
        });

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Referral code successfully apply ho gaya!')),
        );
        _referralCodeController.clear();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  // Fund add request bhejne ka function
  Future<void> _submitAddFundRequest() async {
    double? amount = double.tryParse(_addAmountController.text.trim());
    String utrId = _utrController.text.trim();
    String userUpi = _upiIdController.text.trim();

    if (amount == null || amount < 20 || utrId.isEmpty || userUpi.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kripya minimum ₹20, UPI ID aur UTR ID sahi se bharein!')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      await FirebaseFirestore.instance.collection('users').doc(currentUser!.uid).update({
        'lastUpiId': userUpi,
      });

      await FirebaseFirestore.instance.collection('add_fund_requests').add({
        'userId': currentUser!.uid,
        'userEmail': currentUser!.email ?? 'User',
        'amount': amount,
        'utrId': utrId,
        'userUpi': userUpi,
        'status': 'pending',
        'timestamp': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Fund request successfully bhej di gayi hai! / Request Sent')),
      );
      _addAmountController.clear();
      _utrController.clear();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  // Withdrawal request bhejne ka function
  Future<void> _submitWithdrawalRequest(double currentBalance) async {
    double? amount = double.tryParse(_withdrawAmountController.text.trim());

    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kripya valid rashi darj karein! / Enter valid amount')),
      );
      return;
    }

    if (amount > currentBalance) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Aapke wallet me paryapt balance nahi hai! / Insufficient Balance')),
      );
      return;
    }

    Map<String, dynamic> payoutDetails = {};
    if (_withdrawType == 'upi') {
      String upiId = _upiIdController.text.trim();
      if (upiId.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Kripya UPI ID darj karein!')));
        return;
      }
      payoutDetails = {'type': 'upi', 'upiId': upiId};
    } else {
      String accNo = _accountNumberController.text.trim();
      String ifsc = _ifscController.text.trim();
      if (accNo.isEmpty || ifsc.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Kripya bank vivaran bharein!')));
        return;
      }
      payoutDetails = {'type': 'bank', 'accountNumber': accNo, 'ifsc': ifsc};
    }

    setState(() => _isLoading = true);
    try {
      final userRef = FirebaseFirestore.instance.collection('users').doc(currentUser!.uid);
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        transaction.update(userRef, {'walletBalance': currentBalance - amount});
        
        DocumentReference withdrawalRef = FirebaseFirestore.instance.collection('withdrawal_requests').doc();
        transaction.set(withdrawalRef, {
          'userId': currentUser!.uid,
          'userEmail': currentUser!.email ?? 'User',
          'amount': amount,
          'payoutDetails': payoutDetails,
          'status': 'pending',
          'timestamp': FieldValue.serverTimestamp(),
        });
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Withdrawal request submit ho gayi hai! / Requested')),
      );
      _withdrawAmountController.clear();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (currentUser == null) {
      return const Scaffold(
        body: Center(child: Text('Kripya pehle login karein! / Please Login')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mera Wallet & Transactions / मेरा वॉलेट'),
        backgroundColor: Colors.deepPurple,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('users').doc(currentUser!.uid).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: CircularProgressIndicator());
          }

          var userData = snapshot.data!.data() as Map<String, dynamic>;
          double walletBalance = (userData['walletBalance'] ?? 0.0).toDouble();
          
          // Fallback logic taaki "NA" ya blank na aaye
          String myReferralCode = userData['referralCode'] ?? '';
          if (myReferralCode.isEmpty || myReferralCode == 'N/A' || myReferralCode == 'NA') {
            myReferralCode = currentUser != null && currentUser!.uid.length >= 6
                ? 'REF${currentUser!.uid.substring(0, 6).toUpperCase()}'
                : 'ESPORTS123';
          }

          String? referredBy = userData['referredBy'];

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Wallet Balance Section
                Card(
                  elevation: 3,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Wallet Balance / वॉलेट बैलेंस:', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.grey)),
                        const SizedBox(height: 5),
                        Text('₹${walletBalance.toStringAsFixed(2)}', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.green)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 15),

                // 2. Refer & Earn Card
                Card(
                  elevation: 3,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Text('🎁 ', style: TextStyle(fontSize: 20)),
                            Text('Refer & Earn ₹5 / रेफ़र एंड अर्न', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.deepPurple)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Apna unique referral code share karein. Dost ke pehla match khelne par labh milega.',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(8)),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(myReferralCode, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                              const Icon(Icons.copy, size: 18, color: Colors.grey),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        
                        if (referredBy == null || referredBy.isEmpty) ...[
                          const Text('Aapke paas koi coupon/referral code hai? / कूपन कोड?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _referralCodeController,
                                  decoration: const InputDecoration(
                                    hintText: 'Enter Code / कोड दर्ज करें',
                                    border: OutlineInputBorder(),
                                    isDense: true,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple),
                                onPressed: _isLoading ? null : _applyReferralCode,
                                child: const Text('Apply / लागू', style: TextStyle(color: Colors.white)),
                              ),
                            ],
                          ),
                        ] else ...[
                          Text('Applied Code: $referredBy', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 13)),
                        ]
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 15),

                // 3. Add Funds Section with Direct UPI Trigger Button
                Card(
                  elevation: 3,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Add Funds (Instant Pay) / फंड जोड़ें', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blue)),
                        const SizedBox(height: 6),
                        const Text('Admin UPI: Proesportsarena@axl', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87)),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _addAmountController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Amount (Min ₹20) / राशि', border: OutlineInputBorder(), isDense: true),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _upiIdController,
                          decoration: const InputDecoration(labelText: 'Your UPI ID (From which you paid) / आपकी UPI ID', border: OutlineInputBorder(), isDense: true),
                        ),
                        const SizedBox(height: 10),
                        // Cross-Platform Direct UPI Trigger Button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                            onPressed: _openUpiAppForPayment,
                            icon: const Icon(Icons.payment, color: Colors.white),
                            label: const Text('Pay via GPay / PhonePe / Paytm / भुगतान करें', style: TextStyle(color: Colors.white)),
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _utrController,
                          decoration: const InputDecoration(labelText: 'UTR / Transaction ID', border: OutlineInputBorder(), isDense: true),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                            onPressed: _isLoading ? null : _submitAddFundRequest,
                            child: const Text('Submit Add Fund Request / अनुरोध भेजें', style: TextStyle(color: Colors.white)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 15),

                // 4. Withdrawal Section
                Card(
                  elevation: 3,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Withdrawal / पैसे निकालें', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.orange)),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _withdrawAmountController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Withdrawal Amount / निकासी राशि', border: OutlineInputBorder(), isDense: true),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Radio<String>(
                              value: 'upi',
                              groupValue: _withdrawType,
                              onChanged: (val) => setState(() => _withdrawType = val!),
                            ),
                            const Text('UPI ID'),
                            Radio<String>(
                              value: 'bank',
                              groupValue: _withdrawType,
                              onChanged: (val) => setState(() => _withdrawType = val!),
                            ),
                            const Text('Bank Account / बैंक खाता'),
                          ],
                        ),
                        if (_withdrawType == 'upi') ...[
                          TextField(
                            controller: _upiIdController,
                            decoration: const InputDecoration(labelText: 'Enter UPI ID / यूपीआई आईडी', border: OutlineInputBorder(), isDense: true),
                          ),
                        ] else ...[
                          TextField(
                            controller: _accountNumberController,
                            decoration: const InputDecoration(labelText: 'Account Number / खाता संख्या', border: OutlineInputBorder(), isDense: true),
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: _ifscController,
                            decoration: const InputDecoration(labelText: 'IFSC Code / आईएफएससी कोड', border: OutlineInputBorder(), isDense: true),
                          ),
                        ],
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                            onPressed: _isLoading ? null : () => _submitWithdrawalRequest(walletBalance),
                            child: const Text('Request Withdrawal / विथड्रॉल अनुरोध', style: TextStyle(color: Colors.white)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
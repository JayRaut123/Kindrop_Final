import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:marquee/marquee.dart';
import 'firebase_options.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'config.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'kindrop_route.dart';

// ─── GoogleSignIn Factory ─────────────────────────────────────────────────────
// On Android: no clientId — reads from google-services.json automatically
// On Web: clientId is required for the browser OAuth popup
const _kWebClientId =
    '369670218792-gu1t37180qt2nvb5lceol6tb395tn9hf.apps.googleusercontent.com';

GoogleSignIn makeGoogleSignIn() => kIsWeb
    ? GoogleSignIn(clientId: _kWebClientId)
    : GoogleSignIn();

// ─── Theme Constants ──────────────────────────────────────────────────────────
const kPrimary = Color(0xFFCBF43E);
const kDark = Color(0xFF0D0D0D);
const kCard = Color(0xFFF2F2F2);
const kMuted = Color(0xFF888888);

// ─── Tunnel URL — auto-synced from Firestore ──────────────────────────────────
// The backend writes the current tunnel URL to Firestore on every start.
// Flutter reads it here — no manual copy-pasting needed!
String kCloudflareUrl = 'https://scanners-minimum-arch-seven.trycloudflare.com'; // fallback

Future<void> _loadTunnelUrl() async {
  try {
    final doc = await FirebaseFirestore.instance.collection('config').doc('tunnel').get();
    if (doc.exists) {
      final url = doc.data()?['url'] as String?;
      if (url != null && url.isNotEmpty) {
        kCloudflareUrl = url;
        debugPrint('🌍 Tunnel URL loaded from Firestore: $kCloudflareUrl');
      }
    }
  } catch (e) {
    debugPrint('⚠️ Could not load tunnel URL from Firestore: $e');
    debugPrint('   Using fallback URL: $kCloudflareUrl');
  }
}

Future<void> syncFirebaseWithPostgres() async {
  try {
    final response = await http.get(
      Uri.parse('$kCloudflareUrl/pickup/all'),
      headers: {'Bypass-Tunnel-Reminder': 'true'},
    );
    if (response.statusCode == 200) {
      final List list = json.decode(response.body);
      if (list.isEmpty) {
        final snap = await FirebaseFirestore.instance.collection('donations').where('status', isNotEqualTo: 'Completed').get();
        for (var doc in snap.docs) {
           await doc.reference.update({'status': 'Completed'});
        }
      }
    }
  } catch(e) {
    debugPrint('Sync error: $e');
  }
}

// ─── Entry Point ─────────────────────────────────────────────────────────────
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await _loadTunnelUrl(); // 🔥 Auto-fetch tunnel URL before app launches
  runApp(const KindropApp());
}

// ─── Root App ─────────────────────────────────────────────────────────────────
class KindropApp extends StatelessWidget {
  const KindropApp({super.key});

  @override
  Widget build(BuildContext context) {
    final base = ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: kPrimary),
      scaffoldBackgroundColor: Colors.white,
      useMaterial3: true,
      textTheme: GoogleFonts.spaceMonoTextTheme(),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.windows: ZoomPageTransitionsBuilder(),
        },
      ),
    );
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Kindrop',
      theme: base.copyWith(
        textTheme: base.textTheme.apply(bodyColor: kDark, displayColor: kDark),
      ),
      home: const AuthGate(),
    );
  }
}

// ─── Auth Gate ────────────────────────────────────────────────────────────────
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  UserProfile? profile;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    FirebaseAuth.instance.authStateChanges().listen((_) => _loadProfile());
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final demo = prefs.getString('kindrop_demo_user');
    final user = FirebaseAuth.instance.currentUser;

    if (user == null && demo != null) {
      setState(() {
        profile = UserProfile.fromMap(jsonDecode(demo));
        loading = false;
      });
      return;
    }

    if (user == null) {
      setState(() {
        profile = null;
        loading = false;
      });
      return;
    }

    final docSnap = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    setState(() {
      profile = docSnap.exists ? UserProfile.fromMap(docSnap.data()!) : null;
      loading = false;
    });
  }

  Future<void> signOut() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('kindrop_demo_user');
    await makeGoogleSignIn().signOut();
    await FirebaseAuth.instance.signOut();
    await _loadProfile();
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const SplashScreen();
    if (profile == null) return LoginScreen(onChanged: _loadProfile);
    if (profile!.role == 'organization') {
      return OrgHomeScreen(
          user: profile!, onChanged: _loadProfile, onSignOut: signOut);
    }
    if (profile!.role == 'delivery') {
      return DeliveryShell(
          user: profile!, onChanged: _loadProfile, onSignOut: signOut);
    }
    return DonorShell(
        user: profile!, onChanged: _loadProfile, onSignOut: signOut);
  }
}

// ─── Splash ───────────────────────────────────────────────────────────────────
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) => const Scaffold(
        body: Center(child: Text('🤝', style: TextStyle(fontSize: 52))),
      );
}

// ─── Donor Shell (Bottom Nav) ─────────────────────────────────────────────────
class DonorShell extends StatefulWidget {
  final UserProfile user;
  final Future<void> Function() onChanged;
  final Future<void> Function() onSignOut;

  const DonorShell(
      {super.key,
      required this.user,
      required this.onChanged,
      required this.onSignOut});

  @override
  State<DonorShell> createState() => _DonorShellState();
}

class _DonorShellState extends State<DonorShell> with WidgetsBindingObserver {
  int _index = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    syncFirebaseWithPostgres();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      syncFirebaseWithPostgres();
    }
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      DonorHomeScreen(user: widget.user),
      HistoryScreen(user: widget.user),
      ProfileScreen(user: widget.user, onSignOut: widget.onSignOut),
    ];

    return Scaffold(
      extendBody: true,
      body: screens[_index],
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: kDark, width: 2)),
        ),
        child: SafeArea(
          child: SizedBox(
            height: 68,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                // Home
                GestureDetector(
                  onTap: () => setState(() => _index = 0),
                  child: Icon(Icons.home_rounded,
                      size: 28, color: _index == 0 ? kDark : kMuted),
                ),
                // Donate FAB
                GestureDetector(
                  onTap: () async {
                    await Navigator.push(
                      context,
                      KindropRoute(
                        builder: (_) =>
                            DonateSelectionScreen(user: widget.user),
                      ),
                    );
                    await widget.onChanged();
                  },
                  child: Container(
                    width: 54,
                    height: 54,
                    decoration: brutalBox(kPrimary, borderWidth: 3),
                    child: const Icon(Icons.add, color: kDark, size: 28),
                  ),
                ),
                // Profile
                GestureDetector(
                  onTap: () => setState(() => _index = 2),
                  child: Icon(Icons.person_rounded,
                      size: 28, color: _index == 2 ? kDark : kMuted),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Login Screen ─────────────────────────────────────────────────────────────
class LoginScreen extends StatefulWidget {
  final Future<void> Function() onChanged;

  const LoginScreen({super.key, required this.onChanged});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;
  String _error = '';

  Future<void> _signIn() async {
    setState(() {
      _loading = true;
      _error = '';
    });
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _email.text.trim(),
        password: _password.text.trim(),
      );
      await widget.onChanged();
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _googleSignIn() async {
    setState(() {
      _loading = true;
      _error = '';
    });
    try {
      final googleUser = await makeGoogleSignIn().signIn();
      if (googleUser == null) return;
      final auth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: auth.accessToken,
        idToken: auth.idToken,
      );
      final result =
          await FirebaseAuth.instance.signInWithCredential(credential);
      final ref =
          FirebaseFirestore.instance.collection('users').doc(result.user!.uid);
      final doc = await ref.get();
      if (!doc.exists) {
        await ref.set({
          'uid': result.user!.uid,
          'fullName': result.user!.displayName ?? 'Google User',
          'email': result.user!.email,
          'role': 'donor',
          'createdAt': DateTime.now().toIso8601String(),
        });
      }
      await widget.onChanged();
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _enterDemo(String role) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'kindrop_demo_user',
      jsonEncode({
        'uid': 'demo_$role',
        'fullName': role == 'donor'
          ? 'Demo Donor'
          : role == 'delivery'
              ? 'Demo Delivery Partner'
              : 'Demo Organization',
        'email': 'demo@kindrop.com',
        'role': role,
        'orgName': role == 'organization' ? 'Kindrop Demo Home' : null,
        'createdAt': DateTime.now().toIso8601String(),
      }),
    );
    await widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                children: [
                  const SizedBox(height: 40),
                  // Logo
                  Container(
                    width: 80,
                    height: 80,
                    decoration: brutalBox(kPrimary, borderWidth: 4),
                    alignment: Alignment.center,
                    child: const Text('🤝', style: TextStyle(fontSize: 36)),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'KINDROP',
                    style: GoogleFonts.anton(
                        fontSize: 40, letterSpacing: -1, color: kDark),
                  ),
                  const SizedBox(height: 40),
                  if (_error.isNotEmpty) _ErrorBox(error: _error),
                  _BrutalField(controller: _email, hint: 'Email'),
                  const SizedBox(height: 12),
                  _BrutalField(
                      controller: _password, hint: 'Password', obscure: true),
                  const SizedBox(height: 16),
                  _BrutalButton.dark(
                    text: _loading ? 'Signing In...' : 'Sign In',
                    onTap: _loading ? null : _signIn,
                  ),
                  const SizedBox(height: 20),
                  Row(children: [
                    const Expanded(
                        child: Divider(color: Color(0x44888888), thickness: 1)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text('OR CONTINUE WITH',
                          style: GoogleFonts.spaceMono(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: kMuted)),
                    ),
                    const Expanded(
                        child: Divider(color: Color(0x44888888), thickness: 1)),
                  ]),
                  const SizedBox(height: 20),
                  _BrutalButton.outline(
                    text: 'Google Sign In',
                    onTap: _loading ? null : _googleSignIn,
                  ),
                  const SizedBox(height: 12),
                  _BrutalButton.primary(
                    text: 'Create Account',
                    onTap: () => Navigator.push(
                      context,
                      KindropRoute(
                        builder: (_) =>
                            RegisterScreen(onChanged: widget.onChanged),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  Text('QUICK ACCESS (DEMO MODE)',
                      style: GoogleFonts.spaceMono(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: kMuted)),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(
                      child: _SmallDemoButton(
                        text: 'Enter as Donor',
                        onTap: () => _enterDemo('donor'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _SmallDemoButton(
                        text: 'Enter as Delivery Partner',
                        onTap: () => _enterDemo('delivery'),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Register Screen ──────────────────────────────────────────────────────────
class RegisterScreen extends StatefulWidget {
  final Future<void> Function() onChanged;

  const RegisterScreen({super.key, required this.onChanged});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  String _role = 'donor';
  final _fullName = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  final _orgName = TextEditingController();
  String _error = '';
  bool _loading = false;

  Future<void> _register() async {
    setState(() {
      _loading = true;
      _error = '';
    });
    try {
      final result = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _email.text.trim(),
        password: _password.text.trim(),
      );
      await FirebaseFirestore.instance
          .collection('users')
          .doc(result.user!.uid)
          .set({
        'uid': result.user!.uid,
        'fullName': _fullName.text.trim(),
        'email': _email.text.trim(),
        'phone': _phone.text.trim(),
        'role': _role,
        'orgName': _role == 'organization' ? _orgName.text.trim() : null,
        'createdAt': DateTime.now().toIso8601String(),
      });
      await widget.onChanged();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                children: [
                  const SizedBox(height: 24),
                  Container(
                    width: 72,
                    height: 72,
                    decoration: brutalBox(kPrimary, borderWidth: 4),
                    alignment: Alignment.center,
                    child: const Text('🤝', style: TextStyle(fontSize: 30)),
                  ),
                  const SizedBox(height: 12),
                  Text('JOIN KINDROP',
                      style: GoogleFonts.anton(fontSize: 30, color: kDark)),
                  const SizedBox(height: 28),
                  Row(children: [
                    Expanded(
                      child: _ChoiceChip(
                        text: 'Donor',
                        active: _role == 'donor',
                        onTap: () => setState(() => _role = 'donor'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _ChoiceChip(
                        text: 'Organization',
                        active: _role == 'organization',
                        onTap: () => setState(() => _role = 'organization'),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 24),
                  if (_error.isNotEmpty) _ErrorBox(error: _error),
                  _BrutalField(controller: _fullName, hint: 'Full Name'),
                  const SizedBox(height: 12),
                  if (_role == 'organization') ...[
                    _BrutalField(
                        controller: _orgName, hint: 'Organization Name'),
                    const SizedBox(height: 12),
                  ],
                  _BrutalField(controller: _email, hint: 'Email'),
                  const SizedBox(height: 12),
                  _BrutalField(controller: _phone, hint: 'Phone Number'),
                  const SizedBox(height: 12),
                  _BrutalField(
                      controller: _password, hint: 'Password', obscure: true),
                  const SizedBox(height: 20),
                  _BrutalButton.primary(
                    text: _loading ? 'Joining...' : 'Join Kindrop 🤝',
                    onTap: _loading ? null : _register,
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Already have account? Sign In',
                        style: TextStyle(
                            color: kMuted, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Donor Home Screen ────────────────────────────────────────────────────────
class DonorHomeScreen extends StatelessWidget {
  final UserProfile user;

  const DonorHomeScreen({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    final firstName = user.fullName.split(' ').first;

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('donations')
          .where('donorId', isEqualTo: user.uid)
          .snapshots(),
      builder: (context, snapshot) {
        final allDonations = snapshot.data?.docs
                .map((e) => Donation.fromMap(e.data(), e.id))
                .toList() ?? [];
        
        // Sort DESC natively here to avoid requiring composite indexes
        allDonations.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        
        // Calculate true stats from full history
        final totalDonations = allDonations.length;
        final orgsHelped = totalDonations;
        final livesTouched = allDonations.fold<int>(0, (sum, d) => sum + d.quantity);
        
        // Subset of recent activity not cleared by user
        final visibleDonations = allDonations.where((d) => !d.clearedForDonor).toList();

        return ListView(
          padding: EdgeInsets.zero,
          children: [
            // Marquee ticker
            SizedBox(
              height: 40,
              child: Container(
                color: kDark,
                child: Marquee(
                  text:
                      '• URGENT: 500+ CHILDREN NEED SCHOOL SUPPLIES • DONATE CLOTHES FOR WINTER • YOUR IMPACT MATTERS • HELP SOMEONE TODAY •',
                  style: GoogleFonts.spaceMono(
                      color: kPrimary,
                      fontSize: 11,
                      fontWeight: FontWeight.bold),
                  scrollAxis: Axis.horizontal,
                  blankSpace: 40.0,
                  velocity: 60.0,
                ),
              ),
            ),

            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
              decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(bottom: BorderSide(color: kDark, width: 2))),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('WELCOME',
                            style: GoogleFonts.spaceMono(
                                fontWeight: FontWeight.bold,
                                letterSpacing: 3,
                                fontSize: 13)),
                        Text(
                          firstName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.cinzelDecorative(
                              fontSize: 44,
                              fontWeight: FontWeight.w900,
                              color: kDark,
                              height: 1),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () {},
                    child: Container(
                      width: 62,
                      height: 62,
                      decoration: brutalBox(kPrimary),
                      alignment: Alignment.center,
                      child: Text(
                        user.fullName[0].toUpperCase(),
                        style: const TextStyle(
                            fontSize: 28, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Stats
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
              child: Row(children: [
                Expanded(
                    child: _StatCard(
                        label: 'Donations',
                        value: '$totalDonations',
                        bg: kPrimary)),
                const SizedBox(width: 12),
                Expanded(
                    child: _StatCard(
                        label: 'Orgs Helped', value: '$orgsHelped', bg: Colors.white)),
                const SizedBox(width: 12),
                Expanded(
                    child: _StatCard(
                        label: 'Lives Touched', value: '$livesTouched', bg: Colors.white)),
              ]),
            ),

            // Donate Now card
            Padding(
              padding: const EdgeInsets.all(24),
              child: Container(
                padding: const EdgeInsets.all(28),
                decoration: brutalBox(kDark),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Someone needs your help today',
                      style: GoogleFonts.anton(
                          fontSize: 34, color: Colors.white, height: .95),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Tap to make a difference 🤝',
                      style: GoogleFonts.spaceMono(
                          color: kPrimary,
                          fontSize: 11,
                          fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 20),
                    _BrutalButton.primary(
                      text: 'Donate Now',
                      onTap: () => Navigator.push(
                        context,
                        KindropRoute(
                          builder: (_) => DonateSelectionScreen(user: user),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Recent Activity header
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
              child: Row(children: [
                Expanded(
                  child: Text('RECENT ACTIVITY',
                      style: GoogleFonts.spaceMono(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 3)),
                ),
                TextButton(
                  onPressed: visibleDonations.isEmpty ? null : () {
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        backgroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.zero,
                            side: BorderSide(color: kDark, width: 2)),
                        title: Text('Clear Activity?', style: GoogleFonts.anton()),
                        content: const Text('This will clear your recent logs but your stats will stay intact. Are you sure?'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: kDark))),
                          TextButton(
                            onPressed: () {
                              Navigator.pop(ctx);
                              for (var d in visibleDonations) {
                                FirebaseFirestore.instance.collection('donations').doc(d.id).update({'clearedForDonor': true});
                              }
                            }, 
                            child: const Text('Clear All', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    );
                  },
                  child: const Text('Clear All', style: TextStyle(color: Colors.red)),
                ),
                TextButton(
                  onPressed: () {},
                  child:
                      const Text('View All', style: TextStyle(color: kMuted)),
                ),
              ]),
            ),

            // Donations list
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 100),
              child: visibleDonations.isEmpty
                  ? const _EmptyBox(
                      text:
                          'No recent activity.\nStart by helping someone today!')
                  : Column(
                      children: visibleDonations
                          .map((d) => Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: _DonationTile(donation: d),
                              ))
                          .toList(),
                    ),
            ),
          ],
        );
      },
    );
  }
}

// ─── Delivery Shell (Bottom Nav) ──────────────────────────────────────────────
class DeliveryShell extends StatefulWidget {
  final UserProfile user;
  final Future<void> Function() onChanged;
  final Future<void> Function() onSignOut;

  const DeliveryShell(
      {super.key,
      required this.user,
      required this.onChanged,
      required this.onSignOut});

  @override
  State<DeliveryShell> createState() => _DeliveryShellState();
}

class _DeliveryShellState extends State<DeliveryShell> with WidgetsBindingObserver {
  int _index = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    syncFirebaseWithPostgres();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      syncFirebaseWithPostgres();
    }
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      DeliveryHomeScreen(user: widget.user),
      HistoryScreen(user: widget.user),
      ProfileScreen(user: widget.user, onSignOut: widget.onSignOut),
    ];

    return Scaffold(
      extendBody: true,
      body: screens[_index],
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: kDark, width: 2)),
        ),
        child: SafeArea(
          child: SizedBox(
            height: 68,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                // Home
                GestureDetector(
                  onTap: () => setState(() => _index = 0),
                  child: Icon(Icons.home_rounded,
                      size: 28, color: _index == 0 ? kDark : kMuted),
                ),
                // See Pickups FAB
                GestureDetector(
                  onTap: () async {
                    try {
                      final url = Uri.parse('$kCloudflareUrl/delivery.html');
                      await launchUrl(url, mode: LaunchMode.externalApplication);
                    } catch (e) {
                      debugPrint('Could not launch delivery UI: $e');
                    }
                  },
                  child: Container(
                    width: 54,
                    height: 54,
                    decoration: brutalBox(kPrimary, borderWidth: 3),
                    child: const Icon(Icons.local_shipping, color: kDark, size: 28),
                  ),
                ),
                // Profile
                GestureDetector(
                  onTap: () => setState(() => _index = 2),
                  child: Icon(Icons.person_rounded,
                      size: 28, color: _index == 2 ? kDark : kMuted),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Delivery Home Screen ─────────────────────────────────────────────────────
class DeliveryHomeScreen extends StatelessWidget {
  final UserProfile user;

  const DeliveryHomeScreen({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    final firstName = user.fullName.split(' ').first;

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('donations')
          .snapshots(),
      builder: (context, snapshot) {
        final allDonations = snapshot.data?.docs
                .map((e) => Donation.fromMap(e.data(), e.id))
                .toList() ?? [];
                
        // Sort DESC natively here to avoid requiring composite indexes
        allDonations.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        
        // Calculate true stats from full history
        final totalPickups = allDonations.length;
        final orgsReached = totalPickups;
        final livesTouched = allDonations.fold<int>(0, (sum, d) => sum + d.quantity);
        
        // Subset of recent activity not cleared by driver
        final visibleDonations = allDonations.where((d) => !d.clearedForDelivery).toList();

        return ListView(
          padding: EdgeInsets.zero,
          children: [
            // Marquee ticker
            SizedBox(
              height: 40,
              child: Container(
                color: kDark,
                child: Marquee(
                  text:
                      '• URGENT: 500+ CHILDREN NEED SCHOOL SUPPLIES • DONATE CLOTHES FOR WINTER • YOUR IMPACT MATTERS • HELP SOMEONE TODAY •',
                  style: GoogleFonts.spaceMono(
                      color: kPrimary,
                      fontSize: 11,
                      fontWeight: FontWeight.bold),
                  scrollAxis: Axis.horizontal,
                  blankSpace: 40.0,
                  velocity: 60.0,
                ),
              ),
            ),

            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
              decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(bottom: BorderSide(color: kDark, width: 2))),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('WELCOME',
                            style: GoogleFonts.spaceMono(
                                fontWeight: FontWeight.bold,
                                letterSpacing: 3,
                                fontSize: 13)),
                        Text(
                          firstName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.cinzelDecorative(
                              fontSize: 44,
                              fontWeight: FontWeight.w900,
                              color: kDark,
                              height: 1),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () {},
                    child: Container(
                      width: 62,
                      height: 62,
                      decoration: brutalBox(kPrimary),
                      alignment: Alignment.center,
                      child: Text(
                        user.fullName[0].toUpperCase(),
                        style: const TextStyle(
                            fontSize: 28, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Stats
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
              child: Row(children: [
                Expanded(
                    child: _StatCard(
                        label: 'Pickups',
                        value: '$totalPickups',
                        bg: kPrimary)),
                const SizedBox(width: 12),
                Expanded(
                    child: _StatCard(
                        label: 'Orgs Reached', value: '$orgsReached', bg: Colors.white)),
                const SizedBox(width: 12),
                Expanded(
                    child: _StatCard(
                        label: 'Lives Touched', value: '$livesTouched', bg: Colors.white)),
              ]),
            ),

            // See Pickups card
            Padding(
              padding: const EdgeInsets.all(24),
              child: Container(
                padding: const EdgeInsets.all(28),
                decoration: brutalBox(kDark),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Someone needs your help today',
                      style: GoogleFonts.anton(
                          fontSize: 34, color: Colors.white, height: .95),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Tap to make a difference 🤝',
                      style: GoogleFonts.spaceMono(
                          color: kPrimary,
                          fontSize: 11,
                          fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 20),
                    _BrutalButton.primary(
                      text: 'See Pickups',
                      onTap: () async {
                         try {
                           final url = Uri.parse('$kCloudflareUrl/delivery.html');
                           await launchUrl(url, mode: LaunchMode.externalApplication);
                         } catch (e) {
                           debugPrint('Could not launch delivery UI: $e');
                         }
                      },
                    ),
                  ],
                ),
              ),
            ),

            // Recent Activity header
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
              child: Row(children: [
                Expanded(
                  child: Text('RECENT ACTIVITY',
                      style: GoogleFonts.spaceMono(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 3)),
                ),
                TextButton(
                  onPressed: visibleDonations.isEmpty ? null : () {
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        backgroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.zero,
                            side: BorderSide(color: kDark, width: 2)),
                        title: Text('Clear Activity?', style: GoogleFonts.anton()),
                        content: const Text('This will clear your recent logs but your stats will stay intact. Are you sure?'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: kDark))),
                          TextButton(
                            onPressed: () {
                              Navigator.pop(ctx);
                              for (var d in visibleDonations) {
                                FirebaseFirestore.instance.collection('donations').doc(d.id).update({'clearedForDelivery': true});
                              }
                            }, 
                            child: const Text('Clear All', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    );
                  },
                  child: const Text('Clear All', style: TextStyle(color: Colors.red)),
                ),
                TextButton(
                  onPressed: () {},
                  child:
                      const Text('View All', style: TextStyle(color: kMuted)),
                ),
              ]),
            ),

            // Donations list
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 100),
              child: visibleDonations.isEmpty
                  ? const _EmptyBox(
                      text:
                          'No recent pickups.\nStart by helping someone today!')
                  : Column(
                      children: visibleDonations
                          .map((d) => Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: _DonationTile(donation: d),
                              ))
                          .toList(),
                    ),
            ),
          ],
        );
      },
    );
  }
}

// ─── Org Home Screen ──────────────────────────────────────────────────────────
class OrgHomeScreen extends StatefulWidget {
  final UserProfile user;
  final Future<void> Function() onChanged;
  final Future<void> Function() onSignOut;

  const OrgHomeScreen(
      {super.key,
      required this.user,
      required this.onChanged,
      required this.onSignOut});

  @override
  State<OrgHomeScreen> createState() => _OrgHomeScreenState();
}

class _OrgHomeScreenState extends State<OrgHomeScreen> {
  void _showAddNeedDialog() {
    showDialog(
      context: context,
      builder: (_) => _AddNeedDialog(user: widget.user),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
              decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(bottom: BorderSide(color: kDark, width: 2))),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('WELCOME',
                            style: GoogleFonts.spaceMono(
                                fontWeight: FontWeight.bold,
                                letterSpacing: 3,
                                fontSize: 13)),
                        Text(
                          widget.user.orgName ?? widget.user.fullName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.cinzelDecorative(
                              fontSize: 30,
                              fontWeight: FontWeight.w900,
                              color: kDark),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 62,
                    height: 62,
                    decoration: brutalBox(kPrimary),
                    alignment: Alignment.center,
                    child: Text(
                      widget.user.fullName[0].toUpperCase(),
                      style: const TextStyle(
                          fontSize: 28, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),

            // Stats
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
              child: Row(children: const [
                Expanded(
                    child: _StatCard(
                        label: 'Items Received', value: '124', bg: kPrimary)),
                SizedBox(width: 12),
                Expanded(
                    child: _StatCard(
                        label: 'Donations', value: '0', bg: Colors.white)),
                SizedBox(width: 12),
                Expanded(
                    child: _StatCard(
                        label: 'Children Helped',
                        value: '45',
                        bg: Colors.white)),
              ]),
            ),

            // Post a Need
            Padding(
              padding: const EdgeInsets.all(24),
              child: _BrutalButton.primary(
                text: 'Post a New Need',
                onTap: _showAddNeedDialog,
              ),
            ),

            // Needs Board
            _SectionTitle(title: 'Needs Board'),
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('needs')
                  .where('orgId', isEqualTo: widget.user.uid)
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                final needs = snapshot.data?.docs
                        .map((e) => Need.fromMap(e.data(), e.id))
                        .toList() ??
                    [];
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: needs.isEmpty
                      ? const _EmptyBox(text: 'No needs posted yet.')
                      : Column(
                          children: needs
                              .map((n) => Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: _NeedTile(need: n),
                                  ))
                              .toList(),
                        ),
                );
              },
            ),

            const SizedBox(height: 24),
            _SectionTitle(title: 'Incoming Donations'),
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('donations')
                  .where('orgId', isEqualTo: widget.user.uid)
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                final donations = snapshot.data?.docs
                        .map((e) => Donation.fromMap(e.data(), e.id))
                        .toList() ??
                    [];
                return Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 0),
                  child: donations.isEmpty
                      ? const _EmptyBox(text: 'No incoming donations yet.')
                      : Column(
                          children: donations
                              .map((d) => Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: _DonationTile(donation: d),
                                  ))
                              .toList(),
                        ),
                );
              },
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
              child: _BrutalButton.dark(
                text: 'Sign Out',
                onTap: () async => widget.onSignOut(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Donate Selection Screen ──────────────────────────────────────────────────
class DonateSelectionScreen extends StatelessWidget {
  final UserProfile user;

  const DonateSelectionScreen({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back, color: kDark),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'What would you\nlike to donate? 🎁',
              style: GoogleFonts.anton(fontSize: 42, color: kDark, height: .9),
            ),
            const SizedBox(height: 32),
            _DonateOption(
              emoji: '👕',
              title: 'Donate Clothes',
              subtitle: 'Help keep them warm',
              bg: kPrimary,
              onTap: () => Navigator.push(
                context,
                KindropRoute(
                  builder: (_) =>
                      DonationFormScreen(user: user, type: 'clothes'),
                ),
              ),
            ),
            const SizedBox(height: 20),
            _DonateOption(
              emoji: '✏️',
              title: 'Donate Stationery',
              subtitle: 'Help them study & grow',
              bg: kCard,
              onTap: () => Navigator.push(
                context,
                KindropRoute(
                  builder: (_) =>
                      DonationFormScreen(user: user, type: 'stationery'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Donation Form Screen ─────────────────────────────────────────────────────
class DonationFormScreen extends StatefulWidget {
  final UserProfile user;
  final String type;

  const DonationFormScreen({super.key, required this.user, required this.type});

  @override
  State<DonationFormScreen> createState() => _DonationFormScreenState();
}

class _DonationFormScreenState extends State<DonationFormScreen> {
  bool _loading = false;
  late String _category;
  String _condition = 'New';
  final _quantity = TextEditingController(text: '1');
  final _address = TextEditingController();
  DateTime? _pickupDate;

  // ── AI Quality Check (clothes only) ─────────────────────────
  File? _clotheImage;
  String _qualityResult = '';
  bool _qualityLoading = false;
  bool _qualityPassed = false;

  Future<void> _pickAndVerify({bool fromGallery = false}) async {
    final source = fromGallery ? ImageSource.gallery : ImageSource.camera;
    final picked = await ImagePicker().pickImage(
      source: source,
      imageQuality: 85,
      maxWidth: 1024,
      maxHeight: 1024,
    );
    if (picked == null) return;
    setState(() {
      _clotheImage = File(picked.path);
      _qualityLoading = true;
      _qualityResult = '';
      _qualityPassed = false;
    });
    try {
      final model = GenerativeModel(
        model: KindropConfig.geminiModel,
        apiKey: KindropConfig.geminiApiKey,
      );
      final imageBytes = await _clotheImage!.readAsBytes();
      // Detect MIME type from file extension
      final ext = picked.path.toLowerCase().split('.').last;
      final mimeType = ext == 'png'
          ? 'image/png'
          : ext == 'webp'
              ? 'image/webp'
              : 'image/jpeg';
      final prompt = TextPart(
        'Look at this clothing item. Is it in good condition suitable for donation? '
        'Answer strictly in one line: either "✅ Good Quality - Suitable for donation" '
        'or "❌ Poor Quality - Not suitable for donation". '
        'Then give one short reason.',
      );
      final imagePart = DataPart(mimeType, imageBytes);
      final response = await model.generateContent([
        Content.multi([prompt, imagePart])
      ]);
      final result = response.text ?? 'Could not analyze';
      setState(() {
        _qualityResult = result;
        _qualityPassed = result.contains('✅');
      });
    } catch (e) {
      debugPrint('AI Quality Check Error: $e');
      if (!mounted) return;
      final errStr = e.toString();
      final isQuota = errStr.contains('quota') || 
          errStr.contains('RESOURCE_EXHAUSTED') || 
          errStr.contains('429');
      
      setState(() {
        if (isQuota) {
          _qualityResult = '\u26a0\ufe0f API key quota exceeded. Update the API key in lib/config.dart '
              'with a fresh key from aistudio.google.com/app/apikey'
              '\nYou can manually skip via the button below.';
          _qualityPassed = false;
        } else {
          _qualityResult = 'Error: ${errStr.replaceAll('Exception: ', '')}';
          _qualityPassed = false;
        }
      });
    } finally {
      setState(() => _qualityLoading = false);
    }
  }

  List<String> get _items => widget.type == 'clothes'
      ? [
          'Kids Clothes',
          'Adult Clothes',
          'Winter Clothes',
          'Summer Clothes',
          'Mixed'
        ]
      : ['Notebooks', 'Pens & Pencils', 'School Kit', 'Art Supplies', 'Mixed'];

  @override
  void initState() {
    super.initState();
    _category = _items.first;
  }

  Future<void> _submit() async {
    if (widget.type == 'clothes' && !_qualityPassed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ AI quality check required! Please verify your clothing first.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    setState(() => _loading = true);
    try {
      final docRef = await FirebaseFirestore.instance.collection('donations').add({
        'donorId': widget.user.uid,
        'donorName': widget.user.fullName,
        'type': widget.type,
        'category': _category,
        'quantity': int.tryParse(_quantity.text) ?? 1,
        'condition': _condition,
        'address': _address.text.trim(),
        'pickupDate': _pickupDate?.toIso8601String() ?? '',
        'status': 'Pending',
        'createdAt': DateTime.now().toIso8601String(),
      });
      final renderUrl = Uri.parse('$kCloudflareUrl/donate.html?fid=${docRef.id}');
      await launchUrl(renderUrl, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint(e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final title =
        widget.type == 'clothes' ? 'Donate Clothes 👕' : 'Donate Stationery ✏️';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back, color: kDark),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: GoogleFonts.anton(fontSize: 32, color: kDark)),
            const SizedBox(height: 6),
            Text('Fill in the details below',
                style: GoogleFonts.spaceMono(
                    fontWeight: FontWeight.bold, color: kMuted)),
            const SizedBox(height: 24),

            // ── AI Quality Check (clothes only) ─────────────────────────
            if (widget.type == 'clothes') ...[
              // Required badge banner
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: const BoxDecoration(
                  color: kDark,
                ),
                child: Row(
                  children: [
                    const Icon(Icons.auto_awesome, color: kPrimary, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      'AI QUALITY VERIFICATION  •  REQUIRED',
                      style: GoogleFonts.spaceMono(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: kPrimary,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 2),
              GestureDetector(
                onTap: () => _pickAndVerify(fromGallery: false),
                child: Container(
                  width: double.infinity,
                  height: 200,
                  decoration: BoxDecoration(
                    color: _qualityPassed ? kPrimary.withOpacity(0.15) : kCard,
                    border: Border.all(
                      color: _qualityPassed ? kPrimary : kDark,
                      width: 3,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: _qualityPassed ? kPrimary : kDark,
                        offset: const Offset(5, 5),
                      )
                    ],
                  ),
                  child: _clotheImage == null
                      ? Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.camera_alt_rounded, size: 52, color: kMuted),
                            const SizedBox(height: 10),
                            Text(
                              'TAP TO TAKE PHOTO',
                              style: GoogleFonts.spaceMono(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: kDark,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Required before submitting',
                              style: GoogleFonts.spaceMono(
                                fontSize: 10,
                                color: kMuted,
                              ),
                            ),
                          ],
                        )
                      : Stack(
                          fit: StackFit.expand,
                          children: [
                            Image.file(_clotheImage!, fit: BoxFit.cover),
                            if (_qualityPassed)
                              Positioned(
                                top: 8, right: 8,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.green,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text('✅ PASSED',
                                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)),
                                ),
                              ),
                          ],
                        ),
                ),
              ),
              // Gallery button below the camera box
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () => _pickAndVerify(fromGallery: true),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: kDark, width: 2),
                    boxShadow: const [BoxShadow(color: kDark, offset: Offset(3, 3))],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.photo_library_outlined, size: 18, color: kDark),
                      const SizedBox(width: 8),
                      Text(
                        'Or pick from Gallery',
                        style: GoogleFonts.spaceMono(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: kDark,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              if (_qualityLoading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: CircularProgressIndicator(color: kDark),
                  ),
                )
              else if (_qualityResult.isNotEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: _qualityPassed ? kPrimary : Colors.red[100],
                    border: Border.all(color: kDark, width: 2),
                    boxShadow: const [BoxShadow(color: kDark, offset: Offset(4, 4))],
                  ),
                  child: Text(
                    _qualityResult,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
              if (_clotheImage != null) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    GestureDetector(
                      onTap: () => _pickAndVerify(fromGallery: false),
                      child: Text(
                        'Retake photo',
                        style: GoogleFonts.spaceMono(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: kMuted,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    GestureDetector(
                      onTap: () => _pickAndVerify(fromGallery: true),
                      child: Text(
                        'Pick from Gallery',
                        style: GoogleFonts.spaceMono(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: kMuted,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 24),
            ],

            // Type selector
            _FieldLabel(
                text: widget.type == 'clothes'
                    ? 'Type of clothes'
                    : 'Type of stationery'),
            Container(
              decoration: brutalBox(Colors.white),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _category,
                  isExpanded: true,
                  items: _items
                      .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                      .toList(),
                  onChanged: (v) => setState(() => _category = v!),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Quantity
            const _FieldLabel(text: 'Number of items'),
            TextField(
              controller: _quantity,
              keyboardType: TextInputType.number,
              decoration: _brutalInputDecoration(),
            ),
            const SizedBox(height: 16),

            // Condition
            const _FieldLabel(text: 'Condition'),
            Row(children: [
              Expanded(
                child: _ChoiceChip(
                  text: 'New',
                  active: _condition == 'New',
                  onTap: () => setState(() => _condition = 'New'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ChoiceChip(
                  text: 'Gently Used',
                  active: _condition == 'Gently Used',
                  onTap: () => setState(() => _condition = 'Gently Used'),
                ),
              ),
            ]),
            const SizedBox(height: 16),

            // Address
            const _FieldLabel(text: 'Pickup address'),
            TextField(
              controller: _address,
              maxLines: 4,
              decoration:
                  _brutalInputDecoration(hint: 'Enter your full address'),
            ),
            const SizedBox(height: 16),

            // Pickup date
            const _FieldLabel(text: 'Preferred pickup date'),
            GestureDetector(
              onTap: () async {
                final selected = await showDatePicker(
                  context: context,
                  firstDate: DateTime.now(),
                  lastDate: DateTime(2035),
                  initialDate: DateTime.now(),
                );
                if (selected != null) {
                  setState(() => _pickupDate = selected);
                }
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: brutalBox(Colors.white),
                child: Text(
                  _pickupDate == null
                      ? 'Select Date'
                      : DateFormat('dd MMM yyyy').format(_pickupDate!),
                  style: GoogleFonts.spaceMono(),
                ),
              ),
            ),
            const SizedBox(height: 28),

            _BrutalButton.primary(
              text: _loading ? 'Submitting...' : 'Submit Donation 🤝',
              onTap: _loading ? null : _submit,
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

// ─── History Screen ───────────────────────────────────────────────────────────
class HistoryScreen extends StatelessWidget {
  final UserProfile user;

  const HistoryScreen({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('donations')
          .where('donorId', isEqualTo: user.uid)
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        final donations = snapshot.data?.docs
                .map((e) => Donation.fromMap(e.data(), e.id))
                .toList() ??
            [];

        return ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text('Activity History',
                style: GoogleFonts.anton(fontSize: 34, color: kDark)),
            const SizedBox(height: 18),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: ['All', 'Clothes', 'Stationery', 'Food']
                  .map((f) => Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: brutalBox(Colors.white, borderWidth: 2),
                        child: Text(f.toUpperCase(),
                            style: GoogleFonts.spaceMono(
                                fontSize: 10, fontWeight: FontWeight.bold)),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 18),
            if (donations.isEmpty)
              const _EmptyBox(text: 'No history found')
            else
              ...donations.map((d) => Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Container(
                      padding: const EdgeInsets.all(18),
                      decoration: brutalBox(Colors.white),
                      child: Column(
                        children: [
                          Row(children: [
                            Container(
                              width: 58,
                              height: 58,
                              decoration: brutalBox(kCard),
                              alignment: Alignment.center,
                              child: Text(
                                d.type == 'clothes' ? '👕' : '✏️',
                                style: const TextStyle(fontSize: 26),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(d.category.toUpperCase(),
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold)),
                                  Text(
                                    d.orgName ?? 'Processing...',
                                    style: const TextStyle(
                                        fontSize: 11,
                                        color: kMuted,
                                        fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                            _StatusBadge(status: d.status),
                          ]),
                          const SizedBox(height: 12),
                          Row(children: [
                            const Icon(Icons.calendar_today,
                                size: 12, color: kMuted),
                            const SizedBox(width: 4),
                            Text(
                              DateFormat('dd/MM/yyyy').format(
                                  DateTime.tryParse(d.createdAt) ??
                                      DateTime.now()),
                              style: const TextStyle(
                                  fontSize: 11,
                                  color: kMuted,
                                  fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(width: 12),
                            const Icon(Icons.filter_list,
                                size: 12, color: kMuted),
                            const SizedBox(width: 4),
                            Text(
                              d.type.toUpperCase(),
                              style: const TextStyle(
                                  fontSize: 11,
                                  color: kMuted,
                                  fontWeight: FontWeight.bold),
                            ),
                          ]),
                        ],
                      ),
                    ),
                  )),
          ],
        );
      },
    );
  }
}

// ─── Profile Screen ───────────────────────────────────────────────────────────
class ProfileScreen extends StatelessWidget {
  final UserProfile user;
  final Future<void> Function() onSignOut;

  const ProfileScreen({super.key, required this.user, required this.onSignOut});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text('Profile', style: GoogleFonts.anton(fontSize: 34, color: kDark)),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: brutalBox(Colors.white),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _FieldLabel(text: 'Full Name'),
              Text(user.fullName,
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              const _FieldLabel(text: 'Email'),
              Text(user.email,
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              const _FieldLabel(text: 'Role'),
              Text(user.role.toUpperCase(),
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
        const SizedBox(height: 20),
        _BrutalButton.dark(
          text: 'Sign Out',
          onTap: () async => onSignOut(),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// REUSABLE WIDGETS
// ─────────────────────────────────────────────────────────────────────────────

class _DonateOption extends StatelessWidget {
  final String emoji;
  final String title;
  final String subtitle;
  final Color bg;
  final VoidCallback onTap;

  const _DonateOption({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.bg,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: brutalBox(bg, borderWidth: 4),
        child: Row(children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(emoji, style: const TextStyle(fontSize: 44)),
                const SizedBox(height: 12),
                Text(title,
                    style: GoogleFonts.anton(fontSize: 28, color: kDark)),
                Text(subtitle,
                    style: GoogleFonts.spaceMono(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: kMuted)),
              ],
            ),
          ),
          Container(
            width: 52,
            height: 52,
            decoration: brutalBox(kDark),
            child: const Icon(Icons.arrow_forward, color: Colors.white),
          ),
        ]),
      ),
    );
  }
}

class _DonationTile extends StatelessWidget {
  final Donation donation;

  const _DonationTile({required this.donation});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: brutalBox(Colors.white),
      child: Row(children: [
        Container(
          width: 52,
          height: 52,
          decoration: brutalBox(kCard),
          alignment: Alignment.center,
          child: Text(
            donation.type == 'clothes' ? '👕' : '✏️',
            style: const TextStyle(fontSize: 24),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(donation.category.toUpperCase(),
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              Text(
                donation.orgName ?? 'Searching for match...',
                style: const TextStyle(
                    fontSize: 11, color: kMuted, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
        _StatusBadge(status: donation.status),
      ]),
    );
  }
}

class _NeedTile extends StatelessWidget {
  final Need need;

  const _NeedTile({required this.need});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: brutalBox(Colors.white),
      child: Row(children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(need.item.toUpperCase(),
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              Text('Quantity: ${need.quantity}',
                  style: const TextStyle(
                      fontSize: 11,
                      color: kMuted,
                      fontWeight: FontWeight.bold)),
            ],
          ),
        ),
        IconButton(
          onPressed: () async {
            await FirebaseFirestore.instance
                .collection('needs')
                .doc(need.id)
                .delete();
          },
          icon: const Icon(Icons.delete_outline, color: Colors.red),
        ),
      ]),
    );
  }
}

class _AddNeedDialog extends StatefulWidget {
  final UserProfile user;

  const _AddNeedDialog({required this.user});

  @override
  State<_AddNeedDialog> createState() => _AddNeedDialogState();
}

class _AddNeedDialogState extends State<_AddNeedDialog> {
  final _item = TextEditingController();
  final _quantity = TextEditingController(text: '1');

  Future<void> _submit() async {
    await FirebaseFirestore.instance.collection('needs').add({
      'orgId': widget.user.uid,
      'orgName': widget.user.orgName ?? widget.user.fullName,
      'item': _item.text.trim(),
      'quantity': int.tryParse(_quantity.text) ?? 1,
      'createdAt': DateTime.now().toIso8601String(),
    });
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: brutalBox(Colors.white, borderWidth: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Post a Need',
                style: GoogleFonts.anton(fontSize: 28, color: kDark)),
            const SizedBox(height: 16),
            _BrutalField(controller: _item, hint: 'Item Name'),
            const SizedBox(height: 12),
            _BrutalField(controller: _quantity, hint: 'Quantity Needed'),
            const SizedBox(height: 18),
            Row(children: [
              Expanded(
                child: _BrutalButton.outline(
                  text: 'Cancel',
                  onTap: () => Navigator.pop(context),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _BrutalButton.primary(
                  text: 'Post Need',
                  onTap: _submit,
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color bg;

  const _StatCard({required this.label, required this.value, required this.bg});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 92,
      padding: const EdgeInsets.all(12),
      decoration: brutalBox(bg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(),
              style: GoogleFonts.spaceMono(
                  fontSize: 9, fontWeight: FontWeight.bold, color: kMuted)),
          const Spacer(),
          Text(value, style: GoogleFonts.bungee(fontSize: 28, color: kDark)),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final bg = status == 'Delivered'
        ? kPrimary
        : status == 'Pickup Soon'
            ? kDark
            : Colors.white;
    final fg = status == 'Pickup Soon' ? Colors.white : kDark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: brutalBox(bg, borderWidth: 2),
      child: Text(
        status,
        style: TextStyle(fontSize: 10, color: fg, fontWeight: FontWeight.bold),
      ),
    );
  }
}

class _BrutalButton extends StatelessWidget {
  final String text;
  final VoidCallback? onTap;
  final Color bg;
  final Color fg;

  const _BrutalButton._(
      {required this.text,
      required this.onTap,
      required this.bg,
      required this.fg});

  factory _BrutalButton.primary(
          {required String text, required VoidCallback? onTap}) =>
      _BrutalButton._(text: text, onTap: onTap, bg: kPrimary, fg: kDark);

  factory _BrutalButton.dark(
          {required String text, required VoidCallback? onTap}) =>
      _BrutalButton._(text: text, onTap: onTap, bg: kDark, fg: Colors.white);

  factory _BrutalButton.outline(
          {required String text, required VoidCallback? onTap}) =>
      _BrutalButton._(text: text, onTap: onTap, bg: Colors.white, fg: kDark);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
        decoration: brutalBox(bg),
        child: Center(
          child: Text(
            text,
            style:
                TextStyle(color: fg, fontWeight: FontWeight.bold, fontSize: 15),
          ),
        ),
      ),
    );
  }
}

class _BrutalField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final bool obscure;

  const _BrutalField(
      {required this.controller, required this.hint, this.obscure = false});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      decoration: _brutalInputDecoration(hint: hint),
    );
  }
}

class _SmallDemoButton extends StatelessWidget {
  final String text;
  final VoidCallback onTap;

  const _SmallDemoButton({required this.text, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: brutalBox(kCard, borderWidth: 1),
        child: Center(
          child: Text(text,
              style:
                  const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }
}

class _ChoiceChip extends StatelessWidget {
  final String text;
  final bool active;
  final VoidCallback onTap;

  const _ChoiceChip(
      {required this.text, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: brutalBox(active ? kPrimary : kCard),
        child: Center(
          child: Text(
            text,
            style: TextStyle(
              color: active ? kDark : kMuted,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;

  const _FieldLabel({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text.toUpperCase(),
        style: GoogleFonts.spaceMono(
            fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.5),
      ),
    );
  }
}

class _EmptyBox extends StatelessWidget {
  final String text;

  const _EmptyBox({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.black26, width: 2),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(
            fontSize: 11, color: kMuted, fontWeight: FontWeight.bold),
      ),
    );
  }
}

class _ErrorBox extends StatelessWidget {
  final String error;

  const _ErrorBox({required this.error});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: const BoxDecoration(
        color: Color(0xFFFFEBEE),
        border: Border(left: BorderSide(color: Colors.red, width: 4)),
      ),
      child: Text(error, style: const TextStyle(color: Colors.red)),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 14),
      child: Text(
        title.toUpperCase(),
        style: GoogleFonts.spaceMono(
            fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 3),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HELPERS
// ─────────────────────────────────────────────────────────────────────────────

InputDecoration _brutalInputDecoration({String? hint}) {
  return InputDecoration(
    hintText: hint,
    filled: true,
    fillColor: Colors.white,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
    enabledBorder: const OutlineInputBorder(
      borderRadius: BorderRadius.zero,
      borderSide: BorderSide(color: kDark, width: 2),
    ),
    focusedBorder: const OutlineInputBorder(
      borderRadius: BorderRadius.zero,
      borderSide: BorderSide(color: kDark, width: 2),
    ),
  );
}

BoxDecoration brutalBox(Color color, {double borderWidth = 2}) {
  return BoxDecoration(
    color: color,
    border: Border.all(color: kDark, width: borderWidth),
    boxShadow: const [BoxShadow(color: kDark, offset: Offset(4, 4))],
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// DATA MODELS
// ─────────────────────────────────────────────────────────────────────────────

class UserProfile {
  final String uid;
  final String fullName;
  final String email;
  final String role;
  final String? phone;
  final String? orgName;
  final String createdAt;

  UserProfile({
    required this.uid,
    required this.fullName,
    required this.email,
    required this.role,
    required this.createdAt,
    this.phone,
    this.orgName,
  });

  factory UserProfile.fromMap(Map<String, dynamic> map) => UserProfile(
        uid: map['uid'] ?? '',
        fullName: map['fullName'] ?? '',
        email: map['email'] ?? '',
        role: map['role'] ?? 'donor',
        phone: map['phone'],
        orgName: map['orgName'],
        createdAt: map['createdAt'] ?? '',
      );
}

class Donation {
  final String id;
  final String donorId;
  final String donorName;
  final String type;
  final String category;
  final int quantity;
  final String condition;
  final String address;
  final String pickupDate;
  final String status;
  final bool clearedForDonor;
  final bool clearedForDelivery;
  final String? orgId;
  final String? orgName;
  final String createdAt;

  Donation({
    required this.id,
    required this.donorId,
    required this.donorName,
    required this.type,
    required this.category,
    required this.quantity,
    required this.condition,
    required this.address,
    required this.pickupDate,
    required this.status,
    required this.createdAt,
    this.clearedForDonor = false,
    this.clearedForDelivery = false,
    this.orgId,
    this.orgName,
  });

  factory Donation.fromMap(Map<String, dynamic> map, String id) => Donation(
        id: id,
        donorId: map['donorId'] ?? '',
        donorName: map['donorName'] ?? '',
        type: map['type'] ?? '',
        category: map['category'] ?? '',
        quantity: map['quantity'] ?? 0,
        condition: map['condition'] ?? '',
        address: map['address'] ?? '',
        pickupDate: map['pickupDate'] ?? '',
        status: map['status'] ?? 'Pending',
        clearedForDonor: map['clearedForDonor'] ?? false,
        clearedForDelivery: map['clearedForDelivery'] ?? false,
        orgId: map['orgId'],
        orgName: map['orgName'],
        createdAt: map['createdAt'] ?? '',
      );
}

class Need {
  final String id;
  final String orgId;
  final String orgName;
  final String item;
  final int quantity;
  final String createdAt;

  Need({
    required this.id,
    required this.orgId,
    required this.orgName,
    required this.item,
    required this.quantity,
    required this.createdAt,
  });

  factory Need.fromMap(Map<String, dynamic> map, String id) => Need(
        id: id,
        orgId: map['orgId'] ?? '',
        orgName: map['orgName'] ?? '',
        item: map['item'] ?? '',
        quantity: map['quantity'] ?? 0,
        createdAt: map['createdAt'] ?? '',
      );
}

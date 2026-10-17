import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'firebase_options.dart';

// ==========================================
// 1. YEREL DEPOLAMA (SHARED PREFERENCES)
// ==========================================
class LocalStorageService {
  static late SharedPreferences prefs;

  static Future<void> init() async {
    prefs = await SharedPreferences.getInstance();
  }

  static Participant? getUser() {
    final id = prefs.getString('userId');
    final name = prefs.getString('userName');
    final colorVal = prefs.getInt('userColor');
    if (id != null && name != null && colorVal != null) {
      return Participant(userId: id, name: name, color: Color(colorVal));
    }
    return null;
  }

  static Future<void> saveUser(Participant user) async {
    await prefs.setString('userId', user.userId);
    await prefs.setString('userName', user.name);
    await prefs.setInt('userColor', user.color.value);
  }

  static List<Map<String, String>> getMyRooms() {
    final list = prefs.getStringList('myRoomsData') ?? [];
    return list.map((e) => Map<String, String>.from(jsonDecode(e))).toList();
  }

  static Future<void> addRoom(String roomId, String title) async {
    final rooms = getMyRooms();
    if (!rooms.any((r) => r['id'] == roomId)) {
      rooms.add({'id': roomId, 'title': title});
      await prefs.setStringList('myRoomsData', rooms.map((e) => jsonEncode(e)).toList());
    } else {
      final idx = rooms.indexWhere((r) => r['id'] == roomId);
      rooms[idx] = {'id': roomId, 'title': title};
      await prefs.setStringList('myRoomsData', rooms.map((e) => jsonEncode(e)).toList());
    }
  }

  static Future<void> removeRoom(String roomId) async {
    final rooms = getMyRooms();
    rooms.removeWhere((r) => r['id'] == roomId);
    await prefs.setStringList('myRoomsData', rooms.map((e) => jsonEncode(e)).toList());
  }
}

// ==========================================
// 2. UYGULAMA BAŞLANGICI & FIREBASE INIT
// ==========================================
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await LocalStorageService.init(); 
  
  runApp(
    const ProviderScope(
      child: PeeTrackerApp(),
    ),
  );
}

class PeeTrackerApp extends StatelessWidget {
  const PeeTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    final user = LocalStorageService.getUser();

    return MaterialApp(
      title: 'Pee Matrix',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Helvetica',
        primarySwatch: Colors.yellow,
        scaffoldBackgroundColor: const Color(0xFFF8F9FA),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.black87,
          elevation: 0,
          centerTitle: false,
        ),
      ),
      home: user != null ? const SetupScreen() : const ProfileSetupScreen(),
    );
  }
}

// ==========================================
// 3. YARDIMCI ARAÇLAR & MİKRO-ANİMASYONLAR
// ==========================================
class ColorUtils {
  static Color calculateBlendedColor(List<Color> colors) {
    if (colors.isEmpty) return Colors.transparent;
    if (colors.length == 1) return colors.first;

    double rSq = 0, gSq = 0, bSq = 0;
    for (var color in colors) {
      rSq += pow(color.red, 2);
      gSq += pow(color.green, 2);
      bSq += pow(color.blue, 2);
    }
    int count = colors.length;
    return Color.fromARGB(
      255,
      sqrt(rSq / count).round(),
      sqrt(gSq / count).round(),
      sqrt(bSq / count).round(),
    );
  }
}

String formatMinuteIndex(int minuteIndex) {
  final int h = minuteIndex ~/ 60;
  final int m = minuteIndex % 60;
  return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
}

// MİKRO ETKİLEŞİM ANİMASYONLARI
class AnimationUtils {
  static void showPeeSplash(BuildContext context) {
    _showOverlay(context, '💦', isFlush: false);
  }

  static void showFlushSwirl(BuildContext context) {
    _showOverlay(context, '🌪️', isFlush: true);
  }

  static void _showOverlay(BuildContext context, String emoji, {required bool isFlush}) {
    final overlay = Overlay.of(context);
    late OverlayEntry entry;

    entry = OverlayEntry(
      builder: (context) => _AnimatedEmojiOverlay(
        emoji: emoji, 
        isFlush: isFlush,
        onComplete: () => entry.remove(),
      ),
    );

    overlay.insert(entry);
  }
}

class _AnimatedEmojiOverlay extends StatefulWidget {
  final String emoji;
  final bool isFlush;
  final VoidCallback onComplete;

  const _AnimatedEmojiOverlay({required this.emoji, required this.isFlush, required this.onComplete});

  @override
  State<_AnimatedEmojiOverlay> createState() => _AnimatedEmojiOverlayState();
}

class _AnimatedEmojiOverlayState extends State<_AnimatedEmojiOverlay> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _rotateAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500));
    
    if (widget.isFlush) {
      // Sifon Animasyonu (Küçülerek ve dönerek kaybolma)
      _scaleAnimation = Tween<double>(begin: 1.5, end: 0.0).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInCirc));
      _rotateAnimation = Tween<double>(begin: 0.0, end: 4.0).animate(CurvedAnimation(parent: _controller, curve: Curves.easeIn));
      _opacityAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(CurvedAnimation(parent: _controller, curve: const Interval(0.5, 1.0)));
      _slideAnimation = Tween<Offset>(begin: Offset.zero, end: const Offset(0, 0.5)).animate(_controller);
    } else {
      // Çiş Sıçrama Animasyonu (Büyüyüp yukarı süzülme)
      _scaleAnimation = TweenSequence<double>([
        TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.8).chain(CurveTween(curve: Curves.elasticOut)), weight: 60),
        TweenSequenceItem(tween: Tween(begin: 1.8, end: 1.2).chain(CurveTween(curve: Curves.easeInOut)), weight: 40),
      ]).animate(_controller);
      _rotateAnimation = Tween<double>(begin: 0.0, end: 0.0).animate(_controller);
      _opacityAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(CurvedAnimation(parent: _controller, curve: const Interval(0.6, 1.0)));
      _slideAnimation = Tween<Offset>(begin: Offset.zero, end: const Offset(0, -1.2)).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    }

    _controller.forward().then((_) => widget.onComplete());
  }

  @override
  void dispose() { 
    _controller.dispose(); 
    super.dispose(); 
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: IgnorePointer(
        child: Center(
          child: FadeTransition(
            opacity: _opacityAnimation,
            child: SlideTransition(
              position: _slideAnimation,
              child: RotationTransition(
                turns: _rotateAnimation,
                child: ScaleTransition(
                  scale: _scaleAnimation,
                  child: Text(widget.emoji, style: const TextStyle(fontSize: 100)),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ==========================================
// 4. FIREBASE VERİ MODELLERİ
// ==========================================
class Participant {
  final String userId;
  final String name;
  final Color color;

  Participant({required this.userId, required this.name, required this.color});

  Map<String, dynamic> toMap() => {
    'userId': userId,
    'name': name,
    'color': color.value,
  };

  factory Participant.fromMap(Map<String, dynamic> map) => Participant(
    userId: map['userId'],
    name: map['name'],
    color: Color(map['color']),
  );
}

class RoomState {
  final String id;
  final String title;
  final List<Participant> participants;
  final Map<int, List<String>> logs;

  RoomState({required this.id, required this.title, required this.participants, required this.logs});

  factory RoomState.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    final participantsData = data['participants'] as List<dynamic>? ?? [];
    final participantsList = participantsData.map((p) => Participant.fromMap(p)).toList();

    final logsData = data['logs'] as Map<String, dynamic>? ?? {};
    final Map<int, List<String>> parsedLogs = {};
    
    logsData.forEach((key, value) {
      parsedLogs[int.parse(key)] = List<String>.from(value);
    });

    return RoomState(
      id: doc.id,
      title: data['title'] ?? 'İsimsiz Tuvalet Odası',
      participants: participantsList,
      logs: parsedLogs,
    );
  }

  double get completionRate => (logs.length / 1440) * 100;
  int get mixedColorsCount => logs.values.where((userIds) => userIds.length > 1).length;
}

// ==========================================
// 5. RIVERPOD & FIREBASE SERVİSLERİ
// ==========================================
final currentUserProvider = StateProvider<Participant?>((ref) => LocalStorageService.getUser());
final currentRoomIdProvider = StateProvider<String?>((ref) => null);

class MyRoomsNotifier extends StateNotifier<List<Map<String, String>>> {
  MyRoomsNotifier() : super(LocalStorageService.getMyRooms());

  void addRoom(String roomId, String title) {
    LocalStorageService.addRoom(roomId, title);
    state = LocalStorageService.getMyRooms();
  }

  void removeRoom(String roomId) {
    LocalStorageService.removeRoom(roomId);
    state = LocalStorageService.getMyRooms();
  }
}
final myRoomsProvider = StateNotifierProvider<MyRoomsNotifier, List<Map<String, String>>>((ref) {
  return MyRoomsNotifier();
});

final roomStreamProvider = StreamProvider<RoomState?>((ref) {
  final roomId = ref.watch(currentRoomIdProvider);
  if (roomId == null) return Stream.value(null);

  return FirebaseFirestore.instance
      .collection('rooms')
      .doc(roomId)
      .snapshots()
      .map((doc) => doc.exists ? RoomState.fromDocument(doc) : null);
});

class FirebaseService {
  static final _db = FirebaseFirestore.instance;

  static Future<String> createRoom(String title, Participant creator) async {
    final String roomCode = (100000 + Random().nextInt(900000)).toString();
    
    await _db.collection('rooms').doc(roomCode).set({
      'title': title,
      'createdAt': FieldValue.serverTimestamp(),
      'participants': [creator.toMap()],
      'logs': {},
    });
    
    return roomCode;
  }

  static Future<String?> getRoomTitle(String roomCode) async {
    final doc = await _db.collection('rooms').doc(roomCode).get();
    if (doc.exists) {
      return doc.data()!['title']?.toString();
    }
    return null;
  }

  static Future<String?> joinRoom(String roomCode, Participant participant) async {
    final docRef = _db.collection('rooms').doc(roomCode);
    final doc = await docRef.get();
    
    if (!doc.exists) return "WC bulunamadı! Kodu kontrol edin.";

    final data = doc.data() as Map<String, dynamic>;
    final participantsData = data['participants'] as List<dynamic>? ?? [];
    List<Participant> participants = participantsData.map((p) => Participant.fromMap(p)).toList();

    for (var p in participants) {
      if (p.userId != participant.userId) { 
        if (p.name.trim().toLowerCase() == participant.name.trim().toLowerCase()) {
          return "Bu kullanıcı adı odada zaten kullanılıyor! Başka bir isim seç.";
        }
        if (p.color.value == participant.color.value) {
          return "Bu çiş rengi odada başka biri tarafından seçilmiş! Başka bir renk seç.";
        }
      }
    }

    participants.removeWhere((p) => p.userId == participant.userId);
    participants.add(participant);

    await docRef.update({
      'participants': participants.map((p) => p.toMap()).toList()
    });
    return null; 
  }

  static Future<void> leaveRoom(String roomCode, String userId) async {
    final docRef = _db.collection('rooms').doc(roomCode);
    final doc = await docRef.get();
    if (doc.exists) {
      final data = doc.data() as Map<String, dynamic>;
      final participantsData = data['participants'] as List<dynamic>? ?? [];
      List<Participant> participants = participantsData.map((p) => Participant.fromMap(p)).toList();
      
      participants.removeWhere((p) => p.userId == userId);
      
      await docRef.update({
        'participants': participants.map((p) => p.toMap()).toList()
      });
    }
  }

  static Future<void> logPee(String roomCode, int minuteIndex, String userId) async {
    await _db.collection('rooms').doc(roomCode).update({
      'logs.$minuteIndex': FieldValue.arrayUnion([userId])
    });
  }

  static Future<void> removePeeLog(String roomCode, int minuteIndex, String userId) async {
    final docRef = _db.collection('rooms').doc(roomCode);
    final doc = await docRef.get();
    
    if (doc.exists) {
      final data = doc.data() as Map<String, dynamic>;
      final logs = data['logs'] as Map<String, dynamic>? ?? {};
      final minuteKey = minuteIndex.toString();

      final userList = logs[minuteKey] as List<dynamic>? ?? [];
      
      if (userList.length <= 1) {
        await docRef.update({
          'logs.$minuteKey': FieldValue.delete(),
        });
      } else {
        await docRef.update({
          'logs.$minuteKey': FieldValue.arrayRemove([userId])
        });
      }
    }
  }
}

// ==========================================
// 6. KULLANICI ARAYÜZÜ (UI) 
// ==========================================

class ProfileSetupScreen extends ConsumerStatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  ConsumerState<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends ConsumerState<ProfileSetupScreen> {
  final _nameController = TextEditingController();
  
  // Başlangıç rengini listedeki bir renkle değiştirdik
  Color _selectedColor = Colors.yellow; 

  // Sadece görseldeki 12 renk
  final List<Color> _availableColors = [
    Colors.red,
    Colors.orange,
    Colors.yellow,
    Colors.green,
    Colors.blue,
    Colors.indigo,
    Colors.purple,
    Colors.grey,
    Colors.black,
    Colors.pink,
    Colors.brown,
  ];

  // ... (Kodun geri kalanı aynı şekilde devam ediyor)

  @override
  void initState() {
    super.initState();
    final existingUser = ref.read(currentUserProvider);
    if (existingUser != null) {
      _nameController.text = existingUser.name;
      _selectedColor = existingUser.color;
    }
  }

  void _proceed() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('⚠️ Lütfen bir kullanıcı adı gir.'))
      );
      return;
    }

    final currentUser = ref.read(currentUserProvider);
    final user = Participant(
      userId: currentUser?.userId ?? 'user_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      color: _selectedColor,
    );

    await LocalStorageService.saveUser(user);
    ref.read(currentUserProvider.notifier).state = user;

    if (currentUser != null && Navigator.canPop(context)) {
      Navigator.pop(context); 
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const SetupScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Çiş Sayacı - Profil', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: -1)),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.water_drop, size: 64, color: Colors.amber),
              const SizedBox(height: 16),
              const Text("Profili Oluştur", textAlign: TextAlign.center, style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: -1)),
              const SizedBox(height: 8),
              const Text("İsmini ve kişisel çiş rengini belirle.", textAlign: TextAlign.center, style: TextStyle(fontSize: 16, color: Colors.grey, fontWeight: FontWeight.w500)),
              const SizedBox(height: 32),

              TextField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Kullanıcı Adın', 
                  prefixIcon: const Icon(Icons.person),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                  filled: true,
                  fillColor: Colors.white,
                ),
              ),
              const SizedBox(height: 24),
              const Text('Çiş Rengini Seç', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12, runSpacing: 12,
                alignment: WrapAlignment.center,
                children: _availableColors.map((color) {
                  final isSelected = _selectedColor == color;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedColor = color),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: isSelected ? 50 : 45, 
                      height: isSelected ? 50 : 45,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: Border.all(color: isSelected ? Colors.black87 : Colors.transparent, width: 4),
                        boxShadow: isSelected ? [BoxShadow(color: color.withOpacity(0.5), blurRadius: 10)] : [],
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _proceed,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 20), 
                  backgroundColor: Colors.black87, 
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                child: const Text('Kaydet ve Devam Et ➡️', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: -0.5)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SetupScreen extends ConsumerStatefulWidget {
  const SetupScreen({super.key});

  @override
  ConsumerState<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends ConsumerState<SetupScreen> {
  final _roomTitleController = TextEditingController();
  final _roomCodeController = TextEditingController();
  bool _isCreatingRoom = true;

  void _submit() async {
    final currentUser = ref.read(currentUserProvider);
    if (currentUser == null) return;

    if (_isCreatingRoom) {
      final title = _roomTitleController.text.trim();
      if (title.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('⚠️ Lütfen bir WC adı gir.')));
        return;
      }
      
      final roomCode = await FirebaseService.createRoom(title, currentUser);
      ref.read(myRoomsProvider.notifier).addRoom(roomCode, title);
      ref.read(currentRoomIdProvider.notifier).state = roomCode;
      
      _goToDashboard();
    } else {
      final code = _roomCodeController.text.trim();
      if (code.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('⚠️ Lütfen WC kodunu gir.')));
        return;
      }
      
      final error = await FirebaseService.joinRoom(code, currentUser);
      if (error == null) {
        final title = await FirebaseService.getRoomTitle(code) ?? 'İsimsiz WC';
        ref.read(myRoomsProvider.notifier).addRoom(code, title);
        ref.read(currentRoomIdProvider.notifier).state = code;
        _goToDashboard();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error), backgroundColor: Colors.redAccent)
        );
      }
    }
  }

  void _goToDashboard() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const PeeDashboardScreen()),
    );
  }

  void _leaveRoom(String roomId, String title) async {
    final currentUser = ref.read(currentUserProvider);
    if (currentUser != null) {
      await FirebaseService.leaveRoom(roomId, currentUser.userId);
    }
    ref.read(myRoomsProvider.notifier).removeRoom(roomId);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("'$title' odasından tamamen ayrıldın.")));
  }

  void _enterExistingRoom(String roomId) async {
    final currentUser = ref.read(currentUserProvider);
    if (currentUser == null) return;

    final error = await FirebaseService.joinRoom(roomId, currentUser);
    if (error == null) {
      ref.read(currentRoomIdProvider.notifier).state = roomId;
      _goToDashboard();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error), backgroundColor: Colors.redAccent));
      if (error.contains("bulunamadı")) {
        ref.read(myRoomsProvider.notifier).removeRoom(roomId); 
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final myRooms = ref.watch(myRoomsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('WC Odası Seçimi', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: -1)),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: "Profili Düzenle",
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ProfileSetupScreen())
            ),
          )
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (user != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade300)),
                  child: Row(
                    children: [
                      CircleAvatar(backgroundColor: user.color, child: const Icon(Icons.person, color: Colors.white)),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(user.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          const Text("Aktif Profil", style: TextStyle(color: Colors.grey, fontSize: 12)),
                        ],
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 24),

              Row(
                children: [
                  Expanded(
                    child: ChoiceChip(
                      label: const Text('Yeni WC Kur', style: TextStyle(fontWeight: FontWeight.w600)),
                      selected: _isCreatingRoom,
                      onSelected: (val) => setState(() => _isCreatingRoom = true),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ChoiceChip(
                      label: const Text("WC'ye Katıl", style: TextStyle(fontWeight: FontWeight.w600)),
                      selected: !_isCreatingRoom,
                      onSelected: (val) => setState(() => _isCreatingRoom = false),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              if (_isCreatingRoom)
                TextField(
                  controller: _roomTitleController,
                  decoration: InputDecoration(
                    labelText: 'WC Adı (Örn: Ofis WC)', 
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                    filled: true, fillColor: Colors.white,
                    prefixIcon: const Icon(Icons.meeting_room)
                  ),
                )
              else
                TextField(
                  controller: _roomCodeController,
                  decoration: InputDecoration(
                    labelText: '6 Haneli WC Kodu', 
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                    filled: true, fillColor: Colors.white,
                    prefixIcon: const Icon(Icons.pin)
                  ),
                  keyboardType: TextInputType.number,
                ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _submit,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 20), 
                  backgroundColor: Colors.black87, 
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                child: Text(_isCreatingRoom ? 'WC Kur & Gir' : "WC'ye Bağlan", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: -0.5)),
              ),
              
              const SizedBox(height: 48),
              const Divider(),
              const SizedBox(height: 24),
              const Text("Odalarım", style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: -1)),
              const SizedBox(height: 16),
              
              if (myRooms.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16.0),
                  child: Text("Henüz bir odaya katılmadın veya kurmadın.", style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic)),
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: myRooms.length,
                  itemBuilder: (context, index) {
                    final room = myRooms[index];
                    return Card(
                      elevation: 0,
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: Colors.grey.shade300)
                      ),
                      color: Colors.white,
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                        title: Text(room['title']!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        subtitle: Text("Kod: ${room['id']}", style: TextStyle(color: Colors.amber.shade700, fontWeight: FontWeight.w600)),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                          tooltip: "Odadan Ayrıl",
                          onPressed: () => _leaveRoom(room['id']!, room['title']!),
                        ),
                        onTap: () => _enterExistingRoom(room['id']!),
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class PeeDashboardScreen extends ConsumerWidget {
  const PeeDashboardScreen({super.key});

  void _handlePee(BuildContext context, WidgetRef ref, int minuteIndex, Participant currentUser, RoomState roomState) async {
    final roomId = ref.read(currentRoomIdProvider)!;
    
    // Mikro Animasyonu Tetikle (Sıçrama)
    AnimationUtils.showPeeSplash(context);

    final existingPeers = roomState.logs[minuteIndex] ?? [];
    if (existingPeers.isNotEmpty && !existingPeers.contains(currentUser.userId)) {
      final names = existingPeers.map((id) => roomState.participants.firstWhere((p) => p.userId == id).name).join(' ve ');
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("🚽 $names ile aynı dakikada çiş yaptın! Ortak akıntı!"),
          backgroundColor: Colors.black87,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
    
    await FirebaseService.logPee(roomId, minuteIndex, currentUser.userId);
  }

  void _handleRemovePee(BuildContext context, WidgetRef ref, int minuteIndex, Participant currentUser) async {
    final roomId = ref.read(currentRoomIdProvider)!;

    // Mikro Animasyonu Tetikle (Sifon)
    AnimationUtils.showFlushSwirl(context);
    
    await FirebaseService.removePeeLog(roomId, minuteIndex, currentUser.userId);
  }

  void _showMinuteDetails(BuildContext context, WidgetRef ref, int minuteIndex, Participant currentUser, RoomState roomState) {
    final logUserIds = roomState.logs[minuteIndex] ?? [];
    final peers = logUserIds.map((id) => roomState.participants.firstWhere((p) => p.userId == id)).toList();
    final userHasLogged = logUserIds.contains(currentUser.userId);

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(child: Text(formatMinuteIndex(minuteIndex), style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, letterSpacing: -1))),
              const SizedBox(height: 24),
              const Text("Bu dakikada tuvalette olanlar:", style: TextStyle(fontWeight: FontWeight.w700, color: Colors.grey)),
              const SizedBox(height: 12),
              if (peers.isEmpty)
                const Padding(padding: EdgeInsets.symmetric(vertical: 8.0), child: Text("Henüz bu dakikada kimse çiş yapmadı.", style: TextStyle(fontStyle: FontStyle.italic)))
              else
                Wrap(
                  spacing: 12, runSpacing: 12,
                  children: peers.map((p) => Chip(
                    avatar: CircleAvatar(backgroundColor: p.color), 
                    label: Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                    backgroundColor: Colors.grey.shade100,
                    side: BorderSide.none,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  )).toList(),
                ),
              const SizedBox(height: 40),
              
              userHasLogged
                  ? ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _handleRemovePee(context, ref, minuteIndex, currentUser);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent, 
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                      ),
                      icon: const Icon(Icons.undo, color: Colors.white),
                      label: const Text("Sifonu Çek (İptal)", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
                    )
                  : ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _handlePee(context, ref, minuteIndex, currentUser, roomState);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: currentUser.color, 
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                      ),
                      icon: const Icon(Icons.water_drop, color: Colors.white),
                      label: const Text("Bu dakikada işedim", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
                    ),
            ],
          ),
        );
      }
    );
  }

  void _showHourGrid(BuildContext context, WidgetRef ref, int hour, Map<int, Color> gridColors, Participant currentUser, RoomState roomState) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
      builder: (ctx) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.75,
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Text(
                "${hour.toString().padLeft(2, '0')}.00 - ${hour.toString().padLeft(2, '0')}.59", 
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: -1)
              ),
              const SizedBox(height: 24),
              Expanded(
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 6, 
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemCount: 60,
                  itemBuilder: (context, minuteOfHour) {
                    final absoluteMinuteIndex = (hour * 60) + minuteOfHour;
                    final color = gridColors[absoluteMinuteIndex];
                    final isFilled = color != null;

                    return GestureDetector(
                      onTap: () {
                        Navigator.pop(ctx);
                        _showMinuteDetails(context, ref, absoluteMinuteIndex, currentUser, roomState);
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: color ?? Colors.white,
                          border: Border.all(color: isFilled ? Colors.transparent : Colors.grey.shade300, width: 2),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: isFilled ? [BoxShadow(color: color.withOpacity(0.4), blurRadius: 8, offset: const Offset(0, 4))] : [],
                        ),
                        child: Center(
                          child: Text(
                            minuteOfHour.toString().padLeft(2, '0'),
                            style: TextStyle(
                              fontSize: 16,
                              color: isFilled ? Colors.white : Colors.black45,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      }
    );
  }

  void _showParticipants(BuildContext context, RoomState roomState) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(32),
          height: MediaQuery.of(context).size.height * 0.6,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Tuvalettekiler", style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: -1)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(20)),
                    child: Text("Kod: ${roomState.id}", style: const TextStyle(fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 1)),
                  )
                ],
              ),
              const SizedBox(height: 24),
              Expanded(
                child: ListView.builder(
                  itemCount: roomState.participants.length,
                  itemBuilder: (ctx, i) {
                    final p = roomState.participants[i];
                    final peeCount = roomState.logs.values.where((userIds) => userIds.contains(p.userId)).length;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(backgroundColor: p.color, radius: 24, child: const Icon(Icons.person, color: Colors.white)),
                        title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18, letterSpacing: -0.5)),
                        subtitle: Text("Toplam $peeCount kez işedi", style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.grey)),
                        trailing: Text("🚽 $peeCount", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.amber)),
                      ),
                    );
                  }
                ),
              ),
            ],
          ),
        );
      }
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = ref.watch(currentUserProvider);
    final roomStream = ref.watch(roomStreamProvider);

    if (currentUser == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return roomStream.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (err, stack) => Scaffold(body: Center(child: Text('Hata oluştu: $err'))),
      data: (roomState) {
        if (roomState == null) return const Scaffold(body: Center(child: Text("WC yüklenemedi")));

        Map<int, Color> gridColors = {};
        roomState.logs.forEach((minute, userIds) {
          final colors = userIds.map((id) => roomState.participants.firstWhere((p) => p.userId == id).color).toList();
          gridColors[minute] = ColorUtils.calculateBlendedColor(colors);
        });

        return Scaffold(
          appBar: AppBar(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(roomState.title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 22, letterSpacing: -1)),
                Text('WC Kodu: ${roomState.id}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.amber)),
              ],
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.home, color: Colors.black87),
                tooltip: "Ana Sayfaya Dön",
                onPressed: () {
                  ref.read(currentRoomIdProvider.notifier).state = null;
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (_) => const SetupScreen()),
                  );
                },
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12.0),
                child: GestureDetector(
                  onTap: () => _showParticipants(context, roomState),
                  child: CircleAvatar(
                    backgroundColor: currentUser.color, 
                    radius: 20,
                    child: const Icon(Icons.group, color: Colors.white, size: 20)
                  ),
                ),
              )
            ],
          ),
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildStatCard("Günlük Doluluk", "%${roomState.completionRate.toStringAsFixed(1)}"),
                    _buildStatCard("Ortak Karışım", "${roomState.mixedColorsCount} Defa"),
                  ],
                ),
              ),
              
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  itemCount: 24,
                  itemBuilder: (context, hour) {
                    int filledMinutesInHour = 0;
                    for (int m = 0; m < 60; m++) {
                      if (roomState.logs.containsKey((hour * 60) + m)) {
                        filledMinutesInHour++;
                      }
                    }
                    double percentage = (filledMinutesInHour / 60) * 100;
                    double fillFraction = filledMinutesInHour / 60.0;

                    return GestureDetector(
                      onTap: () => _showHourGrid(context, ref, hour, gridColors, currentUser, roomState),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        height: 76,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.black87, width: 2.5),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 4))
                          ]
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(13),
                          child: Stack(
                            children: [
                              Align(
                                alignment: Alignment.centerRight,
                                child: FractionallySizedBox(
                                  widthFactor: fillFraction,
                                  heightFactor: 1.0,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Colors.amber.withOpacity(0.25),
                                    ),
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 20),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Text(
                                      "${hour.toString().padLeft(2, '0')}.00 - ${hour.toString().padLeft(2, '0')}.59",
                                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: -0.5),
                                    ),
                                    Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text("%${percentage.toStringAsFixed(0)}", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: -1)),
                                        const Text("dolu", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.black54)),
                                      ],
                                    )
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

              Container(
                padding: const EdgeInsets.all(24.0),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border(top: BorderSide(color: Colors.grey.shade200, width: 1))
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 20), 
                          backgroundColor: currentUser.color,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        icon: const Icon(Icons.water_drop, color: Colors.white),
                        label: const Text("Şu an işiyorum", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
                        onPressed: () {
                          final now = DateTime.now();
                          final minIndex = (now.hour * 60) + now.minute;
                          _handlePee(context, ref, minIndex, currentUser, roomState);
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Container(
                      height: 64,
                      width: 64,
                      decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade300)),
                      child: IconButton(
                        icon: const Icon(Icons.history, size: 28, color: Colors.black87),
                        onPressed: () async {
                          final time = await showTimePicker(
                            context: context, initialTime: TimeOfDay.now(),
                            builder: (ctx, child) => MediaQuery(data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true), child: child!),
                          );
                          if (time != null) {
                            final minIndex = (time.hour * 60) + time.minute;
                            _handlePee(context, ref, minIndex, currentUser, roomState);
                          }
                        },
                      ),
                    )
                  ],
                ),
              ),
            ],
          ),
        );
      }
    );
  }

  Widget _buildStatCard(String title, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(color: Colors.black54, fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 24, letterSpacing: -1)),
      ],
    );
  }
}
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'ui/shell.dart';
import 'ui/theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Color(0xFF0D0221),
    systemNavigationBarIconBrightness: Brightness.light,
  ));
  runApp(const HelixApp());
}

class HelixApp extends StatelessWidget {
  const HelixApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Helix',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: const ColorScheme.dark(
          primary: H.purple,
          secondary: H.pink,
          surface: H.bgMid,
          onSurface: H.text,
        ),
        scaffoldBackgroundColor: H.bgDeep,
        splashColor: H.purple.withValues(alpha: 0.18),
        highlightColor: H.pink.withValues(alpha: 0.08),
        fontFamily: 'sans-serif',
      ),
      home: const _SplashGate(),
    );
  }
}

class _SplashGate extends StatefulWidget {
  const _SplashGate();
  @override
  State<_SplashGate> createState() => _SplashGateState();
}

class _SplashGateState extends State<_SplashGate> {
  bool ready = false;

  @override
  void initState() {
    super.initState();
    Future<void>.delayed(const Duration(milliseconds: 700), () {
      if (mounted) setState(() => ready = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (ready) return const Shell();
    return const Scaffold(
      backgroundColor: H.bgDeep,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.auto_awesome, color: H.purpleSoft, size: 48),
            SizedBox(height: 12),
            Text('HELIX', style: TextStyle(color: H.text, letterSpacing: 4, fontWeight: FontWeight.w700, fontSize: 22)),
          ],
        ),
      ),
    );
  }
}

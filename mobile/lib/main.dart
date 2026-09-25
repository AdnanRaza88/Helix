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
        fontFamily: 'sans-serif',
      ),
      home: const Shell(),
    );
  }
}

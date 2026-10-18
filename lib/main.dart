import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'home.dart';
import 'theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    systemNavigationBarColor: Color(0xFFEDF1E1),
    systemNavigationBarIconBrightness: Brightness.dark,
  ));
  runApp(const AgriSenseApp());
}

class AgriSenseApp extends StatelessWidget {
  const AgriSenseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AgriSense',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Nunito',
        scaffoldBackgroundColor: C.bg,
        colorScheme: ColorScheme.fromSeed(seedColor: C.matchaDark, brightness: Brightness.light, surface: C.bg),
      ),
      home: const HomeScreen(),
    );
  }
}

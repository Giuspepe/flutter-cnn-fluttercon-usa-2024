import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'game_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    const ProviderScope(
      child: EmotionDetectionApp(),
    ),
  );
}

class EmotionDetectionApp extends StatelessWidget {
  const EmotionDetectionApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Rock Paper Scissors',
      theme: ThemeData(
        textTheme: const TextTheme(
          bodyMedium: TextStyle(fontSize: 24),
        ),
        primarySwatch: Colors.blue,
      ),
      initialRoute: '/game',
      routes: {
        '/game': (context) => const GameScreen(),
      },
    );
  }
}

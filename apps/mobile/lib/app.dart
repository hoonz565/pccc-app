import 'package:flutter/material.dart';

import 'features/development/presentation/development_screen.dart';

class FireSafeApp extends StatelessWidget {
  const FireSafeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FireSafe Development',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.red),
      ),
      home: const DevelopmentScreen(),
    );
  }
}

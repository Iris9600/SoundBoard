import 'package:flutter/material.dart';
import 'pages/name_gate.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'SoundBoard',
      theme: ThemeData(primarySwatch: Colors.deepPurple, useMaterial3: true),
      home: const NameGate(),
    );
  }
}

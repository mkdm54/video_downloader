import 'package:flutter/material.dart';
import 'package:video_downloader/components/custom_tabbar.dart';
import 'package:video_downloader/screens/settings.dart'; // pastikan import halaman settings

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const CustomTabbar(),
      routes: {
        '/settings': (context) => const Settings(), // daftarkan route
      },
    );
  }
}

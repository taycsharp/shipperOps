import 'package:flutter/material.dart';

import 'screens/shipper_home_screen.dart';

void main() {
  runApp(const ShipperMobileApp());
}

class ShipperMobileApp extends StatelessWidget {
  const ShipperMobileApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Shipper Mobile',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1565C0)),
        useMaterial3: true,
        cardTheme: CardThemeData(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(color: Colors.grey.shade200),
          ),
        ),
      ),
      home: const ShipperHomeScreen(),
    );
  }
}

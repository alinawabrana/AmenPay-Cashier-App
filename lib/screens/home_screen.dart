import 'package:amenpay_cashir_app/features/home/screens/enroll_palm_vein_screen.dart';
import 'package:flutter/material.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
        centerTitle: true,
      ),
      body: Center(
        child: SizedBox(
          height: 56,
          child: ElevatedButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const EnrollPalmVeinScreen(),
                ),
              );
            },
            child: const Text('Enroll PalmVein'),
          ),
        ),
      ),
    );
  }
}


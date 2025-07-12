import 'package:flutter/material.dart';

class StatisticsPage extends StatelessWidget {
  const StatisticsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(title: const Text('Statistics'), backgroundColor: Colors.black),
      body: const Center(
        child: Text('Statistics Screen', style: TextStyle(color: Colors.white)),
      ),
    );
  }
}
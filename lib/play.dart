import 'package:flutter/material.dart';

class PlayPage extends StatelessWidget {
  const PlayPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(title: const Text('Play'), backgroundColor: Colors.black),
      body: const Center(
        child: Text('Game Screen', style: TextStyle(color: Colors.white)),
      ),
    );
  }
}
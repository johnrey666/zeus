import 'package:flutter/material.dart';

class TrainerHomePage extends StatelessWidget {
  const TrainerHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Trainer Home"),
        centerTitle: true,
      ),
      body: const Center(
        child: Text(
          "Welcome to Trainer Home Page!",
          style: TextStyle(fontSize: 18),
        ),
      ),
    );
  }
}

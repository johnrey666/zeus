// ignore_for_file: use_build_context_synchronously

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:zeus/pages/member_pages/member_home_page.dart';

class PlanningPage extends StatefulWidget {
  const PlanningPage({super.key});

  @override
  State<PlanningPage> createState() => _PlanningPageState();
}

class _PlanningPageState extends State<PlanningPage> {
  int currentIndex = 0;
  final Map<String, dynamic> answers = {};
  final TextEditingController heightController = TextEditingController();
  final TextEditingController weightController = TextEditingController();
  bool _isTrainer = false;
  bool _isGenerating = false;

  final List<Map<String, dynamic>> questions = [
    {
      'question': "What is your fitness goal?",
      'subtitle': "It will help us to choose a best program for you",
      'options': [
        "Build Muscle",
        "Lose Weight",
        "Improve Endurance",
        "Increase Strength"
      ],
      'type': 'radio',
    },
    {
      'question': "Select Your Fitness Level",
      'options': [
        "Beginner\nnew to exercise or training",
        "Intermediate\nexercise 2 - 3 times per week",
        "Expert\nexercise 4+ times per week",
      ],
      'type': 'radio',
    },
    {
      'question': "Select your activity level",
      'options': [
        "Sedentary (1-2 days/week)",
        "Lightly Active (1-3 days/week)",
        "Moderately Active (3-5 days/week)",
        "Very Active (6-7 days/week)",
        "Extra Active (2x training)"
      ],
      'type': 'radio',
    },
    {
      'question': "Let us know you better",
      'type': 'form',
    }
  ];

  @override
  void initState() {
    super.initState();
    _checkUserType();
  }

  Future<void> _checkUserType() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    setState(() {
      _isTrainer = doc.exists && doc['userType'] == 'Trainer';
    });
  }

  void next() async {
    if (currentIndex < questions.length - 1) {
      setState(() => currentIndex++);
    } else {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      answers['Height'] = heightController.text.trim();
      answers['Weight'] = weightController.text.trim();

      setState(() => _isGenerating = true);

      await FirebaseFirestore.instance
          .collection('workout_plans')
          .doc(user.uid)
          .set(answers);

      await Future.delayed(const Duration(seconds: 3));

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
            builder: (_) => const MemberHomePage(initialTabIndex: 1)),
      );
    }
  }

  void back() {
    if (currentIndex > 0) {
      setState(() => currentIndex--);
    }
  }

  Widget _buildRadioQuestion(Map<String, dynamic> questionData) {
    final String question = questionData['question'];
    final List<String> options = List<String>.from(questionData['options']);
    final String? subtitle = questionData['subtitle'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(question,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        if (subtitle != null)
          Padding(
            padding: const EdgeInsets.only(top: 6.0),
            child: Text(subtitle,
                style: const TextStyle(color: Colors.grey, fontSize: 14)),
          ),
        const SizedBox(height: 20),
        ...options.map((option) => Container(
              margin: const EdgeInsets.symmetric(vertical: 6),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: RadioListTile<String>(
                title: Text(option.replaceAll('\n', '\n'),
                    style: const TextStyle(fontSize: 16)),
                value: option,
                groupValue: answers[question],
                onChanged: (value) {
                  setState(() {
                    answers[question] = value;
                  });
                },
              ),
            ))
      ],
    );
  }

  Widget _buildHeightWeightForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Let us know you better",
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: weightController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: "Weight (kg)",
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: heightController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: "Height (cm)",
                  border: OutlineInputBorder(),
                ),
              ),
            )
          ],
        )
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentQuestion = questions[currentIndex];

    return Scaffold(
      body: _isGenerating
          ? const _LoadingScreen()
          : _isTrainer
              ? const Center(
                  child: Text("Trainers cannot create workout plans."))
              : Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      AppBar(
                        title: const Text("Plan Your Workout"),
                        centerTitle: true,
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                        elevation: 0.5,
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: SingleChildScrollView(
                          child: currentQuestion['type'] == 'radio'
                              ? _buildRadioQuestion(currentQuestion)
                              : _buildHeightWeightForm(),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          if (currentIndex > 0)
                            ElevatedButton(
                              onPressed: back,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.grey[300],
                              ),
                              child: const Text("Back",
                                  style: TextStyle(color: Colors.black)),
                            )
                          else
                            const SizedBox(width: 80),
                          ElevatedButton(
                            onPressed: next,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(
                                  vertical: 12, horizontal: 24),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8)),
                            ),
                            child: Text(
                              currentIndex == questions.length - 1
                                  ? "Get My Plan"
                                  : "Next",
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                        ],
                      )
                    ],
                  ),
                ),
    );
  }
}

class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      width: double.infinity,
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 60,
              height: 60,
              child: CircularProgressIndicator(strokeWidth: 6),
            ),
            SizedBox(height: 24),
            Text(
              "Generating Your Plan...",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text("Analyzing your data and preferences...",
                style: TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}

// ignore_for_file: use_build_context_synchronously

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:zeus/pages/member_pages/member_home_page.dart';
import 'dart:math';

class PlanningPage extends StatefulWidget {
  const PlanningPage({super.key});

  @override
  State<PlanningPage> createState() => _PlanningPageState();
}

class _PlanningPageState extends State<PlanningPage> {
  int currentIndex = 0;
  final Map<String, dynamic> answers = {};
  bool _isTrainer = false;
  bool _isGenerating = false;

  int selectedWeight = 70;
  int selectedHeight = 170;

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
        "Sedentary(little or no exercise)1-2 days a week",
        "Lightly active(light exercise/sports 1-3 days/week)",
        "Moderately Active (moderate exercise/sports 3-5 days/week)",
        "Very active (hard exercise/sports 6-7 days a week)",
        "Extra active(very hard exercise/sports/physical job or 2x training)"
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
    _loadExistingData();
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

  Future<void> _loadExistingData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final doc = await FirebaseFirestore.instance
        .collection('workout_plans')
        .doc(user.uid)
        .get();

    if (doc.exists) {
      final data = doc.data()!;
      setState(() {
        selectedWeight = int.tryParse(data['Weight']?.toString() ?? '') ?? 70;
        selectedHeight = int.tryParse(data['Height']?.toString() ?? '') ?? 170;
      });
    }
  }

  void next() async {
    if (currentIndex < questions.length - 1) {
      setState(() => currentIndex++);
    } else {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      answers['Weight'] = selectedWeight.toString();
      answers['Height'] = selectedHeight.toString();

      setState(() {
  _isGenerating = true;
});

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
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Center(
          child: Text(
            question,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
        ),
        if (subtitle != null)
          Padding(
            padding: const EdgeInsets.only(top: 6.0),
            child: Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey, fontSize: 14),
            ),
          ),
        if (question == "What is your fitness goal?")
          Padding(
            padding: const EdgeInsets.only(top: 16.0),
            child: Image.asset('assets/images/zeus.png', height: 190),
          ),
        const SizedBox(height: 20),
        ...options.map((option) {
          final isSelected = answers[question] == option;

          return GestureDetector(
            onTap: () {
              setState(() {
                answers[question] = option;
              });
            },
            child: Container(
              width: double.infinity,
              margin: const EdgeInsets.symmetric(vertical: 6),
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
              decoration: BoxDecoration(
                gradient: isSelected
                    ? const LinearGradient(
                        colors: [Color(0xFF9DCEFF), Color(0xFF92A3FD)],
                      )
                    : const LinearGradient(
                        colors: [Color(0xFFF7F8F8), Color(0xFFF7F8F8)],
                      ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSelected ? Colors.transparent : Colors.grey.shade300,
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: option.split('\n').map((line) {
                        final isMain = line == option.split('\n').first;
                        return Text(
                          line,
                          style: TextStyle(
                            fontSize: isMain ? 16 : 13,
                            fontWeight: isMain
                                ? FontWeight.bold
                                : FontWeight.normal,
                            color: isSelected ? Colors.white : Colors.black,
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  if (isSelected)
                    const Icon(Icons.check_circle,
                        color: Colors.greenAccent, size: 24),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildHeightWeightForm() {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Center(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: const [
            Text(
              "Let us know you better",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              "Let us know you better to help boast your workout results",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],
        ),
      ),
      const SizedBox(height: 16),
      Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Text(
                  "Weight (kg)",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 150,
                  child: CupertinoPicker(
                    scrollController: FixedExtentScrollController(
                        initialItem: selectedWeight - 30),
                    itemExtent: 40,
                    onSelectedItemChanged: (value) {
                      setState(() {
                        selectedWeight = value + 30;
                      });
                    },
                    children: List.generate(
                      221,
                      (index) => Center(
                        child: Text("${index + 30}",
                            style: const TextStyle(fontSize: 20)),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Text(
                  "Height (cm)",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 150,
                  child: CupertinoPicker(
                    scrollController: FixedExtentScrollController(
                        initialItem: selectedHeight - 100),
                    itemExtent: 40,
                    onSelectedItemChanged: (value) {
                      setState(() {
                        selectedHeight = value + 100;
                      });
                    },
                    children: List.generate(
                      201,
                      (index) => Center(
                        child: Text("${index + 100}",
                            style: const TextStyle(fontSize: 20)),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ],
  );
}

  @override
  Widget build(BuildContext context) {
    final currentQuestion = questions[currentIndex];

    return Scaffold(
      backgroundColor: Colors.white,
      body: _isGenerating
    ? _LoadingScreen(
        goal: answers['What is your fitness goal?'],
        fitnessLevel: answers['Select Your Fitness Level'],
        activityLevel: answers['Select your activity level'],
        height: selectedHeight,
        weight: selectedWeight,
      )

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
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (currentIndex > 0)
                            ElevatedButton(
                              onPressed: back,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.grey[300],
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 32, vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30),
                                ),
                              ),
                              child: const Text("Back",
                                  style: TextStyle(color: Colors.black)),
                            ),
                          const SizedBox(width: 12),
                          Container(
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF9DCEFF), Color(0xFF92A3FD)],
                              ),
                              borderRadius: BorderRadius.circular(30),
                            ),
                            child: ElevatedButton(
                              onPressed: next,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 32, vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30),
                                ),
                              ),
                              child: Text(
                                currentIndex == questions.length - 1
                                    ? "Get My Plan"
                                    : "Continue",
                                style: const TextStyle(color: Colors.white),
                              ),
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
  final String goal;
  final String fitnessLevel;
  final String activityLevel;
  final int height;
  final int weight;

  const _LoadingScreen({
    super.key,
    required this.goal,
    required this.fitnessLevel,
    required this.activityLevel,
    required this.height,
    required this.weight,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 80),
          const Text(
            "GENERATING THE PLAN FOR YOU",
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
              color: Colors.black,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Text(
            "Preparing your plan based on your goal...",
            style: TextStyle(color: Colors.grey, fontSize: 14),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 90),

          /// Custom Spinning Dot Loader
          const SpinningFadeDots(),

          const SizedBox(height: 90),

          _DataRow(label: "Your fitness goal:", value: goal),
          _DataRow(label: "Your fitness level:", value: fitnessLevel.split('\n').first),
          _DataRow(label: "Your activity level:", value: activityLevel.split('(').first.trim()),
          _DataRow(
              label: "Analyze you:",
              value: "${height ~/ 30}ft ${height % 30}in, ${weight.toStringAsFixed(1)}lbs"),
          const SizedBox(height: 80),
        ],
      ),
    );
  }
}

class _DataRow extends StatelessWidget {
  final String label;
  final String value;

  const _DataRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.check_circle_rounded, color: Colors.blue, size: 16),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(width: 4),
          Text(value,
              style: const TextStyle(fontSize: 12, color: Colors.blue, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

class SpinningFadeDots extends StatefulWidget {
  const SpinningFadeDots({super.key});

  @override
  State<SpinningFadeDots> createState() => _SpinningFadeDotsState();
}

class _SpinningFadeDotsState extends State<SpinningFadeDots> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _buildDot(int index) {
    final double radius = 60;
    final angle = (2 * pi * index) / 12;

    return AnimatedBuilder(
      animation: _controller,
      builder: (_, __) {
        final progress = (_controller.value * 12).floor() % 12;
        final isActive = index == progress;

        return Transform.translate(
          offset: Offset(radius * cos(angle), radius * sin(angle)),
          child: Opacity(
            opacity: isActive ? 1.0 : 0.3,
            child: Container(
              width: 18,
              height: 18,
              decoration: const BoxDecoration(
                color: Colors.blue,
                shape: BoxShape.circle,
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 100,
      height: 100,
      child: Center(
        child: Stack(
          alignment: Alignment.center,
          children: List.generate(12, _buildDot),
        ),
      ),
    );
  }
}
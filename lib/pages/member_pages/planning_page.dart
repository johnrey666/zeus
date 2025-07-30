// ignore_for_file: use_build_context_synchronously

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
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

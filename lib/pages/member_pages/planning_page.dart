import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PlanningPage extends StatefulWidget {
  final Map<String, dynamic>? existingData;

  const PlanningPage({super.key, this.existingData});

  @override
  State<PlanningPage> createState() => _PlanningPageState();
}

class _PlanningPageState extends State<PlanningPage> {
  int currentIndex = 0;
  final Map<String, dynamic> answers = {};

  final List<Map<String, dynamic>> questions = [
    {
      'question': "What is your fitness goal?",
      'options': ["Loss Weight", "Gain Weight", "Maintain Weight", "Muscle Gain"],
      'type': 'radio',
    },
    {
      'question': "How many days a week do you want to train?",
      'options': ["1-2 days", "3-4 days", "5-6 days", "Everyday"],
      'type': 'radio',
    },
    {
      'question': "Do you follow any of these diets?",
      'options': ["Vegetarian", "Non-Vegetarian", "None of the above"],
      'type': 'radio',
    },
    {
      'question': "Select Fitness Level",
      'options': ["Beginner", "Intermediate", "Advanced"],
      'type': 'radio',
    },
    {
      'question': "Set Up Your Workout Plan",
      'days': ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"],
      'type': 'dropdown',
    },
  ];

  final List<String> workoutTypes = ['Cardio', 'Strength', 'Flexibility', 'Rest'];

  @override
  void initState() {
    super.initState();
    _initializeAnswers();
  }

  void _initializeAnswers() {
    if (widget.existingData != null) {
      answers.addAll(widget.existingData!);
    }
  }

  void next() async {
    if (currentIndex < questions.length - 1) {
      setState(() => currentIndex++);
    } else {
      try {
        final user = FirebaseAuth.instance.currentUser;
        if (user == null) throw Exception("User not logged in");
        final uid = user.uid;

        await FirebaseFirestore.instance.collection('workout_plans').doc(uid).set(answers);
        if (!mounted) return;
        Navigator.pop(context, true); // Signal success
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to save workout plan: $e")),
        );
      }
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(question, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        ...options.map((option) => Container(
              margin: const EdgeInsets.symmetric(vertical: 4),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.2),
                    blurRadius: 5,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: RadioListTile<String>(
                title: Text(option),
                value: option,
                groupValue: answers[question],
                onChanged: (value) {
                  setState(() {
                    answers[question] = value;
                  });
                },
              ),
            )),
      ],
    );
  }

  Widget _buildDropdownQuestion(Map<String, dynamic> questionData) {
    final String question = questionData['question'];
    final List<String> days = List<String>.from(questionData['days']);

    answers.putIfAbsent(question, () {
      return {for (var day in days) day: null};
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(question, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        Expanded(
          child: ListView.builder(
            itemCount: days.length,
            itemBuilder: (context, index) {
              final day = days[index];
              return Container(
                margin: const EdgeInsets.symmetric(vertical: 8),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.2),
                      blurRadius: 5,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: DropdownButtonFormField<String>(
                  decoration: InputDecoration(labelText: day, border: InputBorder.none),
                  value: answers[question][day],
                  items: workoutTypes
                      .map((type) => DropdownMenuItem(value: type, child: Text(type)))
                      .toList(),
                  onChanged: (value) {
                    setState(() {
                      answers[question][day] = value;
                    });
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentQuestion = questions[currentIndex];

    return Scaffold(
      appBar: AppBar(
        title: const Text("Plan Your Workout"),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0.5,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Expanded(
              child: currentQuestion['type'] == 'dropdown'
                  ? _buildDropdownQuestion(currentQuestion)
                  : SingleChildScrollView(child: _buildRadioQuestion(currentQuestion)),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (currentIndex > 0)
                  ElevatedButton(
                    onPressed: back,
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.grey[300]),
                    child: const Text("Back", style: TextStyle(color: Colors.black)),
                  )
                else
                  const SizedBox(width: 80),
                ElevatedButton(
                  onPressed: next,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: Text(
                    currentIndex == questions.length - 1 ? "Submit" : "Next",
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

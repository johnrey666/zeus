// ignore_for_file: use_build_context_synchronously, prefer_const_constructors, curly_braces_in_flow_control_structures, invalid_return_type_for_catch_error
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart'; // For debugPrint
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconly/iconly.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:intl/intl.dart';
import 'dart:async'; // Added for Timer

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => HomePageState();
}

class HomePageState extends State<HomePage> {
  final user = FirebaseAuth.instance.currentUser;
  bool _isLoading = true;
  bool _isLoadingAISuggestions = true;
  Map<DateTime, List<Map<String, dynamic>>> _events = {};
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  String _selectedBodyPart = 'Abs';
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  Map<String, dynamic> _userPlan = {};
  List<String> _suggestedWorkouts = [];
  Map<String, int> _workoutDurations = {};
  bool _isAISuggestionFallback = false;
  late ScrollController _scrollController; // Add this
  static const _apiKey = 'AIzaSyB5_B3sIGAe6GHPV9F-ULUn7VHqQxUPdmA';
  late final GenerativeModel _model =
      GenerativeModel(model: 'gemini-2.5-flash', apiKey: _apiKey);
  final Map<String, List<String>> _programWorkouts = {
    'Fullbody Workout': [
      'Warm-up',
      'Push-Ups',
      'Squats',
      'Plank',
      'Bicep Curls',
      'Yoga'
    ],
    'Lowerbody Workout': ['Warm-up', 'Jumping Jacks', 'Squats', 'Lunges'],
    'AB Workout': ['Warm-up', 'Plank', 'Crunches'],
  };

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController(); // Initialize here
    _selectedDay = _focusedDay;
    _initializeData();
  }

  @override
  void dispose() {
    _scrollController.dispose(); // Dispose here
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _initializeData() async {
    final uid = user!.uid;
    final calendarSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('calendar')
        .get();
    final Map<DateTime, List<Map<String, dynamic>>> tempEvents = {};
    for (var doc in calendarSnapshot.docs) {
      final data = doc.data();
      final timestamp = data['timestamp']?.toDate();
      if (timestamp != null) {
        final key = DateTime(timestamp.year, timestamp.month, timestamp.day);
        tempEvents.putIfAbsent(key, () => []);
        tempEvents[key]!.add({...data, 'id': doc.id});
      }
    }
    await _loadUserPlan();
    if (mounted) {
      setState(() {
        _events = tempEvents;
        _isLoading = false;
      });
    }
    // Load AI suggestions (cached or fresh)
    await _loadAISuggestions();
  }

  Future<void> _loadUserPlan() async {
    if (user == null) return;

    try {
      final planSnapshot = await FirebaseFirestore.instance
          .collection('workout_plans')
          .doc(user!.uid)
          .get();

      if (mounted) {
        setState(() {
          _userPlan = planSnapshot.exists ? planSnapshot.data()! : {};
        });
      }

      // Force reload AI suggestions when user plan changes
      await _loadAISuggestions();
    } catch (e) {
      debugPrint('Error loading user plan: $e');
      if (mounted) {
        setState(() {
          _userPlan = {};
        });
      }
    }
  }

  Future<void> _saveAISuggestionsToFirestore(List<String> workouts,
      Map<String, int> durations, String? inputHash) async {
    if (user == null) return;

    try {
      final saveData = {
        'ai_suggestions': workouts,
        'ai_durations': durations,
        'ai_input_hash': inputHash ?? '',
        'last_updated': FieldValue.serverTimestamp(),
      };

      await FirebaseFirestore.instance
          .collection('workout_plans')
          .doc(user!.uid)
          .set(saveData, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error saving AI suggestions: $e');
    }
  }

  Future<Map<String, dynamic>?> _loadAISuggestionsFromFirestore() async {
    if (user == null) return null;

    try {
      final planSnapshot = await FirebaseFirestore.instance
          .collection('workout_plans')
          .doc(user!.uid)
          .get();

      if (!planSnapshot.exists) return null;

      final data = planSnapshot.data();
      if (data == null ||
          !data.containsKey('ai_suggestions') ||
          !data.containsKey('ai_durations') ||
          !data.containsKey('ai_input_hash')) {
        return null;
      }

      final suggestions = List<String>.from(data['ai_suggestions'] ?? []);
      final durationsData =
          Map<String, dynamic>.from(data['ai_durations'] ?? {});
      final durations = durationsData.map((key, value) => MapEntry(
          key, value is int ? value : int.tryParse(value.toString()) ?? 15));
      final savedHash = data['ai_input_hash']?.toString() ?? '';

      return {
        'workouts': suggestions,
        'durations': durations,
        'hash': savedHash
      };
    } catch (e) {
      debugPrint('Error loading AI suggestions from Firestore: $e');
      return null;
    }
  }

  void refreshAISuggestions() {
    if (_isLoadingAISuggestions) return;

    setState(() {
      _isLoadingAISuggestions = true;
    });

    // Clear the cached AI suggestions to force regeneration
    FirebaseFirestore.instance
        .collection('workout_plans')
        .doc(user!.uid)
        .update({
      'ai_input_hash': FieldValue.delete(),
    }).then((_) {
      _loadAISuggestions();
    }).catchError((e) {
      debugPrint('Error clearing AI cache: $e');
      _loadAISuggestions();
    });
  }

  Future<void> _loadAISuggestions() async {
    if (mounted) {
      setState(() {
        _isLoadingAISuggestions = true;
      });
    }

    try {
      final currentHash = _computeInputHash();

      debugPrint('Current user data hash: $currentHash');

      // Always regenerate if we have user data, don't use cache
      if (currentHash.isNotEmpty) {
        debugPrint('User data available, forcing AI regeneration...');
        final aiData = await _generateAIDataCombined();
        if (mounted) {
          setState(() {
            _suggestedWorkouts = aiData['workouts'] as List<String>;
            _workoutDurations = aiData['durations'] as Map<String, int>;
            _isLoadingAISuggestions = false;
          });
          await _saveAISuggestionsToFirestore(
            _suggestedWorkouts,
            _workoutDurations,
            currentHash,
          );
        }
        return;
      }

      // If no user data, try cache or use fallback
      final savedData = await _loadAISuggestionsFromFirestore();
      if (savedData != null && savedData['hash'] == currentHash) {
        if (mounted) {
          setState(() {
            _suggestedWorkouts = List<String>.from(savedData['workouts']);
            _workoutDurations = Map<String, int>.from(savedData['durations']);
            _isLoadingAISuggestions = false;
            _isAISuggestionFallback = false;
          });
        }
        return;
      }

      // No data and no cache - use fallback
      if (mounted) {
        setState(() {
          _suggestedWorkouts = ['Warm-up', 'Squats', 'Yoga', 'Plank'];
          _workoutDurations = _getDefaultDurations();
          _isLoadingAISuggestions = false;
          _isAISuggestionFallback = true;
        });
      }
    } catch (e) {
      debugPrint('Error loading AI suggestions: $e');
      if (mounted) {
        setState(() {
          _suggestedWorkouts = ['Warm-up', 'Squats', 'Yoga', 'Plank'];
          _workoutDurations = _getDefaultDurations();
          _isLoadingAISuggestions = false;
          _isAISuggestionFallback = true;
        });
      }
    }
  }

  String _computeInputHash() {
    if (_userPlan.isEmpty) return '';

    final goal = _userPlan['What is your fitness goal?']?.toString() ?? '';
    final fitnessLevel =
        _userPlan['Select Your Fitness Level']?.toString() ?? '';
    final activityLevel =
        _userPlan['Select your activity level']?.toString() ?? '';

    // Get weight and height from userPlan, don't use defaults
    final weightStr = _userPlan['Weight']?.toString() ?? '';
    final heightStr = _userPlan['Height']?.toString() ?? '';

    // If weight or height is empty/missing, return empty hash to force regeneration
    if (weightStr.isEmpty || heightStr.isEmpty) {
      return '';
    }

    final weight = int.tryParse(weightStr) ?? 0;
    final height = int.tryParse(heightStr) ?? 0;

    // If we have invalid weight/height values, return empty hash
    if (weight <= 0 || height <= 0) {
      return '';
    }

    final heightInMeters = height / 100;
    final bmi = weight / (heightInMeters * heightInMeters);

    String bmiCategory = 'Normal';
    if (bmi < 18.5)
      bmiCategory = 'Underweight';
    else if (bmi < 25)
      bmiCategory = 'Normal';
    else if (bmi < 30)
      bmiCategory = 'Overweight';
    else
      bmiCategory = 'Obese';

    return json.encode({
      'goal': goal,
      'fitnessLevel': fitnessLevel,
      'activityLevel': activityLevel,
      'bmiCategory': bmiCategory,
      'weight': weight, // Include raw values in hash
      'height': height, // Include raw values in hash
    });
  }

  Future<Map<String, dynamic>> _generateAIDataCombined() async {
    final defaultData = {
      'workouts': ['Warm-up', 'Squats', 'Yoga', 'Plank'],
      'durations': _getDefaultDurations(),
    };

    final availableWorkoutsList = [
      'Plank',
      'Crunches',
      'Push-Ups',
      'Incline Push-Ups',
      'Bench Press',
      'Yoga',
      'Jumping Jacks',
      'Squats',
      'Lunges',
      'Bicep Curls',
      'Dumbbell Curl',
      'Cable Flyes',
      'Warm-up',
      'Dumbbell Press',
    ];

    // DEBUG: Print user data to see what's being used
    debugPrint('=== AI GENERATION DEBUG ===');
    debugPrint('User Plan: $_userPlan');
    debugPrint('Goal: ${_userPlan['What is your fitness goal?']}');
    debugPrint('Fitness Level: ${_userPlan['Select Your Fitness Level']}');
    debugPrint('Activity Level: ${_userPlan['Select your activity level']}');
    debugPrint('Weight: ${_userPlan['Weight']}');
    debugPrint('Height: ${_userPlan['Height']}');
    debugPrint('===========================');

    // Check if we have sufficient user data
    if (_userPlan.isEmpty) {
      debugPrint('User plan is empty - using fallback');
      _isAISuggestionFallback = true;
      return defaultData;
    }

    final goal = _userPlan['What is your fitness goal?']?.toString();
    final fitnessLevel = _userPlan['Select Your Fitness Level']?.toString();
    final activityLevel = _userPlan['Select your activity level']?.toString();
    final weightStr = _userPlan['Weight']?.toString();
    final heightStr = _userPlan['Height']?.toString();

    // Check if we have all required data
    if (goal == null ||
        goal.isEmpty ||
        fitnessLevel == null ||
        fitnessLevel.isEmpty ||
        activityLevel == null ||
        activityLevel.isEmpty ||
        weightStr == null ||
        weightStr.isEmpty ||
        heightStr == null ||
        heightStr.isEmpty) {
      debugPrint('Missing required user data - using fallback');
      _isAISuggestionFallback = true;
      return defaultData;
    }

    final weight = int.tryParse(weightStr) ?? 0;
    final height = int.tryParse(heightStr) ?? 0;

    // Validate we have proper data
    if (weight <= 0 || height <= 0) {
      debugPrint('Invalid weight/height values - using fallback');
      _isAISuggestionFallback = true;
      return defaultData;
    }

    try {
      final heightInMeters = height / 100;
      final bmi = weight / (heightInMeters * heightInMeters);
      String bmiCategory = 'Normal';
      if (bmi < 18.5)
        bmiCategory = 'Underweight';
      else if (bmi < 25)
        bmiCategory = 'Normal';
      else if (bmi < 30)
        bmiCategory = 'Overweight';
      else
        bmiCategory = 'Obese';

      final availableWorkouts = availableWorkoutsList.join(', ');

      final prompt = '''
User Profile:
- Fitness Goal: $goal
- Fitness Level: $fitnessLevel  
- Activity Level: $activityLevel
- BMI Category: $bmiCategory (Weight: $weight kg, Height: $height cm)

Based on this profile, suggest exactly 4 personalized workout names from this list only: $availableWorkouts

Consider:
- For beginners: focus on foundational exercises like Squats, Push-Ups, Plank
- For weight loss: include cardio like Jumping Jacks, Yoga
- For muscle gain: include strength exercises like Bench Press, Bicep Curls
- Match intensity to fitness level

Return ONLY valid JSON in this exact format (no other text):
{
  "suggestions": ["Workout1", "Workout2", "Workout3", "Workout4"],
  "durations": {
    "Plank": 30, "Crunches": 45, "Push-Ups": 20, "Incline Push-Ups": 20,
    "Bench Press": 30, "Yoga": 30, "Jumping Jacks": 15, "Squats": 25,
    "Lunges": 25, "Bicep Curls": 20, "Dumbbell Curl": 20, "Cable Flyes": 25,
    "Warm-up": 10, "Dumbbell Press": 25
  }
}
''';

      debugPrint('Sending prompt to AI...');

      final content = await _model.generateContent([Content.text(prompt)]);
      final response = content.text ?? '';

      debugPrint('AI Response: $response');

      if (response.isEmpty) {
        throw Exception('Empty response from AI');
      }

      // Clean the response
      final cleaned = response
          .trim()
          .replaceAll(RegExp(r'```(?:json)?'), '')
          .replaceAll('```', '')
          .trim();

      debugPrint('Cleaned response: $cleaned');

      final Map<String, dynamic> jsonData = json.decode(cleaned);
      final List<dynamic> suggestionsList = jsonData['suggestions'] ?? [];

      debugPrint('Parsed suggestions: $suggestionsList');

      // Validate suggestions
      final List<String> suggestions = suggestionsList
          .map((item) => item.toString().trim())
          .where((w) => availableWorkoutsList.contains(w))
          .take(4)
          .toList();

      if (suggestions.length < 4) {
        debugPrint(
            'AI returned only ${suggestions.length} valid suggestions, filling with defaults');
        // Fill missing slots with appropriate defaults
        final defaultSuggestions = ['Warm-up', 'Squats', 'Push-Ups', 'Plank'];
        for (int i = suggestions.length; i < 4; i++) {
          suggestions.add(defaultSuggestions[i]);
        }
      }

      final Map<String, dynamic> durationsMap = jsonData['durations'] ?? {};
      final Map<String, int> durations = {};

      for (var entry in durationsMap.entries) {
        final workout = entry.key.toString().trim();
        final duration = int.tryParse(entry.value.toString()) ?? 15;
        if (availableWorkoutsList.contains(workout)) {
          durations[workout] =
              duration.clamp(10, 60); // Limit to reasonable range
        }
      }

      // Fill in missing durations with defaults
      for (var workout in availableWorkoutsList) {
        if (!durations.containsKey(workout)) {
          durations[workout] = _getDefaultDuration(workout);
        }
      }

      debugPrint('Final suggestions: $suggestions');
      _isAISuggestionFallback = false;
      return {'workouts': suggestions, 'durations': durations};
    } catch (e) {
      debugPrint('AI Generation Error: $e');
      debugPrint('Stack trace: ${e.toString()}');
    }

    debugPrint('Using fallback workouts due to error');
    _isAISuggestionFallback = true;
    return defaultData;
  }

  Map<String, int> _getDefaultDurations() {
    return {
      'Plank': 15,
      'Crunches': 15,
      'Push-Ups': 20,
      'Incline Push-Ups': 20,
      'Bench Press': 30,
      'Yoga': 30,
      'Jumping Jacks': 15,
      'Squats': 20,
      'Lunges': 20,
      'Bicep Curls': 15,
      'Dumbbell Curl': 15,
      'Cable Flyes': 25,
      'Warm-up': 10,
      'Dumbbell Press': 25,
    };
  }

  int _getDefaultDuration(String workout) {
    final defaults = _getDefaultDurations();
    return defaults[workout] ?? 15;
  }

  int _getWorkoutDuration(String workoutName) {
    return _workoutDurations[workoutName] ?? _getDefaultDuration(workoutName);
  }

  List<Map<String, dynamic>> _getEventsForDay(DateTime day) {
    return _events[DateTime(day.year, day.month, day.day)] ?? [];
  }

  Future<void> _markAsDoneForEvent(
      String calendarId, String workoutName, Timestamp timestamp) async {
    final uid = user!.uid;
    // Update calendar
    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('calendar')
        .doc(calendarId)
        .update({'completed': true});
    // Update training
    final trainingQuery = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('training')
        .where('timestamp', isEqualTo: timestamp)
        .where('workout', isEqualTo: workoutName)
        .get();
    for (var doc in trainingQuery.docs) {
      await doc.reference.update({'completed': true});
    }
  }

  void _showScheduledWorkoutsModal(
      DateTime day, List<Map<String, dynamic>> events) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.6,
        padding: EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Scheduled Workouts",
              style: GoogleFonts.poppins(
                fontSize: 24,
                fontWeight: FontWeight.w600,
                color: Colors.black,
              ),
            ),
            SizedBox(height: 8),
            Text(
              DateFormat('EEEE, MMMM d, yyyy').format(day),
              style: GoogleFonts.poppins(
                fontSize: 16,
                color: Colors.grey.shade600,
              ),
            ),
            SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount: events.length,
                itemBuilder: (context, index) {
                  final event = events[index];
                  final workout = event['workout'];
                  final duration = event['duration'] ?? 15;
                  final completed = event['completed'] ?? false;
                  final image = event['image'] ?? _getWorkoutImage(workout);
                  return Container(
                    margin: EdgeInsets.only(bottom: 12),
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.1),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.asset(
                            image,
                            width: 60,
                            height: 60,
                            fit: BoxFit.cover,
                            errorBuilder: (c, e, s) => Icon(
                              Icons.fitness_center,
                              size: 60,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                        SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                workout,
                                style: GoogleFonts.poppins(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Text(
                                "$duration mins",
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Row(
                          children: [
                            IconButton(
                              icon: Icon(Icons.play_arrow, color: Colors.blue),
                              onPressed: () =>
                                  _showVideoModal(context, workout, true),
                            ),
                            if (!completed)
                              ElevatedButton(
                                onPressed: () async {
                                  await _markAsDoneForEvent(
                                    event['id'],
                                    workout,
                                    event['timestamp'],
                                  );
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Marked as done!'),
                                        backgroundColor: Colors.green,
                                      ),
                                    );
                                  }
                                  Navigator.pop(context);
                                  _initializeData();
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 8,
                                  ),
                                ),
                                child: Text("Done"),
                              )
                            else
                              Icon(
                                Icons.check_circle,
                                color: Colors.green,
                              ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showWorkoutDetails(String workoutName, bool isFromSuggested) {
    final now = DateTime.now();
    DateTime selectedDate = now;
    final duration = _getWorkoutDuration(workoutName);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.fromLTRB(24, 24, 24, 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.shade100, width: 1.5),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.asset(
                    _getWorkoutImage(workoutName),
                    width: 80,
                    height: 80,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Icon(
                      IconlyLight.activity,
                      size: 80,
                      color: Colors.blue.shade300,
                    ),
                  ),
                ),
              ).animate().fadeIn(duration: 300.ms),
              SizedBox(height: 12),
              TextButton(
                onPressed: () {
                  _showVideoModal(context, workoutName, isFromSuggested);
                },
                child: Text(
                  "Show Demo",
                  style: GoogleFonts.poppins(
                    color: Colors.blue.shade300,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              SizedBox(height: 8),
              Text(
                workoutName,
                style: GoogleFonts.poppins(
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                  color: Colors.black,
                ),
              ),
              if (isFromSuggested) ...[
                SizedBox(height: 8),
                Text(
                  "$duration mins per session",
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
              SizedBox(height: 12),
              Divider(color: Colors.grey.shade200),
              SizedBox(height: 8),
              Row(
                children: [
                  Icon(IconlyLight.calendar,
                      color: Colors.blue.shade300, size: 20),
                  SizedBox(width: 8),
                  Text(
                    "Choose a date",
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8),
              GestureDetector(
                onTap: () async {
                  final pickedDate = await showDatePicker(
                    context: context,
                    initialDate: now,
                    firstDate: now,
                    lastDate: DateTime(now.year + 1),
                    builder: (context, child) {
                      return Theme(
                        data: Theme.of(context).copyWith(
                          dialogBackgroundColor: Colors.white,
                          colorScheme: ColorScheme.light(
                            primary: Colors.blue.shade100,
                            onPrimary: Colors.white,
                            onSurface: Colors.black,
                          ),
                          textButtonTheme: TextButtonThemeData(
                            style: ButtonStyle(
                              foregroundColor:
                                  MaterialStateProperty.all(Colors.green),
                              overlayColor: MaterialStateProperty.all(
                                  Colors.green.withOpacity(0.1)),
                            ),
                          ),
                          dialogTheme: DialogTheme(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                        child: child!,
                      );
                    },
                  );
                  if (pickedDate != null) {
                    setModalState(() => selectedDate = pickedDate);
                  }
                },
                child: Container(
                  height: 52,
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Text(
                          "${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}",
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: Colors.black,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      SizedBox(width: 8),
                      Icon(Icons.calendar_today_outlined,
                          size: 18, color: Colors.blue.shade300),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 24),
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: LinearGradient(
                    colors: [Color(0xFF9DCEFF), Color(0xFF92A3FD)],
                  ),
                ),
                child: ElevatedButton.icon(
                  icon: Icon(IconlyLight.plus, size: 20),
                  label: Text(
                    "Add to Calendar",
                    style: GoogleFonts.poppins(fontSize: 16),
                  ),
                  style: ElevatedButton.styleFrom(
                    elevation: 0,
                    foregroundColor: Colors.white,
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () async {
                    final image = _getWorkoutImage(workoutName);
                    final data = {
                      'workout': workoutName,
                      'timestamp': Timestamp.fromDate(selectedDate),
                      'image': image,
                      'completed': false,
                      'duration': duration,
                    };
                    final uid = user!.uid;
                    final calendarRef = FirebaseFirestore.instance
                        .collection('users')
                        .doc(uid)
                        .collection('calendar');
                    final trainingRef = FirebaseFirestore.instance
                        .collection('users')
                        .doc(uid)
                        .collection('training');
                    await calendarRef.add(data);
                    await trainingRef.add(data);
                    Navigator.pop(context);
                    _initializeData();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          '$workoutName saved to calendar!',
                          style: GoogleFonts.poppins(),
                        ),
                        backgroundColor: Colors.blue.shade300,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        margin: EdgeInsets.all(16),
                      ),
                    );
                  },
                ),
              ).animate().slideY(begin: 0.2, end: 0, duration: 300.ms),
              SizedBox(height: 16),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  "Cancel",
                  style: GoogleFonts.poppins(
                    color: Colors.redAccent,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showProgramModal(String title, List<String> workouts) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        padding: EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: GoogleFonts.poppins(
                fontSize: 24,
                fontWeight: FontWeight.w600,
                color: Colors.black,
              ),
            ),
            SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount: workouts.length,
                itemBuilder: (context, index) {
                  final workout = workouts[index];
                  return Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.asset(
                            _getWorkoutImage(workout),
                            width: 60,
                            height: 60,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => Icon(
                              IconlyLight.activity,
                              size: 60,
                              color: Colors.blue.shade300,
                            ),
                          ),
                        ),
                        SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            workout,
                            style: GoogleFonts.poppins(
                              fontSize: 18,
                              fontWeight: FontWeight.w500,
                              color: Colors.black,
                            ),
                          ),
                        ),
                        Row(
                          children: [
                            TextButton(
                              onPressed: () =>
                                  _showVideoModal(context, workout, false),
                              child: Text(
                                "Demo",
                                style: GoogleFonts.poppins(
                                  color: Colors.blue.shade300,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            SizedBox(width: 8),
                            TextButton(
                              onPressed: () => _showAddToCalendarModal(workout),
                              child: Text(
                                "Add",
                                style: GoogleFonts.poppins(
                                  color: Colors.green,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddToCalendarModal(String workoutName) {
    final now = DateTime.now();
    DateTime selectedDate = now;
    final duration = _getWorkoutDuration(workoutName);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.fromLTRB(24, 24, 24, 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                workoutName,
                style: GoogleFonts.poppins(
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                  color: Colors.black,
                ),
              ),
              SizedBox(height: 12),
              Divider(color: Colors.grey.shade200),
              SizedBox(height: 8),
              Row(
                children: [
                  Icon(IconlyLight.calendar,
                      color: Colors.blue.shade300, size: 20),
                  SizedBox(width: 8),
                  Text(
                    "Choose a date",
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8),
              GestureDetector(
                onTap: () async {
                  final pickedDate = await showDatePicker(
                    context: context,
                    initialDate: now,
                    firstDate: now,
                    lastDate: DateTime(now.year + 1),
                    builder: (context, child) {
                      return Theme(
                        data: Theme.of(context).copyWith(
                          dialogBackgroundColor: Colors.white,
                          colorScheme: ColorScheme.light(
                            primary: Colors.blue.shade100,
                            onPrimary: Colors.white,
                            onSurface: Colors.black,
                          ),
                          textButtonTheme: TextButtonThemeData(
                            style: ButtonStyle(
                              foregroundColor:
                                  MaterialStateProperty.all(Colors.green),
                              overlayColor: MaterialStateProperty.all(
                                  Colors.green.withOpacity(0.1)),
                            ),
                          ),
                          dialogTheme: DialogTheme(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                        child: child!,
                      );
                    },
                  );
                  if (pickedDate != null) {
                    setModalState(() => selectedDate = pickedDate);
                  }
                },
                child: Container(
                  height: 52,
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Text(
                          "${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}",
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: Colors.black,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      SizedBox(width: 8),
                      Icon(Icons.calendar_today_outlined,
                          size: 18, color: Colors.blue.shade300),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 24),
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: LinearGradient(
                    colors: [Color(0xFF9DCEFF), Color(0xFF92A3FD)],
                  ),
                ),
                child: ElevatedButton.icon(
                  icon: Icon(IconlyLight.plus, size: 20),
                  label: Text(
                    "Add to Calendar",
                    style: GoogleFonts.poppins(fontSize: 16),
                  ),
                  style: ElevatedButton.styleFrom(
                    elevation: 0,
                    foregroundColor: Colors.white,
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () async {
                    final image = _getWorkoutImage(workoutName);
                    final data = {
                      'workout': workoutName,
                      'timestamp': Timestamp.fromDate(selectedDate),
                      'image': image,
                      'completed': false,
                      'duration': duration,
                    };
                    final uid = user!.uid;
                    final calendarRef = FirebaseFirestore.instance
                        .collection('users')
                        .doc(uid)
                        .collection('calendar');
                    final trainingRef = FirebaseFirestore.instance
                        .collection('users')
                        .doc(uid)
                        .collection('training');
                    await calendarRef.add(data);
                    await trainingRef.add(data);
                    Navigator.pop(context);
                    _initializeData();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          '$workoutName saved to calendar!',
                          style: GoogleFonts.poppins(),
                        ),
                        backgroundColor: Colors.blue.shade300,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        margin: EdgeInsets.all(16),
                      ),
                    );
                  },
                ),
              ).animate().slideY(begin: 0.2, end: 0, duration: 300.ms),
              SizedBox(height: 16),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  "Cancel",
                  style: GoogleFonts.poppins(
                    color: Colors.redAccent,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showVideoModal(
      BuildContext context, String workoutName, bool showDuration) {
    final String videoPath = _getWorkoutVideo(workoutName);
    final int duration = _getWorkoutDuration(workoutName);
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => VideoPlayerDialog(
        videoPath: videoPath,
        workoutName: workoutName,
        showDuration: showDuration,
        duration: duration,
      ),
    );
  }

  String _getWorkoutVideo(String title) {
    final lower = title.toLowerCase();
    if (lower.contains('plank')) return 'assets/videos/plank.mp4';
    if (lower.contains('crunch')) return 'assets/videos/crunches.mp4';
    if (lower.contains('push-up') ||
        lower.contains('push up') ||
        lower.contains('incline push-ups')) return 'assets/videos/push_up.mp4';
    if (lower.contains('bench')) return 'assets/videos/bench_press.mp4';
    if (lower.contains('yoga')) return 'assets/videos/yoga.mp4';
    if (lower.contains('cardio') ||
        lower.contains('jump') ||
        lower.contains('jumping') ||
        lower.contains('jumping jack'))
      return 'assets/videos/jumping_jacks.mp4';
    if (lower.contains('squat')) return 'assets/videos/squat.mp4';
    if (lower.contains('lunge')) return 'assets/videos/lunge.mp4';
    if (lower.contains('bicep') || lower.contains('dumbbell curl'))
      return 'assets/videos/bicep_curl.mp4';
    if (lower.contains('cable')) return 'assets/videos/cable_flyes.mp4';
    if (lower.contains('warm-up')) return 'assets/videos/warm_up.mp4';
    // Fixed: Check for exact "dumbbell press" before other dumbbell matches
    if (lower.contains('dumbbell press'))
      return 'assets/videos/dumbbell_press.mp4';
    return 'assets/videos/dumbbell_press.mp4'; // Consistent default
  }

  String _getWorkoutImage(String title) {
    final lower = title.toLowerCase();
    if (lower.contains('plank')) return 'assets/images/plank.jpg';
    if (lower.contains('crunch')) return 'assets/images/crunches.jpg';
    if (lower.contains('push-up') || lower.contains('push up'))
      return 'assets/images/push_up.jpg';
    if (lower.contains('bench')) return 'assets/images/bench_press.jpg';
    if (lower.contains('yoga')) return 'assets/images/yoga.jpg';
    if (lower.contains('cardio') ||
        lower.contains('jump') ||
        lower.contains('jumping')) return 'assets/images/jumping_jacks.jpg';
    if (lower.contains('squat')) return 'assets/images/squat.jpg';
    if (lower.contains('lunge')) return 'assets/images/lunge.jpg';
    if (lower.contains('bicep') || lower.contains('dumbbell curl'))
      return 'assets/images/bicep_curl.jpg';
    if (lower.contains('cable')) return 'assets/images/cable_flyes.jpg';
    if (lower.contains('warm-up')) return 'assets/images/warm_up.jpg';
    if (lower.contains('dumbbell press'))
      return 'assets/images/dumbbell_press.jpg';
    return 'assets/images/workout.jpg';
  }

  Widget buildWorkoutChip(String title, bool isFromSuggested) {
    final duration = _getWorkoutDuration(title);
    return GestureDetector(
      onTap: () => _showWorkoutDetails(title, isFromSuggested),
      child: Container(
        margin: EdgeInsets.symmetric(vertical: 10),
        padding: EdgeInsets.symmetric(vertical: 24, horizontal: 24),
        decoration: BoxDecoration(
          color: Colors.blue.shade50,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.asset(
                _getWorkoutImage(title),
                width: 48,
                height: 48,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Icon(
                  IconlyLight.activity,
                  size: 48,
                  color: Colors.black,
                ),
              ),
            ),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      color: Colors.black,
                    ),
                  ),
                  if (isFromSuggested)
                    Text(
                      "$duration mins per session",
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        color: Colors.grey.shade600,
                      ),
                    ),
                ],
              ),
            ),
            Icon(IconlyLight.arrow_right_2, color: Colors.black, size: 24),
          ],
        ),
      ).animate().fadeIn(duration: 300.ms).slideX(begin: 0.1, end: 0),
    );
  }

  Widget buildBodyFocusSection() {
    final workoutsByBody = {
      'Abs': ['Plank', 'Crunches'],
      'Arms': ['Dumbbell Curl', 'Bicep Curls'],
      'Chest': [
        'Push-Ups',
        'Bench Press',
        'Incline Push-Ups',
        'Cable Flyes',
        'Dumbbell Press'
      ],
      'Legs': ['Squats', 'Lunges'],
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Body Focus",
          style: GoogleFonts.poppins(
            fontSize: 22,
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
        SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: workoutsByBody.keys.map((category) {
            final selected = _selectedBodyPart == category;
            return ChoiceChip(
              label: Text(
                category,
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.black,
                ),
              ),
              selected: selected,
              selectedColor: Colors.blue.shade50,
              backgroundColor: Colors.grey.shade100,
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              onSelected: (_) => setState(() => _selectedBodyPart = category),
            );
          }).toList(),
        ),
        SizedBox(height: 16),
        ...workoutsByBody[_selectedBodyPart]!
            .where((w) => w.toLowerCase().contains(_searchQuery))
            .map((w) => buildWorkoutChip(w, false))
            .toList(),
      ],
    );
  }

  Widget buildStretchSection() {
    final stretches = ['Warm-up', 'Jumping Jacks', 'Dumbbell Curl'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Stretch & Warm Up",
          style: GoogleFonts.poppins(
            fontSize: 22,
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
        SizedBox(height: 16),
        ...stretches
            .where((s) => s.toLowerCase().contains(_searchQuery))
            .map((s) => buildWorkoutChip(s, false))
            .toList(),
      ],
    );
  }

  Widget buildProgramCards() {
    final List<Map<String, dynamic>> programs = [
      {
        'title': 'Fullbody Workout',
        'desc': '${_programWorkouts['Fullbody Workout']!.length} Exercises',
        'image': 'assets/images/fullbody.jpg',
        'workouts': _programWorkouts['Fullbody Workout']!,
      },
      {
        'title': 'Lowerbody Workout',
        'desc': '${_programWorkouts['Lowerbody Workout']!.length} Exercises',
        'image': 'assets/images/lowerbody.jpg',
        'workouts': _programWorkouts['Lowerbody Workout']!,
      },
      {
        'title': 'AB Workout',
        'desc': '${_programWorkouts['AB Workout']!.length} Exercises',
        'image': 'assets/images/abworkout.jpg',
        'workouts': _programWorkouts['AB Workout']!,
      },
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "What Do You Want to Train",
          style: GoogleFonts.poppins(
            fontSize: 22,
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
        SizedBox(height: 16),
        ...programs.map((program) {
          if (!program['title'].toLowerCase().contains(_searchQuery))
            return SizedBox.shrink();
          return Container(
            width: double.infinity,
            margin: EdgeInsets.symmetric(vertical: 10),
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        program['title'],
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.black,
                        ),
                      ),
                      SizedBox(height: 6),
                      Text(
                        program['desc'],
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: Colors.black,
                        ),
                      ),
                      SizedBox(height: 10),
                      ElevatedButton(
                        onPressed: () => _showProgramModal(
                          program['title'],
                          program['workouts'],
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          padding: EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 10,
                          ),
                        ),
                        child: Text(
                          "View more",
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: Colors.blue,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.asset(
                    program['image'],
                    width: 100,
                    height: 100,
                    fit: BoxFit.contain,
                  ),
                ),
              ],
            ),
          ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.1, end: 0);
        }).toList(),
      ],
    );
  }

  Widget _buildAIFallbackAlert() {
    if (!_isAISuggestionFallback) return SizedBox.shrink();

    final hasUserData = _computeInputHash().isNotEmpty;

    return Container(
      margin: EdgeInsets.only(bottom: 24),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: hasUserData ? Colors.orange.shade50 : Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: hasUserData ? Colors.orange.shade300 : Colors.blue.shade300,
            width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(hasUserData ? Icons.warning_amber : Icons.info,
              color:
                  hasUserData ? Colors.orange.shade600 : Colors.blue.shade600,
              size: 24),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hasUserData
                      ? "AI Service Temporary Unavailable"
                      : "Complete Your Profile",
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: hasUserData
                        ? Colors.orange.shade600
                        : Colors.blue.shade600,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  hasUserData
                      ? "Using default workouts. This might be due to network issues or AI service limits. Your personalized data is ready when service resumes."
                      : "Add your height, weight, and fitness goals to get personalized workout suggestions tailored just for you!",
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: hasUserData
                        ? Colors.orange.shade500
                        : Colors.blue.shade500,
                  ),
                ),
                if (hasUserData) ...[
                  SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: refreshAISuggestions,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange.shade100,
                      foregroundColor: Colors.orange.shade800,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding:
                          EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    ),
                    child: Text(
                      "Retry Now",
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 500.ms);
  }

  Widget _buildSuggestedWorkoutSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              "Suggested Workout",
              style: GoogleFonts.poppins(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                color: Colors.black,
              ),
            ),
            SizedBox(width: 8),
            if (!_isLoadingAISuggestions)
              IconButton(
                icon:
                    Icon(Icons.refresh, size: 20, color: Colors.blue.shade300),
                onPressed: refreshAISuggestions,
                tooltip: 'Refresh suggestions',
              ),
          ],
        ),
        SizedBox(height: 16),
        if (_isLoadingAISuggestions)
          Center(
            child: Container(
              padding: EdgeInsets.all(40),
              child: Column(
                children: [
                  CircularProgressIndicator(
                    color: Colors.blue.shade300,
                  ),
                  SizedBox(height: 16),
                  Text(
                    "Loading personalized workouts...",
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
          ).animate().fadeIn(duration: 300.ms)
        else
          ..._suggestedWorkouts
              .where((w) => w.toLowerCase().contains(_searchQuery))
              .map((w) => buildWorkoutChip(w, true)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(color: Colors.blue.shade300))
          : SingleChildScrollView(
              controller: _scrollController,
              padding: EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _searchController,
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value.toLowerCase();
                      });
                    },
                    cursorColor: Colors.blue,
                    decoration: InputDecoration(
                      prefixIcon: Icon(IconlyLight.search, color: Colors.black),
                      hintText: 'Search workouts...',
                      hintStyle: GoogleFonts.poppins(
                        color: Colors.grey.shade600,
                        fontSize: 16,
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide:
                            BorderSide(color: Colors.blue.shade300, width: 2),
                      ),
                      contentPadding:
                          EdgeInsets.symmetric(vertical: 18, horizontal: 24),
                    ),
                    style:
                        GoogleFonts.poppins(fontSize: 16, color: Colors.black),
                  ).animate().fadeIn(duration: 300.ms),
                  SizedBox(height: 24),
                  Text(
                    "Workout Schedule",
                    style: GoogleFonts.poppins(
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                    ),
                  ),
                  SizedBox(height: 16),
                  // Wrap the Container in GestureDetector
                  GestureDetector(
                    behavior: HitTestBehavior
                        .translucent, // Allows taps to reach calendar
                    onPanUpdate: (details) {
                      // Only handle vertical drags (ignore horizontal swipes)
                      if (details.delta.dy.abs() > details.delta.dx.abs()) {
                        final newOffset =
                            (_scrollController.offset + details.delta.dy).clamp(
                                0.0,
                                _scrollController.position.maxScrollExtent);
                        _scrollController.jumpTo(newOffset);
                      }
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.2),
                            blurRadius: 8,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: TableCalendar(
                        focusedDay: _focusedDay,
                        firstDay: DateTime.utc(2020, 1, 1),
                        lastDay: DateTime.utc(2030, 12, 31),
                        calendarFormat: CalendarFormat.month,
                        availableCalendarFormats: const {
                          CalendarFormat.month: 'Month',
                          CalendarFormat.week: 'Week',
                        },
                        startingDayOfWeek: StartingDayOfWeek.monday,
                        selectedDayPredicate: (day) =>
                            isSameDay(_selectedDay, day),
                        onDaySelected: (selectedDay, focusedDay) {
                          setState(() {
                            _selectedDay = selectedDay;
                            _focusedDay = focusedDay;
                          });
                          final eventsForDay = _getEventsForDay(selectedDay);
                          if (eventsForDay.isNotEmpty) {
                            _showScheduledWorkoutsModal(
                                selectedDay, eventsForDay);
                          }
                        },
                        onFormatChanged: (format) {},
                        eventLoader: _getEventsForDay,
                        calendarStyle: CalendarStyle(
                          todayDecoration: BoxDecoration(
                            color: Colors.blue.shade200,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black12,
                                blurRadius: 4,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          selectedDecoration: BoxDecoration(
                            color: Colors.blue.shade300,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black12,
                                blurRadius: 4,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          defaultDecoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white,
                          ),
                          weekendDecoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white,
                          ),
                          outsideDecoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white,
                          ),
                          markerDecoration: BoxDecoration(
                            color: Colors.amber.shade600,
                            shape: BoxShape.circle,
                          ),
                          markersMaxCount: 3,
                          cellMargin: EdgeInsets.all(6),
                          defaultTextStyle: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.black87,
                          ),
                          weekendTextStyle: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.black87,
                          ),
                          outsideTextStyle: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey.shade400,
                          ),
                          todayTextStyle: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                          selectedTextStyle: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        headerStyle: HeaderStyle(
                          titleTextStyle: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                          formatButtonVisible: true,
                          formatButtonDecoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Color(0xFF9DCEFF), Color(0xFF92A3FD)],
                            ),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black12,
                                blurRadius: 4,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          formatButtonTextStyle: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                          leftChevronIcon: Icon(
                            Icons.chevron_left,
                            color: Colors.white,
                            size: 28,
                          ),
                          rightChevronIcon: Icon(
                            Icons.chevron_right,
                            color: Colors.white,
                            size: 28,
                          ),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Color(0xFF9DCEFF), Color(0xFF92A3FD)],
                            ),
                            borderRadius: BorderRadius.vertical(
                              top: Radius.circular(16),
                            ),
                          ),
                        ),
                        calendarBuilders: CalendarBuilders(
                          dowBuilder: (context, day) {
                            final text = [
                              'Mon',
                              'Tue',
                              'Wed',
                              'Thu',
                              'Fri',
                              'Sat',
                              'Sun'
                            ][day.weekday - 1];
                            return Center(
                              child: Text(
                                text,
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black54,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  )
                      .animate()
                      .fadeIn(duration: 300.ms)
                      .slideY(begin: 0.1, end: 0),
                  SizedBox(height: 24),
                  _buildAIFallbackAlert(),
                  _buildSuggestedWorkoutSection(),
                  SizedBox(height: 24),
                  buildBodyFocusSection(),
                  SizedBox(height: 24),
                  buildStretchSection(),
                  SizedBox(height: 24),
                  buildProgramCards(),
                ],
              ),
            ),
    );
  }
}

// VideoPlayerDialog class (moved to top-level)
class VideoPlayerDialog extends StatefulWidget {
  final String videoPath;
  final String workoutName;
  final bool showDuration;
  final int duration;
  const VideoPlayerDialog({
    super.key,
    required this.videoPath,
    required this.workoutName,
    required this.showDuration,
    required this.duration,
  });
  @override
  State<VideoPlayerDialog> createState() => _VideoPlayerDialogState();
}

class _VideoPlayerDialogState extends State<VideoPlayerDialog> {
  ChewieController? _chewieController;
  bool _isLoading = true;
  String? _error;
  @override
  void initState() {
    super.initState();
    _loadVideo();
  }

  Future<void> _loadVideo() async {
    List<String> pathsToTry = [widget.videoPath];
    final fallbackPath = 'assets/videos/dumbbell_press.mp4';
    if (widget.videoPath != fallbackPath) {
      pathsToTry.add(fallbackPath);
    }
    for (final path in pathsToTry) {
      VideoPlayerController? videoController;
      try {
        // Micro-delay for timing stability
        await Future.delayed(const Duration(milliseconds: 50));
        videoController = VideoPlayerController.asset(path);
        await videoController.initialize();
        _chewieController = ChewieController(
          videoPlayerController: videoController,
          autoPlay: false,
          looping: true,
          allowFullScreen: true,
          allowMuting: true,
          materialProgressColors: ChewieProgressColors(
            playedColor: Colors.blue,
            handleColor: Colors.blue.shade300,
            backgroundColor: Colors.grey,
            bufferedColor: Colors.blue.shade100,
          ),
          placeholder: Container(color: Colors.black),
          errorBuilder: (context, errorMessage) {
            return Center(
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.error_outline,
                        size: 48, color: Colors.redAccent),
                    SizedBox(height: 10),
                    Text(
                      'Video Playback Error',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        color: Colors.redAccent,
                      ),
                    ),
                    SizedBox(height: 10),
                    Text(
                      errorMessage,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: Colors.black,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          },
        );
        if (mounted) {
          setState(() {
            _isLoading = false;
            _error = null;
          });
        }
        return; // Success, exit loop
      } catch (e) {
        debugPrint('Video init failed for $path: $e');
        // Clean up partial controller
        videoController?.dispose();
        if (mounted && path == pathsToTry.last) {
          setState(() {
            _isLoading = false;
            _error =
                'Failed to load video: $e. Tried paths: ${pathsToTry.join(', ')}';
          });
        }
      }
    }
  }

  @override
  void dispose() {
    _chewieController?.pause();
    _chewieController?.videoPlayerController.dispose();
    _chewieController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(32),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: MediaQuery.of(context).size.width * 0.9,
        height: (MediaQuery.of(context).size.width * 0.9) * (9 / 16),
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: Colors.blue),
                )
              : _error != null
                  ? Center(
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.error_outline,
                                size: 48, color: Colors.redAccent),
                            const SizedBox(height: 10),
                            Text(
                              'Failed to Load Video',
                              style: GoogleFonts.poppins(
                                fontSize: 18,
                                color: Colors.redAccent,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              _error!,
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                color: Colors.black,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 20),
                            ElevatedButton(
                              onPressed: () => Navigator.of(context).pop(),
                              child: const Text('Close'),
                            ),
                          ],
                        ),
                      ),
                    )
                  : Stack(
                      fit: StackFit.expand,
                      children: [
                        Chewie(controller: _chewieController!),
                        Positioned(
                          top: 10,
                          right: 10,
                          child: IconButton(
                            icon: const Icon(Icons.close, color: Colors.white),
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                        ),
                        Positioned(
                          top: 10,
                          left: 10,
                          child: Row(
                            children: [
                              Text(
                                widget.workoutName,
                                style: GoogleFonts.poppins(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                  decoration: TextDecoration.none,
                                ),
                              ),
                              if (widget.showDuration) ...[
                                const SizedBox(width: 8),
                                Text(
                                  "${widget.duration} mins per session",
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w400,
                                    color: Colors.white70,
                                    decoration: TextDecoration.none,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
        ),
      ),
    );
  }
}

// ignore_for_file: use_build_context_synchronously, prefer_const_constructors, curly_braces_in_flow_control_structures, invalid_return_type_for_catch_error
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconly/iconly.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:google_generative_ai/google_generative_ai.dart'; // NEW: For Gemini AI

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final user = FirebaseAuth.instance.currentUser;
  bool _isLoading = true;
  Map<DateTime, List<Map<String, dynamic>>> _events = {};
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  String _selectedBodyPart = 'Abs';
  VideoPlayerController? _videoController;
  ChewieController? _chewieController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  Map<String, dynamic> _userPlan = {};
  List<String> _suggestedWorkouts = [];
  Map<String, int> _workoutDurations = {};

  // NEW/UPDATED: Debugging flags
  bool _isAISuggestionFallback = false;

  // NEW: Gemini setup
  static const _apiKey = 'AIzaSyAv-8phkpHuQbEnZshddCxYIpl4nIbgqJs';
  late final GenerativeModel _model =
      GenerativeModel(model: 'gemini-2.5-flash', apiKey: _apiKey);

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _initializeData();
  }

  @override
  void dispose() {
    _videoController?.dispose();
    _chewieController?.dispose();
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

    // Fetch user plan from workout_plans collection
    final planSnapshot = await FirebaseFirestore.instance
        .collection('workout_plans')
        .doc(uid)
        .get();

    setState(() {
      _events = tempEvents;
      _userPlan = planSnapshot.exists ? planSnapshot.data()! : {};
    });

    // Await AI suggestions
    _suggestedWorkouts = await _generateAISuggestedWorkouts();
    // NEW: Await AI durations
    _workoutDurations = await _generateWorkoutDurations();
    _isLoading = false;
    if (mounted) setState(() {}); // Refresh UI
  }

  // AI-powered - Generates personalized workout suggestions
  Future<List<String>> _generateAISuggestedWorkouts() async {
    const defaultSuggestions = [
      'Warm-up',
      'Squats',
      'Yoga',
      'Plank'
    ]; // The fallback list

    final availableWorkouts = [
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
      'Arm Raises',
      'Cable Flyes',
      'Warm-up',
      'Skipping',
      'Fullbody Workout',
      'Lowerbody Workout',
      'AB Workout',
    ].join(', ');

    // Default if no plan or offline
    if (_userPlan.isEmpty) {
      // Set flag for UI notification
      _isAISuggestionFallback = true;
      // Fallback for new user or missing plan data
      return defaultSuggestions;
    }

    // Extract user data from Firestore
    final goal = _userPlan['What is your fitness goal?']?.toString() ??
        'general fitness';
    final fitnessLevel =
        _userPlan['Select Your Fitness Level']?.toString() ?? 'Beginner';
    final activityLevel =
        _userPlan['Select your activity level']?.toString() ?? 'Sedentary';
    final weight = int.tryParse(_userPlan['Weight']?.toString() ?? '70') ?? 70;
    final height =
        int.tryParse(_userPlan['Height']?.toString() ?? '170') ?? 170;

    // Calculate BMI for context
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

    // Highly structured for Gemini to return a clean JSON array
    final prompt = '''
    Based on this user profile:
    - Goal: $goal
    - Fitness Level: $fitnessLevel
    - Activity Level: $activityLevel
    - BMI Category: $bmiCategory (Weight: $weight kg, Height: $height cm)
    
    Suggest exactly 4 personalized workout names from this list only: $availableWorkouts.
    Prioritize safe, effective ones matching the profile (e.g., low-impact cardio and foundational strength for a beginner/sedentary person).
    Return ONLY a JSON array like: ["Workout1", "Workout2", "Workout3", "Workout4"]
    ''';

    try {
      final content = await _model.generateContent([Content.text(prompt)]);
      final response = content.text ?? '';

      // FIX: Clean response (remove markdown if present) for robust JSON parsing
      final cleaned = response
          .trim()
          .replaceAll(RegExp(r'```(?:json)?'), '')
          .replaceAll('```', '')
          .trim();

      // Parse as a list
      final List<dynamic> jsonList = json.decode(cleaned);

      final List<String> suggestions = jsonList
          .map((item) => item.toString().trim())
          .where((w) => availableWorkouts.contains(w)) // Validate against pool
          .take(4)
          .toList();

      // Final check for a valid list of 4
      if (suggestions.length == 4) {
        _isAISuggestionFallback =
            false; // Successfully retrieved AI suggestions
        return suggestions;
      } else {
        // AI returned something that wasn't exactly 4, this is a soft fail
        debugPrint(
            'AI Workout Generation Soft Error: Response was not a list of 4: $response');
      }
    } catch (e) {
      debugPrint(
          'AI Workout Generation FATAL Error: $e'); // Log API/Parsing error
    }

    // Ultimate hardcoded fallback if AI fails or returns invalid JSON
    _isAISuggestionFallback = true;
    return defaultSuggestions;
  }

  // NEW: AI-powered - Generates personalized durations for workouts
  Future<Map<String, int>> _generateWorkoutDurations() async {
    final defaultDurations = _getDefaultDurations(); // Get the fallback map

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
      'Arm Raises',
      'Cable Flyes',
      'Warm-up',
      'Skipping',
      'Fullbody Workout',
      'Lowerbody Workout',
      'AB Workout',
    ];
    final availableWorkouts = availableWorkoutsList.join(', ');

    // Default if no plan or offline
    if (_userPlan.isEmpty) {
      return defaultDurations;
    }

    // Extract user data from Firestore
    final goal = _userPlan['What is your fitness goal?']?.toString() ??
        'general fitness';
    final fitnessLevel =
        _userPlan['Select Your Fitness Level']?.toString() ?? 'Beginner';
    final activityLevel =
        _userPlan['Select your activity level']?.toString() ?? 'Sedentary';
    final weight = int.tryParse(_userPlan['Weight']?.toString() ?? '70') ?? 70;
    final height =
        int.tryParse(_userPlan['Height']?.toString() ?? '170') ?? 170;

    // Calculate BMI for context
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

    // Highly structured for Gemini to return a clean JSON object
    final prompt = '''
    Based on this user profile:
    - Goal: $goal
    - Fitness Level: $fitnessLevel
    - Activity Level: $activityLevel
    - BMI Category: $bmiCategory (Weight: $weight kg, Height: $height cm)
    
    For each workout in this exact list: $availableWorkouts
    Assign a realistic session duration in minutes: only 15, 30, 45, or 60.
    Consider fitness level (shorter for beginners), goal, and workout type (e.g., 15-30 for isolations like Plank, 45-60 for full routines like Fullbody Workout).
    Include EVERY workout from the list.
    Return ONLY a JSON object like: {"Plank":15, "Crunches":30, "Push-Ups":20, ...}
    ''';

    try {
      final content = await _model.generateContent([Content.text(prompt)]);
      final response = content.text ?? '';

      // Clean response (remove markdown if present)
      final cleaned = response
          .trim()
          .replaceAll(RegExp(r'```(?:json)?'), '')
          .replaceAll('```', '')
          .trim();

      final Map<String, dynamic> jsonMap = json.decode(cleaned);

      final Map<String, int> durations = {};
      for (var entry in jsonMap.entries) {
        final workout = entry.key.toString().trim();
        final duration = int.tryParse(entry.value.toString()) ?? 15;
        if (availableWorkoutsList.contains(workout) &&
            (duration == 15 ||
                duration == 30 ||
                duration == 45 ||
                duration == 60)) {
          durations[workout] = duration;
        }
      }

      // If we got here, parsing succeeded enough to generate a map

      // Fill missing workouts with defaults
      for (var workout in availableWorkoutsList) {
        if (!durations.containsKey(workout)) {
          durations[workout] = _getDefaultDuration(workout);
        }
      }

      return durations;
    } catch (e) {
      debugPrint('AI Duration Generation Error: $e');
      return defaultDurations;
    }
  }

  // NEW: Default durations fallback
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
      'Arm Raises': 15,
      'Cable Flyes': 25,
      'Warm-up':
          10, // Note: 10 as special case, but clamped to 15 in display if needed
      'Skipping': 15,
      'Fullbody Workout': 45,
      'Lowerbody Workout': 40,
      'AB Workout': 30,
    };
  }

  int _getDefaultDuration(String workout) {
    final defaults = _getDefaultDurations();
    return defaults[workout] ?? 15;
  }

  List<Map<String, dynamic>> _getEventsForDay(DateTime day) {
    return _events[DateTime(day.year, day.month, day.day)] ?? [];
  }

  void _showWorkoutDetails(String workoutName) {
    final now = DateTime.now();
    DateTime _selectedDate = now;

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
                  _showVideoModal(context, workoutName);
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
                    firstDate: now, // Restrict to today and future dates
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
                    setModalState(() => _selectedDate = pickedDate);
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
                          "${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}",
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
                      'timestamp': Timestamp.fromDate(_selectedDate),
                      'image': image,
                      'completed': false,
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

  void _showVideoModal(BuildContext context, String workoutName) {
    String videoPath = _getWorkoutVideo(workoutName);
    print('Attempting to load video from: $videoPath');

    // NEW: Dynamic duration from AI
    final int duration = _workoutDurations[workoutName] ?? 15;

    Future<ChewieController?> _initializeVideo(String path) async {
      try {
        final videoController = VideoPlayerController.asset(path);
        await videoController.initialize();
        final chewieController = ChewieController(
          videoPlayerController: videoController,
          autoPlay: false,
          looping: true,
          allowFullScreen: true,
          allowMuting: true, // NEW: Better cross-device support
          materialProgressColors: ChewieProgressColors(
            playedColor: Colors.blue,
            handleColor: Colors.blue.shade300,
            backgroundColor: Colors.grey,
            bufferedColor: Colors.blue.shade100,
          ),
          placeholder: Container(
            color: Colors.black,
          ),
          errorBuilder: (context, errorMessage) {
            return Center(
              child: Container(
                padding: EdgeInsets.all(20),
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
                      'Video Error',
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
        return chewieController;
      } catch (e) {
        print('Failed to initialize video at $path: $e');
        return null;
      }
    }

    Future<ChewieController?> _loadVideo() async {
      var chewieController = await _initializeVideo(videoPath);
      if (chewieController != null) return chewieController;

      final fallbackVideoPath = 'assets/videos/workout.mp4';
      if (videoPath != fallbackVideoPath) {
        print('Falling back to default video: $fallbackVideoPath');
        chewieController = await _initializeVideo(fallbackVideoPath);
        if (chewieController != null) return chewieController;
      }

      return null;
    }

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: "VideoDemo",
      barrierColor: Colors.black.withOpacity(0.6),
      transitionDuration: Duration(milliseconds: 300),
      pageBuilder: (context, anim1, anim2) {
        return FutureBuilder<ChewieController?>(
          future: _loadVideo(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(
                child: CircularProgressIndicator(color: Colors.blue.shade300),
              );
            }
            if (snapshot.hasError || snapshot.data == null) {
              return Center(
                child: Container(
                  padding: EdgeInsets.all(20),
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
                        'Failed to Load Video',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          color: Colors.redAccent,
                        ),
                      ),
                      SizedBox(height: 10),
                      Text(
                        'Please check if the video file is correctly included in assets.',
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
            }

            _chewieController = snapshot.data!;
            return Center(
              child: AnimatedContainer(
                duration: Duration(milliseconds: 300),
                width: MediaQuery.of(context).size.width * 0.9,
                height: (MediaQuery.of(context).size.width * 0.9) * (9 / 16),
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 10,
                      offset: Offset(0, 5),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Chewie(controller: _chewieController!),
                      Positioned(
                        top: 10,
                        right: 10,
                        child: IconButton(
                          icon: Icon(Icons.close, color: Colors.white),
                          onPressed: () {
                            _chewieController?.pause();
                            _chewieController?.videoPlayerController.dispose();
                            _chewieController?.dispose();
                            _chewieController = null;
                            Navigator.of(context).pop();
                          },
                        ),
                      ),
                      Positioned(
                        top: 10,
                        left: 10,
                        child: Row(
                          children: [
                            Text(
                              workoutName,
                              style: GoogleFonts.poppins(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                                decoration: TextDecoration.none,
                              ),
                            ),
                            SizedBox(width: 8),
                            Text(
                              "${duration} mins per session",
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w400,
                                color: Colors.white70,
                                decoration: TextDecoration.none,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
      transitionBuilder: (context, anim1, anim2, child) {
        return FadeTransition(
          opacity: anim1,
          child: child,
        );
      },
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
    if (lower.contains('bicep') ||
        lower.contains('arm raise') ||
        lower.contains('arm raises')) return 'assets/videos/bicep_curl.mp4';
    if (lower.contains('cable')) return 'assets/videos/cable_flyes.mp4';
    if (lower.contains('warm-up') || lower.contains('skipping'))
      return 'assets/videos/warm_up.mp4';
    if (lower.contains('fullbody')) return 'assets/videos/fullbody.mp4';
    if (lower.contains('lowerbody')) return 'assets/videos/lowerbody.mp4';
    if (lower.contains('ab workout')) return 'assets/videos/abworkout.mp4';
    return 'assets/videos/workout.mp4';
  }

  Map<String, dynamic> _generateWorkoutSchedule(String workout) {
    final lower = workout.toLowerCase();
    if (lower.contains('yoga')) return {'days': 3, 'minutes': 30};
    if (lower.contains('bench')) return {'days': 2, 'minutes': 40};
    if (lower.contains('cardio') || lower.contains('jumping jack'))
      return {'days': 5, 'minutes': 25};
    return {'days': 3, 'minutes': 30};
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
    if (lower.contains('bicep') || lower.contains('arm raise'))
      return 'assets/images/bicep_curl.jpg';
    if (lower.contains('cable')) return 'assets/images/cable_flyes.jpg';
    if (lower.contains('warm-up') || lower.contains('skipping'))
      return 'assets/images/warm_up.jpg';
    if (lower.contains('fullbody')) return 'assets/images/fullbody.jpg';
    if (lower.contains('lowerbody')) return 'assets/images/lowerbody.jpg';
    if (lower.contains('ab workout')) return 'assets/images/abworkout.jpg';
    return 'assets/images/workout.jpg';
  }

  Widget buildWorkoutChip(String title) {
    return GestureDetector(
      onTap: () => _showWorkoutDetails(title),
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
              child: Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  color: Colors.black,
                ),
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
      'Arms': ['Arm Raises', 'Bicep Curls'],
      'Chest': ['Push-Ups', 'Bench Press', 'Incline Push-Ups', 'Cable Flyes'],
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
            .map(buildWorkoutChip)
            .toList(),
      ],
    );
  }

  Widget buildStretchSection() {
    final stretches = ['Warm-up', 'Jumping Jacks', 'Skipping', 'Arm Raises'];
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
            .map(buildWorkoutChip)
            .toList(),
      ],
    );
  }

  Widget buildProgramCards() {
    final programs = [
      {
        'title': 'Fullbody Workout',
        'desc': '11 Exercises | 32 mins',
        'image': 'assets/images/fullbody.jpg'
      },
      {
        'title': 'Lowerbody Workout',
        'desc': '12 Exercises | 40 mins',
        'image': 'assets/images/lowerbody.jpg'
      },
      {
        'title': 'AB Workout',
        'desc': '14 Exercises | 20 mins',
        'image': 'assets/images/abworkout.jpg'
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
          if (!program['title']!.toLowerCase().contains(_searchQuery))
            return SizedBox();
          return GestureDetector(
            onTap: () => _showWorkoutDetails(program['title']!),
            child: Container(
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
                          program['title']!,
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.black,
                          ),
                        ),
                        SizedBox(height: 6),
                        Text(
                          program['desc']!,
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: Colors.black,
                          ),
                        ),
                        SizedBox(height: 10),
                        ElevatedButton(
                          onPressed: () =>
                              _showWorkoutDetails(program['title']!),
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
                      program['image']!,
                      width: 100,
                      height: 100,
                      fit: BoxFit.contain,
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.1, end: 0),
          );
        }).toList(),
      ],
    );
  }

  // NEW: Widget to display the AI Fallback message
  Widget _buildAIFallbackAlert() {
    if (!_isAISuggestionFallback) return SizedBox.shrink();

    return Container(
      margin: EdgeInsets.only(bottom: 24),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade300, width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(IconlyBold.danger, color: Colors.red.shade600, size: 24),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Default Workouts Displayed",
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.red.shade600,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  "Failed to fetch personalized suggestions. Please check your Gemini API key in the code and your internet connection.",
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.red.shade500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 500.ms);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(color: Colors.blue.shade300))
          : SingleChildScrollView(
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
                  Container(
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
                      onDaySelected: (selected, focused) {
                        setState(() {
                          _selectedDay = selected;
                          _focusedDay = focused;
                        });
                      },
                      onFormatChanged: (format) {
                        setState(() {
                          // No state variable needed as TableCalendar manages format
                        });
                      },
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
                  )
                      .animate()
                      .fadeIn(duration: 300.ms)
                      .slideY(begin: 0.1, end: 0),
                  SizedBox(height: 24),

                  // ADDED: AI Fallback Alert
                  _buildAIFallbackAlert(),

                  // Display dynamic, AI-generated suggestions
                  Text(
                    "Suggested Workout",
                    style: GoogleFonts.poppins(
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                    ),
                  ),
                  SizedBox(height: 16),
                  ..._suggestedWorkouts
                      .where((w) => w.toLowerCase().contains(_searchQuery))
                      .map(buildWorkoutChip),
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

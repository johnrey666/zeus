// ignore_for_file: use_build_context_synchronously, prefer_const_constructors, curly_braces_in_flow_control_structures, invalid_return_type_for_catch_error
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconly/iconly.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:video_player/video_player.dart';

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
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  Map<String, dynamic> _userPlan = {};
  List<String> _suggestedWorkouts = [];

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _initializeData();
  }

  @override
  void dispose() {
    _videoController?.dispose();
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
      _suggestedWorkouts = _generateSuggestedWorkouts();
      _isLoading = false;
    });
  }

  List<String> _generateSuggestedWorkouts() {
    // Use only existing workouts with confirmed images and videos
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
    ];

    // Default workouts if no user plan exists
    if (_userPlan.isEmpty) {
      return ['Arm Raises', 'Incline Push-Ups', 'Cable Flyes', 'Plank'];
    }

    final goal = _userPlan['What is your fitness goal?']?.toString() ?? '';
    final fitnessLevel =
        _userPlan['Select Your Fitness Level']?.toString() ?? '';
    final activityLevel =
        _userPlan['Select your activity level']?.toString() ?? '';
    final weight = int.tryParse(_userPlan['Weight']?.toString() ?? '70') ?? 70;
    final height =
        int.tryParse(_userPlan['Height']?.toString() ?? '170') ?? 170;

    // Calculate BMI
    final heightInMeters = height / 100;
    final bmi = weight / (heightInMeters * heightInMeters);
    String bmiCategory;
    if (bmi < 18.5) {
      bmiCategory = 'Underweight';
    } else if (bmi < 25) {
      bmiCategory = 'Normal';
    } else if (bmi < 30) {
      bmiCategory = 'Overweight';
    } else {
      bmiCategory = 'Obese';
    }

    // Initialize workout scores
    final workoutScores = {for (var w in availableWorkouts) w: 0.0};

    // Adjust scores based on fitness goal
    if (goal == 'Build Muscle') {
      workoutScores['Push-Ups'] = workoutScores['Push-Ups']! + 2.0;
      workoutScores['Incline Push-Ups'] =
          workoutScores['Incline Push-Ups']! + 1.5;
      workoutScores['Squats'] = workoutScores['Squats']! + 2.0;
      workoutScores['Bench Press'] = workoutScores['Bench Press']! + 2.0;
      workoutScores['Bicep Curls'] = workoutScores['Bicep Curls']! + 1.5;
      workoutScores['Cable Flyes'] = workoutScores['Cable Flyes']! + 1.5;
      workoutScores['Fullbody Workout'] =
          workoutScores['Fullbody Workout']! + 2.0;
    } else if (goal == 'Lose Weight') {
      workoutScores['Jumping Jacks'] = workoutScores['Jumping Jacks']! + 2.0;
      workoutScores['Skipping'] = workoutScores['Skipping']! + 1.5;
      workoutScores['AB Workout'] = workoutScores['AB Workout']! + 1.5;
      workoutScores['Fullbody Workout'] =
          workoutScores['Fullbody Workout']! + 1.5;
    } else if (goal == 'Improve Endurance') {
      workoutScores['Yoga'] = workoutScores['Yoga']! + 2.0;
      workoutScores['Plank'] = workoutScores['Plank']! + 2.0;
      workoutScores['Jumping Jacks'] = workoutScores['Jumping Jacks']! + 1.5;
      workoutScores['Skipping'] = workoutScores['Skipping']! + 1.5;
      workoutScores['AB Workout'] = workoutScores['AB Workout']! + 1.5;
    } else if (goal == 'Increase Strength') {
      workoutScores['Bench Press'] = workoutScores['Bench Press']! + 2.0;
      workoutScores['Squats'] = workoutScores['Squats']! + 2.0;
      workoutScores['Bicep Curls'] = workoutScores['Bicep Curls']! + 1.5;
      workoutScores['Push-Ups'] = workoutScores['Push-Ups']! + 1.5;
      workoutScores['Fullbody Workout'] =
          workoutScores['Fullbody Workout']! + 2.0;
    }

    // Adjust scores based on BMI
    if (bmiCategory == 'Underweight') {
      workoutScores['Yoga'] = workoutScores['Yoga']! + 1.0;
      workoutScores['Warm-up'] = workoutScores['Warm-up']! + 1.0;
      workoutScores['Arm Raises'] = workoutScores['Arm Raises']! + 1.0;
      workoutScores['Incline Push-Ups'] =
          workoutScores['Incline Push-Ups']! + 1.0;
    } else if (bmiCategory == 'Overweight' || bmiCategory == 'Obese') {
      workoutScores['Jumping Jacks'] = workoutScores['Jumping Jacks']! + 1.5;
      workoutScores['Skipping'] = workoutScores['Skipping']! + 1.5;
      workoutScores['Plank'] = workoutScores['Plank']! + 1.0;
      workoutScores['AB Workout'] = workoutScores['AB Workout']! + 1.0;
    }

    // Adjust scores based on fitness level
    if (fitnessLevel.contains('Beginner')) {
      workoutScores['Warm-up'] = workoutScores['Warm-up']! + 1.0;
      workoutScores['Plank'] = workoutScores['Plank']! + 1.0;
      workoutScores['Arm Raises'] = workoutScores['Arm Raises']! + 1.0;
      workoutScores['Incline Push-Ups'] =
          workoutScores['Incline Push-Ups']! + 1.0;
      workoutScores['Yoga'] = workoutScores['Yoga']! + 1.0;
    } else if (fitnessLevel.contains('Intermediate')) {
      workoutScores['Push-Ups'] = workoutScores['Push-Ups']! + 1.0;
      workoutScores['Squats'] = workoutScores['Squats']! + 1.0;
      workoutScores['Lunges'] = workoutScores['Lunges']! + 1.0;
      workoutScores['Crunches'] = workoutScores['Crunches']! + 1.0;
    } else if (fitnessLevel.contains('Expert')) {
      workoutScores['Bench Press'] = workoutScores['Bench Press']! + 1.0;
      workoutScores['Cable Flyes'] = workoutScores['Cable Flyes']! + 1.0;
      workoutScores['Fullbody Workout'] =
          workoutScores['Fullbody Workout']! + 1.0;
      workoutScores['Lowerbody Workout'] =
          workoutScores['Lowerbody Workout']! + 1.0;
    }

    // Adjust scores based on activity level
    if (activityLevel.contains('Sedentary') ||
        activityLevel.contains('Lightly active')) {
      workoutScores['Warm-up'] = workoutScores['Warm-up']! + 1.0;
      workoutScores['Yoga'] = workoutScores['Yoga']! + 1.0;
      workoutScores['Plank'] = workoutScores['Plank']! + 1.0;
    } else if (activityLevel.contains('Very active') ||
        activityLevel.contains('Extra active')) {
      workoutScores['Fullbody Workout'] =
          workoutScores['Fullbody Workout']! + 1.0;
      workoutScores['Lowerbody Workout'] =
          workoutScores['Lowerbody Workout']! + 1.0;
      workoutScores['Bench Press'] = workoutScores['Bench Press']! + 1.0;
    }

    // Select top 4 workouts with highest scores
    final sortedWorkouts = workoutScores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sortedWorkouts.take(4).map((e) => e.key).toList();
  }

  List<Map<String, dynamic>> _getEventsForDay(DateTime day) {
    return _events[DateTime(day.year, day.month, day.day)] ?? [];
  }

  void _showWorkoutDetails(String workoutName) {
    final now = DateTime.now();
    DateTime _selectedDate = now;
    final TextEditingController _durationController = TextEditingController();

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
                    "Choose a date and time",
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: GestureDetector(
                      onTap: () async {
                        final pickedDate = await showDatePicker(
                          context: context,
                          initialDate: now,
                          firstDate: DateTime(now.year - 1),
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
                          final pickedTime = await showTimePicker(
                            context: context,
                            initialTime: TimeOfDay.now(),
                            builder: (context, child) {
                              return Theme(
                                data: Theme.of(context).copyWith(
                                  dialogBackgroundColor: Colors.white,
                                  colorScheme: ColorScheme.light(
                                    primary: Colors.blue.shade50,
                                    onPrimary: Colors.black,
                                    surface: Colors.white,
                                    onSurface: Colors.black,
                                  ),
                                  timePickerTheme: TimePickerThemeData(
                                    backgroundColor: Colors.white,
                                    hourMinuteTextColor: Colors.black,
                                    dialHandColor: Colors.blue.shade300,
                                    dialBackgroundColor: Colors.blue.shade50,
                                    entryModeIconColor: Colors.blue,
                                  ),
                                  textButtonTheme: TextButtonThemeData(
                                    style: ButtonStyle(
                                      foregroundColor:
                                          MaterialStateProperty.resolveWith(
                                        (states) => states
                                                .contains(MaterialState.pressed)
                                            ? Colors.red
                                            : Colors.green,
                                      ),
                                    ),
                                  ),
                                ),
                                child: child!,
                              );
                            },
                          );

                          if (pickedTime != null) {
                            final combined = DateTime(
                              pickedDate.year,
                              pickedDate.month,
                              pickedDate.day,
                              pickedTime.hour,
                              pickedTime.minute,
                            );
                            setModalState(() => _selectedDate = combined);
                          }
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
                                "${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')} "
                                "${TimeOfDay.fromDateTime(_selectedDate).format(context)}",
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
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: Container(
                      height: 52,
                      child: TextField(
                        controller: _durationController,
                        keyboardType: TextInputType.number,
                        cursorColor: Colors.blue,
                        decoration: InputDecoration(
                          hintText: "Minutes",
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                                color: Colors.blue.shade300, width: 2),
                          ),
                          contentPadding: EdgeInsets.symmetric(horizontal: 16),
                        ),
                        style: GoogleFonts.poppins(
                            fontSize: 14, color: Colors.black),
                      ),
                    ),
                  ),
                ],
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
                    final minutes = int.tryParse(_durationController.text);
                    if (minutes == null || minutes <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text("Please enter valid minutes.",
                              style: GoogleFonts.poppins()),
                          backgroundColor: Colors.redAccent,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          margin: EdgeInsets.all(16),
                        ),
                      );
                      return;
                    }

                    final image = _getWorkoutImage(workoutName);
                    final data = {
                      'workout': workoutName,
                      'minutes': minutes,
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
    final videoPath = _getWorkoutVideo(workoutName);
    print('Attempting to load video from: $videoPath');
    final controller = VideoPlayerController.asset(videoPath);

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: "VideoDemo",
      barrierColor: Colors.black.withOpacity(0.6),
      transitionDuration: Duration(milliseconds: 300),
      pageBuilder: (context, anim1, anim2) {
        return FutureBuilder(
          future: controller.initialize().then((_) {
            controller.setVolume(0.0); // Mute the video
            controller.setLooping(true); // Optional: loop the video
            return controller;
          }).catchError((error) {
            print('Video initialization error: $error');
            return null;
          }),
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
                  child: Text(
                    'Failed to load video',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      color: Colors.redAccent,
                    ),
                  ),
                ),
              );
            }

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
                      VideoPlayer(controller),
                      Positioned.fill(
                        child: Center(
                          child: IconButton(
                            icon: Icon(
                              controller.value.isPlaying
                                  ? Icons.pause
                                  : Icons.play_arrow,
                              color: Colors.white,
                              size: 50,
                            ),
                            onPressed: () {
                              if (controller.value.isPlaying) {
                                controller.pause();
                              } else {
                                controller.play();
                              }
                            },
                          ),
                        ),
                      ),
                      Positioned(
                        top: 10,
                        right: 10,
                        child: IconButton(
                          icon: Icon(Icons.close, color: Colors.white),
                          onPressed: () {
                            controller.pause();
                            controller.dispose();
                            Navigator.of(context).pop();
                          },
                        ),
                      ),
                      Positioned(
                        bottom: 10,
                        left: 10,
                        child: Text(
                          workoutName,
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                            decoration: TextDecoration.none,
                          ),
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
                  TableCalendar(
                    focusedDay: _focusedDay,
                    firstDay: DateTime.utc(2020, 1, 1),
                    lastDay: DateTime.utc(2030, 12, 31),
                    calendarFormat: CalendarFormat.week,
                    startingDayOfWeek: StartingDayOfWeek.monday,
                    selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                    onDaySelected: (selected, focused) {
                      setState(() {
                        _selectedDay = selected;
                        _focusedDay = focused;
                      });
                    },
                    eventLoader: _getEventsForDay,
                    calendarStyle: CalendarStyle(
                      todayDecoration: BoxDecoration(
                        color: Colors.blue.shade200,
                        shape: BoxShape.circle,
                      ),
                      selectedDecoration: BoxDecoration(
                        color: Colors.blue.shade100,
                        shape: BoxShape.circle,
                      ),
                      weekendTextStyle:
                          GoogleFonts.poppins(color: Colors.black),
                      defaultTextStyle:
                          GoogleFonts.poppins(color: Colors.black),
                      outsideTextStyle:
                          GoogleFonts.poppins(color: Colors.grey.shade400),
                    ),
                    headerStyle: HeaderStyle(
                      titleTextStyle: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.black,
                      ),
                      formatButtonVisible: false,
                    ),
                  )
                      .animate()
                      .fadeIn(duration: 300.ms)
                      .slideY(begin: 0.1, end: 0),
                  SizedBox(height: 24),
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

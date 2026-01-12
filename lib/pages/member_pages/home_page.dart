// ignore_for_file: use_build_context_synchronously, prefer_const_constructors, curly_braces_in_flow_control_structures, invalid_return_type_for_catch_error
import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconly/iconly.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:intl/intl.dart';
import 'package:zeus/services/workout_config_service.dart';
import 'package:zeus/services/notification_service.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => HomePageState();
}

class HomePageState extends State<HomePage> with AutomaticKeepAliveClientMixin {
  // Add this to preserve state
  @override
  bool get wantKeepAlive => true;

  final user = FirebaseAuth.instance.currentUser;
  bool _isLoading = true;
  bool _isLoadingAISuggestions = false;
  Map<DateTime, List<Map<String, dynamic>>> _events = {};
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  String _selectedBodyPart = 'Abs';
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  Map<String, dynamic> _userPlan = {};
  List<String> _suggestedWorkouts = [];
  Map<String, int> _workoutDurations = {};
  List<String> _aiWarmUp = [];
  List<String> _aiStretching = [];
  Map<String, List<String>> _aiBodyFocus = {};
  bool _isAISuggestionFallback = false;
  late ScrollController _scrollController;

  // Caching variables
  late final GenerativeModel _model;
  String? _cachedInputHash;
  bool _hasLoadedInitialAISuggestions = false;
  bool _hasLoadedInitialData = false;
  bool _isFirstLoad = true;

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
    _scrollController = ScrollController();
    _selectedDay = _focusedDay;

    // Only initialize API key on first load
    if (!_hasLoadedInitialData) {
      _initializeApiKey();
    } else {
      // If we already loaded data, just mark as not loading
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _initializeApiKey() async {
    try {
      debugPrint('Fetching API key from Firestore...');

      final doc = await FirebaseFirestore.instance
          .collection('app_config')
          .doc('api_keys')
          .get();

      if (doc.exists) {
        final apiKey = doc.data()?['gemini_api_key'] as String?;
        if (apiKey != null && apiKey.isNotEmpty) {
          debugPrint('API key successfully loaded from Firestore');
          _model = GenerativeModel(model: 'gemini-2.5-flash', apiKey: apiKey);

          await _initializeData();
          return;
        }
      }
      throw Exception('API key not found in Firestore');
    } catch (e) {
      debugPrint('Error loading API key from Firestore: $e');
      _showApiKeyError();
    }
  }

  bool _hasUserDataChanged() {
    final currentHash = _computeInputHash();
    final hasChanged =
        currentHash != _cachedInputHash && currentHash.isNotEmpty;
    if (hasChanged) {
      debugPrint(
          'User data changed! Old hash: $_cachedInputHash, New hash: $currentHash');
    }
    return hasChanged;
  }

  Future<void> reloadAISuggestions({bool forceRegenerate = false}) async {
    debugPrint('Checking if AI suggestions need reload...');

    // Check if user data has actually changed
    if (!forceRegenerate && !_hasUserDataChanged()) {
      debugPrint('User data unchanged, skipping reload');

      // If the user is manually reloading but data hasn't changed,
      // show a message that it's up to date
      if (forceRegenerate) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  'Workouts are already up to date with your current profile!'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
      return;
    }

    debugPrint('User data changed, regenerating AI suggestions...');

    if (mounted) {
      setState(() {
        _isLoadingAISuggestions = true;
      });
    }

    try {
      // First reload the user plan to get latest data
      await _loadUserPlan();

      // Generate new AI suggestions
      final aiData = await _generateAIDataCombined();

      if (mounted) {
        setState(() {
          _suggestedWorkouts = aiData['workouts'] as List<String>;
          _workoutDurations = aiData['durations'] as Map<String, int>;
          _aiWarmUp = List<String>.from(aiData['warmUp'] ?? []);
          _aiStretching = List<String>.from(aiData['stretching'] ?? []);
          _aiBodyFocus =
              Map<String, List<String>>.from(aiData['bodyFocus'] ?? {});
          _isLoadingAISuggestions = false;
          _hasLoadedInitialAISuggestions = true;
        });

        // Save to cache with hash
        final currentHash = _computeInputHash();
        _cachedInputHash = currentHash; // Update cached hash
        await _saveAISuggestionsToFirestore(
          _suggestedWorkouts,
          _workoutDurations,
          currentHash,
        );

        // Show success message
        if (mounted) {
          _showWorkoutUpdatedMessage();
        }
      }
    } catch (e) {
      debugPrint('Error reloading AI suggestions: $e');
      if (mounted) {
        setState(() {
          _isLoadingAISuggestions = false;
        });
      }
    }
  }

  void _showApiKeyError() {
    debugPrint('Failed to load API key - AI features will be disabled');
    _model = GenerativeModel(model: 'gemini-2.5-flash', apiKey: '');
    _initializeData();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _initializeData() async {
    // If already loaded, just return
    if (_hasLoadedInitialData && _hasLoadedInitialAISuggestions) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
      return;
    }

    final uid = user!.uid;

    // Load calendar events
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

    // Load user plan
    await _loadUserPlan();

    if (mounted) {
      setState(() {
        _events = tempEvents;
        _isLoading = false;
        _hasLoadedInitialData = true;
      });
    }

    // Load AI suggestions (cached by default)
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
    } catch (e) {
      debugPrint('Error loading user plan: $e');
      if (mounted) {
        setState(() {
          _userPlan = {};
        });
      }
    }
  }

  Future<bool> _loadCachedAISuggestions() async {
    final savedData = await _loadAISuggestionsFromFirestore();
    if (savedData != null &&
        savedData['hash'] == _cachedInputHash &&
        _cachedInputHash != null) {
      debugPrint('Loading cached AI suggestions');
      if (mounted) {
        setState(() {
          _suggestedWorkouts = List<String>.from(savedData['workouts']);
          _workoutDurations = Map<String, int>.from(savedData['durations']);
          _aiWarmUp = List<String>.from(savedData['warmUp'] ?? []);
          _aiStretching = List<String>.from(savedData['stretching'] ?? []);
          _aiBodyFocus =
              Map<String, List<String>>.from(savedData['bodyFocus'] ?? {});
          _isLoadingAISuggestions = false;
          _isAISuggestionFallback = false;
          _hasLoadedInitialAISuggestions = true;
        });
      }
      return true;
    }
    return false;
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
        'ai_warmUp': _aiWarmUp,
        'ai_stretching': _aiStretching,
        'ai_bodyFocus': _aiBodyFocus,
      };

      await FirebaseFirestore.instance
          .collection('workout_plans')
          .doc(user!.uid)
          .set(saveData, SetOptions(merge: true));

      debugPrint('AI suggestions saved to Firestore with hash: $inputHash');
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
      final warmUp = List<String>.from(data['ai_warmUp'] ?? []);
      final stretching = List<String>.from(data['ai_stretching'] ?? []);
      final bodyFocus =
          Map<String, List<String>>.from(data['ai_bodyFocus'] ?? {});

      return {
        'workouts': suggestions,
        'durations': durations,
        'warmUp': warmUp,
        'stretching': stretching,
        'bodyFocus': bodyFocus,
        'hash': savedHash
      };
    } catch (e) {
      debugPrint('Error loading AI suggestions from Firestore: $e');
      return null;
    }
  }

  Future<void> _loadAISuggestions({bool forceRegenerate = false}) async {
    // If we already have loaded suggestions and not forcing regenerate, just return
    if (_hasLoadedInitialAISuggestions &&
        !forceRegenerate &&
        !_hasUserDataChanged()) {
      debugPrint('Using existing AI suggestions (already loaded)');
      return;
    }

    if (mounted) {
      setState(() {
        _isLoadingAISuggestions = true;
      });
    }

    try {
      final currentHash = _computeInputHash();
      debugPrint('Current user data hash: $currentHash');

      // Update cached hash
      _cachedInputHash = currentHash;

      // If no user data, use fallback
      if (currentHash.isEmpty) {
        debugPrint('No user data available, using fallback workouts');
        if (mounted) {
          setState(() {
            _suggestedWorkouts = ['Warm-up', 'Squats', 'Yoga', 'Plank'];
            _workoutDurations = _getDefaultDurations();
            _aiWarmUp = ['Warm-up'];
            _aiStretching = ['Yoga'];
            _aiBodyFocus = {
              'Abs': ['Plank', 'Crunches'],
              'Arms': ['Bicep Curls'],
              'Chest': ['Push-Ups'],
              'Legs': ['Squats'],
            };
            _isLoadingAISuggestions = false;
            _isAISuggestionFallback = true;
            _hasLoadedInitialAISuggestions = true;
          });
        }
        return;
      }

      // Try to load cached suggestions first (if not forcing regenerate)
      if (!forceRegenerate) {
        final cachedLoaded = await _loadCachedAISuggestions();
        if (cachedLoaded) {
          return;
        }
      }

      // Only regenerate if:
      // 1. We're forcing regeneration (manual reload)
      // 2. User data has changed
      // 3. No cached data available
      debugPrint('Generating new AI suggestions...');
      final aiData = await _generateAIDataCombined();

      if (mounted) {
        setState(() {
          _suggestedWorkouts = aiData['workouts'] as List<String>;
          _workoutDurations = aiData['durations'] as Map<String, int>;
          _aiWarmUp = List<String>.from(aiData['warmUp'] ?? []);
          _aiStretching = List<String>.from(aiData['stretching'] ?? []);
          _aiBodyFocus =
              Map<String, List<String>>.from(aiData['bodyFocus'] ?? {});
          _isLoadingAISuggestions = false;
          _hasLoadedInitialAISuggestions = true;
        });

        // Save to cache with hash
        await _saveAISuggestionsToFirestore(
          _suggestedWorkouts,
          _workoutDurations,
          currentHash,
        );
      }
    } catch (e) {
      debugPrint('Error loading AI suggestions: $e');
      if (mounted) {
        setState(() {
          _suggestedWorkouts = ['Warm-up', 'Squats', 'Yoga', 'Plank'];
          _workoutDurations = _getDefaultDurations();
          _aiWarmUp = ['Warm-up'];
          _aiStretching = ['Yoga'];
          _aiBodyFocus = {
            'Abs': ['Plank', 'Crunches'],
            'Arms': ['Bicep Curls'],
            'Chest': ['Push-Ups'],
            'Legs': ['Squats'],
          };
          _isLoadingAISuggestions = false;
          _isAISuggestionFallback = true;
          _hasLoadedInitialAISuggestions = true;
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

    final weightStr = _userPlan['Weight']?.toString() ?? '';
    final heightStr = _userPlan['Height']?.toString() ?? '';

    if (weightStr.isEmpty || heightStr.isEmpty) {
      return '';
    }

    final weight = int.tryParse(weightStr) ?? 0;
    final height = int.tryParse(heightStr) ?? 0;

    if (weight <= 0 || height <= 0) {
      return '';
    }

    // Create a simple hash based on height and weight only
    // This ensures AI only regenerates when height/weight changes
    return '${goal}_${fitnessLevel}_${activityLevel}_${weight}_${height}';
  }

  // Override to prevent unnecessary rebuilds
  @override
  void didUpdateWidget(covariant HomePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Do nothing - we want to keep our state
  }

  // Override to prevent unnecessary rebuilds
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Only check for updates if we've already loaded initial data
    // and it's not the first load
    if (_hasLoadedInitialAISuggestions && _isFirstLoad) {
      _isFirstLoad = false;
    }
  }

  Future<Map<String, dynamic>> _generateAIDataCombined() async {
    final defaultData = {
      'workouts': ['Warm-up', 'Squats', 'Yoga', 'Plank'],
      'durations': _getDefaultDurations(),
      'warmUp': ['Warm-up'],
      'bodyFocus': {
        'Abs': ['Plank', 'Crunches'],
        'Arms': ['Bicep Curls'],
        'Chest': ['Push-Ups'],
        'Legs': ['Squats'],
      },
      'stretching': ['Yoga'],
      'workoutConfig': {},
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

    debugPrint('=== AI GENERATION DEBUG ===');
    debugPrint('User Plan: $_userPlan');
    debugPrint('Goal: ${_userPlan['What is your fitness goal?']}');
    debugPrint('Fitness Level: ${_userPlan['Select Your Fitness Level']}');
    debugPrint('Activity Level: ${_userPlan['Select your activity level']}');
    debugPrint('Weight: ${_userPlan['Weight']}');
    debugPrint('Height: ${_userPlan['Height']}');
    debugPrint('===========================');

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

    final user = FirebaseAuth.instance.currentUser;
    List<String> healthConditions = [];
    List<String> activityRestrictions = [];
    if (user != null) {
      try {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        if (userDoc.exists) {
          healthConditions =
              List<String>.from(userDoc.data()?['healthConditions'] ?? []);
          activityRestrictions =
              List<String>.from(userDoc.data()?['activityRestrictions'] ?? []);
        }
      } catch (e) {
        debugPrint('Error loading health conditions: $e');
      }
    }

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

      final filteredWorkouts = WorkoutConfigService.filterWorkoutsByHealth(
        availableWorkoutsList,
        healthConditions,
        activityRestrictions,
      );

      final availableWorkouts = filteredWorkouts.join(', ');
      final healthInfo = healthConditions.isNotEmpty
          ? 'Health Conditions: ${healthConditions.join(', ')}. '
          : '';
      final restrictionsInfo = activityRestrictions.isNotEmpty
          ? 'Activity Restrictions: ${activityRestrictions.join(', ')}. '
          : '';

      final fitnessLevelKey = fitnessLevel.split('\n').first;
      final workoutConfig = WorkoutConfigService.getWorkoutConfig(
        fitnessLevel: fitnessLevelKey,
        bmi: bmi,
        healthConditions: healthConditions,
        activityRestrictions: activityRestrictions,
      );

      final prompt = '''
User Profile:
- Fitness Goal: $goal
- Fitness Level: $fitnessLevelKey
- Activity Level: $activityLevel
- BMI Category: $bmiCategory (BMI: ${bmi.toStringAsFixed(1)}, Weight: $weight kg, Height: $height cm)
$healthInfo$restrictionsInfo

IMPORTANT: The body focus exercises should be adjusted based on the BMI category:
- Underweight (BMI < 18.5): Focus on strength-building exercises for all muscle groups
- Normal (BMI 18.5-24.9): Balanced workout with cardio and strength for all muscle groups
- Overweight (BMI 25-29.9): Higher cardio focus, lower-impact strength exercises, focus on full-body movements
- Obese (BMI ≥ 30): Low-impact exercises, focus on mobility and core strength, avoid high-impact exercises

Generate a COMPLETE workout regimen including:
1. Warm-up protocols (exactly 2 exercises, 30-60 seconds each)
2. Primary exercises (3-4 exercises, 2-5 minutes each)
3. Body focus routines categorized by muscle groups:
   - Abs: exercises targeting abdominal muscles (adjusted for BMI category)
   - Arms: exercises targeting arms (adjusted for BMI category)
   - Chest: exercises targeting chest (adjusted for BMI category)
   - Legs: exercises targeting legs (adjusted for BMI category)
4. Stretching sequences (exactly 2 exercises, 30-60 seconds each)

Available workouts: $availableWorkouts

Duration Guidelines:
- Warm-up/Stretching: 30-60 seconds each
- Regular Workouts: 2-5 minutes each (120-300 seconds)
- Adjust durations based on BMI category, fitness level, and health conditions

IMPORTANT: Each workout must have a duration specified. Warm-up/Stretching: 30-60s, Workouts: 120-300s.

Return ONLY valid JSON in this exact format:
{
  "warmUp": ["Warm-up", "Jumping Jacks"],
  "primaryExercises": ["Exercise1", "Exercise2", "Exercise3", "Exercise4"],
  "bodyFocus": {
    "Abs": ["Plank", "Crunches"],
    "Arms": ["Bicep Curls", "Dumbbell Curl"],
    "Chest": ["Push-Ups", "Bench Press"],
    "Legs": ["Squats", "Lunges"]
  },
  "stretching": ["Yoga", "Warm-up"],
  "suggestions": ["Primary1", "Primary2", "Primary3", "Primary4"],
  "durations": {
    "Plank": 120, "Crunches": 150, "Push-Ups": 180, "Incline Push-Ups": 180,
    "Bench Press": 240, "Yoga": 45, "Jumping Jacks": 50, "Squats": 180,
    "Lunges": 180, "Bicep Curls": 150, "Dumbbell Curl": 150, "Cable Flyes": 200,
    "Warm-up": 45, "Dumbbell Press": 200
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

      final cleaned = response
          .trim()
          .replaceAll(RegExp(r'```(?:json)?'), '')
          .replaceAll('```', '')
          .trim();

      debugPrint('Cleaned response: $cleaned');

      final Map<String, dynamic> jsonData = json.decode(cleaned);

      final List<dynamic> warmUpList = jsonData['warmUp'] ?? ['Warm-up'];
      final List<dynamic> primaryList =
          jsonData['primaryExercises'] ?? jsonData['suggestions'] ?? [];
      final Map<String, dynamic> bodyFocusMap = jsonData['bodyFocus'] ?? {};
      final List<dynamic> stretchingList = jsonData['stretching'] ?? ['Yoga'];

      debugPrint('Parsed workout regimen:');
      debugPrint('Warm-up: $warmUpList');
      debugPrint('Primary: $primaryList');
      debugPrint('Body Focus: $bodyFocusMap');
      debugPrint('Stretching: $stretchingList');

      final List<String> warmUp = warmUpList
          .map((item) => item.toString().trim())
          .where((w) => filteredWorkouts.contains(w))
          .take(2)
          .toList();

      final List<String> primary = primaryList
          .map((item) => item.toString().trim())
          .where((w) => filteredWorkouts.contains(w))
          .take(4)
          .toList();

      final Map<String, List<String>> bodyFocusByCategory = {
        'Abs': [],
        'Arms': [],
        'Chest': [],
        'Legs': [],
      };

      // ignore: unnecessary_type_check
      if (bodyFocusMap is Map) {
        for (var category in ['Abs', 'Arms', 'Chest', 'Legs']) {
          final categoryList = bodyFocusMap[category] as List<dynamic>? ?? [];
          bodyFocusByCategory[category] = categoryList
              .map((item) => item.toString().trim())
              .where((w) => filteredWorkouts.contains(w))
              .toList();
        }
      }

      final List<String> stretching = stretchingList
          .map((item) => item.toString().trim())
          .where((w) => filteredWorkouts.contains(w))
          .take(2)
          .toList();

      if (warmUp.isEmpty) warmUp.add('Warm-up');
      if (primary.isEmpty) {
        primary.addAll(['Squats', 'Push-Ups', 'Plank', 'Crunches']
            .where((w) => filteredWorkouts.contains(w))
            .take(4));
      }
      if (stretching.isEmpty) stretching.add('Yoga');

      final List<String> suggestions = primary.take(4).toList();
      if (suggestions.length < 4) {
        final defaultSuggestions = ['Warm-up', 'Squats', 'Push-Ups', 'Plank'];
        for (int i = suggestions.length; i < 4; i++) {
          if (filteredWorkouts.contains(defaultSuggestions[i])) {
            suggestions.add(defaultSuggestions[i]);
          }
        }
      }

      final Map<String, dynamic> durationsMap = jsonData['durations'] ?? {};
      final Map<String, int> durations = {};

      for (var entry in durationsMap.entries) {
        final workout = entry.key.toString().trim();
        final duration = int.tryParse(entry.value.toString()) ?? 15;
        if (filteredWorkouts.contains(workout)) {
          final bmiMultiplier =
              WorkoutConfigService.getBMIIntensityMultiplier(bmi);
          durations[workout] =
              (duration * bmiMultiplier).round().clamp(30, 300);
        }
      }

      final bmiMultiplier = WorkoutConfigService.getBMIIntensityMultiplier(bmi);
      final isWarmupOrStretch = (String workout) =>
          warmUp.contains(workout) || stretching.contains(workout);

      for (var workout in filteredWorkouts) {
        if (!durations.containsKey(workout)) {
          if (isWarmupOrStretch(workout)) {
            durations[workout] = (45 * bmiMultiplier).round().clamp(30, 60);
          } else {
            durations[workout] = (180 * bmiMultiplier).round().clamp(120, 300);
          }
        } else {
          final aiDuration = durations[workout]!;
          if (isWarmupOrStretch(workout)) {
            durations[workout] =
                (aiDuration * bmiMultiplier).round().clamp(30, 60);
          } else {
            durations[workout] =
                (aiDuration * bmiMultiplier).round().clamp(120, 300);
          }
        }
      }

      debugPrint('Final workout regimen with config: $workoutConfig');
      debugPrint('Body Focus by Category: $bodyFocusByCategory');
      debugPrint('BMI Category: $bmiCategory');
      _isAISuggestionFallback = false;
      return {
        'workouts': suggestions,
        'durations': durations,
        'warmUp': warmUp,
        'primaryExercises': primary,
        'bodyFocus': bodyFocusByCategory,
        'stretching': stretching,
        'workoutConfig': workoutConfig,
      };
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
      'Plank': 120,
      'Crunches': 150,
      'Push-Ups': 180,
      'Incline Push-Ups': 180,
      'Bench Press': 240,
      'Yoga': 45,
      'Jumping Jacks': 60,
      'Squats': 180,
      'Lunges': 180,
      'Bicep Curls': 150,
      'Dumbbell Curl': 150,
      'Cable Flyes': 200,
      'Warm-up': 45,
      'Dumbbell Press': 200,
    };
  }

  int _getDefaultDuration(String workout) {
    final defaults = _getDefaultDurations();
    return defaults[workout] ?? 180;
  }

  int _getWorkoutDurationInSeconds(String workoutName) {
    return _workoutDurations[workoutName] ?? _getDefaultDuration(workoutName);
  }

  String _getDurationDisplay(String workoutName) {
    final seconds = _getWorkoutDurationInSeconds(workoutName);
    if (seconds <= 60) {
      return '$seconds secs';
    } else {
      final minutes = (seconds / 60).ceil();
      return '$minutes mins';
    }
  }

  List<Map<String, dynamic>> _getEventsForDay(DateTime day) {
    return _events[DateTime(day.year, day.month, day.day)] ?? [];
  }

  Future<void> _markAsDoneForEvent(
      String calendarId, String workoutName, Timestamp timestamp) async {
    final uid = user!.uid;
    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('calendar')
        .doc(calendarId)
        .update({'completed': true});
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

  void _showWorkoutUpdatedMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Workout suggestions updated based on your new BMI!',
                style: GoogleFonts.poppins(),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 3),
      ),
    );
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

  Future<void> _selectDate(
      BuildContext context, Function(DateTime) onDateSelected) async {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    // Calculate safe dialog height based on screen size
    final maxDialogHeight = screenHeight * 0.7; // Use max 70% of screen height

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (BuildContext context, Widget? child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF4A90E2),
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
            dialogBackgroundColor: Colors.white,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: maxDialogHeight,
                maxWidth: screenWidth * 0.9,
              ),
              child: child!,
            ),
          ),
        );
      },
    );

    if (picked != null) {
      onDateSelected(picked);
    }
  }

  void _showWorkoutDetails(String workoutName, bool isFromSuggested) {
    final now = DateTime.now();
    DateTime selectedDate = now;
    final durationDisplay = _getDurationDisplay(workoutName);
    final durationSeconds = _getWorkoutDurationInSeconds(workoutName);
    final isWarmupOrStretch = durationSeconds <= 60;

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
                  _showVideoModal(context, workoutName, true);
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
              SizedBox(height: 4),
              Text(
                durationDisplay,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: Colors.grey.shade600,
                ),
              ),
              if (isFromSuggested) ...[
                SizedBox(height: 4),
                Text(
                  isWarmupOrStretch ? 'Warm-up/Stretching' : 'Regular Workout',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: Colors.blue.shade300,
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
              // FIXED: Use TextField with readOnly: true to prevent keyboard
              TextField(
                readOnly: true, // This prevents keyboard from showing
                controller: TextEditingController(
                  text:
                      "${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}",
                ),
                onTap: () async {
                  // Dismiss any existing focus
                  FocusScope.of(context).unfocus();
                  await Future.delayed(Duration(milliseconds: 100));

                  final pickedDate = await showDatePicker(
                    context: context,
                    initialDate: selectedDate,
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(Duration(days: 365)),
                    builder: (context, child) {
                      final screenHeight = MediaQuery.of(context).size.height;
                      final screenWidth = MediaQuery.of(context).size.width;
                      final maxDialogHeight = screenHeight * 0.7;

                      return Theme(
                        data: ThemeData.light().copyWith(
                          colorScheme: ColorScheme.light(
                            primary: Color(0xFF4A90E2),
                            onPrimary: Colors.white,
                            surface: Colors.white,
                            onSurface: Colors.black,
                          ),
                          dialogBackgroundColor: Colors.white,
                        ),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              maxHeight: maxDialogHeight,
                              maxWidth: screenWidth * 0.9,
                            ),
                            child: child!,
                          ),
                        ),
                      );
                    },
                  );

                  if (pickedDate != null && pickedDate != selectedDate) {
                    setModalState(() {
                      selectedDate = pickedDate;
                    });
                  }
                },
                decoration: InputDecoration(
                  suffixIcon: Icon(Icons.calendar_today_outlined,
                      size: 18, color: Colors.blue.shade300),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        BorderSide(color: Colors.blue.shade300, width: 1.5),
                  ),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  filled: true,
                  fillColor: Colors.white,
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

                    final fitnessLevel =
                        _userPlan['Select Your Fitness Level']?.toString() ??
                            'Beginner';
                    final fitnessLevelKey = fitnessLevel.split('\n').first;
                    final weightStr = _userPlan['Weight']?.toString() ?? '70';
                    final heightStr = _userPlan['Height']?.toString() ?? '170';
                    final weight = int.tryParse(weightStr) ?? 70;
                    final height = int.tryParse(heightStr) ?? 170;
                    final bmi = weight / ((height / 100) * (height / 100));

                    List<String> healthConditions = [];
                    List<String> activityRestrictions = [];
                    try {
                      final userDoc = await FirebaseFirestore.instance
                          .collection('users')
                          .doc(user!.uid)
                          .get();
                      if (userDoc.exists) {
                        healthConditions = List<String>.from(
                            userDoc.data()?['healthConditions'] ?? []);
                        activityRestrictions = List<String>.from(
                            userDoc.data()?['activityRestrictions'] ?? []);
                      }
                    } catch (e) {
                      debugPrint('Error loading health: $e');
                    }

                    final workoutConfig = WorkoutConfigService.getWorkoutConfig(
                      fitnessLevel: fitnessLevelKey,
                      bmi: bmi,
                      healthConditions: healthConditions,
                      activityRestrictions: activityRestrictions,
                    );

                    final durationSeconds =
                        _getWorkoutDurationInSeconds(workoutName);
                    final isWarmupOrStretch = durationSeconds <= 60;
                    final durationMinutes = (durationSeconds / 60).ceil();

                    final data = {
                      'workout': workoutName,
                      'timestamp': Timestamp.fromDate(selectedDate),
                      'image': image,
                      'completed': false,
                      'duration': durationMinutes,
                      'durationSeconds': durationSeconds,
                      'isWarmupOrStretch': isWarmupOrStretch,
                      // FIX: Warm-up/Stretching should always have 1 set, regular workouts use config
                      'sets': isWarmupOrStretch ? 1 : workoutConfig['sets'],
                      'reps': isWarmupOrStretch ? 1 : workoutConfig['reps'],
                      'restSeconds':
                          isWarmupOrStretch ? 0 : workoutConfig['restSeconds'],
                      'setsCompleted': 0,
                      'completedSets': [],
                      'restIntervalsObserved': false,
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
                    final calendarDoc = await calendarRef.add(data);
                    await trainingRef.add(data);

                    await NotificationService().scheduleWorkoutReminder(
                      id: calendarDoc.id.hashCode % 1000,
                      scheduledTime: selectedDate,
                      workoutName: workoutName,
                    );

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
                  final durationDisplay = _getDurationDisplay(workout);
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
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                workout,
                                style: GoogleFonts.poppins(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.black,
                                ),
                              ),
                              Text(
                                durationDisplay,
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
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
    final durationDisplay = _getDurationDisplay(workoutName);
    final durationSeconds = _getWorkoutDurationInSeconds(workoutName);
    final isWarmupOrStretch = durationSeconds <= 60;

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
              SizedBox(height: 4),
              Text(
                durationDisplay,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
              ),
              SizedBox(height: 4),
              Text(
                isWarmupOrStretch ? 'Warm-up/Stretching' : 'Regular Workout',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: Colors.blue.shade300,
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
              // FIXED: Use TextField with readOnly: true to prevent keyboard
              TextField(
                readOnly: true, // This prevents keyboard from showing
                controller: TextEditingController(
                  text:
                      "${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}",
                ),
                onTap: () async {
                  // Dismiss any existing focus
                  FocusScope.of(context).unfocus();
                  await Future.delayed(Duration(milliseconds: 100));

                  final pickedDate = await showDatePicker(
                    context: context,
                    initialDate: selectedDate,
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(Duration(days: 365)),
                    builder: (context, child) {
                      final screenHeight = MediaQuery.of(context).size.height;
                      final screenWidth = MediaQuery.of(context).size.width;
                      final maxDialogHeight = screenHeight * 0.7;

                      return Theme(
                        data: ThemeData.light().copyWith(
                          colorScheme: ColorScheme.light(
                            primary: Color(0xFF4A90E2),
                            onPrimary: Colors.white,
                            surface: Colors.white,
                            onSurface: Colors.black,
                          ),
                          dialogBackgroundColor: Colors.white,
                        ),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              maxHeight: maxDialogHeight,
                              maxWidth: screenWidth * 0.9,
                            ),
                            child: child!,
                          ),
                        ),
                      );
                    },
                  );

                  if (pickedDate != null && pickedDate != selectedDate) {
                    setModalState(() {
                      selectedDate = pickedDate;
                    });
                  }
                },
                decoration: InputDecoration(
                  suffixIcon: Icon(Icons.calendar_today_outlined,
                      size: 18, color: Colors.blue.shade300),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        BorderSide(color: Colors.blue.shade300, width: 1.5),
                  ),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  filled: true,
                  fillColor: Colors.white,
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

                    final fitnessLevel =
                        _userPlan['Select Your Fitness Level']?.toString() ??
                            'Beginner';
                    final fitnessLevelKey = fitnessLevel.split('\n').first;
                    final weightStr = _userPlan['Weight']?.toString() ?? '70';
                    final heightStr = _userPlan['Height']?.toString() ?? '170';
                    final weight = int.tryParse(weightStr) ?? 70;
                    final height = int.tryParse(heightStr) ?? 170;
                    final bmi = weight / ((height / 100) * (height / 100));

                    List<String> healthConditions = [];
                    List<String> activityRestrictions = [];
                    try {
                      final userDoc = await FirebaseFirestore.instance
                          .collection('users')
                          .doc(user!.uid)
                          .get();
                      if (userDoc.exists) {
                        healthConditions = List<String>.from(
                            userDoc.data()?['healthConditions'] ?? []);
                        activityRestrictions = List<String>.from(
                            userDoc.data()?['activityRestrictions'] ?? []);
                      }
                    } catch (e) {
                      debugPrint('Error loading health: $e');
                    }

                    final workoutConfig = WorkoutConfigService.getWorkoutConfig(
                      fitnessLevel: fitnessLevelKey,
                      bmi: bmi,
                      healthConditions: healthConditions,
                      activityRestrictions: activityRestrictions,
                    );

                    final durationSeconds =
                        _getWorkoutDurationInSeconds(workoutName);
                    final isWarmupOrStretch = durationSeconds <= 60;
                    final durationMinutes = (durationSeconds / 60).ceil();

                    final data = {
                      'workout': workoutName,
                      'timestamp': Timestamp.fromDate(selectedDate),
                      'image': image,
                      'completed': false,
                      'duration': durationMinutes,
                      'durationSeconds': durationSeconds,
                      'isWarmupOrStretch': isWarmupOrStretch,
                      // FIX: Warm-up/Stretching should always have 1 set, regular workouts use config
                      'sets': isWarmupOrStretch ? 1 : workoutConfig['sets'],
                      'reps': isWarmupOrStretch ? 1 : workoutConfig['reps'],
                      'restSeconds':
                          isWarmupOrStretch ? 0 : workoutConfig['restSeconds'],
                      'setsCompleted': 0,
                      'completedSets': [],
                      'restIntervalsObserved': false,
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
                    final calendarDoc = await calendarRef.add(data);
                    await trainingRef.add(data);

                    await NotificationService().scheduleWorkoutReminder(
                      id: calendarDoc.id.hashCode % 1000,
                      scheduledTime: selectedDate,
                      workoutName: workoutName,
                    );

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
    final durationDisplay = _getDurationDisplay(workoutName);
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => VideoPlayerDialog(
        videoPath: videoPath,
        workoutName: workoutName,
        showDuration: showDuration,
        duration: durationDisplay,
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
    if (lower.contains('dumbbell press'))
      return 'assets/videos/dumbbell_press.mp4';
    return 'assets/videos/dumbbell_press.mp4';
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
    final durationDisplay = _getDurationDisplay(title);
    final durationSeconds = _getWorkoutDurationInSeconds(title);
    final isWarmupOrStretch = durationSeconds <= 60;

    return GestureDetector(
      onTap: () => _showWorkoutDetails(title, isFromSuggested),
      child: Container(
        margin: EdgeInsets.symmetric(vertical: 10),
        padding: EdgeInsets.symmetric(vertical: 24, horizontal: 24),
        decoration: BoxDecoration(
          color: Colors.blue.shade50,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isWarmupOrStretch
                ? Colors.orange.shade300
                : Colors.blue.shade300,
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Stack(
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
                if (isWarmupOrStretch)
                  Positioned(
                    top: -4,
                    right: -4,
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.orange,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        'Warm-up',
                        style: GoogleFonts.poppins(
                          fontSize: 8,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
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
                  Text(
                    durationDisplay,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  if (isFromSuggested)
                    Text(
                      isWarmupOrStretch
                          ? 'Stretch & Warm-up'
                          : 'Suggested Workout',
                      style: GoogleFonts.poppins(
                        fontSize: 10,
                        fontWeight: FontWeight.w400,
                        color: isWarmupOrStretch
                            ? Colors.orange
                            : Colors.blue.shade300,
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
    final workoutsByBody = _aiBodyFocus.isNotEmpty
        ? _aiBodyFocus
        : {
            'Abs': ['Plank', 'Crunches'],
            'Arms': ['Dumbbell Curl', 'Bicep Curls'],
            'Chest': ['Push-Ups', 'Bench Press'],
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
          children: ['Abs', 'Arms', 'Chest', 'Legs'].map((category) {
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
        // Show loader for Body Focus section when AI is loading
        if (_isLoadingAISuggestions && _aiBodyFocus.isEmpty)
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
                    "Updating body focus exercises...",
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
          Column(
            children: (workoutsByBody[_selectedBodyPart] ?? [])
                .where((w) => w.toLowerCase().contains(_searchQuery))
                .map((w) => buildWorkoutChip(w, false))
                .toList(),
          ),
      ],
    );
  }

  Widget buildStretchSection() {
    final allStretches = [
      ...(_aiWarmUp.isNotEmpty ? _aiWarmUp : ['Warm-up']),
      ...(_aiStretching.isNotEmpty ? _aiStretching : ['Yoga']),
    ].toSet().toList();

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
        if (_isLoadingAISuggestions &&
            _aiWarmUp.isEmpty &&
            _aiStretching.isEmpty)
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
                    "Updating warm-up exercises...",
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
          ).animate().fadeIn(duration: 300.ms)
        else if (allStretches.isNotEmpty)
          Column(
            children: allStretches
                .where((s) => s.toLowerCase().contains(_searchQuery))
                .take(2)
                .map((s) => buildWorkoutChip(s, false))
                .toList(),
          )
        else
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'No recommended warm-up or stretching exercises.',
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.grey.shade600,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
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
        Column(
          children: programs
              .where((program) =>
                  program['title'].toLowerCase().contains(_searchQuery))
              .map((program) {
            return Container(
              width: double.infinity,
              margin: EdgeInsets.symmetric(vertical: 10),
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.blue.shade200, width: 2),
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
        ),
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
        Text(
          "Suggested Workout",
          style: GoogleFonts.poppins(
            fontSize: 22,
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
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
                    "Updating personalized workouts...",
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    "Adjusting for your new BMI...",
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.blue.shade300,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
          ).animate().fadeIn(duration: 300.ms)
        else
          Column(
            children: _suggestedWorkouts
                .where((w) => w.toLowerCase().contains(_searchQuery))
                .map((w) => buildWorkoutChip(w, true))
                .toList(),
          ),
      ],
    );
  }

  // Add this to build method to ensure state is preserved
  @override
  Widget build(BuildContext context) {
    super.build(context); // Call super.build for AutomaticKeepAliveClientMixin
    return Scaffold(
      backgroundColor: Colors.white,
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(color: Colors.blue.shade300))
          : SingleChildScrollView(
              key: PageStorageKey('homePageScroll'), // Add PageStorageKey
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
                  GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onPanUpdate: (details) {
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
                        key: PageStorageKey(
                            'homePageCalendar'), // Add key for calendar
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

// VideoPlayerDialog class (keep this exactly as it was)
class VideoPlayerDialog extends StatefulWidget {
  final String videoPath;
  final String workoutName;
  final bool showDuration;
  final String duration;
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
        return;
      } catch (e) {
        debugPrint('Video init failed for $path: $e');
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
                                  widget.duration,
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

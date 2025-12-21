import 'dart:math';

class WorkoutConfigService {
  // Fitness level tiers
  static const Map<String, Map<String, int>> fitnessLevelConfig = {
    'Beginner': {
      'sets': 2,
      'reps': 8,
      'restSeconds': 60,
    },
    'Intermediate': {
      'sets': 3,
      'reps': 12,
      'restSeconds': 90,
    },
    'Expert': {
      'sets': 4,
      'reps': 15,
      'restSeconds': 120,
    },
  };

  // BMI-based intensity multipliers
  static double getBMIIntensityMultiplier(double bmi) {
    if (bmi < 18.5) {
      return 0.8; // Underweight - reduce intensity
    } else if (bmi < 25) {
      return 1.0; // Normal - standard intensity
    } else if (bmi < 30) {
      return 0.9; // Overweight - slightly reduced
    } else {
      return 0.85; // Obese - reduced intensity
    }
  }

  // Medical condition adjustments
  static Map<String, dynamic> applyMedicalAdjustments(
    Map<String, dynamic> baseConfig,
    List<String> healthConditions,
    List<String> activityRestrictions,
  ) {
    int sets = baseConfig['sets'] as int;
    int reps = baseConfig['reps'] as int;
    int restSeconds = baseConfig['restSeconds'] as int;

    // Reduce intensity for health conditions
    if (healthConditions.contains('Heart Disease') ||
        healthConditions.contains('High Blood Pressure')) {
      sets = max(1, (sets * 0.7).round());
      reps = max(5, (reps * 0.8).round());
      restSeconds = (restSeconds * 1.5).round();
    }

    if (healthConditions.contains('Diabetes')) {
      sets = max(1, (sets * 0.85).round());
      restSeconds = (restSeconds * 1.2).round();
    }

    if (healthConditions.contains('Asthma')) {
      restSeconds = (restSeconds * 1.3).round();
    }

    if (healthConditions.contains('Joint Problems') ||
        healthConditions.contains('Back Pain')) {
      sets = max(1, (sets * 0.75).round());
      reps = max(5, (reps * 0.85).round());
    }

    // Apply activity restrictions
    if (activityRestrictions.contains('No Heavy Lifting')) {
      sets = max(1, (sets * 0.6).round());
      reps = max(5, (reps * 0.7).round());
    }

    if (activityRestrictions.contains('No High Impact')) {
      // This will be handled at workout filtering level
    }

    if (activityRestrictions.contains('Limited Range of Motion')) {
      reps = max(5, (reps * 0.9).round());
    }

    return {
      'sets': sets,
      'reps': reps,
      'restSeconds': restSeconds,
    };
  }

  // Get workout configuration based on fitness level, BMI, and health
  static Map<String, dynamic> getWorkoutConfig({
    required String fitnessLevel,
    required double bmi,
    List<String> healthConditions = const [],
    List<String> activityRestrictions = const [],
  }) {
    // Get base config from fitness level
    final baseConfig = Map<String, int>.from(
      fitnessLevelConfig[fitnessLevel] ??
          fitnessLevelConfig['Beginner']!,
    );

    // Apply BMI multiplier
    final bmiMultiplier = getBMIIntensityMultiplier(bmi);
    final adjustedConfig = {
      'sets': max(1, (baseConfig['sets']! * bmiMultiplier).round()),
      'reps': max(5, (baseConfig['reps']! * bmiMultiplier).round()),
      'restSeconds': baseConfig['restSeconds']!,
    };

    // Apply medical adjustments
    final finalConfig = applyMedicalAdjustments(
      adjustedConfig,
      healthConditions,
      activityRestrictions,
    );

    return finalConfig;
  }

  // Filter workouts based on health conditions
  static List<String> filterWorkoutsByHealth(
    List<String> workouts,
    List<String> healthConditions,
    List<String> activityRestrictions,
  ) {
    final filtered = <String>[];

    for (final workout in workouts) {
      bool shouldInclude = true;

      // Check activity restrictions
      if (activityRestrictions.contains('No Heavy Lifting')) {
        if (['Bench Press', 'Dumbbell Press', 'Cable Flyes']
            .contains(workout)) {
          shouldInclude = false;
        }
      }

      if (activityRestrictions.contains('No High Impact')) {
        if (['Jumping Jacks', 'Squats', 'Lunges'].contains(workout)) {
          // Replace with low-impact alternatives
          if (workout == 'Jumping Jacks') {
            filtered.add('Warm-up');
            shouldInclude = false;
          }
        }
      }

      if (healthConditions.contains('Back Pain')) {
        if (['Bench Press', 'Squats'].contains(workout)) {
          shouldInclude = false;
        }
      }

      if (healthConditions.contains('Joint Problems')) {
        if (['Lunges', 'Squats'].contains(workout)) {
          shouldInclude = false;
        }
      }

      if (shouldInclude) {
        filtered.add(workout);
      }
    }

    return filtered.isEmpty ? ['Warm-up', 'Plank', 'Yoga'] : filtered;
  }
}


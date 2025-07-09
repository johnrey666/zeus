import 'package:flutter/material.dart';

class TrainingPage extends StatelessWidget {
  const TrainingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Workout Plan Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [
                BoxShadow(color: Colors.black26, blurRadius: 4)
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Customize your\nWorkout Plan',
                    style: TextStyle(fontSize: 18)),
                const SizedBox(height: 4),
                const Text('Move. Sweat. Conquer!',
                    style: TextStyle(fontSize: 12)),
                const SizedBox(height: 10),
                Center(
                  child: ElevatedButton(
                    onPressed: () {},
                    style:
                        ElevatedButton.styleFrom(backgroundColor: Colors.white),
                    child: const Text('Create',
                        style: TextStyle(color: Colors.black)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Category Tabs
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Text('Beginner', style: TextStyle(fontWeight: FontWeight.bold)),
              Text('Intermediate'),
              Text('Advance'),
            ],
          ),
          const SizedBox(height: 20),

          // Workout Cards with Icons
          _buildWorkoutCard('Dumbbell Lunge', Icons.fitness_center),
          const SizedBox(height: 12),
          _buildWorkoutCard('Treadmill Running', Icons.directions_run),
          const SizedBox(height: 12),
          _buildWorkoutCard('Bench Press', Icons.sports_gymnastics),
        ],
      ),
    );
  }

  Widget _buildWorkoutCard(String title, IconData iconData) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(iconData, size: 40, color: Colors.black54),
          const SizedBox(width: 16),
          Text(title,
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

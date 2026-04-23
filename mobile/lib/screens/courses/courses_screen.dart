import 'package:flutter/material.dart';
import 'quiz_screen.dart';

// Legacy alias kept to avoid stale imports while the feature has moved to Quiz.
class CoursesScreen extends StatelessWidget {
  const CoursesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const QuizScreen();
  }
}

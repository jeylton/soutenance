import 'package:flutter/material.dart';

class Specialty {
  const Specialty({
    this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.progress,
  });

  final int? id;
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final double progress;
}

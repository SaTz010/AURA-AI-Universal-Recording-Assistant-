import 'package:flutter/material.dart';

import 'placeholder_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderScreen(title: 'Profile', icon: Icons.person_rounded);
  }
}

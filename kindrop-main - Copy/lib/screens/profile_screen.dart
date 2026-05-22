import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/user_profile.dart';
import '../theme.dart';
import '../widgets/brutal_button.dart';
import '../widgets/widgets.dart';

class ProfileScreen extends StatelessWidget {
  final UserProfile user;
  final Future<void> Function() onSignOut;

  const ProfileScreen({super.key, required this.user, required this.onSignOut});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text('Profile', style: GoogleFonts.anton(fontSize: 34, color: kDark)),
        const SizedBox(height: 20),

        Container(
          padding: const EdgeInsets.all(20),
          decoration: brutalBox(Colors.white),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const FieldLabel(text: 'Full Name'),
            Text(user.fullName,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),

            const FieldLabel(text: 'Email'),
            Text(user.email,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),

            const FieldLabel(text: 'Role'),
            Text(user.role.toUpperCase(),
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          ]),
        ),
        const SizedBox(height: 20),

        BrutalButton.dark(
          text: 'Sign Out',
          onTap: () async => onSignOut(),
        ),
      ],
    );
  }
}
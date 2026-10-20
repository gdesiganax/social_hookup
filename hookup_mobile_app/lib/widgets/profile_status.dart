import 'package:flutter/material.dart';

import '../models/profile.dart';

class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({
    super.key,
    required this.imageUrl,
    required this.isOnline,
    required this.isVerified,
    this.radius = 24,
  });

  final String imageUrl;
  final bool isOnline;
  final bool isVerified;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: radius * 2,
      height: radius * 2,
      child: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          CircleAvatar(
            radius: radius,
            backgroundImage: imageUrl.isEmpty ? null : NetworkImage(imageUrl),
            child: imageUrl.isEmpty ? Icon(Icons.person, size: radius) : null,
          ),
          if (isOnline)
            Positioned(
              right: 1,
              bottom: 1,
              child: _Dot(
                size: radius * 0.42,
                color: const Color(0xFF18B857),
                borderColor: Colors.white,
              ),
            ),
          if (isVerified)
            Positioned(
              right: -3,
              top: -3,
              child: Icon(
                Icons.verified,
                color: const Color(0xFF1DA1F2),
                size: radius * 0.58,
              ),
            ),
        ],
      ),
    );
  }
}

class ProfileStatusBadges extends StatelessWidget {
  const ProfileStatusBadges({super.key, required this.profile});

  final Profile profile;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: <Widget>[
        if (profile.isOnline)
          const _StatusChip(
            icon: Icons.circle,
            label: 'Online',
            color: Color(0xFF18B857),
          ),
        if (profile.hasSubmittedVerification)
          _StatusChip(
            icon: Icons.verified,
            label: profile.isVerified ? 'Verified' : 'Verification submitted',
            color: const Color(0xFF1DA1F2),
          ),
      ],
    );
  }
}

class RowStatusBadges extends StatelessWidget {
  const RowStatusBadges({
    super.key,
    required this.isOnline,
    required this.verificationStatus,
  });

  final bool isOnline;
  final String verificationStatus;

  @override
  Widget build(BuildContext context) {
    final hasVerification = verificationStatus.trim().isNotEmpty;
    return Wrap(
      spacing: 6,
      children: <Widget>[
        if (isOnline)
          const _MiniBadge(
            icon: Icons.circle,
            label: 'Online',
            color: Color(0xFF18B857),
          ),
        if (hasVerification)
          _MiniBadge(
            icon: Icons.verified,
            label: verificationStatus == 'verified' ? 'Verified' : 'Submitted',
            color: const Color(0xFF1DA1F2),
          ),
      ],
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({
    required this.size,
    required this.color,
    required this.borderColor,
  });

  final double size;
  final Color color;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: borderColor, width: 2),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(color: color, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _MiniBadge extends StatelessWidget {
  const _MiniBadge({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 3),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

// Automatic FlutterFlow imports
import '/backend/backend.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'index.dart'; // Imports other custom widgets
import '/custom_code/actions/index.dart'; // Imports custom actions
import 'package:flutter/material.dart';
// Begin custom widget code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

import 'dart:ui';
import 'package:url_launcher/url_launcher.dart';

class GlassSettingsPageWidget extends StatefulWidget {
  const GlassSettingsPageWidget({
    super.key,
    this.width,
    this.height,
    this.onSignOut,
    this.onDeleteAccount,
    this.onChangePassword,
    this.userName,
    this.userEmail,
  });

  final double? width;
  final double? height;

  /// Bind these in FlutterFlow to actions
  final Future Function()? onSignOut;
  final Future Function()? onDeleteAccount;
  final Future Function()? onChangePassword;

  /// Optional display fields
  final String? userName;
  final String? userEmail;

  @override
  State<GlassSettingsPageWidget> createState() =>
      _GlassSettingsPageWidgetState();
}

class _GlassSettingsPageWidgetState extends State<GlassSettingsPageWidget> {
  bool _signingOut = false;
  bool _deleting = false;
  bool _changingPassword = false;

  Future<void> _openPrivacyPolicy() async {
    final uri = Uri.parse('https://lidloop.com/privacyPolicy');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final pageWidth = widget.width ?? MediaQuery.of(context).size.width;
    final pageHeight = widget.height ?? MediaQuery.of(context).size.height;

    return Container(
      width: pageWidth,
      height: pageHeight,
      clipBehavior: Clip.antiAlias,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF0E0B1F),
            Color(0xFF16112B),
            Color(0xFF1F1740),
            Color(0xFF19253E),
            Color(0xFF111827),
          ],
        ),
      ),
      child: Stack(
        children: [
          _buildBackgroundOrbs(),
          SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTopHeader(),
                  const SizedBox(height: 18),
                  _buildProfileCard(),
                  const SizedBox(height: 18),
                  _buildSectionTitle('Account'),
                  const SizedBox(height: 10),
                  _buildActionCard(
                    icon: Icons.lock_outline_rounded,
                    title: 'Change Password',
                    subtitle: 'Secure your account with a new password',
                    accent1: const Color(0xFF8B5CF6),
                    accent2: const Color(0xFF38BDF8),
                    loading: _changingPassword,
                    onTap: () async {
                      if (_changingPassword) return;
                      setState(() => _changingPassword = true);
                      try {
                        await widget.onChangePassword?.call();
                      } finally {
                        if (mounted) {
                          setState(() => _changingPassword = false);
                        }
                      }
                    },
                  ),
                  const SizedBox(height: 22),
                  _buildSectionTitle('Session'),
                  const SizedBox(height: 10),
                  _buildActionCard(
                    icon: Icons.logout_rounded,
                    title: 'Sign Out',
                    subtitle: 'Log out of your account on this device',
                    accent1: const Color(0xFF6366F1),
                    accent2: const Color(0xFF22D3EE),
                    loading: _signingOut,
                    onTap: () async {
                      if (_signingOut) return;
                      setState(() => _signingOut = true);
                      try {
                        await widget.onSignOut?.call();
                      } finally {
                        if (mounted) {
                          setState(() => _signingOut = false);
                        }
                      }
                    },
                  ),
                  const SizedBox(height: 22),
                  _buildSectionTitle('Account Deletion'),
                  const SizedBox(height: 10),
                  _buildDangerCard(
                    loading: _deleting,
                    onTap: () async {
                      if (_deleting) return;
                      setState(() => _deleting = true);
                      try {
                        await widget.onDeleteAccount?.call();
                      } finally {
                        if (mounted) {
                          setState(() => _deleting = false);
                        }
                      }
                    },
                  ),
                  const SizedBox(height: 22),
                  _buildFootNote(),
                  const SizedBox(height: 14),
                  _buildPrivacyPolicyLink(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackgroundOrbs() {
    return Stack(
      children: [
        Positioned(
          top: -40,
          left: -30,
          child: _orb(
            size: 180,
            colors: const [
              Color(0x553B82F6),
              Color(0x227C3AED),
            ],
          ),
        ),
        Positioned(
          top: 110,
          right: -35,
          child: _orb(
            size: 200,
            colors: const [
              Color(0x557C3AED),
              Color(0x2238BDF8),
            ],
          ),
        ),
        Positioned(
          bottom: 60,
          left: -20,
          child: _orb(
            size: 160,
            colors: const [
              Color(0x444F46E5),
              Color(0x2238BDF8),
            ],
          ),
        ),
      ],
    );
  }

  Widget _orb({
    required double size,
    required List<Color> colors,
  }) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: colors),
      ),
    );
  }

  Widget _buildTopHeader() {
    return Row(
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: const LinearGradient(
              colors: [
                Color(0xFF7C3AED),
                Color(0xFF38BDF8),
              ],
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x447C3AED),
                blurRadius: 18,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: const Icon(
            Icons.settings_rounded,
            color: Colors.white,
            size: 28,
          ),
        ),
        const SizedBox(width: 14),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Settings',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.2,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Manage your account and security',
                style: TextStyle(
                  color: Color(0xFFD1D5DB),
                  fontSize: 13.5,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildProfileCard() {
    final userName =
        (widget.userName != null && widget.userName!.trim().isNotEmpty)
            ? widget.userName!.trim()
            : 'Your Account';
    final userEmail =
        (widget.userEmail != null && widget.userEmail!.trim().isNotEmpty)
            ? widget.userEmail!.trim()
            : 'your@email.com';

    final initials = _getInitials(userName);

    return _glassCard(
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          Container(
            width: 62,
            height: 62,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF8B5CF6),
                  Color(0xFF3B82F6),
                ],
              ),
              border: Border.all(
                color: Colors.white.withOpacity(0.18),
                width: 1.2,
              ),
            ),
            child: Center(
              child: Text(
                initials,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  userName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  userEmail,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFFD1D5DB),
                    fontSize: 13.5,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title,
        style: const TextStyle(
          color: Color(0xFFE5E7EB),
          fontSize: 14.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color accent1,
    required Color accent2,
    required bool loading,
    required Future<void> Function() onTap,
  }) {
    return _glassCard(
      padding: EdgeInsets.zero,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: loading ? null : onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    gradient: LinearGradient(
                      colors: [accent1, accent2],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: accent1.withOpacity(0.25),
                        blurRadius: 14,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Icon(
                    icon,
                    color: Colors.white,
                    size: 25,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16.2,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: Color(0xFFD1D5DB),
                          fontSize: 12.8,
                          fontWeight: FontWeight.w400,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                loading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2.4),
                      )
                    : Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.07),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.09),
                            width: 1,
                          ),
                        ),
                        child: const Icon(
                          Icons.arrow_forward_ios_rounded,
                          color: Colors.white70,
                          size: 16,
                        ),
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDangerCard({
    required bool loading,
    required Future<void> Function() onTap,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: const LinearGradient(
              colors: [
                Color(0x33EF4444),
                Color(0x22A855F7),
              ],
            ),
            border: Border.all(
              color: const Color(0x55EF4444),
              width: 1.1,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x22EF4444),
                blurRadius: 24,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(24),
              onTap: loading ? null : onTap,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xFFEF4444),
                            Color(0xFFF97316),
                          ],
                        ),
                      ),
                      child: const Icon(
                        Icons.delete_forever_rounded,
                        color: Colors.white,
                        size: 27,
                      ),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Delete Account',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16.2,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          SizedBox(height: 5),
                          Text(
                            'Permanently remove your account and its data',
                            style: TextStyle(
                              color: Color(0xFFF3F4F6),
                              fontSize: 12.8,
                              fontWeight: FontWeight.w400,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    loading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2.4),
                          )
                        : Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.09),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.12),
                              ),
                            ),
                            child: const Text(
                              'Delete',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFootNote() {
    return Center(
      child: Text(
        'Your account settings and security controls in one place.',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Colors.white.withOpacity(0.55),
          fontSize: 12.5,
          fontWeight: FontWeight.w400,
        ),
      ),
    );
  }

  Widget _buildPrivacyPolicyLink() {
    return Center(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: _openPrivacyPolicy,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Text(
              'Privacy Policy',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withOpacity(0.82),
                fontSize: 12.8,
                fontWeight: FontWeight.w600,
                decoration: TextDecoration.underline,
                decorationColor: Colors.white.withOpacity(0.82),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _glassCard({
    required Widget child,
    EdgeInsetsGeometry? padding,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withOpacity(0.12),
                Colors.white.withOpacity(0.05),
              ],
            ),
            border: Border.all(
              color: Colors.white.withOpacity(0.12),
              width: 1.1,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF000000).withOpacity(0.20),
                blurRadius: 28,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }

  String _getInitials(String value) {
    final parts = value
        .trim()
        .split(RegExp(r'\s+'))
        .where((e) => e.trim().isNotEmpty)
        .toList();

    if (parts.isEmpty) return 'U';
    if (parts.length == 1) {
      return parts.first.substring(0, 1).toUpperCase();
    }
    return (parts[0].substring(0, 1) + parts[1].substring(0, 1)).toUpperCase();
  }
}

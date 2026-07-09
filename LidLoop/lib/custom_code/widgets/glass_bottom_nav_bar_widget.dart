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
import 'dart:math' as math;
import 'package:flutter/services.dart';

class GlassBottomNavBarWidget extends StatefulWidget {
  const GlassBottomNavBarWidget({
    super.key,
    this.width,
    this.height,
    this.currentPage,
  });

  final double? width;
  final double? height;
  final String? currentPage;

  @override
  State<GlassBottomNavBarWidget> createState() =>
      _GlassBottomNavBarWidgetState();
}

class _GlassBottomNavBarWidgetState extends State<GlassBottomNavBarWidget>
    with SingleTickerProviderStateMixin {
  bool _expanded = true;

  late final AnimationController _controller;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;

  final List<_NavItemData> _items = const [
    _NavItemData(
        title: 'History',
        routeName: 'historyPage',
        icon: Icons.history_rounded),
    _NavItemData(
        title: 'Scanner',
        routeName: 'visualSearchPage',
        icon: Icons.camera_alt_rounded),
    _NavItemData(
        title: 'Explore',
        routeName: 'explorePage',
        icon: Icons.travel_explore_rounded),
    _NavItemData(
        title: 'Discover',
        routeName: 'discoverPage',
        icon: Icons.auto_awesome_rounded),
    _NavItemData(
        title: 'Profile', routeName: 'profilePage', icon: Icons.person_rounded),
  ];

  String get _currentPage => widget.currentPage ?? '';
  bool get _isCameraPage => _currentPage == 'visualSearchPage';

  @override
  void initState() {
    super.initState();
    _expanded = !_isCameraPage;
    _controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 380));
    _fadeAnimation =
        CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.4), end: Offset.zero).animate(
            CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _controller.value = _expanded ? 1.0 : 0.0;
  }

  @override
  void didUpdateWidget(covariant GlassBottomNavBarWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    final bool oldCam = (oldWidget.currentPage ?? '') == 'visualSearchPage';
    if (oldCam != _isCameraPage) {
      _isCameraPage
          ? _collapseNav(immediate: true)
          : _expandNav(immediate: true);
    }
  }

  void _expandNav({bool immediate = false}) {
    setState(() => _expanded = true);
    immediate ? _controller.value = 1.0 : _controller.forward();
  }

  void _collapseNav({bool immediate = false}) {
    if (immediate) {
      _controller.value = 0.0;
      setState(() => _expanded = false);
    } else {
      _controller.reverse().whenComplete(() {
        if (mounted) setState(() => _expanded = false);
      });
    }
  }

  void _toggleNav() {
    HapticFeedback.lightImpact();
    _expanded ? _collapseNav() : _expandNav();
  }

  void _navigateTo(String routeName) {
    if (_currentPage == routeName) return;
    HapticFeedback.selectionClick();
    context.goNamed(routeName);
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final bool isLandscape = media.orientation == Orientation.landscape;
    final double maxWidth = widget.width ?? media.size.width;
    final double navWidth = isLandscape
        ? (maxWidth > 700 ? 580 : maxWidth * 0.74)
        : maxWidth * 0.93;
    final double bottomInset = media.padding.bottom;
    final double bottomSpacing = isLandscape ? 10 : 14;
    final double navHeight = isLandscape ? 66 : 82;
    final double collapsedSize = isLandscape ? 50 : 56;
    final double requiredHeight = (_expanded ? navHeight : collapsedSize) +
        bottomInset +
        bottomSpacing +
        12;
    final double effectiveHeight = math.max(widget.height ?? 0, requiredHeight);

    return SizedBox(
      width: widget.width ?? double.infinity,
      height: effectiveHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          if (_expanded)
            Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: EdgeInsets.only(bottom: bottomInset + bottomSpacing),
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: _buildExpandedNav(
                        context, navWidth, isLandscape, navHeight),
                  ),
                ),
              ),
            ),
          if (_isCameraPage && !_expanded)
            Align(
              alignment: Alignment.bottomRight,
              child: Padding(
                padding: EdgeInsets.only(
                  right: isLandscape ? 18 : 16,
                  bottom: bottomInset + (isLandscape ? 10 : 14),
                ),
                child: _buildCollapsedButton(isLandscape),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildExpandedNav(BuildContext context, double navWidth,
      bool isLandscape, double navHeight) {
    final double iconSize = isLandscape ? 21 : 23;
    final double labelSize = isLandscape ? 9.5 : 10.5;
    final double radius = isLandscape ? 26 : 32;
    final bool showCollapseButton = _isCameraPage;

    return Stack(
      alignment: Alignment.bottomCenter,
      clipBehavior: Clip.none,
      children: [
        // Outer ambient glow
        Positioned(
          bottom: -6,
          child: Container(
            width: navWidth * 0.92,
            height: 24,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(40),
              gradient: RadialGradient(
                colors: [
                  const Color(0xFF8A6BFF).withOpacity(0.35),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
        ClipRRect(
          borderRadius: BorderRadius.circular(radius),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
            child: Container(
              width: navWidth,
              height: navHeight,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(radius),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xE01A0B2E),
                    Color(0xCC2A1550),
                    Color(0xC01E2D66),
                    Color(0xB0355080),
                  ],
                ),
                border: Border.all(
                    color: Colors.white.withOpacity(0.22), width: 1.2),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0A0418).withOpacity(0.55),
                    blurRadius: 30,
                    spreadRadius: 1,
                    offset: const Offset(0, 14),
                  ),
                  BoxShadow(
                    color: const Color(0xFF8A6BFF).withOpacity(0.22),
                    blurRadius: 28,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  // Top sheen (uniform highlight across whole bar)
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      height: navHeight * 0.55,
                      decoration: BoxDecoration(
                        borderRadius:
                            BorderRadius.vertical(top: Radius.circular(radius)),
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.white.withOpacity(0.22),
                            Colors.white.withOpacity(0.0),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: isLandscape ? 8 : 10,
                            vertical: isLandscape ? 6 : 8,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: _items.map((item) {
                              final bool isSelected =
                                  _currentPage == item.routeName;
                              return Expanded(
                                child: Padding(
                                  padding:
                                      const EdgeInsets.symmetric(horizontal: 2),
                                  child: _NavItem(
                                    title: item.title,
                                    icon: item.icon,
                                    selected: isSelected,
                                    iconSize: iconSize,
                                    labelSize: labelSize,
                                    onTap: () => _navigateTo(item.routeName),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                      if (showCollapseButton)
                        Padding(
                          padding: EdgeInsets.only(
                              right: isLandscape ? 8 : 10, left: 4),
                          child: GestureDetector(
                            onTap: _toggleNav,
                            child: Container(
                              width: isLandscape ? 36 : 40,
                              height: isLandscape ? 36 : 40,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Colors.white.withOpacity(0.22),
                                    Colors.white.withOpacity(0.06),
                                  ],
                                ),
                                border: Border.all(
                                    color: Colors.white.withOpacity(0.28)),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.25),
                                    blurRadius: 8,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: Icon(
                                Icons.keyboard_arrow_down_rounded,
                                color: Colors.white,
                                size: isLandscape ? 20 : 22,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCollapsedButton(bool isLandscape) {
    final double size = isLandscape ? 50 : 56;
    return GestureDetector(
      onTap: _toggleNav,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(size / 2),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xDD1D1133),
                  Color(0xC42B1A4C),
                  Color(0xB5344D7A),
                ],
              ),
              border:
                  Border.all(color: Colors.white.withOpacity(0.28), width: 1.2),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF8A6BFF).withOpacity(0.35),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
                BoxShadow(
                  color: Colors.black.withOpacity(0.5),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Icon(
              Icons.keyboard_arrow_up_rounded,
              color: Colors.white,
              size: isLandscape ? 26 : 30,
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

class _NavItemData {
  final String title;
  final String routeName;
  final IconData icon;
  const _NavItemData(
      {required this.title, required this.routeName, required this.icon});
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.title,
    required this.icon,
    required this.selected,
    required this.onTap,
    required this.iconSize,
    required this.labelSize,
  });

  final String title;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  final double iconSize;
  final double labelSize;

  @override
  Widget build(BuildContext context) {
    final Color activeColor = Colors.white;
    final Color inactiveColor = Colors.white.withOpacity(0.68);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: selected
              ? const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0x88D4BFFF),
                    Color(0x66A47CFF),
                    Color(0x445E8BCC),
                  ],
                )
              : null,
          border: selected
              ? Border.all(color: Colors.white.withOpacity(0.35), width: 1)
              : null,
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: const Color(0xFFB58CFF).withOpacity(0.45),
                    blurRadius: 18,
                    spreadRadius: 0,
                    offset: const Offset(0, 4),
                  ),
                  BoxShadow(
                    color: Colors.white.withOpacity(0.15),
                    blurRadius: 6,
                    offset: const Offset(0, -1),
                  ),
                ]
              : null,
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final bool forceIconOnly =
                constraints.maxHeight <= 28 || constraints.maxWidth <= 52;

            if (forceIconOnly) {
              return Center(
                child: Icon(icon,
                    size: iconSize,
                    color: selected ? activeColor : inactiveColor),
              );
            }

            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 280),
                    curve: Curves.easeOutCubic,
                    transform: Matrix4.identity()..scale(selected ? 1.08 : 1.0),
                    transformAlignment: Alignment.center,
                    child: Icon(
                      icon,
                      size: iconSize,
                      color: selected ? activeColor : inactiveColor,
                      shadows: selected
                          ? [
                              Shadow(
                                color: const Color(0xFFB58CFF).withOpacity(0.9),
                                blurRadius: 10,
                              ),
                            ]
                          : null,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: selected ? activeColor : inactiveColor,
                      fontSize: labelSize,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      letterSpacing: 0.2,
                      height: 1.0,
                      shadows: selected
                          ? [
                              Shadow(
                                  color:
                                      const Color(0xFFB58CFF).withOpacity(0.6),
                                  blurRadius: 8)
                            ]
                          : null,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

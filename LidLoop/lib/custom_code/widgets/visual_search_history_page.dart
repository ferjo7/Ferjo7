// Automatic FlutterFlow imports
import '/backend/backend.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'index.dart'; // Imports other custom widgets
import '/custom_code/actions/index.dart'; // Imports custom actions
import 'package:flutter/material.dart';
// Begin custom widget code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

class VisualSearchHistoryPage extends StatefulWidget {
  const VisualSearchHistoryPage({
    Key? key,
    this.width,
    this.height,
    this.maxSearches = 20,
    // NEW: default raised from 10 -> 0, where 0 means "no cap, show all".
    // Pass any positive number to cap per-search display if you need to.
    this.maxItemsPerSearch = 0,
    this.showHeader = true,
    this.showNotice = true,
    this.emptyTitle = 'No recent visual searches yet',
    this.emptySubtitle = 'Saved results will appear here for up to 6 hours.',
  }) : super(key: key);

  final double? width;
  final double? height;
  final int maxSearches;
  final int maxItemsPerSearch;
  final bool showHeader;
  final bool showNotice;
  final String emptyTitle;
  final String emptySubtitle;

  @override
  State<VisualSearchHistoryPage> createState() =>
      _VisualSearchHistoryPageState();
}

class _VisualSearchHistoryPageState extends State<VisualSearchHistoryPage> {
  static const Duration _maxAge = Duration(hours: 6);

  bool _openingLink = false;

  User? get _user => FirebaseAuth.instance.currentUser;

  Query<Map<String, dynamic>> get _query {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(_user!.uid)
        .collection('visual_searches')
        .orderBy('createdAt', descending: true)
        .limit(widget.maxSearches.clamp(1, 100));
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final width = widget.width ?? media.size.width;
    final height = widget.height ?? media.size.height;
    final orientation = media.orientation;
    final isPortrait = orientation == Orientation.portrait;

    if (_user == null) {
      return _buildShell(
        context: context,
        width: width,
        height: height,
        isPortrait: isPortrait,
        child: _buildNotLoggedIn(context),
      );
    }

    return _buildShell(
      context: context,
      width: width,
      height: height,
      isPortrait: isPortrait,
      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _query.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return _buildLoadingState(context);
          }

          if (snapshot.hasError) {
            return _buildErrorState(context, snapshot.error.toString());
          }

          final docs = snapshot.data?.docs ?? const [];
          var entries = docs
              .map((doc) => _SearchEntry.fromDoc(doc))
              .where((entry) => !entry.isExpired)
              .where((entry) => entry.items.isNotEmpty)
              .toList();

          entries = _dedupeEntries(entries);

          if (entries.isEmpty) {
            return _buildEmptyState(context, isPortrait);
          }

          return Column(
            children: [
              if (widget.showHeader) _buildHeroHeader(context),
              if (widget.showNotice) _buildExpiryNotice(context),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    isPortrait ? 14 : 18,
                    8,
                    isPortrait ? 14 : 18,
                    isPortrait ? 18 : 14,
                  ),
                  child: ListView.separated(
                    physics: const BouncingScrollPhysics(),
                    padding: EdgeInsets.zero,
                    itemCount: entries.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 14),
                    itemBuilder: (context, index) {
                      final entry = entries[index];
                      return _SearchHistorySection(
                        entry: entry,
                        compact: !isPortrait,
                        maxItemsPerSearch: widget.maxItemsPerSearch,
                        onOpenItem: _openingLink ? null : _openItem,
                      );
                    },
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  List<_SearchEntry> _dedupeEntries(List<_SearchEntry> entries) {
    final seen = <String>{};
    final output = <_SearchEntry>[];

    for (final entry in entries) {
      final fingerprint = entry.displayFingerprint;
      if (seen.add(fingerprint)) {
        output.add(entry);
      }
    }
    return output;
  }

  Widget _buildShell({
    required BuildContext context,
    required double width,
    required double height,
    required bool isPortrait,
    required Widget child,
  }) {
    final media = MediaQuery.of(context);
    final safeTop = media.padding.top;
    final safeBottom = media.padding.bottom;

    return SizedBox(
      width: width,
      height: height,
      child: ClipRect(
        child: Stack(
          fit: StackFit.expand,
          children: [
            Container(
              width: width,
              height: height,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF0B0814),
                    Color(0xFF1A1033),
                    Color(0xFF261A4D),
                    Color(0xFF23365D),
                  ],
                  stops: [0.0, 0.34, 0.68, 1.0],
                ),
              ),
            ),
            Positioned(
              top: -80,
              left: -40,
              child: _blurOrb(
                size: 210,
                color: const Color(0xAA904DFF),
              ),
            ),
            Positioned(
              right: -50,
              top: height * 0.14,
              child: _blurOrb(
                size: 180,
                color: const Color(0x8848B6FF),
              ),
            ),
            Positioned(
              bottom: -70,
              left: 40,
              child: _blurOrb(
                size: 220,
                color: const Color(0x66857BFF),
              ),
            ),
            Positioned.fill(
              child: Padding(
                padding: EdgeInsets.only(
                  top: isPortrait ? safeTop + 8 : math.max(10, safeTop * 0.45),
                  bottom: isPortrait ? safeBottom + 8 : math.max(8, safeBottom),
                ),
                child: child,
              ),
            ),
            if (_openingLink)
              Positioned.fill(
                child: IgnorePointer(
                  child: Container(
                    color: Colors.black.withOpacity(0.16),
                    alignment: Alignment.center,
                    child: _glassPanel(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 14,
                      ),
                      borderRadius: 24,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.1,
                              color: Color(0xFFD8C8FF),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Opening product...',
                            style: FlutterFlowTheme.of(context)
                                .bodyMedium
                                .override(
                                  fontFamily: FlutterFlowTheme.of(context)
                                      .bodyMediumFamily,
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  useGoogleFonts: !FlutterFlowTheme.of(context)
                                      .bodyMediumIsCustom,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 10),
      child: _glassPanel(
        borderRadius: 28,
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFFB07CFF).withOpacity(0.95),
                    const Color(0xFF5CC8FF).withOpacity(0.92),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF8B5CFF).withOpacity(0.24),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Icon(
                Icons.history_rounded,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Recent visual search results',
                    style: FlutterFlowTheme.of(context).titleLarge.override(
                          fontFamily:
                              FlutterFlowTheme.of(context).titleLargeFamily,
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          useGoogleFonts:
                              !FlutterFlowTheme.of(context).titleLargeIsCustom,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Tap any saved product to reopen it.',
                    style: FlutterFlowTheme.of(context).bodyMedium.override(
                          fontFamily:
                              FlutterFlowTheme.of(context).bodyMediumFamily,
                          color: Colors.white.withOpacity(0.74),
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                          useGoogleFonts:
                              !FlutterFlowTheme.of(context).bodyMediumIsCustom,
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpiryNotice(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
      child: _glassPanel(
        borderRadius: 22,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: const Color(0xFF6E4BFF).withOpacity(0.18),
                border: Border.all(color: Colors.white.withOpacity(0.12)),
              ),
              child: const Icon(
                Icons.schedule_rounded,
                color: Color(0xFFD8C8FF),
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Saved visual-search data is automatically cleared after 6 hours.',
                style: FlutterFlowTheme.of(context).bodyMedium.override(
                      fontFamily: FlutterFlowTheme.of(context).bodyMediumFamily,
                      color: Colors.white.withOpacity(0.84),
                      fontSize: 12.8,
                      fontWeight: FontWeight.w600,
                      useGoogleFonts:
                          !FlutterFlowTheme.of(context).bodyMediumIsCustom,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: _glassPanel(
          borderRadius: 26,
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  color: Color(0xFFD8C8FF),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Loading saved results...',
                style: FlutterFlowTheme.of(context).titleMedium.override(
                      fontFamily:
                          FlutterFlowTheme.of(context).titleMediumFamily,
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      useGoogleFonts:
                          !FlutterFlowTheme.of(context).titleMediumIsCustom,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: _glassPanel(
          borderRadius: 26,
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded,
                  color: Color(0xFFFFC0D6), size: 28),
              const SizedBox(height: 12),
              Text(
                'Could not load search history',
                textAlign: TextAlign.center,
                style: FlutterFlowTheme.of(context).titleMedium.override(
                      fontFamily:
                          FlutterFlowTheme.of(context).titleMediumFamily,
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      useGoogleFonts:
                          !FlutterFlowTheme.of(context).titleMediumIsCustom,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                error,
                textAlign: TextAlign.center,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: FlutterFlowTheme.of(context).bodySmall.override(
                      fontFamily: FlutterFlowTheme.of(context).bodySmallFamily,
                      color: Colors.white.withOpacity(0.72),
                      fontSize: 11.5,
                      useGoogleFonts:
                          !FlutterFlowTheme.of(context).bodySmallIsCustom,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, bool isPortrait) {
    return SizedBox.expand(
      child: Center(
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: isPortrait ? 18 : 28,
            vertical: 18,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: isPortrait ? 640 : 720,
            ),
            child: _glassPanel(
              borderRadius: 28,
              padding: EdgeInsets.fromLTRB(
                isPortrait ? 20 : 28,
                isPortrait ? 24 : 26,
                isPortrait ? 20 : 28,
                isPortrait ? 24 : 26,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: isPortrait ? 62 : 68,
                    height: isPortrait ? 62 : 68,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF8754FF).withOpacity(0.95),
                          const Color(0xFF59BDFF).withOpacity(0.85),
                        ],
                      ),
                    ),
                    child: const Icon(Icons.search_rounded,
                        color: Colors.white, size: 28),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    widget.emptyTitle,
                    textAlign: TextAlign.center,
                    style: FlutterFlowTheme.of(context).titleMedium.override(
                          fontFamily:
                              FlutterFlowTheme.of(context).titleMediumFamily,
                          color: Colors.white,
                          fontSize: isPortrait ? 18 : 20,
                          fontWeight: FontWeight.w800,
                          useGoogleFonts:
                              !FlutterFlowTheme.of(context).titleMediumIsCustom,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.emptySubtitle,
                    textAlign: TextAlign.center,
                    style: FlutterFlowTheme.of(context).bodyMedium.override(
                          fontFamily:
                              FlutterFlowTheme.of(context).bodyMediumFamily,
                          color: Colors.white.withOpacity(0.74),
                          fontSize: isPortrait ? 12.6 : 13.5,
                          fontWeight: FontWeight.w500,
                          useGoogleFonts:
                              !FlutterFlowTheme.of(context).bodyMediumIsCustom,
                        ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNotLoggedIn(BuildContext context) {
    return SizedBox.expand(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: _glassPanel(
            borderRadius: 28,
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock_outline_rounded,
                    color: Colors.white, size: 28),
                const SizedBox(height: 12),
                Text(
                  'User must be logged in',
                  textAlign: TextAlign.center,
                  style: FlutterFlowTheme.of(context).titleMedium.override(
                        fontFamily:
                            FlutterFlowTheme.of(context).titleMediumFamily,
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        useGoogleFonts:
                            !FlutterFlowTheme.of(context).titleMediumIsCustom,
                      ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Calls the server-side resolveAffiliateLink callable on-tap.
  Future<Map<String, dynamic>> _resolveAffiliateLink({
    required String url,
    required bool amazonOnly,
    String store = '',
    String title = '',
  }) async {
    try {
      final callable = FirebaseFunctions.instanceFor(region: 'us-central1')
          .httpsCallable('resolveAffiliateLink');

      final response = await callable.call({
        'url': url,
        'amazonOnly': amazonOnly,
        'store': store,
        'title': title,
      });

      final data = response.data;
      if (data is Map<String, dynamic>) return data;
      if (data is Map) return Map<String, dynamic>.from(data);
    } catch (_) {}
    return <String, dynamic>{};
  }

  bool _isSovrnUrl(String value) {
    final lower = value.trim().toLowerCase();
    return lower.contains('redirect.viglink.com') ||
        lower.contains('redirect.skimresources.com') ||
        lower.contains('sovrn.co');
  }

  Future<void> _launchExternalThenFallback(String url) async {
    final uri = Uri.tryParse(url.trim());
    if (uri == null) return;

    try {
      final opened = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (opened) return;
    } catch (_) {}

    try {
      await launchUrl(uri, mode: LaunchMode.platformDefault);
    } catch (_) {}
  }

  Future<void> _openItem(_VisualSearchItem item) async {
    if (_openingLink) return;

    final String hintUrl = item.originalUrl.trim().isNotEmpty
        ? item.originalUrl.trim()
        : item.affiliateUrl.trim();

    setState(() {
      _openingLink = true;
    });

    try {
      final resolved = await _resolveAffiliateLink(
        url: hintUrl,
        amazonOnly: item.isAmazon,
        store: item.store,
        title: item.title,
      );

      String launchTarget = (resolved['affiliateUrl'] ?? '').toString().trim();

      if (!_isSovrnUrl(launchTarget)) {
        if (_isSovrnUrl(item.affiliateUrl.trim())) {
          launchTarget = item.affiliateUrl.trim();
        } else {
          launchTarget = '';
        }
      }

      if (launchTarget.isEmpty) return;

      await _launchExternalThenFallback(launchTarget);
    } finally {
      if (mounted) {
        setState(() {
          _openingLink = false;
        });
      }
    }
  }

  Widget _blurOrb({required double size, required Color color}) {
    return IgnorePointer(
      child: ImageFiltered(
        imageFilter: ImageFilter.blur(sigmaX: 34, sigmaY: 34),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
          ),
        ),
      ),
    );
  }

  Widget _glassPanel({
    required Widget child,
    EdgeInsetsGeometry? padding,
    double borderRadius = 24,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(borderRadius),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withOpacity(0.16),
                Colors.white.withOpacity(0.07),
              ],
            ),
            border: Border.all(
              color: Colors.white.withOpacity(0.12),
              width: 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.18),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

class _SearchHistorySection extends StatelessWidget {
  const _SearchHistorySection({
    required this.entry,
    required this.compact,
    required this.maxItemsPerSearch,
    required this.onOpenItem,
  });

  final _SearchEntry entry;
  final bool compact;
  final int maxItemsPerSearch;
  final Future<void> Function(_VisualSearchItem item)? onOpenItem;

  @override
  Widget build(BuildContext context) {
    // maxItemsPerSearch == 0 means "show all items".
    final items = maxItemsPerSearch <= 0
        ? entry.items
        : entry.items.take(maxItemsPerSearch.clamp(1, 500)).toList();
    final crossAxisCount = compact ? 2 : 1;
    final ratio = compact ? 1.76 : 2.42;

    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withOpacity(0.15),
                Colors.white.withOpacity(0.06),
              ],
            ),
            border: Border.all(color: Colors.white.withOpacity(0.11)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      entry.bestGuess.isEmpty
                          ? 'Visual search result'
                          : entry.bestGuess,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: FlutterFlowTheme.of(context).titleMedium.override(
                            fontFamily:
                                FlutterFlowTheme.of(context).titleMediumFamily,
                            color: Colors.white,
                            fontSize: compact ? 17 : 18,
                            fontWeight: FontWeight.w800,
                            useGoogleFonts: !FlutterFlowTheme.of(context)
                                .titleMediumIsCustom,
                          ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  _countBadge(context, '${items.length}'),
                  const SizedBox(width: 6),
                  _timeBadge(
                    context,
                    compact ? entry.relativeTime : entry.createdAtLabel,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: items.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: ratio,
                ),
                itemBuilder: (context, index) {
                  final item = items[index];
                  return _HistoryProductCard(
                    item: item,
                    compact: compact,
                    onTap: onOpenItem == null ? null : () => onOpenItem!(item),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _timeBadge(BuildContext context, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: const Color(0xFF8A63FF).withOpacity(0.18),
        border: Border.all(color: Colors.white.withOpacity(0.10)),
      ),
      child: Text(
        text,
        style: FlutterFlowTheme.of(context).bodySmall.override(
              fontFamily: FlutterFlowTheme.of(context).bodySmallFamily,
              color: Colors.white.withOpacity(0.88),
              fontSize: 11,
              fontWeight: FontWeight.w700,
              useGoogleFonts: !FlutterFlowTheme.of(context).bodySmallIsCustom,
            ),
      ),
    );
  }

  Widget _countBadge(BuildContext context, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: const Color(0xFF5CC8FF).withOpacity(0.18),
        border: Border.all(color: Colors.white.withOpacity(0.10)),
      ),
      child: Text(
        text,
        style: FlutterFlowTheme.of(context).bodySmall.override(
              fontFamily: FlutterFlowTheme.of(context).bodySmallFamily,
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              useGoogleFonts: !FlutterFlowTheme.of(context).bodySmallIsCustom,
            ),
      ),
    );
  }
}

class _HistoryProductCard extends StatefulWidget {
  const _HistoryProductCard({
    required this.item,
    required this.compact,
    required this.onTap,
  });

  final _VisualSearchItem item;
  final bool compact;
  final VoidCallback? onTap;

  @override
  State<_HistoryProductCard> createState() => _HistoryProductCardState();
}

class _HistoryProductCardState extends State<_HistoryProductCard> {
  int _imageIndex = 0;

  @override
  void didUpdateWidget(covariant _HistoryProductCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item != widget.item) {
      _imageIndex = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final image = widget.item.imageCandidates.isNotEmpty
        ? widget.item.imageCandidates[
            _imageIndex.clamp(0, widget.item.imageCandidates.length - 1)]
        : '';

    final imageSize = widget.compact ? 74.0 : 86.0;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: widget.onTap,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withOpacity(0.14),
                Colors.white.withOpacity(0.05),
              ],
            ),
            border: Border.all(color: Colors.white.withOpacity(0.10)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                Container(
                  width: imageSize,
                  height: imageSize,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    color: Colors.white.withOpacity(0.92),
                  ),
                  padding: const EdgeInsets.all(8),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: _buildImage(image),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        widget.item.title.isEmpty
                            ? 'Product'
                            : widget.item.title,
                        maxLines: widget.compact ? 2 : 3,
                        overflow: TextOverflow.ellipsis,
                        style: FlutterFlowTheme.of(context).bodyMedium.override(
                              fontFamily:
                                  FlutterFlowTheme.of(context).bodyMediumFamily,
                              color: Colors.white,
                              fontSize: widget.compact ? 12.4 : 13.2,
                              fontWeight: FontWeight.w800,
                              useGoogleFonts: !FlutterFlowTheme.of(context)
                                  .bodyMediumIsCustom,
                            ),
                      ),
                      const SizedBox(height: 7),
                      Text(
                        widget.item.store.isEmpty
                            ? 'Product page'
                            : widget.item.store,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: FlutterFlowTheme.of(context).bodySmall.override(
                              fontFamily:
                                  FlutterFlowTheme.of(context).bodySmallFamily,
                              color: Colors.white.withOpacity(0.70),
                              fontSize: 10.8,
                              fontWeight: FontWeight.w600,
                              useGoogleFonts: !FlutterFlowTheme.of(context)
                                  .bodySmallIsCustom,
                            ),
                      ),
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          if (widget.item.price.isNotEmpty)
                            Text(
                              widget.item.price,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: FlutterFlowTheme.of(context)
                                  .bodySmall
                                  .override(
                                    fontFamily: FlutterFlowTheme.of(context)
                                        .bodySmallFamily,
                                    color: const Color(0xFFFFD88A),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    useGoogleFonts:
                                        !FlutterFlowTheme.of(context)
                                            .bodySmallIsCustom,
                                  ),
                            ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 7),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(999),
                              gradient: LinearGradient(
                                colors: [
                                  const Color(0xFF8E63FF).withOpacity(0.95),
                                  const Color(0xFF52BFFF).withOpacity(0.95),
                                ],
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.open_in_new_rounded,
                                    color: Colors.white, size: 12),
                                const SizedBox(width: 5),
                                Text(
                                  'Open',
                                  style: FlutterFlowTheme.of(context)
                                      .bodySmall
                                      .override(
                                        fontFamily: FlutterFlowTheme.of(context)
                                            .bodySmallFamily,
                                        color: Colors.white,
                                        fontSize: 10.8,
                                        fontWeight: FontWeight.w800,
                                        useGoogleFonts:
                                            !FlutterFlowTheme.of(context)
                                                .bodySmallIsCustom,
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildImage(String image) {
    if (image.isEmpty) {
      return _fallbackImage();
    }

    if (image.startsWith('data:image/')) {
      final bytes = _decodeDataImage(image);
      if (bytes != null) {
        return Image.memory(
          bytes,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => _fallbackImage(),
        );
      }
      return _fallbackImage();
    }

    return Image.network(
      image,
      fit: BoxFit.contain,
      gaplessPlayback: true,
      errorBuilder: (_, __, ___) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          if (_imageIndex + 1 < widget.item.imageCandidates.length) {
            setState(() {
              _imageIndex += 1;
            });
          }
        });
        return _fallbackImage();
      },
    );
  }

  Widget _fallbackImage() {
    return Container(
      color: const Color(0xFFF0F1F6),
      alignment: Alignment.center,
      child: const Icon(
        Icons.image_outlined,
        color: Color(0xFF8A8FA7),
        size: 24,
      ),
    );
  }

  Uint8List? _decodeDataImage(String value) {
    final text = value.trim();
    if (!text.startsWith('data:image/')) return null;

    final commaIndex = text.indexOf(',');
    if (commaIndex <= 0 || commaIndex >= text.length - 1) return null;

    final meta = text.substring(0, commaIndex).toLowerCase();
    if (!meta.contains(';base64')) return null;

    final payload = text.substring(commaIndex + 1).trim();
    if (payload.isEmpty) return null;

    try {
      return base64Decode(payload);
    } catch (_) {
      return null;
    }
  }
}

// Accepts BOTH product-detail URLs and allowlisted merchant search URLs,
// matching the backend's isAcceptableSovrnDestination(). This is what
// lets search-URL-fallback items open correctly from history.
bool _looksLikeAcceptableSovrnAffiliate(String value) {
  final text = value.trim();
  if (text.isEmpty) return false;

  final lower = text.toLowerCase();
  final isSovrn = lower.contains('redirect.viglink.com') ||
      lower.contains('redirect.skimresources.com') ||
      lower.contains('sovrn.co');
  if (!isSovrn) return false;

  final uri = Uri.tryParse(text);
  if (uri == null) return false;

  final wrapped = (uri.queryParameters['u'] ?? '').trim();
  if (wrapped.isEmpty) return false;

  final wrappedUri = Uri.tryParse(wrapped);
  final wrappedHost = (wrappedUri?.host ?? '').toLowerCase();
  if (wrappedHost.isEmpty) return false;
  if (wrappedHost == 'google.com' ||
      wrappedHost == 'www.google.com' ||
      wrappedHost.endsWith('.google.com')) {
    return false;
  }

  if (!(wrapped.startsWith('http://') || wrapped.startsWith('https://'))) {
    return false;
  }

  return _sharedIsLikelyProductDetailUrl(wrapped) ||
      _sharedIsAllowlistedMerchantSearchUrl(wrapped);
}

bool _sharedIsLikelyProductDetailUrl(String value) {
  final cleaned = value.trim();
  if (cleaned.isEmpty) return false;

  final uri = Uri.tryParse(cleaned);
  if (uri == null) return false;

  final host = uri.host.toLowerCase();
  if (host.isEmpty) return false;
  if (host == 'google.com' ||
      host == 'www.google.com' ||
      host.endsWith('.google.com')) {
    return false;
  }

  final path = uri.path.toLowerCase();
  final segments = uri.pathSegments.where((e) => e.trim().isNotEmpty).toList();
  if (segments.isEmpty) return false;

  final pathLooksLikeDetail =
      RegExp(r'/(product|products|prod|itm)/', caseSensitive: false)
              .hasMatch(path) ||
          RegExp(r'/(p-|sku-|pid-|prod-)[a-z0-9-]+', caseSensitive: false)
              .hasMatch(path) ||
          RegExp(r'/(?:[a-z0-9-]+-){2,}[a-z0-9-]+(?:\.html?)?$',
                  caseSensitive: false)
              .hasMatch(path) ||
          RegExp(r'[-_][a-z0-9]{6,}(?:\.html?)?$', caseSensitive: false)
              .hasMatch(path) ||
          RegExp(r'/\d{3,}\.(p|html?)(?:[/?]|$)', caseSensitive: false)
              .hasMatch(path) ||
          (segments.length >= 2 && segments.last.length >= 18);

  const searchParamKeys = [
    'q',
    'query',
    'keyword',
    'keywords',
    'search',
    'searchTerm',
    'st',
    'Ntt',
    'page',
    'pageNumber',
    'pageSize',
    'sort',
    'sortOption',
    'ibp',
    'prds',
    'pvorigin',
    'udm'
  ];
  bool hasSearchParam = false;
  for (final key in searchParamKeys) {
    if ((uri.queryParameters[key] ?? '').trim().isNotEmpty) {
      hasSearchParam = true;
      break;
    }
  }
  if (!pathLooksLikeDetail && hasSearchParam) return false;

  const listingHints = [
    '/search',
    '/shop/search',
    '/searchpage.jsp',
    '/sch/',
    '/keyword.php',
    '/s/',
    '/w/',
    '/sr'
  ];
  for (final hint in listingHints) {
    if (path == hint || path.startsWith(hint)) return false;
  }

  if (host.contains('amazon.')) {
    return RegExp(r'/dp/[A-Za-z0-9]{10}(?:[/?-]|$)', caseSensitive: false)
            .hasMatch(path) ||
        RegExp(r'/gp/product/[A-Za-z0-9]{10}(?:[/?-]|$)', caseSensitive: false)
            .hasMatch(path);
  }

  if (RegExp(r'/(product|products|prod|itm)/', caseSensitive: false)
      .hasMatch(path)) return true;
  if (RegExp(r'/(p-|sku-|pid-|prod-)[A-Za-z0-9-]+', caseSensitive: false)
      .hasMatch(path)) return true;
  if (RegExp(r'/\d{3,}\.(p|html?)(?:[/?]|$)', caseSensitive: false)
      .hasMatch(path)) return true;

  final last = segments.isNotEmpty ? segments.last : '';
  final slugLooksDetailed =
      RegExp(r'^[a-z0-9-]{18,}(?:\.html?)?$', caseSensitive: false)
              .hasMatch(last) ||
          RegExp(r'^(?:[a-z0-9-]+-){2,}[a-z0-9-]+(?:\.html?)?$',
                  caseSensitive: false)
              .hasMatch(last);
  if (slugLooksDetailed) return true;

  return segments.length >= 2 &&
      last.length >= 18 &&
      !segments.contains('search') &&
      !segments.contains('shop') &&
      !segments.contains('category') &&
      !segments.contains('collections');
}

const Set<String> _sharedMerchantSearchHostAllowlist = {
  'walmart.com',
  'target.com',
  'bestbuy.com',
  'macys.com',
  'kohls.com',
  'nordstrom.com',
  'dickssportinggoods.com',
  'wayfair.com',
  'overstock.com',
  'bedbathandbeyond.com',
  'homedepot.com',
  'lowes.com',
  'nike.com',
  'adidas.com',
  'newbalance.com',
  'puma.com',
  'us.puma.com',
  'reebok.com',
  'underarmour.com',
  'asics.com',
  'lululemon.com',
  'shop.lululemon.com',
  'patagonia.com',
  'thenorthface.com',
  'columbia.com',
  'levi.com',
  'ralphlauren.com',
  'coach.com',
  'fanatics.com',
  'nflshop.com',
  'nbastore.com',
  'store.nba.com',
  'mlbshop.com',
  'zappos.com',
  'footlocker.com',
  'finishline.com',
  'sephora.com',
  'ulta.com',
  'apple.com',
  'samsung.com',
  'sony.com',
  'electronics.sony.com',
  'lg.com',
  'dell.com',
  'hp.com',
  'lenovo.com',
  'microsoft.com',
  'bose.com',
  'jbl.com',
  'gopro.com',
  'lego.com',
  'funko.com',
  'westelm.com',
  'cb2.com',
  'crateandbarrel.com',
  'potterybarn.com',
  'ashleyfurniture.com',
  'ikea.com',
  'bhphotovideo.com',
  'amazon.com',
};

bool _sharedIsAllowlistedMerchantSearchUrl(String value) {
  final uri = Uri.tryParse(value.trim());
  if (uri == null) return false;
  final host = uri.host.toLowerCase().replaceFirst(RegExp(r'^www\.'), '');
  if (!_sharedMerchantSearchHostAllowlist.contains(host)) return false;

  const searchKeys = {
    'q',
    'query',
    'searchterm',
    'search',
    'keyword',
    'keywords',
    'words',
    'text',
    'k',
    'ntt',
    'st',
    'term',
    'searchquery',
  };
  for (final entry in uri.queryParameters.entries) {
    if (searchKeys.contains(entry.key.toLowerCase()) &&
        entry.value.trim().isNotEmpty) {
      return true;
    }
  }

  final path = uri.path;
  if (RegExp(r'/(s|search)/[^/]+', caseSensitive: false).hasMatch(path)) {
    return true;
  }
  if (RegExp(r'/shop/featured/[^/]+', caseSensitive: false).hasMatch(path)) {
    return true;
  }
  return false;
}

class _SearchEntry {
  const _SearchEntry({
    required this.id,
    required this.bestGuess,
    required this.matchType,
    required this.storagePath,
    required this.derivedQuery,
    required this.createdAt,
    required this.items,
  });

  final String id;
  final String bestGuess;
  final String matchType;
  final String storagePath;
  final String derivedQuery;
  final DateTime? createdAt;
  final List<_VisualSearchItem> items;

  bool get isExpired {
    if (createdAt == null) return false;
    return DateTime.now().difference(createdAt!) >
        _VisualSearchHistoryPageState._maxAge;
  }

  String get relativeTime {
    if (createdAt == null) return 'Recent';
    final diff = DateTime.now().difference(createdAt!);

    if (diff.inSeconds < 60) return '${math.max(diff.inSeconds, 1)}s ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  String get createdAtLabel {
    if (createdAt == null) return 'Now';
    return DateFormat('MMM d, h:mm a').format(createdAt!);
  }

  String get displayFingerprint {
    final roundedMinute = createdAt == null
        ? 'no-time'
        : DateTime(
            createdAt!.year,
            createdAt!.month,
            createdAt!.day,
            createdAt!.hour,
            createdAt!.minute,
          ).millisecondsSinceEpoch.toString();

    final firstLinks = items
        .take(3)
        .map((e) => e.affiliateUrl.trim().toLowerCase())
        .where((e) => e.isNotEmpty)
        .join('|');

    return '${bestGuess.trim().toLowerCase()}__${roundedMinute}__${firstLinks}';
  }

  factory _SearchEntry.fromDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    final rawItems = data['items'];

    final items = rawItems is List
        ? rawItems
            .map((e) => _VisualSearchItem.fromDynamic(e))
            .where((e) => e.hasOpenableUrl)
            .toList()
        : <_VisualSearchItem>[];

    return _SearchEntry(
      id: doc.id,
      bestGuess: (data['bestGuess'] ?? data['title'] ?? '').toString().trim(),
      matchType: (data['matchType'] ?? '').toString().trim(),
      storagePath: (data['storagePath'] ?? '').toString().trim(),
      derivedQuery: (data['derivedQuery'] ?? '').toString().trim(),
      createdAt: _readDate(data['createdAt']),
      items: items,
    );
  }

  static DateTime? _readDate(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate().toLocal();
    if (value is DateTime) return value.toLocal();
    if (value is String) return DateTime.tryParse(value)?.toLocal();
    return null;
  }
}

class _VisualSearchItem {
  const _VisualSearchItem({
    required this.title,
    required this.store,
    required this.storeLogo,
    required this.price,
    required this.affiliateUrl,
    required this.originalUrl,
    required this.isAmazon,
    required this.imageCandidates,
  });

  final String title;
  final String store;
  final String storeLogo;
  final String price;
  final String affiliateUrl;
  final String originalUrl;
  final bool isAmazon;
  final List<String> imageCandidates;

  bool get hasOpenableUrl => _looksLikeAcceptableSovrnAffiliate(affiliateUrl);

  factory _VisualSearchItem.fromDynamic(dynamic raw) {
    final map = raw is Map<String, dynamic>
        ? raw
        : raw is Map
            ? Map<String, dynamic>.from(raw)
            : <String, dynamic>{};

    final imageCandidates = _collectImageCandidates(map);

    final affiliateUrl =
        (map['affiliateUrl'] ?? map['buyUrl'] ?? map['url'] ?? '')
            .toString()
            .trim();
    final originalUrl =
        (map['originalUrl'] ?? map['destinationUrl'] ?? map['url'] ?? '')
            .toString()
            .trim();

    final store = (map['store'] ?? map['source'] ?? '').toString().trim();
    final bool isAmazonFlag = map['isAmazon'] == true;
    final bool isAmazonDerived = store.toLowerCase().contains('amazon') ||
        originalUrl.toLowerCase().contains('amazon.') ||
        affiliateUrl.toLowerCase().contains('amazon.');

    return _VisualSearchItem(
      title: (map['title'] ?? '').toString().trim(),
      store: store,
      storeLogo:
          (map['storeLogo'] ?? map['sourceIcon'] ?? '').toString().trim(),
      price: (map['price'] ?? map['priceValue'] ?? '').toString().trim(),
      affiliateUrl: affiliateUrl,
      originalUrl: originalUrl,
      isAmazon: isAmazonFlag || isAmazonDerived,
      imageCandidates: imageCandidates,
    );
  }

  static List<String> _collectImageCandidates(Map<String, dynamic> map) {
    final candidates = <dynamic>[
      map['thumbnail'],
      map['image'],
      map['thumbnailUrl'],
      map['imageUrl'],
      map['primaryImage'],
      map['primaryImageUrl'],
      map['productImage'],
      map['productImageUrl'],
      map['largeImage'],
      map['largeImageUrl'],
      map['mediumImage'],
      map['mediumImageUrl'],
      map['smallImage'],
      map['smallImageUrl'],
      map['thumb'],
      map['thumbUrl'],
      map['image_link'],
      map['imageLink'],
      map['previewImage'],
      map['previewImageUrl'],
      map['photo'],
      map['photoUrl'],
      map['picture'],
      map['pictureUrl'],
      map['src'],
      map['images'],
      map['thumbnails'],
      map['media'],
      map['gallery'],
      map['product'],
      map['offer'],
      map['offers'],
      map['shoppingResult'],
      map['shoppingResults'],
      map['imageCandidates'],
    ];

    final results = <String>[];
    final seen = <String>{};

    for (final candidate in candidates) {
      for (final value in _extractStrings(candidate)) {
        final normalized = _normalizeImageUrl(value);
        if (normalized.isEmpty) continue;
        if (seen.add(normalized)) {
          results.add(normalized);
        }
      }
    }

    return results;
  }

  static List<String> _extractStrings(dynamic value) {
    if (value == null) return const [];
    if (value is String) return [value];
    if (value is List) {
      return value.expand(_extractStrings).toList();
    }
    if (value is Map) {
      final map = Map<String, dynamic>.from(value);
      return [
        ..._extractStrings(map['url']),
        ..._extractStrings(map['src']),
        ..._extractStrings(map['image']),
        ..._extractStrings(map['imageUrl']),
        ..._extractStrings(map['thumbnail']),
        ..._extractStrings(map['thumbnailUrl']),
        ..._extractStrings(map['secure_url']),
        ..._extractStrings(map['secureUrl']),
        ..._extractStrings(map['original']),
        ..._extractStrings(map['large']),
        ..._extractStrings(map['medium']),
        ..._extractStrings(map['small']),
        ..._extractStrings(map['images']),
        ..._extractStrings(map['media']),
        ..._extractStrings(map['gallery']),
      ];
    }
    return [value.toString()];
  }

  static String _normalizeImageUrl(String value) {
    var url = value.trim();
    if (url.isEmpty) return '';

    if (url.startsWith('//')) {
      url = 'https:$url';
    }

    if (url.startsWith('http://') ||
        url.startsWith('https://') ||
        url.startsWith('data:image/')) {
      return url;
    }

    return '';
  }
}

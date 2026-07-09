// Automatic FlutterFlow imports
import '/backend/backend.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'index.dart'; // Imports other custom widgets
import '/custom_code/actions/index.dart'; // Imports custom actions
import 'package:flutter/material.dart';
// Begin custom widget code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';

class DiscoverPage extends StatefulWidget {
  const DiscoverPage({
    Key? key,
    this.width,
    this.height,
    this.limit = 18,
    this.historyLimit = 10,
    this.bottomScrollSpace = 100,
    this.showHeader = true,
    this.showNotice = true,
    this.heroTitle = 'Discover',
    this.heroSubtitle =
        'Smart affiliate recommendations based on your recent visual searches.',
    this.emptyTitle = 'No recommendations yet',
    this.emptySubtitle =
        'Search products by photo or snapshot and related merch will appear here.',
  }) : super(key: key);

  final double? width;
  final double? height;
  final int limit;
  final int historyLimit;
  final double bottomScrollSpace;
  final bool showHeader;
  final bool showNotice;
  final String heroTitle;
  final String heroSubtitle;
  final String emptyTitle;
  final String emptySubtitle;

  @override
  State<DiscoverPage> createState() => _DiscoverPageState();
}

class _DiscoverPageState extends State<DiscoverPage> {
  bool _loading = true;
  bool _refreshing = false;
  bool _openingLink = false;
  String _errorText = '';

  _DiscoverResponse? _response;

  User? get _user => FirebaseAuth.instance.currentUser;

  // ---------------------------------------------------------------------------
  // NaN / Infinity guards
  //
  // When this widget is embedded as a FlutterFlow custom widget, the wrapper
  // can pass `double.nan` or `double.infinity` for width/height props, and in
  // some constraint paths MediaQuery.size can also be non-finite. That leaks
  // into `Positioned(top: height * 0.14, ...)` → "Offset argument contained a
  // NaN value" crash. Sanitize every numeric size at the top of build().
  // ---------------------------------------------------------------------------
  double _safeDouble(double? value, double fallback) {
    if (value == null) return fallback;
    if (value.isNaN || value.isInfinite) return fallback;
    return value;
  }

  double _safePositive(double? value, double fallback) {
    final v = _safeDouble(value, fallback);
    return v <= 0 ? fallback : v;
  }

  @override
  void initState() {
    super.initState();
    unawaited(_loadRecommendations());
  }

  Future<void> _loadRecommendations({bool forceRefresh = false}) async {
    if (_user == null) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _refreshing = false;
        _errorText = '';
        _response = null;
      });
      return;
    }

    if (!mounted) return;
    setState(() {
      if (forceRefresh) {
        _refreshing = true;
      } else {
        _loading = true;
      }
      _errorText = '';
    });

    try {
      final callable =
          FirebaseFunctions.instanceFor(region: 'us-central1').httpsCallable(
        'discoverAffiliateRecommendations',
        options: HttpsCallableOptions(
          // Backend is configured for 180s — match it on the client or
          // the platform SDK aborts at its ~70s default while the server
          // is still running the OpenAI planner + Serper shopping call.
          timeout: const Duration(seconds: 180),
        ),
      );

      final result = await callable.call({
        'limit': widget.limit.clamp(1, 30),
        'historyLimit': widget.historyLimit.clamp(3, 20),
      });

      final data = result.data;
      final map = data is Map<String, dynamic>
          ? data
          : data is Map
              ? Map<String, dynamic>.from(data)
              : <String, dynamic>{};

      final parsed = _DiscoverResponse.fromMap(map);

      if (!mounted) return;
      setState(() {
        _response = parsed;
        _loading = false;
        _refreshing = false;
        _errorText = '';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _refreshing = false;
        _errorText = e.toString();
      });
    }
  }

  // Calls the server-side resolveAffiliateLink callable on-tap.
  // Server returns { success, affiliateUrl, network: "sovrn"|"amazon"|"none" }.
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

  bool _isGoogleOwnedUrl(String value) {
    final uri = Uri.tryParse(value.trim());
    final host = (uri?.host ?? '').toLowerCase();
    if (host.isEmpty) return false;
    return host == 'google.com' ||
        host == 'www.google.com' ||
        host.endsWith('.google.com');
  }

  String _unwrapSovrnDestination(String value) {
    final uri = Uri.tryParse(value.trim());
    if (uri == null) return '';
    return (uri.queryParameters['u'] ?? '').trim();
  }

  bool _hasAnyQueryParam(Uri uri, List<String> keys) {
    for (final key in keys) {
      if ((uri.queryParameters[key] ?? '').trim().isNotEmpty) return true;
    }
    return false;
  }

  // Matches the backend's MERCHANT_SEARCH_URL_ALLOWED_HOSTS so that
  // Sovrn-wrapped merchant search URLs (walmart.com/search?q=...,
  // target.com/s?searchTerm=..., etc.) tap through successfully.
  // Previously the strict _isLikelyProductDetailUrl rejected these,
  // so Discover recommendations backed by search-URL fallbacks
  // silently did nothing on tap.
  static const Set<String> _merchantSearchHostAllowlist = {
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

  bool _isAllowlistedMerchantSearchUrl(String value) {
    final uri = Uri.tryParse(value.trim());
    if (uri == null) return false;
    final host = uri.host.toLowerCase().replaceFirst(RegExp(r'^www\.'), '');
    if (!_merchantSearchHostAllowlist.contains(host)) return false;

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

  bool _isLikelyProductDetailUrl(String value) {
    final cleaned = value.trim();
    if (cleaned.isEmpty) return false;
    if (_isGoogleOwnedUrl(cleaned)) return false;

    final uri = Uri.tryParse(cleaned);
    if (uri == null) return false;

    final host = uri.host.toLowerCase();
    final path = uri.path.toLowerCase();
    final segments =
        uri.pathSegments.where((e) => e.trim().isNotEmpty).toList();

    if (segments.isEmpty) return false;

    // Path-aware detail detection — tolerant of tracking/variant query
    // params like ?color= or ?srsltid= on pages whose PATH already
    // looks like a product detail URL.
    final pathLooksLikeDetail =
        RegExp(r'/(product|products|prod|itm)/', caseSensitive: false)
                .hasMatch(path) ||
            RegExp(r'/(p-|sku-|pid-|prod-)[a-z0-9-]+', caseSensitive: false)
                .hasMatch(path) ||
            RegExp(
                    r'/(?:[a-z0-9-]+-){2,}[a-z0-9-]+(?:\.html?)?$',
                    caseSensitive: false)
                .hasMatch(path) ||
            RegExp(r'[-_][a-z0-9]{6,}(?:\.html?)?$', caseSensitive: false)
                .hasMatch(path) ||
            RegExp(r'/\d{3,}\.(p|html?)(?:[/?]|$)', caseSensitive: false)
                .hasMatch(path) ||
            (segments.length >= 2 && segments.last.length >= 18);

    if (!pathLooksLikeDetail &&
        _hasAnyQueryParam(uri, const [
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
        ])) {
      return false;
    }

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
          RegExp(r'/gp/product/[A-Za-z0-9]{10}(?:[/?-]|$)',
                  caseSensitive: false)
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

  bool _isAcceptableSovrnDestination(String value) {
    return _isLikelyProductDetailUrl(value) ||
        _isAllowlistedMerchantSearchUrl(value);
  }

  bool _isDirectMerchantAffiliateUrl(String value) {
    if (!_isSovrnUrl(value)) return false;
    final wrapped = _unwrapSovrnDestination(value);
    if (wrapped.isEmpty) return false;
    if (_isGoogleOwnedUrl(wrapped)) return false;
    return _isAcceptableSovrnDestination(wrapped);
  }

  bool _isExactMerchantUrl(String value) {
    return _isAcceptableSovrnDestination(value);
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

  Future<void> _openItem(_DiscoverItem item) async {
    if (_openingLink) return;

    // Hand the backend the ORIGINAL merchant URL (or the pre-built
    // affiliate URL as a fallback hint) plus the store name and title.
    // The backend's resolveAffiliateLink:
    //   1. Tries to produce a direct merchant URL
    //   2. If given a Google URL, unwraps / follows it to the real store
    //   3. If still nothing, builds a MERCHANT-SEARCH URL on the actual
    //      store's site (walmart.com/search?q=..., fanatics.com/search?
    //      query=..., etc.) — NEVER Amazon unless the item actually has
    //      no other store signal.
    //   4. Wraps the final URL through the Sovrn Commerce Link Check API
    // Whatever comes back is already a Sovrn-attributed redirect URL.
    final String hintUrl = item.originalUrl.trim().isNotEmpty
        ? item.originalUrl.trim()
        : item.affiliateUrl.trim();

    setState(() {
      _openingLink = true;
    });

    try {
      final resolved = await _resolveAffiliateLink(
        url: hintUrl,
        amazonOnly: false,
        store: item.store,
        title: item.title,
      );

      String launchTarget = (resolved['affiliateUrl'] ?? '').toString().trim();

      // The server returned a Sovrn-wrapped URL? Trust it and launch.
      if (!_isSovrnUrl(launchTarget)) {
        // Extreme last resort: if the pre-built affiliate URL is itself
        // Sovrn-wrapped, use it. Otherwise refuse to launch anything —
        // we never want to send the user to a non-Sovrn URL (that would
        // forfeit commission).
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

  String? _extractAmazonAsin(String url) {
    final value = url.trim();
    if (value.isEmpty) return null;

    final patterns = <RegExp>[
      RegExp(r'/dp/([A-Z0-9]{10})(?:[/?]|$)', caseSensitive: false),
      RegExp(r'/gp/product/([A-Z0-9]{10})(?:[/?]|$)', caseSensitive: false),
      RegExp(r'/product/([A-Z0-9]{10})(?:[/?]|$)', caseSensitive: false),
      RegExp(r'[?&]asin=([A-Z0-9]{10})(?:[&#]|$)', caseSensitive: false),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(value);
      if (match != null && match.groupCount >= 1) {
        return match.group(1)?.toUpperCase();
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);

    final double mediaWidth = _safePositive(media.size.width, 360.0);
    final double mediaHeight = _safePositive(media.size.height, 640.0);

    final double width = _safePositive(widget.width, mediaWidth);
    final double height = _safePositive(widget.height, mediaHeight);

    final isPortrait = media.orientation == Orientation.portrait;

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
      child: _buildBody(context, isPortrait),
    );
  }

  Widget _buildBody(BuildContext context, bool isPortrait) {
    if (_loading) {
      return _buildLoadingState(context);
    }

    if (_errorText.isNotEmpty) {
      return _buildErrorState(context, _errorText);
    }

    final response = _response;
    if (response == null || response.items.isEmpty) {
      return _buildEmptyState(context, isPortrait);
    }

    final spotlight = response.items.take(3).toList();
    final moreItems = response.items.length > 3
        ? response.items.skip(3).toList(growable: false)
        : const <_DiscoverItem>[];

    final double bottomPad = _safeDouble(
      MediaQuery.of(context).padding.bottom,
      0.0,
    );

    return Column(
      children: [
        if (widget.showHeader) _buildHeroHeader(context, response),
        if (widget.showNotice) _buildNotice(context, response),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => _loadRecommendations(forceRefresh: true),
            color: const Color(0xFFB99CFF),
            backgroundColor: const Color(0xFF171229),
            child: ListView(
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              padding: EdgeInsets.fromLTRB(
                isPortrait ? 14 : 18,
                8,
                isPortrait ? 14 : 18,
                _safeDouble(widget.bottomScrollSpace, 100.0) +
                    (isPortrait ? 8 : 6) +
                    bottomPad,
              ),
              children: [
                _buildThemeSummaryCard(context, response),
                const SizedBox(height: 14),
                _buildCategoryChips(context, response),
                const SizedBox(height: 14),
                _buildTopPicksSection(context, spotlight, isPortrait),
                if (moreItems.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  _buildGridSection(context, moreItems, isPortrait),
                ],
                if (_refreshing) ...[
                  const SizedBox(height: 14),
                  Center(
                    child: Text(
                      'Refreshing recommendations...',
                      style: FlutterFlowTheme.of(context).bodySmall.override(
                            fontFamily:
                                FlutterFlowTheme.of(context).bodySmallFamily,
                            color: Colors.white.withOpacity(0.74),
                            fontSize: 11.4,
                            fontWeight: FontWeight.w600,
                            useGoogleFonts:
                                !FlutterFlowTheme.of(context).bodySmallIsCustom,
                          ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildShell({
    required BuildContext context,
    required double width,
    required double height,
    required bool isPortrait,
    required Widget child,
  }) {
    final media = MediaQuery.of(context);
    final double safeTop = _safeDouble(media.padding.top, 0.0);
    final double safeBottom = _safeDouble(media.padding.bottom, 0.0);

    final double safeHeight = _safePositive(height, 640.0);
    final double safeWidth = _safePositive(width, 360.0);

    return SizedBox(
      width: safeWidth,
      height: safeHeight,
      child: ClipRect(
        child: Stack(
          fit: StackFit.expand,
          children: [
            Container(
              width: safeWidth,
              height: safeHeight,
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
              top: _safeDouble(safeHeight * 0.14, 90.0),
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
                  bottom: isPortrait ? safeBottom + 6 : math.max(6, safeBottom),
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
                      borderRadius: 24,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 14,
                      ),
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
                            'Opening recommendation...',
                            style: FlutterFlowTheme.of(context)
                                .bodyMedium
                                .override(
                                  fontFamily: FlutterFlowTheme.of(context)
                                      .bodyMediumFamily,
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
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

  Widget _buildHeroHeader(BuildContext context, _DiscoverResponse response) {
    final subtitle = response.primaryTheme.isEmpty
        ? widget.heroSubtitle
        : 'Recommendations inspired by ${response.primaryTheme}.';

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 10),
      child: _glassPanel(
        borderRadius: 28,
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFFB07CFF).withOpacity(0.96),
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
                Icons.auto_awesome_rounded,
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
                    widget.heroTitle,
                    style: FlutterFlowTheme.of(context).titleLarge.override(
                          fontFamily:
                              FlutterFlowTheme.of(context).titleLargeFamily,
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          useGoogleFonts:
                              !FlutterFlowTheme.of(context).titleLargeIsCustom,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: FlutterFlowTheme.of(context).bodyMedium.override(
                          fontFamily:
                              FlutterFlowTheme.of(context).bodyMediumFamily,
                          color: Colors.white.withOpacity(0.76),
                          fontSize: 12.8,
                          fontWeight: FontWeight.w500,
                          useGoogleFonts:
                              !FlutterFlowTheme.of(context).bodyMediumIsCustom,
                        ),
                  ),
                ],
              ),
            ),
            Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: _refreshing
                    ? null
                    : () => _loadRecommendations(forceRefresh: true),
                child: Ink(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    color: Colors.white.withOpacity(0.08),
                    border: Border.all(color: Colors.white.withOpacity(0.08)),
                  ),
                  child: const Icon(
                    Icons.refresh_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotice(BuildContext context, _DiscoverResponse response) {
    final text = response.shopperIntent.isNotEmpty
        ? response.shopperIntent
        : 'These picks are generated from your recent visual search history using your affiliate recommendation flow.';

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
                Icons.local_fire_department_rounded,
                color: Color(0xFFD8C8FF),
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                text,
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

  Widget _buildThemeSummaryCard(
    BuildContext context,
    _DiscoverResponse response,
  ) {
    return _glassPanel(
      borderRadius: 26,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Theme',
            style: FlutterFlowTheme.of(context).bodySmall.override(
                  fontFamily: FlutterFlowTheme.of(context).bodySmallFamily,
                  color: Colors.white.withOpacity(0.68),
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  useGoogleFonts:
                      !FlutterFlowTheme.of(context).bodySmallIsCustom,
                ),
          ),
          const SizedBox(height: 5),
          Text(
            response.primaryTheme.isEmpty
                ? 'Related picks for you'
                : response.primaryTheme,
            style: FlutterFlowTheme.of(context).titleMedium.override(
                  fontFamily: FlutterFlowTheme.of(context).titleMediumFamily,
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  useGoogleFonts:
                      !FlutterFlowTheme.of(context).titleMediumIsCustom,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            '${response.resultCount} recommendations found',
            style: FlutterFlowTheme.of(context).bodySmall.override(
                  fontFamily: FlutterFlowTheme.of(context).bodySmallFamily,
                  color: Colors.white.withOpacity(0.72),
                  fontSize: 11.8,
                  fontWeight: FontWeight.w600,
                  useGoogleFonts:
                      !FlutterFlowTheme.of(context).bodySmallIsCustom,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryChips(
    BuildContext context,
    _DiscoverResponse response,
  ) {
    final chips = response.relatedCategories;
    if (chips.isEmpty) {
      return const SizedBox.shrink();
    }

    return _glassPanel(
      borderRadius: 24,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Related categories',
            style: FlutterFlowTheme.of(context).titleSmall.override(
                  fontFamily: FlutterFlowTheme.of(context).titleSmallFamily,
                  color: Colors.white,
                  fontSize: 14.6,
                  fontWeight: FontWeight.w800,
                  useGoogleFonts:
                      !FlutterFlowTheme.of(context).titleSmallIsCustom,
                ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: chips
                .map(
                  (term) => Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      gradient: LinearGradient(
                        colors: [
                          Colors.white.withOpacity(0.12),
                          Colors.white.withOpacity(0.05),
                        ],
                      ),
                      border: Border.all(color: Colors.white.withOpacity(0.10)),
                    ),
                    child: Text(
                      term,
                      style: FlutterFlowTheme.of(context).bodySmall.override(
                            fontFamily:
                                FlutterFlowTheme.of(context).bodySmallFamily,
                            color: const Color(0xFFE7DEFF),
                            fontSize: 11.2,
                            fontWeight: FontWeight.w700,
                            useGoogleFonts:
                                !FlutterFlowTheme.of(context).bodySmallIsCustom,
                          ),
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildTopPicksSection(
    BuildContext context,
    List<_DiscoverItem> items,
    bool isPortrait,
  ) {
    return _glassPanel(
      borderRadius: 28,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Top picks for you',
            style: FlutterFlowTheme.of(context).titleMedium.override(
                  fontFamily: FlutterFlowTheme.of(context).titleMediumFamily,
                  color: Colors.white,
                  fontSize: 16.5,
                  fontWeight: FontWeight.w800,
                  useGoogleFonts:
                      !FlutterFlowTheme.of(context).titleMediumIsCustom,
                ),
          ),
          const SizedBox(height: 10),
          Column(
            children: List.generate(items.length, (index) {
              final item = items[index];
              final badge = index == 0
                  ? 'Best match'
                  : index == 1
                      ? 'Related favorite'
                      : 'Clever pick';

              return Padding(
                padding:
                    EdgeInsets.only(bottom: index == items.length - 1 ? 0 : 12),
                child: _FeaturedRecommendationCard(
                  item: item,
                  compact: !isPortrait,
                  badge: badge,
                  onTap: _openingLink ? null : () => _openItem(item),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildGridSection(
    BuildContext context,
    List<_DiscoverItem> items,
    bool isPortrait,
  ) {
    final crossAxisCount = isPortrait ? 2 : 3;
    final aspectRatio = isPortrait ? 0.78 : 0.96;

    return _glassPanel(
      borderRadius: 28,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'More related items',
            style: FlutterFlowTheme.of(context).titleMedium.override(
                  fontFamily: FlutterFlowTheme.of(context).titleMediumFamily,
                  color: Colors.white,
                  fontSize: 16.2,
                  fontWeight: FontWeight.w800,
                  useGoogleFonts:
                      !FlutterFlowTheme.of(context).titleMediumIsCustom,
                ),
          ),
          const SizedBox(height: 12),
          GridView.builder(
            itemCount: items.length,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: aspectRatio,
            ),
            itemBuilder: (context, index) {
              final item = items[index];
              return _MiniRecommendationCard(
                item: item,
                onTap: _openingLink ? null : () => _openItem(item),
              );
            },
          ),
        ],
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
                'Loading recommendations...',
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
              const Icon(
                Icons.error_outline_rounded,
                color: Color(0xFFFFC0D6),
                size: 28,
              ),
              const SizedBox(height: 12),
              Text(
                'Could not load recommendations',
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
              const SizedBox(height: 14),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: () => _loadRecommendations(forceRefresh: true),
                  child: Ink(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF9F6BFF).withOpacity(0.96),
                          const Color(0xFF63C7FF).withOpacity(0.90),
                        ],
                      ),
                    ),
                    child: Text(
                      'Try again',
                      style: FlutterFlowTheme.of(context).bodyMedium.override(
                            fontFamily:
                                FlutterFlowTheme.of(context).bodyMediumFamily,
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            useGoogleFonts: !FlutterFlowTheme.of(context)
                                .bodyMediumIsCustom,
                          ),
                    ),
                  ),
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
                    child: const Icon(
                      Icons.travel_explore_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
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
                const Icon(
                  Icons.lock_outline_rounded,
                  color: Colors.white,
                  size: 28,
                ),
                const SizedBox(height: 12),
                Text(
                  'User must be logged in',
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
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _glassPanel({
    required Widget child,
    EdgeInsetsGeometry padding = const EdgeInsets.all(12),
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
                Colors.white.withOpacity(0.06),
              ],
            ),
            border: Border.all(
              color: Colors.white.withOpacity(0.10),
              width: 1,
            ),
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _blurOrb({
    required double size,
    required Color color,
  }) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              color,
              color.withOpacity(0.0),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeaturedRecommendationCard extends StatefulWidget {
  const _FeaturedRecommendationCard({
    required this.item,
    required this.compact,
    required this.badge,
    required this.onTap,
  });

  final _DiscoverItem item;
  final bool compact;
  final String badge;
  final VoidCallback? onTap;

  @override
  State<_FeaturedRecommendationCard> createState() =>
      _FeaturedRecommendationCardState();
}

class _FeaturedRecommendationCardState
    extends State<_FeaturedRecommendationCard> {
  int _imageIndex = 0;

  @override
  void didUpdateWidget(covariant _FeaturedRecommendationCard oldWidget) {
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

    final imageSize = widget.compact ? 86.0 : 98.0;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: widget.onTap,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
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
            padding: const EdgeInsets.all(11),
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
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(999),
                              color: const Color(0xFF8754FF).withOpacity(0.18),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.08),
                              ),
                            ),
                            child: Text(
                              widget.badge,
                              style: FlutterFlowTheme.of(context)
                                  .bodySmall
                                  .override(
                                    fontFamily: FlutterFlowTheme.of(context)
                                        .bodySmallFamily,
                                    color: const Color(0xFFE1D5FF),
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w800,
                                    useGoogleFonts:
                                        !FlutterFlowTheme.of(context)
                                            .bodySmallIsCustom,
                                  ),
                            ),
                          ),
                          if (widget.item.categoryHint.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(999),
                                color:
                                    const Color(0xFF63C7FF).withOpacity(0.16),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.08),
                                ),
                              ),
                              child: Text(
                                widget.item.categoryHint,
                                style: FlutterFlowTheme.of(context)
                                    .bodySmall
                                    .override(
                                      fontFamily: FlutterFlowTheme.of(context)
                                          .bodySmallFamily,
                                      color: const Color(0xFFD9F2FF),
                                      fontSize: 10.2,
                                      fontWeight: FontWeight.w800,
                                      useGoogleFonts:
                                          !FlutterFlowTheme.of(context)
                                              .bodySmallIsCustom,
                                    ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 9),
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
                              fontSize: widget.compact ? 12.6 : 13.4,
                              fontWeight: FontWeight.w800,
                              useGoogleFonts: !FlutterFlowTheme.of(context)
                                  .bodyMediumIsCustom,
                            ),
                      ),
                      const SizedBox(height: 7),
                      Text(
                        widget.item.store.isEmpty
                            ? 'Affiliate product'
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
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          if (widget.item.price.isNotEmpty)
                            Flexible(
                              child: Text(
                                widget.item.price,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: FlutterFlowTheme.of(context)
                                    .titleSmall
                                    .override(
                                      fontFamily: FlutterFlowTheme.of(context)
                                          .titleSmallFamily,
                                      color: const Color(0xFFD9C9FF),
                                      fontSize: 13.2,
                                      fontWeight: FontWeight.w800,
                                      useGoogleFonts:
                                          !FlutterFlowTheme.of(context)
                                              .titleSmallIsCustom,
                                    ),
                              ),
                            ),
                          const Spacer(),
                          Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: [
                                  const Color(0xFF9F6BFF).withOpacity(0.96),
                                  const Color(0xFF63C7FF).withOpacity(0.90),
                                ],
                              ),
                            ),
                            child: const Icon(
                              Icons.arrow_outward_rounded,
                              color: Colors.white,
                              size: 18,
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

class _MiniRecommendationCard extends StatefulWidget {
  const _MiniRecommendationCard({
    required this.item,
    required this.onTap,
  });

  final _DiscoverItem item;
  final VoidCallback? onTap;

  @override
  State<_MiniRecommendationCard> createState() =>
      _MiniRecommendationCardState();
}

class _MiniRecommendationCardState extends State<_MiniRecommendationCard> {
  int _imageIndex = 0;

  @override
  void didUpdateWidget(covariant _MiniRecommendationCard oldWidget) {
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
                Colors.white.withOpacity(0.13),
                Colors.white.withOpacity(0.05),
              ],
            ),
            border: Border.all(color: Colors.white.withOpacity(0.10)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      color: Colors.white.withOpacity(0.93),
                    ),
                    padding: const EdgeInsets.all(8),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: _buildImage(image),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                if (widget.item.categoryHint.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      widget.item.categoryHint,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: FlutterFlowTheme.of(context).bodySmall.override(
                            fontFamily:
                                FlutterFlowTheme.of(context).bodySmallFamily,
                            color: const Color(0xFFD9F2FF),
                            fontSize: 10.2,
                            fontWeight: FontWeight.w800,
                            useGoogleFonts:
                                !FlutterFlowTheme.of(context).bodySmallIsCustom,
                          ),
                    ),
                  ),
                Text(
                  widget.item.title.isEmpty ? 'Product' : widget.item.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: FlutterFlowTheme.of(context).bodyMedium.override(
                        fontFamily:
                            FlutterFlowTheme.of(context).bodyMediumFamily,
                        color: Colors.white,
                        fontSize: 12.2,
                        fontWeight: FontWeight.w800,
                        useGoogleFonts:
                            !FlutterFlowTheme.of(context).bodyMediumIsCustom,
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  widget.item.store.isEmpty
                      ? 'Affiliate product'
                      : widget.item.store,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: FlutterFlowTheme.of(context).bodySmall.override(
                        fontFamily:
                            FlutterFlowTheme.of(context).bodySmallFamily,
                        color: Colors.white.withOpacity(0.70),
                        fontSize: 10.6,
                        fontWeight: FontWeight.w600,
                        useGoogleFonts:
                            !FlutterFlowTheme.of(context).bodySmallIsCustom,
                      ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.item.price.isEmpty
                            ? 'View item'
                            : widget.item.price,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: FlutterFlowTheme.of(context).titleSmall.override(
                              fontFamily:
                                  FlutterFlowTheme.of(context).titleSmallFamily,
                              color: const Color(0xFFD9C9FF),
                              fontSize: 12.4,
                              fontWeight: FontWeight.w800,
                              useGoogleFonts: !FlutterFlowTheme.of(context)
                                  .titleSmallIsCustom,
                            ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(
                      Icons.arrow_outward_rounded,
                      color: Colors.white,
                      size: 16,
                    ),
                  ],
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

class _DiscoverResponse {
  const _DiscoverResponse({
    required this.success,
    required this.primaryTheme,
    required this.shopperIntent,
    required this.relatedCategories,
    required this.queriesUsed,
    required this.resultCount,
    required this.items,
    required this.createdAt,
  });

  final bool success;
  final String primaryTheme;
  final String shopperIntent;
  final List<String> relatedCategories;
  final List<String> queriesUsed;
  final int resultCount;
  final List<_DiscoverItem> items;
  final String createdAt;

  factory _DiscoverResponse.fromMap(Map<String, dynamic> map) {
    final rawItems = map['items'];
    return _DiscoverResponse(
      success: map['success'] == true,
      primaryTheme: (map['primaryTheme'] ?? '').toString().trim(),
      shopperIntent: (map['shopperIntent'] ?? '').toString().trim(),
      relatedCategories: _stringList(map['relatedCategories']),
      queriesUsed: _stringList(map['queriesUsed']),
      resultCount: _safeInt(map['resultCount']),
      items: rawItems is List
          ? rawItems
              .map((e) => _DiscoverItem.fromDynamic(e))
              .where((e) => e.title.isNotEmpty || e.hasOpenableUrl)
              .toList(growable: false)
          : const <_DiscoverItem>[],
      createdAt: (map['createdAt'] ?? '').toString().trim(),
    );
  }

  static List<String> _stringList(dynamic value) {
    if (value is! List) return const <String>[];
    return value
        .map((e) => e?.toString().trim() ?? '')
        .where((e) => e.isNotEmpty)
        .toList(growable: false);
  }

  static int _safeInt(dynamic value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}

class _DiscoverItem {
  const _DiscoverItem({
    required this.title,
    required this.store,
    required this.storeLogo,
    required this.price,
    required this.affiliateUrl,
    required this.originalUrl,
    required this.categoryHint,
    required this.imageCandidates,
    required this.score,
    required this.isAmazon,
  });

  final String title;
  final String store;
  final String storeLogo;
  final String price;
  final String affiliateUrl;
  final String originalUrl;
  final String categoryHint;
  final List<String> imageCandidates;
  final double score;
  final bool isAmazon;

  // Now accepts BOTH product-detail URLs AND allowlisted merchant search
  // URLs, matching the backend's isAcceptableSovrnDestination(). Without
  // this, Discover items whose affiliate URL wrapped a search-URL fall-
  // back (e.g. target.com/s?searchTerm=...) were silently filtered out.
  bool get hasOpenableUrl => _looksLikeAcceptableSovrnAffiliate(affiliateUrl);

  factory _DiscoverItem.fromDynamic(dynamic raw) {
    final map = raw is Map<String, dynamic>
        ? raw
        : raw is Map
            ? Map<String, dynamic>.from(raw)
            : <String, dynamic>{};

    final images = _collectImageCandidates(map);

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

    return _DiscoverItem(
      title: (map['title'] ?? '').toString().trim(),
      store: store,
      storeLogo:
          (map['storeLogo'] ?? map['sourceIcon'] ?? '').toString().trim(),
      price: (map['price'] ?? map['priceValue'] ?? '').toString().trim(),
      affiliateUrl: affiliateUrl,
      originalUrl: originalUrl,
      categoryHint: (map['categoryHint'] ?? '').toString().trim(),
      imageCandidates: images,
      score: _safeDouble(map['score']),
      isAmazon: isAmazonFlag || isAmazonDerived,
    );
  }

  static double _safeDouble(dynamic value) {
    if (value is double) {
      if (value.isNaN || value.isInfinite) return 0;
      return value;
    }
    if (value is int) return value.toDouble();
    final parsed = double.tryParse(value?.toString() ?? '') ?? 0;
    if (parsed.isNaN || parsed.isInfinite) return 0;
    return parsed;
  }

  static List<String> _collectImageCandidates(Map<String, dynamic> map) {
    final candidates = <dynamic>[
      map['imageCandidates'],
      map['image'],
      map['thumbnail'],
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
      map['icon'],
      map['iconUrl'],
      map['photo'],
      map['photoUrl'],
      map['picture'],
      map['pictureUrl'],
      map['src'],
      map['images'],
      map['thumbnails'],
      map['media'],
      map['gallery'],
    ];

    final seen = <String>{};
    final output = <String>[];

    for (final candidate in candidates) {
      final urls = _extractImageStrings(candidate);
      for (final url in urls) {
        final normalized = _normalizeImageUrl(url);
        if (normalized.isEmpty) continue;
        if (seen.add(normalized)) {
          output.add(normalized);
        }
      }
    }

    return output;
  }

  static List<String> _extractImageStrings(dynamic value) {
    if (value == null) return const <String>[];

    if (value is String) {
      return value.trim().isEmpty ? const <String>[] : <String>[value.trim()];
    }

    if (value is List) {
      final output = <String>[];
      for (final entry in value) {
        output.addAll(_extractImageStrings(entry));
      }
      return output;
    }

    if (value is Map) {
      final map = Map<String, dynamic>.from(value);
      final output = <String>[];
      for (final key in [
        'url',
        'src',
        'image',
        'imageUrl',
        'thumbnail',
        'thumbnailUrl',
        'link',
        'href',
        'secure_url',
        'secureUrl',
        'original',
        'large',
        'medium',
        'small',
        'image_link',
        'imageLink',
        'previewImage',
        'previewImageUrl',
        'primaryImage',
        'primaryImageUrl',
        'productImage',
        'productImageUrl',
        'images',
        'thumbnails',
        'media',
        'gallery',
      ]) {
        output.addAll(_extractImageStrings(map[key]));
      }
      return output;
    }

    return <String>[value.toString()];
  }

  static String _normalizeImageUrl(dynamic value) {
    if (value == null) return '';
    var url = value.toString().trim();
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

// Top-level version of the validator, shared by _DiscoverItem.hasOpenableUrl.
// Identical semantics to the class-level version inside _DiscoverPageState.
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

  return _topLevelIsLikelyProductDetailUrl(wrapped) ||
      _topLevelIsAllowlistedMerchantSearchUrl(wrapped);
}

bool _topLevelIsLikelyProductDetailUrl(String value) {
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

const Set<String> _topLevelMerchantSearchHostAllowlist = {
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

bool _topLevelIsAllowlistedMerchantSearchUrl(String value) {
  final uri = Uri.tryParse(value.trim());
  if (uri == null) return false;
  final host = uri.host.toLowerCase().replaceFirst(RegExp(r'^www\.'), '');
  if (!_topLevelMerchantSearchHostAllowlist.contains(host)) return false;

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

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

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:go_router/go_router.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

class ImageSearchPage extends StatefulWidget {
  const ImageSearchPage({
    Key? key,
    this.width,
    this.height,
    this.searchLimit = 20,
    this.storeHistoryToFirestore = true,
    this.showHeader = true,
    this.showNotice = true,
    this.bottomScrollSpace = 100,
    this.heroTitle = 'Image product search',
    this.heroSubtitle =
        'Upload one photo and find the closest matching products.',
    // Pass the FlutterFlow route or URL for the history page. When set,
    // we navigate there after results are ready. Leave null and handle
    // navigation via a Firestore listener on visual_search_runtime/current.
    this.historyRouteName,
    // Route to send anonymous (guest) users to once they've used their
    // free guest searches up. Defaults to "introPage".
    this.introRouteName = 'introPage',
    // How many free image searches a guest user gets. Default: 2.
    this.guestSearchLimit = 2,
  }) : super(key: key);

  final double? width;
  final double? height;
  final int searchLimit;
  final bool storeHistoryToFirestore;
  final bool showHeader;
  final bool showNotice;
  final double bottomScrollSpace;
  final String heroTitle;
  final String heroSubtitle;
  final String? historyRouteName;
  final String introRouteName;
  final int guestSearchLimit;

  @override
  State<ImageSearchPage> createState() => _ImageSearchPageState();
}

class _ImageSearchPageState extends State<ImageSearchPage>
    with SingleTickerProviderStateMixin {
  final ImagePicker _picker = ImagePicker();

  bool _busy = false;
  bool _hasSearched = false;

  String _statusText = 'Upload a product image to start';
  String _bestGuess = '';
  String _lastStoragePath = '';

  Uint8List? _selectedImageBytes;

  // Guest tracking
  int _guestSearchCount = 0;
  bool _guestLimitChecked = false;

  User? get _user => FirebaseAuth.instance.currentUser;

  bool get _isGuest => _user?.isAnonymous == true;

  DocumentReference<Map<String, dynamic>>? get _runtimeDoc {
    final user = _user;
    if (user == null) return null;
    return FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('visual_search_runtime')
        .doc('current');
  }

  DocumentReference<Map<String, dynamic>>? get _guestUsageDoc {
    final user = _user;
    if (user == null) return null;
    return FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('guest_usage')
        .doc('current');
  }

  @override
  void initState() {
    super.initState();
    unawaited(_writeRuntimeState(
      status: _statusText,
      busy: false,
      lastError: '',
      clearResult: true,
    ));
    unawaited(_loadGuestSearchCount());
  }

  Future<void> _loadGuestSearchCount() async {
    if (!_isGuest) {
      if (!mounted) return;
      setState(() {
        _guestLimitChecked = true;
      });
      return;
    }

    try {
      final doc = _guestUsageDoc;
      if (doc == null) return;
      final snap = await doc.get();
      final data = snap.data() ?? {};
      final count = (data['imageSearchCount'] as num?)?.toInt() ?? 0;

      if (!mounted) return;
      setState(() {
        _guestSearchCount = count;
        _guestLimitChecked = true;
      });

      // If guest already exhausted limit before opening this page,
      // bounce them to intro immediately.
      if (count >= widget.guestSearchLimit) {
        _navigateToIntro();
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _guestLimitChecked = true;
      });
    }
  }

  Future<void> _incrementGuestSearchCount() async {
    if (!_isGuest) return;
    final doc = _guestUsageDoc;
    if (doc == null) return;
    try {
      await doc.set({
        'imageSearchCount': FieldValue.increment(1),
        'lastImageSearchAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  void _navigateToIntro() {
    if (!mounted) return;
    final routeName = widget.introRouteName.trim();
    if (routeName.isEmpty) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      try {
        context.pushNamed(routeName);
        return;
      } catch (_) {}

      try {
        context.push(routeName);
        return;
      } catch (_) {}

      try {
        Navigator.of(context).pushNamed(routeName);
      } catch (_) {
        try {
          Navigator.of(context).pushReplacementNamed(routeName);
        } catch (_) {}
      }
    });
  }

  Future<void> _pickImageAndSearch() async {
    if (_busy) return;

    if (_user == null) {
      setState(() {
        _statusText = 'User must be logged in';
      });
      return;
    }

    // Guest gate: check before doing any work.
    if (_isGuest && _guestSearchCount >= widget.guestSearchLimit) {
      _navigateToIntro();
      return;
    }

    try {
      final picked = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 96,
        maxWidth: 2200,
        maxHeight: 2200,
      );
      if (picked == null) return;

      final rawBytes = await picked.readAsBytes();
      final normalizedBytes = await _normalizeUpload(rawBytes);

      if (!mounted) return;
      setState(() {
        _selectedImageBytes = normalizedBytes;
        _busy = true;
        _hasSearched = false;
        _bestGuess = '';
        _statusText = 'Uploading image...';
      });

      await _writeRuntimeState(
        status: 'Uploading image...',
        busy: true,
        lastError: '',
        clearResult: true,
      );

      final storagePath = await _uploadToFirebaseStorage(normalizedBytes);
      _lastStoragePath = storagePath;

      await _writeRuntimeState(
        status: 'Searching similar products...',
        busy: true,
        storagePath: storagePath,
        lastError: '',
      );

      if (!mounted) return;
      setState(() {
        _statusText = 'Searching similar products...';
      });

      final result = await _callSearchFunction(storagePath);
      final allItems = _extractAllItems(result);

      if (widget.storeHistoryToFirestore) {
        await _saveHistory(storagePath, result, allItems);
      }

      // Count this as a used guest search.
      if (_isGuest) {
        await _incrementGuestSearchCount();
        if (mounted) {
          setState(() {
            _guestSearchCount += 1;
          });
        }
      }

      await _writeRuntimeState(
        status: allItems.isEmpty
            ? 'No matching products found'
            : 'Opening results...',
        busy: false,
        storagePath: storagePath,
        bestGuess: (result['bestGuess'] ?? '').toString(),
        resultJson: result,
        resultCount: allItems.length,
        lastError: '',
      );

      await _deleteUploadedImage(storagePath);

      if (!mounted) return;
      setState(() {
        _busy = false;
        _hasSearched = true;
        _bestGuess = (result['bestGuess'] ?? '').toString();
        _statusText = allItems.isEmpty
            ? 'No matching products found'
            : 'Results ready — opening history';
      });

      if (allItems.isNotEmpty) {
        // Navigate guests who just hit the limit straight to intro,
        // otherwise navigate to history.
        if (_isGuest && _guestSearchCount >= widget.guestSearchLimit) {
          _navigateToIntro();
        } else {
          _navigateToHistory();
        }
      } else if (_isGuest && _guestSearchCount >= widget.guestSearchLimit) {
        // Even if this search returned nothing, if the guest is now out
        // of free searches, send them to intro so the next tap doesn't
        // silently fail.
        _navigateToIntro();
      }
    } catch (e) {
      if (_lastStoragePath.isNotEmpty) {
        await _deleteUploadedImage(_lastStoragePath);
      }

      await _writeRuntimeState(
        status: 'Search failed',
        busy: false,
        lastError: e.toString(),
      );

      if (!mounted) return;
      setState(() {
        _busy = false;
        _hasSearched = true;
        _statusText = 'Search failed';
      });
    } finally {
      _lastStoragePath = '';
    }
  }

  void _navigateToHistory() {
    if (!mounted) return;
    final routeName = widget.historyRouteName?.trim() ?? '';
    if (routeName.isEmpty) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      // FlutterFlow registers pages with GoRouter using their page name.
      try {
        context.pushNamed(routeName);
        return;
      } catch (_) {}

      try {
        context.push(routeName);
        return;
      } catch (_) {}

      try {
        Navigator.of(context).pushNamed(routeName);
      } catch (_) {
        try {
          Navigator.of(context).pushReplacementNamed(routeName);
        } catch (_) {}
      }
    });
  }

  Future<Uint8List> _normalizeUpload(Uint8List bytes) async {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return bytes;

    img.Image output = decoded;
    const maxEdge = 1800;
    if (decoded.width > maxEdge || decoded.height > maxEdge) {
      output = img.copyResize(
        decoded,
        width: decoded.width >= decoded.height ? maxEdge : null,
        height: decoded.height > decoded.width ? maxEdge : null,
        interpolation: img.Interpolation.average,
      );
    }

    return Uint8List.fromList(img.encodeJpg(output, quality: 90));
  }

  Future<String> _uploadToFirebaseStorage(Uint8List bytes) async {
    final user = _user;
    if (user == null) {
      throw Exception('User must be logged in.');
    }

    final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
    final path = 'visual-search/${user.uid}/$fileName';

    final ref = FirebaseStorage.instance.ref().child(path);
    await ref.putData(
      bytes,
      SettableMetadata(contentType: 'image/jpeg'),
    );

    return path;
  }

  Future<void> _deleteUploadedImage(String storagePath) async {
    if (storagePath.trim().isEmpty) return;
    try {
      await FirebaseStorage.instance.ref().child(storagePath).delete();
    } catch (_) {}
  }

  Future<Map<String, dynamic>> _callSearchFunction(String storagePath) async {
    final callable =
        FirebaseFunctions.instanceFor(region: 'us-central1').httpsCallable(
      'searchVisualProducts',
      options: HttpsCallableOptions(
        timeout: const Duration(seconds: 150),
      ),
    );

    try {
      final response = await callable.call({
        'storagePath': storagePath,
        'limit': widget.searchLimit,
      });

      final data = response.data;
      if (data is Map<String, dynamic>) return data;
      if (data is Map) return Map<String, dynamic>.from(data);
      throw Exception('Invalid Cloud Function response.');
    } on FirebaseFunctionsException catch (e) {
      final code = e.code.toLowerCase();
      final message = (e.message ?? '').trim();
      if (code == 'deadline-exceeded' ||
          message.toLowerCase().contains('timed out')) {
        throw Exception('Image search took longer than expected. Try again.');
      }
      throw Exception(message.isNotEmpty
          ? message
          : 'Cloud Function request failed (${e.code}).');
    } on TimeoutException {
      throw Exception('Image search request timed out. Try again.');
    }
  }

  Future<void> _saveHistory(
    String storagePath,
    Map<String, dynamic> result,
    List<Map<String, dynamic>> items,
  ) async {
    final user = _user;
    if (user == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('visual_searches')
          .add({
        'storagePath': storagePath,
        'bestGuess': (result['bestGuess'] ?? '').toString(),
        'items': items,
        'resultCount': items.length,
        'createdAt': FieldValue.serverTimestamp(),
        'provider': 'searchVisualProducts',
      });
    } catch (_) {}
  }

  Future<void> _writeRuntimeState({
    String? status,
    bool? busy,
    String? lastError,
    String? storagePath,
    String? bestGuess,
    Map<String, dynamic>? resultJson,
    int? resultCount,
    bool clearResult = false,
  }) async {
    final doc = _runtimeDoc;
    if (doc == null) return;

    final data = <String, dynamic>{
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (status != null) data['status'] = status;
    if (busy != null) data['busy'] = busy;
    if (lastError != null) data['lastError'] = lastError;
    if (storagePath != null) data['storagePath'] = storagePath;
    if (bestGuess != null) data['bestGuess'] = bestGuess;
    if (resultCount != null) data['resultCount'] = resultCount;
    if (resultJson != null) {
      data['resultJson'] = resultJson;
      data['resultJsonString'] = jsonEncode(resultJson);
    }

    if (clearResult) {
      data['resultJson'] = FieldValue.delete();
      data['resultJsonString'] = FieldValue.delete();
      data['bestGuess'] = FieldValue.delete();
      data['resultCount'] = FieldValue.delete();
    }

    await doc.set(data, SetOptions(merge: true));
  }

  List<Map<String, dynamic>> _extractAllItems(Map<String, dynamic> result) {
    final rawItems = result['items'];
    if (rawItems is! List) return <Map<String, dynamic>>[];

    return rawItems
        .map<Map<String, dynamic>>((raw) {
          final map = raw is Map<String, dynamic>
              ? raw
              : raw is Map
                  ? Map<String, dynamic>.from(raw)
                  : <String, dynamic>{};

          final imageCandidates = _pickImageCandidates(map);
          final primaryImage =
              imageCandidates.isNotEmpty ? imageCandidates.first : '';
          final title = (map['title'] ?? result['bestGuess'] ?? '').toString();
          final storeLogo =
              (map['storeLogo'] ?? map['sourceIcon'] ?? '').toString();
          final store = (map['store'] ?? map['source'] ?? '').toString();
          final affiliateUrl =
              (map['affiliateUrl'] ?? map['buyUrl'] ?? map['url'] ?? '')
                  .toString();
          final originalUrl = (map['originalUrl'] ??
                  map['destinationUrl'] ??
                  map['url'] ??
                  affiliateUrl)
              .toString();
          final price = (map['price'] ?? map['priceValue'] ?? '').toString();

          return {
            ...map,
            'title': title,
            'image': primaryImage,
            'thumbnail': primaryImage,
            'imageCandidates': imageCandidates,
            'storeLogo': storeLogo,
            'store': store,
            'affiliateUrl': affiliateUrl,
            'originalUrl': originalUrl,
            'price': price,
          };
        })
        .where(_hasRenderableImage)
        .toList();
  }

  List<String> _pickImageCandidates(Map<String, dynamic> map) {
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
      map['product'],
      map['offer'],
      map['offers'],
      map['shoppingResult'],
      map['shoppingResults'],
    ];

    final seen = <String>{};
    final output = <String>[];

    for (final candidate in candidates) {
      final extracted = _extractImageStrings(candidate);
      for (final url in extracted) {
        if (url.isEmpty) continue;
        if (seen.add(url)) output.add(url);
      }
    }

    return output;
  }

  List<String> _extractImageStrings(dynamic value) {
    if (value == null) return const [];

    if (value is String) {
      final normalized = _normalizeImageUrl(value);
      return normalized.isEmpty ? const [] : [normalized];
    }

    if (value is List) {
      final results = <String>[];
      for (final entry in value) {
        results.addAll(_extractImageStrings(entry));
      }
      return results;
    }

    if (value is Map) {
      final map = Map<String, dynamic>.from(value);
      final nestedCandidates = <dynamic>[
        map['url'],
        map['src'],
        map['image'],
        map['imageUrl'],
        map['thumbnail'],
        map['thumbnailUrl'],
        map['link'],
        map['href'],
        map['secure_url'],
        map['secureUrl'],
        map['original'],
        map['large'],
        map['medium'],
        map['small'],
        map['image_link'],
        map['imageLink'],
        map['previewImage'],
        map['previewImageUrl'],
        map['primaryImage'],
        map['primaryImageUrl'],
        map['productImage'],
        map['productImageUrl'],
        map['images'],
        map['thumbnails'],
        map['media'],
        map['gallery'],
        map['product'],
        map['offer'],
        map['offers'],
        map['shoppingResult'],
        map['shoppingResults'],
      ];

      final results = <String>[];
      for (final entry in nestedCandidates) {
        results.addAll(_extractImageStrings(entry));
      }
      return results;
    }

    final normalized = _normalizeImageUrl(value.toString());
    return normalized.isEmpty ? const [] : [normalized];
  }

  String _normalizeImageUrl(dynamic value) {
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

  bool _hasRenderableImage(Map<String, dynamic> item) {
    final candidates = item['imageCandidates'];
    if (candidates is List) {
      for (final candidate in candidates) {
        final image = _normalizeImageUrl(candidate);
        if (image.isEmpty) continue;
        if (image.startsWith('data:image/')) return true;
        final uri = Uri.tryParse(image);
        if (uri == null) continue;
        final scheme = uri.scheme.toLowerCase();
        if (scheme == 'http' || scheme == 'https') return true;
      }
    }

    final image = _normalizeImageUrl(item['image']);
    if (image.isEmpty) return false;
    if (image.startsWith('data:image/')) return true;

    final uri = Uri.tryParse(image);
    if (uri == null) return false;
    final scheme = uri.scheme.toLowerCase();
    return scheme == 'http' || scheme == 'https';
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final width = widget.width ?? media.size.width;
    final height = widget.height ?? media.size.height;
    final isPortrait = media.orientation == Orientation.portrait;

    return SizedBox(
      width: width,
      height: height,
      child: ClipRect(
        child: Stack(
          fit: StackFit.expand,
          children: [
            Container(
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
              child: _blurOrb(size: 210, color: const Color(0xAA904DFF)),
            ),
            Positioned(
              right: -50,
              top: height * 0.14,
              child: _blurOrb(size: 180, color: const Color(0x8848B6FF)),
            ),
            Positioned(
              bottom: -70,
              left: 40,
              child: _blurOrb(size: 220, color: const Color(0x66857BFF)),
            ),
            Positioned.fill(
              child: Padding(
                padding: EdgeInsets.only(
                  top: isPortrait
                      ? media.padding.top + 8
                      : math.max(10, media.padding.top * 0.45),
                  bottom: isPortrait
                      ? media.padding.bottom + 8
                      : math.max(8, media.padding.bottom),
                ),
                child: _user == null
                    ? _buildNotLoggedIn(context)
                    : _buildContent(context, isPortrait),
              ),
            ),
            if (_busy) _buildBusyOverlay(context),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, bool isPortrait) {
    return Column(
      children: [
        if (widget.showHeader) _buildHeroHeader(context),
        Expanded(
          child: ListView(
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.fromLTRB(
              isPortrait ? 14 : 18,
              0,
              isPortrait ? 14 : 18,
              widget.bottomScrollSpace,
            ),
            children: [
              if (widget.showNotice) _buildExpiryNotice(context),
              if (_isGuest && _guestLimitChecked) _buildGuestCounter(context),
              _buildUploadPanel(context, isPortrait),
              const SizedBox(height: 14),
              if (_selectedImageBytes != null)
                _buildPreviewCard(context, isPortrait),
              if (_selectedImageBytes != null) const SizedBox(height: 14),
              _buildStatusCard(context),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGuestCounter(BuildContext context) {
    final remaining =
        (widget.guestSearchLimit - _guestSearchCount).clamp(0, 999);
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
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
                color: const Color(0xFFFFD400).withOpacity(0.18),
                border: Border.all(color: Colors.white.withOpacity(0.12)),
              ),
              child: const Icon(
                Icons.bolt_rounded,
                color: Color(0xFFFFE680),
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                remaining > 0
                    ? 'Guest mode: $remaining of ${widget.guestSearchLimit} free image searches remaining. Sign up to keep searching.'
                    : 'Guest searches used up. Sign up to continue searching.',
                style: FlutterFlowTheme.of(context).bodyMedium.override(
                      fontFamily: FlutterFlowTheme.of(context).bodyMediumFamily,
                      color: Colors.white.withOpacity(0.92),
                      fontSize: 12.8,
                      fontWeight: FontWeight.w700,
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
                Icons.image_search_rounded,
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
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          useGoogleFonts:
                              !FlutterFlowTheme.of(context).titleLargeIsCustom,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.heroSubtitle,
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
      padding: const EdgeInsets.only(bottom: 14),
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
                Icons.auto_delete_rounded,
                color: Color(0xFFD8C8FF),
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Your uploaded image is used for the search, then deleted right after the results return. Results open in the history page.',
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

  Widget _buildUploadPanel(BuildContext context, bool isPortrait) {
    final guestExhausted =
        _isGuest && _guestSearchCount >= widget.guestSearchLimit;
    final disabled = _busy || guestExhausted;

    return _glassPanel(
      borderRadius: 28,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withOpacity(0.10)),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withOpacity(0.11),
                  Colors.white.withOpacity(0.04),
                ],
              ),
            ),
            padding: const EdgeInsets.all(18),
            child: Column(
              children: [
                Container(
                  width: 66,
                  height: 66,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFF9F6BFF).withOpacity(0.98),
                        const Color(0xFF63C7FF).withOpacity(0.92),
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF8B5CFF).withOpacity(0.28),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.add_photo_alternate_rounded,
                    color: Colors.white,
                    size: 30,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Upload one product photo',
                  textAlign: TextAlign.center,
                  style: FlutterFlowTheme.of(context).titleMedium.override(
                        fontFamily:
                            FlutterFlowTheme.of(context).titleMediumFamily,
                        color: Colors.white,
                        fontSize: isPortrait ? 18 : 19,
                        fontWeight: FontWeight.w800,
                        useGoogleFonts:
                            !FlutterFlowTheme.of(context).titleMediumIsCustom,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  guestExhausted
                      ? 'You\'ve used all your free guest searches. Sign up to keep searching.'
                      : 'Use a clear photo of the item. Results open in the history page automatically when ready.',
                  textAlign: TextAlign.center,
                  style: FlutterFlowTheme.of(context).bodyMedium.override(
                        fontFamily:
                            FlutterFlowTheme.of(context).bodyMediumFamily,
                        color: Colors.white.withOpacity(0.74),
                        fontSize: 12.8,
                        fontWeight: FontWeight.w500,
                        useGoogleFonts:
                            !FlutterFlowTheme.of(context).bodyMediumIsCustom,
                      ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      gradient: LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: guestExhausted
                            ? const [
                                Color(0xFF6B5070),
                                Color(0xFF55416C),
                                Color(0xFF3D5577),
                              ]
                            : const [
                                Color(0xFF9F69FF),
                                Color(0xFF6B86FF),
                                Color(0xFF53C7FF),
                              ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF855DFF).withOpacity(0.28),
                          blurRadius: 16,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(18),
                        onTap: disabled
                            ? (guestExhausted ? _navigateToIntro : null)
                            : _pickImageAndSearch,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 15,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                _busy
                                    ? Icons.hourglass_top_rounded
                                    : guestExhausted
                                        ? Icons.lock_open_rounded
                                        : Icons.upload_rounded,
                                color: Colors.white,
                                size: 19,
                              ),
                              const SizedBox(width: 10),
                              Text(
                                _busy
                                    ? 'Searching...'
                                    : guestExhausted
                                        ? 'Sign up to continue'
                                        : 'Upload image',
                                style: FlutterFlowTheme.of(context)
                                    .bodyMedium
                                    .override(
                                      fontFamily: FlutterFlowTheme.of(context)
                                          .bodyMediumFamily,
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                      useGoogleFonts:
                                          !FlutterFlowTheme.of(context)
                                              .bodyMediumIsCustom,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewCard(BuildContext context, bool isPortrait) {
    return _glassPanel(
      borderRadius: 28,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Uploaded image',
            style: FlutterFlowTheme.of(context).titleMedium.override(
                  fontFamily: FlutterFlowTheme.of(context).titleMediumFamily,
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  useGoogleFonts:
                      !FlutterFlowTheme.of(context).titleMediumIsCustom,
                ),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: Container(
              constraints: BoxConstraints(
                minHeight: isPortrait ? 200 : 170,
                maxHeight: isPortrait ? 330 : 240,
              ),
              width: double.infinity,
              color: Colors.white.withOpacity(0.90),
              child: _selectedImageBytes == null
                  ? const SizedBox.shrink()
                  : Image.memory(
                      _selectedImageBytes!,
                      fit: BoxFit.contain,
                      gaplessPlayback: true,
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard(BuildContext context) {
    return _glassPanel(
      borderRadius: 24,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: const Color(0xFF6E4BFF).withOpacity(0.18),
              border: Border.all(color: Colors.white.withOpacity(0.12)),
            ),
            child: Icon(
              _busy
                  ? Icons.search_rounded
                  : _hasSearched
                      ? Icons.check_circle_outline_rounded
                      : Icons.auto_awesome_rounded,
              color: const Color(0xFFD8C8FF),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _bestGuess.isEmpty ? _statusText : _bestGuess,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: FlutterFlowTheme.of(context).bodyMedium.override(
                        fontFamily:
                            FlutterFlowTheme.of(context).bodyMediumFamily,
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        useGoogleFonts:
                            !FlutterFlowTheme.of(context).bodyMediumIsCustom,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  _bestGuess.isEmpty ? 'Ready for your image.' : _statusText,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: FlutterFlowTheme.of(context).bodySmall.override(
                        fontFamily:
                            FlutterFlowTheme.of(context).bodySmallFamily,
                        color: Colors.white.withOpacity(0.72),
                        fontSize: 11.8,
                        fontWeight: FontWeight.w600,
                        useGoogleFonts:
                            !FlutterFlowTheme.of(context).bodySmallIsCustom,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotLoggedIn(BuildContext context) {
    return Center(
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
    );
  }

  Widget _buildBusyOverlay(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: Container(
          color: Colors.black.withOpacity(0.16),
          alignment: Alignment.center,
          child: _glassPanel(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
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
                  'Searching...',
                  style: FlutterFlowTheme.of(context).bodyMedium.override(
                        fontFamily:
                            FlutterFlowTheme.of(context).bodyMediumFamily,
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        useGoogleFonts:
                            !FlutterFlowTheme.of(context).bodyMediumIsCustom,
                      ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
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

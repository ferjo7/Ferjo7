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
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:go_router/go_router.dart';
import 'package:image/image.dart' as img;

class VisualSearchCameraView extends StatefulWidget {
  const VisualSearchCameraView({
    Key? key,
    this.width,
    this.height,
    this.captureNonce = 0,
    this.guideBoxWidthFactor = 0.28,
    this.guideBoxHeightFactor = 0.28,
    this.cropPaddingFactor = 0.18,
    this.searchLimit = 20,
    this.showGuideOverlay = true,
    this.showDebugText = false,
    this.storeHistoryToFirestore = true,
    // FlutterFlow route/path for the history page. Examples:
    //   "VisualSearchHistoryPage"  (FlutterFlow page name)
    //   "/visual-search-history"   (FlutterFlow URL path)
    // Leave null to skip auto-navigation; the host page should watch
    // visual_search_runtime/current.resultCount and navigate itself.
    this.historyRouteName,
    // Route to send anonymous (guest) users to once they've used their
    // free guest searches up. Defaults to "introPage".
    this.introRouteName = 'introPage',
    // How many free visual (camera) searches a guest user gets.
    this.guestSearchLimit = 2,
  }) : super(key: key);

  final double? width;
  final double? height;
  final int captureNonce;
  final double guideBoxWidthFactor;
  final double guideBoxHeightFactor;
  final double cropPaddingFactor;
  final int searchLimit;
  final bool showGuideOverlay;
  final bool showDebugText;
  final bool storeHistoryToFirestore;
  final String? historyRouteName;
  final String introRouteName;
  final int guestSearchLimit;

  @override
  State<VisualSearchCameraView> createState() => _VisualSearchCameraViewState();
}

class _VisualSearchCameraViewState extends State<VisualSearchCameraView>
    with WidgetsBindingObserver {
  CameraController? _cameraController;

  bool _initializing = true;
  bool _disposed = false;
  bool _captureInProgress = false;
  bool _initInProgress = false;

  int _lastHandledCaptureNonce = -1;

  String _statusText = 'Point camera at a product';

  double _minZoomLevel = 1.0;
  double _maxZoomLevel = 1.0;
  double _currentZoomLevel = 1.0;

  Orientation? _lastOrientation;
  Timer? _orientationDebounce;

  // Guest tracking
  int _guestSearchCount = 0;
  bool _guestLimitChecked = false;

  bool get _isGuest => FirebaseAuth.instance.currentUser?.isAnonymous == true;

  DocumentReference<Map<String, dynamic>>? get _runtimeDoc {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;
    return FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('visual_search_runtime')
        .doc('current');
  }

  DocumentReference<Map<String, dynamic>>? get _guestUsageDoc {
    final user = FirebaseAuth.instance.currentUser;
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
    WidgetsBinding.instance.addObserver(this);
    _lastHandledCaptureNonce = widget.captureNonce;

    unawaited(_writeRuntimeState(
      status: _statusText,
      busy: false,
      lastError: '',
      clearResult: false,
    ));
    unawaited(_loadGuestSearchCount());
    unawaited(_initEverything());
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
      final count = (data['visualSearchCount'] as num?)?.toInt() ?? 0;

      if (!mounted) return;
      setState(() {
        _guestSearchCount = count;
        _guestLimitChecked = true;
      });

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
        'visualSearchCount': FieldValue.increment(1),
        'lastVisualSearchAt': FieldValue.serverTimestamp(),
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

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final orientation = MediaQuery.orientationOf(context);

    if (_lastOrientation == null) {
      _lastOrientation = orientation;
      return;
    }

    if (_lastOrientation != orientation) {
      _lastOrientation = orientation;
      _orientationDebounce?.cancel();
      _orientationDebounce = Timer(const Duration(milliseconds: 260), () {
        if (_disposed || _captureInProgress || _initInProgress) return;
        unawaited(_initEverything());
      });
    }
  }

  @override
  void didUpdateWidget(covariant VisualSearchCameraView oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.captureNonce != oldWidget.captureNonce &&
        widget.captureNonce != _lastHandledCaptureNonce) {
      _lastHandledCaptureNonce = widget.captureNonce;
      unawaited(_captureUploadAndSearch());
    }
  }

  @override
  void dispose() {
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
    _orientationDebounce?.cancel();

    final controller = _cameraController;
    _cameraController = null;

    unawaited(() async {
      try {
        await controller?.dispose();
      } catch (_) {}
    }());

    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_disposed) return;

    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      final controller = _cameraController;
      _cameraController = null;

      unawaited(() async {
        try {
          await controller?.dispose();
        } catch (_) {}
      }());
      return;
    }

    if (state == AppLifecycleState.resumed) {
      unawaited(_initEverything());
    }
  }

  Future<void> _initEverything() async {
    if (_disposed || _initInProgress) return;
    _initInProgress = true;

    try {
      if (mounted) {
        setState(() {
          _initializing = true;
        });
      }

      final oldController = _cameraController;
      _cameraController = null;
      if (oldController != null) {
        try {
          await oldController.dispose();
        } catch (_) {}
      }

      await _initCamera();

      _statusText = 'Tap capture to search';

      await _writeRuntimeState(
        status: _statusText,
        busy: false,
        lastError: '',
      );

      if (!_disposed && mounted) {
        setState(() {
          _initializing = false;
        });
      }
    } catch (e) {
      await _writeRuntimeState(
        status: 'Camera failed to start',
        busy: false,
        lastError: e.toString(),
      );

      if (!_disposed && mounted) {
        setState(() {
          _initializing = false;
        });
      }
    } finally {
      _initInProgress = false;
    }
  }

  Future<void> _initCamera() async {
    final cameras = await availableCameras();

    CameraDescription? backCamera;
    for (final c in cameras) {
      if (c.lensDirection == CameraLensDirection.back) {
        backCamera = c;
        break;
      }
    }
    backCamera ??= cameras.isNotEmpty ? cameras.first : null;

    if (backCamera == null) {
      throw Exception('No back camera found.');
    }

    final controller = CameraController(
      backCamera,
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup:
          Platform.isIOS ? ImageFormatGroup.bgra8888 : ImageFormatGroup.yuv420,
    );

    await controller.initialize();
    await controller.setFlashMode(FlashMode.off);

    try {
      await controller.setFocusMode(FocusMode.auto);
    } catch (_) {}

    try {
      await controller.setExposureMode(ExposureMode.auto);
    } catch (_) {}

    try {
      _minZoomLevel = await controller.getMinZoomLevel();
      _maxZoomLevel = await controller.getMaxZoomLevel();
    } catch (_) {
      _minZoomLevel = 1.0;
      _maxZoomLevel = 1.0;
    }

    if (_minZoomLevel.isNaN || _minZoomLevel.isInfinite || _minZoomLevel <= 0) {
      _minZoomLevel = 1.0;
    }
    if (_maxZoomLevel.isNaN ||
        _maxZoomLevel.isInfinite ||
        _maxZoomLevel < _minZoomLevel) {
      _maxZoomLevel = _minZoomLevel;
    }

    _currentZoomLevel = _currentZoomLevel.clamp(_minZoomLevel, _maxZoomLevel);

    try {
      await controller.setZoomLevel(_currentZoomLevel);
    } catch (_) {}

    _cameraController = controller;
  }

  Rect _guideRectNorm(BuildContext context) {
    final orientation = MediaQuery.orientationOf(context);

    final double w = orientation == Orientation.portrait
        ? widget.guideBoxWidthFactor.clamp(0.16, 0.85)
        : widget.guideBoxWidthFactor.clamp(0.16, 0.85) * 0.88;
    final double h = orientation == Orientation.portrait
        ? widget.guideBoxHeightFactor.clamp(0.16, 0.85)
        : widget.guideBoxHeightFactor.clamp(0.16, 0.85) * 0.88;

    final left = (1.0 - w) / 2.0;
    final top = orientation == Orientation.portrait
        ? 0.44 - (h / 2.0)
        : 0.42 - (h / 2.0);

    return Rect.fromLTWH(left, top.clamp(0.10, 0.70), w, h);
  }

  Future<void> _captureUploadAndSearch() async {
    final controller = _cameraController;
    if (controller == null || !controller.value.isInitialized) return;
    if (_captureInProgress) return;

    // Guest gate: if already at the limit, redirect immediately.
    if (_isGuest && _guestSearchCount >= widget.guestSearchLimit) {
      _navigateToIntro();
      return;
    }

    _captureInProgress = true;

    if (mounted) {
      setState(() {
        _statusText = 'Capturing image...';
      });
    }

    await _writeRuntimeState(
      status: 'Capturing image...',
      busy: true,
      lastError: '',
    );

    try {
      final picture = await controller.takePicture();
      final rawBytes = await File(picture.path).readAsBytes();

      if (mounted) {
        setState(() {
          _statusText = 'Cropping image...';
        });
      }

      final croppedJpg = await _cropCapturedImage(rawBytes);
      final storagePath = await _uploadToFirebaseStorage(croppedJpg);

      await _writeRuntimeState(
        status: 'Image uploaded',
        busy: true,
        storagePath: storagePath,
      );

      if (mounted) {
        setState(() {
          _statusText = 'Searching similar products...';
        });
      }

      final result = await _callSearchFunction(storagePath);

      List<Map<String, dynamic>> allItems = const [];
      try {
        allItems = _extractAllItems(result);
      } catch (_) {
        allItems = const [];
      }

      if (widget.storeHistoryToFirestore) {
        try {
          await _saveHistory(storagePath, result, allItems);
        } catch (_) {}
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

      try {
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
      } catch (_) {}

      if (!mounted) return;
      setState(() {
        _statusText = allItems.isEmpty
            ? 'No matching products found'
            : 'Tap capture to search';
      });

      if (allItems.isNotEmpty) {
        // If guest just exhausted their limit, send to intro.
        // Otherwise, send to history.
        if (_isGuest && _guestSearchCount >= widget.guestSearchLimit) {
          _navigateToIntro();
        } else {
          _navigateToHistory();
        }
      } else if (_isGuest && _guestSearchCount >= widget.guestSearchLimit) {
        _navigateToIntro();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _statusText = 'Scan failed';
        });
      }

      await _writeRuntimeState(
        status: 'Scan failed',
        busy: false,
        lastError: e.toString(),
      );
    } finally {
      _captureInProgress = false;
      if (!_disposed && mounted) {
        setState(() {});
      }
    }
  }

  void _navigateToHistory() {
    if (!mounted) return;

    final routeName = widget.historyRouteName?.trim() ?? '';
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

  List<Map<String, dynamic>> _extractAllItems(Map<String, dynamic> result) {
    final rawItems = result['items'];
    if (rawItems is! List) return <Map<String, dynamic>>[];

    return rawItems.map<Map<String, dynamic>>((raw) {
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
          (map['affiliateUrl'] ?? map['buyUrl'] ?? map['url'] ?? '').toString();
      final originalUrl =
          (map['originalUrl'] ?? map['destinationUrl'] ?? map['url'] ?? '')
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
    }).where((item) {
      return _hasRenderableImage(item);
    }).toList();
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
        if (seen.add(url)) {
          output.add(url);
        }
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

  Future<Uint8List> _cropCapturedImage(Uint8List bytes) async {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return bytes;

    final guideRect = _guideRectNorm(context);
    Rect cropNorm = Rect.fromLTRB(
      (guideRect.left - widget.cropPaddingFactor * 0.5).clamp(0.0, 1.0),
      (guideRect.top - widget.cropPaddingFactor * 0.5).clamp(0.0, 1.0),
      (guideRect.right + widget.cropPaddingFactor * 0.5).clamp(0.0, 1.0),
      (guideRect.bottom + widget.cropPaddingFactor * 0.5).clamp(0.0, 1.0),
    );

    final x =
        (cropNorm.left * decoded.width).round().clamp(0, decoded.width - 1);
    final y =
        (cropNorm.top * decoded.height).round().clamp(0, decoded.height - 1);
    final w =
        (cropNorm.width * decoded.width).round().clamp(1, decoded.width - x);
    final h =
        (cropNorm.height * decoded.height).round().clamp(1, decoded.height - y);

    final cropped = img.copyCrop(
      decoded,
      x: x,
      y: y,
      width: w,
      height: h,
    );

    return Uint8List.fromList(img.encodeJpg(cropped, quality: 88));
  }

  Future<String> _uploadToFirebaseStorage(Uint8List bytes) async {
    final user = FirebaseAuth.instance.currentUser;
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

  Future<Map<String, dynamic>> _callSearchFunction(String storagePath) async {
    final callable =
        FirebaseFunctions.instanceFor(region: 'us-central1').httpsCallable(
      'searchVisualProducts',
      options: HttpsCallableOptions(
        timeout: const Duration(seconds: 180),
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
        throw Exception('Visual search took longer than expected. Try again.');
      }
      throw Exception(message.isNotEmpty
          ? message
          : 'Cloud Function request failed (${e.code}).');
    } on TimeoutException {
      throw Exception('Visual search request timed out. Try again.');
    }
  }

  Future<void> _saveHistory(
    String storagePath,
    Map<String, dynamic> result,
    List<Map<String, dynamic>> items,
  ) async {
    final user = FirebaseAuth.instance.currentUser;
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

  Future<void> _setZoomLevel(double value) async {
    final controller = _cameraController;
    if (controller == null || !controller.value.isInitialized) return;

    final target = value.clamp(_minZoomLevel, _maxZoomLevel).toDouble();
    try {
      await controller.setZoomLevel(target);
      if (!mounted) return;
      setState(() {
        _currentZoomLevel = target;
      });
    } catch (_) {}
  }

  Future<void> _stepZoom(double delta) async {
    await _setZoomLevel(_currentZoomLevel + delta);
  }

  Widget _buildZoomControls({
    required double safeTop,
    required double safeRight,
  }) {
    if (_maxZoomLevel <= _minZoomLevel + 0.01) {
      return const SizedBox.shrink();
    }

    return Positioned(
      right: 18 + safeRight,
      top: 18 + safeTop,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.34),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.white.withOpacity(0.12)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildZoomButton(
              icon: Icons.add_rounded,
              onTap: () => _stepZoom(0.5),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                '${_currentZoomLevel.toStringAsFixed(1)}x',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            _buildZoomButton(
              icon: Icons.remove_rounded,
              onTap: () => _stepZoom(-0.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildZoomButton(
      {required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.14),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withOpacity(0.14)),
        ),
        child: Icon(icon, color: Colors.white, size: 22),
      ),
    );
  }

  Widget _buildGuestBanner({required double safeTop}) {
    if (!_isGuest || !_guestLimitChecked) {
      return const SizedBox.shrink();
    }
    final remaining =
        (widget.guestSearchLimit - _guestSearchCount).clamp(0, 999);

    return Positioned(
      top: 12 + safeTop,
      left: 18,
      right: 76, // leave room for zoom controls
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.42),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFFFD400).withOpacity(0.45)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.bolt_rounded, color: Color(0xFFFFE680), size: 16),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                remaining > 0
                    ? 'Guest: $remaining of ${widget.guestSearchLimit} free scans left'
                    : 'Guest scans used. Sign up to continue',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = widget.width ?? MediaQuery.of(context).size.width;
    final height = widget.height ?? MediaQuery.of(context).size.height;
    final safeBottom = MediaQuery.of(context).padding.bottom;
    final safeRight = MediaQuery.of(context).padding.right;
    final safeTop = MediaQuery.of(context).padding.top;

    return SizedBox(
      width: width,
      height: height,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Stack(
          fit: StackFit.expand,
          children: [
            _buildCameraLayer(context),
            _buildTopFade(),
            _buildBottomFade(),
            if (widget.showGuideOverlay)
              IgnorePointer(
                child: CustomPaint(
                  painter: _ScannerGuidePainter(
                    guideRectNorm: _guideRectNorm(context),
                  ),
                ),
              ),
            if (_initializing)
              Container(
                color: Colors.black,
                alignment: Alignment.center,
                child: const CircularProgressIndicator(
                  color: Color(0xFFFFD400),
                  strokeWidth: 2.0,
                ),
              ),
            if (!_initializing) _buildGuestBanner(safeTop: safeTop),
            if (!_initializing)
              _buildCaptureControls(
                safeBottom: safeBottom,
              ),
            if (!_initializing)
              _buildZoomControls(
                safeTop: safeTop,
                safeRight: safeRight,
              ),
            if (widget.showDebugText) _buildDebugBanner(),
          ],
        ),
      ),
    );
  }

  Widget _buildCameraLayer(BuildContext context) {
    final controller = _cameraController;
    if (controller == null || !controller.value.isInitialized) {
      return Container(color: Colors.black);
    }

    final previewSize = controller.value.previewSize;
    if (previewSize == null) {
      return Container(color: Colors.black);
    }

    final orientation = MediaQuery.orientationOf(context);

    final double previewWidth = orientation == Orientation.portrait
        ? previewSize.height
        : previewSize.width;
    final double previewHeight = orientation == Orientation.portrait
        ? previewSize.width
        : previewSize.height;

    return LayoutBuilder(
      builder: (context, constraints) {
        final double screenRatio = constraints.maxWidth / constraints.maxHeight;
        final double previewRatio = previewWidth / previewHeight;

        double scale = previewRatio / screenRatio;
        if (scale < 1) {
          scale = 1 / scale;
        }

        return ClipRect(
          child: Transform.scale(
            scale: scale,
            child: Center(
              child: SizedBox(
                width: constraints.maxWidth,
                height: constraints.maxHeight,
                child: FittedBox(
                  fit: BoxFit.cover,
                  clipBehavior: Clip.hardEdge,
                  child: SizedBox(
                    width: previewWidth,
                    height: previewHeight,
                    child: CameraPreview(controller),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTopFade() {
    return IgnorePointer(
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.center,
            colors: [
              Color(0x80000000),
              Color(0x20000000),
              Color(0x00000000),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomFade() {
    return IgnorePointer(
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Container(
          height: 320,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0x00000000),
                Color(0x1A000000),
                Color(0xAA000000),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDebugBanner() {
    return Positioned(
      left: 12,
      right: 12,
      top: 40,
      child: Container(
        padding: const EdgeInsets.all(8),
        color: Colors.black.withOpacity(0.55),
        child: Text(
          'busy=$_captureInProgress\nguest=$_isGuest count=$_guestSearchCount\n$_statusText',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildCaptureControls({required double safeBottom}) {
    final guestExhausted =
        _isGuest && _guestSearchCount >= widget.guestSearchLimit;

    return Positioned(
      bottom: 34 + safeBottom,
      left: 0,
      right: 0,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedOpacity(
            duration: const Duration(milliseconds: 280),
            opacity: _captureInProgress ? 1.0 : 0.82,
            child: Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.36),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: Colors.white.withOpacity(0.12),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_captureInProgress)
                    const Padding(
                      padding: EdgeInsets.only(right: 10),
                      child: SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFFFFD400),
                        ),
                      ),
                    ),
                  Flexible(
                    child: Text(
                      guestExhausted
                          ? 'Sign up to continue searching'
                          : _statusText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 260),
            switchInCurve: Curves.easeOut,
            switchOutCurve: Curves.easeIn,
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: ScaleTransition(
                scale: Tween<double>(begin: 0.85, end: 1.0).animate(animation),
                child: child,
              ),
            ),
            child: _captureInProgress
                ? const SizedBox(
                    key: ValueKey('shutter-hidden'),
                    height: 78,
                  )
                : KeyedSubtree(
                    key: const ValueKey('shutter-visible'),
                    child: _buildCaptureShutterButton(
                      size: 78,
                      guestExhausted: guestExhausted,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildCaptureShutterButton({
    required double size,
    required bool guestExhausted,
  }) {
    final double innerPadding = size * 0.10;
    final double borderWidth = size * 0.055;

    return GestureDetector(
      onTap: _captureInProgress
          ? null
          : (guestExhausted ? _navigateToIntro : _captureUploadAndSearch),
      child: AnimatedScale(
        scale: _captureInProgress ? 0.90 : 1.0,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 180),
          opacity: _captureInProgress ? 0.65 : 1.0,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: guestExhausted
                    ? const Color(0xFFFFD400).withOpacity(0.95)
                    : Colors.white.withOpacity(0.92),
                width: borderWidth,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.30),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
                BoxShadow(
                  color: const Color(0xFFFFD400).withOpacity(0.18),
                  blurRadius: 24,
                  spreadRadius: 2,
                ),
              ],
            ),
            padding: EdgeInsets.all(innerPadding),
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: guestExhausted
                    ? const Color(0xFFFFD400)
                    : (_captureInProgress
                        ? Colors.white.withOpacity(0.60)
                        : Colors.white.withOpacity(0.97)),
              ),
              child: guestExhausted
                  ? const Icon(
                      Icons.lock_open_rounded,
                      color: Colors.black,
                      size: 24,
                    )
                  : null,
            ),
          ),
        ),
      ),
    );
  }
}

class _ScannerGuidePainter extends CustomPainter {
  const _ScannerGuidePainter({
    required this.guideRectNorm,
  });

  final Rect guideRectNorm;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(
      (guideRectNorm.left + guideRectNorm.width / 2.0) * size.width,
      (guideRectNorm.top + guideRectNorm.height / 2.0) * size.height,
    );

    final radius = math.min(
      (guideRectNorm.width * size.width) / 2.0,
      (guideRectNorm.height * size.height) / 2.0,
    );

    final glowPaint = Paint()
      ..color = const Color(0x33FFD400)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14.0
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

    final ringPaint = Paint()
      ..color = const Color(0xFFFFD400)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5;

    final fillPaint = Paint()
      ..color = const Color(0x0BFFD400)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(center, radius, fillPaint);
    canvas.drawCircle(center, radius + 2, glowPaint);
    canvas.drawCircle(center, radius, ringPaint);
  }

  @override
  bool shouldRepaint(covariant _ScannerGuidePainter oldDelegate) {
    return oldDelegate.guideRectNorm != guideRectNorm;
  }
}

// Automatic FlutterFlow imports
import '/backend/backend.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'index.dart'; // Imports other custom actions
import 'package:flutter/material.dart';
// Begin custom action code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

Future<dynamic> getVisualSearchItemsJsonList() async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) {
    return <dynamic>[];
  }

  final docRef = FirebaseFirestore.instance
      .collection('users')
      .doc(user.uid)
      .collection('visual_search_runtime')
      .doc('current');

  final snapshot = await docRef.get();

  if (!snapshot.exists) {
    return <dynamic>[];
  }

  final data = snapshot.data() ?? {};

  dynamic rawResult = data['resultJson'];

  if (rawResult == null || rawResult is! Map) {
    final rawString = data['resultJsonString'];
    if (rawString != null && rawString.toString().trim().isNotEmpty) {
      try {
        rawResult = jsonDecode(rawString.toString());
      } catch (_) {
        rawResult = {};
      }
    }
  }

  Map<String, dynamic> resultJson = {};
  if (rawResult is Map) {
    resultJson = Map<String, dynamic>.from(rawResult);
  }

  final rawItems =
      resultJson['items'] is List ? resultJson['items'] as List : <dynamic>[];

  final List<Map<String, dynamic>> items = rawItems.map((item) {
    final map =
        item is Map ? Map<String, dynamic>.from(item) : <String, dynamic>{};

    return {
      'title': (map['title'] ?? '').toString(),
      'productImage': (map['thumbnail'] ?? map['image'] ?? '').toString(),
      'siteLogo': (map['sourceIcon'] ?? '').toString(),
      'siteName': (map['source'] ?? '').toString(),
      'price': (map['priceValue'] ?? '').toString(),
      'buyUrl': (map['affiliateUrl'] ?? '').toString(),
      'originalUrl': (map['originalUrl'] ?? '').toString(),
      'rating': map['rating'],
      'reviews': map['reviews'],
      'inStock': map['inStock'],
      'isAmazon': map['isAmazon'] ?? false,
      'exactMatch': map['exactMatch'] ?? false,
    };
  }).toList();

  return items;
}

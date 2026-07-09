import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import '/custom_code/widgets/index.dart' as custom_widgets;
import 'explore_page_widget.dart' show ExplorePageWidget;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

class ExplorePageModel extends FlutterFlowModel<ExplorePageWidget> {
  ///  Local state fields for this page.

  String? uploadedScanPath;

  dynamic searchResultsJson;

  bool? isSearching;

  String? bestGuess;

  int? captureNonce = 0;

  dynamic visualSearchItems;

  @override
  void initState(BuildContext context) {}

  @override
  void dispose() {}
}

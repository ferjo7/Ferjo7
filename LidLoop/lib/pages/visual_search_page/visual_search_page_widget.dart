import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import '/custom_code/widgets/index.dart' as custom_widgets;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'visual_search_page_model.dart';
export 'visual_search_page_model.dart';

class VisualSearchPageWidget extends StatefulWidget {
  const VisualSearchPageWidget({super.key});

  static String routeName = 'visualSearchPage';
  static String routePath = '/visualSearchPage';

  @override
  State<VisualSearchPageWidget> createState() => _VisualSearchPageWidgetState();
}

class _VisualSearchPageWidgetState extends State<VisualSearchPageWidget> {
  late VisualSearchPageModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => VisualSearchPageModel());
  }

  @override
  void dispose() {
    _model.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
        FocusManager.instance.primaryFocus?.unfocus();
      },
      child: Scaffold(
        key: scaffoldKey,
        backgroundColor: Colors.black,
        body: Container(
          width: double.infinity,
          height: double.infinity,
          child: Stack(
            children: [
              Container(
                width: MediaQuery.sizeOf(context).width * 1.0,
                height: MediaQuery.sizeOf(context).height * 1.0,
                child: custom_widgets.VisualSearchCameraView(
                  width: MediaQuery.sizeOf(context).width * 1.0,
                  height: MediaQuery.sizeOf(context).height * 1.0,
                  captureNonce: _model.captureNonce!,
                  guideBoxWidthFactor: 0.62,
                  guideBoxHeightFactor: 0.62,
                  cropPaddingFactor: 0.18,
                  searchLimit: 20,
                  showGuideOverlay: true,
                  showDebugText: false,
                  storeHistoryToFirestore: true,
                  historyRouteName: 'historyPage',
                  introRouteName: 'introPage',
                  guestSearchLimit: 3,
                ),
              ),
              Align(
                alignment: AlignmentDirectional(0.0, 1.0),
                child: Container(
                  width: MediaQuery.sizeOf(context).width * 1.0,
                  height: 150.0,
                  child: custom_widgets.GlassBottomNavBarWidget(
                    width: MediaQuery.sizeOf(context).width * 1.0,
                    height: 150.0,
                    currentPage: 'visualSearchPage',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

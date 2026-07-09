import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import '/custom_code/widgets/index.dart' as custom_widgets;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'explore_page_model.dart';
export 'explore_page_model.dart';

class ExplorePageWidget extends StatefulWidget {
  const ExplorePageWidget({super.key});

  static String routeName = 'explorePage';
  static String routePath = '/explorePage';

  @override
  State<ExplorePageWidget> createState() => _ExplorePageWidgetState();
}

class _ExplorePageWidgetState extends State<ExplorePageWidget> {
  late ExplorePageModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => ExplorePageModel());
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
                width: double.infinity,
                height: double.infinity,
                child: custom_widgets.ImageSearchPage(
                  width: double.infinity,
                  height: double.infinity,
                  searchLimit: 8,
                  storeHistoryToFirestore: true,
                  showHeader: true,
                  showNotice: true,
                  bottomScrollSpace: 100.0,
                  heroTitle: 'Image Search',
                  heroSubtitle: 'Upload a photo to find matching products.',
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
                    currentPage: 'explorePage',
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

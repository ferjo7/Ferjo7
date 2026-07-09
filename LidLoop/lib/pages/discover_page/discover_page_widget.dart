import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import '/custom_code/widgets/index.dart' as custom_widgets;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'discover_page_model.dart';
export 'discover_page_model.dart';

class DiscoverPageWidget extends StatefulWidget {
  const DiscoverPageWidget({super.key});

  static String routeName = 'discoverPage';
  static String routePath = '/discoverPage';

  @override
  State<DiscoverPageWidget> createState() => _DiscoverPageWidgetState();
}

class _DiscoverPageWidgetState extends State<DiscoverPageWidget> {
  late DiscoverPageModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => DiscoverPageModel());
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
                child: custom_widgets.DiscoverPage(
                  width: double.infinity,
                  height: double.infinity,
                  limit: 18,
                  historyLimit: 10,
                  bottomScrollSpace: 100.0,
                  showHeader: true,
                  showNotice: true,
                  heroTitle: 'Discover',
                  heroSubtitle:
                      'Curated picks inspired by your recent searches.',
                  emptyTitle: 'No recommendations yet',
                  emptySubtitle:
                      'Search products by photo or snapshot and related merch will appear here.',
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
                    currentPage: 'discoverPage',
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

import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import '/custom_code/widgets/index.dart' as custom_widgets;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'history_page_model.dart';
export 'history_page_model.dart';

class HistoryPageWidget extends StatefulWidget {
  const HistoryPageWidget({super.key});

  static String routeName = 'historyPage';
  static String routePath = '/historyPage';

  @override
  State<HistoryPageWidget> createState() => _HistoryPageWidgetState();
}

class _HistoryPageWidgetState extends State<HistoryPageWidget> {
  late HistoryPageModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => HistoryPageModel());
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
        backgroundColor: FlutterFlowTheme.of(context).primaryBackground,
        body: Stack(
          children: [
            Container(
              width: double.infinity,
              height: double.infinity,
              child: custom_widgets.VisualSearchHistoryPage(
                width: double.infinity,
                height: double.infinity,
                maxSearches: 0,
                maxItemsPerSearch: 10,
                showHeader: true,
                showNotice: true,
                emptyTitle: 'No recent visual searches yet',
                emptySubtitle:
                    'Saved results will appear here for up to 6 hours.',
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
                  currentPage: 'historyPage',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

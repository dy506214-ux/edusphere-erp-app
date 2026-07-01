import 'package:flutter/material.dart';
import 'navigation_widgets.dart';

class TeacherScaffold extends StatelessWidget {
  final Widget body;
  final String title;
  final int activeIndex;
  final Widget? floatingActionButton;
  final GlobalKey<ScaffoldState>? scaffoldKey;
  final PreferredSizeWidget? bottom;

  const TeacherScaffold({
    super.key,
    required this.body,
    required this.activeIndex,
    this.title = 'EduSphere',
    this.floatingActionButton,
    this.scaffoldKey,
    this.bottom,
  });

  @override
  Widget build(BuildContext context) {
    return TeacherNavigationScaffold(
      scaffoldKey: scaffoldKey,
      title: title,
      activeIndex: activeIndex,
      bottom: bottom,
      body: body,
      floatingActionButton: floatingActionButton,
    );
  }
}


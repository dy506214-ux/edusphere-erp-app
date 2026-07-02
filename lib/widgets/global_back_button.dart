import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../services/auth_service.dart'; // for appNavigatorKey

final ValueNotifier<bool> globalCanPop = ValueNotifier<bool>(false);

class BackButtonObserver extends NavigatorObserver {
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    _update();
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    _update();
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didRemove(route, previousRoute);
    _update();
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    _update();
  }

  void _update() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final canPop = appNavigatorKey.currentState?.canPop() ?? false;
      globalCanPop.value = canPop;
    });
  }
}

class Global3DBackButtonOverlay extends StatefulWidget {
  final Widget child;
  const Global3DBackButtonOverlay({super.key, required this.child});

  @override
  State<Global3DBackButtonOverlay> createState() => _Global3DBackButtonOverlayState();
}

class _Global3DBackButtonOverlayState extends State<Global3DBackButtonOverlay> {
  Offset? _position;
  bool _canPop = false;

  @override
  void initState() {
    super.initState();
    globalCanPop.addListener(_handleCanPopChanged);
    // Initial check after build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _handleCanPopChanged();
    });
  }

  @override
  void dispose() {
    globalCanPop.removeListener(_handleCanPopChanged);
    super.dispose();
  }

  void _handleCanPopChanged() {
    if (mounted) {
      setState(() {
        _canPop = globalCanPop.value;
      });
    }
  }

  Offset _clampPosition(Offset position, Size screenSize) {
    final double fabSize = 48.w;
    final double minX = 16.w;
    final double maxX = screenSize.width - fabSize - 16.w;
    final double minY = MediaQuery.of(context).padding.top + 16.h;
    final double maxY = screenSize.height - fabSize - MediaQuery.of(context).padding.bottom - 16.h;
    return Offset(
      position.dx.clamp(minX, maxX),
      position.dy.clamp(minY, maxY),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    
    if (_position == null) {
      // Default position: top left, floating just below standard App Bar
      final defaultX = 16.w;
      final defaultY = MediaQuery.of(context).padding.top + 70.h;
      _position = _clampPosition(Offset(defaultX, defaultY), size);
    } else {
      _position = _clampPosition(_position!, size);
    }

    return Stack(
      children: [
        widget.child,
        if (_canPop)
          Positioned(
            left: _position!.dx,
            top: _position!.dy,
            child: GestureDetector(
              onPanUpdate: (details) {
                setState(() {
                  _position = _clampPosition(_position! + details.delta, size);
                });
              },
              child: const ThreeDBackButtonWidget(),
            ),
          ),
      ],
    );
  }
}

class ThreeDBackButtonWidget extends StatelessWidget {
  const ThreeDBackButtonWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48.w,
      height: 48.w,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          colors: [
            Color(0xFF4FA5FF), // Brighter blue at top
            Color(0xFF0052D4), // Deep royal blue at bottom
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        boxShadow: [
          // Raised 3D shadow
          BoxShadow(
            color: Colors.black,
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: Colors.white,
          width: 1.5,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () {
            appNavigatorKey.currentState?.pop();
          },
          child: Center(
            child: Icon(
              Icons.arrow_back_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
        ),
      ),
    );
  }
}

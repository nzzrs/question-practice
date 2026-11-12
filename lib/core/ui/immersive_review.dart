import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Navigator observer that lets [ImmersiveReview] pause while another page
/// covers the review and re-enter immersive mode when the learner returns.
final RouteObserver<PageRoute<dynamic>> reviewRouteObserver =
    RouteObserver<PageRoute<dynamic>>();

/// Keeps a review surface free of the Android system bars while it is open.
///
/// Review pages are reading surfaces: the card owns the whole screen and the
/// learner leaves through the explicit close control or the system back
/// gesture. This host hides the status and navigation bars on mount,
/// re-applies immersive mode whenever the app returns to the foreground or the
/// review becomes visible again, and restores the normal edge-to-edge layout
/// when another page covers it or when the review is disposed.
class ImmersiveReview extends StatefulWidget {
  const ImmersiveReview({required this.child, super.key});

  final Widget child;

  @override
  State<ImmersiveReview> createState() => _ImmersiveReviewState();
}

class _ImmersiveReviewState extends State<ImmersiveReview>
    with WidgetsBindingObserver, RouteAware {
  PageRoute<dynamic>? _route;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _enterImmersiveMode();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute<dynamic> && route != _route) {
      if (_route != null) reviewRouteObserver.unsubscribe(this);
      _route = route;
      reviewRouteObserver.subscribe(this, route);
    }
  }

  @override
  void dispose() {
    reviewRouteObserver.unsubscribe(this);
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_restoreSystemBars());
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _enterImmersiveMode();
  }

  @override
  void didPushNext() {
    unawaited(_restoreSystemBars());
  }

  @override
  void didPopNext() {
    _enterImmersiveMode();
  }

  @override
  void didPop() {}

  @override
  void didPush() {}

  void _enterImmersiveMode() {
    unawaited(
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky),
    );
  }

  Future<void> _restoreSystemBars() {
    return SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

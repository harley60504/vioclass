import 'package:flutter/material.dart';

class TwitchWatchFrameNavigation {
  final VoidCallback onBack;
  final VoidCallback onHome;
  const TwitchWatchFrameNavigation({
    required this.onBack,
    required this.onHome,
  });
}

class TwitchRouteObserver extends RouteObserver<PageRoute<dynamic>> {
  final watchNavigation = ValueNotifier<TwitchWatchFrameNavigation?>(null);
  final _watchRoutes = <Route<dynamic>, TwitchWatchFrameNavigation>{};
  Route<dynamic>? _topRoute;
  void registerWatch(Route<dynamic> route, TwitchWatchFrameNavigation actions) {
    _watchRoutes[route] = actions;
    _publish();
  }

  void unregisterWatch(Route<dynamic> route) {
    _watchRoutes.remove(route);
    _publish();
  }

  void _publish() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      watchNavigation.value = _watchRoutes[_topRoute];
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    _topRoute = route;
    _publish();
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    _topRoute = previousRoute;
    _publish();
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didRemove(route, previousRoute);
    if (identical(_topRoute, route)) {
      _topRoute = previousRoute;
    }
    _publish();
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    if (identical(_topRoute, oldRoute)) {
      _topRoute = newRoute;
    }
    _publish();
  }
}

final twitchRouteObserver = TwitchRouteObserver();

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:go_router/go_router.dart';

/// How a page of the shell navigator enters and leaves.
enum NexusPageTransition {
  /// No animation: section switches from the rail, sidebar or tab bar behave
  /// like tab bars.
  none,

  /// A short opacity fade: pushes on Windows, Linux, macOS and the web. The
  /// default Material zoom snapshots both pages every frame, which is
  /// expensive and janky on the web (CanvasKit) and on desktop.
  fade,

  /// The theme's platform transition (Android's zoom, iOS's slide).
  platform,
}

/// Duration of [NexusPageTransition.fade].
const nexusFadeDuration = Duration(milliseconds: 150);

/// The transition pushes use on [platform] (and on every web build).
NexusPageTransition pushTransitionFor(TargetPlatform platform) {
  if (kIsWeb) {
    return NexusPageTransition.fade;
  }
  return switch (platform) {
    TargetPlatform.windows ||
    TargetPlatform.linux ||
    TargetPlatform.macOS =>
      NexusPageTransition.fade,
    TargetPlatform.android ||
    TargetPlatform.iOS ||
    TargetPlatform.fuchsia =>
      NexusPageTransition.platform,
  };
}

/// Marks the navigation started by [go] as a section switch, so the pages it
/// creates appear without a transition and the pages it pops leave without
/// one.
///
/// The router decides a page's transition when its route is created, which
/// happens in the frame after `go`; the mark therefore lasts until the end
/// of that frame.
class SectionSwitchSignal {
  bool _active = false;

  /// Whether a section switch is being applied right now.
  bool get active => _active;

  /// `context.go(location)` without page transitions.
  void go(BuildContext context, String location) {
    _active = true;
    final scheduler = SchedulerBinding.instance;
    scheduler.addPostFrameCallback((_) => _active = false);
    scheduler.ensureVisualUpdate();
    context.go(location);
  }
}

/// Page of the shell navigator: a section switch ([SectionSwitchSignal])
/// creates it without a transition, anything else with the push transition
/// of the current platform ([pushTransitionFor]).
class NexusPage<T> extends Page<T> {
  const NexusPage({
    required this.child,
    required this.sectionSwitch,
    super.key,
    super.name,
    super.arguments,
    super.restorationId,
  });

  final Widget child;
  final SectionSwitchSignal sectionSwitch;

  @override
  Route<T> createRoute(BuildContext context) {
    return _NexusPageRoute<T>(
      page: this,
      transition: sectionSwitch.active
          ? NexusPageTransition.none
          : pushTransitionFor(defaultTargetPlatform),
    );
  }
}

class _NexusPageRoute<T> extends PageRoute<T>
    with MaterialRouteTransitionMixin<T> {
  _NexusPageRoute({required NexusPage<T> page, required this.transition})
      : super(settings: page);

  /// Fixed when the route is created: rebuilding the page list keeps the
  /// route, so a later navigation does not change how this page animated.
  final NexusPageTransition transition;

  NexusPage<T> get _page => settings as NexusPage<T>;

  @override
  Widget buildContent(BuildContext context) => _page.child;

  @override
  bool get maintainState => true;

  @override
  bool get fullscreenDialog => false;

  @override
  String get debugLabel => '${super.debugLabel}(${_page.name})';

  @override
  Duration get transitionDuration => switch (transition) {
        NexusPageTransition.none => Duration.zero,
        NexusPageTransition.fade => nexusFadeDuration,
        NexusPageTransition.platform => super.transitionDuration,
      };

  @override
  Duration get reverseTransitionDuration => transitionDuration;

  @override
  bool didPop(T? result) {
    // A section switch that pops this page (rail tap on its own section
    // while a page of that section is open) removes it at once.
    if (_page.sectionSwitch.active) {
      controller?.reverseDuration = Duration.zero;
    }
    return super.didPop(result);
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return switch (transition) {
      NexusPageTransition.none => child,
      NexusPageTransition.fade => FadeTransition(
          opacity: animation.drive(CurveTween(curve: Curves.easeOut)),
          child: child,
        ),
      NexusPageTransition.platform => super.buildTransitions(
          context,
          animation,
          secondaryAnimation,
          child,
        ),
    };
  }
}

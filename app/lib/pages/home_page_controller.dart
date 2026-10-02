import 'dart:async';

import 'package:flutter/material.dart';
import 'package:localsend_app/config/m3e_tokens.dart';
import 'package:localsend_app/pages/home_tab.dart';
import 'package:localsend_app/provider/animation_provider.dart';
import 'package:refena_flutter/refena_flutter.dart';

class HomePageVm {
  final PageController controller;
  final HomeTab currentTab;
  final void Function(HomeTab, {bool? animate}) changeTab;

  HomePageVm({
    required this.controller,
    required this.currentTab,
    required this.changeTab,
  });
}

final homePageControllerProvider = ReduxProvider<HomePageController, HomePageVm>(
  (ref) => HomePageController(() => ref.read(animationProvider)),
);

class HomePageController extends ReduxNotifier<HomePageVm> {
  final bool Function() _appMotionEnabled;

  HomePageController(this._appMotionEnabled);

  bool get appMotionEnabled => _appMotionEnabled();

  @override
  HomePageVm init() {
    return HomePageVm(
      controller: PageController(),
      currentTab: HomeTab.receive,
      changeTab: (tab, {animate}) => redux.dispatch(ChangeTabAction(tab, animate: animate)),
    );
  }
}

class ChangeTabAction extends ReduxAction<HomePageController, HomePageVm> {
  final HomeTab tab;
  final bool? animate;

  ChangeTabAction(this.tab, {this.animate});

  @override
  HomePageVm reduce() {
    final systemReducedMotion = WidgetsBinding.instance.platformDispatcher.accessibilityFeatures.disableAnimations;
    final shouldAnimate = (animate ?? notifier.appMotionEnabled) && !systemReducedMotion;
    if (state.controller.hasClients && shouldAnimate) {
      unawaited(
        state.controller.animateToPage(
          tab.index,
          duration: M3eTokens.standardMotion,
          curve: M3eTokens.responsiveCurve,
        ),
      );
    } else {
      state.controller.jumpToPage(tab.index);
    }
    return HomePageVm(
      controller: state.controller,
      currentTab: tab,
      changeTab: state.changeTab,
    );
  }
}

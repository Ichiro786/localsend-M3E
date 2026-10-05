import 'dart:async';

import 'package:flutter/material.dart';
import 'package:localsend_app/config/m3e_tokens.dart';
import 'package:localsend_app/pages/home_page.dart';
import 'package:refena_flutter/refena_flutter.dart';

class HomePageVm {
  final PageController controller;
  final HomeTab currentTab;
  final void Function(HomeTab) changeTab;

  HomePageVm({
    required this.controller,
    required this.currentTab,
    required this.changeTab,
  });
}

final homePageControllerProvider = ReduxProvider<HomePageController, HomePageVm>(
  (ref) => HomePageController(),
);

class HomePageController extends ReduxNotifier<HomePageVm> {
  @override
  HomePageVm init() {
    return HomePageVm(
      controller: PageController(),
      currentTab: HomeTab.receive,
      changeTab: (tab) => redux.dispatch(ChangeTabAction(tab)),
    );
  }

  @override
  void dispose() {
    state.controller.dispose();
    super.dispose();
  }
}

class ChangeTabAction extends ReduxAction<HomePageController, HomePageVm> {
  final HomeTab tab;

  ChangeTabAction(this.tab);

  @override
  HomePageVm reduce() {
    final controller = state.controller.hasClients ? state.controller : PageController(initialPage: tab.index);
    if (identical(controller, state.controller)) {
      unawaited(
        controller.animateToPage(
          tab.index,
          duration: M3eTokens.standardMotion,
          curve: M3eTokens.responsiveCurve,
        ),
      );
    } else {
      // With no attached PageView, the requested tab is its next initial page.
      // jumpToPage requires a position; dispose the unattached controller instead.
      state.controller.dispose();
    }
    return HomePageVm(
      controller: controller,
      currentTab: tab,
      changeTab: state.changeTab,
    );
  }
}

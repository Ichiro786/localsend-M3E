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
}

class ChangeTabAction extends ReduxAction<HomePageController, HomePageVm> {
  final HomeTab tab;

  ChangeTabAction(this.tab);

  @override
  HomePageVm reduce() {
    if (state.controller.hasClients) {
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

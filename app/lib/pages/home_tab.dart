import 'package:flutter/material.dart';
import 'package:localsend_app/gen/strings.g.dart';

enum HomeTab {
  receive(Icons.download_for_offline_outlined),
  send(Icons.send),
  settings(Icons.settings)
  ;

  final IconData icon;

  const HomeTab(this.icon);

  String get label {
    switch (this) {
      case HomeTab.receive:
        return t.receiveTab.title;
      case HomeTab.send:
        return t.sendTab.title;
      case HomeTab.settings:
        return t.settingsTab.title;
    }
  }
}

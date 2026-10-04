import 'package:flutter/material.dart';

/// Replace only this transfer's request route. An incoming request can cover
/// it while an outgoing prepare-upload request is awaiting its response.
Future<void> replaceTransferRoute({required PageRoute<void> request, required PageRoute<void> progress}) {
  final navigator = request.navigator;
  if (navigator == null || !request.isActive) return Future.value();
  if (request.isCurrent) return navigator.pushReplacement<void, void>(progress);
  navigator.replace(oldRoute: request, newRoute: progress);
  return progress.popped;
}

void dismissTransferRoute(PageRoute<void> request) {
  final navigator = request.navigator;
  if (navigator == null || !request.isActive) return;
  if (request.isCurrent) {
    navigator.pop();
  } else {
    navigator.removeRoute(request);
  }
}

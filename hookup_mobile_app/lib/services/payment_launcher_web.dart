// ignore_for_file: avoid_web_libraries_in_flutter

import 'dart:html' as html;

Future<bool> openPaymentUrl(String url) async {
  if (url.trim().isEmpty) {
    return false;
  }
  html.window.open(url, '_blank');
  return true;
}

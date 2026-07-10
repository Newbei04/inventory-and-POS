import 'package:flutter/services.dart';

const _channel = MethodChannel('com.example.price_checker/app');

Future<void> killApp() async {
  try {
    await _channel.invokeMethod('killApp');
  } catch (_) {
    SystemNavigator.pop();
  }
}

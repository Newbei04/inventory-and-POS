import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:usb_serial/usb_serial.dart';

class UsbScannerService {
  UsbPort? _port;
  StreamSubscription<Uint8List>? _subscription;
  final _barcodeController = StreamController<String>.broadcast();

  bool _connected = false;
  String _status = 'Disconnected';

  bool get isConnected => _connected;
  String get status => _status;

  Stream<String> get barcodeStream => _barcodeController.stream;

  Future<void> connect({int baudRate = 9600}) async {
    disconnect();

    try {
      _status = 'Scanning for USB devices...';

      final devices = await UsbSerial.listDevices();
      if (devices.isEmpty) {
        _status = 'No USB scanner found';
        return;
      }

      final device = devices.first;
      _status = 'Found ${device.productName ?? device.deviceName}';

      _port = await device.create();
      if (_port == null) {
        _status = 'Failed to create port';
        return;
      }

      final opened = await _port!.open();
      if (!opened) {
        _status = 'Failed to open port (permission denied)';
        _port = null;
        return;
      }

      await _port!.setDTR(true);
      await _port!.setRTS(true);
      await _port!.setPortParameters(
        baudRate,
        UsbPort.DATABITS_8,
        UsbPort.STOPBITS_1,
        UsbPort.PARITY_NONE,
      );

      _connected = true;
      _status = 'USB scanner connected';

      _subscription = _port!.inputStream!.listen(
        _onData,
        onError: (error) {
          _status = 'Read error: $error';
          disconnect();
        },
        onDone: () {
          _status = 'Scanner disconnected';
          disconnect();
        },
        cancelOnError: false,
      );
    } catch (e) {
      _status = 'Connection error: $e';
      await _port?.close();
      _port = null;
      _connected = false;
    }
  }

  final _buffer = StringBuffer();

  void _onData(Uint8List data) {
    final str = utf8.decode(data, allowMalformed: true);
    for (var i = 0; i < str.length; i++) {
      final c = str[i];
      if (c == '\n' || c == '\r') {
        final barcode = _buffer.toString().trim();
        _buffer.clear();
        if (barcode.isNotEmpty) {
          _barcodeController.add(barcode);
        }
      } else {
        _buffer.write(c);
      }
    }
  }

  void disconnect() {
    _subscription?.cancel();
    _subscription = null;
    _port?.close();
    _port = null;
    _connected = false;
    _status = 'Disconnected';
  }

  void dispose() {
    disconnect();
    _barcodeController.close();
  }
}

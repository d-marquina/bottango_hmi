import 'dart:async';
import 'dart:typed_data';

import 'package:usb_serial/usb_serial.dart';

/// Capa de transporte serial (USB CDC) hacia la Raspberry Pi Pico.
///
/// Responsabilidades:
///  - Listar/abrir el puerto USB (115200 8N1, DTR/RTS activos).
///  - Reensamblar bytes en líneas terminadas en '\n' (descartando '\r'),
///    igual que el driver espera/emite (ver outgoing.py del driver).
class SerialConnection {
  UsbPort? _port;
  StreamSubscription<Uint8List>? _sub;
  String _buffer = '';

  final _lineController = StreamController<String>.broadcast();

  /// Líneas completas recibidas de la Pico (sin '\n' ni '\r').
  Stream<String> get lines => _lineController.stream;

  bool get isConnected => _port != null;

  /// Dispositivos USB serial visibles. La Pico usa VID 0x2E8A (Raspberry Pi).
  Future<List<UsbDevice>> listDevices() => UsbSerial.listDevices();

  /// Intenta elegir la Pico automáticamente; si no, el primer dispositivo.
  Future<UsbDevice?> findPico() async {
    final devices = await listDevices();
    if (devices.isEmpty) return null;
    for (final d in devices) {
      if (d.vid == 0x2E8A) return d; // Raspberry Pi (Pico / Pico 2)
    }
    return devices.first;
  }

  Future<bool> connect(UsbDevice device) async {
    final port = await device.create();
    if (port == null) return false;

    if (!await port.open()) return false;

    await port.setDTR(true);
    await port.setRTS(true);
    await port.setPortParameters(
      115200,
      UsbPort.DATABITS_8,
      UsbPort.STOPBITS_1,
      UsbPort.PARITY_NONE,
    );

    _port = port;
    _sub = port.inputStream?.listen(_onData);
    return true;
  }

  void _onData(Uint8List data) {
    _buffer += String.fromCharCodes(data);
    int idx;
    while ((idx = _buffer.indexOf('\n')) >= 0) {
      final line = _buffer.substring(0, idx).replaceAll('\r', '');
      _buffer = _buffer.substring(idx + 1);
      if (line.isNotEmpty) _lineController.add(line);
    }
  }

  /// Envía un comando terminado en '\n' (el driver es estricto: solo '\n').
  Future<void> writeLine(String cmd) async {
    final port = _port;
    if (port == null) return;
    await port.write(Uint8List.fromList('$cmd\n'.codeUnits));
  }

  Future<void> disconnect() async {
    await _sub?.cancel();
    _sub = null;
    await _port?.close();
    _port = null;
    _buffer = '';
  }

  void dispose() {
    _lineController.close();
  }
}

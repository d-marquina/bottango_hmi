import 'dart:async';

import 'serial_connection.dart';

/// Implementa el lado "host" del protocolo Bottango — el rol que hacía la
/// laptop con Bottango. Habla con el driver MicroPython (que NO se modifica).
///
/// Control de flujo: el driver responde a CADA comando (OK / btngoHSK) y lee
/// una línea por iteración de su bucle. Por eso ESPERAMOS la respuesta antes de
/// enviar el siguiente comando, para no desbordar el buffer UART de la Pico.
class BottangoHost {
  final SerialConnection conn;

  final _log = StreamController<String>.broadcast();
  Stream<String> get log => _log.stream;

  Completer<String>? _waiter;
  String? _waitPrefix;
  bool _listening = false;

  BottangoHost(this.conn);

  void _ensureListening() {
    if (_listening) return;
    _listening = true;
    conn.lines.listen((line) {
      _log.add('<< $line');
      final w = _waiter;
      if (w != null && !w.isCompleted) {
        if (_waitPrefix == null || line.startsWith(_waitPrefix!)) {
          _waiter = null;
          w.complete(line);
        }
      }
    });
  }

  Future<String> _send(
    String cmd, {
    String? expect,
    Duration timeout = const Duration(seconds: 3),
  }) async {
    _ensureListening();
    _waitPrefix = expect;
    final completer = Completer<String>();
    _waiter = completer;

    _log.add('>> $cmd');
    await conn.writeLine(cmd);

    return completer.future.timeout(timeout, onTimeout: () {
      _waiter = null;
      throw TimeoutException('Sin respuesta a "$cmd" (esperaba "$expect")');
    });
  }

  /// Handshake: hRQ → btngoHSK. Devuelve la línea btngoHSK (incluye versión).
  Future<String> handshake() => _send('hRQ,0', expect: 'btngoHSK');

  /// Registra los efectores (rSVI2C / rSVPin / rSTDir) leídos del export.
  Future<void> sendSetup(List<String> setupCommands) async {
    for (final c in setupCommands) {
      final line = c.trim();
      if (line.isEmpty) continue;
      await _send(line, expect: 'OK');
    }
  }

  /// Reproducción Modo A ("volcado"): pone el reloj en 0 y encola todas las
  /// curvas. La Pico las reproduce sola. Válido cuando cada efector tiene
  /// ≤ 8 curvas (buffer circular del driver). tSYN DEBE ir antes que las sC.
  Future<void> playModeA(List<String> animationCommands) async {
    await _send('tSYN,0', expect: 'OK');
    for (final c in animationCommands) {
      final line = c.trim();
      if (line.isEmpty) continue;
      await _send(line, expect: 'OK');
    }
  }

  /// Detiene la animación SIN reiniciar la placa.
  /// Ojo: el comando STOP del protocolo hace machine.reset(); por eso usamos
  /// xC (limpiar curvas), que mantiene los efectores registrados.
  Future<void> stop() => _send('xC', expect: 'OK');

  void dispose() {
    _log.close();
  }
}

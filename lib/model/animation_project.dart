import 'dart:convert';

/// Una animación exportada por Bottango (Opción 3: JSON).
///
/// Los comandos son EXACTAMENTE el protocolo serial que el driver MicroPython
/// ya interpreta (sSY, sC, ...). No los transformamos, solo los transportamos.
class BottangoAnimation {
  final String name;
  final List<String> commands; // líneas de reproducción (sSY / sC)
  final List<String> loopCommands; // líneas para loop (puede estar vacío)

  BottangoAnimation({
    required this.name,
    required this.commands,
    required this.loopCommands,
  });

  /// Duración total en ms = max(startOffset + duration) de todas las curvas.
  /// Sirve para saber cuándo termina la animación (habilitar botón / loop).
  int get durationMs {
    int maxEnd = 0;
    for (final line in commands) {
      for (final curve in _extractCurves(line)) {
        if (curve.length >= 3) {
          final start = int.tryParse(curve[1]) ?? 0;
          final dur = int.tryParse(curve[2]) ?? 0;
          final end = start + dur;
          if (end > maxEnd) maxEnd = end;
        }
      }
    }
    return maxEnd;
  }

  /// Devuelve cada curva como lista de campos [id, startOffset, duration, ...].
  /// Maneja tanto `sC,...` como el batch `sSY,sC,<e1>;<e2>;...`.
  static List<List<String>> _extractCurves(String line) {
    final parts = line.split(',');
    final result = <List<String>>[];
    if (parts.isEmpty) return result;

    if (parts[0] == 'sC') {
      result.add(parts.sublist(1)); // [id, start, dur, ...]
    } else if (parts[0] == 'sSY' && parts.length > 2) {
      // sSY,sC,<entry>;<entry>;...  → reunimos tras "sSY,sC" y partimos por ';'
      final joined = parts.sublist(2).join(',');
      for (final entry in joined.split(';')) {
        final fields = entry
            .split(',')
            .where((s) => s.isNotEmpty && !s.startsWith('h'))
            .toList();
        if (fields.isNotEmpty) result.add(fields);
      }
    }
    return result;
  }
}

/// Proyecto completo exportado por Bottango (un controlador + sus animaciones).
class AnimationProject {
  final String controllerName;
  final List<String> setupCommands; // rSVI2C / rSVPin / rSTDir ...
  final List<BottangoAnimation> animations;

  AnimationProject({
    required this.controllerName,
    required this.setupCommands,
    required this.animations,
  });

  factory AnimationProject.fromJsonString(String jsonStr) {
    final data = json.decode(jsonStr) as List<dynamic>;
    if (data.isEmpty) {
      throw const FormatException('El JSON no contiene controladores.');
    }
    // MVP: tomamos el primer controlador (un solo driver / una sola Pico).
    final first = data.first as Map<String, dynamic>;

    final setup =
        (first['Setup']?['Controller Setup Commands'] ?? '') as String;

    final anims = ((first['Animations'] ?? []) as List<dynamic>).map((a) {
      final m = a as Map<String, dynamic>;
      return BottangoAnimation(
        name: (m['Animation Name'] ?? 'Sin nombre') as String,
        commands: _splitLines((m['Animation Commands'] ?? '') as String),
        loopCommands: _splitLines((m['Animation Loop Commands'] ?? '') as String),
      );
    }).toList();

    return AnimationProject(
      controllerName: (first['Controller Name'] ?? '') as String,
      setupCommands: _splitLines(setup),
      animations: anims,
    );
  }

  static List<String> _splitLines(String s) => s
      .split('\n')
      .map((l) => l.trim())
      .where((l) => l.isNotEmpty)
      .toList();
}

import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import 'model/animation_project.dart';
import 'serial/bottango_host.dart';
import 'serial/serial_connection.dart';

void main() => runApp(const BottangoHmiApp());

class BottangoHmiApp extends StatelessWidget {
  const BottangoHmiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bottango HMI',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: Colors.teal, useMaterial3: true),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _conn = SerialConnection();
  BottangoHost? _host;
  AnimationProject? _project;

  String _status = 'Desconectado';
  bool _connected = false;
  bool _busy = false;
  final _logLines = <String>[];

  void _appendLog(String line) {
    setState(() {
      _logLines.add(line);
      if (_logLines.length > 200) _logLines.removeAt(0);
    });
  }

  Future<void> _loadProject() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final bytes = result.files.first.bytes;
    if (bytes == null) return;
    try {
      final project = AnimationProject.fromJsonString(utf8.decode(bytes));
      setState(() => _project = project);
      _appendLog('Proyecto cargado: ${project.controllerName} '
          '(${project.animations.length} animaciones)');
    } catch (e) {
      _appendLog('Error al leer JSON: $e');
    }
  }

  Future<void> _connect() async {
    setState(() {
      _busy = true;
      _status = 'Buscando Pico...';
    });
    try {
      final device = await _conn.findPico();
      if (device == null) {
        setState(() => _status = 'No se encontró dispositivo USB');
        return;
      }
      if (!await _conn.connect(device)) {
        setState(() => _status = 'No se pudo abrir el puerto');
        return;
      }
      final host = BottangoHost(_conn);
      host.log.listen(_appendLog);
      _host = host;

      setState(() => _status = 'Handshake...');
      final hsk = await host.handshake();
      _appendLog('Conectado: $hsk');

      if (_project != null) {
        setState(() => _status = 'Registrando efectores...');
        await host.sendSetup(_project!.setupCommands);
      }

      setState(() {
        _connected = true;
        _status = 'Conectado';
      });
    } catch (e) {
      setState(() => _status = 'Error: $e');
    } finally {
      setState(() => _busy = false);
    }
  }

  Future<void> _play(BottangoAnimation anim) async {
    final host = _host;
    if (host == null) return;
    setState(() => _busy = true);
    try {
      _appendLog('▶ ${anim.name} (${anim.durationMs} ms)');
      await host.playModeA(anim.commands);
    } catch (e) {
      _appendLog('Error al reproducir: $e');
    } finally {
      setState(() => _busy = false);
    }
  }

  Future<void> _stop() async {
    final host = _host;
    if (host == null) return;
    try {
      await host.stop();
      _appendLog('■ Detenido');
    } catch (e) {
      _appendLog('Error al detener: $e');
    }
  }

  @override
  void dispose() {
    _host?.dispose();
    _conn.disconnect();
    _conn.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final project = _project;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bottango HMI'),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Center(
              child: Row(
                children: [
                  Icon(
                    _connected ? Icons.usb : Icons.usb_off,
                    color: _connected ? Colors.greenAccent : Colors.redAccent,
                  ),
                  const SizedBox(width: 6),
                  Text(_status),
                ],
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                FilledButton.icon(
                  onPressed: _busy ? null : _loadProject,
                  icon: const Icon(Icons.folder_open),
                  label: const Text('Cargar JSON'),
                ),
                const SizedBox(width: 12),
                FilledButton.icon(
                  onPressed: (_busy || _connected) ? null : _connect,
                  icon: const Icon(Icons.link),
                  label: const Text('Conectar'),
                ),
                const Spacer(),
                if (_connected)
                  OutlinedButton.icon(
                    onPressed: _stop,
                    icon: const Icon(Icons.stop),
                    label: const Text('Detener'),
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: project == null
                ? const Center(child: Text('Carga un archivo JSON de Bottango'))
                : ListView.builder(
                    itemCount: project.animations.length,
                    itemBuilder: (context, i) {
                      final anim = project.animations[i];
                      return ListTile(
                        leading: const Icon(Icons.movie),
                        title: Text(anim.name),
                        subtitle: Text('${anim.durationMs} ms'),
                        trailing: IconButton(
                          icon: const Icon(Icons.play_arrow),
                          onPressed: (_connected && !_busy)
                              ? () => _play(anim)
                              : null,
                        ),
                      );
                    },
                  ),
          ),
          const Divider(height: 1),
          SizedBox(
            height: 160,
            child: Container(
              color: Colors.black87,
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              child: ListView(
                reverse: true,
                children: _logLines.reversed
                    .map((l) => Text(
                          l,
                          style: const TextStyle(
                            color: Colors.greenAccent,
                            fontFamily: 'monospace',
                            fontSize: 12,
                          ),
                        ))
                    .toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

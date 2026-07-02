# Bottango HMI (tablet)

App Flutter para Android que **reemplaza a Bottango** como interfaz del
animatrónico. Se conecta a la Raspberry Pi Pico por **USB (OTG)** y le envía
los mismos comandos serial que Bottango, leídos de una animación exportada en
formato **JSON**.

El driver MicroPython de la Pico **no se modifica**: la app habla su protocolo.

## Estado — MVP (Hito 1)

- [x] Cargar animación exportada (JSON de Bottango).
- [x] Conexión USB serial (CDC, 115200 8N1).
- [x] Handshake + registro de efectores (rol "host").
- [x] Reproducción **Modo A** (volcado): pone el reloj en 0 y encola todas las
      curvas; la Pico reproduce sola. Válido para ≤ 8 curvas por efector.
- [x] Detener sin reiniciar la placa (comando `xC`, no `STOP`).
- [ ] Control manual en vivo (sliders) — futuro.
- [ ] Streaming Modo B para animaciones largas (> 8 curvas/efector) — futuro.

## Cómo se compila (sin instalar nada localmente)

No necesitas Flutter ni el Android SDK en tu PC. GitHub Actions compila el APK:

1. Sube este repo a GitHub (rama `main`).
2. Ve a la pestaña **Actions** → workflow **Build APK** → espera ~5 min.
3. Descarga el artifact **`bottango-hmi-apk`** (contiene `app-release.apk`).
4. Pásalo a la tablet e instálalo (activa "Instalar apps de origen desconocido").

Para lanzar un build manual: Actions → Build APK → **Run workflow**.

## Cómo se usa en la tablet

1. Conecta la Pico a la tablet con un cable/adaptador **USB-OTG**.
2. Abre la app → **Cargar JSON** (el `AnimationCommands.json` exportado).
3. **Conectar** → acepta el permiso USB de Android.
4. Toca ▶ en una animación. **Detener** la corta.

## Estructura

```
lib/
├── main.dart                       UI (cargar, conectar, lista, log)
├── model/animation_project.dart    parseo del JSON + duración
└── serial/
    ├── serial_connection.dart      transporte USB (líneas '\n')
    └── bottango_host.dart          protocolo host (handshake/setup/play/stop)
test/
└── animation_project_test.dart     pruebas del parser (corren en CI)
```

> `android/` NO está versionado: lo regenera `flutter create` en el CI.

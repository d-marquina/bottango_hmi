import 'package:flutter_test/flutter_test.dart';
import 'package:bottango_hmi/model/animation_project.dart';

// JSON real exportado por Bottango (proyecto "Motor V7 Pro").
const _sampleJson = '''
[
  {
    "Controller Name": "Pico 1 Driver",
    "Setup": {
      "Controller Setup Commands": "rSVI2C,64,2,1000,2000,3000,1500\\nrSVI2C,64,1,1000,2000,3000,1500\\nrSVI2C,64,0,1000,2000,3000,1500\\n"
    },
    "Animations": [
      {
        "Animation Name": "Default Animation",
        "Animation Commands": "sSY,sC,640,0,1167,4096,291,0,7013,-291,0;641,0,1533,4096,396,0,653,-585,0;642,0,2867,4096,697,0,0,-1008,0;\\nsC,640,1167,1133,7013,283,0,1529,-283,0\\nsC,641,1533,2467,653,890,0,4096,-603,0\\nsC,640,2300,1700,1529,425,0,4096,-425,0\\nsC,642,2867,1133,0,433,0,4096,-299,0\\n",
        "Animation Loop Commands": ""
      }
    ]
  }
]
''';

void main() {
  group('AnimationProject', () {
    late AnimationProject project;

    setUp(() {
      project = AnimationProject.fromJsonString(_sampleJson);
    });

    test('lee el nombre del controlador', () {
      expect(project.controllerName, 'Pico 1 Driver');
    });

    test('extrae los 3 comandos de setup', () {
      expect(project.setupCommands.length, 3);
      expect(project.setupCommands.first, 'rSVI2C,64,2,1000,2000,3000,1500');
    });

    test('lee una animación con sus comandos', () {
      expect(project.animations.length, 1);
      final anim = project.animations.first;
      expect(anim.name, 'Default Animation');
      // 1 línea sSY + 4 líneas sC
      expect(anim.commands.length, 5);
      expect(anim.commands.first.startsWith('sSY,sC,640,'), isTrue);
    });

    test('calcula la duración total correctamente', () {
      // La curva que termina más tarde: 641 en offset 1533 + dur 2467 = 4000 ms
      // (640: 2300+1700=4000 también). Máximo = 4000 ms.
      expect(project.animations.first.durationMs, 4000);
    });
  });
}

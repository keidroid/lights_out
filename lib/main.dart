import 'dart:convert';
import 'dart:math';
import 'dart:ui';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

main() => LightsOut().run();

class LightsOut {
  final W = 720.0, H = 1280.0, P = 120.0, PS = 140.0;
  var x = 0.0;
  var touchedX = -1;
  var touchedY = -1;
  var realTouchedX = -1;
  var realTouchedY = -1;
  var isTouched = false;
  var effect = 0;
  var frame = 0;
  int step = 0;
  int clear = 0;
  int stage = 0;
  State current = State.Clear;
  State next = State.Title;
  List<List<int>> panels;

  run() {
    window.onPointerDataPacket = handlePointerDataPacket;
    window.onBeginFrame = update;
    window.scheduleFrame();
  }

  update(Duration timeStamp) {
    if (current != next) {
      current = next;
      if (current == State.Title) {
        resetPanels();
      }
      if (current == State.Stage) {
        loadAsset();
      }
    }

    if (timeStamp.inMilliseconds - frame >= 100) {
      effect = max(effect - 1, 0);
      frame = timeStamp.inMilliseconds;
    }
    var delta = (timeStamp.inMilliseconds - frame) / 1000;

    x += 0.8 * delta;
    var dpr = window.devicePixelRatio;
    var paintBounds = Offset.zero & (window.physicalSize / dpr);
    var logicalSize = window.physicalSize / dpr;
    var physicalBounds = Offset.zero & (logicalSize * dpr);
    var sb = SceneBuilder()
      ..pushClipRect(physicalBounds)
      ..addPicture(Offset(0, 0), paint(paintBounds))
      ..pop();
    window.render(sb.build());
    window.scheduleFrame();
  }

  paint(Rect r) {
    var ratio = window.physicalSize.width / W;
    var physicalBounds = Offset.zero & (Size(W, H) * ratio);
    var r = PictureRecorder();
    var c = Canvas(r, physicalBounds);

    c.scale(ratio, ratio);
    c.drawRect(screen(), Paint()..shader = linearGradient());

    var p = Paint();
    p.style = PaintingStyle.fill;
    p.color = Color(0x10ffffff);
    p.strokeWidth = 1.5;
    p.maskFilter = MaskFilter.blur(BlurStyle.solid, 4);

    c.save();
    c.translate(360, 720);
    c.rotate(x);
    c.drawOval(Rect.fromLTRB(-320.0, -300.0, 320.0, 300.0), p);
    c.drawOval(Rect.fromLTRB(-300.0, -320.0, 300.0, 320.0), p);
    c.restore();

    var p2 = Paint()
      ..color = Color(0xaaffffff)
      ..style = PaintingStyle.fill
      ..maskFilter = MaskFilter.blur(BlurStyle.solid, 12);

    var p3 = Paint()
      ..color = Color(0x80ffffff)
      ..style = PaintingStyle.stroke
      ..maskFilter = MaskFilter.blur(BlurStyle.solid, 3)
      ..strokeWidth = 2.0;

    int s = 1;
    for (int y = 0; y < 5; y++) {
      for (int x = 0; x < 5; x++) {
        c.drawRRect(RRect.fromRectXY(Rect.fromLTWH(20 + PS * x, 400 + PS * y, P, P), 8, 8), panels[y][x] > 0 ? p2 : p3);
        if (current == State.Title) {
          drawText(c, '$s', 64, Offset(44 + PS * x, 424 + PS * y));
        }
        s++;
      }
    }

    if (current == State.Title) {
      drawText(c, 'Lights Out', 128, Offset(80, 160));
    } else if (current == State.Clear) {
      drawText(c, 'Stage Clear!!', 96, Offset(-40, 160));
    } else if (current == State.Failed) {
      drawText(c, 'Stage Failed..', 96, Offset(-40, 160));
    } else {
      drawText(c, 'Step', 64, Offset(20, 240));
      drawText(c, '$step / $clear', 128, Offset(360, 240));
    }
    return r.endRecording();
  }

  handlePointerDataPacket(PointerDataPacket packet) {
    var ratio = window.physicalSize.width / W;

    for (PointerData datum in packet.data) {
      var touchX = (datum.physicalX / ratio - 20) / PS;
      var touchY = (datum.physicalY / ratio - 400) / PS;

      var x = (0.0 < touchX && touchX < 5.0) ? touchX.floor() : -1;
      var y = (0.0 < touchY && touchY < 5.0) ? touchY.floor() : -1;

      if (datum.change == PointerChange.up) {
        if (0 > x || 0 > y) break;
        if (current == State.Game) {
          toggleX(x, y);
          step = min(step + 1, 99);
          if (isClearPanels()) {
            next = State.Clear;
          } else if (clear == step) {
            next = State.Failed;
          }
          print(':: $step :: $clear');
        } else if (current == State.Title) {
          next = State.Stage;
          stage = y * 5 + x + 1;
        } else if (current == State.Clear || current == State.Failed) {
          next = State.Title;
        }
      }
      break;
    }
  }

  resetPanels() => panels = List.generate(5, (_) => List.generate(5, (_) => 0));

  toggleX(int x, int y) {
    toggle(x, y);
    if (y > 0) toggle(x, y - 1);
    if (y < 4) toggle(x, y + 1);
    if (x > 0) toggle(x - 1, y);
    if (x < 4) toggle(x + 1, y);
  }

  toggle(int x, int y) => panels[y][x] = (panels[y][x] + 1) % 2;

  isClearPanels() {
    for (var line in panels) {
      for (var p in line) {
        if (p > 0) return false;
      }
    }
    return true;
  }

  onPanel(int x, int y) => panels[y][x] = 2;

  screen() => Rect.fromLTWH(0, 0, W, H);

  textStyle(double size, {bool on = true}) =>
      ui.TextStyle(fontFamily: 'Roboto', color: Color(on ? 0xffffffff : 0x88ffffff), fontSize: size);

  drawText(Canvas c, String text, double size, Offset p) {
    var builder = ParagraphBuilder(ParagraphStyle())
      ..pushStyle(textStyle(size))
      ..addText(text);
    c.drawParagraph(builder.build()..layout(ParagraphConstraints(width: W)), p);
  }

  linearGradient() => LinearGradient(
        colors: <Color>[Color(0xff101010), Color(0xff204060)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(screen());

  loadAsset() async {
    var a = await rootBundle.loadString('assets/$stage.json');
    var conf = json.decode(a);
    print('${conf['title']}');

    clear = 0;
    for (int p in conf['step']) {
      print('step: $p');
      toggleX(p % 5, (p / 5).floor());
      clear++;
    }
    step = 0;

    next = State.Game;
  }
}

enum State { Title, Stage, Game, Clear, Failed }

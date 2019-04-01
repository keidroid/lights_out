import 'dart:convert';
import 'dart:math';
import 'dart:ui';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

main() => LightsOut().run();

class LightsOut {
  static const W = 720.0, H = 1080.0, P = 120.0, Q = 140.0, X = 20.0, Y = 280.0;

  List<List<int>> panels;
  List<int> result = List.filled(5 * 5, 0);

  /// 0:TITLE 1:LOADING, 2:STAGE, 3:SUCCESS, 4:FAILED
  int state = -1, next = 0;

  int frame = 0, step = 0, clear = 0, stage = 0, diff = 0;
  double rot = 0.0;

  run() {
    window.onPointerDataPacket = handlePointerDataPacket;
    window.onBeginFrame = update;
    window.scheduleFrame();
  }

  update(Duration timeStamp) {
    if (state != next) {
      if (next == 0) reset();
      if (next == 1) load();
      state = next;
      diff = 8;
    }

    var ms = timeStamp.inMilliseconds;
    if (ms - frame >= 100) {
      frame = ms;
    }

    var delta = (ms - frame) / 1000;
    rot += 0.8 * delta;
    diff = max(0, diff - 1);

    var sb = SceneBuilder()
      ..pushClipRect(screen)
      ..addPicture(Offset.zero, paint())
      ..pop();
    window.render(sb.build());
    window.scheduleFrame();
  }

  paint() {
    var r = PictureRecorder();
    var c = Canvas(r, screen);

    c.scale(ratio, ratio);
    c.drawRect(screen, Paint()..shader = gradient);

    c.save();
    c.translate(0, contentY);

    c.save();
    c.translate(360, 620);
    c.rotate(rot);
    c.drawOval(Rect.fromLTRB(-320.0, -300.0, 320.0, 300.0), bg);
    c.drawOval(Rect.fromLTRB(-300.0, -320.0, 300.0, 320.0), bg);
    c.restore();

    for (int y = 0; y < 5; y++) {
      for (int x = 0; x < 5; x++) {
        c.drawRRect(
            RRect.fromRectXY(Rect.fromLTWH(X + Q * x, Y + Q * y, P, P), 8, 8),
            panels[y][x] > 0 ? on : off);
        if (state == 0) {
          text(c, '${y * 5 + x + 1}', 64, X + 24 + Q * x, Y + 24 + Q * y,
              result[y * 5 + x] == 0);
        }
      }
    }

    if (state == 0) {
      text(c, 'Lights Out', 128, 80, 80);
      if (!result.contains(0)) {
        text(c, 'Thank you for playing!!', 64, 48, 980);
      }
    } else {
      text(c, 'Stage', 64, 40, 60);
      text(c, '$stage', 128, 40, 120);
      text(c, 'Step', 64, 360, 60);
      text(c, '$step / $clear', 128, 360, 120);
    }
    if (state == 3) {
      text(c, 'Success!', 96, 160, 980.0 + diff * diff);
    }
    if (state == 4) {
      text(c, 'Failed..', 96, 220, 980.0 + diff * diff);
    }

    c.restore();
    return r.endRecording();
  }

  handlePointerDataPacket(PointerDataPacket packet) {
    for (var datum in packet.data) {
      var tx = (datum.physicalX / ratio - X) / Q;
      var ty = (datum.physicalY / ratio - Y - contentY) / Q;
      var x = (0.0 < tx && tx < 5) ? tx.floor() : -1;
      var y = (0.0 < ty && ty < 5) ? ty.floor() : -1;

      if (datum.change == PointerChange.up) {
        if (0 > x || 0 > y) break;
        touched(x, y);
      }
      break;
    }
  }

  touched(int x, int y) {
    if (state == 0) {
      stage = y * 5 + x + 1;
      next = 1;
    } else if (state == 2) {
      toggleX(x, y);
      step++;
      if (isClear()) {
        result[stage - 1] = 1;
        next = 3;
      } else if (clear == step) {
        next = 4;
      }
    } else if (state > 2) {
      next = 0;
    }
  }

  reset() {
    step = 0;
    panels = List.generate(5, (_) => List.generate(5, (_) => 0));
  }

  load() async {
    var j = await rootBundle.loadString('assets/$stage.json');
    var c = json.decode(j);
    clear = 0;
    for (int p in c['s']) {
      toggleX(p % 5, p ~/ 5);
      clear++;
    }
    next = 2;
  }

  toggleX(int x, int y) {
    toggle(x, y);
    if (x > 0) toggle(x - 1, y);
    if (y > 0) toggle(x, y - 1);
    if (x < 4) toggle(x + 1, y);
    if (y < 4) toggle(x, y + 1);
  }

  toggle(int x, int y) => panels[y][x] = (panels[y][x] + 1) % 2;

  isClear() {
    for (var y in panels) for (var x in y) if (x > 0) return false;
    return true;
  }

  text(Canvas c, String text, double size, double x, double y,
      [bool on = true]) {
    var builder = ParagraphBuilder(ParagraphStyle())
      ..pushStyle(ui.TextStyle(
          fontFamily: 'Roboto-Thin',
          color: Color(on ? 0xddffffff : 0x44ffffff),
          fontSize: size))
      ..addText(text);
    c.drawParagraph(
        builder.build()..layout(ParagraphConstraints(width: W)), Offset(x, y));
  }

  solid(double s) => MaskFilter.blur(BlurStyle.solid, s);

  get screen => Offset.zero & window.physicalSize;

  get ratio => window.physicalSize.width / W;

  get contentY => (window.physicalSize.height / ratio - H) / 2;

  get gradient => LinearGradient(
        colors: <Color>[Color(0xff101010), Color(0xff204060)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(screen);

  get bg => Paint()
    ..color = Color(0x10ffffff)
    ..maskFilter = solid(5);

  get on => Paint()
    ..color = Color(0xaaffffff)
    ..maskFilter = solid(50);

  get off => Paint()
    ..color = Color(0xaaffffff)
    ..style = PaintingStyle.stroke
    ..maskFilter = solid(5);
}

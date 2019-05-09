import 'dart:convert';
import 'dart:math';
import 'package:flutter_web_ui/ui.dart';
import 'package:flutter_web_ui/ui.dart' as ui;

import 'package:flutter_web/material.dart';
import 'package:flutter_web/services.dart';
import 'package:flutter_web/rendering.dart';

class LightsOut extends RenderBox {
  LightsOut();

  static const W = 720.0/2, H = 720.0/2, P = 120.0/2, Q = 140.0/2, X = 20.0/2, Y = 60.0/2;
  static const FL = 128.0/2, FM = 96.0/2, FS = 64.0/2;

  List<List<int>> panels;
  List<int> result = List.filled(5 * 5, 0);

  /// 0:TITLE 1:LOADING, 2:STAGE, 3:SUCCESS, 4:FAILED
  int state = -1, next = 0;

  int frame = 0, step = 0, clear = 0, stage = 0, diff = 0;
  double rot = 0.0;

  @override
  bool get sizedByParent => true;

  @override
  void performResize() {
    size = constraints.biggest;
  }

  @override
  bool hitTestSelf(Offset position) => true;

  @override
  void handleEvent(PointerEvent event, BoxHitTestEntry entry) {
    if (event is PointerDownEvent) {
      var tx = (event.position.dx / ratio - X) / Q;
      var ty = (event.position.dy / ratio - Y - contentY) / Q;
      var x = (0.0 < tx && tx < 5) ? tx.floor() : -1;
      var y = (0.0 < ty && ty < 5) ? ty.floor() : -1;

      if (0 > x || 0 > y) return;
      touched(x, y);
    }
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final Canvas c = context.canvas;
    c.drawRect(offset & size, Paint()..color = const Color(0xFF000000));

    c.scale(ratio, ratio);
    c.drawRect(screen, Paint()..shader = gradient);

    c.save();
    c.translate(0, contentY);

    c.save();
    c.translate(360/2, 360/2);
    c.rotate(rot);
    c.drawOval(Rect.fromLTRB(-320.0/2, -300.0/2, 320.0/2, 300.0/2), bg);
    c.drawOval(Rect.fromLTRB(-300.0/2, -320.0/2, 300.0/2, 320.0/2), bg);
    c.restore();

    for (int y = 0; y < 5; y++) {
      for (int x = 0; x < 5; x++) {

        c.drawRect(Rect.fromLTWH(X + Q * x, Y + Q * y, P, P), panels[y][x] > 0 ? on : off);
/* crash: drawRRect 
        c.drawRRect(
            RRect.fromRectXY(Rect.fromLTWH(X + Q * x, Y + Q * y, P, P), 8, 8),
            panels[y][x] > 0 ? on : off);
*/
        if (state == 0) {
          text(c, '${y * 5 + x + 1}', FS, X + 24/2 + Q * x, Y + 24/2 + Q * y,
              result[y * 5 + x] == 0);
        }
      }
    }

    if (state == 0) {
      text(c, 'Lights Out', FL, 80/2, -100/2);
      if (!result.contains(0)) {
        text(c, 'Thank you for playing!!', FS, 48/2, 980/2);
      }
    } else {
      text(c, 'Stage', FS, 40/2, -64/2);
      text(c, '$stage', FM, 220/2, -96/2);
      text(c, 'Step', FS, 320/2, -66/2);
      text(c, '$step / $clear', FM, 460/2, -96/2);
    }
    if (state == 3) {
      text(c, 'Success!', FM, 160/2, 220.0/2 + diff * diff);
    }
    if (state == 4) {
      text(c, 'Failed..', FM, 220/2, 220.0/2 + diff * diff);
    }
    c.restore();
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

  Future load() async {
    /* incompatible flutter_web
    var j = await rootBundle.loadString('assets/$stage.json');
    var c = json.decode(j);
    clear = 0;
    for (int p in c['s']) {
      toggleX(p % 5, p ~/ 5);
      clear++;
    }
    */

    //json stage data
    var s = [
      [12],[11,13],[2,10,12],[21,22,23],[7,12,17,22],
      [12],[11,13],[2,10,12],[21,22,23],[7,12,17,22], //sample
      [12],[11,13],[2,10,12],[21,22,23],[7,12,17,22], //sample
      [12],[11,13],[2,10,12],[21,22,23],[7,12,17,22], //sample
      [12],[11,13],[2,10,12],[21,22,23],[7,12,17,22], //sample
    ];
    clear = 0;
    for (int p in s[stage - 1]) {
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

  get screen => Offset.zero & size;

  get ratio => size.width / W;

  get contentY => (size.height / ratio - H) / 2;

  get gradient => LinearGradient(
        colors: <Color>[Color(0xff101010), Color(0xff204060)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(screen);

  get bg => Paint()
    ..color = Color(0x10ffffff);
//    ..maskFilter = solid(2);

  get on => Paint()
    ..color = Color(0xccffffff);
//    ..maskFilter = solid(20);

  get off => Paint()
    ..color = Color(0xccffffff)
    ..style = PaintingStyle.stroke;
//    ..maskFilter = solid(2);
}

void main() {
  runApp(new LightsOutWidget()..run());
}

class LightsOutWidget extends SingleChildRenderObjectWidget {
  LightsOut lightsOut = LightsOut();
  RenderObject createRenderObject(BuildContext context) {
    return lightsOut;
  }

  Future run() async {
    while (true) {
      var duration = Duration(milliseconds: 20);
      await new Future.delayed(duration);
      lightsOut.update(duration);
      lightsOut.markNeedsPaint();
    }
  }
}

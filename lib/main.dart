import 'dart:async';
import 'dart:async' as sync;
import 'dart:convert';
import 'dart:math';
import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flame/input.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  runApp(
    GameWidget(
      game: GameplayFlame(),
      overlayBuilderMap: {
        'ButtonPause': (ctx, GameplayFlame g) {
          return Align(
            alignment: Alignment.topLeft,
            child: Container(
              margin: const EdgeInsets.only(top: 40, left: 10),
              child: GestureDetector(
                onTap: () => g.pauseGame(),
                child: Image.asset(
                  'assets/images/pause-button.png',
                  fit: BoxFit.cover,
                  height: g.size.x * 0.1,
                ),
              ),
            ),
          );
        },
        'Overlay': (ctx, GameplayFlame g) {
          return Center(
            child: GestureDetector(
              onTap: () => g.isGameOver ? g.resetGame() : g.resumeGame(),
              child: Image.asset(
                "assets/images/${g.isGameOver ? "gameover" : "pause"}-overlay.png",
                fit: BoxFit.cover,
                height: g.size.x * .6,
              ),
            ),
          );
        },
      },
    ),
  );
}

class GameplayFlame extends FlameGame with PanDetector, HasCollisionDetection {
  List<List<String>> questionsData = [];
  double intervalGate = 8;
  late SpriteAnimationComponent player;
  late Sprite gateSprite;
  late Vector2 gateSize;
  late Vector2 gateSizeExpand;
  late Timer gateSpawner;
  bool isGameOver = false;
  int randomIndex = 0;
  int nextRandomIndex = 0;
  late TextComponent questionText;
  late TextComponent scoreText;
  bool isFirstSpawn = true;

  @override
  Color backgroundColor() {
    return const Color(0xff25253D);
  }

  @override
  FutureOr<void> onLoad() async {
    final jsonData = await rootBundle.loadString('assets/json/question.json');
    final jsonMap = json.decode(jsonData) as Map<String, dynamic>;
    questionsData = (jsonMap['question'] as List<dynamic>)
        .map(
          (questionData) => (questionData as List<dynamic>)
              .map(
                (answer) => answer.toString(),
              )
              .toList(),
        )
        .toList();
    gateSprite = await loadSprite('gate.png');
    gateSize = Vector2(size.x * .36, size.x * .2);
    gateSizeExpand = Vector2(size.x * .49, size.x * .49 * 20 / 36) * 1.5;
    overlays.add('ButtonPause');
    add(
      SpriteComponent()
        ..sprite = Sprite(await images.load('bg.png'))
        ..position = size / 2
        ..size = size
        ..anchor = Anchor.center,
    );
    questionText = TextComponent()
      ..size = Vector2(size.x * .4, size.y * .2)
      ..position = Vector2(size.x / 2, size.y * .1)
      ..anchor = Anchor.center;
    scoreText = TextComponent()
      ..text = '0'
      ..size = Vector2(size.x * .1, size.x * .1)
      ..position = Vector2(size.x - 10, size.y * .1)
      ..anchor = Anchor.centerRight;
    player = SpriteAnimationComponent()
      ..animation = await loadSpriteAnimation(
        'player-sprite.png',
        SpriteAnimationData.sequenced(
          amount: 8,
          stepTime: .1,
          textureSize: Vector2.all(256),
        ),
      )
      ..position = Vector2(size.x / 2, size.y - size.x * .25)
      ..size = Vector2.all(size.x * .25)
      ..anchor = Anchor.center
      ..priority = 999;
    addAll([player, questionText, scoreText]);
    startSpawner();
  }

  @override
  void update(double dt) {
    gateSpawner.update(dt);
    super.update(dt);
  }

  @override
  void onPanUpdate(DragUpdateInfo info) {
    if (info.eventPosition.global.x < 64) {
      player.position.x = 64;
    } else if (info.eventPosition.global.x > size.x - 64) {
      player.position.x = size.x - 64;
    } else {
      player.position.x = info.eventPosition.global.x;
    }
  }

  void startSpawner() {
    spawnGates();
    gateSpawner = Timer(
      intervalGate - 3,
      onTick: spawnGates,
      repeat: true,
    );
  }

  void spawnGates() {
    randomIndex = Random().nextInt(questionsData.length);
    if (isFirstSpawn) {
      isFirstSpawn = false;
      questionText.text = questionsData[randomIndex][0];
    }
    add(
      GateObject(
        isTheAnswer: questionsData[randomIndex][3] == 'left',
        theSprite: gateSprite,
        initPosition: Vector2((size.x / 2) - 5, size.y / 2),
        initSize: gateSize * .5,
        isLeft: true,
        ex: gateSizeExpand,
        intervalGate: intervalGate,
        displayText: questionsData[randomIndex][1],
      ),
    );
    add(
      GateObject(
        isTheAnswer: questionsData[randomIndex][3] == 'right',
        theSprite: gateSprite,
        initPosition: Vector2((size.x / 2) + 5, size.y / 2),
        initSize: gateSize * .5,
        isLeft: false,
        ex: gateSizeExpand,
        intervalGate: intervalGate,
        displayText: questionsData[randomIndex][2],
      ),
    );
  }

  void gameover() {
    overlays.remove('ButtonPause');
    overlays.add('Overlay');
    isGameOver = true;
    pauseEngine();
  }

  void resetGame() {
    isGameOver = false;
    scoreText.text = '0';
    gateSpawner.reset();
    player.position.x = size.x / 2;
    isFirstSpawn = true;
  }

  void pauseGame() {
    pauseEngine();
    overlays.remove('ButtonPause');
    overlays.add('Overlay');
  }

  void resumeGame() {
    resumeEngine();
    overlays.add('ButtonPause');
    overlays.remove('Overlay');
  }

  void answerCorrect() {
    nextRandomIndex = randomIndex;
    questionText.text = questionsData[nextRandomIndex][0];
    scoreText.text = (int.parse(scoreText.text) + 1).toString();
  }
}

class GateObject extends SpriteComponent with HasGameRef<GameplayFlame> {
  GateObject({
    required Sprite theSprite,
    required Vector2 initPosition,
    required Vector2 initSize,
    required this.isLeft,
    required this.ex,
    required this.intervalGate,
    required this.displayText,
    required this.isTheAnswer,
  }) : super(
          sprite: theSprite,
          position: initPosition,
          size: initSize,
          anchor: isLeft ? Anchor.centerRight : Anchor.centerLeft,
        );
  late EffectController ec;
  final Vector2 ex;
  final double intervalGate;
  final bool isLeft;
  bool isCollide = false;
  late TextComponent textComponent;
  final String displayText;
  final bool isTheAnswer;

  @override
  FutureOr<void> onLoad() {
    ec = EffectController(
      duration: intervalGate * 5,
      curve: Curves.fastOutSlowIn,
    );
    textComponent = TextComponent()
      ..textRenderer = TextPaint(
        style: const TextStyle(
          color: Color(0xff25253D),
        ),
      )
      ..text = displayText
      ..anchor = Anchor.center
      ..position = size / 2;
    add(SizeEffect.to(ex, ec));
    add(MoveEffect.by(Vector2(0, gameRef.size.y / 2), ec));
    add(textComponent);
    textComponent.add(
      ScaleEffect.to(Vector2(ex.x / size.x, ex.y / size.y), ec),
    );
    return super.onLoad();
  }

  @override
  void update(double dt) {
    textComponent.position = size / 2;
    if (ec.progress > 0.75) {
      print("JUST REMOVE HERE");
      sync.Timer(const Duration(milliseconds: 200), removeFromParent);
    } else if (ec.progress > 0.7 && !isCollide) {
      isCollide = true;
      priority = 1000;
      final playerAbs = gameRef.player.absoluteCenter.x;
      final l = playerAbs < (gameRef.size.x / 2) - ex.x / 6;
      final r = playerAbs > (gameRef.size.x / 2) + ex.x / 6;
      final isLeftSided = gameRef.player.absoluteCenter.x <= gameRef.size.x / 2;
      if (l || r) {
        if (isLeft && isLeftSided) {
          if (isTheAnswer) {
            game.answerCorrect();
          } else {
            print("SALAH NABRAK");
            game.gameover();
          }
        } else if (!isLeft && !isLeftSided) {
          if (isTheAnswer) {
            game.answerCorrect();
          } else {
            print("SALAH NABRAK");
            game.gameover();
          }
        }
      }
      sync.Timer(const Duration(milliseconds: 200), removeFromParent);
    }
    super.update(dt);
  }
}

import 'dart:async';
import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flame/input.dart';
import 'package:flutter/material.dart';
import 'dart:async' as sync;

void main() {
  runApp(
    GameWidget(
      game: GameplayFlame(),
      overlayBuilderMap: {
        "ButtonPause": (context, GameplayFlame game) {
          return Align(
            alignment: Alignment.topLeft,
            child: GestureDetector(
              onTap: () => game.pauseGame(),
              child: Container(
                margin: const EdgeInsets.only(top: 40, left: 10),
                child: Image.asset(
                  "assets/images/pause-button.png",
                  fit: BoxFit.cover,
                  height: 32,
                ),
              ),
            ),
          );
        },
        "Overlay": (context, GameplayFlame game) {
          return Center(
            child: GestureDetector(
              onTap: () => game.isGameOver ? game.resetGame() : game.resumeGame(),
              child: Image.asset(
                "assets/images/${game.isGameOver ? "gameover" : "pause"}-overlay.png",
                fit: BoxFit.cover,
                height: game.size.x * .6,
              ),
            ),
          );
        },
        "DisplayText": (context, GameplayFlame game) {
          return Positioned(
            top: 40,
            left: game.size.x * .2,
            child: Container(
              width: game.size.x * .6,
              height: game.size.x * .24,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: const BoxDecoration(
                image: DecorationImage(image: AssetImage("assets/images/text-area.png"), fit: BoxFit.cover),
              ),
              child: Center(
                child: Text(
                  game.displayText,
                  style: const TextStyle(
                    fontSize: 30,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          );
        },
      },
    ),
  );
}

class GameplayFlame extends FlameGame with PanDetector, HasCollisionDetection {
  double intervalGate = 8;
  late SpriteAnimationComponent player;
  late Sprite gateSprite;
  late Vector2 gateSize;
  late Vector2 gateSizeExpand;
  late Timer gateSpawner;
  String displayText = "0";
  int answerStrike = 0;
  bool isGameOver = false;

  @override
  Color backgroundColor() {
    return const Color(0xff25253D);
  }

  @override
  FutureOr<void> onLoad() async {
    /// Init Data
    gateSprite = await loadSprite('gate.png');
    gateSize = Vector2(size.x * .36, size.x * .2);
    gateSizeExpand = Vector2(size.x * .49, size.x * .49 * 20 / 36) * 1.5;
    overlays.addAll(["ButtonPause", "DisplayText"]);

    /// Background
    add(
      SpriteComponent(
        sprite: Sprite(await images.load("bg.png")),
        position: size / 2,
        size: size,
        anchor: Anchor.center,
      ),
    );

    /// Player
    player = SpriteAnimationComponent(
      animation: await loadSpriteAnimation(
        "player-sprite.png",
        SpriteAnimationData.sequenced(amount: 8, stepTime: .1, textureSize: Vector2.all(256)),
      ),
      position: Vector2(size.x / 2, size.y - size.x * .25),
      size: Vector2.all(size.x * .25),
      anchor: Anchor.center,
      priority: 999,
    );

    add(player);
    add(FpsTextComponent(position: Vector2(size.x, 40), anchor: Anchor.topRight, scale: Vector2.all(.5)));

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
      onTick: () => spawnGates(),
      repeat: true,
      autoStart: true,
    );
  }

  void spawnGates() {
    add(GateObject(
        isTheAnswer: true,
        theSprite: gateSprite,
        initPosition: Vector2((size.x / 2) - 5, size.y / 2),
        initSize: gateSize * .5,
        isLeft: true,
        expandSize: gateSizeExpand,
        intervalGate: intervalGate,
        displayText: ": 2"));

    add(GateObject(
        isTheAnswer: false,
        theSprite: gateSprite,
        initPosition: Vector2((size.x / 2) + 5, size.y / 2),
        initSize: gateSize * .5,
        isLeft: false,
        expandSize: gateSizeExpand,
        intervalGate: intervalGate,
        displayText: "x 2"));
  }

  void gameover() {
    overlays.add("Overlay");
    isGameOver = true;
    pauseEngine();
  }

  void resetGame() {
    isGameOver = false;
    answerStrike = 0;
    gateSpawner.reset();
    player.position.x = size.x / 2;
  }

  void pauseGame() {
    pauseEngine();
    overlays.remove("ButtonPause");
    overlays.add("Overlay");
  }

  void resumeGame() {
    resumeEngine();
    overlays.add("ButtonPause");
    overlays.remove("Overlay");
  }
}

class GateObject extends SpriteComponent with HasGameRef<GameplayFlame> {
  GateObject({
    required Sprite theSprite,
    required Vector2 initPosition,
    required Vector2 initSize,
    required this.isLeft,
    required this.expandSize,
    required this.intervalGate,
    required this.displayText,
    required this.isTheAnswer,
  }) : super(
          sprite: theSprite,
          position: initPosition,
          size: initSize,
          anchor: isLeft ? Anchor.centerRight : Anchor.centerLeft,
        );

  @override
  bool get debugMode => false;

  late EffectController effectController;

  final Vector2 expandSize;
  final double intervalGate;
  final bool isLeft;
  bool isCollide = false;
  late TextComponent textComponent;
  final String displayText;
  final bool isTheAnswer;

  @override
  FutureOr<void> onLoad() {
    effectController = EffectController(
      duration: intervalGate * 5,
      curve: Curves.fastOutSlowIn,
    );
    textComponent = TextComponent(
      text: displayText,
      textRenderer: TextPaint(style: const TextStyle(fontSize: 12, color: Color(0xff25253D))),
      anchor: Anchor.center,
      position: size / 2,
    );

    add(SizeEffect.to(expandSize, effectController));

    add(MoveEffect.by(
      Vector2(0, gameRef.size.y / 2),
      effectController,
    ));

    add(textComponent);
    textComponent.add(ScaleEffect.to(Vector2(expandSize.x / size.x, expandSize.y / size.y), effectController));

    return super.onLoad();
  }

  @override
  void update(double dt) {
    textComponent.position = size / 2;
    if (effectController.progress > 0.75) {
      removeFromParent();
    }

    if (effectController.progress > 0.7 && !isCollide) {
      checkCollision();
    }
    super.update(dt);
  }

  void checkCollision() {
    isCollide = true;
    priority = 1000;

    bool isWithinRangeLeft = gameRef.player.absoluteCenter.x > absoluteCenter.x - size.x * .25;
    bool isWithinRangeRight = gameRef.player.absoluteCenter.x < absoluteCenter.x + size.x * .25;

    if (isWithinRangeLeft && isWithinRangeRight) {
      if (isTheAnswer) {
        game.answerStrike++;
      } else {
        game.gameover();
      }
    }

    sync.Timer(const Duration(milliseconds: 200), () {
      removeFromParent();
    });
  }
}

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
      initialActiveOverlays: const [
        "ButtonPause",
      ],
      overlayBuilderMap: {
        "ButtonPause": (context, GameplayFlame game) {
          return Align(
            alignment: Alignment.topLeft,
            child: GestureDetector(
              onTap: () {
                game.pauseEngine();
                game.overlays.remove("ButtonPause");
                game.overlays.add("PauseOverlay");
              },
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
        "PauseOverlay": (context, GameplayFlame game) {
          return Center(
            child: GestureDetector(
              onTap: () {
                game.resumeEngine();
                game.overlays.add("ButtonPause");
                game.overlays.remove("PauseOverlay");
              },
              child: Image.asset(
                "assets/images/pause-overlay.png",
                fit: BoxFit.cover,
                height: game.size.x * .6,
              ),
            ),
          );
        }
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

  @override
  Color backgroundColor() {
    return const Color(0xff25253D);
  }

  @override
  FutureOr<void> onLoad() async {
    /// Init Data
    gateSprite = await loadSprite('gate.png');
    gateSize = Vector2(size.x * .36, size.x * .2);
    gateSizeExpand = Vector2(size.x * .49, size.x * .49 * 20 / 36);

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
    add(FpsTextComponent(position: Vector2(size.x, 40), anchor: Anchor.topRight));

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
      intervalGate,
      onTick: () => spawnGates(),
      repeat: true,
      autoStart: true,
    );
  }

  void spawnGates() {
    add(GateObject(
      gateSprite,
      Vector2((size.x / 2) - 5, size.y / 2),
      gateSize * .5,
      true,
      gateSizeExpand,
      intervalGate,
    ));

    add(GateObject(
      gateSprite,
      Vector2((size.x / 2) + 5, size.y / 2),
      gateSize * .5,
      false,
      gateSizeExpand,
      intervalGate,
    ));
  }
}

class GateObject extends SpriteComponent with HasGameRef<GameplayFlame> {
  GateObject(
    Sprite theSprite,
    Vector2 initPosition,
    Vector2 initSize,
    this.isLeft,
    this.expandSize,
    this.intervalGate,
  ) : super(
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

  @override
  FutureOr<void> onLoad() {
    effectController = EffectController(
      duration: intervalGate * 5,
      curve: Curves.fastOutSlowIn,
    );

    add(SizeEffect.to(expandSize, effectController));

    add(MoveEffect.by(
      Vector2(0, gameRef.size.y / 2),
      effectController,
    ));

    return super.onLoad();
  }

  @override
  void update(double dt) {
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
      if (isLeft) {
        print("NABRAK KIRI");
      } else {
        print("NABRAK KANAN");
      }
    }

    sync.Timer(const Duration(milliseconds: 200), () {
      removeFromParent();
    });
  }
}

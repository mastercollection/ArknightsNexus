import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../../domain/stage.dart';
import '../../i18n/nexus_i18n.dart';
import '../../ui/redesign/rd_widgets.dart';
import 'stage_enemy_view.dart';
import 'stage_format.dart';
import 'stage_playback.dart';

/// The map card of a stage: route filter, the map with the enemies' paths
/// and positions, and the playback controls over the spawn schedule.
class StagePlayer extends StatefulWidget {
  const StagePlayer({
    required this.detail,
    required this.code,
    required this.i18n,
    super.key,
  });

  final StageDetail detail;
  final String code;
  final NexusI18n i18n;

  @override
  State<StagePlayer> createState() => _StagePlayerState();
}

class _StagePlayerState extends State<StagePlayer>
    with SingleTickerProviderStateMixin {
  static const _speeds = [1.0, 2.0, 4.0];

  late StagePlayback _playback;
  late List<int> _laneOrder;
  late final Ticker _ticker;
  Duration _lastTick = Duration.zero;

  double _time = 0;
  double _speed = 1;
  bool _playing = false;

  /// Index into [StageDetail.lanes]; null shows every lane.
  int? _lane;

  /// The enemy whose details show under the playback, picked on the map
  /// or in the next spawns.
  String? _focus;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);
    _setDetail();
  }

  @override
  void didUpdateWidget(StagePlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.detail, widget.detail)) {
      _pause();
      _time = 0;
      _lane = null;
      _focus = null;
      _setDetail();
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _setDetail() {
    _playback = StagePlayback(widget.detail);
    _laneOrder = laneOrder(widget.detail.lanes);
  }

  void _onTick(Duration elapsed) {
    final delta = (elapsed - _lastTick).inMicroseconds / 1e6;
    _lastTick = elapsed;
    setState(() {
      _time = math.min(_time + delta * _speed, _playback.duration);
      if (_time >= _playback.duration) {
        _pause();
      }
    });
  }

  void _play() {
    if (_time >= _playback.duration) {
      _time = 0;
    }
    _lastTick = Duration.zero;
    _ticker.start();
    _playing = true;
  }

  void _pause() {
    if (_ticker.isActive) {
      _ticker.stop();
    }
    _playing = false;
  }

  void _toggle() => setState(() => _playing ? _pause() : _play());

  void _seek(double time) {
    setState(() => _time = time.clamp(0, _playback.duration).toDouble());
  }

  @override
  Widget build(BuildContext context) {
    final i18n = widget.i18n;
    final detail = widget.detail;
    final compact = context.rdLayout == RdLayout.compact;
    final enemies = _playback.enemiesAt(_time, laneIndex: _lane);
    final numbers = {
      for (final (rank, lane) in _laneOrder.indexed) lane: rank + 1,
    };
    final upcoming = _playback
        .spawnsAfter(_time)
        .where(
          (spawn) =>
              _lane == null || detail.paths[spawn.pathIndex].laneIndex == _lane,
        )
        .take(3)
        .toList();
    final enemyById = {
      for (final enemy in detail.enemies) enemy.enemyId: enemy,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (detail.lanes.isNotEmpty) ...[
          Semantics(
            container: true,
            label: i18n.t('stages.lanes'),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                RdChip(
                  label: i18n.t('stages.lane.all'),
                  trailing: _Count(
                    detail.lanes.fold(0, (sum, lane) => sum + lane.enemyCount),
                  ),
                  selected: _lane == null,
                  height: compact ? 36 : 32,
                  onPressed: () => setState(() => _lane = null),
                ),
                for (final index in _laneOrder)
                  RdChip(
                    label:
                        laneLabel(i18n, detail.lanes[index], numbers[index]!),
                    trailing: _Count(detail.lanes[index].enemyCount),
                    selected: _lane == index,
                    height: compact ? 36 : 32,
                    onPressed: () => setState(() => _lane = index),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
        Semantics(
          image: true,
          label: i18n.t('stages.mapLabel', {
            'code': widget.code,
            'time': formatStageTime(_time),
            'count': enemies.length,
          }),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final map = detail.map;
              final cell = map.width == 0
                  ? 0.0
                  : math.min(56.0, (constraints.maxWidth - 4) / map.width);
              // A tap picks the enemy nearest to it, within a tile.
              void pick(Offset local) {
                if (cell <= 0) {
                  return;
                }
                final col = (local.dx - 2) / cell - 0.5;
                final row = map.height - 1 - ((local.dy - 2) / cell - 0.5);
                EnemyOnMap? nearest;
                var best = 0.8;
                for (final enemy in enemies) {
                  final distance = math.sqrt(
                    math.pow(enemy.row - row, 2) + math.pow(enemy.col - col, 2),
                  );
                  if (distance < best) {
                    best = distance;
                    nearest = enemy;
                  }
                }
                if (nearest != null) {
                  setState(() => _focus = nearest!.spawn.enemyId);
                }
              }

              return Align(
                alignment: Alignment.centerLeft,
                child: GestureDetector(
                  onTapUp: (details) => pick(details.localPosition),
                  child: SizedBox(
                    width: cell * map.width + 4,
                    height: cell * map.height + 4,
                    child: CustomPaint(
                      painter: StageMapPainter(
                        detail: detail,
                        enemies: enemies,
                        lane: _lane,
                        laneNumbers: numbers,
                        focus: _focus,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            RdIconButton(
              icon: _playing ? Icons.pause : Icons.play_arrow,
              tooltip: i18n.t(_playing ? 'stages.pause' : 'stages.play'),
              active: true,
              onPressed: detail.spawns.isEmpty ? null : _toggle,
            ),
            const SizedBox(width: 12),
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: formatStageTime(_time)),
                  TextSpan(
                    text: ' / ${formatStageTime(_playback.duration)}',
                    style: RdText.mono(
                      fontSize: 14,
                      color: RdColors.muted,
                    ),
                  ),
                ],
              ),
              style: RdText.mono(fontSize: 15, fontWeight: FontWeight.w700),
            ),
            const Spacer(),
            SizedBox(
              width: _speeds.length * 52,
              child: RdSegmented<double>(
                semanticLabel: i18n.t('stages.speed'),
                height: compact ? 40 : 34,
                segments: [
                  for (final speed in _speeds)
                    RdSegment(speed, '${speed.toStringAsFixed(0)}×'),
                ],
                selected: _speed,
                onChanged: (speed) => setState(() => _speed = speed),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _Timeline(
          label: i18n.t('stages.position'),
          time: _time,
          duration: _playback.duration,
          spawnTimes: [for (final spawn in detail.spawns) spawn.time],
          onSeek: _seek,
        ),
        const SizedBox(height: 14),
        Text(i18n.t('stages.nextSpawns'), style: RdText.small),
        const SizedBox(height: 6),
        if (upcoming.isEmpty)
          Text(i18n.t('stages.noMoreSpawns'), style: RdText.muted)
        else
          for (final spawn in upcoming)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: _NextSpawn(
                onTap: () => setState(() => _focus = spawn.enemyId),
                selected: spawn.enemyId == _focus,
                time: formatStageTime(spawn.time),
                enemy: enemyById[spawn.enemyId],
                enemyId: spawn.enemyId,
                count: spawn.count,
                lane: laneLabel(
                  i18n,
                  detail.lanes[detail.paths[spawn.pathIndex].laneIndex],
                  numbers[detail.paths[spawn.pathIndex].laneIndex]!,
                ),
              ),
            ),
        if (enemyById[_focus] case final focused?) ...[
          const SizedBox(height: 6),
          StageEnemyDetails(
            i18n: i18n,
            enemy: focused,
            onClose: () => setState(() => _focus = null),
          ),
        ],
        const SizedBox(height: 10),
        _Legend(i18n: i18n),
        const SizedBox(height: 6),
        Text(i18n.t('stages.mapHint'), style: RdText.caption),
        const SizedBox(height: 8),
        Text(i18n.t('stages.estimate'), style: RdText.caption),
        if (detail.hasVariableSpawns) ...[
          const SizedBox(height: 4),
          Text(i18n.t('stages.variable'), style: RdText.caption),
        ],
      ],
    );
  }
}

class _Count extends StatelessWidget {
  const _Count(this.count);

  final int count;

  @override
  Widget build(BuildContext context) {
    return Text(
      '$count',
      style: RdText.mono(fontSize: 12, color: RdColors.muted),
    );
  }
}

class _NextSpawn extends StatelessWidget {
  const _NextSpawn({
    required this.onTap,
    required this.selected,
    required this.time,
    required this.enemy,
    required this.enemyId,
    required this.count,
    required this.lane,
  });

  final String time;
  final StageEnemy? enemy;
  final String enemyId;
  final int count;
  final String lane;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? RdColors.accentSoft : RdColors.surface3,
      borderRadius: BorderRadius.circular(RdRadii.control),
      child: InkWell(
        borderRadius: BorderRadius.circular(RdRadii.control),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            children: [
              SizedBox(
                width: 40,
                child: Text(
                  time,
                  style: RdText.mono(fontSize: 12, color: RdColors.secondary),
                ),
              ),
              if (enemy != null) ...[
                StageEnemyIcon(enemy: enemy!, size: 28),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Text(
                  '${enemy?.name ?? enemyId} ×$count',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13, color: RdColors.text),
                ),
              ),
              const SizedBox(width: 8),
              RdPill(label: lane),
            ],
          ),
        ),
      ),
    );
  }
}

/// A seek bar with a tick at every spawn.
class _Timeline extends StatelessWidget {
  const _Timeline({
    required this.label,
    required this.time,
    required this.duration,
    required this.spawnTimes,
    required this.onSeek,
  });

  final String label;
  final double time;
  final double duration;
  final List<double> spawnTimes;
  final ValueChanged<double> onSeek;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        void seekTo(double x) {
          if (duration > 0 && width > 0) {
            onSeek((x / width).clamp(0.0, 1.0) * duration);
          }
        }

        final step = math.max(1.0, duration / 20);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              slider: true,
              label: label,
              value: formatStageTime(time),
              increasedValue: formatStageTime(math.min(duration, time + step)),
              decreasedValue: formatStageTime(math.max(0, time - step)),
              onIncrease: () => onSeek(time + step),
              onDecrease: () => onSeek(time - step),
              child: Focus(
                onKeyEvent: (node, event) {
                  if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
                    return KeyEventResult.ignored;
                  }
                  if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
                    onSeek(time + step);
                    return KeyEventResult.handled;
                  }
                  if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
                    onSeek(time - step);
                    return KeyEventResult.handled;
                  }
                  return KeyEventResult.ignored;
                },
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapDown: (details) => seekTo(details.localPosition.dx),
                    onHorizontalDragUpdate: (details) =>
                        seekTo(details.localPosition.dx),
                    child: SizedBox(
                      height: 32,
                      child: CustomPaint(
                        painter: _TimelinePainter(
                          progress: duration <= 0 ? 0 : time / duration,
                          ticks: [
                            for (final spawnTime in spawnTimes)
                              duration <= 0 ? 0 : spawnTime / duration,
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Row(
              children: [
                Text(
                  '0:00',
                  style: RdText.mono(fontSize: 11, color: RdColors.muted),
                ),
                const Spacer(),
                Text(
                  formatStageTime(duration),
                  style: RdText.mono(fontSize: 11, color: RdColors.muted),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _TimelinePainter extends CustomPainter {
  const _TimelinePainter({required this.progress, required this.ticks});

  final double progress;
  final List<double> ticks;

  @override
  void paint(Canvas canvas, Size size) {
    final mid = size.height / 2;
    final track = RRect.fromLTRBR(
      0,
      mid - 3,
      size.width,
      mid + 3,
      const Radius.circular(3),
    );
    canvas.drawRRect(track, Paint()..color = RdColors.surface3);
    canvas.drawRRect(
      RRect.fromLTRBR(
        0,
        mid - 3,
        size.width * progress,
        mid + 3,
        const Radius.circular(3),
      ),
      Paint()..color = RdColors.accent,
    );
    for (final tick in ticks) {
      final x = size.width * tick;
      canvas.drawRRect(
        RRect.fromLTRBR(
          x - 1,
          mid - 9,
          x + 1,
          mid + 9,
          const Radius.circular(1),
        ),
        Paint()
          ..color = tick <= progress ? RdColors.accentHover : RdColors.handle,
      );
    }
    final thumb = Offset(size.width * progress, mid);
    canvas.drawCircle(thumb, 14, Paint()..color = RdColors.accentLine);
    canvas.drawCircle(thumb, 10, Paint()..color = RdColors.text);
  }

  @override
  bool shouldRepaint(_TimelinePainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.ticks != ticks;
}

class _Legend extends StatelessWidget {
  const _Legend({required this.i18n});

  final NexusI18n i18n;

  @override
  Widget build(BuildContext context) {
    Widget entry(String key, Widget swatch) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            swatch,
            const SizedBox(width: 6),
            Text(
              i18n.t(key),
              style: const TextStyle(fontSize: 12, color: RdColors.secondary),
            ),
          ],
        );
    Widget box(Color color, {Color? outline}) => Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
            border:
                outline == null ? null : Border.all(color: outline, width: 1.5),
          ),
        );
    return Wrap(
      spacing: 14,
      runSpacing: 6,
      children: [
        entry('stages.legend.ground', box(StageMapPainter.ground)),
        entry('stages.legend.highland', box(StageMapPainter.highland)),
        entry('stages.legend.blocked', box(StageMapPainter.floor)),
        entry(
          'stages.legend.gate',
          box(StageMapPainter.gateFill, outline: RdColors.danger),
        ),
        entry(
          'stages.legend.goal',
          box(StageMapPainter.goalFill, outline: RdColors.accent),
        ),
        entry('stages.legend.path', box(StageMapPainter.pathColor)),
        entry(
          'stages.legend.enemy',
          Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: RdColors.warning, width: 2),
            ),
          ),
        ),
      ],
    );
  }
}

/// Draws a stage map bottom row last (as the game shows it), the paths of
/// one lane or all, and the enemies at their positions.
class StageMapPainter extends CustomPainter {
  StageMapPainter({
    required this.detail,
    required this.enemies,
    required this.lane,
    required this.laneNumbers,
    this.focus,
  });

  static const ground = Color(0xFF2A303B);
  static const highland = Color(0xFF454E5E);
  static const floor = Color(0xFF1F242D);
  static const forbidden = Color(0xFF0F1217);
  static const gateFill = Color(0x38FF7A6B);
  static const goalFill = Color(0x3D7C8CFF);
  static const pathColor = Color(0x6BECEEF2);

  final StageDetail detail;
  final List<EnemyOnMap> enemies;
  final int? lane;
  final Map<int, int> laneNumbers;

  /// The picked enemy, whose tokens get a thicker ring.
  final String? focus;

  @override
  void paint(Canvas canvas, Size size) {
    final map = detail.map;
    if (map.width == 0 || map.height == 0) {
      return;
    }
    const inset = 2.0;
    final cell = (size.width - inset * 2) / map.width;
    Offset centre(double row, double col) => Offset(
          inset + (col + 0.5) * cell,
          inset + (map.height - 1 - row + 0.5) * cell,
        );
    Rect tileRect(int row, int col) => Rect.fromLTWH(
          inset + col * cell + 1,
          inset + (map.height - 1 - row) * cell + 1,
          cell - 2,
          cell - 2,
        );

    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(10)),
      Paint()..color = RdColors.bg,
    );
    final starts = <GridPosition, int>{};
    for (final (index, stageLane) in detail.lanes.indexed) {
      starts.putIfAbsent(stageLane.start, () => laneNumbers[index] ?? 0);
    }
    final devices = {for (final device in detail.devices) device.position};

    for (var row = 0; row < map.height; row++) {
      for (var col = 0; col < map.width; col++) {
        final position = GridPosition(row: row, col: col);
        final tile = map.tileAt(position);
        final rect = RRect.fromRectAndRadius(
          tileRect(row, col),
          Radius.circular(cell * 0.08),
        );
        final key = tile.tileKey;
        Color fill;
        Color? outline;
        if (key.contains('start')) {
          fill = gateFill;
          outline = RdColors.danger;
        } else if (key.contains('end') || key.contains('goal')) {
          fill = goalFill;
          outline = RdColors.accent;
        } else if (key == 'tile_forbidden' ||
            key == 'tile_empty' ||
            tile.passableMask == 'NONE' ||
            (tile.passableMask == 'FLY_ONLY' && !tile.isHighland)) {
          fill = forbidden;
        } else if (tile.isHighland) {
          fill = highland;
        } else if (tile.buildableType == 'NONE') {
          fill = floor;
        } else {
          fill = ground;
        }
        canvas.drawRRect(rect, Paint()..color = fill);
        if (outline != null) {
          canvas.drawRRect(
            rect.deflate(0.75),
            Paint()
              ..color = outline
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.5,
          );
        }
        if (devices.contains(position)) {
          canvas.drawRRect(
            rect.deflate(0.75),
            Paint()
              ..color = RdColors.warningText
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.5,
          );
        }
        final number = starts[position];
        if (number != null && number > 0) {
          _label(
            canvas,
            '$number',
            centre(row.toDouble(), col.toDouble()),
            cell * 0.32,
            RdColors.dangerText,
          );
        }
      }
    }

    // Paths, faint for every lane, stronger for the chosen one.
    final drawn = <int>{};
    for (final (index, path) in detail.paths.indexed) {
      if (lane != null && path.laneIndex != lane) {
        continue;
      }
      if (!drawn.add(index) || path.steps.isEmpty) {
        continue;
      }
      final line = Path();
      for (final (i, step) in path.steps.indexed) {
        final point = centre(
          step.position.row.toDouble(),
          step.position.col.toDouble(),
        );
        if (i == 0 || step.jump) {
          line.moveTo(point.dx, point.dy);
        } else {
          line.lineTo(point.dx, point.dy);
        }
      }
      canvas.drawPath(
        line,
        Paint()
          ..color = lane == null ? pathColor.withAlpha(0x55) : pathColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(1.5, cell * 0.06)
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
    }

    final radius = math.max(7.0, cell * 0.34);
    for (final enemy in enemies) {
      final point = centre(enemy.row, enemy.col);
      final color = switch (enemy.enemy?.levelType) {
        'BOSS' => RdColors.danger,
        'ELITE' => RdColors.accentHover,
        _ => RdColors.warning,
      };
      final focused = enemy.spawn.enemyId == focus;
      if (focused) {
        canvas.drawCircle(
          point,
          radius + 4,
          Paint()..color = RdColors.accentLine,
        );
      }
      canvas.drawCircle(point, radius, Paint()..color = RdColors.surface2);
      canvas.drawCircle(
        point,
        radius - 1,
        Paint()
          ..color = focused ? RdColors.text : color
          ..style = PaintingStyle.stroke
          ..strokeWidth = focused ? 3 : 2,
      );
      final label = enemy.enemy?.enemyIndex ?? '';
      if (label.isNotEmpty && radius >= 10) {
        _label(canvas, label, point, radius * 0.62, RdColors.text);
      }
    }
  }

  void _label(
    Canvas canvas,
    String text,
    Offset centre,
    double size,
    Color color,
  ) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: RdText.mono(
          fontSize: size,
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    painter.paint(
      canvas,
      centre - Offset(painter.width / 2, painter.height / 2),
    );
  }

  @override
  bool shouldRepaint(StageMapPainter oldDelegate) =>
      oldDelegate.detail != detail ||
      oldDelegate.enemies != enemies ||
      oldDelegate.lane != lane ||
      oldDelegate.laneNumbers != laneNumbers ||
      oldDelegate.focus != focus;
}

/// Penguin Stats drop matrix domain model, ported from the Tauri
/// implementation in `src/services/operators.ts`.
library;

/// Penguin Stats server regions.
enum PenguinServer {
  cn('CN'),
  us('US'),
  jp('JP'),
  kr('KR');

  const PenguinServer(this.value);

  final String value;
}

/// A single stage drop entry for an item from Penguin Stats.
class PenguinMatrixEntry {
  const PenguinMatrixEntry({
    required this.stageId,
    required this.itemId,
    required this.quantity,
    required this.times,
    required this.dropRate,
    this.start,
    this.end,
  });

  final String stageId;
  final String itemId;
  final int quantity;
  final int times;
  final double dropRate;
  final int? start;
  final int? end;
}

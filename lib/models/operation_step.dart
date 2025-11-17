import 'apdu_response.dart';

/// Operation Step Model
/// Represents a single step in a multi-step smartcard operation
class OperationStep {
  /// Step number in the operation sequence
  final int stepNumber;
  
  /// Human-readable step name
  final String stepName;
  
  /// APDU command sent
  final String commandApdu;
  
  /// Response received
  final ApduResponse response;
  
  /// Duration of the operation
  final Duration duration;
  
  /// Additional notes or context
  final String? notes;

  OperationStep({
    required this.stepNumber,
    required this.stepName,
    required this.commandApdu,
    required this.response,
    required this.duration,
    this.notes,
  });

  /// Whether this step was successful
  bool get isSuccess => response.success;

  /// Format command with spaces
  String get formattedCommand {
    final clean = commandApdu.replaceAll(' ', '').toUpperCase();
    final buffer = StringBuffer();
    for (int i = 0; i < clean.length; i += 2) {
      if (i > 0) buffer.write(' ');
      if (i + 2 <= clean.length) {
        buffer.write(clean.substring(i, i + 2));
      }
    }
    return buffer.toString();
  }

  @override
  String toString() {
    return 'Step $stepNumber: $stepName - ${response.success ? "✓" : "✗"} (${duration.inMilliseconds}ms)';
  }
}

/// Operation Log Model
/// Represents a complete multi-step operation with all its steps
class OperationLog {
  /// Unique operation ID
  final String id;
  
  /// Operation name
  final String name;
  
  /// All steps in the operation
  final List<OperationStep> steps;
  
  /// Start time
  final DateTime startTime;
  
  /// End time
  final DateTime? endTime;
  
  /// Whether the entire operation was successful
  final bool success;

  OperationLog({
    required this.id,
    required this.name,
    required this.steps,
    required this.startTime,
    this.endTime,
    required this.success,
  });

  /// Total duration of the operation
  Duration get totalDuration {
    if (endTime == null) return Duration.zero;
    return endTime!.difference(startTime);
  }

  /// Number of successful steps
  int get successfulSteps => steps.where((s) => s.isSuccess).length;

  /// Number of failed steps
  int get failedSteps => steps.where((s) => !s.isSuccess).length;

  @override
  String toString() {
    return 'Operation: $name - ${success ? "✓" : "✗"} ($successfulSteps/${ steps.length} steps, ${totalDuration.inMilliseconds}ms)';
  }
}

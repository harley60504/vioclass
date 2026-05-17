import 'package:flutter/foundation.dart';

/// Development-only probe service for Twitch prediction realtime experiments.
///
/// This file is intentionally lightweight for now. It lets
/// `twitch_prediction_probe_sheet.dart` compile and gives the debug sheet a
/// stable controller shape before the real Hermes implementation is added.
class TwitchPredictionProbeService extends ChangeNotifier {
  final List<String> _logs = <String>[];
  final List<TwitchPredictionProbeEvent> _events = <TwitchPredictionProbeEvent>[];

  bool _hermesConnected = false;
  String _statusText = 'Hermes 尚未啟用';
  String? _errorText;

  bool get hermesConnected => _hermesConnected;
  String get statusText => _statusText;
  String? get errorText => _errorText;

  List<String> get logs => List<String>.unmodifiable(_logs);
  List<TwitchPredictionProbeEvent> get events =>
      List<TwitchPredictionProbeEvent>.unmodifiable(_events);

  void reconnect() {
    _hermesConnected = false;
    _statusText = 'Hermes 尚未接線，等待 Stage 119 實作';
    _errorText = null;
    addLog('Prediction Probe reconnect requested, but Hermes transport is not implemented yet.');
  }

  void setConnected(bool value, {String? statusText}) {
    _hermesConnected = value;
    _statusText = statusText ?? (value ? 'Hermes 已連線' : 'Hermes 未連線');
    _errorText = null;
    notifyListeners();
  }

  void setError(Object error) {
    _hermesConnected = false;
    _errorText = error.toString();
    _statusText = 'Prediction Probe 發生錯誤';
    addLog('ERROR: $_errorText');
  }

  void addLog(String message) {
    final now = DateTime.now().toIso8601String();
    _logs.add('[$now] $message');
    if (_logs.length > 240) {
      _logs.removeRange(0, _logs.length - 240);
    }
    notifyListeners();
  }

  void addEvent(TwitchPredictionProbeEvent event) {
    _events.add(event);
    if (_events.length > 120) {
      _events.removeRange(0, _events.length - 120);
    }
    notifyListeners();
  }

  void clear() {
    _logs.clear();
    _events.clear();
    _errorText = null;
    notifyListeners();
  }
}

class TwitchPredictionProbeEvent {
  final String? topic;
  final String? type;
  final TwitchPredictionProbeSummary summary;

  const TwitchPredictionProbeEvent({
    this.topic,
    this.type,
    this.summary = const TwitchPredictionProbeSummary(),
  });
}

class TwitchPredictionProbeSummary {
  final String? title;
  final String? status;
  final int? totalPoints;
  final int? totalUsers;
  final List<TwitchPredictionProbeOutcome> outcomes;

  const TwitchPredictionProbeSummary({
    this.title,
    this.status,
    this.totalPoints,
    this.totalUsers,
    this.outcomes = const <TwitchPredictionProbeOutcome>[],
  });
}

class TwitchPredictionProbeOutcome {
  final String? id;
  final String? title;
  final int? points;
  final int? users;
  final String? odds;
  final bool? winner;

  const TwitchPredictionProbeOutcome({
    this.id,
    this.title,
    this.points,
    this.users,
    this.odds,
    this.winner,
  });
}

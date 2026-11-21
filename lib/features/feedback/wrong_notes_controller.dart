import 'dart:async';

import 'package:flutter/foundation.dart';

import 'domain/wrong_notes.dart';

enum WrongNotesSaveState { clean, saving, failed }

/// Editor state for one attempt's wrong-answer bullets.
///
/// Rows may be empty while editing; only [WrongNotes.format] is persisted.
/// Edits save after a short debounce and [flush] forces the pending save.
class WrongNotesController extends ChangeNotifier {
  WrongNotesController({
    required Iterable<String> initial,
    required this.onSave,
    this.debounce = const Duration(milliseconds: 600),
  }) : _rows = _initialRows(initial) {
    _saved = WrongNotes.format(_rows);
  }

  static const int maxRows = WrongNotes.maxNotes;
  static const int maxLength = WrongNotes.maxNoteLength;

  final Future<void> Function(List<String> notes) onSave;
  final Duration debounce;
  final List<String> _rows;

  Timer? _timer;
  bool _saving = false;
  bool _failed = false;
  bool _disposed = false;
  String _saved = '';

  List<String> get rows => List<String>.unmodifiable(_rows);
  WrongNotesSaveState get saveState => _saving
      ? WrongNotesSaveState.saving
      : _failed
      ? WrongNotesSaveState.failed
      : WrongNotesSaveState.clean;
  bool get canAddRow => _rows.length < maxRows;
  String get canonical => WrongNotes.format(_rows);
  bool get isDirty => canonical != _saved;

  static List<String> _initialRows(Iterable<String> initial) {
    final parsed = WrongNotes.normalize(initial);
    return parsed.isEmpty ? <String>[''] : parsed;
  }

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  void setRow(int index, String value) {
    if (index < 0 || index >= _rows.length) return;
    final capped = value.length > maxLength
        ? value.substring(0, maxLength)
        : value;
    if (_rows[index] == capped) return;
    _rows[index] = capped;
    _failed = false;
    scheduleSave();
    notifyListeners();
  }

  void replaceRow(int index, String value) => setRow(index, value);

  void insertRows(int index, Iterable<String> values) {
    final room = maxRows - _rows.length;
    if (room <= 0) return;
    final clean = <String>[for (final value in values) _cleanInput(value)]
        .take(room)
        .toList();
    if (clean.isEmpty) return;
    final at = index.clamp(0, _rows.length);
    _rows.insertAll(at, clean);
    _failed = false;
    scheduleSave();
    notifyListeners();
  }

  void addRow() {
    if (!canAddRow) return;
    _rows.add('');
    notifyListeners();
  }

  void removeRow(int index) {
    if (index < 0 || index >= _rows.length) return;
    if (_rows.length == 1) {
      _rows[0] = '';
    } else {
      _rows.removeAt(index);
    }
    _failed = false;
    scheduleSave();
    notifyListeners();
  }

  /// Drops an empty row on blur, unless it is the only one.
  void dropEmptyRow(int index) {
    if (index < 0 || index >= _rows.length || _rows.length == 1) return;
    if (_rows[index].trim().isNotEmpty) return;
    _rows.removeAt(index);
    notifyListeners();
  }

  void scheduleSave() {
    _timer?.cancel();
    _timer = Timer(debounce, () => unawaited(save()));
  }

  /// Saves now, cancelling the pending debounce.
  Future<bool> flush() async {
    _timer?.cancel();
    _timer = null;
    return save();
  }

  Future<bool> save() async {
    if (_saving) return !_failed;
    if (!isDirty) return true;
    _saving = true;
    _failed = false;
    notifyListeners();
    final notes = _rows.map((row) => row.trim()).toList(growable: false);
    final canonical = WrongNotes.format(notes);
    try {
      await onSave(notes);
      _saved = canonical;
      _saving = false;
      _failed = false;
      notifyListeners();
      return true;
    } on Object {
      _saving = false;
      _failed = true;
      notifyListeners();
      return false;
    }
  }

  String _cleanInput(String value) {
    final stripped = WrongNotes.stripMarker(value);
    return stripped.length > maxLength
        ? stripped.substring(0, maxLength)
        : stripped;
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    super.dispose();
  }
}

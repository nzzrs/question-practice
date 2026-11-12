import 'package:meta/meta.dart';

/// The field used to order a list of topics or practices.
enum ListSortField { name, recency }

/// The direction applied after the field comparison.
enum ListSortDirection { increasing, decreasing }

/// A persisted list order, shared by the Home topic list and each topic's
/// practice list.
@immutable
class ListSort {
  const ListSort({required this.field, required this.direction});

  /// The default order used when a list has no saved sort.
  static const defaultByName = ListSort(
    field: ListSortField.name,
    direction: ListSortDirection.increasing,
  );

  final ListSortField field;
  final ListSortDirection direction;

  ListSort copyWith({ListSortField? field, ListSortDirection? direction}) {
    return ListSort(
      field: field ?? this.field,
      direction: direction ?? this.direction,
    );
  }

  /// Stable text form stored in the settings table.
  String encode() => '${field.name}:${direction.name}';

  /// Decodes a stored value, returning null for an absent or invalid value.
  static ListSort? tryDecode(String? raw) {
    if (raw == null) return null;
    final parts = raw.split(':');
    if (parts.length != 2) return null;
    final field = _fieldByName(parts[0]);
    final direction = _directionByName(parts[1]);
    if (field == null || direction == null) return null;
    return ListSort(field: field, direction: direction);
  }

  static ListSortField? _fieldByName(String name) {
    for (final value in ListSortField.values) {
      if (value.name == name) return value;
    }
    return null;
  }

  static ListSortDirection? _directionByName(String name) {
    for (final value in ListSortDirection.values) {
      if (value.name == name) return value;
    }
    return null;
  }

  @override
  bool operator ==(Object other) {
    return other is ListSort &&
        other.field == field &&
        other.direction == direction;
  }

  @override
  int get hashCode => Object.hash(field, direction);

  @override
  String toString() => 'ListSort(${field.name}, ${direction.name})';
}

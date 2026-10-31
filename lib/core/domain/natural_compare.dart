/// Compares text so numbers sort by value instead of by character.
///
/// For example, "practice 2" comes before "practice 12".
int compareNatural(String a, String b) {
  final left = a.toLowerCase();
  final right = b.toLowerCase();
  var i = 0;
  var j = 0;
  while (i < left.length && j < right.length) {
    final leftIsDigit = _isDigit(left.codeUnitAt(i));
    final rightIsDigit = _isDigit(right.codeUnitAt(j));
    if (leftIsDigit && rightIsDigit) {
      final leftStart = i;
      final rightStart = j;
      while (i < left.length && _isDigit(left.codeUnitAt(i))) {
        i++;
      }
      while (j < right.length && _isDigit(right.codeUnitAt(j))) {
        j++;
      }
      final leftNumber = _trimLeadingZeros(left.substring(leftStart, i));
      final rightNumber = _trimLeadingZeros(right.substring(rightStart, j));
      if (leftNumber.length != rightNumber.length) {
        return leftNumber.length.compareTo(rightNumber.length);
      }
      final numeric = leftNumber.compareTo(rightNumber);
      if (numeric != 0) return numeric;
    } else {
      final leftCode = left.codeUnitAt(i);
      final rightCode = right.codeUnitAt(j);
      if (leftCode != rightCode) return leftCode.compareTo(rightCode);
      i++;
      j++;
    }
  }
  return (left.length - i).compareTo(right.length - j);
}

bool _isDigit(int codeUnit) => codeUnit >= 0x30 && codeUnit <= 0x39;

String _trimLeadingZeros(String value) {
  var index = 0;
  while (index < value.length - 1 && value.codeUnitAt(index) == 0x30) {
    index++;
  }
  return value.substring(index);
}

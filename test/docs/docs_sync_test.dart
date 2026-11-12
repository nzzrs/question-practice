import 'package:flutter_test/flutter_test.dart';

import '../../tool/docs/update_docs.dart' as docs;

void main() {
  test('database documentation is generated from the current schema', () {
    final root = docs.findProjectRoot();
    final issues = docs.checkDocs(root);

    expect(
      issues,
      isEmpty,
      reason:
          'docs/database.md must match lib/core/database/tables.dart and '
          'app_database.dart. Run: dart run tool/docs/update_docs.dart',
    );
  });
}

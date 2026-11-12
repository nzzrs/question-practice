// Regenerates the database reference sections in docs/database.md.
//
// The generator reads the real Drift table definitions in
// lib/core/database/tables.dart and the schema version, migrations and custom
// indexes in lib/core/database/app_database.dart. It intentionally has no
// analyzer dependency: small, explicit parsers fail loudly when the code uses
// a construct this tool does not understand, rather than silently producing a
// stale map.
//
// Usage:
//   dart run tool/docs/update_docs.dart
//   dart run tool/docs/update_docs.dart --check
//
// The --check form exits with code 1 when docs/database.md differs from the
// generated output. `test/docs/docs_sync_test.dart`, CI and the tracked
// pre-push hook use it to keep the documentation in step with the schema.

import 'dart:io';

const databaseDocPath = 'docs/database.md';

const _markers = <String>['database', 'migrations', 'backup'];

void main(List<String> args) {
  final check = args.length == 1 && args.single == '--check';
  if (args.isNotEmpty && !check) {
    stderr.writeln('Usage: dart run tool/docs/update_docs.dart [--check]');
    exitCode = 64;
    return;
  }

  try {
    final root = findProjectRoot();
    if (check) {
      final issues = checkDocs(root);
      if (issues.isEmpty) {
        stdout.writeln('Documentation is in sync with the database code.');
        return;
      }
      stderr.writeln('Documentation is out of sync with the database code:');
      for (final issue in issues) {
        stderr.writeln('  - $issue');
      }
      stderr.writeln('Run: dart run tool/docs/update_docs.dart');
      exitCode = 1;
      return;
    }

    updateDocs(root);
    stdout.writeln('Updated generated sections in $databaseDocPath.');
  } on FormatException catch (error) {
    stderr.writeln('Documentation generator failed: ${error.message}');
    exitCode = 1;
  } on FileSystemException catch (error) {
    stderr.writeln('Documentation generator failed: ${error.message}');
    exitCode = 1;
  }
}

/// Finds the repository root from the current directory or this script.
Directory findProjectRoot([Directory? start]) {
  var directory = (start ?? Directory.current).absolute;
  while (true) {
    if (_isProjectRoot(directory)) return directory;
    final parent = directory.parent;
    if (parent.path == directory.path) break;
    directory = parent;
  }

  var scriptDirectory = File.fromUri(Platform.script).absolute.parent;
  while (true) {
    if (_isProjectRoot(scriptDirectory)) return scriptDirectory;
    final parent = scriptDirectory.parent;
    if (parent.path == scriptDirectory.path) break;
    scriptDirectory = parent;
  }
  throw const FormatException(
    'Could not find the project root (lib/core/database/tables.dart).',
  );
}

bool _isProjectRoot(Directory directory) {
  return File('${directory.path}/lib/core/database/tables.dart').existsSync() &&
      File('${directory.path}/pubspec.yaml').existsSync();
}

/// Returns the documentation files whose generated sections are stale.
List<String> checkDocs(Directory root) {
  final doc = File('${root.path}/$databaseDocPath');
  if (!doc.existsSync()) {
    return ['Missing $databaseDocPath.'];
  }
  final current = doc.readAsStringSync();
  final generated = buildGeneratedSections(root);
  final issues = <String>[];

  for (final marker in _markers) {
    final expected = generated[marker];
    if (expected == null) {
      issues.add('No generator output for marker "$marker".');
      continue;
    }
    final actual = _sectionBody(current, marker);
    if (actual == null) {
      issues.add('Missing generated marker "$marker" in $databaseDocPath.');
      continue;
    }
    if (actual != '\n$expected\n') {
      issues.add(
        'Generated section "$marker" in $databaseDocPath does not match '
        'the current database code.',
      );
    }
  }
  return issues;
}

/// Rewrites the generated sections in docs/database.md in place.
void updateDocs(Directory root) {
  final doc = File('${root.path}/$databaseDocPath');
  if (!doc.existsSync()) {
    throw FormatException('Missing $databaseDocPath.');
  }
  final generated = buildGeneratedSections(root);
  var text = doc.readAsStringSync();
  for (final marker in _markers) {
    final content = generated[marker];
    if (content == null) {
      throw FormatException('No generator output for marker "$marker".');
    }
    text = _replaceSection(text, marker, content);
  }
  doc.writeAsStringSync(text);
}

/// Builds every generated markdown block, in marker order.
Map<String, String> buildGeneratedSections(Directory root) {
  final schema = parseSchema(root);
  final backup = parseBackupCoverage(root, schema);

  return {
    'database': _databaseMarkdown(schema),
    'migrations': _migrationsMarkdown(schema),
    'backup': _backupMarkdown(backup),
  };
}

// ---------------------------------------------------------------------------
// Schema parsing
// ---------------------------------------------------------------------------

class SchemaModel {
  SchemaModel({
    required this.version,
    required this.tables,
    required this.migrations,
    required this.extraIndexes,
    required this.daosByTable,
  });

  final int version;
  final List<TableSchema> tables;
  final List<MigrationStep> migrations;
  final List<TableIndexSchema> extraIndexes;
  final Map<String, List<String>> daosByTable;

  late final Map<String, TableSchema> bySqlName = {
    for (final table in tables) table.sqlName: table,
  };
  late final Map<String, TableSchema> byClassName = {
    for (final table in tables) table.className: table,
  };
}

class TableSchema {
  TableSchema({
    required this.className,
    required this.sqlName,
    required this.rowClass,
    required this.columns,
    required this.primaryKey,
    required this.uniqueKeys,
    required this.indexes,
  });

  final String className;
  final String sqlName;
  final String rowClass;
  final List<ColumnSchema> columns;
  final List<String> primaryKey;
  final List<List<String>> uniqueKeys;
  final List<TableIndexSchema> indexes;

  late final Map<String, ColumnSchema> byName = {
    for (final column in columns) column.name: column,
  };
  late final Map<String, ColumnSchema> bySqlName = {
    for (final column in columns) column.sqlName: column,
  };
}

class ColumnSchema {
  ColumnSchema({
    required this.name,
    required this.sqlName,
    required this.driftType,
    required this.sqlType,
    required this.nullable,
    required this.defaultValue,
    required this.autoIncrement,
    required this.length,
    required this.reference,
  });

  final String name;
  final String sqlName;
  final String driftType;
  final String sqlType;
  final bool nullable;
  final String? defaultValue;
  final bool autoIncrement;
  final String? length;
  final ColumnReference? reference;
}

class ColumnReference {
  ColumnReference({
    required this.tableClass,
    required this.columnName,
    required this.onDelete,
  });

  final String tableClass;
  final String columnName;
  final String onDelete;
  late String tableSqlName;
  late String columnSqlName;
}

class TableIndexSchema {
  const TableIndexSchema({
    required this.name,
    required this.tableSqlName,
    required this.columns,
    this.unique = false,
    this.where,
  });

  final String name;
  final String tableSqlName;
  final List<String> columns;
  final bool unique;
  final String? where;
}

class MigrationStep {
  const MigrationStep({
    required this.version,
    required this.changes,
    required this.createdTables,
  });

  final int version;
  final List<String> changes;
  final Set<String> createdTables;
}

SchemaModel parseSchema(Directory root) {
  final source = _stripComments(
    _read('${root.path}/lib/core/database/tables.dart'),
  );
  final databaseSource = _stripComments(
    _read('${root.path}/lib/core/database/app_database.dart'),
  );
  final modelSource = _stripComments(
    _read('${root.path}/lib/core/domain/models.dart'),
  );

  final versionMatch = RegExp(r'int\s+get\s+schemaVersion\s*=>\s*(\d+)\s*;')
      .firstMatch(databaseSource);
  if (versionMatch == null) {
    throw const FormatException(
      'Could not read AppDatabase.schemaVersion from app_database.dart.',
    );
  }
  final version = int.parse(versionMatch.group(1)!);

  final classBlocks = _tableClassBlocks(source);
  if (classBlocks.isEmpty) {
    throw const FormatException(
      'No "class ... extends Table" declarations found in tables.dart.',
    );
  }

  final tables = <TableSchema>[];
  for (final block in classBlocks) {
    tables.add(_parseTable(block));
  }
  _validateUniqueTableNames(tables);

  _resolveReferences(tables);
  _requireDocumentedColumns(tables);

  final extraIndexes = _parseCustomIndexes(databaseSource, tables);
  final migrations = _parseMigrations(databaseSource, version, tables);

  _validateTableDocs(tables, modelSource);
  final daosByTable = _parseDaos(root, tables);

  return SchemaModel(
    version: version,
    tables: tables,
    migrations: migrations,
    extraIndexes: extraIndexes,
    daosByTable: daosByTable,
  );
}

class _ClassBlock {
  const _ClassBlock({
    required this.className,
    required this.block,
    required this.prefix,
  });

  final String className;
  final String block;
  final String prefix;
}

List<_ClassBlock> _tableClassBlocks(String source) {
  final blocks = <_ClassBlock>[];
  final regex = RegExp(r'class\s+([A-Za-z_]\w*)\s+extends\s+Table\s*\{');
  var searchStart = 0;
  var previousEnd = -1;

  while (true) {
    final match = regex.firstMatch(source.substring(searchStart));
    if (match == null) break;
    final absoluteStart = searchStart + match.start;
    final openBrace = searchStart + match.end - 1;
    final closeBrace = _findMatching(source, openBrace, '{', '}');
    final prefix = source.substring(previousEnd + 1, absoluteStart);
    blocks.add(
      _ClassBlock(
        className: match.group(1)!,
        block: source.substring(openBrace + 1, closeBrace),
        prefix: prefix,
      ),
    );
    previousEnd = closeBrace;
    searchStart = closeBrace + 1;
  }
  return blocks;
}

TableSchema _parseTable(_ClassBlock classBlock) {
  final className = classBlock.className;
  final dataClassMatch = RegExp(r"@DataClassName\(\s*'([^']+)'\s*\)")
      .firstMatch(classBlock.prefix);
  final rowClass = dataClassMatch?.group(1) ?? className;

  final tableNameMatch = RegExp(
    r"String\s+get\s+tableName\s*=>\s*'([^']+)'\s*;",
  ).firstMatch(classBlock.block);
  if (classBlock.block.contains('get tableName') && tableNameMatch == null) {
    throw FormatException(
      'Could not read tableName on $className. Drift requires a string '
      'literal; teach the generator about the new form.',
    );
  }
  final sqlName = tableNameMatch?.group(1) ?? _snakeCase(className);

  final indexes = <TableIndexSchema>[];
  final indexAnnotationCount = RegExp(r'@TableIndex\b')
      .allMatches(classBlock.prefix)
      .length;
  if (RegExp(r'@TableIndex\s*\.\s*sql|IndexedColumn')
      .hasMatch(classBlock.prefix)) {
    throw FormatException(
      'Table $className uses a @TableIndex form this generator cannot read '
      '(TableIndex.sql or IndexedColumn).',
    );
  }
  final indexRegex = RegExp(
    r"@TableIndex\(\s*name:\s*'([^']+)'\s*,\s*columns:\s*\{([^}]*)\}\s*\)",
  );
  for (final match in indexRegex.allMatches(classBlock.prefix)) {
    final columns = [
      for (final columnMatch in RegExp(
        r'#([A-Za-z_]\w*)',
      ).allMatches(match.group(2)!))
        columnMatch.group(1)!,
    ];
    if (columns.isEmpty) {
      throw FormatException(
        'TableIndex "${match.group(1)}" on $className has no columns.',
      );
    }
    indexes.add(
      TableIndexSchema(
        name: match.group(1)!,
        tableSqlName: sqlName,
        columns: columns,
      ),
    );
  }
  if (indexes.length != indexAnnotationCount) {
    throw FormatException(
      'Table $className has $indexAnnotationCount @TableIndex annotations but '
      'only ${indexes.length} could be read. Use the supported name/columns '
      'form or teach the generator about the new options.',
    );
  }

  final columns = <ColumnSchema>[];
  final columnRegex = RegExp(
    r'([A-Za-z_]\w*Column)\s+get\s+([A-Za-z_]\w*)\s*=>',
  );
  for (final match in columnRegex.allMatches(classBlock.block)) {
    final expressionStart = match.end;
    final expressionEnd = _findStatementEnd(classBlock.block, expressionStart);
    final expression = classBlock.block
        .substring(expressionStart, expressionEnd)
        .trim();
    columns.add(_parseColumn(className, match.group(2)!, expression));
  }
  final declaredColumns = RegExp(
    r'([A-Za-z_]\w*Column)\s+get\s+[A-Za-z_]\w*\s*=>',
  ).allMatches(classBlock.block).length;
  if (declaredColumns != columns.length) {
    throw FormatException(
      'Table $className declares $declaredColumns column getters but only '
      '${columns.length} could be parsed.',
    );
  }
  if (columns.isEmpty) {
    throw FormatException('Table $className has no columns.');
  }

  final primaryKey = <String>[];
  final primaryKeyMatch = RegExp(
    r'Set<Column>\s+get\s+primaryKey\s*=>\s*\{([^}]*)\}',
  ).firstMatch(classBlock.block);
  if (classBlock.block.contains('get primaryKey') && primaryKeyMatch == null) {
    throw FormatException(
      'Could not read primaryKey on $className. Use a set literal of column '
      'getters.',
    );
  }
  if (primaryKeyMatch != null) {
    primaryKey.addAll(_identifiers(primaryKeyMatch.group(1)!));
  }

  final uniqueKeys = <List<String>>[];
  final uniqueKeysMatch = RegExp(
    r'List<Set<Column>>\s+get\s+uniqueKeys\s*=>\s*\[([\s\S]*?)\]\s*;',
  ).firstMatch(classBlock.block);
  if (classBlock.block.contains('get uniqueKeys') && uniqueKeysMatch == null) {
    throw FormatException(
      'Could not read uniqueKeys on $className. Use a list of set literals '
      'of column getters.',
    );
  }
  if (uniqueKeysMatch != null) {
    for (final setMatch in RegExp(
      r'\{([^}]*)\}',
    ).allMatches(uniqueKeysMatch.group(1)!)) {
      uniqueKeys.add(_identifiers(setMatch.group(1)!));
    }
  }

  final autoIncrementColumns = [
    for (final column in columns)
      if (column.autoIncrement) column.name,
  ];
  if (primaryKey.isEmpty && autoIncrementColumns.length == 1) {
    primaryKey.add(autoIncrementColumns.single);
  }
  if (primaryKey.isEmpty && autoIncrementColumns.isEmpty) {
    throw FormatException(
      'Table $className has neither an auto-increment primary key nor a '
      'primaryKey override.',
    );
  }
  if (primaryKey.isNotEmpty && autoIncrementColumns.length > 1) {
    throw FormatException(
      'Table $className declares more than one auto-increment column.',
    );
  }

  final table = TableSchema(
    className: className,
    sqlName: sqlName,
    rowClass: rowClass,
    columns: columns,
    primaryKey: primaryKey,
    uniqueKeys: uniqueKeys,
    indexes: indexes,
  );
  _validateColumnNames(table);
  return table;
}

ColumnSchema _parseColumn(String table, String name, String expression) {
  final baseMatch = RegExp(r'^(integer|text|dateTime|boolean)\(\)')
      .firstMatch(expression);
  if (baseMatch == null) {
    throw FormatException(
      'Unsupported column definition for $table.$name: $expression',
    );
  }

  final driftType = baseMatch.group(1)!;
  final sqlType = switch (driftType) {
    'integer' => 'INTEGER',
    'text' => 'TEXT',
    'dateTime' => 'INTEGER (DateTime)',
    'boolean' => 'INTEGER (boolean)',
    _ => throw FormatException('Unsupported drift type $driftType.'),
  };

  var nullable = false;
  var autoIncrement = false;
  String? defaultValue;
  String? length;
  ColumnReference? reference;
  var index = baseMatch.end;

  while (index < expression.length) {
    if (expression.substring(index).trim() == '()') {
      // Drift column getters end with a second call that builds the column:
      // integer().autoIncrement()().
      index = expression.length;
      break;
    }
    if (expression[index] != '.') {
      throw FormatException(
        'Unsupported column syntax for $table.$name near '
        '"${expression.substring(index)}".',
      );
    }
    final callMatch = RegExp(r'\.([A-Za-z_]\w*)')
        .matchAsPrefix(expression, index);
    if (callMatch == null) {
      throw FormatException(
        'Could not read the method chain for $table.$name.',
      );
    }
    final method = callMatch.group(1)!;
    final open = callMatch.end;
    if (open >= expression.length || expression[open] != '(') {
      throw FormatException(
        'Method $method on $table.$name is missing parentheses.',
      );
    }
    final close = _findMatching(expression, open, '(', ')');
    final args = expression.substring(open + 1, close).trim();
    index = close + 1;

    switch (method) {
      case 'autoIncrement':
        _expectEmpty(args, '$table.$name.autoIncrement');
        if (driftType != 'integer') {
          throw FormatException(
            'autoIncrement is only supported on integer columns '
            '($table.$name).',
          );
        }
        autoIncrement = true;
      case 'nullable':
        _expectEmpty(args, '$table.$name.nullable');
        nullable = true;
      case 'withLength':
        length = _parseLength(table, name, args);
      case 'withDefault':
        defaultValue = _parseDefault(table, name, args);
      case 'references':
        reference = _parseReference(table, name, args);
      default:
        throw FormatException(
          'Unsupported column method "$method" on $table.$name. '
          'Teach tool/docs/update_docs.dart how to document it.',
        );
    }
  }

  return ColumnSchema(
    name: name,
    sqlName: _snakeCase(name),
    driftType: driftType,
    sqlType: sqlType,
    nullable: nullable,
    defaultValue: defaultValue,
    autoIncrement: autoIncrement,
    length: length,
    reference: reference,
  );
}

void _expectEmpty(String args, String label) {
  if (args.isNotEmpty) {
    throw FormatException('$label does not accept arguments.');
  }
}

String _parseLength(String table, String name, String args) {
  final min = RegExp(r'\bmin\s*:\s*(\d+)').firstMatch(args)?.group(1);
  final max = RegExp(r'\bmax\s*:\s*(\d+)').firstMatch(args)?.group(1);
  if (min == null && max == null) {
    throw FormatException('Could not read withLength on $table.$name.');
  }
  if (min != null && max != null) return 'length $min..$max';
  if (min != null) return 'length ≥ $min';
  return 'length ≤ $max';
}

String _parseDefault(String table, String name, String args) {
  final match = RegExp(
    r'^(?:const\s+)?Constant\((.*)\)$',
    dotAll: true,
  ).firstMatch(args);
  if (match == null) {
    throw FormatException('Unsupported withDefault on $table.$name: $args');
  }
  final literal = match.group(1)!.trim();
  if (RegExp(r"^'(?:\\.|[^'])*'$").hasMatch(literal) ||
      RegExp(r'^"(?:\\.|[^"])*"$').hasMatch(literal) ||
      literal == 'true' ||
      literal == 'false' ||
      RegExp(r'^-?\d+(?:\.\d+)?$').hasMatch(literal)) {
    return literal;
  }
  throw FormatException(
    'Unsupported default literal on $table.$name: $literal',
  );
}

ColumnReference _parseReference(String table, String name, String args) {
  final match = RegExp(
    r'^([A-Za-z_]\w*)\s*,\s*#([A-Za-z_]\w*)'
    r'(?:\s*,\s*onDelete\s*:\s*KeyAction\.([A-Za-z_]\w*))?\s*,?\s*$',
    dotAll: true,
  ).firstMatch(args);
  if (match == null) {
    throw FormatException('Unsupported references() on $table.$name: $args');
  }
  final onDelete = switch (match.group(3)) {
    null || 'noAction' => 'NO ACTION',
    'cascade' => 'CASCADE',
    'setNull' => 'SET NULL',
    'setDefault' => 'SET DEFAULT',
    'restrict' => 'RESTRICT',
    final other => throw FormatException(
      'Unsupported onDelete KeyAction.$other on $table.$name.',
    ),
  };
  return ColumnReference(
    tableClass: match.group(1)!,
    columnName: match.group(2)!,
    onDelete: onDelete,
  );
}

void _validateUniqueTableNames(List<TableSchema> tables) {
  final classes = <String>{};
  final sqlNames = <String>{};
  for (final table in tables) {
    if (!classes.add(table.className)) {
      throw FormatException('Duplicate Drift table class ${table.className}.');
    }
    if (!sqlNames.add(table.sqlName)) {
      throw FormatException('Duplicate SQL table name ${table.sqlName}.');
    }
  }
}

void _resolveReferences(List<TableSchema> tables) {
  final byClass = {for (final table in tables) table.className: table};
  for (final table in tables) {
    for (final column in table.columns) {
      final reference = column.reference;
      if (reference == null) continue;
      final target = byClass[reference.tableClass];
      if (target == null) {
        throw FormatException(
          '${table.className}.${column.name} references unknown table '
          '${reference.tableClass}.',
        );
      }
      final targetColumn = target.byName[reference.columnName];
      if (targetColumn == null) {
        throw FormatException(
          '${table.className}.${column.name} references unknown column '
          '${target.className}.${reference.columnName}.',
        );
      }
      reference.tableSqlName = target.sqlName;
      reference.columnSqlName = targetColumn.sqlName;
    }
  }
}

/// Columns whose hand-written documentation would become misleading if the
/// code changed without the prose being revisited.
void _requireDocumentedColumns(List<TableSchema> tables) {
  final questions = tables.where((table) => table.sqlName == 'questions');
  if (questions.isEmpty ||
      !questions.single.columns.any((column) => column.sqlName == 'subtopic')) {
    throw const FormatException(
      'The documentation explains questions.subtopic end to end, but that '
      'column no longer exists. Update the subtopic prose and this guard.',
    );
  }
}

void _validateColumnNames(TableSchema table) {
  for (final name in table.primaryKey) {
    if (!table.byName.containsKey(name)) {
      throw FormatException(
        '${table.className} primaryKey names unknown column "$name".',
      );
    }
  }
  for (final key in table.uniqueKeys) {
    for (final name in key) {
      if (!table.byName.containsKey(name)) {
        throw FormatException(
          '${table.className} uniqueKeys names unknown column "$name".',
        );
      }
    }
  }
  for (final index in table.indexes) {
    for (final name in index.columns) {
      if (!table.byName.containsKey(name)) {
        throw FormatException(
          'Index ${index.name} on ${table.className} names unknown column '
          '"$name".',
        );
      }
    }
  }
}

List<TableIndexSchema> _parseCustomIndexes(
  String source,
  List<TableSchema> tables,
) {
  final bySqlName = {for (final table in tables) table.sqlName: table};
  final indexes = <TableIndexSchema>[];
  final seen = <String>{};
  for (final args in _customStatementArguments(source)) {
    final sql = _stringLiterals(args).join(' ');
    final regex = RegExp(
      r'CREATE\s+(UNIQUE\s+)?INDEX\s+IF\s+NOT\s+EXISTS\s+'
      r'([A-Za-z_]\w*)\s+ON\s+([A-Za-z_]\w*)\s*\(([^)]*)\)'
      r'\s*(WHERE\s+([\s\S]+))?',
      caseSensitive: false,
    );
    for (final match in regex.allMatches(sql)) {
      final name = match.group(2)!;
      if (!seen.add(name)) continue;
      final tableName = match.group(3)!;
      final table = bySqlName[tableName];
      if (table == null) {
        throw FormatException(
          'Custom index $name targets unknown table $tableName.',
        );
      }
      final columns = [
        for (final part in match.group(4)!.split(','))
          if (part.trim().isNotEmpty) part.trim(),
      ];
      for (final column in columns) {
        if (!table.bySqlName.containsKey(column)) {
          throw FormatException(
            'Custom index $name targets unknown column $tableName.$column.',
          );
        }
      }
      indexes.add(
        TableIndexSchema(
          name: name,
          tableSqlName: tableName,
          columns: columns,
          unique: match.group(1) != null,
          where: match.group(6)?.trim(),
        ),
      );
    }
  }
  return indexes;
}

List<MigrationStep> _parseMigrations(
  String source,
  int version,
  List<TableSchema> tables,
) {
  final upgradeStart = source.indexOf('onUpgrade:');
  if (upgradeStart < 0) {
    throw const FormatException(
      'Could not find MigrationStrategy.onUpgrade in app_database.dart.',
    );
  }
  final open = source.indexOf('{', upgradeStart);
  if (open < 0) {
    throw const FormatException('onUpgrade has no body.');
  }
  final close = _findMatching(source, open, '{', '}');
  final body = source.substring(open + 1, close);

  final steps = <MigrationStep>[];
  final stepRegex = RegExp(r'if\s*\(\s*from\s*<\s*(\d+)\s*\)\s*\{');
  var searchStart = 0;
  while (true) {
    final match = stepRegex.firstMatch(body.substring(searchStart));
    if (match == null) break;
    final absoluteStart = searchStart + match.start;
    final stepOpen = searchStart + match.end - 1;
    final stepClose = _findMatching(body, stepOpen, '{', '}');
    final stepVersion = int.parse(match.group(1)!);
    final stepBody = body.substring(stepOpen + 1, stepClose);

    final changes = <String>[];
    final addColumnRegex = RegExp(
      r'migrator\s*\.\s*addColumn\s*\(\s*([A-Za-z_]\w*)\s*,\s*'
      r'([A-Za-z_]\w*)\s*\.\s*([A-Za-z_]\w*)\s*,?\s*\)',
      dotAll: true,
    );
    for (final add in addColumnRegex.allMatches(stepBody)) {
      final table = _tableByClass(tables, add.group(1)!);
      final column = table.byName[add.group(3)!];
      if (column == null) {
        throw FormatException(
          'Migration $stepVersion adds unknown column '
          '${add.group(1)}.${add.group(3)}.',
        );
      }
      changes.add('Added `${column.sqlName}` to `${table.sqlName}`.');
    }

    final createdTables = <String>{};
    final createTableRegex = RegExp(
      r'migrator\s*\.\s*createTable\s*\(\s*([A-Za-z_]\w*)\s*,?\s*\)',
      dotAll: true,
    );
    for (final create in createTableRegex.allMatches(stepBody)) {
      final table = _tableByClass(tables, create.group(1)!);
      createdTables.add(table.sqlName);
      changes.add('Created table `${table.sqlName}`.');
    }

    final methodNames = RegExp(r'migrator\s*\.\s*([A-Za-z_]\w*)')
        .allMatches(stepBody)
        .map((match) => match.group(1)!)
        .toSet();
    const supportedMethods = {'addColumn', 'createTable'};
    final unsupported = methodNames.difference(supportedMethods);
    if (unsupported.isNotEmpty) {
      throw FormatException(
        'Migration $stepVersion uses unsupported migrator methods: '
        '${unsupported.join(', ')}.',
      );
    }

    final backfilled = <String>{};
    var otherStatements = 0;
    for (final args in _customStatementArguments(stepBody)) {
      final sql = _stringLiterals(args).join(' ');
      final updates = RegExp(
        r'UPDATE\s+([A-Za-z_]\w*)',
        caseSensitive: false,
      ).allMatches(sql).map((match) => match.group(1)!.toLowerCase()).toSet();
      if (updates.isEmpty) {
        otherStatements++;
      } else {
        backfilled.addAll(updates);
      }
    }
    if (backfilled.isNotEmpty) {
      final ordered = [
        for (final table in tables)
          if (backfilled.contains(table.sqlName)) table.sqlName,
      ];
      changes.add(
        'Custom SQL backfilled ${ordered.map((name) => '`$name`').join(', ')}.',
      );
    }
    if (otherStatements > 0) {
      final label = otherStatements == 1
          ? 'a custom SQL statement'
          : '$otherStatements custom SQL statements';
      changes.add('Ran $label.');
    }

    if (changes.isEmpty) {
      changes.add('No schema change.');
    }
    if (steps.any((step) => step.version == stepVersion)) {
      throw FormatException(
        'Duplicate migration step for schema version $stepVersion.',
      );
    }
    steps.add(
      MigrationStep(
        version: stepVersion,
        changes: changes,
        createdTables: createdTables,
      ),
    );
    searchStart = absoluteStart + 1;
    if (stepClose <= searchStart) {
      throw FormatException('Could not advance past migration $stepVersion.');
    }
  }

  steps.sort((a, b) => a.version.compareTo(b.version));
  final stepVersions = {for (final step in steps) step.version};
  for (var expected = 2; expected <= version; expected++) {
    if (!stepVersions.contains(expected)) {
      throw FormatException(
        'No migration step for schema version $expected. '
        'Update tool/docs/update_docs.dart if the strategy changed.',
      );
    }
  }
  for (final step in steps) {
    if (step.version < 2 || step.version > version) {
      throw FormatException(
        'Migration step ${step.version} is outside the supported range '
        '2..$version.',
      );
    }
  }
  return steps;
}

TableSchema _tableByClass(List<TableSchema> tables, String identifier) {
  for (final table in tables) {
    if (table.className == identifier ||
        _lowerCamelCase(table.className) == identifier) {
      return table;
    }
  }
  throw FormatException('Unknown Drift table class or getter $identifier.');
}

void _validateTableDocs(List<TableSchema> tables, String modelSource) {
  final modelClasses = RegExp(r'class\s+([A-Za-z_]\w*)')
      .allMatches(modelSource)
      .map((match) => match.group(1)!)
      .toSet();
  final tableNames = {for (final table in tables) table.sqlName};

  for (final table in tables) {
    final doc = _tableDocs[table.sqlName];
    if (doc == null) {
      throw FormatException(
        'Table ${table.sqlName} has no documentation entry in '
        'tool/docs/update_docs.dart. Add its feature, domain model and '
        'repository.',
      );
    }
    if (doc.model != '—' && !modelClasses.contains(doc.model)) {
      throw FormatException(
        'Table ${table.sqlName} names unknown domain model ${doc.model}.',
      );
    }
  }
  for (final name in _tableDocs.keys) {
    if (!tableNames.contains(name)) {
      throw FormatException(
        'tool/docs/update_docs.dart documents table "$name", but no such '
        'table exists in tables.dart.',
      );
    }
  }
}

Map<String, List<String>> _parseDaos(Directory root, List<TableSchema> tables) {
  final daoTables = <String, List<String>>{};
  final directory = Directory('${root.path}/lib/core/database/daos');
  if (!directory.existsSync()) {
    throw const FormatException('Missing lib/core/database/daos.');
  }
  for (final entity in directory.listSync()) {
    if (entity is! File ||
        !entity.path.endsWith('.dart') ||
        entity.path.endsWith('.g.dart')) {
      continue;
    }
    final source = _stripComments(entity.readAsStringSync());
    final annotation = RegExp(r'@DriftAccessor\s*\(([\s\S]*?)\)\s*class')
        .firstMatch(source);
    if (annotation == null) continue;
    final tablesMatch = RegExp(r'tables\s*:\s*\[([\s\S]*?)\]')
        .firstMatch(annotation.group(1)!);
    if (tablesMatch == null) continue;
    final classMatch = RegExp(
      r'class\s+([A-Za-z_]\w*)\s+extends\s+DatabaseAccessor',
    ).firstMatch(source);
    if (classMatch == null) continue;
    final dao = classMatch.group(1)!;
    for (final name in _identifiers(tablesMatch.group(1)!)) {
      daoTables.putIfAbsent(name, () => []).add(dao);
    }
  }

  for (final table in tables) {
    final daos = daoTables[table.className];
    if (daos == null || daos.isEmpty) {
      throw FormatException(
        'Table ${table.className} is not listed by any @DriftAccessor DAO.',
      );
    }
    daos.sort();
  }
  return daoTables;
}

// ---------------------------------------------------------------------------
// Backup coverage parsing
// ---------------------------------------------------------------------------

class BackupCoverage {
  const BackupCoverage({
    required this.formatVersion,
    required this.minimumFormatVersion,
    required this.appVersion,
    required this.buildNumber,
    required this.requiredTables,
    required this.optionalTables,
  });

  final int formatVersion;
  final int minimumFormatVersion;
  final String appVersion;
  final int buildNumber;
  final List<String> requiredTables;
  final List<String> optionalTables;
}

BackupCoverage parseBackupCoverage(Directory root, SchemaModel schema) {
  final source = _stripComments(
    _read('${root.path}/lib/features/backup/domain/backup_service.dart'),
  );
  final formatVersion = _intConstant(source, 'formatVersion');
  final minimumFormatVersion = _intConstant(source, 'minimumFormatVersion');
  final appVersion = RegExp(r"static\s+const\s+appVersion\s*=\s*'([^']+)'\s*;")
      .firstMatch(source)
      ?.group(1);
  final buildNumber = _intConstant(source, 'buildNumber');
  if (appVersion == null) {
    throw const FormatException('Could not read BackupService.appVersion.');
  }
  final requiredTables = _stringSetConstant(source, 'requiredTables');
  final optionalTables = _stringSetConstant(source, 'optionalTables');

  final schemaTables = {for (final table in schema.tables) table.sqlName};
  final backupToSchema = {
    for (final table in schema.tables) _lowerCamelCase(table.className): table,
  };
  final seen = <String>{};
  for (final name in [...requiredTables, ...optionalTables]) {
    if (!seen.add(name)) {
      throw FormatException('Backup table "$name" is listed more than once.');
    }
    if (!backupToSchema.containsKey(name)) {
      throw FormatException(
        'Backup table "$name" does not match any database table.',
      );
    }
  }
  final missing = schemaTables.difference({
    for (final name in seen) backupToSchema[name]!.sqlName,
  });
  if (missing.isNotEmpty) {
    throw FormatException(
      'Backup coverage is missing database tables: ${missing.join(', ')}.',
    );
  }

  return BackupCoverage(
    formatVersion: formatVersion,
    minimumFormatVersion: minimumFormatVersion,
    appVersion: appVersion,
    buildNumber: buildNumber,
    requiredTables: requiredTables,
    optionalTables: optionalTables,
  );
}

int _intConstant(String source, String name) {
  final match = RegExp('static\\s+const\\s+$name\\s*=\\s*(\\d+)\\s*;')
      .firstMatch(source);
  if (match == null) {
    throw FormatException('Could not read constant $name.');
  }
  return int.parse(match.group(1)!);
}

List<String> _stringSetConstant(String source, String name) {
  final regex = RegExp(
    'static\\s+const\\s+$name\\s*=\\s*<String>\\s*\\{([\\s\\S]*?)\\}\\s*;',
  );
  final match = regex.firstMatch(source);
  if (match == null) {
    throw FormatException('Could not read constant $name.');
  }
  return [for (final literal in _stringLiterals(match.group(1)!)) literal];
}

// ---------------------------------------------------------------------------
// Markdown rendering
// ---------------------------------------------------------------------------

class _TableDoc {
  const _TableDoc(this.feature, this.model, this.repository);

  final String feature;
  final String model;
  final String repository;
}

const _tableDocs = <String, _TableDoc>{
  'topics': _TableDoc(
    'Home topic list, topic editor, archive/restore, per-topic Anki deck, '
        'priority and natural-name ordering, statistics scope.',
    'Topic',
    'PracticeRepository',
  ),
  'practices': _TableDoc(
    'Topic practice list, import and duplicate detection, rename/description '
        'edit, mark done/active, split, practice JSON download/update.',
    'Practice',
    'PracticeRepository',
  ),
  'questions': _TableDoc(
    'Import, practice sessions, shuffled eligibility, multi-answer scoring, '
        'subtopic statistics, practice JSON export/update.',
    'Question',
    'PracticeRepository',
  ),
  'sessions': _TableDoc(
    'Practice, mixed and past-error runs, paused sessions on Home, score and '
        'statistics history.',
    'PracticeSession',
    'SessionRepository',
  ),
  'session_questions': _TableDoc(
    'Ordered question set of an in-progress or completed session; enables '
        'resume and counts questions left unanswered.',
    '—',
    'SessionRepository',
  ),
  'attempts': _TableDoc(
    'One submitted answer, reasoning, distraction and "I didn\'t know this" '
        'flags, and the done/solved/skipped history.',
    'Attempt',
    'SessionRepository',
  ),
  'concepts': _TableDoc(
    'Define lookups, missing-definition review steps and concept cards for '
        'Anki export.',
    'Concept',
    'CardRepository',
  ),
  'error_cards': _TableDoc(
    'Wrong-answer error queue, 48-hour retry, bias/vaccine review, shared card '
        'review and Anki export.',
    'ErrorCard',
    'CardRepository',
  ),
  'manual_cards': _TableDoc(
    'Basic question/answer cards from skipped questions, Ask or a highlight.',
    'ManualCard',
    'CardRepository',
  ),
  'skipped_questions': _TableDoc(
    'Persistent skipped-question queue that stays in Cards until a concept or '
        'basic card is made.',
    'SkippedQuestion',
    'CardRepository',
  ),
  'highlights': _TableDoc(
    'Selected passages painted during practice, kept or converted into a '
        'concept/basic card, downloaded as plain text.',
    'StudyHighlight',
    'CardRepository',
  ),
  'settings': _TableDoc(
    'Lookup mode, AI provider/model/base URL, dynamic color, sounds and volume, '
        'default Anki deck, Home topic sort and each topic\'s practice sort.',
    'AppSettings',
    'SettingsRepository',
  ),
};

String _databaseMarkdown(SchemaModel schema) {
  final lines = <String>[
    'Current schema version: **${schema.version}** '
        '(`AppDatabase.schemaVersion`).',
    '',
    'Table names below are the SQL names Drift creates. Every column, default, '
        'reference, cascade, primary key, unique key and index is read from '
        '`lib/core/database/tables.dart` and `app_database.dart`; the '
        'feature/model/repository notes come from the documented mapping in '
        '`tool/docs/update_docs.dart`.',
    '',
    '### Tables',
    '',
  ];

  for (final table in schema.tables) {
    lines.addAll(_tableMarkdown(table, schema));
  }

  final allIndexes = [
    for (final table in schema.tables)
      for (final index in table.indexes) index,
    ...schema.extraIndexes,
  ];
  if (allIndexes.isNotEmpty) {
    lines
      ..add('### Index summary')
      ..add('')
      ..add('| Index | Table | Columns | Kind | Condition |')
      ..add('|---|---|---|---|---|');
    for (final index in allIndexes) {
      final columns = index.columns
          .map(
            (column) => '`${_sqlColumn(index.tableSqlName, column, schema)}`',
          )
          .join(', ');
      final condition = index.where == null
          ? '—'
          : '`${_escapeCell(index.where!)}`';
      lines.add(
        '| `${index.name}` | `${index.tableSqlName}` | $columns | '
        '${index.unique ? 'UNIQUE' : 'INDEX'} | $condition |',
      );
    }
    lines.add('');
  }

  return _trimTrailingBlank(lines);
}

List<String> _tableMarkdown(TableSchema table, SchemaModel schema) {
  final doc = _tableDocs[table.sqlName]!;
  final daos = schema.daosByTable[table.className] ?? const <String>[];
  final lines = <String>[
    '#### `${table.sqlName}`',
    '',
    '**Drift class:** `${table.className}` · **Row class:** `${table.rowClass}`',
    '',
    '**Feature use:** ${doc.feature}',
    '',
    '**Domain model:** `${doc.model}` · **Repository:** '
        '`${doc.repository}` · **DAO:** ${daos.isEmpty ? '—' : daos.map((dao) => '`$dao`').join(', ')}',
    '',
    '| Column | Type | Null | Default | Constraints | References |',
    '|---|---|---|---|---|---|',
  ];

  for (final column in table.columns) {
    final constraints = <String>[];
    if (column.autoIncrement) constraints.add('AUTOINCREMENT');
    if (column.length != null) constraints.add(column.length!);
    if (table.primaryKey.contains(column.name)) constraints.add('PRIMARY KEY');
    final unique = table.uniqueKeys.any(
      (key) => key.length == 1 && key.single == column.name,
    );
    if (unique) constraints.add('UNIQUE');
    final reference = column.reference;
    lines.add(
      '| `${column.sqlName}` | ${column.sqlType} | '
      '${column.nullable ? 'NULL' : 'NOT NULL'} | '
      '${column.defaultValue == null ? '—' : '`${_escapeCell(column.defaultValue!)}`'} | '
      '${constraints.isEmpty ? '—' : _escapeCell(constraints.join(', '))} | '
      '${reference == null ? '—' : '`${reference.tableSqlName}.${reference.columnSqlName}` ON DELETE ${reference.onDelete}'} |',
    );
  }

  lines
    ..add('')
    ..add('**Keys and indexes**')
    ..add('');

  if (table.primaryKey.length == 1 &&
      table.byName[table.primaryKey.single]?.autoIncrement == true) {
    lines.add(
      '- Primary key: `${table.bySqlName[table.primaryKey.single]!.sqlName}` (auto-increment)',
    );
  } else {
    lines.add(
      '- Primary key: ${table.primaryKey.map((name) => '`${table.byName[name]!.sqlName}`').join(', ')}',
    );
  }
  for (final key in table.uniqueKeys) {
    lines.add(
      '- Unique: (${key.map((name) => '`${table.byName[name]!.sqlName}`').join(', ')})',
    );
  }
  if (table.indexes.isEmpty) {
    lines.add('- Explicit table indexes: none');
  } else {
    for (final index in table.indexes) {
      lines.add(
        '- Index `${index.name}`: (${index.columns.map((name) => '`${table.byName[name]!.sqlName}`').join(', ')})',
      );
    }
  }
  for (final index in schema.extraIndexes.where(
    (index) => index.tableSqlName == table.sqlName,
  )) {
    final kind = index.unique ? 'Partial unique index' : 'Partial index';
    final condition = index.where == null
        ? ''
        : ' WHERE `${_escapeCell(index.where!)}`';
    lines.add(
      '- $kind `${index.name}`: (${index.columns.map((column) => '`$column`').join(', ')})$condition',
    );
  }
  if (table.sqlName == 'error_cards') {
    lines.add(
      '- The partial unique index above enforces at most one `active` error '
      'card per question; resolved history rows are unrestricted.',
    );
  }
  lines.add('');
  return lines;
}

String _sqlColumn(String table, String driftName, SchemaModel schema) {
  final column = schema.bySqlName[table]?.byName[driftName];
  return column?.sqlName ?? driftName;
}

String _migrationsMarkdown(SchemaModel schema) {
  final createdByMigrations = {
    for (final step in schema.migrations) ...step.createdTables,
  };
  final baselineTables = [
    for (final table in schema.tables)
      if (!createdByMigrations.contains(table.sqlName)) table.sqlName,
  ];
  final lines = <String>[
    'Current schema version: **${schema.version}**. Migration steps are read '
        'from `AppDatabase.migration.onUpgrade`; `onCreate` creates every table '
        'and the custom partial indexes listed above.',
    '',
    '| Version | Changes |',
    '|---|---|',
    '| 1 | Initial schema with '
        '${baselineTables.map((name) => '`$name`').join(', ')}. |',
  ];
  for (final step in schema.migrations) {
    lines.add('| ${step.version} | ${step.changes.join(' ')} |');
  }
  lines
    ..add('')
    ..add(
      'The database opens with `PRAGMA foreign_keys = ON`, so every reference '
      'and cascade in the table map is enforced. Versions are cumulative: a '
      'database at version 1 runs every step from 2 through '
      '${schema.version}.',
    );
  return _trimTrailingBlank(lines);
}

String _backupMarkdown(BackupCoverage backup) {
  final required = backup.requiredTables.map((name) => '`$name`').join(', ');
  final optional = backup.optionalTables.isEmpty
      ? 'None'
      : backup.optionalTables.map((name) => '`$name`').join(', ');
  return _trimTrailingBlank([
    'Backup format **v${backup.formatVersion}**; minimum readable format '
        '**v${backup.minimumFormatVersion}**. Files record app version '
        '**${backup.appVersion}** build **${backup.buildNumber}**, the database '
        'schema version, export time and per-table row counts.',
    '',
    '| Coverage | Backup keys |',
    '|---|---|',
    '| Required in every backup | $required |',
    '| Optional for older files | $optional |',
    '',
    'The required and optional sets together cover every database table '
        'exactly once. `settings` stores preferences as key/value rows; the AI '
        'API key is in Android secure storage and is never exported.',
  ]);
}

String _trimTrailingBlank(List<String> lines) {
  while (lines.isNotEmpty && lines.last.trim().isEmpty) {
    lines.removeLast();
  }
  return lines.join('\n');
}

String _escapeCell(String value) {
  return value.replaceAll('|', r'\|').replaceAll('\n', ' ');
}

// ---------------------------------------------------------------------------
// Section markers
// ---------------------------------------------------------------------------

String _beginMarker(String marker) => '<!-- BEGIN GENERATED: $marker -->';
String _endMarker(String marker) => '<!-- END GENERATED: $marker -->';

String? _sectionBody(String text, String marker) {
  final begin = _beginMarker(marker);
  final end = _endMarker(marker);
  final start = text.indexOf(begin);
  if (start < 0) return null;
  if (text.indexOf(begin, start + begin.length) >= 0) {
    throw FormatException('Duplicate begin marker "$marker".');
  }
  final bodyStart = start + begin.length;
  final endIndex = text.indexOf(end, bodyStart);
  if (endIndex < 0) {
    throw FormatException('Missing end marker "$marker".');
  }
  return text.substring(bodyStart, endIndex);
}

String _replaceSection(String text, String marker, String content) {
  final begin = _beginMarker(marker);
  final end = _endMarker(marker);
  final start = text.indexOf(begin);
  if (start < 0) {
    throw FormatException('Missing begin marker "$marker".');
  }
  final bodyStart = start + begin.length;
  final endIndex = text.indexOf(end, bodyStart);
  if (endIndex < 0) {
    throw FormatException('Missing end marker "$marker".');
  }
  return '${text.substring(0, bodyStart)}\n$content\n'
      '${text.substring(endIndex)}';
}

// ---------------------------------------------------------------------------
// Small source helpers
// ---------------------------------------------------------------------------

String _read(String path) {
  final file = File(path);
  if (!file.existsSync()) {
    throw FileSystemException('Missing source file', path);
  }
  return file.readAsStringSync();
}

String _stripComments(String input) {
  final out = StringBuffer();
  var index = 0;
  while (index < input.length) {
    final char = input[index];
    if (char == "'" || char == '"') {
      final end = _skipString(input, index);
      out.write(input.substring(index, end));
      index = end;
      continue;
    }
    if (char == '/' && index + 1 < input.length) {
      final next = input[index + 1];
      if (next == '/') {
        index += 2;
        while (index < input.length && input[index] != '\n') {
          index++;
        }
        continue;
      }
      if (next == '*') {
        index += 2;
        while (index + 1 < input.length &&
            !(input[index] == '*' && input[index + 1] == '/')) {
          index++;
        }
        index = index + 1 < input.length ? index + 2 : input.length;
        continue;
      }
    }
    out.write(char);
    index++;
  }
  return out.toString();
}

int _skipString(String source, int start) {
  final quote = source[start];
  final triple =
      start + 2 < source.length &&
      source[start + 1] == quote &&
      source[start + 2] == quote;
  var index = start + (triple ? 3 : 1);
  while (index < source.length) {
    if (triple && source.startsWith('$quote$quote$quote', index)) {
      return index + 3;
    }
    if (source[index] == '\\') {
      index += 2;
      continue;
    }
    if (!triple && source[index] == quote) {
      return index + 1;
    }
    index++;
  }
  throw const FormatException('Unterminated string literal in source.');
}

int _findMatching(String source, int openIndex, String open, String close) {
  var depth = 0;
  var index = openIndex;
  while (index < source.length) {
    final char = source[index];
    if (char == "'" || char == '"') {
      index = _skipString(source, index);
      continue;
    }
    if (char == open) {
      depth++;
    } else if (char == close) {
      depth--;
      if (depth == 0) return index;
    }
    index++;
  }
  throw FormatException('Unbalanced "$open" starting at $openIndex.');
}

int _findStatementEnd(String source, int start) {
  var parens = 0;
  var brackets = 0;
  var braces = 0;
  var index = start;
  while (index < source.length) {
    final char = source[index];
    if (char == "'" || char == '"') {
      index = _skipString(source, index);
      continue;
    }
    switch (char) {
      case '(':
        parens++;
      case ')':
        parens--;
      case '[':
        brackets++;
      case ']':
        brackets--;
      case '{':
        braces++;
      case '}':
        braces--;
      case ';':
        if (parens == 0 && brackets == 0 && braces == 0) return index;
    }
    index++;
  }
  throw FormatException('Missing semicolon at $start.');
}

List<String> _identifiers(String source) {
  return [
    for (final match in RegExp(r'[A-Za-z_]\w*').allMatches(source))
      match.group(0)!,
  ]..removeWhere(
    (name) =>
        const {'const', 'final', 'var', 'Set', 'Column', 'List'}.contains(name),
  );
}

Iterable<String> _customStatementArguments(String source) {
  final regex = RegExp(r'customStatement\s*\(');
  final results = <String>[];
  for (final match in regex.allMatches(source)) {
    final open = match.end - 1;
    final close = _findMatching(source, open, '(', ')');
    results.add(source.substring(open + 1, close));
  }
  return results;
}

List<String> _stringLiterals(String source) {
  final results = <String>[];
  var index = 0;
  while (index < source.length) {
    final char = source[index];
    if (char != "'" && char != '"') {
      index++;
      continue;
    }
    final end = _skipString(source, index);
    final triple =
        index + 2 < source.length &&
        source[index + 1] == char &&
        source[index + 2] == char;
    final contentStart = index + (triple ? 3 : 1);
    final contentEnd = end - (triple ? 3 : 1);
    results.add(source.substring(contentStart, contentEnd));
    index = end;
  }
  return results;
}

String _snakeCase(String value) {
  final buffer = StringBuffer();
  for (var index = 0; index < value.length; index++) {
    final char = value[index];
    final isUpper = char.toUpperCase() == char && char.toLowerCase() != char;
    if (isUpper && index > 0) buffer.write('_');
    buffer.write(char.toLowerCase());
  }
  return buffer.toString();
}

String _lowerCamelCase(String value) {
  if (value.isEmpty) return value;
  return '${value[0].toLowerCase()}${value.substring(1)}';
}

#!/usr/bin/env dart

import 'dart:io';
import 'dart:convert';

/// Filters dart_apitool JSON output to show only classes and methods
/// Usage: dart run filter_api.dart <input_file> [output_format]
void main(List<String> arguments) async {
  if (arguments.isEmpty) {
    stderr.writeln(
        'Usage: dart run filter_api.dart <input_file> [output_format]');
    stderr
        .writeln('Output formats: json, markdown, summary (default: summary)');
    exit(1);
  }

  final inputFile = arguments[0];
  final outputFormat = arguments.length > 1 ? arguments[1] : 'summary';

  if (!await File(inputFile).exists()) {
    stderr.writeln('Error: File $inputFile not found');
    exit(1);
  }

  final content = await File(inputFile).readAsString();
  final data = jsonDecode(content) as Map<String, dynamic>;

  final filtered = filterAPI(data);

  switch (outputFormat.toLowerCase()) {
    case 'json':
      stdout.writeln(jsonEncode(filtered));
      break;
    case 'markdown':
      stdout.writeln(generateMarkdown(filtered));
      break;
    case 'summary':
    default:
      stdout.writeln(generateSummary(filtered));
      break;
  }
}

Map<String, dynamic> filterAPI(Map<String, dynamic> data) {
  final packageApi = data['packageApi'] as Map<String, dynamic>;
  final interfaces = packageApi['interfaceDeclarations'] as List<dynamic>;

  final filteredClasses = <Map<String, dynamic>>[];

  for (final interface in interfaces) {
    final cls = interface as Map<String, dynamic>;

    // Extract basic class info
    final classInfo = {
      'name': cls['name'],
      'isDeprecated': cls['isDeprecated'],
      'superTypes': cls['superTypeNames'],
      'file': _extractFileName(cls['relativePath']),
    };

    // Extract methods
    final executables = cls['executableDeclarations'] as List<dynamic>? ?? [];
    final methods = <Map<String, dynamic>>[];

    for (final executable in executables) {
      final exec = executable as Map<String, dynamic>;

      // Skip if deprecated (unless we want to see them)
      if (exec['isDeprecated'] == true) continue;

      final method = {
        'name': exec['name'],
        'returnType': exec['returnTypeName'],
        'type': exec['type'], // constructor, method, etc.
        'isStatic': exec['isStatic'],
        'parameters':
            _extractParameters(exec['parameters'] as List<dynamic>? ?? []),
      };

      methods.add(method);
    }

    // Extract properties/fields
    final fields = cls['fieldDeclarations'] as List<dynamic>? ?? [];
    final properties = <Map<String, dynamic>>[];

    for (final field in fields) {
      final fld = field as Map<String, dynamic>;

      if (fld['isDeprecated'] == true) continue;

      final property = {
        'name': fld['name'],
        'type': fld['typeName'],
        'isStatic': fld['isStatic'],
        'isReadable': fld['isReadable'],
        'isWriteable': fld['isWriteable'],
      };

      properties.add(property);
    }

    classInfo['methods'] = methods;
    classInfo['properties'] = properties;

    filteredClasses.add(classInfo);
  }

  return {
    'packageName': packageApi['packageName'],
    'packageVersion': packageApi['packageVersion'],
    'classes': filteredClasses,
    'summary': {
      'totalClasses': filteredClasses.length,
      'totalMethods': filteredClasses.fold<int>(
          0, (sum, cls) => sum + (cls['methods'] as List).length),
      'totalProperties': filteredClasses.fold<int>(
          0, (sum, cls) => sum + (cls['properties'] as List).length),
    }
  };
}

List<String> _extractParameters(List<dynamic> parameters) {
  return parameters.map((param) {
    final p = param as Map<String, dynamic>;
    final name = p['name'];
    final type = p['typeName']; // Keep original Dart type
    final isRequired = p['isRequired'] == true;
    final isNamed = p['isNamed'] == true;

    if (isNamed) {
      return isRequired ? 'required $type $name' : '$type $name';
    } else {
      return '$type $name';
    }
  }).toList();
}

String _extractFileName(String? relativePath) {
  if (relativePath == null) return 'unknown';
  final parts = relativePath.split('/');
  return parts.last.replaceAll('package:customer_io/', '');
}

String generateSummary(Map<String, dynamic> filtered) {
  final buffer = StringBuffer();
  final classes = filtered['classes'] as List<dynamic>;

  // Sort classes alphabetically by name for deterministic output
  final sortedClasses = List<dynamic>.from(classes);
  sortedClasses.sort((a, b) {
    final nameA = (a as Map<String, dynamic>)['name'] as String;
    final nameB = (b as Map<String, dynamic>)['name'] as String;
    return nameA.compareTo(nameB);
  });

  for (final cls in sortedClasses) {
    final clsMap = cls as Map<String, dynamic>;
    final methods = clsMap['methods'] as List<dynamic>;
    final properties = clsMap['properties'] as List<dynamic>;

    // Generate class declaration - keep original class name exactly
    final className = clsMap['name'];
    buffer.writeln('public final class $className {');

    // Handle constructors - keep original constructor names and types
    final constructors =
        methods.where((m) => m['type'] == 'constructor').toList();
    // Sort constructors alphabetically
    constructors
        .sort((a, b) => (a['name'] as String).compareTo(b['name'] as String));
    for (final constructor in constructors) {
      final constructorName = constructor['name'];
      final returnType = constructor['returnType'];
      final params = constructor['parameters'] as List<String>;
      final isStatic = constructor['isStatic'] == true;

      buffer.writeln(_formatMethodOriginal(
          constructorName, returnType, params, false,
          isStatic: isStatic));
    }

    // Handle regular methods - keep original method names and types
    final nonConstructors =
        methods.where((m) => m['type'] != 'constructor').toList();
    // Sort methods alphabetically
    nonConstructors
        .sort((a, b) => (a['name'] as String).compareTo(b['name'] as String));
    for (final method in nonConstructors) {
      final methodName = method['name'];
      final returnType = method['returnType']; // Keep original type
      final params = method['parameters'] as List<String>;
      final isStatic = method['isStatic'] == true;
      final isAsync = returnType.contains('Future');

      buffer.writeln(_formatMethodOriginal(
          methodName, returnType, params, isAsync,
          isStatic: isStatic));
    }

    // Handle properties - keep original property names and types
    // Sort properties alphabetically
    final sortedProperties = List<dynamic>.from(properties);
    sortedProperties
        .sort((a, b) => (a['name'] as String).compareTo(b['name'] as String));
    for (final property in sortedProperties) {
      final propName = property['name'];
      final propType = property['type']; // Keep original type
      final isStatic = property['isStatic'] == true;
      final isWriteable = property['isWriteable'] == true;

      // Show property as simple field declaration
      final staticMark = isStatic ? 'static ' : '';
      final accessType = isWriteable ? 'var' : 'val';
      buffer.writeln('\t${staticMark}public $accessType $propName: $propType;');
    }

    buffer.writeln('}');
    buffer.writeln('');
  }

  return buffer.toString();
}

String _formatMethodOriginal(
    String methodName, String returnType, List<String> params, bool isAsync,
    {bool isStatic = false}) {
  final buffer = StringBuffer();

  // Add static modifier if needed (static comes before public)
  final staticPrefix = isStatic ? 'static ' : '';

  // Keep original return type exactly as-is
  final hasReturnType = returnType != 'void';
  final returnTypeSuffix = hasReturnType ? ': $returnType' : '';

  // Start method declaration
  if (params.isEmpty) {
    // No parameters
    final asyncSuffix = isAsync ? ' async' : '';
    buffer.write(
        '\t${staticPrefix}public fun $methodName()$returnTypeSuffix$asyncSuffix;');
  } else if (params.length == 1 && params[0].length < 50) {
    // Single short parameter
    final asyncSuffix = isAsync ? ' async' : '';
    buffer.write(
        '\t${staticPrefix}public fun $methodName(${params[0]})$returnTypeSuffix$asyncSuffix;');
  } else {
    // Multiple parameters or long parameters - format on multiple lines
    buffer.write('\t${staticPrefix}public fun $methodName(');
    for (int i = 0; i < params.length; i++) {
      if (i == 0) {
        buffer.writeln('');
        buffer.write('\t\t${params[i]}');
      } else {
        buffer.writeln(',');
        buffer.write('\t\t${params[i]}');
      }
    }
    final asyncSuffix = isAsync ? ' async' : '';
    buffer.write('\n\t)$returnTypeSuffix$asyncSuffix;');
  }

  return buffer.toString();
}

String generateMarkdown(Map<String, dynamic> filtered) {
  final buffer = StringBuffer();
  final summary = filtered['summary'] as Map<String, dynamic>;

  buffer.writeln('# ${filtered['packageName']} v${filtered['packageVersion']}');
  buffer.writeln('');
  buffer.writeln('## Summary');
  buffer.writeln('- **Classes:** ${summary['totalClasses']}');
  buffer.writeln('- **Methods:** ${summary['totalMethods']}');
  buffer.writeln('- **Properties:** ${summary['totalProperties']}');
  buffer.writeln('');

  final classes = filtered['classes'] as List<dynamic>;

  buffer.writeln('## Classes');
  buffer.writeln('');

  for (final cls in classes) {
    final clsMap = cls as Map<String, dynamic>;
    final methods = clsMap['methods'] as List<dynamic>;
    final properties = clsMap['properties'] as List<dynamic>;

    buffer.writeln('### `${clsMap['name']}`');
    buffer.writeln('**File:** `${clsMap['file']}`');

    if ((clsMap['superTypes'] as List).isNotEmpty) {
      final supers =
          (clsMap['superTypes'] as List).where((s) => s != 'Object').toList();
      if (supers.isNotEmpty) {
        buffer.writeln('**Extends:** `${supers.join(', ')}`');
      }
    }
    buffer.writeln('');

    // Constructors
    final constructors =
        methods.where((m) => m['type'] == 'constructor').toList();
    if (constructors.isNotEmpty) {
      buffer.writeln('**Constructors:**');
      for (final constructor in constructors) {
        final params = (constructor['parameters'] as List<String>).join(', ');
        buffer.writeln('- `${constructor['name']}($params)`');
      }
      buffer.writeln('');
    }

    // Methods
    final nonConstructors =
        methods.where((m) => m['type'] != 'constructor').toList();
    if (nonConstructors.isNotEmpty) {
      buffer.writeln('**Methods:**');
      for (final method in nonConstructors) {
        final params = (method['parameters'] as List<String>).join(', ');
        final staticMark = method['isStatic'] == true ? 'static ' : '';
        buffer.writeln(
            '- `$staticMark${method['returnType']} ${method['name']}($params)`');
      }
      buffer.writeln('');
    }

    // Properties
    if (properties.isNotEmpty) {
      buffer.writeln('**Properties:**');
      for (final property in properties) {
        final staticMark = property['isStatic'] == true ? 'static ' : '';
        final accessMark = property['isWriteable'] == true ? 'get/set' : 'get';
        buffer.writeln(
            '- `$staticMark${property['type']} ${property['name']}` ($accessMark)');
      }
      buffer.writeln('');
    }
  }

  return buffer.toString();
}

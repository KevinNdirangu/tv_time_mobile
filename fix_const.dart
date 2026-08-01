import 'dart:io';

void main() {
  final dir = Directory('lib');
  final files = dir.listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'));

  for (final file in files) {
    String content = file.readAsStringSync();
    
    // We only replace 'const ' if the line contains 'AppTheme.primary'
    // This is safer.
    final lines = content.split('\n');
    bool modified = false;
    for (int i = 0; i < lines.length; i++) {
      if (lines[i].contains('AppTheme.primary') && lines[i].contains('const ')) {
        // Just remove 'const ' from this specific line.
        // Be careful not to remove const from static const Color background, etc.
        if (!lines[i].contains('static const Color primary')) {
           lines[i] = lines[i].replaceAll('const ', '');
           modified = true;
        }
      }
    }
    
    if (modified) {
      file.writeAsStringSync(lines.join('\n'));
      print('Fixed \${file.path}');
    }
  }
}

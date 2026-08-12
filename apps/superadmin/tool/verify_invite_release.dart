import 'dart:io';

void main() {
  final sourceRoot = Directory('lib/features/invites');
  final bundle = File('build/web/main.dart.js');
  if (!sourceRoot.existsSync() || !bundle.existsSync()) {
    stderr.writeln('Convites release scan requires source and build/web/main.dart.js.');
    exitCode = 2;
    return;
  }

  final forbidden = <({String label, RegExp pattern})>[
    (
      label: 'service role secret',
      pattern: RegExp(r'\bservice_role\b\s*[:=]', caseSensitive: false),
    ),
    (label: 'Supabase secret key', pattern: RegExp(r'\bsb_secret_[A-Za-z0-9_-]+')),
    (
      label: 'Postgres connection string',
      pattern: RegExp(r'postgres(?:ql)?://', caseSensitive: false),
    ),
    (label: 'private key', pattern: RegExp(r'-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----')),
    (
      label: 'JWT literal',
      pattern: RegExp(r'\beyJ[A-Za-z0-9_-]+\.eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\b'),
    ),
    (label: 'fake invitation repository', pattern: RegExp(r'FakeInviteRepository')),
    (
      label: 'obsolete mobile channel',
      pattern: RegExp(r'InviteChannel\.mobile|Celular do destinatário'),
    ),
    (
      label: 'obsolete invitation fixture',
      pattern: RegExp(r'preview\.coelo\.test|owner@aurora\.test|time@coelo\.test'),
    ),
  ];

  final inputs = <File>[
    ...sourceRoot
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart')),
    bundle,
  ];
  final findings = <String>[];
  for (final file in inputs) {
    final text = file.readAsStringSync();
    for (final rule in forbidden) {
      if (rule.pattern.hasMatch(text)) findings.add('${rule.label}: ${file.path}');
    }
  }
  if (findings.isNotEmpty) {
    stderr.writeln(findings.join('\n'));
    exitCode = 1;
    return;
  }
  stdout.writeln('Convites release scan passed (${inputs.length} files).');
}

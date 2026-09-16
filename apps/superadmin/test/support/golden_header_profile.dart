import 'package:coelo_superadmin/app/shell/superadmin_shell.dart';
import 'package:flutter/widgets.dart';

/// Identidade determinística do cabeçalho global para goldens e testes de
/// página montados sem o host persistente.
///
/// Sem esta cobertura o `SuperadminShell` renderiza o placeholder de sessão
/// ausente (`–`/`Conta`), que não é a composição aprovada e muda o canto
/// superior direito sempre que o contrato de identidade evolui (deriva do
/// cabeçalho, ADR 0041 C1). Envolva a árvore da página (não o `MaterialApp`)
/// para que o shell encontre o escopo.
Widget withGoldenHeaderProfile(Widget child) =>
    SuperadminHeaderProfileScope(profile: const SuperadminHeaderProfile.preview(), child: child);

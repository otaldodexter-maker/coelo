---
title: "E01 — ação honesta nas páginas de erro"
source: "apps/superadmin/lib/features/errors/presentation/screens/superadmin_error_screen.dart"
status: "local-green; E2E aberto"
generated_at: "2026-09-07"
---

Reserva nominal do Coordenador: três helpers de indisponibilidade do router,
preview /dev/errors e actionLabel opcional no componente. Guard, shell,
composição e mutações intactos. O default Tentar novamente de 500/503 continua
disponível aos consumidores com retry real. Nos helpers que navegam ao início,
o label explicita Voltar ao início; preview retorna somente ao início /dev.

Cinco testes RED reproduziram a divergência label/efeito. Após correção, 29
testes passaram, incluindo os oito goldens existentes sem atualizar baselines.
Testes nominais clicam no botão e verificam URI final de início produtivo ou
preview. Negativo mantém /dev bloqueado sem allowDevelopmentPreview explícito.
Analyzer dos três arquivos alterados: sem issues. Review independente read-only:
sem achados no recorte. Nenhum SQL, operação remota ou action_id promovido.

Comando: flutter test --no-pub test/app/router/superadmin_error_routes_test.dart
test/features/errors/presentation/screens (cwd apps/superadmin).

Quatro callsites adicionais identificados fora da reserva inicial: studentManage,
Support sem controller, profile e devStudentManage. Extensão solicitada; não
incluídos nesta evidência. Gate de memória: no-op, correção aplica o contrato
existente de ação explícita; não introduz regra de produto reutilizável nova.

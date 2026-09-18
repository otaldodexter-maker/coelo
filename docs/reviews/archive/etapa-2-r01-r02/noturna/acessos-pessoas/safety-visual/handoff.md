---
source: "TRABALHO-ATUAL.md; adc902eaf; D04-child-safety.md R02; docs/design/design-system.md; LOC-STATUSA11Y01; parent assignment /root/safety_visual"
status: "local-visual-gate-passed; production-and-e2e-open"
generated_at: "2026-09-09"
---

# Safety visual, revisão 1 — 18:18 BRT

Etapa 2 → apps/superadmin → Acessos → Segurança infantil → diretório/cards/status → `child-safety.list`. Reuso também alcança `child-safety.child/create/edit/suspend`, sem certificar essas ações completas. Família administrativa: diretório Instituições. Worktree `C:/Users/adrie/Documents/Coelo.worktrees/e2-noturna-acessos-pessoas`, branch `work/etapa2-noturna-acessos-pessoas`, base `cc5d73bc74de652c91570061aef6ede95b3915a7`. Executor `/root/safety_visual`; pai serializa commits/push. Nenhum arquivo central, compartilhado, router ou SQL alterado nesta revisão.

Objetivo: reaproveitar o candidato R02 e resolver o golden F1 sem reduzir acessibilidade ou substituir a composição aprovada. Incluído: materialização focal, revisão visual, teste de alvo/interação e suíte de apresentação na base conjunta. Fora: bootstrap produtivo, escrita/identidade, SQL, E2E e alteração de shared. Ordem executada: comparar cadeia/base, inspecionar referências e imagens, materializar, prova focal, reconciliar imagem nominal, suíte afetada e checks. Parada: gate visual local demonstrado e residual transferido. Delta real desta revisão: cerca de dez minutos entre leitura/prova/registro; não é estimativa de fechamento E2E.

## Reuso e correção

Materializados seletivamente dez paths de `adc902eaf`, preservando suas correções de controller/contexto/idempotência/negação e decoder/lifecycle/count. Nenhum snapshot de shell foi importado. A troca de IntrinsicHeight por Wrap é exatamente o candidato R02 e o contrato de diretório aprovado; evita a incompatibilidade já demonstrada com LayoutBuilder do status compartilhado.

- `lib/features/safety/application/child_safety_controller.dart`
- `lib/features/safety/data/child_safety_response_decoder.dart`
- `lib/features/safety/domain/child_safety.dart`
- `lib/features/safety/presentation/safety_pages.dart`
- `test/features/safety/application/child_safety_controller_test.dart`
- `test/features/safety/application/child_safety_error_hang_test.dart`
- `test/features/safety/data/child_safety_response_decoder_test.dart`
- `test/features/safety/presentation/safety_page_context_test.dart`
- `test/features/safety/presentation/safety_pages_test.dart`
- `test/features/safety/presentation/safety_unexpected_error_test.dart`

Os caminhos acima são relativos a `apps/superadmin`. Novidade própria: um teste de apresentação garante alvo de pelo menos48px, toque fora do dot24 que expande o rótulo sem abrir o card, foco e Enter que alternam expansão sem abrir o card. O PNG único `test/features/safety/presentation/goldens/child_safety_directory_light_1440.png` foi reconciliado após revisão nominal; não houve nova API, variante ou desenho.

## Fundamento visual e inspeção

Consultados índice Coelo UI (`pattern.institution-card-status`), Design System, matriz de baselines/estados, contratos administrativos, código de Instituições/status e golden aprovado `institution_directory_cards_light_1440.png`. Inspecionados baseline Safety antigo, actual R02 e actual/diff atuais. A regra canônica diferencia círculo visual24 e alvo48; LOC-STATUSA11Y01 registra explicitamente que a caixa maior desloca conteúdo do card. Preservar a imagem antiga por redução do alvo violaria essa regra.

A comparação atual apresenta48196 pixels distintos (3,35%):31895 no conteúdo dos cards, exatamente a região divergente R02, e16301 no shell. Toolbar e card de criar têm zero pixels diferentes. Dentro dos cards permanecem os deslocamentos R02 de cabeçalho+2px, corpo+4px e dot−24px horizontal, com bounds externos preservados. Shell adicional corresponde à disponibilidade de Usuários internos integrada em `d019c109a`; `git diff adc902eaf HEAD -- apps/superadmin/lib/app/navigation/superadmin_navigation.dart` mostra somente retirada de `_developmentOnly` desse item. O shell atual é preservado, incluindo Coelo (Principal); não foi escondido ou substituído no teste.

`before.png`, `after.png` e `diff.png` preservam a comparação, e `compare.py` recalcula os totais sem alterar imagens. A fonte Ahem deste teste verifica geometria e não certifica Nunito Sans em runtime. Imagens de failures foram usadas apenas como diagnóstico; a reconciliação do golden decorre dos contratos e alterações integradas identificados, não de uma atualização cega para obter PASS. Nenhum golden global de Instituições/Locais foi atualizado.

SHA256 antes: `545e85f0ab74b2877977a85c4a3c3634a551912717008f32089e556dfd7374ca`.
SHA256 depois/novo golden: `01ab965db8eb1a0ab90415b7cadf007a795c5639e948b3707c717b694aced330`.
SHA256 Safety pages: `ea37ec3afd6bb78c196ad304a32d43fbfcafac281c4dc695ad16d4b4902bf5e6`.
SHA256 Safety pages test: `f87848948ea543e79c0a942f3454252419bc22bc35cd91a9937e0a55e529a44a`.

## Provas e limites

Campanha noturna Safety visual r1, Windows/Flutter local, fixtures sintéticas, base acima mais materialização descrita. Plano próprio N18: P18/F0/B0/S0/U0; executados18/18 e aprovados18/18. Não somar reruns nem converter o histórico111/112 da R02 em testes atuais. Três casos focais anteriores eram P2/F1; o F1 foi resolvido pela reconciliação documentada e está incluído nos18 finais.

- `focal-before.txt`: alvo/interação e responsividade passam; golden falha por48196px. O wrapper desse primeiro comando não propagou o exit do Flutter: o resultado vem do log explícito P2/F1, não de seu exit0.
- `presentation-green.txt`: `flutter test --no-pub test/features/safety/presentation/safety_pages_test.dart --reporter expanded`, P18/F0, exit0. Inclui negações, estado anterior, edição pendente/identidade, contagem autoritativa, suspensão/cancelamento/reload, exportação adiada, formulário, tabela e diretório light/dark375/768/1024/1440 a200%.
- `analyze.txt`: `flutter analyze --no-pub lib/features/safety test/features/safety`, zero issues, exit0.
- Validador administrativo: `rtk proxy C:/src/flutter/bin/cache/dart-sdk/bin/dart.exe apps/catalog/tool/validate_admin_visual_contracts.dart . apps/catalog/assets/admin-visual-contract-allowlist.json`, exit0 e zero diagnósticos; não produz stdout no sucesso. O bloqueio histórico de Locais não apareceu nesta base. Allowlist intacta.
- `git diff --check`: exit0. Pub get local offline somente preparou o runner; nenhum lockfile versionado alterado.

Gate visual F1 local resolvido. Novas ações FE/BE/E2E certificadas nesta revisão:0/5,0/5,0/5. Diretório ainda precisa composição normal com reader autorizado e provas de leituras/negações; criação precisa lookup de adulto global; escrita/edição/suspensão dependem de contratos e persistência/auditoria reais. SQL43U não foi executado nem certificado aqui. Nenhum botão de escrita foi habilitado por inferência de repository real. MFA/adiamentos preservados.

Próximo passo do pai: revisar e publicar os paths e evidências; integrar seletivamente com adapter/SQL nominais, executar somente provas materiais da composição conjunta e manter os gates produtivos/E2E abertos até evidência. Sem aprovação remota concedida por esta entrega.

Memória: consulta realizada com Root explícito, fonte/projeção da hierarquia administrativa conferidas; no-op porque regra24/48 já canonizada e nenhuma política nova foi criada. Pai centraliza os validadores da rodada. Stash não criado/tocado; WIP é exatamente reuso/teste/golden/evidências acima. Nenhum servidor, porta, container ou runner próprio permanece; slot Flutter liberado ao pai às18:16 BRT. Sem commit/push pelo filho conforme reserva; essa publicação não é declarada realizada.

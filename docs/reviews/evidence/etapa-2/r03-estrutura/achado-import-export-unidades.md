---
title: "Achado — importar/exportar de Unidades não está honesto"
source: "apps/superadmin/lib/features/units/presentation/widgets/unit_file_actions.dart; app/activity/superadmin_activity.dart:259; AGENTS.md (import/export adiados); decisão D3 do Owner em 10/09/2026"
status: "achado do executor; a remoção do diálogo é decisão do Owner"
generated_at: "2026-09-10"
timezone: "America/Sao_Paulo"
---

# A regra

O `AGENTS.md` diz que importação e exportação reais ficam adiadas para depois do
MVP, e que "os botões permanecem visíveis nas telas aplicáveis, com
indisponibilidade honesta e **sem picker, parser, job, arquivo, RPC ou
persistência**". A decisão D3 do Owner, de 10/09, reforça o princípio para as
telas do Principal: "não existe prévia... nenhuma mensagem de prévia ou de
'experiência completa' permanece".

Instituições cumpre isso à risca: os três botões existem e cada um chama
`showSuperadminNotice(context, 'Indisponível nesta etapa')`. Nada mais.

# O que Unidades faz hoje

Unidades não cumpre, em dois pontos.

**Exportar.** Com o gateway ausente — que é o estado de hoje, porque
`superadmin_router.dart:1461` só passa `unitBackendCommands` quando
`hasStructureMutationCapability()` é verdadeiro, e ela é falsa —
`unit_file_actions.dart:45` cai num ramo que:

1. chama `activityController.completeDemoExport(...)`, que insere no sininho uma
   atividade com `status: succeeded`, `progress: 100` e um `fileName`
   (`unidades.csv` ou `unidades.xlsx`) que **não existe**;
2. mostra ao usuário "A exportação está em andamento. Acompanhe pelo sininho."

O usuário vê uma exportação bem-sucedida, com nome de arquivo, para um arquivo
que nunca foi gerado. É o oposto de indisponibilidade honesta.

`completeDemoExport` tem **um único** chamador em produção, este. Todos os outros
usos estão em testes, onde ele é fixture legítima do centro de atividades.

**Importar.** O botão abre `_UnitImportDialog`, que tem seletor de arquivo
(`Key('unit-demo-file-picker')`), prévia com "N linhas válidas" e "N linhas com
erro", e o texto "Linhas rejeitadas não serão persistidas. O relatório permanece
vinculado ao job auditado." Ou seja: picker, parser e vocabulário de job — as
três coisas que a regra nomeia.

# O que proponho

**Exportar:** corrigir agora, igualando a Instituições. É um ramo de dez linhas,
o comportamento certo já existe na tela irmã, e o estado atual afirma ao usuário
algo falso. Não vejo decisão de produto envolvida: ninguém decidiu mostrar uma
exportação bem-sucedida inexistente.

**Importar:** levar ao Owner antes de mexer. Remover o diálogo é uma mudança
visível de produto e o diálogo pode aparecer em anexo aprovado de UI. A pergunta
é curta: o diálogo de importar de Unidades, com seletor de arquivo e prévia de
linhas válidas e rejeitadas, deve ser trocado agora pela mesma indisponibilidade
honesta de Instituições, ou fica como está até a importação real existir?

Minha recomendação é trocar. Um seletor de arquivo que não importa nada ensina o
usuário a esperar um comportamento que o produto não tem, e a regra do
`AGENTS.md` já decidiu isso em tese — o que falta é aplicá-la a esta tela.

Ações afetadas: `units.import`, `units.export`, `units.people-export`.

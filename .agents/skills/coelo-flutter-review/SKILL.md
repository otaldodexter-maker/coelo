---
name: coelo-frontend
description: Use when a Coelo task reviews, audits, corrects, implements, estimates, or verifies front-end behavior in Flutter/Dart apps or the Astro site, including screens, routes, states, responsiveness, accessibility, architecture, tests, and app-specific completion.
metadata:
  source: "AGENTS.md; docs/reviews/coelo-flutter-pendencias.md; specs/050-principal-ui-ux-closure.md"
  status: "active"
  generated_at: "2026-09-09"
---

# Coelo Front-end

> O caminho `coelo-flutter-review/` foi mantido para compatibilidade. O nome e
> o contrato canônicos são **Coelo Front-end** (`coelo-frontend`).

## Chamada padrão: resolver pendências

Invocar `$coelo-frontend` para trabalhar no projeto significa **executar a
resolução das pendências Front-end da Etapa 2**, conforme o
[ciclo de resolução](../coelo-flutter-supabase-review/references/review-scope.md#ciclo-de-resolução-de-pendências).
Usar o recorte informado; sem recorte novo, retomar a subtela pendente do último
checkpoint ou selecionar a próxima ação local executável do inventário.
Informar a escolha e prosseguir sem perguntar novamente se pode corrigir.
Conduzir até o aceite Front-end ou um bloqueio demonstrado, preservando os
limites de autorização. Pedido explícito de explicação, diagnóstico/review
somente leitura ou manutenção da própria skill segue esse pedido.

A entrega deve trazer correção e prova, ou a prova de um aceite já atendido.
Atualizar documentação/percentuais, produzir plano ou abrir uma tela não resolve
por si só a pendência. Ausência de backend não impede fechar os aceites próprios
do cliente; a dependência E2E permanece identificada.

## Princípio e superfícies

Concluir somente o que pertence ao cliente, sem confundir UI visível, rota
aberta, fixture ou teste isolado com ação Front-end concluída.

- `apps/superadmin`, `apps/admin` e `apps/principal`: Flutter/Dart.
- `apps/site`: Astro quando o site entrar em um recorte autorizado.
- Packages compartilhados podem ser alterados apenas quando o contrato listar
  consumidores e regressões. Compartilhamento não autoriza tocar outro app.

Todo contrato nomeia os apps incluídos. Na Etapa 2 atual, o único app é
`apps/superadmin`; “Coelo (Principal)” é o menu dentro dele. `apps/admin`,
`apps/principal` e `apps/site` permanecem fora.

Em abertura, checkpoint e entrega, identificar **Etapa 2 → apps/superadmin →
menu → tela → subtela/estado → action_id**. Para cada subtela trabalhada,
mostrar avanço Front-end e a conclusão E2E conhecida, com base e data; uma
subtela não herda o percentual da tela. Aplicar o
[contrato de métricas e testes](../../../docs/superpowers/specs/2026-09-01-coelo-review-progress-metrics-design.md).

## Dependências por recorte

Confirmar a base integrada e o handoff antes de reutilizar estado local; seguir
a retomada entre worktrees e o limite de repetição de testes do contrato comum.
Ler `AGENTS.md` e o [contrato de recorte](../coelo-flutter-supabase-review/references/review-scope.md).
Usar `docs/reviews/coelo-flutter-pendencias.md` conforme a profundidade do pedido:
ação localizada usa cabeçalho, linhas afetadas e dependências; auditoria ou
conclusão ampla exige leitura integral.

- `coelo-ui` para composição e interação: distinguir família administrativa,
  Principal hospedado no Superadmin e Site. Não impor Instituições a todo app.
  Abrir os manifestos de anexos indicados nas referências dessa skill e o item
  da tela. Correções do Owner e sua integração têm prioridade no recorte;
  preservação do anexo não comprova implementação nem aceite.
- `rtk` para comandos; `coelo-knowledge` para conhecimento durável.
- Em Flutter/Dart, revisão de código carrega `flutter-dart-code-review`;
  mudanças de layout carregam `flutter-build-responsive-layout`.
- Em Astro, carregar `astro` e ferramentas web pertinentes.
- Defeito funcional usa teste que reproduz a causa antes da correção e
  verificação final. Mudança documental/visual simples usa checks proporcionais.
- Usar `coelo-frontend-backend` quando contrato, alteração ou conclusão
  atravessarem cliente e backend. Ajustar um rótulo numa tela de Auth não
  inaugura auditoria Supabase. Registrar dependências conhecidas sem certificá-las.

## Progresso e limite de `verified`

Medir Front-end até o fim do cliente: rota e composition root normais, UI,
loading/empty/error/unauthorized/processing/expired, validação, navegação,
foco/teclado/toque, responsividade, acessibilidade, tema, arquitetura,
contrato do repository/gateway e regressão.

`local-green` indica uma fatia local ainda incompleta. `verified` indica que a
ação chegou ao fim do Front-end; pode usar double fiel no teste, mas runtime
normal não pode cair em fake/fixture. A falta do backend não rebaixa um
`verified`; fica aberta no rastreador integrado.

Régua do MVP (ADR 0034): `verified` exige rota normal abrindo sem fixture nem
fail-closed, formulário salvando pelo repository produtivo e reload mantendo o
estado. Golden divergente, prova de teclado por estado e varredura de
acessibilidade por tela ficam registrados, mas não bloqueiam `verified` no MVP;
entram na revisão profunda. Chaves de composição fechadas
(`structureMutationsEnabled`, adapters `available: false`) devem ser ligadas
assim que o SQL correspondente estiver aplicado, não deixadas em indisponível.

Obter o denominador atual do inventário e rastreador da camada. Não manter
contagens fixas na skill. `pending-verification` exige conferir evidências e
não significa que a implementação inexiste. Quando Astro entrar em escopo, criar
denominador explícito por app ou ampliar o rastreador de forma reconciliada;
nunca somar apps diferentes silenciosamente.

Em trabalho de entrega, reportar o recorte por tela/subtela e o geral conhecido
da Etapa 2 separadamente, com base de IDs, evidência e horário. Consulta de uma
camada reutiliza o snapshot integrado datado; não inicia auditoria das demais.
Se faltarem dados, indicar o dado necessário, sem inventar zero nem percentual.
Tempo usado é medido; se faltar, escrever `não calculável ainda`.

Checkpoint curto, no máximo quatro linhas:

```text
Etapa 2 | apps/superadmin | menu > tela > subtela | action_ids
Feito: telas ligadas/corrigidas ...; testes P/F; verified C/N.
Aberto: ... (o que falta e quem desbloqueia).
Próximo passo: ...
```

Não montar manifestos com hash de arquivo, recibos de recibo nem contagens
P/F/B/S/U por lote: o commit no Git e a saída do `flutter test` são a evidência.

## Contrato de abertura

Registrar o recorte já solicitado, pendências, apps, família visual, ações,
ordem, parada, evidências e estimativa do delta real. Não perguntar tempo por
padrão nem aplicar faixas fixas por tela. Distinguir implementação faltante,
verificação faltante e espera externa, reaproveitando código e testes existentes.

## Contratos Front-end de mídia e arquivos

- O cliente chama apenas o Media Gateway; nunca recebe credencial permanente R2, Stream,
  secret key ou `service_role`. URLs curtas de upload/playback/download podem
  ser consumidas em runtime após reautorização pelo gateway, sem embutir em
  código/assets, persistir como acesso permanente ou registrar em logs.
- Agora prefere Stream pronto e usa MP4 temporário do R2 ou estado de
  processamento enquanto codifica; expiração não vira download nem tela presa.
- Momentos e Acontece reproduzem R2 progressivamente; Stream é seletivo.
- Chat usa R2 para anexos.
- Formulários exibem exportação XLSX com as respostas do formulário. Demais
  import/export mantêm botão acessível com indisponibilidade honesta.

## Execução e checkpoint

Aplicar a verificação proporcional do contrato de recorte. Por `action_id`
em escopo, provar listar, criar, detalhe, editar,
publicar/ativar, excluir/revogar, arquivos, estados e reload visual quando
aplicáveis. Validar mobile/desktop, light/dark, texto 200%, teclado, toque e
foco. Atualizar o rastreador após correção, regressão, bloqueio ou ETA novo.

No checkpoint, informar app, tela/subtela/action, evidência, estado Front-end,
dependência externa, primeiro gate aberto e ETA. Diferenciar atividade
concluída, ação Front-end `verified` e produto pendente.
Ao corrigir, avançar a subtela até o próximo aceite verificável do recorte;
reabrir provas anteriores somente por mudança relevante, regressão ou evidência
insuficiente identificada. Não repetir auditoria ampla a cada retomada.

---
name: coelo-frontend
description: Use when a Coelo task reviews, audits, corrects, implements, estimates, or verifies front-end behavior in Flutter/Dart apps or the Astro site, including screens, routes, states, responsiveness, accessibility, architecture, tests, and app-specific completion.
metadata:
  source: "AGENTS.md; docs/reviews/coelo-flutter-pendencias.md; specs/050-principal-ui-ux-closure.md"
  status: "active"
  generated_at: "2026-09-08"
---

# Coelo Front-end

> O caminho `coelo-flutter-review/` foi mantido para compatibilidade. O nome e
> o contrato canônicos são **Coelo Front-end** (`coelo-frontend`).

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

## Dependências por recorte

Ler `AGENTS.md` e o [contrato de recorte](../coelo-flutter-supabase-review/references/review-scope.md).
Usar `docs/reviews/coelo-flutter-pendencias.md` conforme a profundidade do pedido:
ação localizada usa cabeçalho, linhas afetadas e dependências; auditoria ou
conclusão ampla exige leitura integral.

- `coelo-ui` para composição e interação: distinguir família administrativa,
  Principal hospedado no Superadmin e Site. Não impor Instituições a todo app.
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

Obter o denominador atual do inventário e rastreador da camada. Não manter
contagens fixas na skill. `pending-verification` exige conferir evidências e
não significa que a implementação inexiste. Quando Astro entrar em escopo, criar
denominador explícito por app ou ampliar o rastreador de forma reconciliada;
nunca somar apps diferentes silenciosamente.

Quando medir progresso, reportar geral e recorte separadamente, base de IDs,
evidência e horário. Tempo usado é medido; se faltar, escrever `não calculável
ainda`.

```text
Progresso geral conhecido — Concluído: ... (.../... unidades)
Progresso geral conhecido — Restante: ... (.../... unidades)
Tempo usado no trabalho geral concluído: ...
Tempo estimado para finalizar o backlog geral: ...
Progresso do recorte — Concluído: ...
Progresso do recorte — Restante: ...
Tempo usado no trabalho concluído no recorte: ...
Tempo estimado para finalizar o recorte: ...
Base do cálculo: action_ids/gates, app, evidência e horário.
```

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

---
name: coelo-frontend
description: Use when a Coelo task reviews, audits, corrects, implements, estimates, or verifies front-end behavior in Flutter/Dart apps or the Astro site, including screens, routes, states, responsiveness, accessibility, architecture, tests, and app-specific completion.
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

## Dependências obrigatórias

Sempre ler `AGENTS.md`, `docs/reviews/coelo-flutter-pendencias.md` e usar:

1. `coelo-ui`, autoridade visual e de interação;
2. `rtk`, para comandos com wrapper compatível;
3. `ponytail`, para a menor solução que corrige a causa raiz;
4. `test-driven-development` e `verification-before-completion`;
5. `coelo-knowledge` quando houver conhecimento durável.

Em Flutter/Dart, usar também `flutter-dart-code-review` e
`flutter-build-responsive-layout`. Em Astro, usar `astro` e as ferramentas de
browser/validação web aplicáveis. Quando houver Auth, persistência, Supabase,
R2, Stream ou alegação ponta a ponta, usar `coelo-frontend-backend`.

Consultar brevemente o rastreador integrado mesmo quando o backend estiver fora
para registrar dependências sem certificá-las.

## Progresso e limite de `verified`

Medir Front-end até o fim do cliente: rota e composition root normais, UI,
loading/empty/error/unauthorized/processing/expired, validação, navegação,
foco/teclado/toque, responsividade, acessibilidade, tema, arquitetura,
contrato do repository/gateway e regressão.

`local-green` indica uma fatia local ainda incompleta. `verified` indica que a
ação chegou ao fim do Front-end; pode usar double fiel no teste, mas runtime
normal não pode cair em fake/fixture. A falta do backend não rebaixa um
`verified`; fica aberta no rastreador integrado.

O rastreador atual mede 207 ações Flutter. Quando Astro entrar em escopo, criar
denominador explícito por app ou ampliar o rastreador de forma reconciliada;
nunca somar apps diferentes silenciosamente.

Sempre reportar progresso geral e do recorte separadamente, base de IDs,
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

Se o usuário não informou tempo, perguntar. Se já definiu `Completa`, todas as
pendências ou execução até terminar, não perguntar novamente. Antes da primeira
edição, registrar apps, telas/subtelas/actions, objetivo, incluído/fora, ordem,
critério de parada, evidências, nível e ETA recalculado.

| Nível | Referência inicial | Limite |
| --- | ---: | --- |
| `Básica` | 30–90 min por ação simples | Não conclui tela. |
| `Intermediária` | 2–6 h por ação/tela simples | Mínimo recomendado. |
| `Avançada` | 1–2 dias por tela | Pode permanecer parcial. |
| `Completa` | 2–5 dias por tela | Pode sustentar conclusão integral. |

As faixas são referência pré-inventário, não promessa. Reduzir recorte em vez
de remover testes, acessibilidade ou regressão.

## Contratos Front-end de mídia e arquivos

- O cliente chama apenas o Media Gateway; nunca recebe credencial R2, Stream,
  secret key ou `service_role`.
- Agora prefere Stream pronto e usa MP4 temporário do R2 ou estado de
  processamento enquanto codifica; expiração não vira download nem tela presa.
- Momentos e Acontece reproduzem R2 progressivamente; Stream é seletivo.
- Chat usa R2 para anexos.
- Formulários exibem exportação XLSX com as respostas do formulário. Demais
  import/export mantêm botão acessível com indisponibilidade honesta.

## Execução e checkpoint

Usar teste primeiro. Por `action_id`, provar listar, criar, detalhe, editar,
publicar/ativar, excluir/revogar, arquivos, estados e reload visual quando
aplicáveis. Validar mobile/desktop, light/dark, texto 200%, teclado, toque e
foco. Atualizar o rastreador após correção, regressão, bloqueio ou ETA novo.

No checkpoint, informar app, tela/subtela/action, evidência, estado Front-end,
dependência externa, primeiro gate aberto e ETA. Diferenciar atividade
concluída, ação Front-end `verified` e produto pendente.

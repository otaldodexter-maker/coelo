---
source: "docs/superpowers/plans/2026-07-22-coelo-ui-foundation-componentization-catalog.md"
status: "complete"
generated_at: "2026-07-24"
---

# Checkpoint — Task 13 concluída

## 1. Resultado obtido

Login, esqueci minha senha e redefinição receberam baseline light/dark e matriz
responsiva antes de qualquer tentativa de promoção. A comparação demonstrou que
as primitives do core não são equivalentes aos widgets auth; a conclusão
correta foi manter todos locais.

## 2. Arquivos alterados

- três testes golden de auth;
- novo `superadmin_auth_responsive_matrix_test.dart`;
- quatro baselines reconciliados após inspeção;
- três baselines dark adicionados;
- plano, progresso e relatório da Task 13.

## 3. Componentes criados, promovidos ou mantidos locais

Nenhum componente público foi criado ou promovido. `LoginTextField`,
`LoginFeedback`, forms, header, card, ações e estados de recuperação permanecem
locais. O padrão de marca compartilhado no app já existente foi apenas
verificado.

## 4. Diferença visual encontrada

Os antigos goldens ainda mostravam o coelho isolado. O estado atual aprovado
usa:

- light: logo branca em círculo laranja;
- dark: logo laranja em círculo branco.

Não foi encontrada outra diferença visual.

## 5. Testes executados

- 8/8 goldens após reexecução sem atualização;
- 30/30 casos responsivos/texto ampliado;
- 105/105 testes de auth;
- análise estática limpa;
- busca de estilos locais e imports indevidos: zero;
- revisão independente: zero P0, P1 e P2.

## 6. Pendências

P3: viewports intermediários têm proteção estrutural, não pixel a pixel. O
catálogo em `8772` continua temporariamente liberado sem credenciais, isolado da
versão oficial protegida.

## 7. Decisão que precisa de aprovação

Nenhuma decisão adicional para encerrar a Task 13.

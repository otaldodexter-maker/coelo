---
title: "F-AUTHOR02 — contexto e cliente nominal de rascunhos"
source: "Contrato 83c552 e fechamento do Coordenador; reserva 20260908032100"
status: "approved-executing-locally"
generated_at: "2026-09-08"
---

# Contrato

Conectar somente rascunhos internos nunca publicados no Superadmin, com reader
de instituições paginado forms.manage e contexto do formulário manage OU read.
Sem People, grants implícitos, publicação/aplicações/transferência, execução SQL
ou produção nesta frente. Disponibilidade draft-only não representa grants false.
Root writer único; reviews paralelos read-only. Estimativa local: 60–90 minutos,
sem promessa de E2E antes do replay exclusivo Eng1.

# Passos

1. DTO/API pequena nominal; testes RED de envelope, paginação, cursores,
   identidade e proibição de fallback. Reusar DTO canônico de definição.
2. Implementar adapter estrito para os três endpoints nominais aprovados.
3. Testar editor de leitura sem catálogo, criação paginada >20, troca de contexto,
   persistência/reload simulados, save e disponibilidade separada.
4. Conectar editor por interface nominal separada, preservando DEV e sem mudar
   rotas produtivas antes do gate de integração. Usar componentes visuais canônicos.
5. Preparar testes SQL próprios e migration
   `20260908032100_superadmin_forms_authoring_institution_context_v2.sql`;
   manter pacote01 intacto. Capabilities do reader só manage efetivo, instituição
   vinculada sob lock; reader de candidatos active+notdeleted no escopo real.
6. Review independente, regressões/analyzer/visual, evidência e pins para Eng1.

Critério local: contratos e comportamento verificados; gates SQL/concorrência,
persistência real, segurança e E2E continuam abertos enquanto não executados.
Atualizar plano/evidência da frente e informar Coordenador, sem trackers centrais.

# Progresso local

Passos 1–5 implementados, sem execução SQL e sem wiring produtivo. Passo 6:
198/198 testes em nove suítes Forms, analyzer dos cinco arquivos limpo, validator
visual exit 0. Review independente corrigiu allowlist/version do save, acesso a
detalhes read-only e estado após negativa; SQL/fixtures aprovados estaticamente.
Evidência: `docs/reviews/evidence/etapa-2/formularios-cuidado/2026-09-08-authoring-context-local-package.md`.
Gate de replay/integrado continua aberto; conclusão local não é E2E.

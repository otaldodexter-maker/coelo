---
title: "PERS-PAGE-LIFECYCLE02 — entrega de resultado da página"
source: "specs/019-superadmin-people-directory.md"
status: "local-verified"
generated_at: "2026-09-07"
---

# Recorte aprovado pelo coordenador

Somente `person_form_page.dart`, teste nominal e evidência. Não alterar
validação, campos, componentes compartilhados, router, entidades ou backend.
Complementa PERS-LIFECYCLE01, sem encerrar Pessoas/E2E.

Objetivo: impedir callback duplicado e resposta tardia entregue à pessoa,
repository ou intenção errada. O RED inicial comprovou duas chamadas de
`onSaved` para uma única escrita compartilhada.

Implementação delimitada: guard síncrono antes de iniciar save; geração da
operação e snapshot dos campos/vínculos; conferir identidade do view model
antes de callback/erro; recriar estado do formulário ao mudar original/repository
e descartar opções pendentes do contexto anterior. Não reidratar receipt nem
inventar versão de retry; isso permanece fora do contrato local.

## Ordem e gates locais

- [x] Reproduzir callback duplicado antes da correção.
- [x] Negativas para dispose, troca de pessoa/repository e edição posterior.
- [x] Correção mínima, 11/11 focal, 61/61 regressão e analyzer sem issues.
- [x] Review independente sem bloqueantes e evidência para handoff central.

Estimativa local: 30–60 minutos. Nenhuma escrita remota ou integração legada.

Evidência: `docs/reviews/evidence/etapa-2/estruturas/2026-09-07-person-page-save-lifecycle.md`.

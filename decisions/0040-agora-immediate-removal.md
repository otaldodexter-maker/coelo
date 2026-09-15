---
title: "Remoção imediata de publicações do Agora"
source: "Owner em 2026-09-15; decisions/0032-mvp-private-media-r2.md; decisions/0034-mvp-remote-application-and-acceptance-bar.md; decisions/0037-principal-host-context-and-media-controls.md; decisions/0038-owner-decisions-etapa2-backlog-20260914.md; specs/036-principal-now-publication-mvp.md"
status: "accepted"
generated_at: "2026-09-15"
updated_at: "2026-09-15"
lifecycle: "current"
supersedes: "decisions/0032-mvp-private-media-r2.md (ciclo da remoção explícita do Agora); decisions/0034-mvp-remote-application-and-acceptance-bar.md (Decisão 6, somente nesse ponto)"
action_id: "agora.remove"
audience: "team"
---

# ADR 0040 — Remoção imediata de publicações do Agora

## Decisão do Owner

Em 15/09/2026, o Owner decidiu substituir o comportamento **expiração-only**
da remoção explícita do Agora por **remoção imediata**. A expiração automática
de 24 horas continua sendo o prazo normal de validade quando ninguém remove a
publicação antes. Esta ADR cria o `action_id` oficial `agora.remove`.

Esta decisão formaliza o produto e o contrato de aceite. Ela não declara a
implementação, a aplicação de migration, o deploy de Edge Function ou o aceite
produtivo como concluídos. O inventário mantém `agora.remove` pendente até que
o pacote técnico seja implementado e provado.

## Contrato de remoção

- O comando recebe `request_id`, `publication_id`, `expected_version` quando a
  tela possuir a versão e motivo opcional limitado a 280 caracteres. O ator,
  tenant, instituição, unidade, grupo, autoria e capacidade são resolvidos e
  revalidados no servidor; nenhum desses valores vindos do cliente concede
  acesso.
- Somente o autor da publicação com a capacidade contextual de remoção, ou o
  papel institucional explicitamente autorizado pelo contrato vigente, pode
  remover. Outro tenant, contexto revogado, publicação inexistente, já removida
  ou conflito de versão falham de modo seguro e não revelam a existência do
  registro.
- A operação é idempotente por ator e `request_id`. Repetição da mesma
  requisição devolve o recibo; reutilização do mesmo identificador com payload
  diferente falha. `expected_version` evita apagar uma alteração concorrente.
- O estado de remoção é materializado com `removed_at`,
  `removed_by_person_id` e motivo sanitizado, ou campos equivalentes no modelo
  final. A publicação deixa de aparecer no feed e não pode receber novo ticket
  ou URL após a confirmação da transação.

## Revogação e retenção da mídia

- A revogação lógica é imediata: o catálogo e o gateway passam a negar leitura
  da publicação e de seus assets quando `removed_at` está preenchido. Isso
  inclui leitura pelo autor, outro membro do mesmo tenant e qualquer tenant
  diferente, salvo um fluxo de auditoria server-side explicitamente autorizado.
- Se houver cópia HOT no Stream, o comando solicita sua remoção imediatamente
  e um worker/sweep idempotente repete a limpeza em caso de falha transitória.
  A cópia não pode voltar a ser servida enquanto a publicação estiver removida.
- O objeto privado do R2 entra em purge físico idempotente como parte da
  remoção explícita: o comando solicita a exclusão e um worker/sweep repete a
  operação até confirmação ou erro auditado. O catálogo, o recibo e a
  auditoria permanecem, mas o binário não fica retido no fluxo normal. Nenhum
  ticket ou URL nova é emitido; tickets do gateway são invalidados na transação
  e URLs assinadas anteriores deixam de resolver após a confirmação do purge,
  sem renovação. Retenção jurídica excepcional exige decisão separada.
- Não há bucket público, path escolhido pelo cliente, segredo no cliente ou
  acesso direto ao R2/Stream. O Postgres continua sendo a fonte de catálogo,
  ownership, autorização, retenção e auditoria, conforme ADR 0032.

## Auditoria mínima

Cada tentativa autorizada ou negada deve ser auditável sem PII desnecessária,
com `action_id=agora.remove`, resultado (`success`, `denied`, `conflict` ou
`error`), ator resolvido, tenant/contexto, `publication_id`, `asset_id` quando
aplicável, `request_id`, versão anterior/nova, horário, motivo sanitizado e
resultado da remoção da cópia Stream. Não registrar token, URL assinada,
conteúdo binário, CPF, nome de criança ou segredo. Repetições idempotentes não
criam uma segunda remoção; a auditoria deve preservar a correlação do recibo.

## Critério de aceite de `agora.remove`

O action só pode ser promovido quando houver, no mesmo pacote versionado:

1. teste local de contrato, idempotência e conflito de versão;
2. pgTAP/RLS para autoria, capacidade, tenant, contexto e negativas
   cross-tenant/revogado/inexistente;
3. prova da rota normal autenticada: publicar, reler, remover, receber sucesso,
   recarregar e confirmar ausência imediata;
4. prova de que o gateway nega novos tickets/URLs depois da remoção, de que o
   objeto R2 e a cópia Stream entram em purge confirmado ou retry auditado, e de
   que catálogo/recibo/auditoria permanecem;
5. auditoria minimizada, sem dados sensíveis, e teste de repetição segura;
6. migration/Edge versionada, ordem, rollback/recuperação, secret scan,
   inventário e gate de entrega reconciliados.

Produção só pode ser aplicada após revisão do pacote e confirmação explícita do
Coordenador no fluxo R14. A autorização nominal já registrada pelo Owner para
R2/Edge/Stream da Sessão E cobre a execução técnica deste pacote, mas não
substitui os testes nem promove o estado do inventário.

## Fora desta decisão

Esta ADR não altera Agora/Momentos/Acontece de forma genérica, não cria remoção
imediata para outras superfícies, não transforma a expiração automática em
purge do master R2 e não abre recuperação de Auth, Planos comerciais ou
qualquer escopo da Etapa 3.

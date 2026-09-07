---
title: "N01 — testes preparados para replay isolado"
source: "reserva E2E3-N01; revisão local de SQL; contrato worker e orientação Eng2 pelo Coordenador"
status: "prepared-not-executed; no-migration-or-remote-change"
generated_at: "2026-09-07"
---

# Situação

Três arquivos pgTAP preparados, revisados estaticamente e ainda NÃO executados.
Não existe implementação N01 nesta entrega. A migration nominal continua
reservada: `20260907222708_superadmin_notice_publication_pipeline.sql`.
Replay depende do perfil e da janela serializados pelo Coordenador/Eng1.

| Arquivo em supabase/tests | Assertivas | Recorte |
| --- | --- | --- |
| superadmin_notice_publication_pipeline_test.sql | 17 | Autor interno sem people bridge; publish/replay gera um job scheduled/queued; detail/directory não ativam por relógio; versão/audiência congeladas; zero entrega |
| superadmin_notice_publication_worker_security_test.sql | 14 | ACL dos wrappers; ausência de role, worker NULL e limites NULL/zero/excessivo negados antes de operar jobs |
| superadmin_notice_publication_metrics_test.sql | 10 | Geração atual, zero sem ponteiro, exclusão de recibos antigos/legados, pause não confunde versão administrativa, preservação dos receipts |

Todos usam begin/rollback. O teste de worker deve rodar somente no projeto
isolado: uma implementação defeituosa pode alcançar jobs existentes nos casos
de NULL. O teste de métricas usa fixtures diretas de jobs/recipients e não
prova que o worker materializa ou entrega mensagens. Os atores humanos dos
comandos são exclusivamente identidades internas; pessoas de fixture são
destinatários, não bridges de autoria.

## Gates da implementação

- Manter wrappers humanos v2 com envelope e claim/run worker com formato raw
  vigente; o Edge worker lê state diretamente.
- Publish/resume/edit scheduled criam geração nominal de publicação;
  publication timestamp e ponteiro atual somente após materialização completa.
  Uma edição que reenfileira deve validar a capacidade de publicação, além
  da capacidade de edição, sem usar permissões do publicador antigo para
  autorizar payload modificado por outro ator.
- Remover o update de refresh_lifecycle que ativa scheduled por relógio;
  preservar expiração. Leitura nunca substitui worker.
- Materializador valida status, versão, prazo, elegibilidade e regras congeladas
  antes de inserir; não deixar caminho direto sem proteção. Receipts devem
  nascer ligados ao job e versão, sem reconciliação por timestamp.
- Ordem única de locks notice → job → linhas atuais de autorização → receipts
  → auditoria. Claim permanece job-only/SKIP LOCKED em transação curta.
- Autor do enqueue mantém identity/auth_link/membership originais no job.
  Worker revalida link, membership, role, grant e escopo atuais a cada página
  e antes de active; não fabrica JWT nem sessão humana.
- Conforme orientação Eng2: auditoria humana v2 no comando, conclusão v1
  sistema em audit.audit_logs, correlation_id=job.id. Não usar
  notice_admin_audit para ator interno/sistema, pois exige pessoa. Sessão/AAL
  pertencem ao comando humano aceito, não à identidade do worker.
- Métricas seguem current_publication_job_id. Pause pode alterar
  management_version sem invalidar a publicação já concluída.

Os testes preparados não cobrem ainda todas essas obrigações. Restam páginas
parciais/finais, reautorização, audiência filtrada/cross-tenant, resume/edit,
auditoria de conclusão, concorrência com duas sessões e integração real.

## Dependências do replay

Perfil nominal precisa dos quatro prerequisites indicados pelo Eng1:
20260812002900, 20260812003000, 20260820212340 e 20260820220500.
O histórico contém referências public.notice_events após movimento para
analytics e inserts de capabilities sem labels após endurecimento NOT NULL.
São bloqueios de composição do perfil, não erros para mascarar nas fixtures:
não tornar campos nullable, criar catálogo paralelo ou editar migrations antigas.

Gate de memória: evidência técnica preparada; sem nova decisão de produto ou
promoção de backend/E2E.

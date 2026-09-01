---
title: "Circulares versionadas e mídia privada no Supabase Storage"
source: "specs/037-principal-circulars.md; decisão explícita do Owner em 2026-08-21; decisions/0010-private-media-r2.md; decisions/0022-superadmin-activities-and-identity-storage.md; decisions/0026-happens-mvp-private-supabase-storage.md"
status: approved-exception
generated_at: "2026-08-21"
---

# ADR 0027 — Circulares versionadas e mídia privada no Supabase Storage

> **Complemento supersedente do MVP:** a ADR 0030 generaliza Supabase Storage
> privado para toda mídia do MVP. O contexto abaixo que apresenta R2 como regra
> vigente permanece apenas histórico.

## Contexto

As ADRs 0010 e 0022 reservam Cloudflare R2 para mídia operacional, enquanto a
ADR 0026 permite Supabase Storage privado temporariamente somente em Acontece e
Agora. Circulares é conteúdo operacional novo e, portanto, não poderia herdar a
exceção por analogia.

Em 2026-08-21, durante a implementação da spec 037, o Owner decidiu
explicitamente: Circulares não usará R2 e usará Supabase Storage.

## Decisão

Circulares possui domínio e revisões próprios e aparece no Acontece por projeção
`UNION ALL`, sem criar post duplicado. Conteúdo e respostas são vinculados à
revisão publicada; uma nova revisão preserva histórico e requer nova resposta.

A mídia usa exclusivamente o bucket privado `coelo-circulars-private`. Flutter
não recebe `service_role`, não escolhe object key e não recebe URL permanente.
Uma Edge Function autenticada prepara upload assinado, baixa o objeto para
validar assinatura real, MIME, extensão, tamanho e checksum, finaliza metadados
idempotentemente e emite leitura assinada por até 120 segundos após nova
autorização.

O upload assinado respeita a validade nativa de duas horas do Supabase Storage;
o cliente não persiste o token e a finalização exige uma segunda autorização
com ticket de dois minutos. A aplicação não deve representar esse token como se
expirasse antes do prazo real fornecido pelo provedor.

## Limites da exceção

- a decisão vale somente para Circulares;
- Acontece e Agora continuam sob a dívida temporária da ADR 0026;
- Moments e demais mídias operacionais não migram por analogia;
- Postgres permanece fonte canônica de tenant, ownership, público, estado,
  revisão e auditoria;
- bucket público, segredo no cliente e grant direto de escrita permanecem
  proibidos;
- eventual migração futura de Circulares exige nova ADR e preservação dos
  contratos de domínio/repository.

## Consequências

O gateway pode validar bytes reais sem proxy de base64, mas a finalização baixa
o arquivo privado e deve ser monitorada para custo e limite de execução. Órfãos
são reclamados por worker idempotente. O conflito com as ADRs gerais fica
registrado em `docs/open-questions.md` e resolvido por esta exceção explícita.

---
title: "Storage privado, anonimato e exportações multipart de Formulários"
source: "docs/superpowers/specs/2026-08-13-superadmin-forms-end-to-end-design.md; decisions/0020-backend-authorization-application-security.md; decisions/0021-operational-import-export-files.md; decisions/0022-superadmin-activities-and-identity-storage.md"
status: approved
generated_at: "2026-08-13"
---

# ADR 0025 - Storage privado e exportações de Formulários

> **Complemento supersedente do MVP:** a ADR 0030 define Supabase Storage
> privado para toda mídia do MVP. A ADR 0031 adia exportações reais para depois
> do MVP; o botão pode permanecer visível, mas não haverá job, arquivo ou
> download real agora. O texto abaixo é preservado como contrato futuro.

## Contexto

Formulários pode receber fotos e galerias em respostas e produzir CSV, XLSX e
ZIP com mídias. Esses arquivos não são conteúdo de Happens, Now ou Moments, e o
contrato da ADR 0021 não cobre ZIP incremental maior que uma execução/upload.

Respostas anônimas exigem separação persistente entre a participação nominal,
usada somente para elegibilidade, e o conteúdo enviado.

## Decisão

Fotos e galerias de Formulários usam **Supabase Storage privado no MVP**. Esta é
uma exceção específica à regra de mídia operacional no Cloudflare R2 e não
autoriza outras features por analogia. Postgres permanece como fonte de verdade
para autorização, owner, tenant, ocorrência, resposta, MIME, tamanho, checksum,
estado e auditoria.

Exportações CSV, XLSX e ZIP são jobs privados, idempotentes e auditados. ZIPs
grandes são escritos por stream e enviados por multipart server-side, com lease
retomável, partes persistidas no job e expiração máxima de 24 horas. Credenciais
S3, `service_role` e secret keys ficam exclusivamente no worker.

Uma resposta anônima não armazena `person_id`, `participation_id` nem chave
compartilhada com a participação. Consulta nominal de participação é operação
Owner separada, exige motivo, capability própria e auditoria, e nunca retorna
ID, ordem ou horário de resposta.

## Controles obrigatórios

- bucket privado `coelo-forms-private`, paths opacos e JPEG/PNG/WebP;
- até 10 MiB por imagem e cinco imagens por pergunta, validados no servidor;
- prepare/finalize/discard server-side; nenhum sucesso simulado no cliente;
- download somente após reautorização e URL assinada curta;
- exportação neutraliza fórmulas e evita produto cartesiano multivalorado;
- worker usa claim/lease idempotente e não mantém rede sob lock de banco;
- artefatos e multipart incompletos expiram em até 24 horas;
- logs não incluem respostas completas, fotos ou segredo de edição;
- modo anônimo/identificado torna-se imutável na primeira publicação.

## Riscos e decisões adiadas

Não haverá retenção automática de respostas ou mídias até aprovação jurídica.
A cópia anônima exata e a exceção operacional de participação nominal para
Owner exigem revisão jurídica antes de produção pública. Perder o segredo opaco
de edição anônima torna a edição irrecuperável.

## Consequências

O adaptador de mídia permitirá migração futura para R2 sem alterar domínio ou
UI. Esta decisão complementa as ADRs 0021 e 0022, mas não substitui o R2 para
Happens, Now e Moments.

## Referências verificadas

- https://supabase.com/docs/guides/storage/buckets/fundamentals
- https://supabase.com/docs/guides/storage/uploads/s3-uploads
- https://supabase.com/docs/guides/cron
- https://supabase.com/docs/guides/functions/limits
- https://supabase.com/changelog?types=breaking-change

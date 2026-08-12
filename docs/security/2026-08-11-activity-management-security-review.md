---
title: Revisao de seguranca da gestao de Atividades
source: ADR 0020; ADR 0022; plano de Atividades aprovado em 2026-08-11
status: implementation-review
generated_at: 2026-08-11
---

# Revisao de seguranca da gestao de Atividades

## Modelo de ameacas

O Flutter e ambiente hostil. UUID, handle, filtros, paginacao, deep links,
membership em cache, caminhos de Storage e payloads CSV/XLSX podem ser alterados
diretamente. O backend deve selecionar o recurso dentro do conjunto autorizado,
revalidar ator, MFA, capability, tenant, instituicao, unidade, turma, crianca e
profissional e falhar fechado sem revelar existencia indevida.

Riscos prioritarios: IDOR/BOLA por troca de pais/filhos; elevacao por capability
decidida no cliente; stale membership; replay e concorrencia; SQL/formula
injection; XSS/URL perigosa; upload com MIME, assinatura, tamanho ou caminho
forjado; exportacao de dados infantis; vazamento de segredo ou signed URL.

## Controles ASVS

| Area | Baseline | Evidencia esperada |
|---|---|---|
| V2 Auth | L2/L3 | sessao valida, MFA AAL2 para mutacoes e arquivos |
| V4 Access control | L3 | capabilities server-side, RLS, escopo hierarquico, deny-by-default |
| V5 Validation | L2/L3 | allowlists, limites, constraints, SQL parametrizado, CSV neutralizado |
| V7 Logging | L3 | auditoria before/after, ator, objeto, resultado e idempotency key |
| V8 Data protection | L3 | minimizacao infantil, bucket privado, URLs curtas, sem enumeracao |
| V12 Files | L3 | nome, MIME real, assinatura, 5 MB, checksum, path server-side e retencao |
| V14 Configuration | L2 | grants explicitos, functions sem PUBLIC, search_path fixo, secret scan |

O comando de criação de modelo institucional expõe somente a RPC
`superadmin_create_activity_template` a `authenticated`; a implementação e
o recibo idempotente permanecem em `app_private`, sem EXECUTE/SELECT para
clientes. O backend exige `activities.templates.manage`, MFA AAL2, instituição
ativa, subtipo ativo e governança allowlisted, limita nome/descrição e audita
`activity.template.create`.

## Matriz negativa obrigatoria

- Usuario A troca tenant, instituicao, unidade, turma, crianca ou profissional de B.
- Usuario autenticado sem `activities.read/manage/import/export` chama RPC direto.
- Parent e child pertencem individualmente ao ator, mas nao entre si.
- Handle/alias de outro escopo e usado em rota, busca, update ou exportacao.
- Filtros/paginacao tentam ampliar o conjunto autorizado ou inferir contagens.
- Membership e revogada entre duas requisicoes ou durante retry.
- `expected_version` antigo, idempotency key reutilizada com payload diferente e
  duplo submit concorrente.
- CSV/XLSX com formula, header duplicado, UUID invalido, linha excessiva, MIME ou
  assinatura divergente e path traversal.
- Signed URL expirada ou objeto de outro job e reutilizado.
- Bundle web, diff e logs sao inspecionados por service role, secrets, JWT e PII.

## Estado da verificacao

Testes Dart focados cobrem falha fechada do repository e sequence guard. Testes
SQL estruturais e cross-tenant foram adicionados, mas a execucao local permanece
bloqueada porque Docker/Podman nao esta instalado e o Supabase local nao responde
em `127.0.0.1:54322`. Nenhuma verificacao bloqueada deve ser reportada como verde.
O arquivo `activity_template_create_test.sql` adiciona 20 asserts para o novo
comando; eles também permanecem pendentes de execução real pelo mesmo bloqueio.

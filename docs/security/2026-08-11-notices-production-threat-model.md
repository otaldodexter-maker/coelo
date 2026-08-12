---
title: "Avisos: threat model e controles de produção"
source: "OWASP ASVS; docs/superpowers/specs/2026-08-05-superadmin-notices-mvp-design.md; ADR 0020"
status: "implementation"
generated_at: "2026-08-11"
---

# Avisos: threat model e controles de produção

## Limites de confiança

Flutter, rotas, IDs, filtros, cursores, seleção de público e configuração
visual são entrada hostil. Somente Postgres/RLS/RPC e o worker server-side
autorizam e congelam destinatários. O cliente usa exclusivamente publishable
key e nunca recebe segredo, lista fora do escopo ou payload de auditoria.

## Matriz de ameaças e controles

| Ameaça | Controle ASVS e decisão |
| --- | --- |
| IDOR/BOLA por aviso, instituição, unidade, turma ou pessoa | ASVS L2: buscar já dentro do escopo autorizado; validar membership, capability e cadeia pai/filho em toda RPC; resposta fechada sem revelar existência. |
| Amplificação por `select all` ou filtro adulterado | ASVS L3: filtro allowlisted, resolução server-side, teto/rate limit, AAL2 para publicação crítica/global e snapshot imutável de destinatários. |
| Membership/JWT obsoleto | Recalcular autorização no comando e no worker; nunca confiar em cache de tela. |
| Replay, duplo clique e corrida de status | `request_id`, versão esperada, lock transacional e recibo idempotente por ator/operação/payload. |
| XSS, URL perigosa e conteúdo ativo | Texto renderizado como texto; sem HTML/Markdown/WebView; HTTPS e deep links internos allowlisted; limites no banco. |
| Vazamento por logs, métricas ou erro | Auditoria guarda ator/contexto/ação/resultado/digests, nunca corpo, mídia ou destinatários; contagens sempre limitadas ao escopo. |
| Bypass de RLS/RPC | RLS deny-by-default, policies separadas, grants mínimos, views `security_invoker`; funções privadas sem EXECUTE público e `search_path` fixo. |
| Imagem sem arquitetura aprovada | Publicação falha fechada até decisão Storage × R2; nenhum placeholder ou sucesso simulado. |
| Segredo no bundle | Somente publishable key no Flutter; varredura de fonte/build web e `.gitignore`. |

## Evidência obrigatória

- pgTAP/SQL com ator autorizado e matrizes anon, sem capability, cross-tenant,
  parent/child trocado, AAL1, membership revogada, replay e concorrência.
- Testes do adapter comprovando nomes de RPC, cursores, payloads tipados e
  mensagens seguras.
- Testes widget para estados loading/empty/no-results/failure/unauthorized e
  para seleções que nunca viram autorização local.
- Secrets scan no diff e no build web; advisors e consulta real após reset
  local do Supabase.

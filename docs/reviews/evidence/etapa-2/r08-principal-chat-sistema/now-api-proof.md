---
fonte: now_api_smoke.py; gateway/RPCs produtivos; autorizacao nominal C0 R08
status: medido-api-sem-aceite-ui
data: 2026-09-12
---

# Agora — PNG privado por API

apps/superadmin → Coelo (Principal) → Agora → publicar/ler →
agora.create/agora.publish/agora.view. Processo serial exit0;
`now-api-manifest.json` registra 19 operacoes/verificacoes aprovadas,
nao 19 testes ou action_ids distintos. **Sem prova pela UI**.

Prepare R2/PUT sem redirect/finalize/publicacao/leitura/reload retornaram 200.
O PNG sintetico 16×16 de 82 bytes retornou com SHA-256 identico ao enviado.
Leitura anonima foi negada401; ticket aleatorio autenticado foi negado403.
URL de leitura com TTL60s retornou403 apos espera real. Sessao propria
encerrada204. Nenhum token, senha, URL assinada ou chave no manifest.

O script confirmou novamente a hierarquia QA d0c4/0001 → d0c4/0002 →
grupo368a5cea, sob o usuario qa-r06-principal existente. C0 autorizou uma
publicacao sintetica, audiencia school_staff, preservada ate a expiracao
natural; nao foi criado nenhum usuario, papel, estrutura ou recurso Cloudflare.

- Publicacao: `392ee49a-265b-42e3-9c5b-ed44a34028f8`.
- Ativo: `0451e371-7f79-4501-b439-7da426ca4019`.
- `expires_at` retornado pelo servidor: **2026-09-13T15:24:39.452258Z**.

A expiracao da publicacao em24h **nao foi executada/verificada neste turno**.
Ela e distinta da expiracao da URL de leitura. O master R2 permanece privado
sob a retencao vigente. Nenhum DELETE, encurtamento de prazo ou cleanup
fisico foi executado. IDs ficam no manifest ate o fim da Etapa2.

H09 possui prova separada do disparador em
`r08-coordenacao/lote56-cron-execucoes.md`; nao usar filtro do feed ou este
teste de URL para afirmar transicao material de uma publicacao expirada.

Todos os atores qa-r06-* disponiveis sao Owner/platform; nao houve negativo
cross-tenant real. Gate seguinte permanece UI normal, escopo negado real e
expiracao material observada quando o prazo chegar. Sem proposta E2E por G4.

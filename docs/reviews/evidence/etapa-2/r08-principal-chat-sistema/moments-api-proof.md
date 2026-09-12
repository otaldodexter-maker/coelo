---
fonte: moments_api_smoke.py; gateway v10 e RPCs produtivos; autorizacao nominal C0 R08
status: leitura-aprovada-retirada-bloqueada
data: 2026-09-12
---

# Momentos — PNG privado por API e retirada403

apps/superadmin → Coelo (Principal) → Momentos → publicar/ler/retirar →
momentos.create/momentos.publish/momentos.view/momentos.remove.
**Prova API, sem aceite UI/E2E**.

`moments-api-manifest.json` registra **20 verificacoes/operacoes aprovadas e
1 falha**, processo exit1, sessao propria encerrada204. Nao sao 21 testes
distintos nem action_ids.

Prepare/PUT sem redirect/finalize/publicacao retornaram200 no gateway v10.
O feed autorizado retornou o ativo; read por asset_id e GET privado
recuperaram o PNG sintetico16×16/82bytes com SHA-256 identico. Uma nova
consulta manteve o estado. Anonimo401 e ativo aleatorio403 foram negados.
A URL temporaria retornou403 apos a espera do TTL (contrato120s).

**Falha reproduzida:** `withdraw_moment`, pelo mesmo autor QA e com
`p_expected_version:null` como o cliente produtivo, retornou403. Nenhuma
nova tentativa ou alteracao ACL foi feita. C0 recebeu o bloqueio para medir
o contrato em producao antes de autorizar a continuacao.

- Publicacao preservada: `bd9f2361-548f-44f8-a595-fddec3ff1396`.
- Ativo/master privado preservado: `6f8f9fc8-215a-4e07-8b7f-583d210215c7`.
- Trio QA medido e reconferido: instituicao d0c4/0001, unidade d0c4/0002,
  grupo368a5cea, IDs completos no manifest.
- Audiencia: school_staff. Nenhuma pessoa, senha, estrutura, papel, recurso
  Cloudflare ou configuracao foi criada/alterada.

O registro continua publicado no contexto sintetico; retirada e leitura
negada apos retirada **nao passaram/nao foram executadas**, respectivamente.
Nenhum DELETE ou cleanup fisico foi usado para contornar403.

## Hipotese estatica para revisao C0

`20260911130300_moments_feed_and_withdrawal_baseline.sql` cadastra
`moments.publications.remove`, mas nao inclui grant em
`institution_role_permissions`. `moments_actor` exige essa permissao e a
ponte do Owner usa institution_admin. Falta de grant e uma hipotese, ainda
nao uma conclusao sobre ACL em producao.

A versao nula e aceita explicitamente na RPC; nao deve ser alterada no
cliente como tentativa de contornar autorizacao. O pgTAP historico23 cobre
assinaturas/catalogo/corpos SQL; ele nao prova a retirada pelo papel real.

Nao ha segundo ator QA com escopo negado (qa-r06-* sao Owner/platform),
portanto cross-tenant real permanece nao executado. Proximo gate: C0 medir
causa do403, corrigir pelo fluxo serializado se cabivel e repetir somente a
retirada/reconsulta deste mesmo registro, preservando as provas anteriores.

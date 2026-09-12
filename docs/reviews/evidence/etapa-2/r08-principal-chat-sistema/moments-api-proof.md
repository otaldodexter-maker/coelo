---
fonte: moments_api_smoke.py; gateway v10 e RPCs produtivos; autorizacao nominal C0 R08
status: api-retirada-aprovada-ui-e2e-pendente
data: 2026-09-12
---

# Momentos — PNG privado, retirada e negativa ao consumidor por API

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

Na execucao inicial, o registro permaneceu publicado; retirada e leitura
negada apos retirada nao passaram/nao foram executadas, respectivamente.
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


## Continuacao autorizada apos lote 58

C0 aplicou `20260912140550` pelo fluxo serializado (lote 58) e autorizou
somente a retirada do mesmo registro. `moments-withdraw-retry-manifest.json`
registra, em 12/09/2026 15:51 UTC, can_withdraw verdadeiro, retirada HTTP 200
com withdrawn_at e nova consulta sem a publicacao. O defeito inicial de ACL
foi resolvido; nao houve novo upload nem alteracao de versao pelo cliente.

O roteiro dessa tentativa terminou com **8 checks aprovados e 1 falho**,
exit1, porque esperava 403 para o proprio autor e recebeu 200. Esse oraculo
estava errado: `authorize_moments_media_read` no contrato
`20260911130300_moments_feed_and_withdrawal_baseline.sql` preserva o caminho
do autor com capacidade de criacao; o caminho de consumidor exige publicacao
publicada e nao retirada. O script historico e o resultado falho foram
preservados para rastreabilidade; nao usar seu ultimo assert como criterio
canonico nem repetir a retirada para corrigir uma contagem.

C0 autorizou uma consulta somente leitura com o outro consumidor nominal
`qa-r06-realm`, no mesmo asset. `moments-withdraw-consumer-manifest.json`
registra login200, **read403**, denied=true e logout local204 em 15:54 UTC.
A sonda foi executada por Python inline com a mesma configuracao privada,
login normal e POST moments-media action=read/asset_id; somente esses campos
sanitizados foram gravados. Nao houve PUT, finalize, DELETE ou alteracao de
permissoes nessa consulta. O autor tambem encerrou sua sessao com logout204.

Estado atual: publicacao retirada, ausente no feed; outro consumidor negado;
master privado preservado. Essas etapas comprovam o contrato API de retirada,
sem promover UI/E2E e **sem comprovar cross-tenant**: as duas contas QA sao
Owner/platform. Nao somar os checks das tentativas como testes distintos.

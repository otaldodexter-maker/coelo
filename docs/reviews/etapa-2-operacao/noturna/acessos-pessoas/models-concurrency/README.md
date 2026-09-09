---
source: "AGENTS.md; 20260901170731_access_profile_models_crud_and_catalog.sql; 20260908182839_access_profile_models_aal1_phase_policy.sql"
status: "runtime-unexecuted; local-attempt-blocked-before-sql"
generated_at: "2026-09-09"
---

# Modelos: reautorizacao de receipts apos espera

Recorte: `apps/superadmin -> Acessos -> Modelos -> criar/editar/excluir/duplicar`
(`access-models.create`, `access-models.edit`, `access-models.duplicate`;
delete e comando backend sem ID separado neste inventario), somente Postgres
local descartavel. O pai conserva
ownership do pacote nominal `../models/`, commits e publicacao.

## Hipotese e limite

Os quatro writers autorizam antes de chamar
`app_private.access_profile_model_replay_internal`. O helper espera no advisory
lock da request, confere ator/hash/comando e devolve o receipt; esse ramo nao
chama `access_profile_model_audit_success`, que reautoriza a mutacao nova.
O teste procura retorno indevido do receipt quando a sessao ou a capability
perde validade durante a espera. Inspecao estatica nao comprova vulnerabilidade
runtime nem estado remoto.

O runner usa AAL1 conforme a politica MVP vigente. A invalidacao de sessao grava
`not_after = clock_timestamp() - interval '1 hour'`: o valor precede o inicio da
transacao aguardando, isolando o problema de snapshot/reautorizacao da discussao
Auth `now()` versus `clock_timestamp()`. Expiracao natural durante a espera,
revogacao de membership, requests novas, tenants e IDOR nao sao certificados
por esta prova. A cobertura existente de outros testes nao e somada aqui.

## Prova preparada

`Test-ModelReceiptConcurrency.ps1` possui 12 criterios:
quatro acoes multiplicadas por replay permitido, sessao invalidada e capability
inativada. Cada acao cria um receipt pela RPC publica real. Cada criterio observa
o caller bloqueado pelo holder real via `pg_blocking_pids`, efetua a alteracao
em outra conexao e libera o lock. O permitido precisa retornar replay; as
negativas precisam retornar `SAI_SESSION_INVALID` ou `SAI_PERMISSION_DENIED`,
sem dados. Modelo, receipt e quantidade de auditorias de sucesso do ator
precisam permanecer identicos.

O runner nao cria stack/container, nao aceita URL/credencial remota e exige
marker `.coelo-safe-replay` compativel com `coelo_safe_<29 hex>`. Fecha seus
processos psql e restaura o status da permission inclusive em falha. As linhas
sinteticas pertencem ao volume descartavel: o wrapper pai deve remove-lo,
inclusive se a prova falhar. Nenhuma tabela Auth/auditoria e apagada pelo teste.

Executar somente apos liberacao do slot serializado pelo pai/coordenador:

```powershell
& ./docs/reviews/etapa-2-operacao/noturna/acessos-pessoas/models-concurrency/Test-ModelReceiptConcurrency.ps1 `
  -ProjectRoot <diretorio-descartavel-com-marker> -ProjectId <coelo_safe_id>
```

Antes da execucao, conectar o runner ao lifecycle nominal ja utilizado pelo pai;
`replay-wrapper.patch` propoe um switch `RunModelReceiptConcurrency`, limitado
a AuthOnly/target 20260901200206, sem outros modos/adicoes e com exatamente
`ap_models_nominal_package_test.sql`. Esse TAP instala o pacote antes do runner;
seus 8 criterios sao pre-requisito de montagem, nao rerun do lote95 completo.
O patch deve ser aplicado apenas pelo dono do wrapper sob reserva coordenada.
nao relaxar defaults/constraints ou substituir helpers Auth para viabiliza-lo.
Registrar RED e GREEN separados; manter 12 IDs unicos, sem somar reruns. Se a
base historica devolver receipts nas negativas, o RED esperado e P4/F8. Se
falhar antes de observar os locks, registrar erro de runner/base, nao RED do
produto. Parse PowerShell e `-DescribeOnly` aprovados; SQL P0/F0/U12 nesta revisao.

## Tentativa local 19:07-19:10 BRT

Slot nominal liberado pelo pai apos reserva coordenada. A chamada real pelo
wrapper, via `Invoke-ReceiptProof.ps1`, bloqueou na primeira inspecao Docker
`ps -a`, antes de criar a stack, instalar a base ou executar TAP. Apos mais de
dois minutos sem resposta, foram encerrados somente os subprocessos docker
proprios PID31728 (inspecao inicial) e PID24448 (verificacao de cleanup). O
wrapper terminou com `cannot inspect Docker containers` e erro agregado de
cleanup incompleto. Isso e falha de infraestrutura, nao RED do produto.

`red-replay.txt` e `attempt-01.json` preservam a tentativa. Concorrencia12:
P0/F0/B0/S0/U12; instalacao TAP8: P0/F0/B0/S0/U8. Nenhuma correcao SQL foi
produzida sem RED. Conferencia final19:10 BRT: pasta temporaria inexistente,
mutex `Local\CoeloSafeSupabaseReplay` adquirivel/liberado e PIDs9500/31728/24448
ausentes. Nenhuma criacao de recurso Docker chegou a ser comandada, mas a
ausencia de containers/volumes/networks nao foi certificada porque Docker nao
respondeu. Nao houve retry; pai assumiu o diagnostico compartilhado.

## Proximo passo recuperavel

1. Pai confirma recuperacao Docker e novo slot antes de executar a prova na
   base nominal local, preservando o log da tentativa01.
2. Se RED demonstrar causa, adicionar reautorizacao nos quatro ramos de replay,
   usando dominio ja resolvido pelo writer e mesma acao (`create` na duplicacao).
   Preparar SQL forward-only com guarda de assinatura, ACL e hash do corpo.
   Sem mudar assinatura, politica Auth/MFA ou import/export adiados.
3. Executar GREEN focal e negativas adicionais pertinentes ao delta; conferir
   cleanup e devolver hashes ao pai para commit/publicacao e coordenador.

Referencia tecnica: funcoes VOLATILE estabelecem snapshots novos nas consultas
que executam; STABLE usa o snapshot da consulta chamadora. A prova runtime acima
decide o comportamento desta cadeia concreta, conforme a
[documentacao PostgreSQL](https://www.postgresql.org/docs/current/xfunc-volatility.html).

Gate de memoria: no-op. Nenhuma regra de produto nova aprovada; a exigencia de
reautorizacao server-side ja consta em AGENTS.md. Nenhum rastreador central ou
arquivo `../models/` foi alterado por este filho.

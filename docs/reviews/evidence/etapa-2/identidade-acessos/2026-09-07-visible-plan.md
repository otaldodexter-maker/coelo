---
title: "E2E 1 — passos por tela e camada"
source: "recorte do Coordenador E2E; trabalho local da branch codex/e2e-identidade-acessos"
status: "in-progress"
generated_at: "2026-09-07"
updated_at: "2026-09-08"
---

# Plano visível

## Checkpoint vigente — 2026-09-08

O histórico abaixo não substitui este corte; contagens de execuções diferentes
não são somadas. Nenhuma ação desta retomada foi promovida a verified-e2e.

Regressão funcional conjunta mais recente, HEAD e35c32f2: todos os arquivos
`*_test.dart` sob test/features/auth, access_profiles e platform_users,
excluindo `*golden*`: 303/303 PASS, exit0. Não inclui router/core guard/Conta,
goldens, runtime HTTP ou produção; não somar com as rodadas focais abaixo.
O candidato runtime foi ampliado em b6238e5a: 36 guards + 4 testes dos
manifestos = 40 PASS, um runtime SKIP forçado e analyzer limpo. Distingue
sessão inexistente, negação de escopo/domínio e membership realmente revogada.
Manifestos são JSON declarativos, não SQL executável; ainda aguardam
seed/porta/janela nominal de Eng1 para Users49 e Models50 separadas.
O cenário revogado retorna antes de montar UI; não comprova remoção visual
contínua após revogação. Não confundir JWT igual entre fases com prova de
execução histórica da fase inicial.

Perfis READ recebeu contrato técnico e oito testes de consumidor em memória:
8/8 PASS focal; diretório de testes data completo 81/81 PASS; analyzer focal
limpo. Prova argumentos/envelope/parsing, não autorização ou contagem SQL.
Sem mudança produtiva, HTTP de rede, SQL, Docker ou produção nesta preparação.

| Recorte original | Evidência local entregue | Primeiro gate aberto |
|---|---|---|
| Auth/login/recovery/sessão | R06/R07 e c0a199fd; regressões SDK/HTTP e integração central | Sessão real, revogação persistida, reload e negativos no pacote nominal |
| Conta self-read/self-edit | ce893afe: crosswalk proposto, review sem bloqueantes como desenho | Owner definir capacidade self, contatos/projeção e cadastro ausente; sem SQL/wiring; edição exige allowlist própria |
| Configurações | Persistência local real no browser e correções de load/save/ABA, integração central | Validação final sob sessão real e regressão de destino |
| Usuários internos READ | Users49: 48/48 pgTAP, prova Eng1 36964bbb; evidência reconciliada 586d6861 | Publicação nominal, fluxo real, visual e E2E; edição/convites não habilitados por READ |
| Modelos READ SQL | Models50: 38/38 TAP incluindo ACL10, prova Eng1 5ef2fc4e; 1d314a42 | Produção e cadeia real; contagem inclui testes repetidos 11 dentro de 17 |
| Perfis READ SQL | b11c3c3e executado Auth47 pelo Eng1: 3 PASS/5 FAIL decorrentes de ACL-before-contract; proposta técnica e contrato de consumidor | Contagem/READ reconciliados; decisão pendente somente de visibilidade/agregação do ator institution antes da corretiva nominal |
| Diretórios Perfis/Modelos | 24529b5b: revisão de autorização; 149/149 regressão histórica | Backend real/visual/reload |
| Detalhe e rotas | 6e06a9ed continuidade de recurso/delete; 8bd6bc8b quatro builders; 169/169 naquela rodada | Troca de path/save pendente e validação produtiva ainda não reivindicadas |
| Criação, contexto | 77e9594: dois builders e descarte do draft; 21/21 focal | Template em voo na rota e comando real não comprovados |
| Formulário, diálogos | 37abc763 e 471c99c8: impedir reload/callback após dispose; 45/45 regressão focal | Mesmo State, fluxo real e backend ainda não comprovados |
| Adapter Models READ | 865d0090 detalhe; bdd6fe6c paginação; ca543993 template; 87/87 data/rotas na última rodada | Cache auxiliar de writes e contrato catálogo domain-only separados; nenhuma ampliação de grant |
| Modelos create/update/duplicate/delete — envelopes | Reserva nominal após confronto único: dois REDs reais corrigidos; 169/169 data com 88 casos novos; analyzer/reviews sem bloqueios | Consumer local somente; prova UI/comando/persistência/reload e backend nominais abertos; sem alterar import/export |
| Mídia consumidora/Auth M03 | ce2d9bee: parecer de proveniência, sem helper implementado | Contrato server-side de origem operacional; AAL sozinho não resolve OTP/recovery ambíguo; mídia pertence E2E3 |
| P0 RLS/realm | Fatia três tabelas reservada ao Eng1 | Pacote nominal/replay/produção; não habilitar lote de tabelas por inferência |

Visual permanece aberto: Usuários teve quatro unidades golden falhando na
execução ampliada; Perfis teve três (diretório/tabela, hover, formulário).
Masters intocados; divergência não é autorização para rebaseline nem para
restaurar affordances bloqueadas. Detalhes nas evidências de cada recorte.

Próxima ordem: resultado Profiles ACL nominal → corretiva exclusivamente após
reserva e negativos; diagnósticos independentes de formulário/contratos →
review/commits → integração central → pacote de produção/execução real.
Sem ETA de entrega remota enquanto contrato/lease e replay condicionam o gate.
Trabalho local independente continua; uma decisão aberta não encerra toda a
vertical. Não houve SQL/Docker/produção executados por esta frente.

## Histórico dos recortes

Somente Superadmin. Remoto é produção e permanece read-only sem lease.
Um único writer: agente principal. Subagentes fazem inspeção e review sem
alterações: account_review (Auth/SDK), realm_audit (Usuários internos/Conta).
O escopo original inclui Auth, Conta, Usuários internos, Perfis, Modelos e
capacidades/realm/anti-escalada; um incremento não encerra a frente.
Não houve execução de BD,
Docker ou deploy por esta frente nesta retomada.

## Usuários internos — internal-users.list

| Passo | Camada / objeto | Estado e próximo gate |
|---|---|---|
| 1/6 Contrato/inventário | read/update/suspend internos | Recorte local listado; criação/convite não habilitados |
| 2/6 Backend/negativas | RPCs profiles/list/detail e lifecycle | Users49: Eng1 executou corretiva 27a0c3bb, fixtures originais 45+3 intactas, 48/48 PASS; prova 36964bbb, cleanup 02:55:41.7082440 UTC em 2026-09-08. Produção/E2E pendentes |
| 3/6 Cliente/estados | scope/main/app/router/diretório | Composição readonly, negativa e limpeza de tela implementadas |
| 4/6 Integração/reload | Sessão → RPC → UI | Cache/epoch ligados à sessão e dispose. Backend real aberto; mídia aguarda consumidor real da E2E3 |
| 5/6 Regressão/visual | testes Flutter | Diretório 13/13; composição inicial combinada 32/32; visual real ainda aberto |
| 6/6 Review/evidências/commit | commits locais | 151d9ddf, 022e1568, bbafe63e; reviews locais aprovados, sem promover E2E |

## Sessão — troca de contexto e revogação

| Passo | Camada / objeto | Estado e próximo gate |
|---|---|---|
| 1/6 Contrato/inventário | SuperadminSession; reserva R03 | Preservar autorização/MFA, alterar notificação e descarte de resultados antigos |
| 2/6 Backend/negativas | Nenhum BD nesta fatia | Servidor continua reautorizando; não há mudança de claims/capabilities |
| 3/6 Cliente/estados | authorize/_setSessionState | Alteração semântica notifica; reautorização equivalente permanece estável |
| 4/6 Integração/reload | Lista normal escuta sessão | ListenableBuilder + chave de revisão; teste prova nova carga e perda de permissão sem RPC |
| 5/6 Regressão/visual | sessão/scope/login/logout | R06: 42/42 (14 scope + 13 login + 3 logout + 12 sessão), analyzer e review. R07 SDK recovery em andamento |
| 6/6 Review/evidências/commit | account_review | Bootstrap concorrente inicial corrigido após RED; revisão final aprovada |

## Usuários internos — detalhe/edição

| Passo | Camada / objeto | Estado e próximo gate |
|---|---|---|
| 1/6 Contrato/inventário | detail/update/change_status | R04 concedida e implementada: detalhe somente leitura; edição produtiva continua 503 |
| 2/6 Backend/negativas | RPCs detail/update/change_status | Fixture e0efd98e inclui revoke/receipt/terminalidade; SQL não executado por esta frente |
| 3/6 Cliente/estados | detail/form | Detalhe descarta fallback stale, trata negação/retry e alterações de revisão. Formulário produtivo não habilitado |
| 4/6 Integração/reload | Deep link/lista/detalhe | 1e8f0966 prova navegação e troca de sessão via HTTP mock. Sessão/backend reais abertos |
| 5/6 Regressão/visual | detalhe 7; rota normal 8 | Cenários passam em 800/1440px com NAV-LOGOUT01 da E2E2 como dependency-only 00f794ec/c399e5ca; 15/15 com navegação, consolidado local 132/132. Browser real ainda aberto |
| 6/6 Review/evidências/commit | 4206f2bb, 10730253, 1e8f0966 | Implementação local, não verified-e2e; contagens corrigidas na evidência runtime |

## Perfis e Modelos — P0 RLS

| Passo | Camada / objeto | Estado e próximo gate |
|---|---|---|
| 1/6 Contrato/inventário | 3 tabelas app_private | catalog_versions, command_receipts e command_receipts_v2 nominais identificadas |
| 2/6 Backend/negativas | app_private.access_profile_* | E1-P0-RLS01 reservado exclusivamente ao Eng1, migration 20260908000500; não duplicar pacote |
| 3/6 Cliente/estados | Não incluído no pacote RLS | Não converter receipts people-based para UUID interno |
| 4/6 Integração/reload | Nenhum BD executado | Aguarda replay/preflight; remoto exige lease |
| 5/6 Regressão/visual | pgTAP proposto | ACL real + RLS independente + trigger/receipts positivos e rollback |
| 6/6 Review/evidências/commit | Inspeção read-only | Não há migration aplicada nem estado local-green |

## Auth — recovery e corridas de cleanup

R06 entregue em `7d831c17`: recovery observado durante bootstrap preservado,
sem autorizar o portal nem proteger ID inválido. R07 corrigiu getter/eventos
SDK, refresh e descarte próprio. Teste SDK/HTTP mock reproduziu getter
incorreto após callback tardio; revisão acrescentou RED de construção após
recovery já existente. Sincronização pelo stream existente fechou os REDs:
74/74 locais (9 SDK + 42 Auth + 23 pacote), sem interface pública adicional.
Corrida A rejeitado/B após remontagem foi reproduzida via SDK e router reais
com transporte simulado. `c0a199fd` serializa a operação completa de login;
154/154 na regressão local, analyzer/review aprovados. Coordenador integrou em
`63258e5e` e informou 61/61 no lote de destino Auth/Circulares. Diferença de ID
isolada continua sem autorizar preservar sessão desconhecida. Remoto/E2E abertos.

## Conta e Configurações

`67b36bab` + follow-up obrigatório `beba812a`: carga inicial/dispose e retry
após erro corrigidos com REDs. `9cd80347` serializa saves; `40d755b5` prova
SharedPreferences real após reload em browser local com sessão sintética.
R08 fecha falhas visíveis/retry na tela e três calls sites nominais: 29/29
focais, 148/148 na regressão conjunta, 8 cenários de erro com texto 200%.
Não confundir essas provas com autenticação real. Perfil produtivo continua 503 por
contrato: self-read/self-edit interno exige gateway nominal, sem reaproveitar
comando administrativo ou realm people. Avatar depende E2E3/R2; nenhuma capa
da Conta aprovada. Senha autenticada não se confunde com recovery/reset.

Os rastreadores oficiais permanecem sob autoria exclusiva do Coordenador.
Este plano registra andamento, não amplia o recorte nem substitui evidência.

Regressão conjunta em `009eaf4e`: 128/128 PASS (Auth/SDK/pacote 74,
repository 24, detalhe 7, rotas diretório 4/preview 2/detalhe 8 e Settings 9).
Esta execução não inclui os sete testes NAV da execução anterior; não somar
os denominadores como se fossem uma única execução. Continua sendo prova
local com HTTP simulado, não navegador/backend produtivos.

## Incremento R05 — cache por autorização

`SupabasePlatformUserRepository.clearSessionCache` limpa records/profiles e
avança um epoch. Leituras de perfis/lista/detalhe e comandos validam o epoch
antes de publicar respostas; comandos o capturam antes da leitura preparatória.
Resposta antiga, inclusive negação, não repovoa nem apaga o cache novo.
O scope liga a limpeza às notificações efetivas da sessão; refresh equivalente
não limpa. Testes: repository 24/24 + scope 12/12 = 36/36, analyzer de quatro
arquivos sem problemas, revisão independente favorável. Sem SQL executado.
Extensão separada de dispose: callback opcional executa clearSessionCache uma
única vez, sem notify/signOut. Finally descarta listeners mesmo se cleanup
falhar. Scope cria repository antes da sessão e injeta o callback. Testes
combinados 48/48 (sessão 12 + scope 12 + repository 24), analyzer sem problemas
e revisão aprovada. A prova inclui cache preenchido e resposta pendente no
descarte. Não prova que o app descarte automaticamente uma sessão injetada.

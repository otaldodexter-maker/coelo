---
source: "TRABALHO-ATUAL; coordenacao r18; branch work/etapa2-noturna-acessos-pessoas; handoffs e manifests locais"
status: "checkpoint publicado; vigilancia ativa ate corte; nenhuma certificacao nova"
generated_at: "2026-09-09"
---

# Acessos e Pessoas — entrega recuperavel

Recorte `apps/superadmin -> Acessos / Comunicacao -> Pessoas, Perfis, Modelos,
Convites, Usuarios internos, Seguranca infantil e Arquivos de perfil`.
[38 action_ids e primeiros gates restantes](residuals.md):31 ativos,6 adiados,
1 gate MFA. ADR0019/AAL1, import/export adiados, duplicacao R02 e confinamento
de Convites preservados. Somente Claude integra dev e escreve rastreadores.

Resultado local unico: **430P,4F,0S,120U**; U120=Safety108+concorrenciaModelos12.
[Contagem por conjunto](current-results.json) separa testes de PNGs, preparacao
7P e historico R02. Nenhum certificado FE/BE/E2E novo; historico FE2/38 refere-se
aos adiamentos. Ativos FE0/31,BE0/31,E2E0/31. Nao e medicao atual da suite ampla.

## Correcoes e provas

| Entrega | Commits | Evidencia e limite |
| --- | --- | --- |
| Pacote nominal Modelos preserva cursor remoto, grants adiados e atomicidade | cc5d73bc7,63623e31f,246c9e7e1 | [SQL](models/README.md):95P+rollback tardio6P locais; nenhuma aplicacao remota |
| Recibos Modelos conferem alvo, dominio, nova identidade e versao | 6b3777a57 | [HTTP](models/frontend-receipts.md):123P sinteticos |
| Formularios preservam gravacao confirmada quando navegacao falha | b285a6804,c8c8b0fba | [Formulario](models-form-receipt/handoff.md):17P funcionais; [golden1P](models-form-receipt/golden-reconciliation.md) resolve F1 herdado |
| Duplicacao confirmada nao repete copia apos falha de navegacao | 9d5ce7317 | [Duplicacao](models/duplicate-receipts.md):24P, incluindo9 rotasR02 |
| Safety so oferece comandos com suporte explicito qualificado | 3a96ca535,1d291711e | [Composicao](safety-composition/handoff.md):89P incluindo18 anteriores; adapters reais sem escrita |
| Safety detalhe recusa autorizacoes ausentes/malformadas | 8414ac9ab | [Adapter](safety-sql/adapter-shape.md):41P; adapter interno permanece inativo |
| Safety SQL read-only e perfil53 guardado, target193000 serializado | 7ce41f86b,b91f9206d,cb76f5968,fa3caddd2 | [SQL](safety-sql/handoff.md):108U; [preparacao7P](safety-sql/serialized-profile-proof.json),53arquivos exatos |
| Pessoas: alvo informativo24 corrigido48 mantendo circulo24 centralizado | 99a66fd2e | [Alvo](people-status-target/handoff.md):4P funcionais+200%1P; golden1P reexecutado por sourcechange, nao somado; analyze e contratos visuais PASS |

## Referencias visuais nominais

| Lote | Prova unica | Evidencia |
| --- | --- | --- |
| c8c8b0fba formularioPerfis/Modelos | 1P,3renders (incluido em formulario18) | [Causas](models-form-receipt/golden-reconciliation.md) |
| f60b2c2fe hoverPerfis | 1P,1render | [Hover](profile-hover/handoff.md) |
| c76a0eb23 formularioPessoas | 2P:golden1+alcancefooter1,2renders | [Formulario](people-form-visual/handoff.md) |
| 5ffce5441 diretorioPessoas | 1P,8renders;4cards atualizados depois por99a66fd2e | [Diretorio](people-directory-visual/handoff.md) |
| 7956dda48 diretorioPerfis | 1P,16renders | [Diretorio](profile-directory-visual/handoff.md) |
| 5a1ed044f Convites | 5P,9renders | [Convites](invites-visual/handoff.md) |
| 0dae87652 Usuarios internos | 4P,23renders | [Usuarios](internal-users-visual/handoff.md) |

Cada render foi inspecionado antes da substituicao, com causa integrada ou
mudanca intencional testada, paths e hashes. Nao houve rebaseline generico de
tema. Os14testes F do censo destas familias foram resolvidos; nao se somam
RED/update/reruns. O censo amplo190F em ecc8eae2b permanece historico separado.
O teste card_hover de Usuarios usa onView nulo: prova estado informativo sem
hover, nao hover acionavel. Essa lacuna permanece explicita.

## Bloqueios e proximo passo

1. Safety108: runner `safety-sql/Invoke-SafetyProof.ps1`, perfil
   `SafetyInternalReads53`, target20260909193000. Hunks locais concedidos;
   aguarda ORDEM LOCAL de sequencia por Claude. SlotModelos liberado desde r19.
   Isso e distinto de autorizacao de producao. Nenhum SQL Safety foi iniciado.
2. [ConcorrenciaModelos12U](models-concurrency/README.md): tentativa01 parou
   antes de SQL por Docker indisponivel. Infra recuperou e recursos do projeto
   anterior foram verificados0/0/0. Revisao automatica rejeitou a retomada por
   possivel risco de ciberseguranca; sem contorno, sem prova runtime ou correcao
   especulativa dessa hipotese.
3. Producao exige pacote nominal autorizado. Nenhuma mutacao remota, envio de
   convite, deploy ou ativacao de escrita. [Composicao das sete familias](composicao-produtiva.md)
   responde main/router/repository: repo real e rota normal nao qualificam
   contrato. Safety compoe adapter legado; interno v2 permanece inativo.
4. Pessoas/Perfis/Usuarios/Convites mantem gates de contrato, persona,
   visibilidade e persistencia da matriz. Arquivos e MFA preservados.

## Publicacao e recuperacao

Base original d784462c1. Todos os27 commits proprios ate d02bc4558 estao
integrados e publicados em origin/dev6aa352c6a. Essa base conjunta foi
materializada por fast-forward na worktree propria. Novos2816fbff1 e
c0e4fc47d estao publicados; [lista nominal](published-commits.json) conta
somente commits proprios, sem atribuir os imports de outras frentes ao grupo.
Os testes antigos nao foram repetidos; as novas quatro provas usam6aa.
Ancestralidade Git nao afirma verificacao integrada ou aceite de produto.

Checkpoints atuais, HEAD/upstream, recursos e deltas propostos estao no canal
compartilhado `comunicacao/acessos-pessoas.json`.34deltas:26frontend continuam
pending-verification e8backend blocked-environment. Nenhum rastreador central
foi escrito pelo executor. Tres filhos recolhidos, sem runners; concorrencia
Modelos permanece encerrada por bloqueio automatico.

Worktree R02D04 preservada375e0a62a, limpa. Stash vazio na ultima verificacao;
artefatos brutos ignorados e fixture53 regeneravel permanecem na worktree
noturna, sem remocao. Gate de memoria PASS anterior reutilizado: nenhuma
nova regra de produto, apenas correcao do contrato48 ja aprovado e evidencias.

Congelar novos lotes23:10; pre-entrega23:20; entrega final e parada23:30BRT.
Acompanhamento permanece ativo para resposta de sequencia/achado nominal.
Nao esperar ACK alem do corte. Claude assume o residual depois23:30.

Checkpoint21:18BRT: merge e648b57af incorpora todos os26commits atef6cab17f1 na arvore localdev805512a37. A consulta remota naquele instante ainda devolvia8b22e7edd (antesdessemerge), portanto nao se declarou a nova integracao publicada. Nossa branch estava publicada0/0. [Artefatos ignorados preservados](retained-artifacts.json):319arquivos,24340415bytes, cada path/SHA256; includesfixture53 e falhas brutas historicas, sem remover WIP.

Lote residual de rotas: [2816fbff1](router-residuals/handoff.md),2P preservando
negativa produtiva de Pessoas e negativa de editar Safety approved;
[c0e4fc47d](person-detail-visual/handoff.md),2P do detalhe em375/1440,
seis PNGs desktop reconciliados por d019c109a. people_routes3P ja integrado
por153b2dbfa foi reutilizado sem soma. Quatro arquivos do catalogo revisitados.
Artefatos preservados atuais:343 arquivos,25884065bytes, hashes no manifesto;
o checkpoint21:18 acima e historico, sucedido pela integracao publicada6aa.

Quarta pergunta coordenada r16: [alcance produtivo](alcance-produtivo.md)
registra entradas das sete familias. Detalhes de Pessoas, Perfis e Modelos
tem rota mas nenhum ponto de entrada UI identificado; cards de Perfis/Modelos
levam a editar. Isso acrescenta gate de alcance aos respectivos detalhes,
sem habilitar callbacks ou alterar decisoes. Todos os filhos recolhidos.

Prioridade Safety recebida r18 foi investigada e publicada: [reflow4P](safety-reflow/handoff.md)
8f3905819 confirma carga e alcance em375/1440texto100/200. [Transporte5P](safety-transport/handoff.md)
571ac3cf0 normalizaClientException no adapterlegado sem captura ampla. [Diretrizes2P4F](safety-accessibility/handoff.md)
f4dd600ff: rotulos passam; menu usuario44px e contrastes continuam falhos nas
duas composicoes. Sao causas compartilhadas reservadas a Claude. Token declarado
difere da amostragem de contraste; apurar render/estilo antes de mudar token global.
Sonda exata e logs publicados fora da suite regular, quatro falhas mantidas na
contagem atual. Loading e overflow da triagem d784 nao reproduzidos na base6aa.

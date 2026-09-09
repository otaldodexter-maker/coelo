---
source: "TRABALHO-ATUAL; coordenacao r9; branch work/etapa2-noturna-acessos-pessoas; manifests locais"
status: "checkpoint publicado; execucao ativa ate gates/corte; sem certificacao nova"
generated_at: "2026-09-09"
---

# Acessos e Pessoas — entrega recuperavel

Recorte: `apps/superadmin -> Acessos / Comunicacao -> Pessoas, Perfis,
Modelos, Convites, Usuarios internos, Seguranca infantil, Arquivos de perfil`.
Os 38 action_ids e seus primeiros gates restantes estao em [residuals.md](residuals.md).
Sao31 ativos,6 adiados e1 gate MFA. ADR0019/AAL1 permanece vigente.

## Correcao e evidencia

| Entrega | Commits principais | Evidencia e limite |
| --- | --- | --- |
| Pacote nominal Modelos preserva assinatura cursor, grants adiados e atomicidade | cc5d73bc7,63623e31f,246c9e7e1 | [Models](models/README.md):95P SQL local +6P rollback tardio; nenhuma aplicacao remota |
| Recibos Modelos validam alvo, dominio, identidade nova e versao | 6b3777a57 | [HTTP](models/frontend-receipts.md):123P; transporte sintetico |
| Formularios mantem gravacao confirmada quando navegacao falha | b285a6804 | [Formulario](models-form-receipt/handoff.md):18P; antigo F1 reconciliado conforme [causas aprovadas](models-form-receipt/golden-reconciliation.md), tres renders inspecionados |
| Duplicacao mantem copia confirmada sem novo comando | 9d5ce7317 | [Duplicacao](models/duplicate-receipts.md):24P, incluindo9 rotas R02; captura375 inspecionada |
| Safety recomposto com alvos acessiveis e escrita explicitamente qualificada | 3a96ca535,1d291711e | [Composicao](safety-composition/handoff.md):89P, incluindo18 anteriores; golden revisado; adapters reais sem escrita |
| Safety candidato read-only exige envelope compativel | 7ce41f86b | [SQL Safety](safety-sql/handoff.md):43+63+2 casos ainda nao executados; [adapter41P atual](safety-sql/adapter-shape.md), inativo |
| Perfis de replay reservados e carimbo Safety alinhado ao integrador | b91f9206d,cb76f5968,fa3caddd2 | [Perfil atual](safety-sql/serialized-profile-proof.json):7P preparacao,53 arquivos exatos, sem SQL; target193000 conforme ecc8eae2b |

Resultado atual unico: **401P,0F,0S,120U**. U120=Safety108+Modelos concorrencia12.
Preparacao7P separada de testes do produto. Reruns e evidencias R02 nao somam
cobertura. Nenhum resultado local promove FE/BE/E2E integralmente. Historico
FE2/38 corresponde aos adiamentos; ativos FE0/31,BE0/31,E2E0/31.

## Bloqueios e retomada

1. Safety108 tem runner exato em `safety-sql/Invoke-SafetyProof.ps1` e perfil
   `SafetyInternalReads53`. Aguarda sequencia local do coordenador, respeitando
   prioridade Forms I008. O renome193000 e conteudo identico ao integrado.
2. [Ensaio concorrente de Modelos](models-concurrency/README.md): tentativa01
   parou antes de SQL por Docker indisponivel. Docker recuperou; recursos do
   projeto anterior verificados0/0/0. Retomada do filho rejeitada pela revisao
   automatica por possivel risco de ciberseguranca.12U preservados, sem contorno,
   sem vulnerabilidade runtime afirmada ou correcao especulativa.
3. Form golden1F foi resolvido pela regra nominal do coordenador: sete causas integradas, tres renders inspecionados e paths/hashes registrados. Outros goldens nao foram reexecutados.
4. Producao exige pacote nominal autorizado. Modelos necessita fundacao interna;
   Safety depende do envelope e contrato interno qualificado. Nenhuma mutacao
   remota, envio de convite, deploy ou ativacao de escrita ocorreu.
5. Pessoas/Perfis/Usuarios/Convites mantem gates nominais de contrato, persona,
   visibilidade e persistencia descritos por action_id na matriz. Arquivos e MFA
   permanecem conforme politica; ausencia do Owner nao muda aprovacao.

## Integracao e encerramento

Base do grupo d784462c1; Claude r9 registra merge69ce62c43 ate b285a6804.
Sucessores publicados:9d5ce7317,cb76f5968,f85c8ddad,fa3caddd2. Somente Claude
integra dev e escreve inventario/rastreadores. Dez deltas frontend enviados em
`comunicacao/acessos-pessoas.json`, todos pending-verification.

Checkpoint Git apos fa3caddd2: HEAD/upstream0/0, worktree limpa, stash vazio.
Os dois filhos foram recolhidos: Safety completo; Modelos encerrado por revisao
automatica. Nenhum runner ou servidor proprio ativo. Logs brutos ignorados e
fixture53 regeneravel ficam preservados na worktree; evidencias publicadas em
UTF8 e sem credenciais. Nenhuma worktree alheia foi removida ou alterada.

Gate de memoria executado com Root explicito:PASS. Nenhuma regra nova de produto;
as projecoes historicas de MFA foram apontadas para reconciliacao central.
Congelamento23:10, pre-entrega23:20, entrega final e parada23:30 BRT. Este indice
e um checkpoint e sera atualizado se a sequencia SQL ou a integracao avancar.

## Sucessores visuais e composicao (checkpoint20:58BRT)

Composicao produtiva das sete familias respondida em [composicao-produtiva.md](composicao-produtiva.md), commit f4ac658fb; nao equivale a qualificacao do transporte.

| Lote publicado | Prova focal | Evidencia |
| --- | --- | --- |
| c8c8b0fba formularioPerfis/Modelos | 1P,3renders,substitui F1 antigo | models-form-receipt/golden-reconciliation.md |
| f60b2c2fe hoverPerfis | 1P,1render | profile-hover/handoff.md |
| c76a0eb23 formularioPessoas | 2P,2renders e alcancefooter | people-form-visual/handoff.md |
| 5ffce5441 diretorioPessoas | 1P,8renders | people-directory-visual/handoff.md |
| 7956dda48 diretorioPerfis | 1P,16renders | profile-directory-visual/handoff.md |

Todos aplicam regra nominal do coordenador: causas integradas especificas, inspecao individual antesupdate, caminhos/hashes. Nenhuma promocao. HEAD7956dda48 publicado0/0; WIP identificado people-status-target (correcao funcional de alvo48 pelo filho), pendente de revisao/publicacao. Comunicacao r35 envia22deltas ao escritor central; ultimo recibo observado continua nossa r15 na coordenacao r12. Publicado nao significa integrado.

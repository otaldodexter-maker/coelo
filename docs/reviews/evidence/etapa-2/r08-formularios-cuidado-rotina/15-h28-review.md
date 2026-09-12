---
source: "C0 review nominal FE H28; ponta G2 425aceaf8 confirmada pelo autor; código/testes cliente e candidato SQL"
status: "review encerrado favoravelmente; 19PASS integrados por C0 com log bruto conferido"
generated_at: "2026-09-12"
---

# Revisão independente H28: filtros de Pessoas

SHA fixo revisado: `425aceaf8`, branch G2 `work/etapa2-r08-acessos-pessoas`. Não foi revisado `71e45d3ad` isoladamente. Recorte nominal C0: `apps/superadmin -> Pessoas -> diretório -> filtros atividade/UF/município/bairro -> H28`. G3 não editou arquivos G2, não executou Flutter/SQL e não aplicou candidato remoto.

## Achados concretos

1. **Bairro compatível é descartado ao ampliar a seleção de UFs.** Em `20260912143000_people_directory_context_filters_v1.sql`, a opção `neighborhoods` retorna id/label/municipality_id, sem state_code. O parser admite stateCode opcional, e `PersonDirectoryViewModel.setStates` exige `value.contains(option.stateCode)` para reter o bairro. Sequência sintética: selecionarSP, municípioSãoPaulo, bairroCentro; acrescentarRJ mantendoSP. A cidade continua compatível, mas o bairro cai porque stateCode énull. O teste atual cobre substituirSP porRJ, não preservarSP numa seleção ampliada. Enviado a G2 para alinhar envelope/retenção e reproduzir antes do fix.

2. **Atividade com vários vínculos depende da ordem das opções.** SQL gera uma opção por activity_definition + link, portanto o mesmo activity_id pode aparecer com group_id diferentes. `setGroups`, `setUnits` e `setInstitutions` usam firstOrNull porid antes de conferir contexto. Se X pertence a gA e gB e a primeira opção é gA, removergA mantendo gB pode apagar X mesmo que a segunda opção seja compatível. A retenção precisa considerar existência de qualquer opção compatível; a UI também deve evitar apresentar duas opções indistinguíveis do mesmoid quando selecionar várias turmas. Teste atual usa IDs únicos e não cobre múltiplos vínculos do mesmoid. Enviado a G2, sem patch em arquivo alheio.

Esses achados são incompatibilidades de filtro/UX, não demonstrações de vazamento ou bypass de autorização. O candidato SQL aplica os filtros na mesma linha de contexto; G5 permanece responsável pela revisão SQL/escopo e G2 pelas provas funcionais.

## Caminhos conferidos sem novo achado

- ViewModel conserva os quatro conjuntos no query, setters reiniciam paginação e `_copy` os encaminha. Repository os envia nos nomes `p_activity_ids`, `p_state_codes`, `p_municipality_ids`, `p_neighborhood_ids` quando `contextFiltersAvailable=true`.
- Composição atual deixa a flagfalse até serialização C0. Isso é gate de implantação, não prova de filtro produtivo: omitir parâmetros não equivale a filtrar resultados. `fetchFilterOptions` já aceita campos novos; C0 precisa coordenar disponibilização e flag para não oferecer opções sem aplicação efetiva.
- Filtro de unidade/turma depende dos pais; localidade usa textos canônicos de endereço e não UUIDs municipais fictícios. Não alterar esse contrato por inferência de review.
- `_load` captura requestVersion antes de Future.wait(page,options) e só publica ambos quando a versão continua atual. Nova busca incrementa antes do debounce; substituição de query cancela timer; dispose incrementa versão. Erro/negação obsoletos não limpam a consulta nova. Não encontrei caminho em que resultado antigo volte a atribuir `_query`.
- `PersonDirectoryPage.didUpdateWidget` descarta ViewModel anterior e limpa busca quando muda repository. A instância nova começa sem filtros. Testes existentes lidos: `new search discards old result/denial during debounce`, `pending response cannot mutate a disposed directory`, `revocation clears loaded people, filters and sensitive query state`, `clears tenant content when repository is replaced by unauthorized`. G3 não os reexecutou nem lhes atribui resultado novo.

## Limites e próximo passo

Solicitar RED→GREEN focal dos dois casos a G2 no slot C0; revisar SHA de followup antes de recomendar integração. Fixture funcional A/B e pgTAP estão com G2/G7/G5, não foram duplicados. Não promover H28 nem métricas por leitura de código. A revisão não altera memória canônica: ainda se trata de correções propostas de um contrato existente.

## Followup c83fd9ca1

G2 enviou `c83fd9ca1`, efetivamente lido por diff contra425aceaf8. `setGroups` agora usa any e atende esse caminho. `setUnits` e `setInstitutions` ainda usam firstOrNull, e neighborhoods ainda não fornece state_code: os achados permanecem parcialmente abertos. Exemplo preciso para setInstitutions: atividadeX pertence à instituiçãoI e tem linksuA/gA e uB/gB; usuário mantémuB/gB/X e acrescenta instituiçãoJ sem removerI. A primeira opçãoX=uA é rejeitada pelo conjunto de unidades, apesar do linkuB compatível. Não pressupõe atividade pertencendo a dois tenants.

Revisão enviada a G2/C0, sem promover fechamento por corrigir apenas um setter. Provas Flutter/pgTAP em execução por seus donos não foram duplicadas nem antecipadas por G3.

## Followup 5d4ff2bbf

Lido diff completo contra c83fd9ca1. Retenção usa any nos três setters, SQL de bairros agora emite state_code e atividades visíveis são deduplicadas porid após o filtro de grupos. Os dois achados iniciais estão atendidos em código; a execução dos cenários novos ainda foi declarada pendente pelo autor.

A mesma classe de duplicação exige conciliação nas opções de localidade: SQL distingue objetos por city/state e district/city/state, mas os IDs enviados são city e district. Dois municípios selecionados com bairroCentro produzem dois objetos distintos com idCentro. O seletor marca ambos pelo queryid e desmarcar só um mantém o outro, restaurando ambos no reload. Enviado a G2 deduplicar as opções visíveis porid depois de limitar o contexto, conferirUF também em visibleNeighborhoods para cidades homônimas, e usar any em setMunicipalities para reter bairro com vínculo alternativo compatível. Não alterar os IDs textuais nem tratar isso como incidente de autorização.

## Followup 8ce53fcf6

Lido diff: cidades/bairros visíveis agora deduplicados porid, bairros limitados também porUF, setMunicipalities usa any. Resta alinhar o predicado deste último à UF atual: sem verificar stateCodes, opção de bairro deUFestranha/cidadehomônima pode manter queryid invisível. Exemplo sintético enviado: SP selecionado, trocar de cidadeA para cidadeB/SP; não reter bairroX apenas porque existe X/cidadeB/RJ.

Critério focal de fechamento enviado ao autor/C0:4cenários (atividade alternativa nos três setters; UF aditiva preservando bairro; opções únicas/desmarcação; retenção sem UFestranha) e análise/execução no slot. Nenhum teste novo apareceu nos diffs de followup lidos até este SHA; aprovação continua condicional à última correção e à prova, sem novos itens fora desse conjunto.

## Followup 36cfefa81

Guard deUF em setMunicipalities efetivamente lido e adequado. Todos os achados de código desta revisão estão atendidos na ponta36cfefa81; resta a execução e revisão dos quatro cenários. O autor foi orientado a escrever os testes enquanto espera slot, pois a preparação não ocupa Flutter. Parecer estrutural favorável ao diff, condicionado às provas; não altera o estado produtivo nem libera a flag antes do gate C0.

## Fechamento df0a281cb

Os quatro testes publicados foram lidos integralmente: UF adicional preserva bairro compatível; atividade com vínculo alternativo sobrevive à ampliação de instituições; atividade duplicada aparece uma vez e permite deseleção; mudança de município não retém bairro por opção de outra UF. Os fixtures contêm vínculos duplicados reais. Os achados de código desta revisão estão atendidos; parecer favorável à integração do cliente sob o gate de implantação de C0.

G2 registrou em `968b0173d` a execução focal repository + ViewModel com 19 aprovados e 0 falhos. Em mensagem posterior, confirmou exit code 0 e saída `00:01 +19: All tests passed!`, mas informou que não preservou log bruto. Portanto, este documento distingue resultado informado pelo executor de evidência bruta auditável: G3 leu os testes e o registro commitado, não reexecutou a suíte e não inventou um log retroativo.

A retenção alternativa tem assert específico em setInstitutions; setUnits/setGroups foram inspecionados em código. A deduplicação testada é de atividade; cidades/bairros foram inspecionados sem cenário isolado novo. Esses limites permanecem explícitos, sem ampliar cobertura ou somar os 19 testes às execuções G3. SQL/fixtures A/B e ativação de `contextFiltersAvailable` continuam com C0/G5; esta revisão não certifica H28 produtivo nem E2E.

### Prova integrada C0

C0 publicou `0b9eac1e4` com `ciclo210-people.jsonl`, `ciclo210-people-result.json` e `ciclo210-people-exit.txt` em sua pasta de evidências. G3 leu o log bruto completo e o exit: 19 aprovados, 0 falhos, 0 ignorados, done success e native exit 0, base `3c7ebbd5dcef2643677fc453b742c0fca02fe451`. Os quatro casos acima constam como success. A prova integrada resolve a ausência de log auditável da execução anterior G2, sem fabricar histórico ou duplicar execução G3. Parecer final favorável, mantendo os limites de cobertura e ativação já descritos.

C0 comunicou aplicação do lote59 às14:31 e publicou `477e6c8df`. G3 conferiu o diff que habilita `contextFiltersAvailable:true` e `lote59-apply.log` com nativeExitCode0. O gate de ativação antes pendente foi executado pelo integrador; não foi reaplicado por G3 e não representa prova UI remota nesta revisão.

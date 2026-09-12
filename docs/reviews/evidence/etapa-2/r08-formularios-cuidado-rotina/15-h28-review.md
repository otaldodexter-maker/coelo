---
source: "C0 review nominal FE H28; ponta G2 425aceaf8 confirmada pelo autor; código/testes cliente e candidato SQL"
status: "review readonly com dois achados enviados a G2; aguarda prova e followup"
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

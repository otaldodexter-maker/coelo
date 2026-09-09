---
source: "Spec Locais 2026-09-02; ADENDO-LOCAIS; reserva D00 r15"
status: "local-candidate; reviewed-statically; sql-not-executed"
generated_at: "2026-09-09"
---

# Motor datado — candidato para revisão

Migration `20260909165000_superadmin_location_reservations_v2.sql` e TAP
`superadmin_location_reservations_v2_test.sql` preservados em commit separado.
Não integram LocationCatalogV2 nem recebem autorização de replay/publicação
pela existência deste arquivo. Top-level parser aceitou42 statements SQL;
TAP29 assertions preparado, **0 executado**. Sem prova procedural/DDL no banco.

Regras aprovadas implementadas no candidato:

- Escopo independente de instituição/unidade, catálogo canônico e vínculo
  validado de Turma/Atividade; Event/Form não ganham consumidor inventado.
- Reserva única/semanal finita, intervalos positivos UTC e recorrência em
  timezone nomeada. A janela semanal de disponibilidade permanece separada.
- Política explícita block/warn por proprietário; nenhuma política padrão.
- Sobreposição meia-aberta, lock do Local entre verificação e persistência;
  lock compartilhado do proprietário contra troca exclusiva da política.
- Override exige capability própria e justificativa; registra evento próprio
  com overload14 e justificativa no after_json bruto. A projeção genérica
  atual de auditoria mascara campos fora de sua allowlist; não foi ampliada.
- Cancelamento integral versionado, recibos por ator/request/operation/hash,
  resultado imutável e reautorização atual mesmo em replay. Sem garantia de
  devolver recibo após arquivar/revogar consumidor.
- Listagem paginada por consumidor, cursor validado no escopo real, sem IDs
  de outros consumidores no diagnóstico de conflito.
- Cinco tabelas com RLS forçada e acesso direto revogado; six RPCs públicas
  autenticadas exigem contexto/capability/ownership no servidor. Falhas do
  dispatcher revertem subtransação antes de responder e auditar negativa.

Limites defensivos locais:1000 ocorrências,3660 dias de horizonte e31 dias por
intervalo. Não constituem novas regras comerciais aprovadas. Horário derivado
ambíguo/inexistente por DST é rejeitado; escolha de offset e efeito restritivo
da disponibilidade semanal continuam sem decisão de produto. Não atualizar
knowledge ou decisão global para transformar esses limites em regra aprovada.

Dependências adicionais: LOC01–04, overload14 canônico de auditoria e
provisionamento nominal Owner-only de locations.reservations.read/manage/override.
Não cria/granta essas capabilities por conta própria. O perfil catálogo53+2+2
não inclui sozinho o overload14; uma futura cadeia do motor precisa incorporar
dependência canônica completa, sem copiar função audit ad hoc.

Faltam fixture de integração do dispatcher, testes de permitido/negado,
tenant A/B, revogação, recibo, auditoria, concorrência real e composição com
save atômico de Turmas/Atividades. O painel/gateway Flutter em preparo não
substitui esses gates. FE/BE/E2E de locations.schedule continuam abertos.

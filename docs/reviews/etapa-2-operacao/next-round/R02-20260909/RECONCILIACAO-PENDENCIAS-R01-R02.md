---
title: "Reconciliação das pendências R01/R02 após o fechamento"
source: "Owner; FECHAMENTO-OWNER.md; ENTREGA-L00-PARA-D00.md; CONSOLIDADO-CLAUDE.md; handoffs finais D01-D04/L01-L03; R01-fechamento-20260909.md; inventario-etapa-2.json"
status: "reconciled-documentation; product-pending; rounds-remain-closed"
generated_at: "2026-09-09"
timezone: "America/Sao_Paulo"
---

# Reconciliação das pendências das três skills

O Owner solicitou corrigir integralmente a documentação de pendências após a
conferência encontrar textos superados. Base documental examinada: `09aa3861e`;
base funcional final: `d019c109a`. Escopo: as 230 ações conhecidas e os resíduos
registrados da R01/R02, incluindo entregas Claude. Esta manutenção não reabre
executores, não implementa telas e não faz nova certificação de produto.

As fontes canônicas atualizadas são o [inventário](../../../inventario-etapa-2.json)
e os rastreadores [Front-end](../../../coelo-flutter-pendencias.md),
[Back-end](../../../coelo-supabase-pendencias.md) e
[Front-end + Back-end](../../../coelo-flutter-integrado-supabase-pendencias.md).
Cada matriz agora é conferida campo a campo com o inventário, incluindo trabalho
feito, próximo passo de cada camada e evidência; somente conferir IDs, estados
e contagens não detectava as contradições encontradas.

## Correções de estado

- Painel vigente substituído: 230 ações/39 famílias, FE7/230, BE0/223,
  E2E0/198. Os painéis de 219 ações e as ordens antigas foram preservados em
  bloco explicitamente histórico. A R01 e a R02 continuam encerradas.
- Auth: qualificação local e CLI/ledger entregues; removida a pendência atual
  que ainda descrevia apenas o rascunho I021. Permanecem produção nominal,
  credenciais, personas e SMTP. O I021 de mídia Forms é outro pacote e continua
  aberto. Atomicidade CLI é por arquivo, não entre as duas migrations.
- Atividades: 46 TAP + 3 concorrências aprovados substituem os estados
  intermediários de falha/bloqueio. Integração do consumidor e atomicidade com
  reserva continuam abertas.
- Locais: catálogo165 e reservas49+2 locais aprovados; painel integrado com
  16 casos no lote25. Modal de cópia já integrado é diferente da guarda de
  segunda ativação ainda retida. Pacotes D02 `cd03b9e30`, `1345af29f` e
  `42ad0467` continuam entregues na branch, sem integração final.
- CHILD: diretório composto, 45 TAP + 3 concorrências + 4 HTTP e compositor6
  locais; cache PostgREST U1 e os quatro comandos próprios permanecem abertos.
- Instituições/Turmas: corrigidas as descrições de descarte silencioso de
  campos e contagem agregada que já tinham sucessores integrados. A recusa de
  campos fora da spec042 não amplia o writer nem conclui o CRUD.
- Pessoas/Convites/Modelos: texto distingue correções de formulário/recibos,
  confinamento de autorização e filtro cliente integrados dos gates reais de
  escrita, SQL nominal, SMTP e aceites completos ainda pendentes. AAL1 vigente
  não foi substituído por exigência geral de AAL2 nos Convites.
- Safety: cadeia e sucessor autoral preservados; golden F1, SQL U43 e adapter
  não ativado identificados por SHA. Não descreve a cadeia como inexistente.
- Claude: FE autoral L01 6/23, L02 4/13, L03 3/3 e testes não nulos
  preservados sem promoção dos certificados integrados. Chat Principal e
  administrativo continuam superfícies distintas dentro dos IDs compartilhados.
  Para L02, os quatro aceites FE autorais são editar/recibos/revogar Chat e
  agendar Avisos; corrigir conflito em publicar/arquivar não fecha essas ações.
- Acontece: feed misto já injetado em dev; abrir/responder Circular ainda
  indisponível. Perfil/Para Você completos, Chat Principal e feed Momentos
  permanecem entregas nas branches, com integração parcial/retida explicitada.
- Contratos L01/L02 já escritos não são descritos como ausentes globalmente.
  Harness autoral com relaxamentos não é qualificação nominal de produção.
- Forms: provas SQL I005172/I01382 e schema313/writer128 integrados preservados;
  texto antigo de integração pendente desses mesmos lotes corrigido. Claim,
  consumo de arquivo, mídia, expiração e cleanup completos continuam abertos.

O [delta nominal](handoffs/notes/D00-tracker-reconciliation-delta.json)
preserva os valores anteriores e posteriores de cada ação alterada. Datas de
provas/certificados não foram renovadas por mera edição documental.

## Passagem da fila retida R01

Os 13 grupos do [manifesto R01](../../reports/R01-fechamento-integracao.json)
continuam rastreáveis. O SHA publicado `2b4f189a17146911cbe7d91ad653c67997db3610`
foi confirmado como ancestral da dev examinada. Isso prova preservação da base,
não integração de todos os candidatos das branches.

| Grupo retido na R01 | Situação ao reconciliar |
| --- | --- |
| C01 / 5be8a92a, 27f7bbab | Qualificação local superada pela entrega Auth R02; produção ainda pendente. Não integrar WIP antigo automaticamente. |
| C02 / f002fb2a | Resposta civil/texto preservada; sem novo recibo de integração/aceite final. |
| C02 / cadeia Safety e2224800…720f739e | Retenção continuada na R02 por golden; candidato D04 e SQL43 identificados. |
| C03 / 932003b1 | Publicação de Cardápios com requestId/recibo divergente continua retida. |
| C03 / 8b4dfb6a, 89949f30 | Auditoria: 145 casos sem execução nominal registrada; não herda os testes Clock. |
| C03 / b049b163 | Agenda WIP, composição e aprovação visual ainda pendentes. |
| C03 / fd791a81, b5696cad, 69b534c0, 892e4316 | Adapters/candidatos preservados para revisão seletiva. Avanço R02 de Atividades não prova equivalência de todo o grupo. |
| C04 / 348f81ab | Avatar: sem recibo de solução do mounted após await; candidato preservado. |
| C04 / 9369f677, 41dea4e9 | Integrações seletivas de Locais avançaram; não há aceite de todos os hunks/dependências destes commits inteiros. |
| C04 / 27236a5a, ae7e8f5f, 15516da9 | Gates nominais específicos catálogo/clock/reservas avançaram na R02; demais contratos Instituições/Unidades continuam próprios e sem certificação remota. |
| C05 / 3419a89e, 2802d7fc, edded9bf, 5f10c0b7, 478a805e | Composição Agora/Chat e bordas visuais seguem entrega seletiva; consultar sucessores L01/L02 antes de retomar. |
| C05 / 5f0e7e29, 71f745d5, 6228296a, 6c672709, c5916aa6, d4e13852 | Contratos/SQL candidatos, com sucessores L01/L02; não aplicados nominalmente em produção. |
| C07 / b9be43f4 | Testes e evidências preservados; reverificação conjunta R01 0/1 não foi convertida em aceite pelo build/lote R02. |

Care/Medicação, Planos, Suporte, Catálogo e demais ações fora da seleção R02
mantêm critérios próprios. Histórico não vira resultado atual sem nova prova;
falta de cherry-pick literal não prova ausência de código integrado por hunks.
C06 confirmou I015 na r53 e encerrou a vigília: isso não é pendência operacional.

## Evidências da reconciliação

Fontes: [fechamento R01](../../reports/R01-fechamento-20260909.md),
[fechamento R02](FECHAMENTO-OWNER.md), [entrega L00](ENTREGA-L00-PARA-D00.md),
[consolidado Claude](CONSOLIDADO-CLAUDE.md),
[recibos finais dos oito papéis](handoffs/notes/D00-final-role-receipts.json)
e os manifests por lote referidos no inventário/fechamento.

Validação: `node docs/reviews/validate-trackers.cjs` e
`node --test docs/reviews/validate-trackers.test.cjs`. O teste de regressão
introduz divergências de texto mantendo estados e contagens iguais e exige
rejeição. Arquivos históricos originais continuam verificados pelo validador.

Resultado: 230 ações consistentes nos três rastreadores, 11 testes PASS/0 FAIL,
links do painel vigente e deste recibo válidos. IDs, escopos, estados,
certificados e datas das evidências preservados nas 230 ações. Corrigidas
descrições de 84 ações, com delta nominal antes/depois. Nenhum teste de app
foi repetido para esta manutenção documental.

Memória de conhecimento: skill coelo-knowledge consultada; no-op de projeção.
Esta correção muda estado operacional e referências, sem regra nova aprovada
de produto. A fonte da revisão e a projeção existente foram consultadas;
nenhum artigo artificial de atividade foi criado.
Gate executado: 54 artigos válidos; harness de conhecimento 12 PASS/0 FAIL,
1 SKIP porque o host não permite criar symlink. Erros iniciais de invocação
dos wrappers foram corrigidos antes desses resultados, sem alteração da skill.

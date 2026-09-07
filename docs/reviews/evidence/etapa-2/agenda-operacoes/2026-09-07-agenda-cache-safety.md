---
title: "Agenda — segurança do cache assíncrono"
source: "decisions/0029-superadmin-agenda-backend-authorization.md; specs/050-superadmin-agenda-backend.md; testes locais e review independente E2E5"
status: "local-green; integração e visual pendentes"
generated_at: "2026-09-07"
---

# Recorte e plano por tela

Superadmin somente. Objetivo: impedir aplicação tardia de respostas obsoletas,
exposição de cache após negação e notificações após disposal no repository
produtivo de Agenda. Fora: schema, autorização server-side, recorrência,
reservas, mídia, paginação completa, entrega remota e alteração visual.
Um único writer na branch `codex/e2e-agenda-operacoes`; review read-only por
`activities_contract_read`. Base do pacote: `d8281432c654f01b145d48abf8347a7ce12a935a`.

| Tela / ação | Marco atual | Camada e BD | Resultado / próximo gate |
| --- | --- | --- | --- |
| Agenda / Calendário e Lista | 5/6 regressão → 6/6 review do pacote de cache | Cliente; RPC `public.superadmin_agenda_list` simulada | Gerações por canal; estados visuais e leitura real pendentes |
| Agenda / detalhe e lifecycle | 5/6 → 6/6 do pacote | Cliente; `public.superadmin_agenda_get`, `superadmin_agenda_save`, `superadmin_agenda_command` simuladas | Invalidação após comando validado, negação ou item não revelável; persistência real pendente |
| Agenda / Solicitações e Aprovações | 5/6 → 6/6 do pacote | Cliente; `public.superadmin_agenda_requests` simulada | Commit atômico das duas coleções; decisões/reload reais pendentes |
| Agenda / contexto e capacidades | 5/6 → 6/6 do pacote | Cliente; `public.superadmin_agenda_contexts` simulada | Limpeza após negação; autorização backend não exercitada |

Os seis marcos por tela são contrato/inventário, backend/negativas,
cliente/estados, integração/persistência/reload, regressão/visual e
review/evidências/commit. Avançar o pacote de cache aos marcos 5–6 não fecha
os marcos restantes da tela. Nenhum BD local ou de produção foi executado;
nenhum Docker, migration, R2 ou Worker foi operado neste pacote.

## Mudanças verificadas

- Respostas de uma consulta substituída não sobrescrevem o período mais recente.
- Leituras independentes preservam loading enquanto houver canal atual pendente.
- Negação reconhecida invalida todos os caches e respostas anteriores, inclusive
  escrita em trânsito; disposal impede aplicação e notificação tardia.
- Comando validado invalida leituras de eventos anteriores; lista atrasada não
  ressuscita rascunho excluído. Detalhe não revelável remove a cópia prévia.
- Payload de coleção inválido não vira lista vazia; erro transitório preserva
  snapshot e informa falha. Solicitações aplicam ambas as coleções somente
  depois da validação das duas.
- Review encontrou invalidação anterior à validação do comando. RED confirmou
  `isLoading=false` indevido; parser passou a validar antes da invalidação.
- Teste de router habilita explicitamente `allowDevelopmentPreview`; nenhum
  guard produtivo foi alterado. Essa prova cobre DEV, não rota produtiva.

## Evidências e limites

- TDD inicial: seis novos cenários falharam, depois passaram; mais dois cenários
  de exclusão/detalhe falharam antes dos guards específicos.
- Repository: 18/18 testes verdes após o ajuste final do review.
- Regressão funcional Agenda final: 84/84 verdes (data, router e sete suítes
  funcionais de apresentação), incluindo o último cenário do review.
- Analyzer nos três arquivos Agenda: sem problemas na reexecução final.
- Review independente do ajuste final: sem achados adicionais nesse ajuste.
- Sem atualização de golden nem prova visual nova: UI não foi alterada.
- Não fecha todas as corridas entre canais que escrevem o mesmo evento nem
  comandos simultâneos. Estados tipados/loading/error/retry das telas,
  validação de recorrência/hierarquia, SQL, produção e E2E permanecem abertos.

Gate de memória: projeção `docs/knowledge/team/superadmin-agenda.md` reconciliada
com ADR 0029/spec 050 já aprovadas. Captura somente a autorização durável do
backend, sem promover implantação ou conclusão. Nenhuma decisão nova de produto.
Validação da base e testes da skill de memória executados; o campo `source`
foi ajustado ao formato de caminho único exigido pelo validador.

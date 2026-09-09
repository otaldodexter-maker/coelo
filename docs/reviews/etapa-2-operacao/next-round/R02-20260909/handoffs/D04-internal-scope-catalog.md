---
source: "specs/039-superadmin-internal-auth-session-context.md; platform_user_form_page.dart; PlatformUserRepository.isDemo; delegação nominal do pai D04 de 2026-09-09"
status: "local-green-partial; parent-review-pending; no-production-activation"
generated_at: "2026-09-09T15:56:00-03:00"
---

Recorte delegado excepcionalmente ao filho Convites: apps/superadmin → Acessos →
Usuários internos → Criar/Editar → `internal-users.create`, `internal-users.edit`.
Somente `platform_user_form_page.dart` e `platform_user_form_context_test.dart`;
pai permaneceu sem editar esses arquivos. HEAD observado ao entregar:
`87ab206560fcd0999653e6bb95860901653134fd` (inclui trabalhos independentes).

O formulário oferecia três IDs de instituições fictícios também quando
`repository.isDemo=false`. Seleção, revisão e montagem do draft forçavam
`institutions[id]!`, causando null-check em membership real sem nome no mapa.
Dois testes reproduziram os defeitos antes da correção. A primeira tentativa
do harness teve parâmetro incorreto de copyWith e não conta como falha de produto.

O default agora é mapa vazio; as três instituições demonstrativas só são usadas
quando `isDemo=true`. Repositório real precisa receber catálogo explícito.
Catálogo ausente/incompleto mostra indisponibilidade da edição de perfil e
escopos, preserva acesso recebido do backend e permite editar identidade.
Criação não avança nessa condição. IDs e nomes existentes são preservados no
draft; ausência de nome é apresentada como indisponibilidade, sem converter ID
em nome nem inserir rótulo fictício no payload. A validação de autorização e
validade desses vínculos permanece no backend. Não foi implementado catálogo,
lookup, concessão ou regra nova de acesso.

Evidências próprias em `../evidence/D04/invites/internal-scopes-{red,green}.log`
(UTF-8, sem BOM):

- RED focal final: P0/F2/B0/S0/U0, exit 1: estado de catálogo ausente faltava;
  membership UUID real causava null-check na etapa de acesso/revisão.
- GREEN final: P20/F0/B0/S0/U0, exit 0: 17 testes de contexto (6 novos) e
  3 testes existentes de páginas, incluindo criação demo e seleção de três
  instituições demonstrativas. O teste de recibo create passou a fornecer
  catálogo sintético explícito para seu repository não-demo.
- `git diff --check` dos dois arquivos: exit 0. Analyzer focal dos dois arquivos:
  exit 0, sem issues; não equivale a runtime backend/E2E.

Nenhum SQL, conta, convite, rota compartilhada ou operação remota. Slot Flutter
liberado ao pai após o GREEN. Catálogo produtivo autorizado continua gate
nominal; rota normal de edição permanece read-only conforme composição vigente.
Sem ação promovida a FE/BE/E2E concluída. Memória no-op: defesa implementa a
separação demo/produção e o contrato existente de escopo, sem conhecimento novo.

Revisão do pai resolvida às 15:51 BRT: mudança/remoção do catálogo após editar
alcance revelou divergência entre resumo staged e payload preservado. Dois
testes adicionais reproduziram a falha (P0/F2/B0/S0/U0, exit 1), preservados em
`../evidence/D04/invites/internal-scopes-transition-red.log`. Agora painel,
revisão, validação e payload usam os mesmos valores efetivos do vínculo real.
A disponibilidade verifica também os IDs do vínculo carregado, impedindo que
selecionar global esconda a perda da instituição original no catálogo. Os dois
casos comprovam resumo e payload originais, com a identidade editada mantida.
Estão incluídos nos 20 PASS finais; não somar os lotes anteriores de 17/19 como casos
adicionais. Slot liberado a Safety e analyzer encerrado; sem processo próprio.

Revisão final do pai resolvida às 15:56 BRT: criação que já estava na revisão
também podia perder o catálogo antes de salvar. Novo caso RED P0/F1/B0/S0/U0,
exit 1, em `../evidence/D04/invites/internal-scopes-create-red.log` reproduziu
o null-check. Nomes indisponíveis sem cadastro existente agora retornam lista
vazia; a revisão apresenta bloqueio explícito e o botão de salvar informa a
dependência sem emitir create. O teste verifica ausência de erro, nenhum vínculo
existente fictício e zero comandos. Incluído nos 20 PASS finais, analyzer clean
e diff-check exit 0. Nenhum caminho backend ou escopo adicional foi implementado.

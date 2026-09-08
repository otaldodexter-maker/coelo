---
title: "LOC-READNAV01 — proposta de entrada e navegação contextual"
source: "design Locais aprovado em 2026-09-02; LOC-READADAPTER01 64ec7a63; composição PersonDetail vigente; reserva documental da coordenação em 2026-09-08"
status: "proposal-not-approved-for-shared-implementation"
generated_at: "2026-09-08"
---

# Objetivo e limites

Conectar futuramente a leitura preparada ao contexto proprietário explícito,
sem inventar destino global de menu. Esta proposta não altera os cinco arquivos
compartilhados nem habilita endpoint/rota. Depende de revisão central e replay
SQL nominal; não entrega criar/editar, mapa, foto, cópia, reservas ou vínculos.

## Entrada proposta

A fonte aprovada exige seção `Mapa e locais` desde criar/editar Instituição e
Unidade. Essa seção será a entrada contextual, não um item novo no menu global.
A fatia READ só pode consultar proprietário já persistido. Antes de existir ID
real, não emitir RPC, inventar UUID nem salvar local órfão. A composição de
cadastro inicial precisa do contrato futuro de escrita, preservando dados não
salvos; não será implementada implicitamente nesta fatia.

Para proprietário existente, a ação de consultar catálogo carrega instituição
e unidade real da entidade; parâmetros de navegação continuam não confiáveis.
Não deduzir catálogo da unidade a partir do institucional nem juntar ambos.

## Rotas candidatas para revisão

| Origem | Diretório | Detalhe |
| --- | --- | --- |
| Instituição persistida | `/institutions/:institutionId/locations` | `/institutions/:institutionId/locations/:locationId` |
| Unidade persistida | `/institutions/:institutionId/units/:unitId/locations` | `/institutions/:institutionId/units/:unitId/locations/:locationId` |

São quatro padrões candidatos para duas superfícies reutilizadas. A avaliação
central pode escolher outra representação; nenhum desses endereços existe por
aprovação presumida. A origem explícita permite Voltar sem aceitar URL externa
ou returnTo livre. O detalhe deve voltar ao catálogo do mesmo proprietário;
saída do catálogo volta à origem nominal previamente definida. Preservação do
draft de criação/edição deve ser resolvida antes de conectar o botão da seção.

O detalhe envia somente location_id ao backend, que deriva e reautoriza o
proprietário real. O controller compara a resposta com o proprietário esperado
da rota; divergência não renderiza dados. Essa comparação cliente não substitui
o teste BOLA no backend.

## Hunks compartilhados previstos, ainda não aplicados

1. `core/config/superadmin_auth_scope.dart`: campo/constructor de reader com
   default Unavailable; SupabaseLocationCatalogReader apenas na composição
   produtiva quando a cadeia SQL estiver autorizada. Sem alterar Auth.
2. `main.dart`: repasse do reader, sem singleton novo nem armazenamento de token.
3. `app/superadmin_app.dart`: parâmetro/campo e repasse ao router.
4. `app/router/superadmin_routes.dart`: constantes dos padrões aprovados.
5. `app/router/superadmin_router.dart`: reader default indisponível e builders
   nominais. Reusar ListenableBuilder da sessão como PersonDetail: ausência de
   autenticação/recovery não renderiza; revision invalida estado. Não inserir
   exceção nos gates de mutations nem tocar consumidores de Atividades.

Wrapper de página e callbacks das seções ficam em arquivos da feature própria,
sob reserva posterior; os panels existentes são conteúdo, não outro shell.
Reusar shell persistente/layout canônico e baseline Instituições, sem duplicar
cabeçalho, menu ou inventar visual de página.

## Testes exigidos antes de habilitar

- Deep link válido institucional/unidade; IDs malformados, proprietário/ID
  trocados, resposta owner divergente e ausência de sessão sem payload.
- Troca de sessão/realm/revision, logout e revogação durante request, com
  remoção imediata e descarte de completions/callbacks obsoletos.
- Retorno nominal, sem open redirect, sem cair em edição/escrita; proteção
  explícita do draft na entrada desde criar/editar.
- Diretório e detalhe usam somente readers v2, sem fallback legado ou fixture.
- Integração visual com shell: claro/escuro, 375/768/1024/1440, texto 200%,
  foco/teclado/toque e estados indisponível/negado/vazio/retry.
- SQL/RLS autorizado, tenant A/B, revogado, auditoria e persistência/reload;
  o teste local do adapter não substitui esses gates.

## Decisões pendentes

Validar padrões de endereço, origem/retorno e retenção do draft da seção antes
dos hunks. A interface READ não contém disponibilidade, mapa ou vínculos:
mesmo integrada, não permite promover locations.list ou locations.detail-links
inteiros, nem os outros cinco IDs. R2/cópia/seleção de grupo continuam abertos.

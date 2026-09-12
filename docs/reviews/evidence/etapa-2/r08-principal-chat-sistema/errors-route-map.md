---
fonte: R08-backlog.md; tres rastreadores vigentes; spec2026-07-28-superadmin-error-pages-design.md; codigo b58cbaec9
status: mapeamento-estatico-sem-promocao
data_geracao: 2026-09-12
---

# Erros — gatilhos produtivos e prova ainda necessária

Recorte apps/superadmin → erros → errors.403/404/409/500/503/retry.
Leitura focal do host e de todas as referências a SuperadminErrorScreen em lib;
nenhuma edição de router, exceção artificial ou execução de Chrome/Flutter.

| Ação | Caminho encontrado no router | Limite da conclusão |
| --- | --- | --- |
| errors.403 | Duplicar modelo de perfil: capability ausente, linhas3857–3873; botão retorna aos modelos. | Guard de cliente identificado; falta abertura por ator autorizado QA que realmente não tenha capability. Outro Owner não demonstra negativa cross-tenant. |
| errors.404 | errorBuilder1068–1071 para rota desconhecida; volta ao início. | Gatilho estático presente; nova prova visual da rodada pendente. |
| errors.409 | Nenhuma construção produtiva com kind.conflict em lib. | Enum visual existe; fromCode é usado por /dev/errors/:code6337–6344. Conflitos inline do domínio não equivalem a essa tela. |
| errors.500 | Nenhuma construção produtiva com kind.internal em lib. | Mesma limitação: não provocar/simular erro500 para chamar isso de backend verificado. |
| errors.503 | Capacidade de mutação indisponível840–844, suporte sem controller3983–3988, MedicationPlans7064–7067 e composição ausente7070–7073. | Indisponibilidade de composição identificada; não representa uma indisponibilidade real do serviço medida nesta rodada. |
| errors.retry | O integrado vigente cita retry contextual em Momentos (capturas históricas11/22). principal_moments_preview_page.dart:343–344 chama _loadFeed:122, que lê listVisibleMoments:136; adapter chama list_visible_moments:40. | Fluxo real de releitura existe no código; não depende de SuperadminErrorScreen. Capturas antigas não são novo aceite R08. Negação não oferece retry; erro transitório oferece. |

A rota /dev/errors/:code troca o rótulo por Voltar ao início e retorna ao
/dev/home. Portanto nem seu botão demonstra retry real. O estado deferred503
(linhas848–863) é indisponibilidade pós-MVP aprovada e não deve virar falha
temporária. Router pertence ao integrador; nenhum novo fluxo de erro foi criado.

## Contrato e próximo ajuste concreto

A spec28/07 limita a entrega a tela parametrizada, callback e404 no router;
backend/RLS ficam fora. A extensãoR01 inclui409 e exige manter os erros
contextuais na própria superfície; expressamente não liga retry produtivo nem
repete comandos automaticamente. P26/R04 aprovou o golden409, sem promover rota.
Logo, ausência de wiring global500/409 não autoriza converter conflitos inline.

Para errors.retry, preservar o caminho já existente do Momentos: provocar apenas
uma indisponibilidade transitória de leitura no contexto QA, restaurar o serviço
normal e usar Tentar novamente; conferir nova RPC list_visible_moments, feed,
escopo e reload. Isso exige slot/runtime e método nominal não destrutivo para
indisponibilidade; não foi executado nem implementado bloqueio artificial.
O teste local existente `retries an unavailable feed` verifica duas leituras;
`keeps unauthorized failures fail-closed and without retry` protege negação.
Nenhum desses testes foi repetido nesta revisão.

O próximo ajuste proposto ao escritor central é documental: C0 separar esse retry contextual da
tela global na descrição do gate e retirar expectativa genérica de CRUD,
paginação e tenantA/B para uma tela que só delega callback. Autorização/tenant
continuam exigidos na operação real associada, nunca dispensados por esse mapa.
Não alterei rastreadores nem proponho promoção automática ou novo denominador.
Para403/404/503, a próxima prova usa a rota/contexto já existente; para409/500,
C0 define o fluxo específico se houver necessidade além da composição aprovada.
Nenhum patch produtivo é necessário só para satisfazer uma classificação.

Não há novo aceite BE/E2E, contagem de teste ou mudança de contrato. Memória:
nenhum conhecimento novo aprovado; fonte canônica preservada.

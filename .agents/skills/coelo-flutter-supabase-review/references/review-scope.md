---
source: "AGENTS.md; correção da auditoria das skills autorizada pelo Owner em 2026-09-08"
status: "active"
generated_at: "2026-09-08"
---

# Recorte, leitura e evidência de revisão

Aplicar a profundidade necessária ao pedido, preservando as exigências de
segurança e os critérios de conclusão. A escolha do modelo não altera gates.

## Entrada

Antes de editar, registrar brevemente objetivo, apps/ações, pendências conhecidas,
incluído/fora, ordem, parada e evidências esperadas. Estimar após inventariar;
se não houver base, declarar a incerteza. Não usar faixas fixas como promessa.
Escopo e autorizações já dados pelo usuário dispensam repetição de perguntas.
Perguntar somente quando a ambiguidade material impedir uma decisão segura;
continuar trabalho independente. Não perguntar tempo como requisito de entrada.

| Pedido | Leitura e entrega |
| --- | --- |
| Explicação ou skill/documentação | Fontes canônicas e trechos necessários; rastreador se a explicação depender de estado/progresso. Não inaugurar auditoria de app ou produção. |
| Correção localizada | Cabeçalho, regras de estado e linhas das ações no rastreador da camada, com dependências e evidências. Entregar a correção verificada; sem percentual do backlog inteiro por inferência. |
| Auditoria ampla ou conclusão de camada | Ler integralmente o rastreador da camada, inventariar IDs e reconciliar evidências. Ler as fontes apontadas conforme risco. |
| Alteração ou certificação ponta a ponta | Coordenar as camadas afetadas. Para conclusão ampla, ler os três rastreadores integralmente; para ação específica, cruzar os mesmos IDs e seus gates. |

Ler cada skill/referência uma vez e reutilizar o contexto, salvo mudança do arquivo.
Frontend e Backend chamam integração apenas quando o contrato atravessa as camadas;
integração coordena essas autoridades sem reiniciar dependências em ciclo.
Mencionar Auth, Supabase ou Cloudflare não significa alterar essas camadas.

## Ferramentas e prova proporcional

Carregar skills técnicas conforme o trabalho: UI para composição/interação,
responsividade quando layout muda, revisão Dart quando código Dart é revisado,
Astro para Site, Supabase/Cloudflare quando usados. Não impor uma pilha completa
para correção textual. Preferir a menor mudança que resolve a causa.

Defeito funcional: reproduzir, escrever teste que falha pela causa, corrigir e
verificar. Mudança documental/visual simples: links, schema, consulta, inspeção
ou golden pertinente podem ser mais adequados; não criar teste de frase para
simular prova de comportamento. Executar os checks obrigatórios do recorte.

UI administrativa e Principal têm contratos próprios mesmo no mesmo app.
Ausência de teste não cria decisão de produto; ausência de definição visual
exige proposta antes de oficializar novo padrão. Goldens não se aprovam sozinhos.

## Estados e limites

Usar denominadores e evidências atuais do inventário/rastreadores, sem números
fixos nas skills. Separar resultado da tarefa, progresso do recorte e progresso
geral quando este for medido. `pending-verification` não significa código ausente;
`local-green` histórico não significa certificado atual. Não refazer por contagem.

Atualizar somente rastreadores afetados no mesmo turno da mudança de estado,
bloqueio ou estimativa. Auditoria de skill não certifica ações do produto. Frontend
`verified`, Backend `done` e `verified-e2e` continuam provas distintas.

Todo recurso remoto Coelo é produção. Permissão para corrigir localmente não
autoriza pacote remoto; manter autorização nominal, testes locais, aplicação
forward-only serializada, recuperação e cleanup. Um bloqueio remoto retém
somente o trabalho dependente. Não exigir commit/push, deploy ou worktree limpa
como condição para relatar uma correção local testada; integração/publicação
recebem declaração e evidências próprias quando fizerem parte do pedido.

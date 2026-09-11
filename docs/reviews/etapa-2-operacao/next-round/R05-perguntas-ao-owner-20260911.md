---
title: "Rodada 5 — perguntas ao Owner (tarde de 11/09/2026)"
source: "coordenacao.json revs 38-45; JSONs das sete frentes da R05; docs/reviews/evidence/etapa-2/r05-*/"
status: "open"
generated_at: "2026-09-11"
timezone: "America/Sao_Paulo"
---

# Rodada 5 — perguntas ao Owner

Lote único da tarde. Visuais têm página lado a lado (**R** referência guardada,
**A** render atual). Responder por arquivo (`nome - decisão, observação`) ou
"tudo aprovado". Respostas entram em `coordenacao.json`, na ADR 0034 e nas
skills no mesmo turno em que chegarem.

## Visuais

| Item | Frente | Página | Estado |
| --- | --- | --- | --- |
| G-SUP-R05 — Suporte e Em implantação alinhados como Instituições (16 goldens claros) e `plan_table_light_*` | operacoes | https://claude.ai/code/artifact/7737ccf7-1489-4d67-ba5f-858c051150d2 (cópia em `evidence/etapa-2/r05-operacoes/g-sup/`) | **Respondido às 14:20: "está tudo aprovado, ficou legal"** → `ownerVisualApproval = A` |
| P33/P34-R05 — calendário da Agenda conforme o iPhone (P33, R) e rodapé do detalhe do evento (P34, A+): 12 goldens `agenda_calendar_*` e `agenda_detail_*` | publicacoes-agenda | https://claude.ai/code/artifact/881e760e-4a7a-456e-9f1e-54fd26be3975 (cópia em `evidence/etapa-2/r05-publicacoes-agenda/duvidas-visuais.html`) | **Respondido às 14:52: "o render atual está perfeito e aprovado"** → `ownerVisualApproval = A` nos 12 goldens |
| IMP-R05 — Importações: diretório no composto e goldens dentro da shell (`import_hub_*`) | operacoes | https://claude.ai/code/artifact/aafedc26-2673-4f10-8310-37b367dad7f7 | **Respondido às 14:58: "correto e perfeito", exceto `import_hub_wizard_unavailable_light_1440_200` (wizard incorreto e fundo cinza) → A nos demais, A+ nesse |
| AGENDA-CRIAR-R05 — wizard de evento da Agenda ganhou o campo "Qual Instituição/Unidade/Turma" quando há mais de um contexto do nível (antes ia sempre para o primeiro); goldens `agenda_create_*` regravados por conteúdo novo | publicacoes-agenda | página lado a lado a montar na R06 (goldens em `apps/superadmin/test/goldens/agenda/agenda_create_*`) | aguardando (A+ proposto) |
| IMP-R05-2 — conferir só `import_hub_wizard_unavailable_light_1440_200` corrigido (página honesta dentro da shell a 200%); observação da frente: a página genérica diz "temporariamente indisponível (503)" para recurso adiado por decisão — texto honesto seria "Disponível depois do MVP" (transversal, não mudado) | operacoes | https://claude.ai/code/artifact/aafedc26-2673-4f10-8310-37b367dad7f7 (v2) | aguardando |

## Produto e processo

| Item | Frente | Pergunta | Recomendação |
| --- | --- | --- | --- |
| P43 | operacoes | `account.sessions` (listar e revogar as próprias sessões) não tem tela nem API de cliente; exigiria Edge Function sobre o Admin API do Auth. Entra no MVP? | A) pós-MVP (recomendado; Sair já encerra a sessão e MFA está fora do MVP); B) tela mínima no MVP (lista + revogar todas) com Edge Function |
| P44 | operacoes | Catálogo (`catalog.validate/sync`): 5 componentes do composto da Fase 0 sem entrada no índice e 7 exemplos com fingerprint desatualizado. Atualizar agora ou depois do MVP? | A) depois do MVP, junto da revisão de UI (recomendado); B) agora, por uma frente de UI |
| P45 (numerada P43 no JSON de acessos) | acessos-pessoas | Modelo de sistema de perfil criado pelo Superadmin pode ser excluído ou só inativado? Hoje o delete é protegido. | Manter protegido; só inativar (recomendado) |
| P46 (numerada P44 no JSON de acessos) | acessos-pessoas | Usuários internos (Superadmin) também têm @? Hoje o @ vive em `public.people` (pessoas), e a pessoa de serviço da ponte já recebe um. | Sim, na próxima rodada, reutilizando `person_handles` pela pessoa de serviço (recomendado) |
| P47 (numerada P43 no JSON de principal-chat) | principal-chat-sistema | Cardápios: o assistente de criar/editar/modelo/publicar cai em 503 porque o cliente exige `authorizedMealPlanTenantId` (fail-closed por tenant vazio) que nunca é injetado; o servidor já valida escopo. Autorizar remover esse fail-closed do cliente? A frente não fez a alteração porque o classificador da conversa dela a classificou como afrouxamento de segurança; o coordenador não a fez por ela. | Sim, remover o fail-closed do cliente e provar as 5 ações na rota real na próxima rodada (o servidor é a autoridade) |
| P48 (numerada P44 no JSON de principal-chat) | principal-chat-sistema | Sincronizador do P35: todo usuário interno com `platform_membership` ativa recebe `institution_admin` em toda instituição ativa. Distinguir owner de operations? | Sim: owner → `institution_admin`; operations → papel de leitura, na próxima rodada, junto da correção da raiz da ponte (lote 44) |
| PEND-ARROBAS (pendência do Owner, 15:20) | coordenação | No encerramento do MVP, perguntar ao Owner as duas listas de arrobas: palavras proibidas como @ (e talvez na escrita) e palavras que só o Owner pode usar como @. Não perguntar antes; hoje só `coelo` e `coelo.me` são reservados. | Registrar em `reserved_handles` por migration quando as listas chegarem |
| P49 (numerada P45 no JSON de operações) | operacoes | Suporte e Implantação: hoje o Status é um filtro (dropdown) e a visão volta a cards a cada reload; a regra "estado vazio mantém abas de estado" pede abas por tela (Todos / Novo / Em andamento / Aguardando solicitante / Concluído na tabela). | A) abas no lugar do filtro Status + persistir a visão cards/tabela (recomendado); B) manter filtro e não persistir |
| P50 | publicacoes-agenda | `circulars.respond`: o Superadmin tem tela de resposta à circular ou só o resumo das respostas (o backend já responde por RPC)? | Só o resumo no Superadmin; responder é ação do Principal (recomendado) |

## Registro

- Chaves criadas na rodada e dados sintéticos: ver `R05-fechamento.md`.

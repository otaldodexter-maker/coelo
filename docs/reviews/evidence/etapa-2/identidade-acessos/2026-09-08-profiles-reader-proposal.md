---
title: "Perfis — proposta nominal de reader interno após ACL RED"
source: "Reserva de proposta do Coordenador; diagnóstico Profiles8/Auth47 do Engenheiro 1; spec 018; spec 039; migrations 20260811215451 e 20260901200206; review realm_audit"
status: "proposal-only; institutional-actor-scope-awaiting-decision"
generated_at: "2026-09-08"
---

## Evidência e objetivo

Engenheiro 1 reportou execução real da fixture b11c3c3e: 3 PASS de
precondições e 5 FAIL nas expectativas #4–8, decorrentes de quatro chamadas
capturadas com SQLSTATE 42501, classificadas `acl-before-contract`.
O wrapper público é SECURITY INVOKER com EXECUTE para authenticated; o cursor
privado é SECURITY DEFINER sem esse EXECUTE. Não houve aborto nem grant de
contorno. O artefato final nominal do operador ainda será reconciliado.

Objetivo: permitir a leitura nominal de Perfis pelo principal interno, com o
contrato paginado consumido pelo cliente. Estes resultados não comprovam
cinco defeitos funcionais independentes de paginação e filtros.

## Candidata mínima para aprovação

Substituir somente o corpo de
`public.superadmin_access_profiles_list(text,text,text,text,integer,integer)`
por implementação SECURITY DEFINER, STABLE, owner postgres, search_path vazio
e referências qualificadas. Preservar assinatura e conferir ACL nominal
pré/pós; não conceder EXECUTE ao cursor privado nem mudar helper global.

Antes de consultar dados, obter o contexto com
`require_superadmin_internal_context('platform.read')`. A capability de READ
está na spec 018:138; roles.manage é de mutações (:139–140). A proposta anterior
de copiar a exigência de gestão do helper legado foi descartada após review.
Preservar AAL1 do MVP conforme o aditivo vigente; não copiar o AAL2 histórico.

A consulta deve devolver items, total filtrado, page e page_size; aplicar
paginação de base 1 com limites server-side, ordenação estável lower(name),id
e filtros de conjuntos para CSV. Página além do total devolve items vazio,
sem perder total. Nenhum filtro de status novo será inserido na UI.

## Decisões ainda necessárias antes de SQL

1. Escopo do ator: o guard retorna scope_kind e scope_institution_id, mas
   não autoriza implicitamente um catálogo global para membership institucional.
   Recomenda-se uma primeira fatia explicitamente platform-scoped; liberar
   contexto institucional exige regra de visibilidade por instituição. Uma
   negação nova não deve ser implementada silenciosamente como decisão final.

## Contratos reconciliados pelo review central

O Coordenador conferiu as fontes e esclareceu que, para ator global, o
contador representa atribuições ativas, não contas autenticáveis. No ramo
platform, contar superadmin_internal_memberships ativas por platform_role_id,
sem exigir auth-link nem consultar platform_memberships legadas. A spec 039
mantém uma membership interna ativa por identidade. Não usar o filtro do
diretório de Usuários Internos para reduzir este contador.

No ramo institution, preservar catálogo global e local e contar
institution_role_assignments ativas/não expiradas. A spec 018:101 restringe
CRIAÇÃO, não leitura. Não acrescentar join com People/Auth. A lacuna permanece
na visibilidade/agregação para ator interno de escopo institucional; nenhuma
negação global ou ampliação foi autorizada por conveniência técnica.

Envelope: AccessProfile.fromJson consome `membership_count` ou o tamanho de
`memberships`; não consome `linked_people_count`. O cursor legado devolve este
último nome. A corretiva proposta deve servir `membership_count` ao consumidor
real, sem introduzir `assigned_count` ou outro alias. Essa divergência é
estática até teste nominal; o ACL RED não chegou a esse parsing.

## Matriz complementar proposta

Preservar Profiles8 como diagnóstico original, sem enfraquecer expectativas.
Adicionar em fixture nominal separada:

- interno sem people, AAL1, platform.read e sem roles.manage: permitido;
- auth.uid ausente: SAI_AUTH_REQUIRED; sessão ausente/expirada: SAI_SESSION_INVALID;
- auth-link ausente/inativo: SAI_INTERNAL_CONTEXT_DENIED;
- membership suspensa/revogada: respectivos SAI_MEMBERSHIP_*;
- capability ausente ou deny: SAI_PERMISSION_DENIED;
- membership institucional com capability: negação ou filtro conforme decisão;
- acesso direto ao cursor privado: continua proibido;
- vínculos internos ativos com e sem auth-link: ambos contam no ramo platform;
- vínculos internos suspensos/revogados e vínculos platform legados: não contam;
- assignments institution ativos válidos contam; inativos/expirados não;
- envelope usa membership_count e o teste de cliente verifica seu valor;
- domínio inválido, limites, CSV múltiplo, página vazia e fora do total;
- se institution entrar: global/local e instituição A/B sem exposição cruzada.

A matriz de ACL também confere owner, SECURITY DEFINER, STABLE, search_path e
privilégios efetivos, inclusive ausência de grant indireto indevido.

## Limites e execução

Esta proposta não altera SQL, router, detail, catálogo, Principal, writes,
atribuições, RLS, MFA ou modelos. O reader não resolve os gates próprios de
proveniência de sessão/recovery. Revisão realm_audit aprova a arquitetura
candidata, não fecha o escopo institucional aberto. Após decisão, preparar teste RED,
corretiva nominal forward-only e replay por Engenheiro 1; produção somente com
lease do Coordenador. Não há promoção Front-end verified, Back-end done ou E2E.
Gate de memória: no-op; nenhuma proposta é projetada como produto aprovado.

---
title: "Meu perfil: cabeçalho e organização de acesso"
knowledge_id: account-profile-header-access
source: docs/design/account-profile-owner-adjustments-20260913.md
status: validated
generated_at: 2026-09-13
audience: team
surfaces: [superadmin]
visibility: internal
review_owner: Coelo Owner
---

A direção aprovada exige que nome/foto e sigla/cor salvos sejam refletidos no cabeçalho e
mantidos após reload. Prévia de foto no editor não prova persistência.

As ações de salvar/cancelar permanecem acessíveis; Meu acesso usa rolagem
limitada, busca e grupos baseados no módulo e escopo reais. A área continua
somente leitura e não muda permissões. Funções adiadas não são apresentadas
como operações disponíveis apenas por constarem no catálogo de capacidades.

O cabeçalho usa a identidade confirmada pelo backend; uma resposta que não
confirma todos os campos não autoriza promover a prévia local a perfil salvo.
O rascunho permanece revisável/cancelável. Quando o contrato ainda não informa
módulo/escopo, manter a lista pesquisável sem inventar hierarquia.

A orientação se refere à Conta administrativa, distinta do Sobre do Principal.
Os estados de implementação e as provas atuais pertencem aos rastreadores;
esta projeção de regras não certifica o aceite integral da ação.

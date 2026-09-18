---
source: Owner e doze anexos de Perfis e permissões na conversa de 2026-09-13; specs/018-profiles-permissions-superadmin.md
status: backlog R12; direção registrada; sem implementação
generated_at: 2026-09-13
---

# R12 — Perfis, modelos e permissões

Terceiro bloco de R12-apontamentos-owner.md. Fora da implementação R11.
Host apps/superadmin > Acessos > Perfis e permissões; família administrativa.
Doze anexos vistos na conversa, sem exportação dos binários ou cópia de dados
pessoais. Responsável: C0 R12. Complementa R12-11 sem duplicar avanço.

| ID / anexos | Tela/estado | Requisito e primeiro gate |
|---|---|---|
| R12-19 / 1–2 | Diretório > filtros/abas | Modelos de perfis e Perfis, nessa ordem, abaixo dos filtros. Manter domínio de aplicação distinto dessas categorias. Verificar suspeita de inversão funcional: Perfil abre como modelo não editável e Modelo oferece gestão/vínculos de perfil. Rastrear rota, entidade, repository, persistência e atribuições antes de concluir que é só rótulo ou trocar dados. |
| R12-20 / 3 | Diretório > card | Distribuir informações internas em 2×2, dois acima e dois abaixo; complemento de R12-11. Responsivo, sem inventar quarta métrica e sem limitar diretório a quatro registros. Propor conteúdo coerente com modelo versus perfil. |
| R12-21 / 4 | Detalhe > resumo/permissões | Melhorar hierarquia e leitura, eliminar hover cinza, traduzir nomes/grupos/descritivos de produto. Preservar códigos técnicos internamente. Reproduzir interações e comparar com baseline administrativa. |
| R12-22 / 5–6 | Criar/Editar > Perfil e escopo | Wizard igual Criar/Editar Instituição, sem contêineres redundantes. Remover campo Código do fluxo de usuário; não apagar identificadores usados por contratos. Se necessário, gerar identificador interno sem exigir preenchimento manual. |
| R12-23 / 7 | Perfil e escopo > Principal / funcionário | Owner solicita criar perfil de funcionário para o Principal; pessoa pode ter múltiplos tipos de perfil e vínculos com várias unidades/instituições. Distinguir app/domínio (Principal) de alcance hierárquico (instituição/unidade/turma etc.). Reconciliar conflito com spec 018 antes de implementar, conforme seção abaixo. |
| R12-24 / 8 | Permissões > seleção | Corrigir alinhamento de opções e hover cinza. Retirar rótulo repetido Crítico; explicar consequência específica por tooltip, acessível também por foco/acionamento no toque. Não retirar validações ou proteção do comando. Rótulos em português e iguais aos menus/telas reais. |
| R12-25 / 9–10 | Permissões > matriz | Anexo 9 aprovado como direção de composição tabular; anexo 10 reprovado (lista vertical em contêiner aninhado). Reutilizar matriz compartilhada com colunas alinhadas. Ações específicas como editar próprios/todos não podem ser fundidas e perder semântica só para caber no CRUD. Adaptar telas estreitas sem impor a lista rejeitada. |
| R12-26 / 11 | Rodapé > Continuar | Continuar habilitado é laranja preenchido, padrão canônico. Branco observado em Editar modelo é reprovado. Estados desabilitados continuam semanticamente distintos. |
| R12-27 / 12 | Revisão > permissões adicionadas/removidas | Exibir módulo → tela → ação, em português, explicando o que será permitido/removido e em qual alcance. Códigos como activities.assign_people não são texto principal. Separar configurado de efetivamente autorizado e recurso disponível de adiado. |

## Semântica e conflito que precisam ser resolvidos

A suspeita Perfil/Modelo é relato para investigação, não defeito de banco confirmado.
Modelo é base para criar perfil; perfil tem configuração aplicável a atribuições.
Validar estas definições nas fontes vigentes e no comportamento real antes da correção.
A tradução deve corresponder ao menu/tela real: não traduzir literalmente termos
técnicos como Directory/Management se o usuário vê Atividades e suas ações.
Não renomear chaves de capacidade ou alterar grants por uma mudança de rótulo.

A spec 018, em Terminologia canônica e Fora de escopo, afirma que Principal não
possui perfil reutilizável e que seu catálogo é somente leitura. O novo pedido
R12-23 solicita criação de perfil de funcionário para Principal. É uma mudança
funcional de contrato, não simples opção adicional em Escopo máximo. Registrar
conflito explícito; direção desejada pelo Owner está capturada, mas o desenho da
substituição da regra anterior precisa ser aprovado antes da implementação.

Proposta para discussão: funcionário usa perfis profissionais atribuídos por
vínculo e contexto, com uso no Principal; pessoa global mantém várias atribuições,
sem converter perfil em papel global nem misturar permissões familiares com
profissionais. Principal é o app de uso, não nível acima/abaixo de instituição.
Esta proposta ainda não é decisão aprovada. Não iniciar Etapa 3 nem apps novos
por este apontamento; delimitar o que cabe na gestão do Superadmin na Etapa 2.

A matriz/revisão não deve apresentar importação/exportação adiadas como operação
funcional liberada; aplicar as exceções existentes sem criar novas. Tooltip de
sensibilidade descreve impacto real, não texto genérico. Proteger leitura e
alterações no servidor e preservar negações, tenant, hierarquia e ownership.

## Estado por camada e integração

FE: todos os ajustes acima planejados, não implementados; anexo 9 é referência
aprovada de conceito, não aceite de implementação nova. BE: verificar modelo/perfil,
atribuições e contrato profissional; nenhuma falha backend diagnosticada pelos
anexos. E2E: pendente reprodução por rota normal, salvar/reload, aplicação ao vínculo
correto e negação cross-tenant, sem somar aprovação visual a conclusão funcional.

action_ids existentes: access-profiles.create, access-profiles.detail,
access-profiles.edit. Diretório/modelos sem mapeamento específico confirmado:
não criar IDs nem alterar denominador silenciosamente. Deltas propostos em
R12-perfis-permissoes-delta.json, ainda NÃO aplicados. C0 central deve rebasear
notas atuais antes de apply-tracker-delta.cjs, incorporar ownerItems ao manifesto
e registrar o conflito acima em docs/open-questions.md ao assumir posse central.
WIP R11 preservado; nenhum arquivo de runtime ou rastreador central alterado aqui.

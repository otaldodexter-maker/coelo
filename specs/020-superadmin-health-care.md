---
title: "Saúde e Cuidado no Superadmin"
source: "pedido aprovado em 2026-08-04; docs/product/prd-master.md; docs/data/data-model.md; docs/security/lgpd-security-media.md; specs/019-superadmin-people-directory.md; decisions/0010-private-media-r2.md; decisions/0015-contextual-people-authorizations-attendance.md"
status: "approved-for-demonstrative-ui"
generated_at: "2026-08-04"
---

# Saúde e Cuidado no Superadmin

## Objetivo e problema

Separar informações permanentes da criança da operação periódica de
medicamentos. O módulo demonstrativo possui duas áreas irmãs: **Perfis de
cuidado** e **Planos de medicação**.

## Substituição parcial

A spec 029 substitui os limites demonstrativos desta spec somente para Planos de
medicação. Perfis de cuidado permanecem demonstrativos até spec própria.

## Escopo

- diretório, detalhe e formulário para as duas áreas;
- busca, filtros, cards, tabela, paginação e estados de permissão;
- fixtures determinísticas e persistência somente local;
- componentes compartilhados Coelo para cards, tabs, flyouts, tabela e
  múltipla escolha.

## Fora de escopo

Banco produtivo, Supabase remoto, migration, RLS, RPC, dados reais, upload
produtivo, nova regra de autorização ou telas em Admin/Principal.

## Rotas

- `/health-care/profiles`, `/health-care/profiles/new`,
  `/health-care/profiles/:childId` e `/health-care/profiles/:childId/edit`;
- `/health-care/medication-plans`, `/health-care/medication-plans/new`,
  `/health-care/medication-plans/:medicationId` e
  `/health-care/medication-plans/:medicationId/edit`.

As rotas antigas são removidas sem redirecionamento.

## Perfis de cuidado

Reúnem identidade, alergias/restrições, sinais, adaptações e orientações. Na
criação, seleciona-se uma criança existente; na edição, a identidade fica
travada. O diretório usa Todos, Ativos, Em Implantação e Inativos e filtros por
Pessoa, Criança, Instituição, Unidade e Turma/Atividade.

Alergia tem dimensões independentes:

- status: Ativo, Em acompanhamento e Histórico;
- gravidade do episódio registrado: Leve, Moderada e Grave.

A gravidade descreve apenas o episódio documentado e não prevê intensidade
futura. Cor sempre acompanha texto e ícone. O perfil não usa semáforo clínico.

## Planos de medicação

Reúnem medicamento, dose, via, vigência, horários, responsáveis, documento
opcional, revisão e registros de doses. Cada horário pertence à casa ou a uma
instituição; a frequência deriva dos horários. Mudança relevante cria versão,
invalida aprovações e preserva doses passadas. Claim evita duplicidade e é
distinto de recibo de ciência.

## Permissões e tenant

Dados acompanham a identidade global da criança, mas exigem contexto infantil
ativo e autorização familiar válida. Operação privada de outro tenant não se
torna global. A UI não autoriza operações produtivas. O Owner pode corrigir a
fixture com justificativa, mas não age em nome da instituição.

## Contratos de UI

- `CoeloAdminInteractiveCard` e anatomia de Instituições;
- tabs lineares de Pessoas;
- toggle Cards/Tabela com segmentos de 64 × 48 px;
- `CoeloAdminFlyout` para visões, somente quando houver mais de uma opção de tabela;
- `CoeloAdminResizableTable` centralizada, com scrollbar acima da coluna fixa;
- `CoeloAdminMultiSelectField<T>`;
- formulário de página com `SuperadminFormActionFooter`;
- token semântico Histórico em light/dark.

A correção visual aprovada em 2026-08-05 está detalhada em
`docs/superpowers/specs/2026-08-05-superadmin-health-care-ui-correction-design.md`.
Ela acrescenta Arquivos aos dois diretórios, remove o banner demonstrativo que
compete com a listagem de Perfis, mantém o toggle compartilhado de 64 × 48 px,
reforça a centralização e a scrollbar da tabela e leva criar, editar e detalhe
para a família visual de Instituição + Unidade com navegação por etapas.

Validar 375, 768, 1024 e 1440 px, light/dark, texto a 200%, teclado, mouse,
toque, foco, Esc, semântica e reduced motion. Não usar hover cinza nem controle
Material cru na feature.

## Critérios de aceite

Os destinos são irmãos; o perfil não incorpora doses; há acesso contextual aos
planos; nenhuma informação depende só da cor; não há overflow nos viewports;
nenhum schema ou migration é criado; testes cobrem domínio, componentes, rotas
e shell.

## Riscos

`OQ-003` mantém base legal e retenção pendentes. Documentos dependem do
contrato R2. Schema, RLS, RPCs e concorrência exigem spec técnica e revisão
humana antes de qualquer migration.

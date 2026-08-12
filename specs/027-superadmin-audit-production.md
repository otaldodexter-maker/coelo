---
source: "Prompt Auditoria aprovado pelo Owner Coelo em 2026-08-11; AGENTS.md; specs/011-superadmin-database-rls.md; decisions/0020-backend-authorization-application-security.md; decisions/0021-operational-import-export-files.md; docs/design/design-system.md"
status: "approved"
generated_at: "2026-08-11"
---

# Auditoria produtiva do Superadmin

## Objetivo e problema

Substituir a Auditoria demonstrativa de `/dev/audit` por uma trilha produtiva,
append-only, minimizada e somente leitura. O frontend apenas consulta eventos e
solicita exportações; autorização, escopo, mascaramento, integridade e retenção
são decididos no backend.

## Escopo

- Diretório com cards e tabela, busca, filtros server-side, cursor estável e
  paginação compacta.
- Detalhe com ator e papel/contexto, instituição quando aplicável, ação,
  recurso, before/after minimizado, motivo, correlation id, origem, instante e
  resultado.
- Exportação CSV/XLSX por job autorizado, idempotente, auditado e armazenado
  temporariamente como arquivo operacional privado.
- RPCs de lista, detalhe e exportação, grants mínimos, RLS, índices e evidência
  de integridade contra adulteração.
- Estados loading, empty, no-results, failure/retry, unauthorized e not-found.

## Fora de escopo

- Criar, editar ou excluir eventos pela UI.
- Importação de auditoria, mídia, perfil público, descoberta, representantes,
  localização, contato, tipos, subtipos, herança ou alteração de plano.
- Expor `audit` diretamente na Data API ou usar segredo/service role no Flutter.
- Expurgo automático antes da aprovação jurídica do prazo de retenção. Até lá,
  a retenção é indefinida e sem DELETE concedido aos papéis de aplicação.

## Matriz de aplicabilidade

| Frente | Aplica | Decisão |
| --- | --- | --- |
| Aparência | Sim | Usa integralmente a baseline de diretório/tabela do Coelo UI. |
| Herança | Não | Auditoria registra o contexto efetivo, mas não edita nem calcula herança na UI. |
| Localização e contato | Não | Dados de contato não pertencem ao payload minimizado. |
| Representante | Não | Representante é vínculo de domínio auditável, não cadastro desta superfície. |
| Admins e profissionais | Não | Podem aparecer apenas como ator autorizado e minimizado. |
| Pessoas e perfis | Parcial | Exibe ator global, papel e contexto; não edita pessoa ou perfil. |
| Tipos, subtipos e Outros | Não | `object_type` e `action_code` são taxonomia técnica validada, não um cadastro. |
| Status | Sim | O estado de domínio da linha chama-se Resultado: sucesso, falha ou negado. |
| Hierarquia | Sim | Instituição, unidade, turma e criança limitam autorização e contexto no backend. |
| Plano | Parcial | Pode ser recurso auditado; somente o fluxo próprio de Superadmin altera planos. |
| Importação | Não | Eventos nunca são importados por esta superfície. |
| Exportação | Sim | Job CSV/XLSX real, autorizado, acompanhado e com artefato privado temporário. |
| Mídia | Não | Auditoria não recebe avatar, capa, fotos ou conteúdo operacional. |
| Perfil público e descoberta | Não | Nenhum `@`, bio, destaque, preview ou descoberta é exposto. |

## Dados, interfaces e fluxo

`audit.audit_logs` continua sendo a fonte canônica. A evolução preserva os
registros existentes e acrescenta contexto confiável, correlation id, origem e
evidência criptográfica encadeada. Inserts permanecem dentro das transações dos
comandos de domínio; UPDATE e DELETE falham fechados.

O Flutter consome `AuditRepository`, com consultas de página, detalhe, geração
e acompanhamento da exportação. A lista não carrega before/after. O detalhe é
buscado sob demanda, sem N+1. Busca, filtros, ordenação, contagem e cursor são
aplicados no SQL. O worker revalida a autorização antes do snapshot, produz o
artefato privado e somente então entrega uma URL HTTPS assinada e curta.

## Permissões e tenant

- `audit.read` autoriza lista e detalhe após revalidação da pessoa e do vínculo.
- `audit.export` é separado, exige AAL2 e autoriza somente o mesmo conjunto
  consultável.
- Eventos institucionais são consultados apenas dentro das relações confiáveis
  autorizadas; eventos globais exigem capability de plataforma.
- IDs, filtros, cursor, correlation id e recurso recebidos do cliente são não
  confiáveis. Respostas não distinguem recurso inexistente de recurso fora do
  escopo.

## UX e baseline

Instituições, anexos 8–18, é a baseline bloqueante. A toolbar usa busca/filtros
à esquerda e Cards/Tabela + Exportar à direita; Turmas e Atividades complementam
somente a distribuição responsiva. São canônicos `CoeloAdminListingToolbar`,
`SuperadminDirectoryViewToggle`, `CoeloAdminFileActions`,
`CoeloAdminResizableTable`, `CoeloAdminPagination` e
`SuperadminListingPaginationFooter`.

Não usar DataTable, Material cru, hover cinza, zebra, controles rígidos,
contagens demonstrativas ou troca automática Cards/Tabela por breakpoint.
Estados interativos usam tokens semânticos, alvos de 48 px, teclado, foco,
semântica, texto a 200% e reduced motion.

## Segurança e minimização

Baseline OWASP ASVS L2, elevada a L3 para auditoria, administração privilegiada,
exports e dados de crianças/cuidado. Before/after usa allowlist por ação e nunca
inclui segredo, token, CPF, contato integral, mensagem, arquivo ou payload bruto.
Textos são renderizados como texto; CSV/XLSX neutraliza fórmulas. URLs de
download são curtas, autorizadas e temporárias.

## Critérios de aceite e testes

- Nenhum fixture/fallback fake entra em produção, router, controller,
  repository ou UI da Auditoria.
- Acesso direto à tabela, DML, RPC sem capability, AAL insuficiente, cursor
  adulterado e IDs cross-scope falham fechados.
- Testes cobrem cross-tenant, instituição, unidade, turma e criança, chamadas
  diretas, inputs hostis, append-only, cadeia criptográfica, export idempotente,
  secrets scan e ausência de segredo no build web.
- UI é validada em 375/768/1024/1440, light/dark, 200%, teclado, foco e reduced
  motion, com goldens focados e validador Coelo UI.
- Advisors, SQL real, format, analyze, testes, knowledge gate e build web passam
  antes da entrega.

## Riscos e perguntas abertas

- O prazo jurídico de retenção permanece aberto. Nenhuma rotina de expurgo será
  ativada até aprovação formal; a integridade append-only prevalece.
- A migration deve retrocompatibilizar inserts legados e não reescrever
  before/after existentes como se tivessem sido validados pelo contrato novo.

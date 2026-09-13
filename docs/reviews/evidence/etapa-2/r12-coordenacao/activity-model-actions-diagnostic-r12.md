---
source: R12 C0 — R12-02 actions diagnostic
status: partial-local; archive contract pending
generated_at: 2026-09-13
---

# R12-02 — ações dos modelos de Atividades

Recorte: Etapa 2 → `apps/superadmin` → Estrutura → Atividades → Modelos →
`activities.list`, cruzado com Rotina diária → Modelos → `daily-routine.list`.

Diagnóstico do código atual:

- Duplicar modelo já existe na composição de cards e tabela, abre o diálogo
  com instituição/unidade/nome e usa callback de duplicação server-side;
- Arquivar não existe no diretório de modelos de Atividades: não há callback
  `onArchive`, ação de linha nem contrato de comando correspondente;
- Rotina diária possui uma ação Arquivar própria, mas sua semântica é distinta
  e não autoriza copiar a ação para Atividades;
- status `archived` é lido/renderizado, porém isso não prova que a mutação de
  arquivamento de um modelo de Atividade esteja disponível.

Não foi criada ação fake, não houve arquivamento em massa e nenhum RPC/RLS foi
alterado. A suíte de Atividades passou 23/23 após o ajuste de R12-03; o item
R12-02 permanece aberto até o contrato de arquivamento, elegibilidade,
versionamento, auditoria e reload serem confirmados.

Próximo gate: definir/aplicar o comando aprovado para arquivar modelos de
Atividades, com confirmação, `expected_version`, negativa de escopo e reload;
depois alinhar a ação nos dois diretórios sem alterar origens imutáveis.

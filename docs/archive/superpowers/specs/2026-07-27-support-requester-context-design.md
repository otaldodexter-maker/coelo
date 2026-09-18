---
source: "user-approved extension to specs/016-superadmin-support-prototype.md; admin.context-picker; pattern.chat-admin"
status: "approved"
generated_at: "2026-07-27"
---

# Contexto do solicitante nos chamados de Suporte

## Objetivo

Permitir que o Superadmin identifique quem abriu um chamado e em qual contexto
institucional o problema ocorreu, sem presumir que todos os níveis da hierarquia
existam.

## Modelo local

Cada `SupportTicket` guarda um snapshot imutável e opcional do contexto existente
no momento do envio:

1. solicitante, sempre obrigatório;
2. instituição;
3. unidade;
4. grupo;
5. atividade.

Os níveis institucionais são opcionais e ordenados. Um nível ausente não produz
placeholder nem separador vazio. O protótipo armazena labels demonstrativos, sem
IDs relacionais, consultas ou resolução posterior.

## Experiência

- Cards do Kanban exibem o solicitante e uma trilha contextual compacta.
- A tabela adiciona a coluna `Contexto`, preservando `Solicitante` como coluna
  independente.
- O detalhe apresenta a trilha completa junto ao relatório original.
- A apresentação usa breadcrumb textual com `>` e não depende de cor ou ícone.
- Textos longos usam reticências nas superfícies compactas; o detalhe preserva a
  leitura integral.
- Instituição, unidade, grupo e atividade só aparecem quando existirem.

## Dados demonstrativos

As fixtures devem cobrir:

- contexto completo até atividade;
- contexto até grupo;
- somente instituição;
- solicitante sem contexto institucional.

Chamados criados pelo modal recebem o contexto demonstrativo da sessão atual.

## Testes

- Unidade: snapshot é preservado e a trilha ignora níveis ausentes.
- Widget: card, tabela e detalhe exibem o mesmo contexto.
- Widget: solicitante sem instituição não produz separadores vazios.
- Goldens existentes são atualizados para refletir a nova informação.

## Fora de escopo

- Buscar contexto em Supabase ou outra fonte externa.
- Validar vínculos de tenant no cliente.
- Atualizar chamados antigos quando nomes institucionais mudarem.
- Transformar o breadcrumb em navegação.
- Criar ou alterar API pública no catálogo.

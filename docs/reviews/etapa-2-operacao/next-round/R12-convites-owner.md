---
source: Owner e anexo de Convites na conversa de 2026-09-13; docs/superpowers/checkpoints/2026-08-04-superadmin-invites-ui-handoff.md
status: backlog R12; sem implementação
generated_at: 2026-09-13
---

# R12 — Convites somente em tabela e reenvio

Host apps/superadmin > Convites > Diretório; família administrativa.
Anexo visto na conversa; binário não exportado. Fora da R11, responsável C0 R12.

- R12-44 / invites.list: Owner determina somente tabela. Remover opção de cards
  e alternador Cards/Tabela. Preservar busca, filtros, paginação, Novo convite e
  ações na composição tabular canônica. Adaptar tabela no compacto com leitura
  e ações acessíveis, sem reintroduzir modo cards. Esta direção futura substitui
  a escolha histórica de cards iniciais do handoff de 04/08, mas não descreve
  implementação já entregue.
- R12-45 / invites.resend: Owner não encontrou Reenviar convite. Verificar onde
  está a ação, menu da linha/detalhe, estado do convite e capacidade do ator.
  Não concluir que backend de reenvio inexiste a partir da ausência visual.
  Tornar a ação encontrável em português no padrão de ações da tabela quando
  permitida, com feedback e indisponibilidade explicada conforme contrato.

Primeiro gate R12: abrir tabela pela rota normal e inspecionar menu/detalhe de
convites sintéticos em estados pertinentes (pendente, expirado, aceito, revogado),
reconciliando elegibilidade existente; não habilitar reenvio indiscriminado nem
inferir regra nova para aceitos/revogados. Prova futura de reenvio deve distinguir
pedido aceito, link gerado e entrega efetiva pelo provedor; usar destinatário
sintético autorizado. Nenhum convite enviado ou reenviado neste registro.

FE: ambos pendentes R12. BE: sem mudança prevista para modo tabela; contrato de
reenvio a conferir, nenhuma falha nova diagnosticada. E2E: ainda não executado.
Histórico/certificados permanecem, sem ganho de percentual por documentação.

Integrador central deve incorporar R12-44/45, rebasear notas de invites.list e
invites.resend e aplicar via apply-tracker-delta.cjs, sincronizando três MDs e
manifesto. Integração central pendente; WIP R11 preservado. Ao entregar a UI,
atualizar a projeção histórica superadmin-invites-directory para não continuar
apresentando cards como padrão atual. Sem código, runtime, deploy ou abertura R12.

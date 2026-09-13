---
source: R12 C0 — R12-09 child-safety.list diagnostic
status: diagnostic; owner decision pending
generated_at: 2026-09-13
---

# R12-09 — diretório de Segurança da criança

Recorte: Etapa 2 → `apps/superadmin` → Segurança da criança → Diretório →
`child-safety.list`.

O diretório já exibe identificação da criança, ID interno, instituição,
unidade, situação textual no indicador e contagens de autorizações e
solicitações em análise. O modelo disponível não expõe um campo separado de
alerta/restrição além da segmentação de situação; não foi inventada uma
interpretação de retirada segura por cor ou contagem.

O primeiro gate do Owner pede conteúdo operacional adicional com dados reais e
minimizados. Isso exige decisão de produto sobre quais campos e estados são
autoritativos antes de mudar o card ou o contrato. Nenhum código, SQL, RPC,
RLS ou rastreador foi alterado neste diagnóstico.

Próximo gate: Owner aprovar a composição de identificação/contexto, situação,
autorizações vigentes, solicitações pendentes e restrição/alerta; depois
implementar com prova de minimização, estado vazio, responsividade e escopo.

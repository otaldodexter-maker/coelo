---
title: "Forms XLSX — identidade de colunas sem sobrescrita"
source: "Escopo E2E 4 do Owner; reserva local do Coordenador; export_contract.ts"
status: "local-green-not-e2e"
generated_at: "2026-09-07"
---

# Contrato e recorte

Corrigir perda de respostas no gerador puro de `forms.responses.export`.
Incluído: transformação do snapshot e testes dos dois encoders XLSX existentes.
Fora: SQL, worker index/runtime, jobs, autorização remota, gateway, R2 e deploy.
Ordem: reproduzir, corrigir, reabrir XLSX paginado, revisão independente.
Critério local: nenhuma colisão entre identidade, metadados e perguntas distintas;
não equivale a exportação E2E. Estimativa da fatia: 15 minutos.

# Defeito e mudança

O código usava o título como chave de respostas simples. Títulos homônimos
sobrescreviam respostas; `response_id` substituía a identidade real. Metadados
também podiam substituir IDs, e campos multivalor sobrescreviam títulos reservados.

Respostas simples agora usam `Resposta [ID escapado] título`; metadados usam
`Metadado [chave escapada]`. As seis colunas de sistema/expansão permanecem iguais.
O ID está presente sempre, não apenas quando duas respostas coincidem na mesma
página. Escape percentual impede ambiguidade com delimitadores do cabeçalho.

Compatibilidade: os cabeçalhos simples e de metadados mudam. Não há promessa de
compatibilidade com consumidores externos baseados nos nomes antigos. A chave é
estável para o par ID/título: alteração de título cria outra coluna; versões não
são agrupadas silenciosamente. O limite existente de 512 colunas não foi elevado;
preservar respostas antes colapsadas pode revelar esse limite.

# Evidência executada

- Baseline: 10/10 nos módulos export_contract e snapshot_paging.
- RED: três testes falharam, incluindo `answer:response_id` em vez de `r1`.
- GREEN final: 14/14 com `deno test --no-prompt --deny-net export_contract_test.ts snapshot_paging_test.ts`.
- Pipeline adicional: duas páginas esparsas → transformação → encodeXlsx e
  streamXlsx → reabertura; respostas homônimas, metadados e IDs preservados,
  ausência de fórmulas `cell.f`, hyperlink da rota de mídia preservado.
- `deno lint export_contract.ts export_contract_test.ts`: sem problemas.
- Lint ampliado revelou dois `require-await` preexistentes em
  snapshot_paging_test.ts; arquivo não alterado. O novo caso equivalente foi
  corrigido no próprio teste antes do GREEN final.
- Revisão independente read-only: sem bloqueantes no diff; root executou testes.

Os testes legados CSV/ZIP foram preservados como regressão, não habilitam esses
formatos no MVP. Segue autorizado apenas um XLSX por formulário. Nenhum arquivo
real foi enviado ao R2, nenhum SQL executado e nenhuma prova de reautorização ou
expiração remota foi produzida por esta fatia.

# Memória e próximo gate

Restauração da integridade já exigida; nenhuma regra nova de produto foi criada.
Não foi criada projeção de conhecimento apenas para registrar atividade.
Coordenador recebe o delta; rastreadores oficiais permanecem sob sua autoria.
Gate pendente: exportação nominal com autorização, R2 privado, expiração e auditoria.

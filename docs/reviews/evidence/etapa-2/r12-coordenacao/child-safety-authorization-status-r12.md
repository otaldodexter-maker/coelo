---
source: R12 C0 — R12-12 child-safety.child authorization table
status: local-green; visual golden pending
generated_at: 2026-09-13
---

# R12-12 — status e validade das autorizações

Recorte: Etapa 2 → `apps/superadmin` → Segurança da criança → Criança →
Autorizações → Tabela → `child-safety.child`.

A coluna Status da tabela agora é textual e distingue decisão de ciclo de vida:
uma autorização aprovada aparece como `Aprovado · Ativa`, enquanto pendente ou
rejeitada mantém somente sua decisão. A coluna Validade continua mostrando o
período ou `Até revogação`; o indicador compacto permanece reservado aos
cards, sem ser o único canal de informação da tabela.

Prova local, Windows, checkout `dev`:

- `flutter test test/features/safety/presentation/safety_pages_test.dart`:
  19 testes funcionais passam e a regressão textual passa;
- o golden do diretório em 1440px continua falhando com 0,34%/4.857 px,
  diferença documentada em R12-10; nenhum baseline foi regenerado.

Nenhum contrato, SQL, RPC ou RLS foi alterado. O aceite FE é local-green;
reconciliação visual do golden e prova integrada permanecem pendentes.

Próximo gate: revisar a referência visual aprovada e executar rota normal,
reload e escopo autorizado da criança.

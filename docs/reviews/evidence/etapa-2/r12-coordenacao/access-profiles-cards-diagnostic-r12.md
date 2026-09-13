---
source: R12 C0 — R12-11 access profiles cards diagnostic
status: local-green; visual golden pending
generated_at: 2026-09-13
---

# R12-11 — cards de Perfis e permissões

Recorte: Etapa 2 → `apps/superadmin` → Acessos → Perfis e permissões → Cards.

Os cards atuais já organizam os indicadores em composição compacta: situação
no cabeçalho e três métricas abaixo — `Escopo máximo`, `Vínculos` e `Tipo`
(Predefinido/Personalizado). Nome e descrição permanecem na identificação;
ações de duplicação seguem condicionadas ao callback/capacidade. Não foi
inventada métrica adicional nem atribuído action_id ao diretório sem mapeamento.

Prova local, Windows, checkout `dev`:

- `flutter test test/features/access_profiles/presentation/access_profile_pages_test.dart`:
  15 PASS;
- cobertura inclui cards em 375/1440px, text scale 1/2, estados informativos,
  callbacks, troca de repositório, perfis/modelos e estabilidade responsiva.
- a suíte golden relacionada falha com diferenças pequenas e repetidas em
  várias imagens; nenhum baseline foi regenerado.

O item fica aberto apenas para reconciliação visual da referência aprovada e
para mapear o diretório no inventário, sem alterar contrato, SQL, RLS ou
denominador.

Próximo gate: revisar goldens aprovado/failure e confirmar com o Owner se a
composição atual atende ao 2×2 proposto antes de qualquer mudança.

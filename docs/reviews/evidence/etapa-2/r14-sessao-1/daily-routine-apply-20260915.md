---
source: "Sessão 1 da R14 (Opus 5), 15/09/2026; R14-execucao-paralela.md"
status: evidence
generated_at: 2026-09-15
---

# Rotina › Aplicar (`daily-routine.apply`) — rota real, 15/09/2026

Mesmo ambiente de `circulars-attach-20260915.md` (produção, build QA de `r14/bloco-ab`, código de `a3fd542b7` +
esta correção, 127.0.0.1:3014, CDP 9414, sessão `qa-r06-publicacoes`, Owner). Modelo de origem
"Modelo R05 rota real (R06)" (`176882c5`, versão v2 no diretório). Capturas em `capturas/daily-routine-apply-*.png`.

## Defeito encontrado e corrigido (teste vermelho → verde)

Após o reload, os campos "Horário inicial/final (HH:MM)" hidratavam `08:00:00`/`12:00:00` (o servidor devolve
`time` com segundos). Correção mínima em `supabase_routine_repository.dart` (`_clockTime`, só na leitura da
aplicação); teste "a aplicação hidrata horários do servidor no formato HH:MM do formulário" em
`supabase_routine_data_test.dart` — vermelho (`Actual: '08:00:00'`) → 7/7 verde; `flutter analyze` limpo;
reprova no build corrigido (captura 04 mostra `08:00`/`12:00`).

| action_id | Rota normal | CRUD em produção | Reload | Negativa |
|---|---|---|---|---|
| daily-routine.apply | `/daily-routine` › card do modelo › "Criar rotina por este modelo" (01) → `/daily-routine/new?applicationFrom=176882c5…` "Rotina aplicada": Herança (origem/herdado/efetivo), escopo Instituição, validade 2026-09-15 → 2026-12-31, 08:00–12:00, status Rascunho (02) → "Salvar rotina" → snackbar "Rotina aplicada salva." (03). | `superadmin_routine_save_application` → aplicação `b0005226-cede-4bc3-9818-b5d99f0b7134` (`draft`, `scope_kind institution`, `inheritance_mode inherited`, `source_model_version_id 93b19e6a…`, `valid_from/until`, `starts_at 08:00:00`, `ends_at 12:00:00`) relida por `superadmin_routine_directory` (`entry_kind application`, total 2) e `superadmin_routine_application_detail`. | `/daily-routine/b0005226…/edit?kind=application` após carga completa relê validade, horários, escopo e herança (04); aba "Rotinas" do diretório lista a aplicação (05). | `superadmin_routine_save_application` com `institution_id` alheia (`…0099`) → `400 P0001 routine application hierarchy mismatch`; `application_detail` de id inexistente → `P0002 routine application unavailable` (não enumerável). |

## Achado fora do action_id (R15 / contrato)

"Herdado/Efetivo/Modelo vinculado · versão N" muda de **Versão 2** (antes de salvar: `source.version` do
diretório) para **Versão 1** após o reload (`effective_version` do `application_detail`, que é a revisão
efetiva da aplicação, não a versão do modelo). `superadmin_routine_application_detail` não devolve o número
da versão do modelo (só `source_model_version_id`), e `superadmin_routine_model_detail` devolve
`management_version 1` enquanto o diretório mostra "v2". O vínculo persistido (`93b19e6a`) está correto; o
rótulo é ambíguo. Precisa de contrato (expor `source_model_version_number`) antes de ajustar o cliente —
registrado como sobra; nenhuma alteração de rótulo feita por inferência.

---
title: "PERS-LIFECYCLE01 — evidência local"
source: "specs/019-superadmin-people-directory.md"
status: "local-green-not-e2e"
generated_at: "2026-09-07"
---

# Resultado e limite

View model de Pessoas corrigido: uma escrita pendente compartilhada, comando
capturado antes de listeners, listas imutáveis e nenhuma notificação tardia após
dispose. Erros liberam retry e preservam patches; receipts não reidratam nem
sobrescrevem edições posteriores. Save após dispose falha sem repository.

Nenhuma alteração em validação, entidades, adapter, router, permissões, SQL ou
produção. Não prova persistência/reload remoto, tenant A/B, revogação ou E2E.
O escopo integral Estruturas/Pessoas/Locais, incluindo os sete IDs Locais,
permanece aberto. O coordenador é o escritor exclusivo dos rastreadores.

## Provas executadas

- RED correto: 0/9 passaram antes da correção. Create/edit/reentrada enviavam
  duas escritas; dispose mascarava erro original com FlutterError; patches
  mudavam durante a espera e listas draft permitiam substituição por índice.
- GREEN focal: 15/15, sendo nove novos e seis existentes do view model.
- Regressão: 69/69 em oito arquivos — lifecycle, view model, form page, edit
  route, file actions, identity lookup gate, domínio e adapter Supabase.
- Analyzer dos dois Dart alterados: zero issues.
- Validador de contratos visuais: exit 0, nenhuma alteração visual/golden.
- Ambos os gates de conhecimento: PASS. Memória no-op: restauração de
  invariantes locais, sem regra de produto/permissão nova aprovada.
- Review independente read-only (Nash): nenhum bloqueador; sem executar
  Flutter concorrentemente ou alterar arquivos.

Comando de regressão (em `apps/superadmin`, com Flutter configurado no host):

```powershell
flutter test --no-pub test/features/people/presentation/person_form_page_test.dart test/features/people/presentation/person_edit_route_page_test.dart test/features/people/presentation/person_file_actions_test.dart test/features/people/presentation/person_identity_lookup_gate_test.dart test/features/people/domain/person_directory_test.dart test/features/people/data/supabase_person_directory_repository_test.dart test/features/people/presentation/person_form_view_model_test.dart test/features/people/presentation/person_form_save_lifecycle_test.dart --reporter expanded
```

## Pendências preservadas

O callback `onSaved` da página não faz parte deste pacote. A inspeção mostra
que duas invocações de `_save` podem aguardar a mesma escrita e invocar o
callback duas vezes; requer teste/correção próprios na página. Não declarar o
formulário completo com base apenas neste view model.

Também ficam fora: reconciliação de versão/patch após sucesso, integração v2
produtiva, lista/escrita backend, auditoria e prova remota autorizada.

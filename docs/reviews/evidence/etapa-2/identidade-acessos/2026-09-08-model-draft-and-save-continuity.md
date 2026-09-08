---
title: "Modelos — rascunho e conclusão pendente na rota normal"
source: "Continuação nominal do Coordenador após 071cab32; testes de consumidor e router; review account_review"
status: "local-green; remote-and-cache-gates-separate"
generated_at: "2026-09-08"
---

## Recorte sem duplicar provas

Base 071cab32. Testes existentes access_profile_editor_authorization_test
cobrem READ em voo, não save em voo. access_profile_detail_context_test já
cobre confirmação/delete em voo por troca de recurso, com controle positivo;
não foi duplicado. Duplicação normal continua 503, sem ligar rota por inferência.

Ampliados os nove casos de model_command_consumer_test existentes, não criada
outra cópia da matriz sucesso/negação. Resultado completo **9/9 PASS**:

- criação/edição: nome, descrição, razão e versão esperada conferidos no
  payload que chega ao MockClient; request ID nominal presente;
- negação: campos nome/código/descrição/motivo permanecem na UI após voltar
  pelos passos; duplicação mantém nome e motivo; callback não é acionado;
- conflito: resposta de referência diferente (nome/descrição remotos e versão
  5 em lugar de 3) não apaga campos testados. Reenvio manual mantém nome,
  descrição e razão, usa expected_version 5 e novo request ID. Antes do
  reenvio não há sucesso; depois do controle positivo há exatamente um.

Não se afirma preservação de todas as seleções/capabilities, nem que Código
seja enviado no draft Models: a interface compartilhada o exibe, mas o contrato
de Modelos usa seus campos próprios. Nenhuma mudança produtiva nesta fatia.

## Save em voo na composição normal

Novo app/router/model_save_completion_routes_test.dart: **6/6 PASS**, exit0.
Create/update × contexto inalterado/troca de rota/troca de sessão sintética.
Teste usa submit por interação real com campos/botão, router e adapter reais,
Supabase repository com MockClient. Resposta de sucesso A capturada e retida
antes de entrar em B; somente então liberada.

- Controle positivo: sem troca, conclusão navega para /profile-models.
- Troca de rota: editor B permanece aberto e visível após completion A.
- Troca de sessão: mesma URI, widget B permanece com estado novo; resposta A
  não causa navegação de sucesso nem restaura rascunho A.
- Em cada caso houve apenas um comando. Nenhum router produtivo foi alterado.

Esses testes não provam cancelamento de comando já enviado, revogação no
servidor, persistência, login real ou ausência de cache auxiliar stale após
write. A última é pendência separada sob investigação estática do adapter.
Troca de sessão é injetada no SuperadminSession, não realizada no provedor.

## Verificação e repasse

Comandos via RTK, cwd apps/superadmin:
`flutter test --no-pub test/features/access_profiles/presentation/model_command_consumer_test.dart`
e `flutter test --no-pub test/app/router/model_save_completion_routes_test.dart`.
Rodadas separadas, não somar com 57 ou 169 anteriores como nova suite conjunta.
Analyzer focal dos dois testes, após remover assert não-nulo redundante;
review account_review sem bloqueantes, validando limites e controles positivos.

Plano atualizado no turno. Perfis/Conta/SQL/runtime mantêm gates nominais.
Sem alteração em backend, grants, import/export ou mídia. Gate de memória
no-op: provas adicionais de comportamento existente, sem decisão de produto.

---
title: "Formulários — rascunho incompleto de Enquete rápida"
source: "docs/superpowers/specs/2026-08-13-superadmin-forms-end-to-end-design.md:29-33; docs/knowledge/team/superadmin-forms-production.md; testes locais E2E4"
status: "local-verified-backend-pending"
generated_at: "2026-09-07"
---

# Recorte

Corrigir somente o bloqueio de completude no salvamento de rascunho do editor
Superadmin. A fonte aprovada permite rascunhos incompletos de Enquete rápida e
concentra as exigências de intenção/pergunta no pré-publish e RPC de publicação.
Root writer; revisão independente read-only. Sem SQL, deploy, acesso remoto,
alteração do validator compartilhado ou política de autorização.

# Correção e prova

`_saveDraft` ignora somente `quickPollIntentRequired`,
`quickPollIntentTooLong` e `quickPollRequiresOneQuestion`. Título, limites,
identificadores, posições, fontes de condições e ciclos continuam bloqueantes.
`_openPublishDialog` permanece com validação integral.

RED observado: seis casos não chamavam `saveDraft` (lista de comandos vazia):
intenção nula, em branco, com 281 caracteres, zero perguntas, somente informação
e duas perguntas. Dois controles estruturais já passavam. Saída final: 2 passam,
6 falham, exit 1. Após correção, os oito passaram, exit 0.

Dez novos testes no total também comprovam rejeição da API sem mensagem de
sucesso, preservação da edição local e baseline confirmada de descarte, além do
fluxo de confirmação de publicação para enquete completa.

Verificações finais:

- Suíte de contexto do editor: 59/59, exit 0.
- Regressão conjunta das sete suítes de editor, resposta, DEV, lifecycle e API:
  137/137, exit 0.
- `flutter analyze --no-pub` dos dois arquivos alterados: sem problemas, exit 0.
- Validator de contratos visuais administrativos: exit 0.
- Formatação aplicada e revisão independente aprovada no recorte.

Goldens conhecidos continuam abertos; não foram atualizados ou reclassificados.

# Pendência de backend e limite da conclusão

A cadeia legada contradiz a regra de rascunho incompleto: `form_save_draft` em
`20260813155121_forms_commands_and_projections.sql` chama
`form_replace_working_definition`, que chama o validador completo; este impõe as
exigências de quick poll em
`20260813155005_forms_definition_and_capabilities.sql:293-304`.
Nenhuma dessas migrations foi alterada. A correção Flutter permite solicitar o
salvamento e tratar uma rejeição honesta; não prova persistência produtiva.
O delta é enviado ao Coordenador para a cadeia nominal, sem alterar os trackers
centrais nesta branch.

Gate de memória: nenhuma decisão nova; restauração de comportamento já aprovado.
Não foi criada projeção de conhecimento adicional para registrar atividade.
Imagens, locais, respostas, XLSX/R2 e cuidado/medicação seguem no escopo original;
esta fatia não conclui a vertical E2E.

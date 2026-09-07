---
title: "Editor — isolamento de contexto e diálogos locais"
source: "FormsEditorPage; testes locais; revisão read-only independente"
status: "local-green-partial"
generated_at: "2026-09-07"
---

# Recorte e limites

Superadmin, Editor, `forms.create`, `forms.edit`, `forms.publish`. Somente
lifecycle Flutter: impedir que contextos, carregamentos, recibos e diálogos
obsoletos alterem a nova identidade API/formId/modo. Backend, router, autoria,
idempotência de comandos e descarte produtivo ficam fora desta correção.
Nenhum SQL, RPC real, R2, Worker ou acesso remoto foi executado neste pacote.

## Implementação

- Geração invalidada na troca de identidade e dispose; dados, permissões,
  seleção, preview e controles da origem anterior são limpos imediatamente.
- Checagem entre getEditorContext e getEditor evita consulta obsoleta; recibos,
  erros e finally de save/publish não afetam busy/definição da nova origem.
- Rebuild de identidade igual preserva edições não salvas.
- Sete diálogos pertencem explicitamente ao editor e são removidos sem fechar
  rotas externas. Guardas também cobrem o intervalo anterior ao primeiro build.
- Catálogo protege callbacks obsoletos; mover pergunta usa labels capturados.
- DialogRoute captura o tema local, preservando comportamento de showDialog.

## Verificação

REDs de lifecycle e tema registrados durante o desenvolvimento. Após restaurar
o patch da comparação de baseline, execução final:

```text
flutter test --no-pub test/features/forms/presentation/editor/forms_editor_context_isolation_test.dart test/features/forms/presentation/editor/forms_editor_page_test.dart
42/42 passaram; exit 0

flutter analyze --no-pub lib/features/forms/presentation/editor/forms_editor_page.dart test/features/forms/presentation/editor/forms_editor_context_isolation_test.dart
2 arquivos; No issues found; exit 0
```

Validador visual administrativo executado localmente com exit 0. Revisão
independente read-only aprovada, incluindo tema, modal renderizado, rota externa,
dispose e busy concorrente. A revisão não certifica backend ou E2E.

## Goldens — pendência preexistente preservada

`forms_editor_golden_test.dart`: 2 testes passaram e 2 falharam, com cinco
diferenças de imagens. A comparação foi repetida após reverter temporariamente
somente o patch próprio do editor via apply_patch; diff desse arquivo vazio
contra HEAD `8e336868967a29552689d0f6174c5c0f4590edd1`. Mesmos resultados e
quantidades abaixo; patch restaurado e testes comportamentais repetidos.

| Imagem | Pixels diferentes | Percentual da imagem |
| --- | ---: | ---: |
| forms_editor_light_375 | 140039 | 41,49% |
| forms_editor_dark_375 | 153920 | 45,61% |
| forms_editor_light_768 | 79979 | 11,57% |
| forms_editor_dark_768 | 92341 | 13,36% |
| forms_editor_light_375_text_200 | 108064 | 28,82% |

Os grupos de catálogo/date range/preview e legibilidade compacta passaram nas
duas execuções. Nenhum golden foi atualizado. Isso isola a regressão visual do
patch; não declara o visual geral aprovado.

## Estado e próximo gate

Cliente: local-green parcial. Backend e E2E: não comprovados por esta fatia.
Descarte produtivo ainda restaura fixture e será tratado em pacote separado com
RED. Nenhuma promoção de action_id para verified/done/verified-e2e.

Coelo Knowledge: no-op; preservação do isolamento já exigido, sem nova decisão
de produto ou projeção de atividade. Deltas oficiais enviados ao Coordenador.

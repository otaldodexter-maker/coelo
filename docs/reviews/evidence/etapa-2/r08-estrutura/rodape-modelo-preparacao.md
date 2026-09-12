---
source: "R08-plano.md; R07-decisoes-owner-20260912.md; C0 R08"
status: "implementation-ready; verification-pending-global-slot"
generated_at: "2026-09-12"
---

# Criar modelo de atividade — rodapé canônico

## Recorte

Etapa 2 → apps/superadmin → Estrutura → Atividades → Criar modelo.

O fluxo deixou o `Wrap` local e usa `SuperadminFormActionFooter` ancorado no
`bottomNavigationBar` do `Scaffold`: Cancelar permanece terciária, Anterior é
exibida a partir da segunda etapa e Continuar/Criar modelo permanece primária.

## Prova preparada

`activity_directory_page_test.dart` agora exige
`activity-template-create-footer` e `SuperadminFormActionFooter` ao abrir o
assistente. A execução RED/GREEN está pendente da posse global de `flutter
test`, reservada por C0 para G1 após o slot de G3. Não há promoção de estado,
delta de rastreador ou alegação E2E neste pacote.

## Limites

Sem alteração em `superadmin_form_frame.dart` (G3), SQL, Chrome, rastreadores
ou inventário. O gate de memória é no-op: a decisão durável já consta nas
fontes aprovadas.

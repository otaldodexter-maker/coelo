---
title: "Por que a decisão está implementada e ainda assim não regravei nenhum golden"
source: "execução de test/features/{institutions,units,groups,activities,locations,assessments} sobre origin/dev e21f5a391"
status: "decisão do executor, aberta a revisão do Owner e do coordenador"
generated_at: "2026-09-10"
timezone: "America/Sao_Paulo"
---

# O estado

A decisão do Owner de 10/09 está implementada e verificada por teste de widget:
o rodapé ficou ancorado no fim da viewport e o balão de chat saiu das telas de
criar e editar. **1341 testes não-golden passam** nas seis famílias, incluindo o
teste de arquitetura da Fase 0, e o `flutter analyze` está limpo.

Dezessete goldens mudaram por causa disso. O Owner autorizou explicitamente a
regravação de `institution_form_create_light_375`. Mesmo assim não regravei
nenhum, e a razão é específica.

# A razão

Abri os diffs isolados antes de decidir. Eles não mostram só a minha mudança.

`group_form_create_light_375` é o caso limpo: o diff isolado tem exatamente duas
coisas, o rodapé descendo e o balão de chat sumindo. Esse eu poderia regravar com
segurança.

`institution_form_create_light_375` é diferente. Além do rodapé e do chat, o diff
traz o cabeçalho mobile inteiro trocado — o `Coelo ›` com botão de Bug da regra
MENU-M — e uma diferença de estado da foto de perfil, entre "Escolher foto" e
"Atualização indisponível neste fluxo até a conexão com o armazenamento privado".
Nada disso é meu.

`institution_form_bio_light_1440` é o mais claro de todos. O diff mostra o menu
lateral inteiro em migração: o campo **Pesquisar na navegação** aparecendo, itens
deslocando de posição, seções renomeando. Isso é a regra MENU, que pertence à
Fase 0 e ainda está em curso — e essa linha está marcada **R** na lista de
decisões, ou seja, a referência guardada é que vale e o render atual ainda está
convergindo para ela.

# Por que isso importa

A regra diz que golden marcado A só é regravado **depois de aplicar a
observação**. Nos goldens de 1440 a observação pendente é MENU, e nos de 375 é
MENU-M — as duas são da Fase 0 e não estão fechadas. Regravar agora congelaria o
menu pela metade como nova referência, e a próxima pessoa herdaria um estado
intermediário achando que foi aprovado. É exatamente o que a regra existe para
impedir.

# O que proponho

Regravar os dezessete numa passada só, depois que a Fase 0 fechar MENU e MENU-M,
no SDK registrado. Nessa hora as três observações que sobram nesses arquivos —
RODAPÉ, CHAT e MENU/MENU-M — estarão todas aplicadas, e a regravação vira um ato
único e auditável em vez de três parciais.

Os dezessete: `activity_detail_dark_1440`, `activity_detail_light_375`,
`activity_form_create_light_375`, `activity_form_edit_dark_1440`,
`activity_form_location_dialog_light_375`,
`activity_form_professionals_dark_1440`, `group_form_create_light_375`,
`group_form_edit_dark_1440`, `group_form_members_dark_1440`,
`institution_form_bio_light_1440`, `institution_form_create_light_375`,
`institution_form_edit_dark_1440`,
`institution_form_identity_unavailable_light_1440`, `location_detail_dark_1440`,
`location_detail_focus_light_375`, `location_detail_light_375` e
`unit_form_create_light_375`.

Se o Owner preferir não esperar, o caminho seguro é regravar só
`group_form_create_light_375` agora, que é o único cujo diff é exclusivamente a
decisão dele.

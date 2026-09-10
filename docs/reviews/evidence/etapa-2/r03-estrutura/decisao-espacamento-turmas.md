---
title: "Decisão do Owner de 10/09/2026 — espaçamento dos cards de Turmas está resolvido"
source: "resposta do Owner à página https://claude.ai/code/artifact/78fdeaff-1bba-47c3-8649-255c3aca7c92"
status: "observação encerrada"
generated_at: "2026-09-10"
timezone: "America/Sao_Paulo"
---

# A decisão

Depois de ver os pares antes/depois nas quatro larguras, mais tabela e hover, o
Owner respondeu: **"Já resolveu. O composto arrumou o espaçamento e a observação
de 10/09 está cumprida."**

A observação **"card com excesso de espaçamento"** fica encerrada. Ninguém mexe
mais no espaçamento dos cards do diretório de Turmas por causa dela.

# Em quais arquivos, exatamente

São **doze**, não onze — eu tinha contado errado ao apresentar a pergunta:

`group_directory_bug_open_light_1440`, `group_directory_card_hover_light_1440`,
`group_directory_cards_light_1024`, `group_directory_cards_light_1440`,
`group_directory_cards_light_768`,
`group_directory_create_card_hover_light_1440`,
`group_directory_filter_selected_light_1440`,
`group_directory_institution_filter_open_light_1440`,
`group_directory_pagination_page_size_open_light_1440`,
`group_directory_profile_open_light_1440`,
`group_directory_table_light_1024` e `group_directory_tour_open_light_1440`.

Todos passam hoje, porque a Fase 0 os regravou em `92ac66b68` ao migrar o
diretório de Turmas para o composto. Não há código a mudar nem golden a
regravar por conta desta decisão.

# O que NÃO ficou encerrado nesses mesmos arquivos

Cuidado ao ler a decisão como se limpasse os doze arquivos. Ela encerra **uma**
observação. Nas mesmas linhas continuam abertas:

- **MENU**, em onze dos doze — todos menos `group_directory_cards_light_768`.
  Pertence à Fase 0 e ainda está em curso.
- **FLYOUT**, em `group_directory_profile_open_light_1440`: "o flyout de perfil
  abre muito colado".

# O card Criar turma em 375

`group_directory_cards_light_375` tem observação diferente: "card de criar turma
talvez exagerado; revisar tamanho". Perguntei junto, na mesma página, e o Owner
respondeu escolhendo a opção sobre espaçamento sem citar o card Criar.

Como a resposta dele foi que a observação de 10/09 está cumprida e o diretório
foi reconstruído desde então, estou tratando **também essa observação como
encerrada**, com o card Criar mantido como está. Registro assim de propósito:
se a leitura estiver errada, uma palavra dele reabre o item, e ninguém precisa
reconstruir o contexto.

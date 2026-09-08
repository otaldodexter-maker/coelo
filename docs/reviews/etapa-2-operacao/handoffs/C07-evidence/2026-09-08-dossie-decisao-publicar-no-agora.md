---
title: "C07 — dossiê de decisão: Publicar no Agora, e por que os 13 goldens deixam de ser decisão do Owner"
source: "referência visual aprovada pelo Owner em 2026-08-31, lida diretamente em C:/Users/adrie/.codex/generated_images/01a05881-1dac-78d0-afb2-f30c33149c1c/exec-59c8c015-634c-4451-8390-f8652f75190e.png; docs/superpowers/specs/2026-08-28-coelo-visual-completion-stage-design.md item 31, linhas 328-343, status approved-design; specs/036-principal-now-publication-mvp.md; specs/050-principal-ui-ux-closure.md; código em 4af42925; pedido operacional da C06 de 2026-09-08T18:44-03:00"
status: "evidence-decision-dossier"
generated_at: "2026-09-08T19:05:00-03:00"
timezone: "America/Sao_Paulo"
---

# Dossiê — Publicar no Agora

## A pergunta que eu tinha montado, e por que ela estava errada

O laudo apresentou os 13 goldens do Agora como decisão binária do Owner: ratificar `3419a89e`, que
tirou o trilho lateral de etapas, ou restaurar o contrato de 2026-08-31, que o master registra.

**As duas opções estão erradas, e o Owner já decidiu em 2026-08-31.** A referência aprovada existe,
eu a li, e ela não corresponde nem ao master nem ao código de hoje.

## A referência aprovada, verificada por mim

Ela não está no repositório. Está em
`C:/Users/adrie/.codex/generated_images/01a05881-1dac-78d0-afb2-f30c33149c1c/exec-59c8c015-634c-4451-8390-f8652f75190e.png`,
de 2026-08-31 13:29 — a mesma árvore de imagens que o Owner apontou à C05. Abri e conferi.

O elo escrito entre a imagem e a aprovação está em
`docs/superpowers/specs/2026-08-28-coelo-visual-completion-stage-design.md`
(`status: "approved-design"`, `updated_at: 2026-08-31`), item 31, linhas 328-343, literal:

> "Publicar no Agora também foi aprovado visualmente pelo Owner em 2026-08-31: preserva literalmente
> a anatomia comum de Acontece/Momentos, com mídia temporária vertical, texto curto, ferramentas
> próprias, público/contexto, aviso de 24 horas e **preview lateral no desktop**."

E, para Momentos, no mesmo item: "reproduz literalmente o cabeçalho, **`Sua publicação`**, ordem das
seções, largura útil, **preview** e rodapé de Publicar no Acontece".

O que a imagem mostra, nos três tamanhos:

| Elemento | Presente na referência aprovada |
|---|---|
| Título `Publicar no Agora` com voltar, informação e `Cancelar` | sim |
| Seção **`Sua publicação`** com subtítulo "Compartilhe algo que está acontecendo agora com segurança e contexto." | **sim** |
| Mídia vertical com coluna de ferramentas Texto / Música / Cortar / Capa adjacente | sim |
| Texto com contador 35/60 | sim |
| `Público e contexto` com Famílias / Somente responsáveis | sim |
| Aviso "Fica disponível por **24 horas** no Agora" | sim |
| `Agendamento` → Publicar agora; `Opções` → Salvar como rascunho | sim |
| Em 1440, coluna esquerda = **navegação do app Principal** (Início, Acontece, Mensagens, Agenda, Atividades, Comunidade, Arquivos) | sim — **não é trilho de etapas** |
| Em 1440, coluna direita = card **`Prévia da publicação`**, "Assim será exibido no Agora" | **sim** |
| Rodapé: `Cancelar` à esquerda, `Salvar rascunho` e `Publicar agora` à direita | sim |
| Trilho lateral de etapas | **não** |
| Botões `Continuar` / `Anterior` | **não** |
| Barra de progresso segmentada | **não** |

## O veredito, em três partes

1. **`3419a89e` acertou ao remover o trilho lateral e os botões `Continuar`/`Anterior`.** Eles
   entraram em `fa293a6d` (2026-08-27) sem referência visual aprovada. O master, portanto, registra
   uma composição que o Owner não aprovou para o Agora.
2. **`3419a89e` errou em três pontos:** removeu `Sua publicação`, removeu a `Prévia da publicação`
   lateral do desktop e introduziu uma barra de progresso de três segmentos. A referência aprovada
   de 2026-08-31 mantém os dois primeiros e não tem barra nenhuma. Confirmado no código: o arquivo
   `principal_now_publication_page.dart` em `4af42925` tem **zero** ocorrências de "Sua publicação"
   e de "Prévia".
3. **Logo, os 13 goldens não são decisão do Owner e também não viram A.** Nem o master nem o código
   de hoje correspondem ao que foi aprovado. São **defeito com alvo conhecido**.

## O alvo correto, para quem for corrigir

Sem trilho lateral. Sem `Continuar`/`Anterior`. Sem barra de progresso. **Com** `Sua publicação`.
**Com** `Prévia da publicação` lateral no desktop. Rodapé e demais seções como na imagem. Só depois
disso os 13 masters devem ser regerados, e aí a regeneração é consequência da correção, não decisão
visual.

O dono é a C05, e a C00 já autorizou correção no consumidor
`principal_now_publication_page.dart` no item 4 da decisão `R01-VISUAL-1835`. Esse mesmo item pediu
"recuperar o recibo da instrução Owner já relatada e a referência exata do publicador": **a
referência exata é a imagem acima, e o recibo escrito é o item 31 da spec de 2026-08-28.**

## Achado colateral: Acontece e Momentos também divergem

As referências aprovadas de 2026-08-31 para **Publicar em Momentos**
(`exec-c0319a7b-45bd-4665-ba18-f5b436e41b6b.png`, 13:24) e para Publicar no Acontece têm a mesma
anatomia, também **sem trilho de etapas**. Mas o código de hoje ainda passa `navigation:` ao
`PrincipalPublicationFrame` nos dois:

- `principal_happens_publication_page.dart:192`
- `principal_moments_publication_page.dart:192`

Ou seja, o trilho continua nas duas telas que a referência aprovada não mostra com trilho. Não
investiguei os goldens dessas duas famílias, que passam hoje; registro o achado para a C00 decidir se
entra no mesmo lote de correção.

## Conflitos documentais que a C00 precisa resolver na fonte

Esses conflitos são a razão de eu ter classificado como indeterminado antes, e continuam de pé como
problema de documentação, não de pixels:

1. **`docs/knowledge/team/coelo-visual-families.md`** (`status: validated`, 2026-09-08) diz que
   "Publicar mantém compositor, preview e **etapas** próprios". A referência aprovada não tem etapas.
2. **`.agents/skills/coelo-ui/references/principal-visual-surfaces.md`** (`status: active`, mesma
   data, fonte "esclarecimento do Owner em 2026-09-08") manda "preservar essa geometria e as
   **etapas existentes**... não eliminar etapas". Mesma contradição, e é a fonte que eu citei no
   laudo para sustentar o D.
3. **`docs/superpowers/specs/2026-08-20-coelo-happens-publication-design.md`** (`status: approved`)
   diz "No desktop, rail, composer central e prévia lateral reproduzem a anatomia canônica" — frase
   escrita em 2026-08-31, que conflita com o item 31 do **mesmo dia** e com as duas imagens.
4. **`docs/knowledge/team/now-publication-mvp.md`** (`status: validated`) diz que "o preview lateral
   e o rodapé permanecem contidos nessa superfície" — violado por `3419a89e`, que removeu a prévia.
5. **`specs/036-principal-now-publication-mvp.md`** ainda aponta `source:` para a imagem de
   2026-08-20, anterior à aprovação de 2026-08-31. As duas divergem entre si: a de 2026-08-20 tem
   barra de progresso e não tem prévia; a de 2026-08-31 tem `Sua publicação` e prévia. A spec não
   registra a substituição.

A leitura que proponho, e que a C00 decide: as palavras "etapas" e "rail" nessas projeções
descrevem a implementação de `fa293a6d`, não um anexo aprovado. Prosa escrita depois do código não
vira aprovação. Sugiro registrar em `docs/open-questions.md`.

## Governança: referência aprovada fora do controle de versão

O ponto que mais me preocupa, e que extrapola este caso: **a referência visual que decide o desenho
de três telas vive fora do repositório**, numa pasta de imagens geradas na máquina do Owner. Não
está em git, não tem hash registrado em spec, e a spec 036 aponta para um arquivo por nome sem
caminho. Foi por isso que o laudo original não a encontrou e classificou 13 casos como
indeterminados.

Isso não é meu para resolver, mas registro como risco: qualquer pessoa que refizer esta análise sem
saber da pasta chega à mesma conclusão errada que eu cheguei.

## Limites honestos deste dossiê

1. Li **uma** imagem da pasta de 2026-08-31 diretamente e verifiquei as duas citações da spec ao pé
   da letra. As demais imagens daquele dia foram lidas por subagente somente-leitura; a de Momentos
   (13:24) não abri pessoalmente.
2. Da pasta de 2026-08-20, só a imagem citada pela spec 036 foi aberta, pelo subagente. As outras 18
   não foram conferidas.
3. Não corrigi código nem regenerei golden. Não é meu arquivo e não tenho reserva.
4. Não conferi os goldens de Publicar no Acontece e Publicar em Momentos, que passam hoje; o achado
   sobre o `navigation:` nessas duas telas é leitura de código, não medição visual.
5. A comparação entre a imagem e o código foi feita por leitura, não por captura lado a lado. Uma
   captura candidata do estado atual ajudaria a C00 na inspeção nominal, e eu posso produzi-la se
   houver reserva, sem tocar em master.

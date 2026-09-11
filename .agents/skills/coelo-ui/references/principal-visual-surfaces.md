---
source: "specs/050-principal-ui-ux-closure.md; specs/037-principal-circulars.md; esclarecimento do Owner em 2026-09-08"
status: "active"
generated_at: "2026-09-08"
updated_at: "2026-09-09"
---

# Superfícies visuais do Principal

O menu `Coelo (Principal)` descobre telas do Principal hospedadas hoje em
`apps/superadmin`. Elas preservam composição própria. A referência administrativa
de Instituições não substitui os feeds, viewers ou conteúdo dos publicadores.
A spec específica pode aprovar geometria externa compartilhada.
O estilo administrativo do Superadmin será a referência do Admin; o Site terá
composição própria, cuja aprovação deve ser verificada na spec consumidora.

## Descoberta por ação

Os [12 anexos originais preservados](../../../../docs/reviews/evidence/etapa-2/coelo-principal-superadmin/manifest.md)
ligam cada imagem à tela e finalidade, incluindo Publicar no Acontece e Publicar
em Momentos v1/v2. Abrir o item pertinente junto da spec; v2 é a referência final
registrada de Momentos. Capturas de defeito não são baselines aprovadas.

Os caminhos abaixo são relativos à raiz do repositório. Abrir a implementação,
componentes importados, teste comportamental vizinho e golden do estado afetado.
Ler a spec 050 e as fontes da feature antes de reaproveitar outro compositor.

| Superfície | Implementação | Teste visual de entrada |
| --- | --- | --- |
| Acontece | `apps/superadmin/lib/features/principal_happens/presentation/principal_happens_preview_page.dart` | `apps/superadmin/test/features/principal_happens/presentation/principal_happens_preview_golden_test.dart` |
| Agora | `apps/superadmin/lib/features/principal_now/presentation/principal_now_preview_page.dart` | `apps/superadmin/test/features/principal_now/presentation/principal_now_preview_golden_test.dart` |
| Publicar no Acontece | `apps/superadmin/lib/features/principal_happens_publication/presentation/principal_happens_publication_page.dart` | `apps/superadmin/test/features/principal_happens_publication/presentation/principal_happens_publication_golden_test.dart` |
| Publicar no Agora | `apps/superadmin/lib/features/principal_now_publication/presentation/principal_now_publication_page.dart` | `apps/superadmin/test/features/principal_now_publication/presentation/principal_now_publication_golden_test.dart` |

Para Momentos, Para Você, Perfil, Circulares e outras ações, localizar a rota
e sua spec pelo nome. Esta matriz é uma entrada de descoberta, não um inventário
de conclusão nem prova de backend conectado.

## Preservar os contratos aprovados

- Acontece dá protagonismo à mídia e às interações do feed; não receber toolbar,
  status expansível ou anatomia de card de Instituições por compartilhar host.
- Publicar usa o compositor e o preview próprios da ação. A aprovação de
  2026-08-31 em `docs/superpowers/specs/2026-08-20-coelo-happens-publication-design.md`
  compartilha geometria externa, insets e rodapé de Criar/Editar Instituição.
  Preservar essa geometria e as etapas existentes com componentes Principal;
  não converter o conteúdo em cadastro administrativo nem eliminar etapas. Reutilizar `PrincipalPublicationFrame` em
  `apps/superadmin/lib/features/principal_shared/presentation/principal_publication_frame.dart`
  quando atender. Compartilhar campos neutros não impõe a página administrativa.
- Navegação, header, dock e launcher seguem a composição única da spec 050.
  Decisão final do Owner em 09/09/2026: quando hospedados no Superadmin,
  Agora, Momentos e a leitura de Circular preservam o shell/menu no web e no
  mobile. A imersão fica dentro do contêiner; só elementos internos concorrentes
  do Principal podem ser suspensos. Restaurar foco e contexto ao sair. Esta
  regra pertence ao hospedeiro Superadmin, não ao app Principal independente.
- Decisão do Owner em 10/09/2026 sobre os goldens claros
  ([lista](../../../../docs/reviews/evidence/etapa-2/goldens-claro-decisoes-2026-09-10.md)):
  no web do Superadmin, Acontece, Momentos e Perfil mostram shell/menu com o
  conteúdo Principal dentro do contêiner; o botão "mais" do Acontece é laranja
  com "+" branco e mantém o tracejado; Momentos não corta imagem no mobile e
  preenche mais a área preta no desktop; a foto do perfil Principal não pode
  aparecer recortada.
- Decisão do Owner em 10/09/2026: **o botão flutuante de chat não aparece no
  Agora aberto nem no Momentos aberto**, assim como não aparece em telas de
  criar, editar ou publicar (contrato completo em
  [form-layout-contracts](form-layout-contracts.md)). Essas superfícies ocupam a
  tela com mídia e um balão por cima disso atrapalha. Isso não afeta o shell/menu
  preservado pela decisão de 09/09: o que sai é o launcher de chat, não a
  navegação do hospedeiro.
- O viewer do Agora possui contrato imersivo próprio. Cor/contraste e controles
  sobre mídia seguem esse contrato; não aplicar mecanicamente fundo de popup
  administrativo ou o fechamento vermelho do Bug em toda superfície imersiva.
- `coelo_ui_principal` não importa `coelo_ui_admin`. Reutilizar tokens e controles
  neutros de `coelo_ui_core` quando atenderem; não importar telas entre apps.
- Golden existente protege uma referência. Conferir fonte de aprovação e estado;
  `preview`, `/dev` e teste local não comprovam persistência ou autorização remota.

## Site

Consultar `specs/001-site-publico-astro.md` e seu status atual. Ela não permite
deduzir uma identidade visual final do Site a partir de Principal ou Superadmin.
Preservar marca, acessibilidade, isolamento Astro e assets públicos do build/CDN;
o Site não acessa mídia privada. Uma identidade nova precisa de proposta concreta
quando ainda não houver decisão do Owner para ela.


## Família Publicação (decisão do Owner, 11/09/2026 à tarde)

O Owner reprovou os publicadores do Principal renderizados com o assistente
(wizard) administrativo (V-4 Acontece, V-5 Momentos, V-6 Agora do artefato de
aprovações da R05) e definiu que **publicar é uma família visual própria** do
Coelo (Principal), distinta do diretório administrativo e do wizard de
formulários. Ela vale para **Agora, Acontece, Momentos, Circulares, Eventos da
Agenda e Lançar faltas** (lançar chamada também é uma publicação). As quatro
referências que ele enviou (Agora, Acontece, dois estudos de Momentos) devem
ser guardadas em `docs/reviews/evidence/etapa-2/referencias/publicacao/`
(`agora-publicar.png`, `acontece-publicar.png`, `momentos-publicar-1.png`,
`momentos-publicar-2.png`); até lá esta descrição é a fonte.

Anatomia comum, sobre nossos tokens (fundo branco `neutral0`, texto
`neutral700`, botão primário `orange500` com texto branco, secundário contornado
`neutral200`, notas em `orange50`, cantos `md`/`lg`, Nunito Sans):

- **Cabeçalho:** no mobile, fechar (X) à esquerda, logo `coelo` ao centro e
  ajuda (?) à direita, título "Publicar no/em …" abaixo com uma barra de
  progresso fina laranja quando há etapas; no desktop, cabeçalho global do
  Principal (logo, navegação Início · Agora · Acontece · Momentos · … com a
  aba ativa sublinhada em laranja, sino, avatar) e título com seta de voltar.
- **Mídia primeiro:** a mídia (vídeo vertical no Agora e Momentos, carrossel
  de fotos `1/6` no Acontece) é o maior elemento; miniaturas em fila com
  duração, `+` para adicionar e `Editar capa` sobre a imagem. Vídeo tem um
  trilho vertical de ferramentas em círculos contornados: **Texto, Música,
  Cortar, Capa** (ícones de linha, rótulo abaixo).
- **Blocos em cards contornados** (`neutral200`, raio 12), na ordem:
  **Legenda** (campo com contador, ex. 0/60 no Agora, 0/220 em Momentos,
  0/2.200 no Acontece, emoji no canto) → **Público e contexto** (ícone de
  pessoas laranja, linhas Instituição › Unidade › Turma › audiência, chevron;
  chips de audiência Famílias · Alunos · Equipe escolar · Somente
  responsáveis, a ativa em `orange50` com borda laranja) → **Agendamento**
  (calendário; "Publicar agora ▾" ou toggle "Agendar publicação") →
  **Opções** ("Salvar como rascunho" com toggle) → **nota** em `orange50`
  quando houver regra (Agora: "Stories ficam disponíveis por 24 horas";
  Momentos: "Somente pessoas do contexto selecionado poderão ver").
- **Prévia:** no desktop, coluna à direita "Prévia do post/momento" com o card
  como aparecerá no feed (avatar `CO`, contexto, texto, mídia, curtidas e
  comentários) e a nota "A prévia é uma simulação…"; no mobile a prévia não
  aparece.
- **Rodapé:** mobile com ação primária cheia (`Publicar agora` / `Publicar no
  Acontece`, ícone de enviar) e secundária contornada abaixo (`Salvar
  rascunho`); desktop com as duas à direita, secundária à esquerda da
  primária (cancelar/rascunho à esquerda, publicar à direita).
- **Sem fundo cinza, sem wizard de etapas administrativo, sem balão de chat.**

Aplicações por tela (telas novas propostas no canvas "Publicar no Coelo",
para o Owner aprovar):

- **Agora:** vídeo 9:16 com duração, trilho Texto/Música/Cortar/Capa, legenda
  0/60, público, agendar (toggle), nota das 24 horas.
- **Acontece:** carrossel `1/6`, legenda 0/2.200 com hashtag laranja, público
  + chips, agendamento "Publicar agora ▾", opções, prévia do post.
- **Momentos:** vídeo com trilho, "Capa do momento" (miniaturas, a escolhida
  com contorno laranja), legenda 0/220, público + chips, agendar, nota de
  contexto, prévia vertical.
- **Circulares:** título, texto (0/4.000), anexos até 4 (PDF/imagem), público
  + chips, "Resposta esperada" (Só leitura · Confirmar ciência · Aceitar/
  recusar), agendamento, opções, prévia da circular com o botão que a família
  verá.
- **Eventos (Agenda):** título, data e horário em dois cards, local (catálogo
  de Locais), descrição, categoria (Evento · Prova · Aniversário · Reunião),
  público + chips, lembrete, agendamento; prévia como card do calendário.
- **Lançar faltas (Assiduidade):** card de turma e data, lista de alunos com
  segmentos P/F/A (presente verde `forest`, falta laranja, atraso âmbar),
  observação por aluno, "Marcar todos presentes", observação da chamada,
  nota de que as famílias com falta recebem aviso no sino, rodapé
  "Concluir chamada" (primária) e "Salvar e continuar depois"; no desktop,
  coluna de resumo (presentes/faltas/atrasos).

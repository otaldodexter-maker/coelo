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

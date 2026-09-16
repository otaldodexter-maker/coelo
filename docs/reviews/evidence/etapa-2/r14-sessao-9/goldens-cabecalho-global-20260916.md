---
source: "Sessão 9 da R14 (Opus 5), 16/09/2026; ADR 0041 C1; golden-failure-triage.md §4; diagnósticos R12 (daily-routine-golden-diagnostic-r12.md, child-safety-table-golden-diagnostic-r12.md)"
status: evidence
generated_at: 2026-09-16
---

# Goldens de Segurança da criança, Perfis de acesso e Rotina diária — deriva do cabeçalho global (ADR 0041 C1), 16/09/2026

Trabalho **local** (worktree `r14/visual-arquivar`, base `dev` `e6b8d6f63`); nenhuma rota real, nenhuma
escrita em produção (incidente PostgREST 504 em curso). Comandos em `apps/superadmin` com
`C:\src\flutter\bin\flutter.bat`. Medição por `docs/reviews/evidence/etapa-2/formularios-cuidado/measure-golden-divergence.py`
(decodificador de PNG) estendida com caixa delimitadora e fração no topo (script de sessão, não versionado).

## (a) Medição antes de qualquer alteração — o diff está só no cabeçalho

| Suíte | Golden | Falha | Caixa da diferença (x, y) | Linhas/colunas atingidas | No topo (≤72 px) |
|---|---|---|---|---|---|
| safety_pages_test | child_safety_directory_light_1440 | 0,34 %, 4.857 px | x 1060–1372, y 38–81 | 44/1000, 247/1440 | 93 % (o resto é a sombra do bloco até y 81) |
| daily_routine_golden_test | directory_cards/table/card_hover/read_only 1440 | 0,21 %, 3.058 px | x 1147–1371, y 38–73 | 36/1000, 196/1440 | 98 % |
| daily_routine_golden_test | form_edit_dark_1440 | 3.068 px | x 1147–1371, y 38–73 | idem | 98 % |
| daily_routine_golden_test | scope/fields 1024; form_create/identity_error 375 | 194 px | 26×14 px no canto superior direito (x 953–978 em 1024; x 308–333 em 375) | 14 linhas | 100 % |
| access_profile_golden_test | table_* (8 variantes) | 194 px (≤1024) / 3.058–3.068 px (1440) | mesmas caixas acima | idem | 98–100 % |
| access_profile_golden_test | cards_* (8), domain_tab_hover, editor, form, review | 6.274 – 68.699 px | y 27–858, colunas 62–91 % | — | 0,7–29 % |

Conclusão da medição: nas 22 variantes de Segurança, Rotina e tabela de Perfis a diferença é **um único bloco no
canto superior direito** (o mesmo `x`/`y` em telas diferentes), assinatura §4 da triagem. As 13 variantes de
cards/editor/formulário/revisão de Perfis têm **duas causas**: o mesmo bloco do cabeçalho **mais** mudança de conteúdo
(ver §d).

Recortes (sem PII; a identidade é o fixture sintético "Owner Coelo"): `capturas/header-rotina-1440-referencia-antiga.png`
(referência gravada em 10–11/09: avatar `OC` + "Owner Coelo / Superadmin"), `capturas/header-rotina-1440-antes-sem-escopo.png`
(renderização de teste antes desta fatia: avatar `–` + "Conta / Superadmin", ícones deslocados),
`capturas/header-seguranca-1440-*.png` (mesma dupla; a suíte de Segurança não carrega fontes, por isso caixas Ahem).

## (b) Causa observada no código

`apps/superadmin/lib/app/shell/superadmin_shell.dart`, `_ProfileSummary.build`:

```dart
child: profile?.avatarImage == null
    ? Text(profile?.initials.isNotEmpty == true ? profile!.initials : '–')
    : null,
...
Text(profile?.name ?? 'Conta', style: theme.textTheme.labelLarge),
Text(profile?.role ?? 'Superadmin', style: theme.textTheme.bodySmall),
```

`profile` é `SuperadminHeaderProfile? headerProfile`, introduzido pelo commit `3945394f3` (13/09/2026,
"fix(account): show session identity in shell"), que substituiu `const CircleAvatar(child: Text('OC'))` e
`Text('Owner Coelo')` estáticos pelo perfil da sessão. Em produção o host persistente
(`superadmin_router.dart`, `SuperadminShell.host(headerProfile: …)`) resolve o perfil de `headerController`;
sem sessão o valor é `null`. As páginas dos goldens são montadas **sem host** (`MaterialApp(home: Page(...))`),
logo o cabeçalho renderiza o placeholder `–`/`Conta`. Como o bloco de identidade tem largura natural (texto) e a
`Row` é ancorada à direita, a troca "Owner Coelo" → "Conta" também desloca o sino e o botão de Bug: é exatamente o
bloco de 224×36 px medido em 1440 e o glifo de 26×14 px (iniciais `OC` → `–`) em ≤1024. As referências foram
gravadas em 10–11/09 (`bbc562c6f`, `d26a9f65c`, `c227e531f`, `fa404db39`), antes de `3945394f3`.

Não é fonte/emoji, avatar assíncrono, ícone sem tamanho nem `MediaQuery`: é **identidade dependente de sessão sem
fonte determinística em teste**.

## (c) Estabilização (coelo-ui; desenho aprovado preservado)

- `SuperadminHeaderProfile.preview()` (const): a identidade determinística do preview `/dev` e das referências
  aprovadas (`Owner Coelo` / `Superadmin` / `OC` / `CoeloPalette.orange50`).
- `SuperadminHeaderProfileScope` (InheritedWidget público): terceira fonte de perfil para shells sem parâmetro e sem
  host. Ordem de resolução: `headerProfile` do shell → host persistente → escopo → placeholder `–`/`Conta`.
  Produção não muda (o host continua resolvendo a sessão; sem sessão, o placeholder).
- `test/support/golden_header_profile.dart` (`withGoldenHeaderProfile`) aplicado nos harnesses das três suítes
  (`_app`/`_directoryApp`/`_formApp`).
- Testes de contrato em `test/app/shell/superadmin_shell_header_profile_test.dart`: placeholder sem fonte, escopo
  resolve o preview, parâmetro explícito e host vencem o escopo. `superadmin_shell_test.dart` +
  `superadmin_shell_header_profile_test.dart`: 72/72.

Medição **depois** do escopo e **antes** de regravar: a caixa da diferença encolheu para o avatar (26×14 px do glifo
`OC` em claro; 36×36 px do círculo em escuro) — ícones, nome e papel voltaram à posição da referência. O resíduo é a
cor do avatar: a referência antiga usava as cores padrão do tema (`primaryContainer`), o contrato atual
(`3945394f3`, r12-46) pinta o fundo com a cor escolhida na Conta e calcula o contraste do texto
(`capturas/header-rotina-1440-escuro-referencia-antiga-vs-nova.png`).

## (d) Regravação (autorizada pela ADR 0041 C1) e resultado

`flutter test --update-goldens` restrito a `safety_pages_test.dart`, `daily_routine_golden_test.dart` e
`access_profile_golden_test.dart`; depois `flutter test` nos mesmos arquivos: **+30 ~4, All tests passed** (os 4
skips são pré-existentes e não regravam).

30 referências regravadas:

- `test/features/safety/presentation/goldens/child_safety_directory_light_1440.png` — só cabeçalho.
- `test/features/daily_routine/goldens/` (9): directory_cards/table/card_hover_light_1440, read_only_light_1440,
  form_edit_dark_1440, scope/fields_light_1024, form_create/identity_error_light_375 — só cabeçalho.
- `test/features/access_profiles/presentation/goldens/` (20): table_{light,dark}_{375,768,1024,1440} (8) — só
  cabeçalho; cards_{light,dark}_{375,768,1024,1440} (8) e domain_tab_hover_light_1440 — cabeçalho **+** cards em
  grade com Status/Escopo máximo/Vínculos/Tipo (`420045445`, 13/09; composição **aprovada como está** pela ADR 0041
  C2, `owner.r12-11` done; `capturas/perfis-cards-1440-referencia-antiga.png` vs `-nova.png`);
  form_light_375, editor_dark_1440, review_dark_1440 — cabeçalho **+** formulário sem campo Código (`f51cd1f1c`,
  r12-22 verified-e2e na rota real em 16/09), revisão/matriz com módulo › tela › ação e tooltip de sensibilidade
  (`4b74dc67f`, `e8820264a`, `ccd286970`, `af78baaa8`; r12-24/25/27 vistos na rota real pela Sessão 5).

Nenhuma dessas mudanças de conteúdo foi introduzida nesta fatia; todas estão em commits integrados em `dev` com
evidência própria. A referência nova de `daily_routine_directory_cards_light_1440` **ainda contém o defeito** de
`owner.r12-01` (alturas desiguais, sem "Efetivo: —", sem Arquivar) — é regravada de novo na fatia 2.

## (e) Demais suítes de golden do superadmin — falhavam antes, por causas pré-existentes; não regravadas

`flutter test` nas outras 46 suítes `*golden*_test.dart`: 34 arquivos com 391 goldens reprovados
(`goldens-outras-suites-preexistentes-20260916.tsv`, uma linha por golden com magnitude). Distribuição: 144 × 194 px,
59 × 3.058 px, 44 × 3.068 px, 2 × 3.055 px (assinatura idêntica do cabeçalho: Atividades, Turmas, Pessoas,
Cuidado, Cardápios, Instituições, Unidades, Convites, Auditoria, Formulários, Circulares, Agenda, Assiduidade,
Planos, Usuários internos, Importação, Suporte, Ajuda, detalhes de Pessoa/Estrutura, Conta); 24 × 224 px
(`principal_for_you`/`principal_profile`, cabeçalho do Principal); o restante são as causas já classificadas na
triagem (`principal_happens` geometria 42–55 %, `circular_composer` 11–27 %, `forms_editor` 3–7 %, etc.).

Prova de que a fatia não as alterou: com o `superadmin_shell.dart` **da base** (`git checkout --` temporário; diff
guardado e reaplicado com `git apply`), as suítes `group_golden_test`, `plan_golden_test`,
`principal_for_you_preview_golden_test` e `meal_plan_pages_golden_test` reprovam exatamente os mesmos 68 goldens
com as mesmas magnitudes (`diff` das duas listas vazio). O escopo só atua onde o harness o injeta.

Sobra sugerida: aplicar `withGoldenHeaderProfile` às demais suítes administrativas e regravar as que ficarem só com a
assinatura do cabeçalho — exige a mesma autorização do Owner (C1 cobre nominalmente três famílias).

## Owner items

- `owner.r12-10` (`child-safety.list`): golden local verde após estabilização + regravação → linha atualizada como
  `partial / FE local-green …`; a revisão da tabela contra a Table canônica e a rota real continuam pendentes.
- `owner.r12-11`: já `done` (ADR 0041 C2); goldens de cards regravados aqui, sem alterar a linha.
- `owner.r12-01`: golden de Rotina só conta após a fatia 2 (C3).

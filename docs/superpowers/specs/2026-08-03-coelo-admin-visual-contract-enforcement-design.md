---
source: "Aprovação do Owner Coelo em 2026-08-03; docs/design/design-system.md; .agents/skills/coelo-ui/SKILL.md; .agents/skills/coelo-ui/references/approved-superadmin-visual-baselines.md; tela de Instituições do Superadmin"
status: "approved"
generated_at: "2026-08-03"
---

# Enforcement dos contratos visuais administrativos Coelo

## Objetivo

Impedir que novas telas administrativas sejam entregues com hover Material
cinza ou retangular, cards interativos divergentes, flyouts fora do padrão,
ações negativas sem vermelho semântico ou composições que ignorem a tela de
Instituições como baseline aprovada.

O resultado deve deixar de depender apenas da leitura da skill. O padrão passa
a existir simultaneamente como componente reutilizável, exemplo real no
catálogo, teste de interação e validador bloqueante.

## Problema confirmado

- Instituições implementa corretamente card hover e flyouts, mas parte dessa
  implementação está privada na própria feature.
- Telas novas conseguem usar `Card` com `InkWell`, `PopupMenuButton`,
  `PopupMenuItem` ou `MenuItemButton` local e herdar o estado Material padrão.
- Os testes de novas telas podem validar apenas texto, permissão e navegação,
  sem exercitar hover, foco ou flyout aberto.
- O índice usa correspondência de todos os termos; consultas naturais mais
  amplas podem retornar zero mesmo quando os padrões existem.
- O catálogo de baselines aponta para goldens, mas ainda não oferece todos os
  componentes reais necessários para reutilização.

## Decisão

Adotar componentes canônicos mais enforcement bloqueante. Documentação ou tema
global isoladamente não atendem, pois não distinguem item discreto, linha
contínua, card interativo, toggle e ação negativa.

## Escopo

### Componentes canônicos

Criar no pacote administrativo compartilhado:

1. card administrativo interativo com:
   - `surface` preservada no repouso e hover;
   - `CoeloRadius.lg` em superfície, material e interação;
   - overlay transparente;
   - borda primária translúcida e sombra primária sutil no hover/foco;
   - teclado, semântica, reduced motion e alvo adequados;
2. flyout administrativo com:
   - `surface`, tint transparente, `CoeloRadius.lg`, borda, elevação e
     `space2` de padding;
   - alinhamento e offset configuráveis sem permitir redefinir a aparência;
3. item de flyout nas variantes:
   - padrão: `primaryContainer`/`primary` no hover e foco;
   - selecionado: mesma hierarquia primária, com texto que comunica seleção;
   - negativo: `error` em repouso e `errorContainer` no hover/foco;
   - divisor para iniciar grupo terminal ou destrutivo.

Esses componentes não incorporam domínio de Instituições e poderão ser usados
por Admin e Superadmin. As APIs expõem conteúdo, callbacks, chaves e semântica;
cores, raio, tint, overlay e elevação permanecem controlados pelo Design System.

### Correções imediatas

- Rotina diária deve substituir o `Card + InkWell` cru pelo card canônico.
- Assiduidade deve substituir `PopupMenuButton` e `PopupMenuItem` pelo flyout
  canônico.
- Ocorrências equivalentes em features administrativas serão auditadas. Cada
  ocorrência deve ser migrada ou registrada em allowlist com justificativa
  específica e teste próprio.
- Instituições passa a consumir os componentes canônicos quando a migração não
  alterar sua baseline visual aprovada.

### Validador bloqueante

Criar um validador determinístico, coberto por testes, que examine código de
features administrativas e produza diagnóstico com arquivo, linha, widget
proibido e substituição esperada.

O validador reprova novas ocorrências de:

- `PopupMenuButton` e `PopupMenuItem` em superfícies administrativas;
- `MenuAnchor` ou `MenuItemButton` local fora dos componentes canônicos;
- `InkWell` usado como card interativo fora do componente canônico;
- allowlist sem justificativa textual ou apontando para arquivo inexistente.

A allowlist cobre somente legado ou exceção tecnicamente comprovada. Ela não é
um caminho para aprovar visual alternativo. Novos itens exigem atualização
explícita do contrato e teste visual correspondente.

O comando do validador será obrigatório na skill, na documentação de
contribuição e no gate de CI disponível no repositório. Falha retorna código de
saída diferente de zero.

### Descoberta e skill

- O índice manterá correspondência exata quando houver resultado e aplicará
  fallback ranqueado por quantidade de termos quando a consulta exata retornar
  zero.
- Consultas combinando hover, cinza, reto, flyout, card e Instituições devem
  recuperar os contratos administrativos relevantes.
- A skill `coelo-ui` ganhará um gate de entrega positivo e curto:
  usar componente canônico, executar o validador, exercitar os estados usados e
  comparar com o golden indicado.
- A skill deve declarar como bloqueio: widget Material cru, teste sem estado de
  interação e entrega de localhost sem executar o gate visual proporcional.

### Catálogo e Design System

- O catálogo renderizará os componentes reais de card e flyout em light/dark,
  default, hover, foco, selecionado e negativo.
- A baseline explicativa continuará como índice visual, mas apontará para os
  exemplos executáveis.
- O Design System registrará os componentes obrigatórios, widgets proibidos e
  o comando de validação.
- As referências Markdown e a memória de conhecimento serão atualizadas depois
  da fonte canônica.

## Fora de escopo

- Alterar regras de domínio, permissões ou persistência das features corrigidas.
- Redesenhar telas que já seguem as baselines aprovadas.
- Criar um hover universal para todas as famílias de superfície.
- Proibir `InkWell` em componentes básicos que não representam cards
  administrativos; o validador atua no escopo e contexto documentados.
- Atualizar goldens automaticamente para acomodar regressões.

## Testes e verificação

### RED-GREEN obrigatório

1. testes dos componentes falham antes da implementação por ausência da API;
2. fixtures do validador demonstram cada violação e uma composição válida;
3. consulta natural combinada falha antes do fallback do índice;
4. testes das telas atuais demonstram o widget Material cru antes da migração;
5. após a implementação, restaurar temporariamente cada violação confirma que
   o teste ou validador volta a falhar.

### Matriz mínima

- light e dark;
- mouse hover, foco por teclado e toque;
- texto a 200%;
- reduced motion;
- 375, 768, 1024 e 1440 quando a composição responder por breakpoint;
- flyout aberto com item normal, selecionado e negativo;
- card em repouso, hover e foco;
- análise estática, testes dos pacotes, catálogo, Superadmin, índice, validador,
  fronteiras de pacote e gate de memória.

Goldens são atualizados somente depois de confirmar que a mudança corresponde à
baseline aprovada. Arquivos em `failures/` permanecem diagnósticos transitórios.

## Critérios de aceite

- Uma feature administrativa nova não consegue adicionar os widgets proibidos
  sem quebrar o validador.
- Rotina diária não apresenta hover cinza ou retangular no card.
- Assiduidade abre flyout visualmente equivalente ao de Instituições.
- Ações negativas preservam vermelho em repouso e no hover/foco.
- O catálogo demonstra os componentes reais e seus estados.
- A consulta `hover cinza reto flyout instituições card` retorna padrões úteis.
- A skill exige e nomeia o comando bloqueante antes da entrega.
- Nenhuma alteração alheia presente no worktree é sobrescrita ou incluída nos
  commits deste trabalho.

## Riscos e mitigação

- **Falso positivo do validador:** analisar ocorrências sintáticas restritas ao
  escopo administrativo e cobrir exceções legítimas por fixture.
- **API genérica demais:** manter conteúdo e callbacks flexíveis, mas aparência
  fechada; não incluir domínio de Instituições.
- **Migração visual involuntária:** comparar Instituições antes e depois pelos
  testes funcionais e goldens aprovados.
- **Allowlist virar escape permanente:** exigir justificativa, arquivo existente
  e revisão explícita; reportar todos os itens permitidos na saída do gate.
- **Conflito com trabalho não commitado:** editar arquivos pontuais, revisar o
  diff por caminho e criar commits somente com arquivos intencionais.

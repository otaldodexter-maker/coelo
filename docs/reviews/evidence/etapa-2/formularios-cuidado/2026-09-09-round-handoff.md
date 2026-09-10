---
title: "Formulários e Cuidado — entrega da rodada noturna"
source: "branch work/etapa2-noturna-formularios-cuidado; base d784462c1; comunicacao/formularios-cuidado.json"
status: "delivered-local; remote-pending"
generated_at: "2026-09-09"
---

# Recorte e limites

`apps/superadmin`: Formulários (autoria, editor, respostas, arquivos, XLSX),
Saúde e Cuidado e Medicação. Segurança infantil pertence a acessos-pessoas e
ficou de fora. Nenhuma migration foi criada, nenhuma mutação remota foi
executada e nenhum recurso Supabase ou Cloudflare foi tocado.

Base isolada `d784462c1` durante toda a rodada, sem merge de `dev`, para
preservar a comparabilidade das medições.

# O que mudou de comportamento

Oito correções de produto. Todas passaram por teste vermelho antes da correção.

1. **Limites autorados viraram gate real da resposta.** Valor fora da faixa não
   entra no rascunho, não autosalva e retira o estado revisado. Fecha os quatro
   RED numéricos da r48.
2. **Dinheiro passou a ser autorado em minor units.** Era gravado em unidades
   enquanto a resposta é gravada em centavos — e o servidor sempre comparou
   `money_minor_units`. Um máximo de `10,50` virava `10.5`, e o servidor
   recusaria qualquer valor acima de dez centavos.
3. **O autor passou a declarar o máximo de caracteres de texto curto.** O campo
   já era persistido e já era gate ao responder, mas não havia onde declará-lo.
4. **Publicar deixou de falhar em silêncio.** Um formulário que passa na
   validação mas nunca foi salvo não publicava e não explicava.
5. **Dinheiro salvo passou a ser lido em notação civil.** Reabrir mostrava
   `10.5` e `10.0` em vez de `10,50` e `10,00`.
6. **O editor passou a recusar intervalo numérico invertido.** Mínimo acima do
   máximo produzia pergunta que nenhuma resposta satisfaz.
7. **O intervalo de datas autorado passou a valer no seletor.** Ele oferecia
   120 anos para trás e 20 para a frente, ignorando o intervalo, e o servidor
   recusa fora dele. A correção trouxe junto o tratamento de uma resposta
   gravada antes de um intervalo declarado depois, que faria o seletor estourar.
8. **A escala passou a começar onde o servidor aceita.** O cliente oferecia 0 e
   o servidor aceita a partir de 1 quando a pergunta não declara mínimo — o que
   é o caso de toda escala criada neste app.

Mais duas correções fora do fluxo de resposta: o **gateway de backend** passou a
converter falha de transporte em falha declarada, em vez de deixar escapar uma
exceção de plataforma que carrega o endereço e a URI do backend; e os **dois
exemplos de catálogo** de Formulários passaram a descrever o comportamento novo.

# O padrão por trás de cinco delas

Nos casos 1, 2, 3, 7 e 8 a regra existia dos **dois** lados. O que divergia era
a unidade, o padrão ou o limite: minor units contra unidades; code points contra
unidades UTF-16; ausência de limite contra o padrão de 1000 do servidor;
intervalo de datas ignorado; escala começando em 0 contra o padrão de 1.

Em Formulários o servidor sempre validou mais do que o cliente, e cada
divergência virava uma recusa que a pessoa não conseguia explicar. Registrado
em `docs/knowledge/team/forms-answer-limits.md`.

# Sete defeitos encontrados relendo o próprio diff

Depois de entregar, reli linha a linha o código que eu mesmo havia escrito.
Sete defeitos, seis deles meus, **nenhum** pego pela suíte — todos haviam
passado por RED, correção e regressão completa sem aparecer. Estão em
`d4c997375`. O argumento prático: suíte verde não substitui reler o diff.

# O que NÃO fecha, e por quê

- `forms.test` e `forms.respond`: as páginas existem e estão provadas, mas as
  rotas produtivas montam `const FormsTestPage()` e `const FormResponsePage()`
  sem api. `forms_fail_closed_routes_test` declara essas rotas como superfícies
  que não leem a API, exigindo zero chamadas. Tornar Testar uma superfície de
  leitura é decisão de produto, não correção. Propus o hunk, medi 33 falhas
  contra 34, vi que a falha extra era minha e **retirei** a proposta.
- `forms.create` e `forms.edit`: compostas e corrigidas, mas o diretório
  produtivo é somente leitura por construção (`widget.reader == null &&` em
  `_canManage`), então **não há ponto de entrada navegável**; o editor só é
  alcançável por URL.
- **Autosave do editor**: `_scheduleAutosave` retorna imediatamente quando
  `authoringApi` é nulo, e nada no app constrói `SupabaseFormsAuthoringApi`. O
  autosave existe, está testado e não é alcançável. O rastreador o credita como
  integrado.
- **Saúde e Cuidado e Medicação**: não existe implementação Supabase de
  `HealthCareRepository` nem de `MedicationPlanRepository`; a rota produtiva
  monta `Unavailable`. Os testes verdes são sobre fixture.
- **question-image (I021)** e o ciclo XLSX remoto: dependem de reserva de mídia
  e de aplicação nominal.
- **`forms.location-question` e `forms.location-answer`**: dependem de decisão
  do Owner sobre política, não de código.

# Verificação

| Suíte | Base `d784462c1` | Com a entrega |
| --- | ---: | ---: |
| `apps/superadmin` completo | 5225 PASS / 209 FAIL / 7 SKIP | 5294 PASS / 209 FAIL / 7 SKIP |
| Formulários + contratos de rota | 699 PASS / 11 FAIL | 794 PASS / 9 FAIL |

As mesmas 209 falhas nas duas pontas do app inteiro: **zero regressão**, medida
e não deduzida. As duas falhas que saíram do recorte eram um teste de contrato
obsoleto, nunca defeito de produto. As 9 restantes são comparações de golden, e
a rodada não regrava golden.

Progressão medida na mesma base ao longo da noite: 699, 712, 720, 739, 744,
745, 750, 775, 780, 782, 785, 794.

Também verdes: `coelo_domain` 62/62, `coelo_api` forms 125/125, `apps/catalog`
87/87.

# Acessibilidade

Dez superfícies verificadas nas três diretrizes nativas, que não eram aplicadas
em Formulários nem em Cuidado. Seis de Formulários passam nas três. Os casos
marcados com motivo têm o defeito em componente compartilhado ou no shell,
nenhum no código do recorte: a alça de redimensionar coluna expõe 12x56 px, e o
botão de menu do usuário do shell expõe 242x44 px. O segundo nunca havia
aparecido porque `superadmin_shell_accessibility_test` verifica rótulo e **não**
tamanho de alvo.

# Goldens

Medição própria, preservada em
`2026-09-09-golden-divergence-measurement.md` com a ferramenta ao lado. Derruba
o enquadramento de telas redesenhadas: dimensão idêntica em 355 de 355 pares,
diferença cobrindo quase toda linha e toda coluna, e gravidade caindo conforme
a largura cresce, em quatro features de donos diferentes. Compatível com
mudança global de renderização amplificada por refluxo. Não afirmo causa raiz.

A consequência que muda o painel: enquanto a referência não for fixada e
reaprovada, os goldens **verdes** também não provam nada sobre aparência.

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

9. **O intervalo de datas autorado passou a valer também contra si mesmo.** Um
   intervalo inconsistente, com mínimo depois do máximo, fazia o seletor
   **estourar**, porque `showDatePicker` afirma que a data final não é anterior
   à inicial. Agora a pergunta diz que não pode ser respondida.
10. **A data passou a ser lida do mesmo jeito no campo e no resumo da enviada.**
    Aparecia `01/03/2026` num lugar e `1/3/2026` no outro.
11. **A escolha passou a ser lida pelo rótulo, não pelo id interno.** O resumo
    da enviada mostrava `option-2` para quem respondeu. Além de ilegível,
    expunha identificador interno — o que o teste do detalhe de resposta, na
    superfície de operações, já proíbe explicitamente.

Mais duas correções fora do fluxo de resposta: o **gateway de backend** passou a
converter falha de transporte em falha declarada, em vez de deixar escapar uma
exceção de plataforma que carrega o endereço e a URI do backend; e os **dois
exemplos de catálogo** de Formulários passaram a descrever o comportamento novo.

# Uma segunda lente: comparar duas telas que mostram o mesmo dado

As correções 5, 10 e 11 saíram de comparar a tela de **resposta** com o
**detalhe de resposta** em operações. Nas três, operações já fazia certo e a
resposta ficara com a versão antiga da formatação: dinheiro dividido sem
formatar, data sem zeros, escolha como id. Não é descuido pontual, é
sedimentação — a superfície escrita depois recebeu mais cuidado de apresentação.

Onde existem duas telas que mostram o mesmo dado, compará-las rende mais que
auditar uma.

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

# Uma segunda releitura do próprio diff

Reli também o que escrevi **depois** da primeira releitura. Rendeu um achado, e
foi um estouro: ao honrar o intervalo de datas eu tratei a resposta guardada
fora do intervalo e não tratei o intervalo ser inconsistente.

O rendimento cai da primeira para a segunda passada e não vai a zero, e o que
sobra tende a ser mais grave, porque o barato saiu na primeira.

O critério que separou o que corrigi do que apenas registrei: **latente com
custo de crash não é a mesma coisa que latente com custo de recusa**. Três
pendências latentes ficaram registradas sem correção — contagem de seleções de
múltipla escolha sem verificação no cliente, escala com faixa invertida gerando
zero opções, e escolha com lista vazia — porque nenhuma é produzível pelo editor
atual e todas custam uma recusa, não uma tela quebrada. Isso prioriza; não as
absolve.

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
| `apps/superadmin` completo | 5225 PASS / 209 FAIL / 7 SKIP | 5326 PASS / 207 FAIL / 10 SKIP |
| Formulários + contratos de rota | 699 PASS / 11 FAIL | 797 PASS / 9 FAIL |

O app inteiro reconcilia item a item: **+101 testes**, **duas falhas a menos** —
os dois testes de contrato obsoletos — e **três marcados com motivo**, que são o
diretório de Formulários e os dois de Cuidado. Nenhum número sobrando, e
**zero regressão**, medida e não deduzida.

## O recorte sobre a base integrada

O mesmo comando, `test/features/forms` e `test/features/health_care` juntos,
rodado dos dois lados:

| Base | Resultado |
| --- | ---: |
| `origin/dev` em `6811e453e` | 979 PASS / 13 FAIL / 3 SKIP |
| esta branch em `0de24d014` | 982 PASS / 13 FAIL / 3 SKIP |

Mesmas 13 falhas e mesmos 3 marcados. A diferença de exatamente três testes é o
último commit, ainda não integrado, que adiciona dois casos de faixa de
`maxLength` e um de fidelidade do preview. O recorte se comporta igual com os
lotes das outras sete frentes juntos: não há surpresa de integração guardada
para o fechamento. As duas falhas que saíram do recorte eram um teste de contrato
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

# As nove falhas do recorte, decompostas

`test/features/forms` fecha em **800 PASS / 9 FAIL / 1 SKIP**.

**Oito são comparação de golden** — três de `forms_directory_golden_test`, três
de `forms_editor_golden_test`, uma de `forms_operations_golden_test` e uma de
`form_response_golden_test`. Todas sob a decisão do Owner sobre o ambiente de
referência.

**A nona foi corrigida** e o recorte fecha com **oito falhas, todas de golden**.

> **Superado.** "Oito" valia para `test/features/forms`, que nao era o recorte
> inteiro — dezessete arquivos de teste do grupo viviam fora desse caminho. O
> recorte corrigido fecha em **catorze falhas** sobre a base integrada
> `3fb200dab`, das quais doze sao minhas e todas de golden. Ver
> `2026-09-10-triagem-goldens.md`.
Ela não era defeito de produto:
`forms_editor_page_test`, "production preserves the editor hierarchy with
neutral disabled controls", afirma que há exatamente dois `ExcludeFocus`
excluindo na árvore inteira, e há quatro. Dois vêm do próprio editor, do helper
`_locked` usado na navegação de seções e no corpo — exatamente os dois que o
teste espera. Os outros dois vêm de `CoeloAdminToggleField`, de
`packages/coelo_ui_admin`, que envolve o próprio `Switch` em `ExcludeFocus`.

E esse `ExcludeFocus` do componente está **certo**: o campo inteiro já é focável
por `FocusableActionDetector` com `Semantics(onTap:)`, então excluir o `Switch`
impede que o mesmo controle vire duas paradas de foco. É desenho deliberado de
um focus stop por campo.

A asserção contava a árvore toda, incluindo as entranhas de um componente de
outro pacote, então disparava sempre que mudava quantos campos de alternância
são renderizados. Confirmado que não era desta entrega: com o editor da base
`d784462c1` restaurado no diretório de trabalho, o mesmo arquivo dá quatro
também.

A afirmação passou a ser de intenção — no estado fail-closed nada está focável e
as duas regiões do editor estão excluídas — e o comentário no teste registra que
o `ExcludeFocus` do componente está **certo**, para ninguém "consertar" o
componente depois.

# Três linhas de bloqueio minhas que estavam erradas

Uma linha de bloqueio parece informação e por isso ninguém a testa, mas é uma
hipótese não verificada. Auditei todas as minhas.

> **Corrigido em 2026-09-10: são QUATRO, não três.** A quarta apareceu na
> conferência final — `forms.resolve-file` afirmava que cliente e injeção de
> dependência seguiam em fila, quando o resolvedor está composto em produção.
> Que ela tenha aparecido tão tarde prova que esta auditoria foi oportunista;
> a varredura exaustiva está em `2026-09-10-metodo-e-autocorrecao.md`.

**Três estavam erradas, e as
três eram exatamente as que eu havia copiado do rastreador sem testar.** Nenhum
bloqueio que eu mesmo verifiquei estava errado.

- **question-image (I021)** não estava bloqueada por reserva de mídia. A cadeia
  está aplicada: `form_prepare_asset_upload` com grant a `authenticated`,
  `form_worker_finalize_asset` como função de worker, a Edge Function conferindo
  MIME real, e o adaptador de cliente já implementado. Falta **só a interface**
  de anexo. Decisão de projeto tomada: usa esse caminho, não espera o catálogo
  unificado, que não tem write path para kind nenhum.
- **`forms.location-question` e `forms.location-answer`** não são "código pronto
  esperando decisão". Não existe kind de Local no domínio de Formulários;
  `LocationSelectionSource` vive na feature Locais e nunca é referenciado por
  Formulários. A decisão do Owner **precede** a construção.
- **care049** não espera pacote nominal de produção. `specs/049` está
  `draft-for-review` — rascunho não aprovado — e define um contrato que ainda não
  existe. E `specs/020`, a spec vigente, está `approved-for-demonstrative-ui`, o
  que explica a ausência de repositório de produção: **é o escopo aprovado**.
  Falta aprovar uma spec, não autorizar um pacote.

# Uma dívida medida que decidi não pagar hoje

41 arquivos em `apps/superadmin/lib` escrevem inline o mesmo formatador de data
`dd/MM/aaaa` — agenda 5, forms 4, support 3, notices 3, meal_plans 3,
health_care 3, activities 3, e o resto espalhado por pelo menos doze features.

Não é dívida teórica: **três** das correções desta rodada saíram exatamente
dela. Dinheiro dividido sem formatar numa tela e formatado na outra, data com
zeros no campo e sem zeros no resumo, escolha por id numa tela e por rótulo na
outra. Cada uma existia porque a mesma regra estava escrita duas vezes e as
cópias envelheceram diferente.

Não refatorei: deduplicar três de 41 é cosmético, e deduplicar 41 durante
integração congelada troca um problema de manutenção por um problema de merge
na pior hora. Fica como recomendação de passe dedicado, com dono único, fora de
janela de integração. Quatro das 41 são deste recorte.

# Invariantes de segurança do AGENTS.md

Conferidas contra esta entrega, uma a uma.

- **Regra de negócio validada no backend.** Nenhuma validação foi movida para o
  cliente: o que eu liguei espelha regra que o servidor já aplicava, e serve
  para falhar cedo e explicar. Encontrei uma violação existente e **não** a
  corrigi, porque é migration nova: o gate estrutural de publicação é só do
  cliente. `app_private.form_publish` confere ator, existência,
  `expected_version` e versão de trabalho, e não valida título, ordem,
  obrigatórios nem as regras de Enquete rápida. A autorização está correta e é
  server-side; o que é client-only é a validação estrutural.
- **IDs e parâmetros do cliente não confiáveis.** Nenhum caminho novo confia em
  ID vindo do cliente. Retirei o único hunk que teria composto uma rota nova.
- **Inputs limitados no servidor.** Verificado: `form_replace_response_answers`
  recusa texto acima do máximo, número fora da faixa, data fora do intervalo,
  escala fora dos limites, contagem de seleções e contagem de arquivos.
- **Nenhum segredo em Git, log ou URL.** Varri o diff inteiro: nenhum valor de
  credencial. E **corrigi** um vazamento real — a exceção crua de transporte
  carregava o endereço e a URI do backend, capturados literalmente pelo teste.
  Não há `print`, `debugPrint` ou log em nenhum dos dois recortes, e o ticket de
  download já tinha `toString` redigido.
- **Rotas não entregam dado antes da autorização.** Nenhuma rota foi alterada;
  o router tem zero alteração líquida nesta branch.

# Goldens

Medição própria, preservada em
`2026-09-09-golden-divergence-measurement.md` com a ferramenta ao lado. Derruba
o enquadramento de telas redesenhadas: dimensão idêntica em 355 de 355 pares,
diferença cobrindo quase toda linha e toda coluna, e gravidade caindo conforme
a largura cresce, em quatro features de donos diferentes. Compatível com
mudança global de renderização amplificada por refluxo. Não afirmo causa raiz.

A consequência que muda o painel: enquanto a referência não for fixada e
reaprovada, os goldens **verdes** também não provam nada sobre aparência.

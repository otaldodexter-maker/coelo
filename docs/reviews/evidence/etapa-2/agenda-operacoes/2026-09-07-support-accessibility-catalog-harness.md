---
title: Suporte — viewport, paginação e teclado; harness de preview Suporte/Catálogo
source: Matriz existente de Suporte; RED local de overflow e hit test; revisão independente de foco
status: Correção local verificada no recorte; baseline visual histórica pendente; não E2E
generated: 2026-09-07
---

# Correções e provas

O teste existente reproduziu RenderFlex overflow de 41px em 375×900/texto200%.
A toolbar consumia a altura do board. A tela agora limita a toolbar compacta com
scroll próprio e reserva a anatomia fixa mais área útil da listagem. Sem alterar
componentes compartilhados ou substituir a viewport original por uma maior.

A matriz agora exige paginação acionável, rect dentro da viewport e troca real
para SUP-010. Isso reproduziu outro RED em 1440/texto150%: centro do botão2
(1367,783) dentro do launcher Mens. em y744–792. O inset local do launcher agora
acompanha o textScaler. A1× preserva exatamente o valor anterior.

O novo teste de teclado reproduziu Tab preso em Leitura, cujo FocusScope usava
closedLoop com um único controle. parentScope mantém a restauração de foco do
detalhe e permite sair nas duas direções. A prova375/texto200% nos dois temas
começa com toggle fora da viewport; Tab chega e o torna acionável; Shift+Tab
entra/sai do scope; Tab+Enter abre a tabela. Não usa ensureVisible nesse teste.

Nos harnesses de rotas Suporte e Catálogo, quatro casos de preview falhavam por
não ligar allowDevelopmentPreview. Somente testes de preview fazem opt-in; o
default continua false e negativas verificam /dev bloqueado sem sessão. Nenhum
router de produção, autenticação ou composition root foi alterado.

Validações: matriz de quatro larguras375/768/1024/1440, dois temas, texto150/200%,
kanban/tabela, click de paginação e caso reduced-motion; oito testes no arquivo
de correções de Suporte PASS. Analyzer dos cinco Dart alterados sem issues;
validator de contratos visuais PASS; git diff --check PASS.
Regressão funcional final:70/70 PASS nos testes de correções, páginas, controllers,
widgets e rotas de Suporte, mais host/boundary/rotas de Catálogo. O comando selecionou
explicitamente esses arquivos/diretórios e não incluiu a suite histórica de goldens
pendente abaixo; portanto não representa toda a suite visual verde.

Oito novos goldens com fontes reais375/texto200% e1440/texto150%, ambos temas e
modos, foram gerados, inspecionados visualmente pelo root e comparados novamente
sem update-goldens com PASS. Não houve alteração dos24 masters anteriores.

# Limites e pendências preservados

A regressão ampla encontrou o teste histórico com24 goldens divergentes. Os
masters ainda mostram título Suporte, kanban laranja, ausência de criar/launcher,
enquanto o código anterior deste pacote já tinha título Suporte e implantação,
criar, launcher e aparência atual. Inspeção direta de master/actual768 confirma
drift além da correção compacta; não se atribui toda divergência ao pacote nem
se faz rebaseline automático. Os feedbacks PNG versionados regenerados pelo
runner foram restaurados ao HEAD; os masters foram preservados.
Controle de fonte: git show ee212cb:apps/superadmin/lib/features/support/presentation/screens/support_page.dart
confirma título/subtítulo/launcher/create-table prévios; não foi feito replay visual
isolado do HEAD anterior. Coordenação confirmou ausência de outro writer nominal
de baseline e orientou preservar os24 masters neste pacote.

A suite histórica permanece vermelha e foi informada à coordenação; as novas
provas não substituem sua aprovação/reconciliação. A reserva de altura vale para
900px testados, não é evidência para qualquer altura menor.

Suporte continua protótipo/injeção local. OQ-028 e o contrato remoto do domínio
dependem de decisão do Owner; Catálogo externo em runtime não foi certificado.
Nenhuma operação remota ou status E2E foi promovido.

As skills Coelo UI/integrada e revisão orientaram provas de interação além de
ausência de overflow; a revisão adicional identificou o trap de foco. Gate de
conhecimento sem projeção: correção de comportamento já esperado, sem regra nova.

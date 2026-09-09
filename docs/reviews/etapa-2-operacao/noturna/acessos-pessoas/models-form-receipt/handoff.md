---
fonte: AccessProfileFormPage at 1d291711e; People R02 confirmed completion pattern; parent delegation
status: local correction proven; inherited visual gate open; publication pending parent
data_geracao: 2026-09-09
---

## Recorte e correção

apps/superadmin -> Perfis/Modelos -> criar/editar -> salvar e conclusão após resposta confirmada. Mapeamento lógico; IDs canônicos ficam com o coordenador. Nenhuma alteração no repository HTTP, duplicação, router, bootstrap, SQL ou política de escrita.

O formulário apagava a intenção pendente e chamava onSaved dentro do tratamento da mutação. Uma falha do callback permitia reenviar a mesma criação/edição, agora com novo requestId. RED demonstrou duas chamadas ao repository em cada cenário.

A conclusão confirmada agora fica retida numa closure vinculada à revisão do contexto. Erros do callback são tratados como falha de navegação após confirmação, sem atingir o tratamento de conflito/erro do repository. O rascunho é substituído pelo estado de confirmação com Voltar/Continuar; passos e callbacks de edição ficam bloqueados. A repetição conclui apenas a navegação. Trocar repository/domain/profileId invalida o recibo e callbacks antigos não entregam nada ao novo contexto. O fluxo regular antes da confirmação mantém sua composição anterior.

## Provas e limites

- red.txt: P0/F2 create/edit, ambos com 2 gravações em vez de 1.
- green.txt: P17/F0 nas suítes receipt, context e continuation; quatro casos novos cobrem create/edit, StateError na navegação e troca de repository/profileId.
- golden.txt: F1 no teste existente de create mobile/editor desktop/review desktop, com três comparações de imagem divergentes.
- golden-base.txt: o mesmo F1 na base 1d291711e. visual-comparison.json prova que todas as três imagens geradas são byte-idênticas entre base e correção. A fonte atual foi restaurada em finally e seu hash conferido em source-restored.txt.
- Inspeção de 375px mostra shell antigo no master (hambúrguer, bug, cinza, subtítulo truncado) versus composição atual (marca Coelo, branco, subtítulo em duas linhas). Campos e rodapé permanecem iguais; não houve atualização de PNG.
- analyze.txt: quatro avisos de estilo/parâmetros não usados na fixture; corrigidos. analyze-final.txt: zero problemas, exit0.
- capture-fonts.txt/confirmed-create.png: captura nominal do novo estado após confirmação, sem criar uma golden. Reexecução de um ID já contado, somente para inspeção visual. O teste temporário é removido em finally; prepare_capture.py permite reproduzir. A primeira captura usava Ahem; a final carrega as mesmas fontes da golden e foi inspecionada: painel legível, sem campos editáveis, Voltar/Continuar visíveis e sem overflow.

Contagem final única do plano executado: P17/F1/B0/S0/U0, N18. RED e comparação da base não são somados. O F1 visual é herdado, com zero diferença introduzida nas três imagens verificadas. Isso não torna a golden aprovada nem conclui FE/BE/E2E do domínio. Nenhum ensaio remoto ou HTTP repetido.

## Entrega e próximo gate

Código: lib/features/access_profiles/presentation/access_profile_form_page.dart. Teste novo: test/features/access_profiles/presentation/access_profile_form_receipt_test.dart, ambos sob apps/superadmin. Hashes finais em manifest.json. Pai revisa, publica e integra; executor não fez mutações Git.

Próximo gate visual deve reconciliar as referências de formulário com as mudanças aprovadas do shell, em lote nominal coordenado; este lote não altera referências. A memória durável já está no padrão de recibo confirmado de Pessoas e na política de não repetir persistência confirmada; não foi criada decisão nova de produto nem projeção de conhecimento apenas para registrar atividade.

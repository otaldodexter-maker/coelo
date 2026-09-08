---
title: "Formulários — ramo Se Sim no editor"
source: "Spec Forms 2026-08-13:131,180; reserva nominal do Coordenador; REDs e revisão local E2E4"
status: "local-verified-visual-and-backend-open"
generated_at: "2026-09-07"
---

# Recorte e contrato

Editor Superadmin: criar, salvar, reabrir e editar filhos de condição simples
yesNo=true. Root único writer, revisão independente read-only. Nenhum SQL,
deploy, acesso remoto ou mudança do evaluator compartilhado nesta fatia.
Choice continua dependente de seletor explícito da opção: não foi inferida
opção nem serializado ramo sem gatilho.

# Correção e RED

O payload antes ignorava filhos criados visualmente. Seis testes RED mostraram
filho ausente ou hierarquia Se Sim ausente no reload. A árvore é agora
achatada após o pai com posições contíguas; cada filho novo recebe UUID e a
condição direta do pai. Esconder controles não apaga filhos/condições.

A hidratação só agrupa relações contíguas representáveis, conservando a ordem
original de relações não contíguas, fonte posterior e condições não agrupáveis.
Cópias remapeiam IDs de toda a subárvore, opções e referências internas;
referências externas permanecem. Cards canônicos editam os descendentes, com
movimento entre irmãos e sem arraste acidental da lista ancestral.

A revisão encontrou omissão dos filhos na prévia: RED reproduzido e corrigido
achatando a prévia e indicando pergunta condicionada. Contagem da seção também
considera descendentes. Quatorze testes novos cobrem round-trip por nova
instância da API, identidade, cópias, reordenação, remoção/adição, ciclo rejeitado
e quatro níveis a 375 px com texto a 200%.

# Verificação visual

O primeiro golden após implementação detectou novas diferenças de espaçamento
do painel e exibição de ramo vazio no pai recolhido. Foram corrigidas sem
atualizar imagens aprovadas. A tentativa intermediária de aumentar recuo
recolhido causou overflow de 27 px no teste de quatro níveis: RED observado,
recuo corrigido e teste novamente verde.

A execução final de goldens teve 2 testes passando e 2 falhando. Permanecem
cinco diferenças com as mesmas contagens previamente registradas: light375
140039 px; dark375 153920 px; light768 79979 px; dark768 92341 px;
light375/text200 108064 px. Catálogo, intervalo de datas e prévia passam.
O gate visual não está concluído. Uma tentativa de execução encontrou lock
concorrente de engine.realm no SDK; foi repetida após término, sem alterar SDK.

# Limites e memória

Verificação funcional final: sete suítes de editor, resposta, DEV, lifecycle
e API, 151/151, exit 0. Analyzer dos dois arquivos sem problemas; validator
administrativo visual exit 0. Revisão independente read-only aprovada, incluindo
o ajuste final de posição do painel; nenhum arquivo golden atualizado.

Round-trip aqui usa API de teste; não comprova gravação/reload produtivos.
Autoria nominal, responder autorizado, locais internos, imagens, cuidado e
XLSX/R2 permanecem no escopo original e nos respectivos gates. Delta destinado
ao Coordenador, sem edição dos rastreadores oficiais.

Gate de memória: restauração de regra já aprovada, sem nova decisão de produto
e sem nova projeção criada apenas para registrar atividade.

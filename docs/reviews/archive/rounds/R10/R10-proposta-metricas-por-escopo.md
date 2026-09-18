---
source: Owner; inventario-etapa-2.json; contrato de metricas vigente
status: proposta-de-segmentacao; denominadores-nao-alterados
generated_at: 2026-09-12
---

# Separar entrega da Etapa2, MVP, V1 e app geral

Owner apontou que incluir trabalho adiado na porcentagem da entrega atual
cria percepcao incorreta de incompletude. Exemplo concreto: units.import
(Importar Unidades) esta FE local-green, BE/E2E deferred-post-mvp.
O tratamento local do botao indisponivel nao implementa importacao real.
Essa acao entra hoje na base FE231, embora sua operacao nao seja entrega MVP.
Nao pedir aprovacao de importacao nem implementa-la so para elevar metrica.

Proposta: registrar por action_id o app/superficie, etapa de entrega e marco
de produto (MVP, V1 ou futuro ainda nao atribuido), alem da aplicabilidade
FE/BE/E2E e estado. Etapa e versao sao eixos distintos: a Etapa3 tambem faz
parte do MVP, logo nao se deve igualar Etapa2 e MVP ou somar percentuais.

Painel principal da rodada: somente o escopo aprovado da Etapa2, com suas
acoes FE/BE/E2E aplicaveis. Paineis separados: MVP completo, V1 e escopo geral
conhecido do app, sempre com base/revisao/data e cobertura do inventario.
V1/futuro sem inventario aprovado fica 'base ainda nao definida', nao 0%
nem porcentagem inferida. App geral nao e media simples das etapas; requer
uniao de IDs sem duplicatas e nao pode significar funcionalidades futuras
ainda desconhecidas. Aprovação visual e estoque local-green continuam separados.

Antes de mudar as skills/denominadores: cruzar fontes aprovadas e publicar
mapeamento por ID, lista de ambiguidades e exemplo antes/depois. Marcar o
caso units.import como adiado; nao atribuir automaticamente a V1. Informar
numeradores e denominadores antigos/novos, com uma ponte de reconciliacao.
Depois atualizar contrato canonico de metricas, skills FE/BE/FE+BE/knowledge,
inventario, scripts e tres rastreadores juntos, com testes de exclusao de
adiados e deduplicacao. Nenhuma migracao foi feita nesta preparacao documental.

Na R10, comparar progresso funcional na mesma base antes/depois. Se a nova
segmentacao for implantada, reportar tambem a base historica231/224/199 para
separar ganho de entrega do efeito matematico do recorte. A meta7–9p.p. nao
pode ser atingida apenas removendo pendencias do denominador. Questões de
escopo ambiguo ficam pendentes sem interromper CRUD independente.

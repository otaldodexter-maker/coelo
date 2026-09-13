---
source: Owner screenshot; normal-route C0 reproduction; R08 retained assessment proof
status: implementing
generated_at: 2026-09-13
---

# Atividades — configuração avaliativa por unidade

apps/superadmin → Estrutura → Atividades → detalhe → Configuração avaliativa;
action_id activities.assessment. A rota normal só envia institutionId. A
configuração R08 833a89d8 está na unidade e a página sem unitId mostra vazio.
Não criar configuração substituta nem alterar diário retido para contornar.

Correção: detalhe mantém a ação institucional e oferece ação com nome de cada
unidade ativa retornada pelo repository produtivo; roteia unitId juntamente
com institutionId. Backend continua reautorizando parâmetros não confiáveis.
Owner também apontou Periodicidade fora do padrão e ausência de espaço entre
Adicionar período e estado vazio: cápsula com label persistente e gap16px
por token. Referência canônica da skill atualizada no mesmo delta.

Testes focais preparados: seleção da unidade autorizada e retirada após perder
capacidade; variante do seletor e gap entre botão/estado vazio. Execução aguarda
slot Flutter de chat_inline. C0 não reconstruirá runtime durante prova UI.
Nenhuma gravação de avaliação ocorreu nesta reprodução; cancelamento preserva
os recursos existentes. Próximo gate: teste conjunto, build, rota normal até
a configuração retida, save/reload conforme versão vigente. Responsável C0.

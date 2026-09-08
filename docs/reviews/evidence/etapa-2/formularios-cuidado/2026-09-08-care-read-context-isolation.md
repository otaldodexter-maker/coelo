---
title: "Cuidado — isolamento de leituras e troca do diretório de medicação"
source: "Escopo original E2E 4; review read-only; HealthCareController e diretório de planos"
status: "local-green-not-e2e"
generated_at: "2026-09-08"
---

# Recorte

Objetivo: impedir dados/erros de uma leitura antiga de substituir contexto novo.
Incluído: troca de controller no diretório de medicação, leituras de detalhe,
descarte e negativas locais. Fora: política clínica, backend, persistência real,
autorização server-side, dose/agenda e reload tardio iniciado por mutação.
Ordem: RED discriminante, correção mínima, regressão/visual, review e handoff.
Critério local: nenhuma resposta antiga aplicada nem ID antigo encaminhado ao
controller substituto. Estimativa da fatia: 30 minutos; não é conclusão E2E.

# Defeitos reproduzidos

1. A página não reagia à troca de controller, mantendo cards da criança A no
   contexto B. Após o primeiro await, usava widget.controller novo com IDs de A.
   Quatro REDs confirmaram card residual, child-demo-a enviado ao repositório B,
   sucesso tardio e erro tardio. Ajustamos a sincronização do teste para terminar
   a chamada pendente e obter asserção de dados, não apenas timeout de animação.
2. loadDetail não tinha geração. Se B terminava antes de A, A substituía detalhe,
   estado ou erro. Seis REDs cobriram sucesso, ausência, StateError, erro genérico,
   erro anterior conservado e notify após dispose.

# Correção

- Página invalida gerações, limpa itens/erro/busca/filtros/página e recarrega em
  didUpdateWidget quando muda controller. Captura controller e ator antes do
  await; checa identidade/geração após cada await e no erro. Minimizado e unmount
  não iniciam consultas sensíveis subsequentes.
- Controller compartilha geração entre load e loadDetail: última leitura
  iniciada vence. Limpa erro ao começar detalhe; resultado vai para variável
  local antes de ser aplicado. Dispose invalida ambas e bloqueia novas leituras.
- Nenhuma autorização foi transferida ao frontend; repositórios/backend continuam
  responsáveis por autorizar os recursos. Nenhuma regra de cuidado foi inventada.

# Verificação executada

- 14 testes novos: 10 REDs acima e quatro controles adicionais (minimização,
  unmount e duas ordens directory/detail).
- Regressão final: **165/165** nos 16 arquivos funcionais de
  `test/features/health_care`, excluindo explicitamente health_care_golden_test.
- Analyzer dos quatro arquivos alterados: sem problemas.
- Validador de contratos visuais administrativos: exit 0.
- Review independente read-only: sem bloqueante; recomendação de testar as duas
  ordens de leitura foi incorporada antes da regressão final.

Suíte golden executada separadamente: **0 testes passaram / 4 falharam**.
Diretórios, flyout de arquivos, formulários e estados de perfil continuam com
diferenças. Exemplos medidos: medication_directory_mobile_light 68029 pixels,
medication_directory_desktop_dark 132554; profile_directory_mobile_light 57210,
profile_directory_desktop_dark 130074. As quatro categorias já eram pendência
visual, mas esta fatia não afirma igualdade pixel a pixel com execução anterior.
Nenhuma baseline foi atualizada para ocultar divergências; visual permanece aberto.

# Pendências e memória

O detalhe legado não está ligado à rota produtiva; o diretório e fixtures locais
não comprovam persistência ou autorização E2E. Backend/política clínica continuam
nos gates do escopo original. Próximo achado separado a reproduzir: conclusão de
mutação antiga pode iniciar reload de outra criança após navegação.

Restauração de invariantes existentes; nenhuma nova projeção de conhecimento é
necessária apenas para atividade. Evidência/delta seguem ao Coordenador, que
mantém rastreadores oficiais. Nenhum SQL, deploy ou recurso remoto foi executado.

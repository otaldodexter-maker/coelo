---
source: "Confirmações explícitas do Owner Coelo em 2026-08-06; arbitragem visual de 2026-08-24"
status: "approved"
generated_at: "2026-08-06"
updated_at: "2026-08-24"
---

# Confirmações do intake visual para o review profundo

Este documento resolve as seis perguntas pendentes em
`docs/design/coelo-ui-deep-review-intake-2026-08-06.md`.

1. `Continuar` é laranja quando for a única ação de avanço. Quando coexistir
   com `Salvar`, somente `Salvar` é primária laranja e `Continuar` permanece
   branco com contorno.
2. Acima da tabela, usar ação principal à esquerda, busca e ações secundárias
   em seguida e importação/exportação agrupadas em `Arquivos`, conforme
   Instituições, com adaptação responsiva e sem botões soltos.
3. Cards e contêineres permanecem somente quando agrupam conteúdo com função
   visual clara, como mídia, preview, bloco especializado ou resumo herdado.
   Inputs comuns e seções simples ficam diretamente no canvas da etapa.
4. A matriz de permissões deriva ações exclusivamente das capacidades reais de
   cada módulo/tela. Não força todas as ações em todos os módulos e não inventa
   autorização no cliente.
5. Bandeiras de Conversas: vermelho para urgente; verde para acompanhamento ou
   resolução positiva; azul para informativo ou aguardando ação; rosa para
   sensível/cuidado; amarelo reformulado para atenção; grafite/preto para
   restrito. O texto recolhido abre por hover/foco no desktop e toque no mobile.
6. Eliminar as páginas/rotas intermediárias de leitura apontadas para Perfil de
   cuidado, Plano de medicação, Plano e Usuário interno. A listagem abre
   diretamente a respectiva edição.

## Arbitragem visual posterior

Em 2026-08-24, a baseline `import_hub_new_dialog_light_1440.png` foi
substituída sobre a composição `6eab005c`. A referência anterior registrava
duas ações textuais terminais (`Fechar` e `Cancelar`) e divergia 1,78% no teste
exato. A nova referência preserva o diálogo e todas as opções de importação,
usa o `X` canônico para fechar e mantém uma única ação textual `Cancelar` com
hierarquia negativa. Nenhum source, outro golden ou contrato visual integra
esta arbitragem.

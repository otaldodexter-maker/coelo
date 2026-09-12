---
source: R08 C0; revisões G0–G8; provas locais e remotas commitadas
status: checkpoint-integrado-com-gates-remotos-abertos
generated_at: 2026-09-12
---

# Ciclo 180 — imagem de resposta, Perfil e tabelas

Execução até 14:52:16, revisão das frentes até 15:02:16 e fechamento C0 até
15:22:16 BRT. As nove revisões foram lidas por SHA fixo e receberam ACK180.
A publicação deste ciclo ocorreu após a correção da regressão visual encontrada
na base integrada; nenhum resultado futuro foi convertido em aprovação.

## Validação integrada

- Base `c729090f9`: 411 aprovados, 4 falhos e 1 ignorado em 16 arquivos,
  97,850 s, exit nativo 1. As quatro falhas são goldens de Atividades e
  Instituições afetados pela faixa de interação H25. Forms, câmera, anonimato,
  composição, Perfil e Turmas passaram nesse lote.
- Correção `f0e148a70`: preserva a pintura aprovada e separa os alvos de
  ordenação e redimensionamento. C0 executou os dois arquivos de goldens e a
  tabela: 37 aprovados, zero falhos, 36,116 s, exit 0. Nenhum PNG foi alterado.
- Perfil e scanner SQL `2f0aef225`: 23 aprovados em dois arquivos na base
  integrada, 5,499 s, exit 0. A view relê ao trocar papel/escopo; o scanner
  reconhece identificadores SQL entre aspas e exclui fixtures de teste no Windows.
- Análise global do Superadmin: zero apontamentos, 113,5 s, exit 0. Os ajustes
  posteriores tiveram análise focal autoral zero e serão cobertos pelo censo
  final. Não somar os reruns aos casos únicos.
- Memória: 64 artigos válidos; ferramenta 12 aprovados e 1 ignorado por
  impossibilidade de criar symlink no host. Isso não certifica o aplicativo.

Os logs nativos, inclusive RED e saída de configuração incorreta do Deno,
permanecem preservados. Linhas em branco finais desses logs não foram editadas.

## Entregas e próximos gates das nove frentes

G0 preservou uma única cadeia de formulário/resposta/arquivo. O mesmo asset
passou prepare, PUT de 68 bytes, finalização, replay e gravação. Download ainda
falhou; C0 confirmou no banco um asset finalized, um espelho ready e um vínculo.
O ajuste de parâmetro nulo explícito foi implantado como form-media v21, com
56 testes Deno aprovados, verify_jwt ativo e OPTIONS 204/204/403. A retomada
somente de download foi autorizada após revisão G5, sem novo upload ou fixture.

G1 publicou os 45 A e continua corrigindo o executor de Avaliações. Os reviews
G5/G7 impediram execução com payload incorreto ou retomada insegura. Nenhuma
configuração/diário remoto desse executor foi criado neste ciclo.

G2 prepara H28: filtros reais de Pessoas exigem contrato SQL, opções em cascata,
cliente e pgTAP funcional A/B. O pacote continua fora da fila de aplicação até
revisão e provas completas. Não ativar a nova assinatura antes do banco.

G3 entregou câmera, descarte seguro, H25 e proposta de memória. O teste completo
de acessibilidade antes ignorado passou na frente, sem correção cosmética ou
PNG novo; sua reativação será coberta na próxima base integrada.

G4 corrigiu parser, save/reload e troca de contexto de Perfil; reconciliou o
scanner SQL e mapeou errors.*. Retry contextual de Momentos não exige inventar
uma nova página global. Revisões visuais não viraram E2E.

G5 corrigiu ator interno, expiração da assinatura R2 e parâmetro obrigatório
nulo no download. C0 fez os deploys e alterou somente a flag de provider R2.
Nenhum lote SQL novo foi aplicado; o próximo número continua 59.

G6 revisou composição anônima, Perfil, parser de evidências e imagens H25;
propôs manifesto de recursos retidos. O incidente anterior da Circular
arquivada/excluída logicamente continua registrado, sem limpeza adicional.

G7 corrigiu metadados do Local de Turmas, revisou Avaliações/H28 e inventariou
as dez worktrees. Nenhuma estava encerrável na medição; WIP e arquivos privados
foram identificados sem expor conteúdo. Não remover nem apagar branches.

G8 reconciliou eventos de teste por ID e nomes de exibição, mantendo colisões
de nomes separadas de casos executados. O parser geral do censo segue em revisão;
o censo completo do Superadmin será executado uma vez no fechamento.

## Sete percentuais

| Métrica | Base | Percentual |
| --- | --- | --- |
| Front-end verificado | 161/231 | 69,70% |
| Avanço local Front-end aberto | 26/70 | 37,14% |
| Aprovação visual por ação | 54/231 | 23,38% |
| Avanço local Back-end aberto | 32/75 | 42,67% |
| Cobertura SQL | 181/224 | 80,80% |
| Back-end concluído | 149/224 | 66,52% |
| Integração E2E ativa | 131/199 | 65,83% |

Avanço local real neste ciclo: forms.upload e forms.resolve-file passaram a
local-green após composição e testes integrados. Não houve novo verified,
done ou verified-e2e. Correção de goldens, contagens e exceções históricas são
reconciliações; a recuperação da regressão não é avanço líquido adicional.
Delta aplicado com apply-tracker-delta.cjs; os três rastreadores foram validados.

As fontes canônicas e a projeção team registram persistência do segredo anônimo,
lifecycle da câmera e separação dos alvos da tabela. Não houve nova decisão de
produto/ADR. Os limites de câmera física, concorrência entre abas, targets de
ordenação estreitos e UI real permanecem explícitos. A R08 continua em execução.

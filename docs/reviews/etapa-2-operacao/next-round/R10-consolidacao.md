---
source: Owner, 13/09/2026; Git real; backups verificados
status: workspace consolidado; referências históricas classificadas; produto parcialmente concluído
generated_at: 2026-09-13
---

# Consolidação pós-R10

As 26 worktrees antigas estavam limpas e seus HEADs agora são ancestrais de dev. O único HEAD exclusivo entre elas era d2ed31572 (checkpoint documental de abertura R09 bloqueada); conteúdo48linhas revisado e integrado pelo merge3ee2d1306. Nenhum código antigo foi sobreposto. Foram arquivadas com ignored ZIP_STORED, teste CRC, SHA256 e manifest por worktree; bundle --all foi verificado antes das remoções. Git worktree remove usou somente alvos absolutos conferidos sob Coelo.worktrees, sem processos ativos referenciando o alvo. Nenhuma branch foi apagada.

Backup privado: C:/Users/adrie/Documents/Coelo-backups/consolidacao-20260913. Manifest público sanitizado: docs/reviews/evidence/etapa-2/r10-coordenacao/consolidation-archives.json. Env e demais ignorados ficam apenas nos ZIPs externos, nunca no Git. Para restaurar: verificar hash do ZIP e bundle, recuperar a branch pelo bundle se necessário, git worktree add no caminho original com a branch preservada e extrair seus ignorados. Não extrair sobre checkout com alterações.

O pedido posterior do Owner de não deixar nada à frente/atrás autoriza agora fast-forward do checkout principal e sua adoção como destino único. Não é permissão para sobrescrever ignorados ou alterações. A worktree C0 será arquivada depois de commit/push, backup e transferência do runtime.

## Referências históricas

Há15branches locais fora da ancestralidade: cinco são patch-equivalentes, nove são candidatos anteriores à R10 com conteúdo não integralmente comparado aos sucessores, e uma é a primeira entrega de upload R10. Essa última df90f05b foi substituída por b5a0fe8e7 (integrado): a versão sucessora acrescenta tratamento de replay legado e testes de negação/status. Não reaplicar a primeira versão, que removeria essas guardas.

As cinco patch-equivalentes são work/etapa2-noturna-formularios-cuidado, import-orfao, operacoes-sistema, perfil-para-voce e publicacoes-midia. Identidade de patch não certifica produto, mas não há patch novo delas a integrar.

Nove candidatas retidas: sete branches codex/e2-r02 (d01-auth, d02-estrutura, d03-acompanhamento, d04-acessos, l00-coordenacao, l01-publicacoes, l02-chat), wip/fase0-arquivo-chat e work/etapa2-noturna-copia-previa. WIP fase0 contém launcher/ícones/testes não concluídos à época; a cópia-prévia era proposta condicionada a decisão. Não foram declaradas funcionalmente integradas. Primeiro gate C0: comparar cada alteração necessária com o sucessor atual e seu aceite, integrar somente delta faltante com testes. Toda referência e commit está no bundle e no inventário Git, sem descarte.

Os MDs das três camadas e as cinco skills recebem gate obrigatório ADR0036. O estado completo de231ações está em R10-estado-por-tela.md; status de produto não mudou nesta consolidação. R10 encerrada, R11/Etapa3 não iniciadas. Uma base única sincronizada não equivale a declarar todas as antigas propostas implementadas.


## Fechamento da consolidação física e revisão residual

Em 13/09/2026, o checkout principal recebeu fast-forward protegido por `--no-overwrite-ignore`; seus ignorados foram preservados. As 27 worktrees de execução foram arquivadas e removidas. Resta somente `C:/Users/adrie/Documents/Coelo`, branch dev. As cinco skills e a referência comum estão nesse destino. Stash vazio. Os commits e branches históricos permanecem preservados; sua divergência histórica não é trabalho ativo pendente de push.

O bundle final `coelo-final-refs.bundle` foi verificado antes da última remoção, com todas as refs até eecbfa146. O manifesto `verified-final-worktrees.json` preserva os 191 ignorados da C0, além dos 1476 ignorados das 26 anteriores. O runtime foi copiado para o backup externo/runtime-r10 e servido nas mesmas portas 3000/3016: SHA256 main.dart.js b3f3c8c80606a6367b1b7cd69178c1a18c4036e8af7d4a890dbbbb06d40fed42, igual ao build da R10. Não houve rebuild nem novo deploy remoto nesta consolidação.

Revisão independente por conteúdo do auxiliar `/root/chat_upload`, ACK recebido, confirmada por C0 contra os sucessores ancestrais de dev. A lista anterior de nove candidatas retidas fica superada por esta classificação:

| Referência histórica | Destino do conteúdo / sucessor |
| --- | --- |
| R02 d01 autenticação | 36e8e4c0 e 4b2c5611e: candidato revisado e aplicação atômica; baseline 7ce4337b1 |
| R02 d02 estrutura | 6b03f26eb e cb9eb15a5: reservas sucedidas; baseline posterior |
| R02 d03 acompanhamento | 9554aaa3d: CHILD revisado e baseline posterior |
| R02 d04 acessos | 7ce41f86b e ecc8eae2b: child-safety serializado; baseline posterior |
| R02 l00 coordenação | Histórico documental, sem código; processo vigente ADR0036 em 0d212729b |
| R02 l01 publicações | b522760e7 e 1e39b2fcf, seguidos pelas reconstruções R08 de Circular/Momentos |
| R02 l02 chat | 2fde6ff46 e 2b1293227 no contrato; 2b1cf2f00 e correções seguintes no cliente |
| wip/fase0-arquivo-chat | Conteúdo integrado em d0fd94c07, fechamento posterior ca2f86531 |
| noturna-copia-previa | Texto absorvido por 1e39b2fcf e fechamento 03f8bc0b8 |

Não foi identificado delta funcional a aplicar dessas versões antigas. Handoffs, provas e propostas históricas continuam acessíveis por suas refs e bundles; não são certificados como comportamento atual. Nenhuma migration foi reaplicada. A classificação não afirma que todas as pendências do produto foram resolvidas.

O gate de entrega recebeu revisão adversarial e 18 testes aprovados: destino real, base anterior válida, inventário incluindo remoções, refs locais/remotas, sucessor integrado, referência comum das skills e camadas abertas impedindo falsa conclusão. O gate não substitui conferir manualmente os pedidos do Owner nem provar o app. Consumo real no fechamento da consolidação: 84%. Pendências de produto continuam no relatório completo por tela e nos três rastreadores.

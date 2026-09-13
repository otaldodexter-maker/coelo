---
source: Owner, 13/09/2026; Git real; backups verificados
status: consolidação de workspace em execução; histórico semântico parcialmente revisado
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

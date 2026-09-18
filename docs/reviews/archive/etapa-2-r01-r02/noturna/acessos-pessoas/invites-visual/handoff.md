---
fonte: "GOLDEN-REBASELINE-CRITERIO r12; invite_golden_test.dart; commits em causes.json"
status: "local-green; publicacao pelo coordenador do grupo"
data_geracao: "2026-09-09"
---

# Convites: reconciliacao visual nominal

Recorte: apps/superadmin -> Comunicacao -> Convites -> diretorio cards/tabela/hover/flyout, confirmacao de revogacao, formulario inicial e detalhe. Mapeamento pelo pai: invites.list (diretorio/hover/flyout), invites.create (formulario), invites.detail (detalhe), invites.revoke (confirmacao). Apenas referencias visuais; nenhum aceite funcional ou FE/BE/E2E promovido. Contrato: resolver somente 5 testes vermelhos conhecidos, com 9 PNG, preservar confinamento R02 e encerrar ao comparator focal verde. Sem Dart, shared, router, SQL, SMTP, mutacoes reais ou rastreadores centrais.

Resultado unico do plano N=5: P=5, F=0, B=0, S=0, U=0; 9/9 comparacoes PNG aprovadas. RED inicial 5 F e execucao de confirmacao 5 P sao tentativas dos mesmos IDs, nao 10 testes distintos. Nenhuma falha funcional observada. Logs red.txt e green.txt preservados em UTF8 sem BOM, LF, sem espacos finais.

Cada um dos 18 renders foi aberto e inspecionado antes de substituir qualquer baseline. renders.json lista exatamente os 9 paths alterados, hashes antes/depois e confirmacao de inspecao. Cada subdiretorio conserva before.png e after.png. A substituicao foi copia exata dos testImage inspecionados, sem alteracao manual da imagem nem geracao de novo desenho.

## Causas integradas

- 52735a18d: Circulares mudou de Comunicacao para Coelo (Principal). Nos 6 renders desktop, Governanca ocupa a linha liberada; conteudo dos formularios, detalhe e tabela permanece visualmente igual. No detalhe e formulario escuros, nenhuma mudanca desconhecida de cor.
- d9232a94d: shell compacto substituiu hamburger/marca grande por Coelo com seta; cabecalho e corpo deslocaram 16 px nos 3 renders mobile. Tipografia e conteudo de Convites preservados.
- a0be1abeb: CoeloAdminExpandableStatusIndicator, consumido em invite_directory_widgets.dart, adotou alvo minimo 48 mantendo circulo 24. Cards aumentaram 24 px na altura; flyout acompanha a nova posicao do rodape. Confirmacao de revogacao conserva o mesmo dialogo e texto, com diferencas apenas no fundo (card/sidebar).
- d4374e399: SuperadminFormFrame moveu footer compacto para depois do corpo no scroll. Formulario mobile mostra Continuar/Cancelar imediatamente abaixo dos campos, enquanto desktop conserva rodape inferior. Diff especifico inspecionado; comportamento intencional de alcance das acoes, ja integrado. Nenhuma alteracao local no contrato.

causes.json resolve os quatro SHAs completos e confirma ancestry em HEAD. Nao houve drift residual sem causa dentro destes nove renders.

## Prova e proximo passo

Comando unico por tentativa: `rtk proxy flutter test --no-pub test/features/invites/invite_golden_test.dart --reporter expanded`. Comparator final exit 0. `git diff --check` focal exit 0. Nenhum analyzer necessario: somente PNG e evidencias foram alterados.

Sessoes RED 17507 e comparator 34015 encerradas; nenhum recurso remoto, filho ou processo auxiliar criado. Slot Flutter devolvido ao pai. Proximo passo: pai inspecionar pares e publicar os 9 PNG com evidencias, sem promover contratos reais de Convites. Memoria: nenhuma regra duravel nova; apenas baseline sincronizada com contratos existentes. Gate FE permanece restrito a esta prova visual; BE e E2E nao executados neste recorte.

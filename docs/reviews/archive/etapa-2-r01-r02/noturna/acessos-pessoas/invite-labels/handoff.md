---
source: "E2-noturna-transversal-por-dono-20260909.md; sonda nominal na base6aa+6f4c24c03"
status: "falha de rotulo confirmada; componente shared reservado ao coordenador"
generated_at: "2026-09-09"
---

# Convites: no de longPress sem rotulo identificado

apps/superadmin -> Comunicacao -> Convites -> diretorio /dev/invites carregado -> invites.list. Caso unico em1440x900, claro, texto100%, fonte padrao do harness. A sonda usa router e fixtures de desenvolvimento, exige cards com itens e nenhuma excecao de layout. Nao envia nem modifica convites; confinamentoR02 intacto.

Resultado **0P/1F** em labeledTapTargetGuideline. probe.txt reproduz o candidato da triagem; diagnostic.txt repete somente esse caso acrescentando identificacao do no e seus ancestrais. Contagem unica1F, nao2. SemanticsHandle descartado em finally, sem erro do instrumento. Nao se ocultou semantica.

No violador42: rect814,24..942,72 (128x48), actions focus/longPress, sem label. Ancestrais medidos: Semantics -> OverlayPortal -> RawMenuAnchor -> MenuAnchor -> CoeloAdminFlyout<InviteDirectoryTableView> -> SuperadminDirectoryViewToggle<InviteDirectoryTableView>. Portanto agora ha identificacao concreta; nao e mera suspeita generica de longPress.

Fonte propria consumidora: invite_directory_widgets.dart:91 monta o toggle. Fonte compartilhada: apps/superadmin/lib/shared/presentation/widgets/superadmin_directory_view_toggle.dart:43/44 define64x2=128; linha123 instala GestureDetector.onLongPressStart sobre os dois segmentos, abrindo o menu na metade tabela. Os icones internos tem labels Exibir como cards/tabela; o no adicional de longPress nao herda um rotulo. Nao e devtools.

Proposta para Claude: atribuir semantica explicita a acao de abrir opcoes de tabela, preservando os dois segmentos, foco/Alt+Down, hover e longPress. Provar o no pai rotulado e as acoes existentes; nao remover a semantica para fazer a diretriz passar. O arquivo e compartilhado/reservado: nenhum patch aplicado por este grupo. A prova de rotulos Safety2P continua restrita as duas composicoes medidas ali; nao e certificado geral desse componente.

Fonte exata preservada como invite_directory_labels_probe.dart fora da suite regular; copiar para apps/superadmin/test/app/router/invite_directory_labels_test.dart e executar flutter test --no-pub nesse arquivo a partir de apps/superadmin. Remover a copia apos diagnostico. Falha permanece explicita nas metricas, sem skip ou CI permanentemente vermelho. Runners21066 e79598 encerrados.

Nenhuma promocao FE/BE/E2E, alteracao de produto, regra nova de memoria, chamada remota ou recurso ativo. Proximo passo: coordenador corrigir/reservar o hunk compartilhado e repetir este caso apos mudanca material.

---
source: "C00; C06r5; C07 evidence; approved design 2026-09-01; spec036; C01 RED"
status: "decisions-published;corrections-pending"
generated_at: "2026-09-08T18:33:32-03:00"
timezone: "America/Sao_Paulo"
---

# R01-VISUAL-1835


1. **Cabeçalho administrativo mobile aprovado:** spec `docs/superpowers/specs/2026-09-01-superadmin-estruturas-finalizacao-design.md`, status approved-design, linhas52–54, determina logoCoelo+chevron semhambúrguer e Bug acessível. C00 confirma essa aprovação existente; não precisa nova decisãoOwner. Corrigir a afirmação C07 de ausência de aprovação localizada para esse aspecto de d9232a94. Isso não aprova todos os pixels, conteúdo ou77goldens. Anterioridade dos77 no baselineR01 é evidência; atribuição causal de todos ao mesmo commit continua hipótese.
2. **Shell _PageHeader:** deslocamento de título compacto com actions permanece defeito independente da aprovação do appbar. C00 mantém reserva de superadmin_shell.dart; revisão/correção proporcional em fila. C07 não modifica shell nemregenera masters.
3. **Chat:** borda/canto do inbox cobertos pelo footer se corrigem no consumidor `apps/superadmin/lib/features/chat/presentation/screens/superadmin_chat_page.dart`, que já pertenceC05; preservar geometria e pintura de borda. Não reservar nem mudar globalmente SuperadminListingPaginationFooter por esse caso. C05 coordena seu subagenteChat e usa reprodução C07, sem executar o mesmo teste em paralelo.
4. **Agora:** comparação1200 dentro de bodyMaxWidth1120 torna ramoamplo inalcançável. Spec036 linhas27–36 aprova mídia ampla/colunaeditorialenxuta em1440. C05 pode corrigir o cálculo no consumidor `apps/superadmin/lib/features/principal_now_publication/presentation/principal_now_publication_page.dart` (path real conferido por C00). Não alterar sharedPrincipalPublicationFrame nemnovo layout por conjectura. Referência ao nome do arquivo é reserva apenas dessa página jáC05. Recuperar o recibo da instruçãoOwner já relatada sobre “não tem wizard lateral” e a referência exata do publicador, sem pedirOwner de novo. Não restaurarrail nem aprovar13goldens automaticamente por3419a89e. Correção do breakpoint independe de redesenho/ratificação global.
5. **Acessibilidade seletormúltiplo:** C01 reproduziu RED consumidor: opção Instituição1 semSemanticsAction.tap (0PASS/1FAIL). C00 confirmou Semantics substituto/ExcludeSemantics semonTap. Reserva C01I012: componente packages/coelo_ui_admin/lib/src/filter/coelo_admin_multi_select_field.dart e teste existente packages/coelo_ui_admin/test/filter/coelo_admin_multi_select_field_test.dart. Alteração mínima+testeação semântica, manterdraft/Aplicar/Cancel/disabled/teclado/visual. Ainda sem correção integrada/certificação.

Fontes: C06r5; evidências originais C07 nos arquivos C07-evidence/2026-09-08-laudo-goldens-c05-cea29b1f.md e2026-09-08-c04-suite-observacao-9b076a1d.md; revisão independente C00 e consulta direta às specs acima. Contratos backendantigos citados na spec036 (Storage/ADR0026) permanecem substituídos porADR0032; esta decisão usa somente as linhasUX, não reabre Storage. Nenhum percentual de implementação ou golden atualizado.

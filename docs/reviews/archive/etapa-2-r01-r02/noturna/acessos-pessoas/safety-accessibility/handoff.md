---
fonte: "E2-noturna-transversal-por-dono-20260909.md; probe nominal local; coordenacao r18"
status: "diagnostico executado; correcao shared reservada ao coordenador"
data_geracao: "2026-09-09"
---

# Safety: diretrizes nativas

Recorte apps/superadmin -> Acessos -> Seguranca infantil -> diretorio carregado -> child-safety.list. Somente investigacao de rotulo, alvo Android e contraste em 1440x900 claro, texto100%. Base conjunta informada c526307dd; sem produto alterado. Pai investiga reflow separadamente.

Plano unico N=6: rota real /dev/safety e SafetyLandingPage direta com DevChildSafetyRepository.content, cada uma com tres diretrizes. Resultado valido **P2 F4 B0 S0 U0**: rotulo passa nas duas; alvo e contraste falham nas duas. Todos os seis verificaram Alice Duarte carregada apos 12 pumps de100ms, sem excecao de layout. Loading eterno e rotulo falho da triagem antiga d784 nao reproduzidos nesta base. Nenhuma semantica excluida para aprovar o teste.

O primeiro instrumento teve erro proprio de lifecycle: SemanticsHandle era descartado em addTearDown, tarde para a verificacao Flutter. probe.txt preserva essa tentativa invalida, que nao deve contar como produto F6. Corrigido para finally; probe-corrected.txt e resultado valido. Fonte final preservada em safety_accessibility_probe_test.dart, fora da suite regular por instrucao do pai para nao estabelecer falhas cronicas em CI.

## Achados e fontes

- Alvo Android: unico no violador em ambas composicoes foi menu do usuario do shell, label OC/Owner Coelo/Superadmin e tooltip Abrir menu do usuario,173.1x44. Fonte apps/superadmin/lib/app/shell/superadmin_shell.dart:1682: InkWell sobre Padding vertical space1 (4 por lado) e CircleAvatar radius18 =>36+8=44. Proposta nominal: ConstrainedBox minimo48 no alvo, preservar avatar36 centralizado, teclado e semantica; provar toque na borda e menu. Nao aplicado (shared reservado).
- Contraste: subtitulo do shell e tabs Atencao11/Autorizadas126/Sem autorizacao9, razao nativa3.50 contra4.5; reticencias de paginacao2.16 contra4.5. Mesmo conjunto em ambas composicoes. Fontes: superadmin_shell.dart:1553/1592 usa onSurfaceVariant; shared/presentation/widgets/superadmin_underline_tabs.dart:261 usa onSurfaceVariant em inativas; packages/coelo_ui_admin/lib/src/listing/coelo_admin_pagination.dart:171 const Text de reticencias herda estilo.
- Nao confundir cor declarada e amostragem da diretriz: packages/coelo_tokens/lib/src/coelo_theme.dart:705 declara onSurfaceVariant=neutral600, palette:23 define #596166. A diretriz renderizada computou #848A8E para os quatro textos e #ADB1B3 para reticencias. Isso requer verificar rasterizacao/estilo herdado e render nominal antes de decidir mudanca global de token. A falha medida permanece aberta; nao foi descartada como falso positivo.
- Proposta contraste: inspecionar render e estilo efetivo desses cinco nos com a fonte Nunito Sans carregada, escolher token textual aprovado que passe4.5 e provar as duas composicoes. Para reticencias dar estilo explicito legivel quando a causa for heranca. Nao ocultar semantica nem editar PNG para mascarar. Nao foi aplicado patch shared ou definido novo token.

O probe nao injeta devtools nem longPress artificiais. Usa createSuperadminRouter com allowDevelopmentPreview e composicao de pagina sem router; ambos rotulos passam. LongPress nativo encontrado no controle compartilhado superadmin_directory_view_toggle.dart:123 abre menu do lado tabela, nao em ferramenta de desenvolvimento. Portanto nao ha evidencia atual para atribuir a falha antiga de rotulo a longPress da propria Safety nem a devtools. Instrumento original nao localizado por leitura focal na worktree operacoes-sistema; limite explicitado.

## Reproducao e limpeza

Copiar este safety_accessibility_probe_test.dart para apps/superadmin/test/features/safety/presentation/safety_accessibility_probe_test.dart e executar na pasta apps/superadmin: `rtk proxy flutter test --no-pub test/features/safety/presentation/safety_accessibility_probe_test.dart --reporter expanded`. Remover a copia apos diagnostico. Fonte usa somente imports package, fontes locais e fixtures; nenhum recurso remoto.

Sessoes90066 e81819 encerradas; Flutter devolvido ao pai. Nenhum filho, Git, produto ou recurso remoto modificado. Proximo passo: Claude reservar correcao nominal shared do alvo44 e apuracao dos contrastes medidos. Nenhuma promocao FE/BE/E2E; memoria sem regra nova. Logs UTF8 sem BOM/LF, hashes.json preserva evidencias.

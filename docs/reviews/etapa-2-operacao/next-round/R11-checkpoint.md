---
source: Owner 2026-09-13; R11-prompt-unico.md; Git e quota reais
status: execução R11 em andamento
generated_at: 2026-09-13
---

# R11 — checkpoint C0

T0 real: 2026-09-13T10:47:39-03:00. Base HEAD=origin/dev 1d2f95b5942f5aab23439151b57853dd3180b041 após fetch. Destino e única worktree: C:/Users/adrie/Documents/Coelo, dev. Escritor/integrador C0 /root; execução serial, sem auxiliares. Status inicial limpo; stash vazio. Refs históricas preservadas conforme R10-consolidacao, sem reabrir R10.

Quota U0=87% usados, indicador codex primary, janela 10080 minutos, reset epoch 1789820315 (2026-09-19T12:18:35+00:00). Teto min(87+12,98)=98%; congelar novas fatias em95%; alvo fechar até97%. Medir a cada10min, entrega e antes de build. Limite execução13:47:39BRT, fechamento14:17:39BRT; cota prevalece, reset não estende rodada.

Runtime preservado: PID17204, Python serve.py, build apps/superadmin/build/principal-pos-r10, origem http://127.0.0.1:3000. Código build01833e90b, hash a conferir antes de prova. Chrome Owner PID18924 preservado; slot Chrome QA C0 reservado, ainda sem PID. Slot flutter test C0 reservado e ocioso; dart17780 é MCP, não teste. Nenhum processo encerrado.

## Contrato e pendências

Objetivo: maior conjunto coerente no corte, apps/superadmin > Conta/Meu perfil (família Perfil/Configurações, rodapé Criar/Editar Instituição), Auth e Estrutura > Atividades/Avaliações/Turmas. Ordem A0 account.profile; A auth.recover/auth.reset (inspeção até20min sem evidência nova); B activities.assessment/activities.publish; C assessments.entry/gradebook/detail/close/reopen; D groups.list independente pode antecipar. Só uma vizinha institutions.status ou institutions.locations-map se tudo fechar com margem.

Conta: foto no editor/header com sigla relatados; nome suspeito e cor relatada, ainda sem reprodução após Save/reload. Rodapé e Meu acesso longos requerem correção focal. Auth: SMTP/link real/nova sessão/expiração e uso único sem certificado. Atividade UPDATE draft b04c879e retorna SAI_INTERNAL_ERROR; diário d2c945d8 sem participantes apesar de vínculos; Turmas contadores0. Reutilizar IDs completos das evidências; não recriar nem reaplicarSQL61/62/63.

Provas: rota normal, salvar e reload no mesmo recurso, negação RLS pertinente, testes focais causais; FE/BE/E2E separados. Nenhum aceite novo na abertura. Estimativa do delta ainda não calculável antes de reprodução; janela é limite, não estimativa. Primeiro gate C0: reproduzir Conta no build preservado, inspecionar controller/repository/header e catálogo de capacidades. WIP inicial nenhum; leituras e inventário focal em andamento.

Fora: R12, Etapa3, auditoria231ações, redesign Chat. Preservar direção/anexos via docs/design/chat-media-composer-owner-reference-20260913.md; preservar Principal-pos-R10 e pendências próprias. SQL somente forward, pgTAP/ordem/PITR conforme pedido atual; nenhum remoto alterado na abertura.

## Checkpoint 11:05 BRT

Quota88% (última leitura), janela/reset iguais. QA Chrome PID31192/CDP9427, C0; runtime17204/3000 preservado, slot Flutter ocioso. Build preservado usado pela rota produtiva /profile após login normal. Harness corrigido para teclado nativo, foco emulado e janela QA normal; Chrome Owner preservado. Cor #336699 após Salvar/Perfil atualizado voltou a #FFF1EB após reload. Regression account.profile FE/BE/E2E pending-verification, histórico preservado. Três matrizes validadas176/231FE,161/224BE,149/199E2E. Nome ainda não reproduzido, foto sem transporte no repository/RPC; sigla validada mas não gravada no servidor.

Preflight Management API14:04:42Z: pitr_enabled=false, backup_count0; SMTP próprio ausente. R11 exige PITR, diferente da exceção ADR0034D8 usada na R10; não aplicar SQL sem resolver esse requisito. Preparar correções locais e seguir partes independentes. WIP: harness/evidência, registro de compromissos e matrizes; nenhum código de produto alterado ainda. Próximo C0: rodapé/Meu acesso, confirmação autoritativa e contrato local; Auth inspeção curta sem repetir envio.

## Checkpoint 11:23 BRT

Quota89% usados, janela/reset iguais. Base avançou com documentação externa eaa8e9af6/a6bc5bb4c sobre R12; preservada sem alterações nos arquivos C0. R11 não inicia R12. Commits próprios anteriores ed4e19b25/e4d9ffcc8 publicados. Slots C0: Chrome31192/CDP9427, runtime17204/3000; Flutter ocioso após37 testes focais PASS e análise sem problemas. Docker local iniciado e saudável, sem reset/replay.

Conta: rodapé padrão fixo no contêiner, Meu acesso com busca/rolagem limitada, confirmação do perfil retornado pelo servidor implementados localmente. Grupos por módulo/escopo permanecem abertos: RPC só entrega descrições. Foto/cor/sigla persistidas ainda exigem contrato backend. Nenhum aceite E2E novo; build/prova UI pendentes. Auth: rota normal Login > Esqueci minha senha > solicitação sintética mostrou Confira seu e-mail às11:21; busca na caixa acessível sem mensagem. Sem troca de senha nem geração Admin API. Bloqueio de entrega SMTP/caixa não resolvido; seguir Estrutura. PITR segue aguardando esclarecimento da regra conflitante, sem SQL remoto aplicado.

Próximo C0: compilar fatia local de Conta e provar rodapé/busca/confirmação; preparar correções causais de Estrutura localmente. WIP de código preservado no checkout; estimativa operacional desta fatia mais prova20–35min, condicionada ao build, sem estimar contrato R2 ainda não inspecionado.

## Checkpoint 11:38 BRT

[Evidência focal](../../evidence/etapa-2/r11-coordenacao/checkpoint-1136.md): build Conta ebf7f23e2 PASS, runtime34876/3000, Chrome31192; Flutter ocioso. SQL avaliativo candidato20260913143441 com8/8 pgTAP PASS no espelho próprio coelo_r11 após167 arquivos na ordem real. Sem aplicação remota por PITR pendente. Turmas contadores reproduzidos; matrizes sincronizadas175/231FE,159/224BE,148/199E2E por regressões reconhecidas, sem novos aceites integrais. Cota89%, janela/reset inalterados. WIP: candidato local e evidências; próxima fatia causal Turmas. Referências e WIP externos da R12 preservados; HEADexterno14a89cc41 incorporado somente como documentação.

## Checkpoint 11:49 BRT

Cota90%, mesma janela/reset. Candidatos locais: avaliação8/8, Turmas10/10 (contadores/herança/status/tenant), Conta9/9 (sigla/cor/reload/metadados/receipt de outra sessão/anon) pgTAP PASS. Conta FE negocia contrato2 informado pelo servidor; continua compatível com contrato1 atual. Dois testes novos de repository/grupos PASS e analyze focal sem problemas. São39 testes Flutter únicos aprovados na rodada e27 pgTAP, sem somar reruns. Harness de widget corrigido para HTTP/dispose em runAsync; duas execuções ficaram sobrepostas por encerramento pendente e foram interrompidas, slots reconciliados; nenhuma prova concorrente aceita como final. Flutter agora ocioso, Chrome31192, runtime34876 com build ebf7f23e2. Próximo build após commit desta fatia, sem alterar runtime durante prova.

Foto R2 ainda não implementada; não confundir sigla/cor com aceite integral account.profile. Contrato SQL corrige replay de save por ator: request_id de outra conta não pode devolver identidade anterior. Diário retido: participation_mode=all,0 participantes selecionados, snapshot0; preparar elegibilidade all sem duplicar vínculo. SQL remoto continua aguardando decisão PITR; cf1b7ee70 publicado e candidaturas preservadas. Próximo C0: build/prova focal Conta, diário all/selected local. Não há novo E2E.

## Checkpoint 12:12 BRT

Cota91%, mesma janela/reset; C0 serial, Flutter ocioso após testes. Conta build c17ca4cb7 PASS116,6s, runtime36632/3000, Chrome31192. Nome Operador R11 persistiu no save/reload; nome original Operador interno restaurado via UI. Principal preserva publicação R10; seu header ignorava avatarBackgroundColor e usava cor do tema: propagação/contraste corrigidos localmente,12 testes header/navegação PASS. Crop da Conta aplicado duas vezes: bytes já rasterizados agora ficam com escala1/deslocamentozero, teste focal PASS. Total52 Flutter únicos PASS na rodada, sem somar reruns.

Diário candidato20260913145023: modo all inclui aluno elegível sem criar participante; draft retido vazio projeta aluno até salvar nota no mesmo ID.13/13 pgTAP PASS cobrem nota/releitura/submeter/revisar/reabrir/versão antiga/selected/hierarquia/tenant. Total40 pgTAP únicos PASS nos4 candidatos. SQL continua somente local; próximo gate remoto é decisão PITR pendente, depois backup/ordem/aplicação e rota normal. Cota/tempo ainda permitem uma fatia de foto; inspecionada ausência de gateway Conta e de catálogo de avatar R2, sem reutilizar domínio Chat/Formulários indevidamente. Preparar transporte privado focal, respeitando recorte/variantes e limpeza, sem dependências novas; congelar se não houver margem.

Auth inexistente confirmado no Auth (exists=false) e UI genérica igual à solicitação real; auth-nonexistent.png. Caixa acessível segue0 mensagens para QA. MX coelo.me aponta para próprio domínio162.240.81.81; não certifica existência/acesso da caixa. SMTP próprio ausente; serviço padrão restringe destinos à equipe do projeto conforme documentação Supabase auth-smtp. Nenhum reset/token/link produzido nem senha trocada. Sem ampliar espera ou invitar QA à organização como contorno.

## Checkpoint 12:32 BRT

Cota real mais recente91%, mesma janela/reset, sem ampliar teto98/congelamento95. Commit d20bcfcf2 publicado em dev. Runtime C0 PID39272/3000 com build r11-account-v3, codigo d20bcfcf2, JS1dd04dca028d7b48e0909895ed5885641dfd434c1cd655c89a0dd603b217db36. Build75,3s PASS; analyze focal PASS. Chrome QA31192 e Owner18924 preservados; slot Flutter ocioso. Analyze e build chegaram a sobrepor na abertura desta verificacao por sessao de analyze ainda pendente; ambos terminaram, sem iniciar outro lote concorrente. Nao usar essa sobreposicao como pratica de rodada.

Conta: nome original restaurado e confirmado por reload; cancelar descarta rascunho; footer acessivel desktop/mobile, busca e scroll limitado observados. Principal usa a mesma sigla/cor persistidas, sem cor de tema fixa. Foto pelo picker normal com PNG estatico de marca, recorte ajustado igual ao editor; Save informa ausencia de confirmacao, reload conserva sigla. Persistencia/remocao R2 seguem abertas. Nao ha gateway/catalogo Conta existente; uma entrega dessa cadeia exige verificacao real de imagem, variantes64/128/256/512, ownership, bind/remocao e limpeza, alem do gate remoto bloqueado. Nao foi criado transporte parcial nem dependencia nova. Proximas correcoes locais sao apenas as necessarias para fechar a fatia revisavel; nao prometer aceite da foto.

Quatro goldens antigos falharam pela mudanca autorizada do rodape/Meu acesso; renders375/768/1024/1440 inspecionados, baselines automatizadas atualizadas e4/4 PASS. Nao equivalem a aprovacao visual A do Owner. Texto200% e150 permissoes em375/1440:2/2 PASS. Total58 Flutter unicos PASS;41 pgTAP unicos PASS (40funcionais e1diagnostico adicional, sem repetir3asserts de fixture). SQLSTATE local sanitizado23503:assessment_gradebooks_period_id_institution_id_fkey confirma DELETE indevido de outra configuracao; transacao diagnostica fez rollback e preservou candidato corrigido. Em producao, somente envelope SAI_INTERNAL_ERROR/correlation ja capturado; nao alegar SQLSTATE remoto.

Backup logico de schema do lote em andamento fora do Git; nao substitui PITR nem autoriza aplicacao. Quatro candidatos locais aguardam decisao sobre exigencia explicita da R11 versus excecao ADR0034D8. Atividade retida95b98978 ja esta active em producao; configdraft b04c879e nao e ID de atividade. Nao despublicar/republicar nem criar rascunho para inflar activities.publish. WIP: goldens/provas, README de replay e registros; sem nova rodada ou alteracao dos anexos de chat/R12.

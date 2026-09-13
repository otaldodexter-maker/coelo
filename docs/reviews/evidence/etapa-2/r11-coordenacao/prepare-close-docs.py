from pathlib import Path
from datetime import datetime, timezone
import json
import subprocess

root=Path(__file__).resolve().parents[5]
folder=root/'docs/reviews/etapa-2-operacao/next-round'
evidence='docs/reviews/evidence/etapa-2/r11-coordenacao/'
close='docs/reviews/etapa-2-operacao/next-round/R11-fechamento.md'
pending='docs/reviews/etapa-2-operacao/next-round/R11-pendencias.md'
now=datetime.now(timezone.utc)
metrics=json.loads((root/evidence/'closure-metrics.json').read_text(encoding='utf-8'))
table='\n'.join(f"| {m['name']} | {m['before']['count']}/{m['before']['denominator']} ({m['before']['percent']:.2f}%) | {m['after']['count']}/{m['after']['denominator']} ({m['after']['percent']:.2f}%) | {m['deltaPercentagePoints']:+.2f} |" for m in metrics['metrics'])
front='---\nsource: Owner R11 2026-09-13; R11-checkpoint.md; inventario-etapa-2.json; evidence/etapa-2/r11-coordenacao\nstatus: fechamento parcial em verificacao\ngenerated_at: 2026-09-13\n---\n\n'
(folder/'R11-fechamento.md').write_text(front+'''# R11 — entrega parcial

C0, executor/integrador serial, checkout consolidado `C:/Users/adrie/Documents/Coelo`, branch dev. T0 real2026-09-13T10:47:39-03:00, base origin/dev1d2f95b5942f5aab23439151b57853dd3180b041. R10/extensao preservadas; nenhuma retomada de worktree antiga, R12 ou Etapa3 iniciada. Documentacao concorrente do Owner para R12 foi preservada no mesmo checkout.

## Resultado e corte operacional

Foram implementadas e publicadas fatias de Conta e quatro candidatos SQL locais. Nenhum novo action_id recebeu aceite integral E2E. A entrega continua parcial: PITR permanece desligado e a regra explicita desta R11 aguarda esclarecimento frente a excecao anterior; Auth nao recebeu mensagem real na caixa acessivel; foto ainda nao possui catalogo/gateway de persistencia R2. As proximas provas funcionais de Estrutura exigem o lote remoto. Nao abrir a acao vizinha condicional, pois Conta/Auth/Estrutura nao terminaram.

Abertura87% usados; ultima leitura92%, consumo5p.p. Janela semanal10080min, reset1789820315 (2026-09-19T12:18:35Z); teto98%, congelamento95%, reserva3p.p., alvo de fechamento ate97%. O limite nao foi atingido nem usado como meta de consumo. O corte e antecipado por dependencias de entrega: evitar iniciar uma cadeia nova de foto sem poder aplicar/provar sua persistencia. A foto permanece pedido aberto, nao foi reclassificada fora de escopo. Maximos originais13:47:39BRT execucao/14:17:39 fechamento preservados; nenhum reset estende a rodada.

## Por tela/subtela

Todas as linhas pertencem a Etapa2 / apps/superadmin. Historico abaixo nao vira prova atual.

| Menu > tela/subtela | action_id | FE | BE | E2E / primeiro gate |
|---|---|---|---|---|
| Meu perfil > identidade/acesso/header | account.profile | parcial; footer/busca/cancelar/nome/reload/crop/header corrigidos/provados focalmente | candidato sigla/cor/metadados9/9; foto ausente | pendente; aplicar contrato e completar R2 privado/remocao/reload |
| Auth > Esqueci minha senha | auth.recover | verified historico; pedido normal/generico atual observados | pendente entrega SMTP/caixa | obter mensagem real e redirect local autorizado |
| Auth > Redefinir senha | auth.reset | verified historico; nao reprovar como prova atual | pendente | link real, nova senha/sessao, expiracao e uso unico |
| Estrutura > Atividades > Configuracao avaliativa | activities.assessment | pendente; erro reproduzido no mesmo draft | local-green8/8 + diagnostico23503 | aplicar candidato, salvar b04c879e e reload |
| Estrutura > Atividades > Publicar | activities.publish | local-green historico | done historico | pendente; config corrigida antes da cadeia; atividade retida ja active |
| Estrutura > Avaliacoes > Entrada | assessments.entry | pendente; aluno ausente reproduzido | local-green candidato all/selected | aplicar e abrir aluno no diario retido |
| Estrutura > Avaliacoes > Diario | assessments.gradebook | pendente | local-green | salvar nota no mesmo d2c945d8 |
| Estrutura > Avaliacoes > Detalhe | assessments.detail | pendente | local-green | reler nota persistida |
| Estrutura > Avaliacoes > Fechar | assessments.close | pendente | local-green | fechar/reler estado/versao |
| Estrutura > Avaliacoes > Reabrir | assessments.reopen | pendente | local-green | reabrir/reler e negar escopo alheio |
| Estrutura > Turmas > Contadores | groups.list | pendente; zeros falsos reproduzidos | local-green10/10 | aplicar projecao, UI/reload com contagens reais |

Responsavel das correcoes/provas: C0 integrador na retomada explicitamente autorizada; Owner resolve regra PITR e acesso/configuracao de e-mail. Coelo (Principal) e menu hospedado: header recebe mesma sigla/cor; demais composicoes/publicacoes R10 preservadas. Referencia de chat permanece para rodada posterior Etapa2; sem redesenho global nem A visual inventado.

## Sete metricas e ponte com a base

Geral conhecido,231acoes/39familias; BE224, E2E ativo199. Censo atual por IDs em [closure-metrics.json](../../evidence/etapa-2/r11-coordenacao/closure-metrics.json). Escopo R11 tem11IDs: FE2/11 verified historicos, BE1/11 done historico, E2E0/11; nenhum desses historicos e ganho R11. FE local-green1/9 pendentes; BE local-green7/10 pendentes. Demais avancos parciais de Conta nao viram acao inteira.

| Indicador | Base abertura | Atual | Delta p.p. |
|---|---:|---:|---:|
'''+table+'''

A queda estrita reconhece regressao preexistente de Conta/Turmas e BE da configuracao; nao e perda introduzida pelas correcoes locais. FE local caiu pela retirada da classificacao de entrada com aluno ausente. BE local aumenta com dois candidatos causais. Visual54 e SQL181 sao os mesmos IDs historicos da ponte R10, sem nova certificacao visual ou contagem de migrations/screenshots. Remapeamento0; nao certifica todas as231 acoes, MVP completo, V1 ou outros apps.

## Testes e provas

- Flutter focal:59 casos unicos P,0F/0B/0S/0U no conjunto executado;59/59 aprovados. Inclui Conta/controller/repository, Principal header,4goldens, texto200% e teclado mobile/Tab com rodape acima de300px de teclado. Nao representa suite completa do app.
- pgTAP focal:41 asserts unicos P,0F/0B/0S/0U. Conta9, configuracao8, Turmas10, diario13, diagnosticoSQLSTATE1; os3 asserts de fixture repetidos no diagnostico nao entram de novo. Nao somar esses asserts aos casos Flutter.
- UI: [31 subaceites planejados](../../evidence/etapa-2/r11-coordenacao/ui-acceptance-plan.json), P11/F5/B14/S0/U1. Executados16/31 (51,61%); aprovados11/16 (68,75%), falhos5/16 (31,25%); plano aprovado11/31 (35,48%). P parcial nao certifica action_id integral.
- Analyze focal e build PASS. Validator visual aponta20 ocorrencias legadas fora de Conta; nao adicionar allowlist nem declarar validador verde. Renders375/768/1024/1440 do formulario inspecionados; goldens atualizados para a mudanca solicitada, sem aprovar A em nome do Owner.
- Memoria:77 artigos validos; suite12P/0F/0B/1S/0U, symlink ignorado por limitacao do host. Fonte canonica de Conta atualizada antes da projecao team. Tres matrizes consistentes.

Falhas resolvidas localmente: falso sucesso/estado otimista de perfil; cor fixa/contraste no header Principal; crop reaplicado duas vezes; DELETE de periodos de outra configuracao; contadores omitidos; modo all exigindo participantes selected. Os4goldens antigos divergiram pela alteracao autorizada e passaram apos inspecao/atualizacao. Erros de harness, path/enum de fixture e duas execucoes Flutter inicialmente sobrepostas foram corrigidos/encerrados, sem contar reruns como novos casos. Falhas funcionais remotas ainda abertas:5 no plano UI. Link real/Auth nunca foi substituido por Admin API.

## SQL, backup e runtime

Quatro arquivos em `packages/coelo_database/candidatos/`, nunca movidos para migrations sem aplicacao:

1. r11-estrutura/20260913143441_r11_assessment_update_isolation_v1.sql.
2. r11-estrutura/20260913143659_r11_group_directory_counts_v1.sql.
3. r11-conta/20260913144142_r11_account_avatar_access_v2.sql.
4. r11-estrutura/20260913145023_r11_assessment_all_participants_v1.sql.

Espelho proprio coelo_r11, PostgreSQL local54372, baseline+seed+167arquivos na ordem REAL do manifesto. Baseline antiga de outro projeto nao foi resetada. README reconciliado com manifesto existente; historico remoto61/62/63 nao reaplicado. Diagnostico original local:23503/assessment_gradebooks_period_id_institution_id_fkey, em transacao revertida. No remoto somente envelope sanitizado/correlation; nao alegar SQLSTATE remoto.

Backup schema4.154.444bytes e data4.767.603bytes, exit0, fora do Git em Coelo-backups; [hashes/limites](../../evidence/etapa-2/r11-coordenacao/backup-manifest.json). FKs circulares exigem procedimento de restauracao adequado; restauracao nao testada, nao e PITR e nao autoriza deploy. Preflight12:36BRT: PITR=false, backup_count0, SMTP proprio ausente, allowlist nao inclui127.0.0.1:3000/reset-password. Sem SQL, Edge ou Cloudflare remoto implantado na R11.

Build local `r11-account-v3`, codigo d20bcfcf277d91be541776007804215b93548beb, JS1dd04dca028d7b48e0909895ed5885641dfd434c1cd655c89a0dd603b217db36,75,3s PASS. Runtime Python PID39272/porta3000; Chrome QA31192/CDP9427, Chrome Owner18924 intocado, slot Flutter livre. Manifesto versionado; build anterior principal-pos-r10 preservado. Env usa projeto Supabase de producao; nome de flag staging nao cria homologacao. Push e host local nao sao deploy web publico.

## Integracao e preservacao

Commits C0 publicados: ed4e19b25, e4d9ffcc8, ebf7f23e2, cf1b7ee70, c17ca4cb7, d20bcfcf2, fe9bef6bd; fechamento adiciona commits documentais/testes. [Snapshot Git](../../evidence/etapa-2/r11-coordenacao/git-checkpoint.json). Uma worktree consolidada, sem stash na abertura; historicos/residuais preservados e classificados em entrega-atual.json, sem merge vazio, reset, clean ou force-push. Atualizacoes R12 concorrentes foram documentais e preservadas; nao significam execucao R12.

Ignorados preservados: env privado, credenciais QA fora do Git, builds R10/R11, Chrome QA e espelho local. Dados sinteticos retidos: configb04c879e-bedd-4e45-9358-66c545215646, atividad95b98978-19e2-43ba-aa0c-70ae81557e08, diariod2c945d8-3809-4d84-b836-2bc6da7c381d e turma4214106c-46a2-4bf4-84ba-9c6a619bd486. Nome QA original restaurado, senha nao alterada; nenhuma duplicacao de vinculo/config/diario. Foto de prova foi PNG estatico da marca, sem objeto remoto criado.

O gate final e executado somente apos commit/push. Este documento em verificacao nao antecipa PASS. Pendencias completas do recorte em [R11-pendencias.md](R11-pendencias.md); decisao PITR separada em docs/open-questions.md. Nao iniciar rodada posterior automaticamente.
''',encoding='utf-8')
(folder/'R11-pendencias.md').write_text(front+'''# R11 — pendencias preservadas

Entrega parcial; nao iniciar R12/Etapa3 por este registro. Retomar somente com instrucao explicita, confirmando origin/dev atual, cota e slots. Reutilizar quatro candidatos/testes locais e IDs retidos; nao reaplicar SQL61/62/63 nem criar duplicatas.

| apps/superadmin > menu > tela/subtela > action_id | FE / BE / E2E | Primeiro gate e responsavel |
|---|---|---|
| Meu perfil > Identidade/acesso > account.profile | parcial / parcial / pendente | Owner resolve PITR; C0 aplica candidato sigla/cor/metadados, prova headers/reload e implementa catalogo/gateway R2 de foto, bind/remocao/limpeza/variantes; testar outra sessao sem identidade residual |
| Auth > Recuperar > auth.recover | verified historico / pendente / pendente | Owner disponibiliza caixa/configuracao de e-mail; C0 recebe mensagem real apos pedido normal. SMTP proprio ausente; caixa acessivel nao recebeu. Nao contornar com Admin API |
| Auth > Redefinir > auth.reset | verified historico / pendente / pendente | C0 usa link real na UI, nova senha/sessao, expiracao/uso unico; atualizar arquivo privado se trocar senha. Redirect local3000 ausente da allowlist |
| Estrutura > Atividades > Configuracao > activities.assessment | pendente / local-green8pgTAP / pendente | C0 aplica20260913143441 apos gate remoto, UPDATE mesmo b04c879e, reload dos periodos; SQLSTATE23503 identificado apenas localmente |
| Estrutura > Atividades > Publicar > activities.publish | local-green historico / done historico / pendente | C0 fecha configuracao/publicacao coerente; atividade retida ja active, nao alternar status para produzir contagem |
| Estrutura > Avaliacoes > Entrada > assessments.entry | pendente / local-green / pendente | C0 aplica20260913145023, aluno aparece pelo modo all sem participante individual novo |
| Estrutura > Avaliacoes > Diario > assessments.gradebook | pendente / local-green / pendente | C0 salva nota no diario d2c945d8, sem recria-lo |
| Estrutura > Avaliacoes > Detalhe > assessments.detail | pendente / local-green / pendente | C0 rele nota e snapshot no mesmo diario |
| Estrutura > Avaliacoes > Fechar > assessments.close | pendente / local-green / pendente | C0 fecha estado/versao e rele |
| Estrutura > Avaliacoes > Reabrir > assessments.reopen | pendente / local-green / pendente | C0 reabre/rele e prova escopo remoto alheio negado |
| Estrutura > Turmas > Contadores > groups.list | pendente / local-green10pgTAP / pendente | C0 aplica20260913143659, compara linksativos/heranca e UI/reload, preservando turma sintetica |

Todos os candidatos SQL aguardam requisito de PITR. Backups logicos foram preparados, mas nao substituem esse requisito explicito. C0 nao presume resposta ausente como autorizacao; conflito ADR0034D8 versus promptR11 esta em docs/open-questions.md.

Foto: frontend ja conserva crop rasterizado sem duplicar transformacao e sinaliza ausencia de confirmacao; nao ha persistencia R2 implementada. ADR0032 exige masternormalizado/variantes64/128/256/512, MIME/bytes/dimensoes/checksum verificados, ownership/auditoria/retencao, leitura privada e limpeza. Nao usar Chat/Formularios como catalogo de Conta nem bucket publico. Conta nao ganha capa. A proxima estimativa depende desse contrato ainda nao existente, nao de quantidade de botoes.

Nao executados/condicionados: alternancia de identidade na R11 (prova R10 preservada, nao atual); entrega/reset real; cadeia remota de configuracao/notas/fechar/reabrir; remoção de foto persistida; grupos reais de permissoes aposSQL. Plano UI31:11P/5F/14B/0S/1U. Flutter59P e pgTAP41P separados; nao completam E2E. Ocorrencias legadas do validator visual20 fora de Conta permanecem fora do recorte, sem mascaramento.

institutions.status/locations-map nao foram abertos: condicao A0/A/B/C/D concluidos com margem nao ocorreu. Referencia de chat `docs/design/chat-media-composer-owner-reference-20260913.md` preservada, pendente na Etapa2 futura; nao e render A nem implantacao. Anexos do Owner permanecem na conversa, sem inventar arquivo binario nao fornecido.

Build/runtime e preservacao: r11-account-v3/d20bcfcf2/JS1dd04dca..., Python39272/3000; QAChrome31192/CDP9427, OwnerChrome18924 intocado; Flutter livre. Espelho localcoelo_r11 e builds/env/backups preservados. Uma worktree, stash vazio no checkpoint; branches historicas nao apagadas. Base de retomada e origin/dev atual, nao SHA antigo de handoff. Ver R11-fechamento.md, build-manifest.json, backup-manifest.json, closure-metrics.json e entrega-atual.json. Push nao e deploy.
''',encoding='utf-8')
delivery_path=root/'docs/reviews/entrega-atual.json'
delivery=json.loads(delivery_path.read_text(encoding='utf-8-sig'))
updates={
 'owner.r11-account-header-access':('open','partial-tested','partial-local-candidate','pending-verification','Aplicar sigla/cor/metadados apos requisito PITR e implementar/provar foto privada R2; headers/reload/remocao/outra sessao'),
 'owner.r11-auth':('open','historical-verified-current-request-only','blocked-mailbox-smtp-redirect','pending-verification','Owner: caixa/SMTP e redirect; C0: mensagem real, reset/nova sessao/expiracao/uso unico'),
 'owner.r11-assessment':('open','pending-verification','local-green-assessment-historical-done-publish','pending-verification','C0 aplica candidato apos requisito PITR, salva mesmo b04c879e e fecha cadeia normal; atividade retida ja active'),
 'owner.r11-gradebook':('open','pending-verification','local-green','pending-verification','C0 aplica all/selected apos requisito PITR; nota/detalhe/fechar/reabrir/escopo no mesmo d2c945d8'),
 'owner.r11-group-counters':('open','pending-verification','local-green','pending-verification','C0 aplica contadores apos requisito PITR e prova turma UI/reload'),
 'owner.r11-checkpoints-delivery':('done','not-applicable','not-applicable','not-applicable',''),
 'owner.r11-optional-neighbor':('deferred','not-started','not-started','not-started','Condicao de abertura nao satisfeita: concluir A0/A/B/C/D e reavaliar somente em retomada autorizada'),
}
for item in delivery['ownerItems']:
    if item['id'] in updates:
        item['status'],item['fe'],item['be'],item['e2e'],item['nextGate']=updates[item['id']]
        item['owner']='C0 integrador; Owner nos gates de decisao/acesso'
        item['evidence']=pending if item['status']!='done' else close
delivery['completion']='partial'
delivery['memory']=dict(status='captured',reason='Fonte canonica de Conta atualizada primeiro; projecao team preserva confirmacao autoritativa e metadados reais sem certificar disponibilidade. Validacao77artigos; suite12P/1S. Referencias chat e R12 preservadas.',evidence='docs/knowledge/team/account-profile-header-access.md')
delivery['deployment']=dict(status='pending',evidence=close,reason='Quatro candidatos SQL locais aguardam requisito PITR. Build QA local servido; nenhum SQL/Edge/Cloudflare remoto ou deploy web publico R11.')
for name in [close,pending,evidence+'closure-metrics.json',evidence+'backup-manifest.json',evidence+'build-manifest.json',evidence+'ui-acceptance-plan.json',evidence+'git-checkpoint.json','docs/open-questions.md']:
    if name not in delivery['evidenceFiles']: delivery['evidenceFiles'].append(name)
delivery_path.write_text(json.dumps(delivery,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print('R11 close/pending and existing Owner ledger updated; final gate still required')

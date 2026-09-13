from pathlib import Path
import json

root = Path(__file__).resolve().parents[5]
checkpoint = root / 'docs/reviews/etapa-2-operacao/next-round/R11-checkpoint.md'
with checkpoint.open('a', encoding='utf-8') as out:
    out.write('''
## Checkpoint 12:32 BRT

Cota real mais recente91%, mesma janela/reset, sem ampliar teto98/congelamento95. Commit d20bcfcf2 publicado em dev. Runtime C0 PID39272/3000 com build r11-account-v3, codigo d20bcfcf2, JS1dd04dca028d7b48e0909895ed5885641dfd434c1cd655c89a0dd603b217db36. Build75,3s PASS; analyze focal PASS. Chrome QA31192 e Owner18924 preservados; slot Flutter ocioso. Analyze e build chegaram a sobrepor na abertura desta verificacao por sessao de analyze ainda pendente; ambos terminaram, sem iniciar outro lote concorrente. Nao usar essa sobreposicao como pratica de rodada.

Conta: nome original restaurado e confirmado por reload; cancelar descarta rascunho; footer acessivel desktop/mobile, busca e scroll limitado observados. Principal usa a mesma sigla/cor persistidas, sem cor de tema fixa. Foto pelo picker normal com PNG estatico de marca, recorte ajustado igual ao editor; Save informa ausencia de confirmacao, reload conserva sigla. Persistencia/remocao R2 seguem abertas. Nao ha gateway/catalogo Conta existente; uma entrega dessa cadeia exige verificacao real de imagem, variantes64/128/256/512, ownership, bind/remocao e limpeza, alem do gate remoto bloqueado. Nao foi criado transporte parcial nem dependencia nova. Proximas correcoes locais sao apenas as necessarias para fechar a fatia revisavel; nao prometer aceite da foto.

Quatro goldens antigos falharam pela mudanca autorizada do rodape/Meu acesso; renders375/768/1024/1440 inspecionados, baselines automatizadas atualizadas e4/4 PASS. Nao equivalem a aprovacao visual A do Owner. Texto200% e150 permissoes em375/1440:2/2 PASS. Total58 Flutter unicos PASS;41 pgTAP unicos PASS (40funcionais e1diagnostico adicional, sem repetir3asserts de fixture). SQLSTATE local sanitizado23503:assessment_gradebooks_period_id_institution_id_fkey confirma DELETE indevido de outra configuracao; transacao diagnostica fez rollback e preservou candidato corrigido. Em producao, somente envelope SAI_INTERNAL_ERROR/correlation ja capturado; nao alegar SQLSTATE remoto.

Backup logico de schema do lote em andamento fora do Git; nao substitui PITR nem autoriza aplicacao. Quatro candidatos locais aguardam decisao sobre exigencia explicita da R11 versus excecao ADR0034D8. Atividade retida95b98978 ja esta active em producao; configdraft b04c879e nao e ID de atividade. Nao despublicar/republicar nem criar rascunho para inflar activities.publish. WIP: goldens/provas, README de replay e registros; sem nova rodada ou alteracao dos anexos de chat/R12.
''')

questions = root / 'docs/open-questions.md'
with questions.open('a', encoding='utf-8') as out:
    out.write('''
## R11 — requisito de backup remoto — 2026-09-13

Fontes: `docs/reviews/etapa-2-operacao/next-round/R11-prompt-unico.md` e prompt de execucao do Owner exigem PITR ligado; `decisions/0034-mvp-remote-application-and-acceptance-bar.md`, Decisao8, registra a excecao anterior com backup por lote antes de clientes reais (conforme R10-fechamento). Preflight R11: PITR=false. Decisao solicitada ao Owner: manter a excecao para este lote ou exigir PITR antes da aplicacao. C0 preparou quatro candidatos e pgTAP local; nenhum SQL remoto foi aplicado. Primeiro gate do integrador: resolver esse requisito e medir novamente a configuracao antes de aplicar. Backup logico preparado nao resolve silenciosamente o conflito.

### R11 — ordem do replay local reconciliada

O README antigo dizia ordem por carimbo; `packages/coelo_database/migrations/ordem-de-aplicacao-producao.txt` ja documentava a ordem REAL por lote e a dependencia que impede ordenar por timestamp. C0 corrigiu o README para apontar ao manifesto operacional existente apos replay local dos167 arquivos. Isso nao altera ordem de producao nem aprova reaplicacao do historico. Evidencia: `docs/reviews/evidence/etapa-2/r11-coordenacao/local-replay.json`.
''')

deltas=[]
for action, description in {
    'activities.assessment':'R11 candidato20260913143441 local-green:8/8 pgTAP; diagnostico transacional adicional23503 confirma DELETE em outra configuracao. Aguardando requisito PITR/aplicacao; UPDATE UI ainda falha no mesmo b04c879e.',
    'groups.list':'R11 candidato20260913143659 local-green:10/10 pgTAP cobrem contadores, status, heranca e isolamento real. RPC remoto ainda omite campos; UI/reload permanecem sem aceite dos contadores.'
}.items():
    deltas.append(dict(action_id=action,camada='backend',estado_proposto='local-green',delta=description,evidencia='docs/reviews/etapa-2-operacao/next-round/R11-checkpoint.md'))
deltas.append(dict(action_id='account.profile',camada='frontend',estado_proposto='pending-verification',delta='R11 build d20bcfcf2: nome/cancelar/reload/header Principal, footer/busca/mobile observados;58 testes Flutter focais unicos PASS incluindo4goldens e texto200%. Foto mostra ausencia de confirmacao real; persistencia R2, cor/sigla remotas e grupos de acesso SQL ainda pendentes. Sem aceite integral.',evidencia='docs/reviews/etapa-2-operacao/next-round/R11-checkpoint.md'))
Path(__file__).with_name('delta-1232.json').write_text(json.dumps(deltas,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')

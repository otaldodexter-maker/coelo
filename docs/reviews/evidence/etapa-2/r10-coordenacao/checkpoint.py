import json, pathlib, datetime
root = pathlib.Path(__file__).resolve().parents[5]
now = datetime.datetime.now(datetime.timezone.utc).isoformat()
p = root / 'docs/reviews/etapa-2-operacao/comunicacao/coordenacao.json'
d = json.loads(p.read_text(encoding='utf-8'))
d['revision'] += 1
d['updatedAt'] = now
d['checkpointR10Atual'] = {'time': now, 'base': 'c07ac25e8', 'quotaUsedPercent': 71, 'quotaSource': 'account/rateLimits/read', 'runtime': {'port': 3000, 'pid': 51176, 'owner': 'C0', 'build': 'filters release qa_main.dart 66s PASS'}, 'helpers': {'/root/dev_senior_fe_be': 'ACK; groups.members 67b5dc967 entregue; revisao integracao', '/root/chat_inline': 'ACK; render inline; branch work/etapa2-r10-chat-inline', '/root/chat_upload': 'ACK; retry idempotente; branch work/etapa2-r10-chat-upload; slot Flutter'}, 'wip': 'Filtros 8 controles/5superficies:15PASS analyze0 buildPASS; UI pendente. Chat Owner novos apontamentos upload/inline. Nenhum novo aceite.', 'next': 'UI filtros na origem3000; revisar/merge members e preflightSQL. Chat delegado sem arquivos concorrentes.', 'authorization': 'Owner autorizou maximo auxiliares nesta arvore em13set; tres auxiliares, sem novos modelos.'}
p.write_text(json.dumps(d, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
inv = json.loads((root/'docs/reviews/inventario-etapa-2.json').read_text(encoding='utf-8'))
deltas=[]
for a in inv['actions']:
    if a['id'] in ['activities.list','circulars.filter','notices.list','meal-plans.list','audit.filter']:
        x={'action_id':a['id'],'camada':'frontend','delta':a['fe']+' R10 Owner: filtro single-select em capsula compartilhada corrigido;15testes PASS, analyze0, buildPASS. Prova UI do delta pendente; preservado aceite historico sem novo incremento.','evidencia':'docs/reviews/evidence/etapa-2/r10-coordenacao/filters.md'}
        if a['frontendStatus']=='verified': x['certificacao']=a['certifications']['frontend']
        deltas.append(x)
    if a['id']=='chat.attach':
        for layer,field in [('frontend','fe'),('backend','be'),('integrated','done')]:
            deltas.append({'action_id':a['id'],'camada':layer,'delta':a[field]+' R10 Owner: upload PNG531KB falha na origem3016; OPTIONS chat-media403, origem3000/3014 permite200. Runtime transferido3000. Foto inline/video play pedidos, ainda pendentes; retry sob investigacao. Sem aceite UI novo.','evidencia':'docs/reviews/evidence/etapa-2/r10-coordenacao/chat-owner.md'})
(root/'docs/reviews/evidence/etapa-2/r10-coordenacao/checkpoint-delta.json').write_text(json.dumps(deltas,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')

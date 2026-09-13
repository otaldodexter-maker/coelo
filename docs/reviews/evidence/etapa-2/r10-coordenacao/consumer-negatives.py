"""R10 consumer negatives via normal Auth; no successful business mutation."""
import importlib.util,json,uuid
from pathlib import Path
from datetime import datetime,timezone
ROOT=Path(__file__).resolve().parents[5]
spec=importlib.util.spec_from_file_location('transport',ROOT/'docs/reviews/evidence/etapa-2/r08-estrutura/assessments_api_runner.py'); t=importlib.util.module_from_spec(spec);spec.loader.exec_module(t)
def main():
 out=Path(__file__).with_suffix('.json');assert not out.exists()
 app=t.env(ROOT/'apps/superadmin/.env.local');qa=t.env(Path('C:/Users/adrie/Documents/Coelo-backups/qa-r06-estrutura.env'));base=app['COELO_SUPABASE_URL'].rstrip('/');assert base=='https://evvbomzejfijozbtgvpt.supabase.co'
 h={'apikey':app['COELO_SUPABASE_PUBLISHABLE_KEY'],'Content-Type':'application/json'}; req=str(uuid.uuid4());report={'at':datetime.now(timezone.utc).isoformat(),'request_id':req,'crossTenantSession':False,'checks':[]};authenticated=False
 def check(name,passed,**safe):
  row={'name':name,'pass':bool(passed),**safe};report['checks'].append(row);print(json.dumps(row),flush=True);assert passed,name
 def rpc(name,args):return t.call(base,h,'/rest/v1/rpc/'+name,args)
 try:
  code,body=rpc('superadmin_assessment_configuration_read_by_id',{'target_configuration':'b04c879e-bedd-4e45-9358-66c545215646'});check('anonymous_selected_read_denied',code in (401,403),http=code)
  code,body=t.call(base,h,'/auth/v1/token?grant_type=password',{'email':qa['QA_EMAIL'],'password':qa['QA_PASSWORD']});authenticated=code==200 and bool(body.get('access_token'));check('normal_auth',authenticated,http=code);h['Authorization']='Bearer '+body['access_token']
  code,body=rpc('superadmin_assessment_configuration_read_by_id',{'target_configuration':'b04c879e-bedd-4e45-9358-66c545215646'});data=body.get('data') or {};check('retained_draft_by_id',code==200 and (data.get('configuration') or {}).get('id')=='b04c879e-bedd-4e45-9358-66c545215646',http=code)
  code,body=rpc('superadmin_assessment_configuration_read_by_id',{'target_configuration':'00000000-0000-4000-8000-000000000001'});check('unknown_configuration_opaque',code==200 and body.get('data') is None,http=code)
  code,body=rpc('superadmin_group_student_unlink',{'p_request_id':req,'p_child_context_id':'b1520810-ca23-4632-8b53-cc36e558013c','p_group_id':'368a5cea-2bcf-4fa4-ad1f-18da58694551'});err=body.get('code') if isinstance(body,dict) else None;check('real_foreign_institution_hierarchy_denied',code>=400,http=code,error_code=err)
 except Exception as e:report['failure']=type(e).__name__
 finally:
  if authenticated:
   code,_=t.call(base,h,'/auth/v1/logout?scope=local',{});report['checks'].append({'name':'own_session_logout','pass':code==204,'http':code})
  report['pass']='failure' not in report and all(x['pass'] for x in report['checks']);out.write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
 return 0 if report['pass'] else 1
if __name__=='__main__':raise SystemExit(main())

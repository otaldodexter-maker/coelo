import test from 'node:test';
import assert from 'node:assert/strict';
import { execute, main, mutationSql, plan } from './r02-d01-auth-proof-executor.mjs';

const actorId='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
const sessionId='bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';
const token=(sub)=>`synthetic.${Buffer.from(JSON.stringify({sub,session_id:sessionId,iss:`${plan.apiOrigin}/auth/v1`,role:'authenticated',aal:'aal1',exp:Date.now()/1000+3600})).toString('base64url')}.synthetic`;
function input(action) { return {
  projectRef:plan.projectRef,apiOrigin:plan.apiOrigin,approval:`${plan.package}:${plan.planId}:${action}`,
  mailbox:'synthetic@controlled.example.com',secretKey:'sb_secret_synthetic',managementToken:'synthetic-management-token-only',
  actorToken:token(actorId),password:'synthetic-password-with-thirty-two-characters',syntheticToken:token(plan.authUserId),
}; }
const user=()=>({id:plan.authUserId,email:'synthetic@controlled.example.com',app_metadata:{coelo_e2_package:plan.package,coelo_e2_plan:plan.planId,coelo_e2_persona:plan.persona}});
function server(overrides={}) {
  const state={auth:false,owned:true,bindings:'absent',banned:true,sessions:0,role:true,global:false,collisions:0,actor:true,...overrides};
  const calls=[];
  const response=(body,status=200)=>({status,json:async()=>body});
  const fetcher=async(url,options)=>{
    const body=options.body ? JSON.parse(options.body):undefined;
    calls.push({url,method:options.method,body});
    assert.equal(options.redirect,'error');
    assert.equal(options.credentials,'omit');
    if(url.startsWith('https://api.supabase.com/')) {
      assert.equal(url,`https://api.supabase.com/v1/projects/${plan.projectRef}/database/query`);
      assert.ok(!options.headers.apikey);
      if(body.query.includes(' as actor')) return response([{actor:{authorized:state.actor}}]);
      if(body.query.includes('e2.r02.auth.provision')) {state.bindings='active'; if(state.fail==='bindings') throw Error('private-provider-body');}
      if(body.query.includes('e2.r02.auth.cleanup')) {if(state.bindings==='active') state.bindings='revoked';state.sessions=0; if(state.fail==='revocation') throw Error('private-provider-body');}
      return response([{receipt:{planId:plan.planId,auth_exists:state.auth,owned:state.auth&&state.owned,banned:state.auth&&state.banned,
        bindings:state.bindings,sessions:state.sessions,role_ready:state.role,no_global_link:!state.global,mailbox_collisions:state.collisions}}],201);
    }
    assert.ok(url.startsWith(`${plan.apiOrigin}/auth/v1/`));
    assert.equal(options.headers.apikey,'sb_secret_synthetic');
    if(url.endsWith('/user')) {
      const subject=JSON.parse(Buffer.from(options.headers.Authorization.split('.')[1],'base64url').toString('utf8')).sub;
      return response(subject===actorId?{id:actorId}:user());
    }
    if(url.endsWith('/admin/users')&&options.method==='POST') {
      assert.equal(body.id,plan.authUserId); assert.equal(body.ban_duration,'876000h'); assert.equal(body.email_confirm,true);
      state.auth=true;
      if(state.fail==='create') throw Error('private-create-response');
      return response(state.fail==='wrong-user'?{...user(),id:actorId}:user(),201);
    }
    if(url.endsWith(`/admin/users/${plan.authUserId}`)) {
      if(options.method==='PUT') {if(state.fail==='ban-denied') throw Error('private-ban-denied');state.banned=body.ban_duration!=='none';if(state.fail==='ban') throw Error('private-ban-response');}
      return response(user());
    }
    if(url.endsWith('/logout?scope=global')) {
      state.sessions=0;
      if(state.fail==='logout') throw Error('private-logout-response');
      return response(null,204);
    }
    assert.fail('unexpected endpoint');
  };
  const mutations=()=>calls.filter((call)=>call.url.includes('/database/query') ? /e2\.r02\.auth\.(provision|cleanup)/.test(call.body.query) : call.method!=='GET');
  return {state,calls,fetcher,mutations};
}

test('default and named action are offline without reading credentials or using network',async()=>{
  for(const args of [[],['provision'],['cleanup']]) {
    const result=await main(args,{},()=>assert.fail('network'));
    assert.equal(result.mode,'offline-no-network');assert.equal(result.sendEmail,false);
    assert.equal(result.authUserId,plan.authUserId);
  }
});

test('opaque secret key uses apikey only while actor JWT stays in Authorization',async()=>{
  const s=server();const data=input('provision');let adminRequests=0;let actorRequests=0;
  const fetcher=async(url,options)=>{
    if(url.startsWith(`${plan.apiOrigin}/auth/v1/admin/`)) {
      adminRequests++;
      assert.equal(options.headers.apikey,data.secretKey);
      assert.equal(options.headers.Authorization,undefined);
    } else if(url===`${plan.apiOrigin}/auth/v1/user`) {
      actorRequests++;
      assert.equal(options.headers.apikey,data.secretKey);
      assert.equal(options.headers.Authorization,`Bearer ${data.actorToken}`);
    }
    return s.fetcher(url,options);
  };
  assert.equal((await execute('provision',data,fetcher)).status,'confirmed');
  assert.ok(adminRequests>0);assert.equal(actorRequests,1);
});

test('target, approval and secret-key guards reject before any request',async()=>{
  for(const delta of [{projectRef:'another'},{apiOrigin:`${plan.apiOrigin}.example.com`},{approval:'old-approval'},{secretKey:'sb_publishable_synthetic'}]) {
    await assert.rejects(execute('provision',{...input('provision'),...delta},()=>assert.fail('network')));
  }
});

test('non-Owner context denies Auth creation before mutations',async()=>{
  const s=server({actor:false});
  await assert.rejects(execute('provision',input('provision'),s.fetcher),/LIVE_OWNER_REQUIRED/);
  assert.equal(s.mutations().length,0);
});

test('unowned ID, mailbox collision, cross-realm and private drift deny all mutations',async()=>{
  for(const override of [{auth:true,owned:false},{collisions:1},{global:true},{bindings:'drift'}]) {
    const s=server(override);
    await assert.rejects(execute('provision',input('provision'),s.fetcher),/NOMINAL_OWNERSHIP_OR_COLLISION/);
    assert.equal(s.mutations().length,0);
  }
});

test('provision creates banned Auth user, confirms private COMMIT then activates exact user',async()=>{
  const s=server();const result=await execute('provision',input('provision'),s.fetcher);
  assert.equal(result.status,'confirmed');assert.equal(result.bindings,'active');assert.equal(result.banned,false);
  const mutations=s.mutations();assert.equal(mutations.length,3);
  assert.ok(mutations[0].url.endsWith('/admin/users'));
  assert.ok(mutations[1].body.query.includes('commit;\nselect jsonb_build_object'));
  assert.equal(mutations[2].body.ban_duration,'none');
  assert.ok(!JSON.stringify(result).includes(input('provision').mailbox));
});

test('confirmed provision replay with existing sessions does not repeat creation or activation',async()=>{
  const s=server({auth:true,bindings:'active',banned:false,sessions:1});
  assert.equal((await execute('provision',input('provision'),s.fetcher)).status,'confirmed');
  assert.equal(s.mutations().length,0);
});

test('ambiguous Auth creation never retries, inserts bindings or activates',async()=>{
  const s=server({fail:'create'});
  await assert.rejects(execute('provision',input('provision'),s.fetcher),/^Error: AUTH_CREATE_UNCONFIRMED$/);
  assert.equal(s.mutations().length,1);assert.equal(s.state.bindings,'absent');assert.equal(s.state.banned,true);
});

test('wrong create response ownership stops before private writes',async()=>{
  const s=server({fail:'wrong-user'});
  await assert.rejects(execute('provision',input('provision'),s.fetcher),/AUTH_OWNERSHIP_UNCONFIRMED/);
  assert.equal(s.mutations().length,1);
});

test('ambiguous private COMMIT never retries SQL or unbans account',async()=>{
  const s=server({fail:'bindings'});
  await assert.rejects(execute('provision',input('provision'),s.fetcher),/^Error: BINDINGS_COMMIT_UNCONFIRMED$/);
  assert.equal(s.mutations().length,2);assert.equal(s.state.banned,true);
});

test('cleanup bans exact user and atomically revokes bindings and provider sessions without deleting history',async()=>{
  const s=server({auth:true,bindings:'active',banned:false,sessions:1});
  const result=await execute('cleanup',input('cleanup'),s.fetcher);
  assert.equal(result.status,'confirmed');assert.equal(result.sessionRows,0);assert.equal(result.bindings,'revoked');
  const mutations=s.mutations();assert.equal(mutations.length,2);
  assert.equal(mutations[0].url,`${plan.apiOrigin}/auth/v1/admin/users/${plan.authUserId}`);
  assert.equal(mutations[0].body.ban_duration,'876000h');
  assert.ok(mutations[1].body.query.includes('e2.r02.auth.cleanup'));
  assert.ok(mutations[1].body.query.includes('delete from auth.sessions s using auth.users u'));
  assert.ok(!s.calls.some((call)=>call.method==='DELETE'));
});

test('cleanup does not depend on missing or expired synthetic token and never sends Owner to logout',async()=>{
  for(const syntheticToken of [undefined,'expired-token']) {
    const s=server({auth:true,bindings:'active',banned:false,sessions:1});const data={...input('cleanup'),syntheticToken};
    assert.equal((await execute('cleanup',data,s.fetcher)).status,'confirmed');
    assert.equal(s.mutations().length,2);assert.ok(!s.calls.some((call)=>call.url.includes('/logout')));
  }
});

test('ambiguous ban is not retried and cannot prevent terminal session revocation',async()=>{
  const s=server({auth:true,bindings:'active',banned:false,sessions:1,fail:'ban'});
  assert.equal((await execute('cleanup',input('cleanup'),s.fetcher)).status,'confirmed');
  assert.equal(s.mutations().length,2);assert.equal(s.state.bindings,'revoked');assert.equal(s.state.sessions,0);
});

test('unconfirmed ban still revokes bindings and sessions but never reports complete cleanup',async()=>{
  const s=server({auth:true,bindings:'active',banned:false,sessions:1,fail:'ban-denied'});
  await assert.rejects(execute('cleanup',input('cleanup'),s.fetcher),/^Error: CLEANUP_UNCONFIRMED$/);
  assert.equal(s.mutations().length,2);assert.equal(s.state.bindings,'revoked');assert.equal(s.state.sessions,0);
});

test('cleanup of partial banned creation needs no synthetic login or private insertion',async()=>{
  const s=server({auth:true});const data=input('cleanup');delete data.syntheticToken;
  const result=await execute('cleanup',data,s.fetcher);
  assert.equal(result.status,'confirmed');assert.equal(result.bindings,'absent');
  assert.equal(s.mutations().length,0);
});

test('mutation SQL enforces live Owner, ownership, cross-realm, exact versions and audit within transaction',()=>{
  const actor={sub:actorId,session_id:sessionId,aal:'aal1'};
  for(const action of ['provision','cleanup']) {
    const sql=mutationSql(action,input(action).mailbox,actor);
    assert.ok(sql.startsWith('begin;'));assert.ok(sql.includes("require_superadmin_internal_context('platform.read')"));
    assert.ok(sql.includes('LIVE_OWNER_REQUIRED'));assert.ok(sql.includes('NOMINAL_AUTH_OWNERSHIP_REQUIRED'));
    assert.ok(sql.includes('CROSS_REALM_DENIED'));assert.ok(sql.includes('audit_append_superadmin_internal'));
    assert.ok(!/\b(truncate|alter|drop|create)\b/i.test(sql));
    if(action==='cleanup') {
      assert.equal((sql.match(/\bdelete from\b/g)??[]).length,1);
      assert.ok(sql.includes(`delete from auth.sessions s using auth.users u where s.user_id=u.id and u.id='${plan.authUserId}'::uuid`));
    } else assert.ok(!/\bdelete\b/i.test(sql));
    assert.ok(sql.indexOf('commit;')<sql.lastIndexOf(' as receipt;'));
  }
  assert.ok(mutationSql('cleanup',input('cleanup').mailbox,actor).includes(`where id='${plan.authLinkId}' and version=1`));
});

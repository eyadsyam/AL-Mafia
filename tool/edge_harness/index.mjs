import { PGlite } from '../../build/sql-probe/node_modules/@electric-sql/pglite/dist/index.js';
import { readdir, readFile } from 'node:fs/promises';
import { register } from 'node:module';
import { pathToFileURL } from 'node:url';
import { resolve } from 'node:path';

register(new URL('./resolve.mjs', import.meta.url));

const root = resolve(import.meta.dirname, '../..');
const handlers = new Map();
globalThis.Deno = {
  env: { get: (key) => key === 'SUPABASE_ANON_KEY' ? 'anon' : 'local' },
  serve: (fn) => { if (!globalThis.__edgeImportName) throw Error('unexpected Deno.serve'); handlers.set(globalThis.__edgeImportName, fn); },
};

async function boot(db) {
  // Identical managed-platform setup and pg_net substitution to test_sql_without_docker.mjs.
  await db.exec(`
    create role anon; create role authenticated; create role service_role bypassrls;
    create schema auth; create schema extensions;
    create table auth.users(id uuid primary key, email text, created_at timestamptz not null default now(),
      email_confirmed_at timestamptz, is_anonymous boolean not null default false);
    create function auth.uid() returns uuid language sql stable as $$
      select coalesce(nullif(current_setting('request.jwt.claim.sub',true),''),
        nullif(current_setting('request.jwt.claims',true),'')::jsonb->>'sub')::uuid $$;
    grant usage on schema public,auth to anon,authenticated,service_role;
    grant execute on function auth.uid() to anon,authenticated,service_role;
    alter default privileges in schema public grant all on tables to anon,authenticated,service_role;
    alter default privileges in schema public grant all on sequences to anon,authenticated,service_role;
    create publication supabase_realtime;
    create schema cron;
    create table cron.job(jobid bigint generated always as identity, jobname text unique, schedule text, command text);
    create function cron.schedule(text,text,text) returns bigint language sql as $$
      insert into cron.job(jobname,schedule,command) values($1,$2,$3)
      on conflict(jobname) do update set schedule=$2,command=$3 returning jobid $$;
    create function cron.unschedule(text) returns boolean language sql as $$
      with gone as (delete from cron.job where jobname=$1 returning 1)
      select exists(select 1 from gone) $$;
  `);
  for (const file of (await readdir(resolve(root, 'supabase/migrations'))).filter(f=>f.endsWith('.sql')).sort()) {
    const sql = (await readFile(resolve(root, 'supabase/migrations', file), 'utf8')).replace(
      /create extension if not exists pg_net[^;]*;/i,
      () => `create schema if not exists net;
       create or replace function net.http_post(url text, body jsonb default null,
         params jsonb default null, headers jsonb default null, timeout_milliseconds int default null)
         returns bigint language sql as $$ select 0::bigint $$;`);
    try { await db.exec(sql); } catch (error) { throw new Error(`MIGRATION ${file}: ${error.message}`); }
  }
}

const identifier = (name) => {
  if (!/^[a-z_][a-z_0-9]*$/i.test(name)) throw Error(`bad SQL identifier: ${name}`);
  return `"${name}"`;
};
const postgrestError = (e) => ({ code: e.code ?? e.cause?.code ?? 'PGRST000', message: e.message });
const value = (x) => Array.isArray(x)
  ? `{${x.map(v=>`"${String(v).replaceAll('\\','\\\\').replaceAll('"','\\"')}"`).join(',')}}`
  : x && typeof x === 'object' && !(x instanceof Date) ? JSON.stringify(x) : x;

class Query {
  constructor(db, table) { this.db=db; this.table=identifier(table); this.mode='select'; this.columns='*'; this.filters=[]; this.params=[]; this.sort=[]; this.max=null; this.card=null; this.head=false; this.count=false; this.payload=null; this.conflict=null; }
  select(columns='*', options={}) { this.columns=columns; this.head=!!options.head; this.count=options.count==='exact'; return this; }
  where(column, op, val) { this.params.push(value(val)); this.filters.push(`${identifier(column)} ${op} $${this.params.length}`); return this; }
  eq(c,v) { return this.where(c,'=',v); } neq(c,v) { return this.where(c,'<>',v); }
  gt(c,v) { return this.where(c,'>',v); } gte(c,v) { return this.where(c,'>=',v); }
  lt(c,v) { return this.where(c,'<',v); } lte(c,v) { return this.where(c,'<=',v); }
  in(c,vs) { this.params.push(vs); this.filters.push(`${identifier(c)} = any($${this.params.length})`); return this; }
  is(c,v) { this.filters.push(`${identifier(c)} is ${v === null ? 'null' : v === true ? 'true' : 'false'}`); return this; }
  not(c,op,v) { if(op!=='is') throw Error(`unsupported not ${op}`); this.filters.push(`${identifier(c)} is not ${v === null ? 'null' : v}`); return this; }
  order(c,{ascending=true}={}) { this.sort.push(`${identifier(c)} ${ascending?'asc':'desc'}`); return this; }
  limit(n) { this.max=n; return this; } maybeSingle() { this.card='maybe'; return this; } single() { this.card='one'; return this; }
  insert(x) { this.mode='insert'; this.payload=x; return this; }
  upsert(x,{onConflict,ignoreDuplicates=false}={}) { this.mode='upsert'; this.payload=x; this.conflict=onConflict; this.ignoreDuplicates=ignoreDuplicates; return this; }
  update(x) { this.mode='update'; this.payload=x; return this; }
  delete() { this.mode='delete'; return this; }
  then(resolve,reject) { return this.run().then(resolve,reject); }
  async run() {
    try {
      let rows, count;
      if (this.mode==='select') {
        const embed=this.columns.match(/,?\s*rooms!inner\(([^)]+)\)/);
        const raw=embed ? this.columns.replace(embed[0],'') : this.columns;
        const projection=raw==='*' ? '*' : [...raw.split(',').map(s=>identifier(s.trim())),...(embed && !raw.includes('room_id')?['room_id']:[])].join(',');
        const where=this.filters.length ? ` where ${this.filters.join(' and ')}` : '';
        const order=this.sort.length ? ` order by ${this.sort.join(',')}` : '';
        const limit=this.max==null ? '' : ` limit ${Number(this.max)}`;
        rows=(await this.db.query(`select ${projection} from ${this.table}${where}${order}${limit}`,this.params)).rows;
        count=rows.length;
        if(embed) {
          for(const row of rows) {
            const r=(await this.db.query(`select ${embed[1].split(',').map(s=>identifier(s.trim())).join(',')} from rooms where id=$1`,[row.room_id])).rows[0];
            row.rooms=r ?? null;
            delete row.room_id;
          }
          rows=rows.filter(r=>r.rooms);
        }
      } else if(this.mode==='insert'||this.mode==='upsert') {
        const items=Array.isArray(this.payload)?this.payload:[this.payload]; rows=[];
        for(const item of items) {
          const cols=Object.keys(item), vals=cols.map(k=>value(item[k]));
          const base=`insert into ${this.table} (${cols.map(identifier).join(',')}) values (${cols.map((_,i)=>`$${i+1}`).join(',')})`;
          let target=this.conflict;
          if(this.mode==='upsert' && !target && !this.ignoreDuplicates) {
            const pk=(await this.db.query(`select a.attname from pg_index i join pg_class t on t.oid=i.indrelid join pg_attribute a on a.attrelid=t.oid and a.attnum=any(i.indkey) where t.relname=$1 and i.indisprimary order by array_position(i.indkey::int[],a.attnum)`,[this.table.slice(1,-1)])).rows;
            if(!pk.length) throw Error(`no primary key for upsert ${this.table}`);
            target=pk.map(r=>r.attname).join(',');
          }
          const conflict=this.mode==='upsert' ? ` on conflict ${target?`(${target.split(',').map(s=>identifier(s.trim())).join(',')})`:''} ${this.ignoreDuplicates?'do nothing':`do update set ${cols.map(c=>`${identifier(c)}=excluded.${identifier(c)}`).join(',')}`}` : '';
          rows.push(...(await this.db.query(`${base}${conflict} returning *`,vals)).rows);
        }
      } else {
        const where=this.filters.length ? ` where ${this.filters.join(' and ')}` : '';
        let sql;
        if(this.mode==='update') {
          const sets=Object.entries(this.payload).map(([k,v])=>{this.params.push(value(v)); return `${identifier(k)}=$${this.params.length}`;});
          sql=`update ${this.table} set ${sets.join(',')}${where} returning *`;
        } else sql=`delete from ${this.table}${where} returning *`;
        rows=(await this.db.query(sql,this.params)).rows;
      }
      return {data:this.head?null:this.card?rows[0]??null:rows,error:null,...(this.count?{count}:{} )};
    } catch(e) { if(process.env.EDGE_HARNESS_DEBUG) console.error('QUERY',this.table,this.mode,e); return {data:null,error:postgrestError(e),...(this.count?{count:null}:{})}; }
  }
}

export async function harness() {
  const db=new PGlite();
  try { await boot(db); } catch(e) { await db.close(); throw e; }
  const aliases=new Map();
  const uid=(id)=>aliases.get(id)??id;
  async function rpc(name,args={}) {
    try {
      identifier(name);
      const entries=Object.entries(args);
      const signature=entries.map(([k],i)=>`${identifier(k)} := $${i+1}`).join(',');
      const params=entries.map(([,v])=>value(v));
      const meta=(await db.query(`select p.proretset, t.typtype from pg_proc p join pg_namespace n on n.oid=p.pronamespace join pg_type t on t.oid=p.prorettype where n.nspname='public' and p.proname=$1 and p.pronargs >= $2 order by p.pronargs limit 1`,[name,entries.length])).rows[0];
      const result=await db.query(meta?.proretset ? `select * from public.${identifier(name)}(${signature})` : `select public.${identifier(name)}(${signature}) as data`,params);
      return {data:meta?.proretset?result.rows:result.rows[0]?.data??null,error:null};
    } catch(e) { if(process.env.EDGE_HARNESS_DEBUG) console.error('RPC',name,e); return {data:null,error:postgrestError(e)}; }
  }
  globalThis.__edgeHarnessClient=(token)=>({
    auth:{getUser:async()=>{
      if(!token) return {data:{user:null},error:{message:'missing bearer'}};
      const row=(await db.query('select id from auth.users where id=$1',[token])).rows[0];
      return {data:{user:row??null},error:row?null:{message:'unknown user'}};
    }}, from:(table)=>new Query(db,table), rpc,
  });
  return {
    sql:(text,params=[])=>db.query(text,params),
    user:async(id)=>{const actual=/^[0-9a-f]{8}-[0-9a-f-]{27,}$/i.test(id)?id:crypto.randomUUID(); aliases.set(id,actual); await db.query('insert into auth.users(id) values($1) on conflict do nothing',[actual]); return actual;},
    call:async(name,user,body={})=>{
      if(!handlers.has(name)) {
        globalThis.__edgeImportName=name;
        try { await import(pathToFileURL(resolve(root,'supabase/functions',name,'index.ts')).href); }
        finally { globalThis.__edgeImportName=null; }
      }
      const response=await handlers.get(name)(new Request(`http://localhost/${name}`,{method:'POST',headers:{'Content-Type':'application/json',...(user?{Authorization:`Bearer ${uid(user)}`}:{})},body:JSON.stringify(body)}));
      return {status:response.status,json:await response.json()};
    },
    close:()=>db.close(),
  };
}

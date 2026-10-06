import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { corsHeaders } from "../_shared/cors.ts";

const URL=Deno.env.get("SUPABASE_URL")!;
const SERVICE=Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const serviceHeaders={apikey:SERVICE,Authorization:`Bearer ${SERVICE}`,"Content-Type":"application/json"};
const cors=corsHeaders;
const json=(status:number,body:unknown)=>new Response(JSON.stringify(body),{status,headers:{...cors,"Content-Type":"application/json"}});
async function db(path:string,init:RequestInit={}){
 const response=await fetch(`${URL}/rest/v1/${path}`,{...init,headers:{...serviceHeaders,...(init.headers??{})}});
 const text=await response.text(); if(!response.ok) throw new Error(`database_${response.status}`); return text?JSON.parse(text):null;
}
Deno.serve(async(req:Request)=>{
 if(req.method==="OPTIONS") return new Response("ok",{headers:cors});
 if(req.method!=="POST") return json(405,{error:"method_not_allowed"});
 const authorization=req.headers.get("authorization")??"";
 const auth=await fetch(`${URL}/auth/v1/user`,{headers:{apikey:SERVICE,Authorization:authorization}});
 if(!auth.ok) return json(401,{error:"authentication_required"});
 const user=await auth.json();
 let body:{document_id?:unknown};try{body=await req.json();}catch{return json(400,{error:"invalid_json"});}
 if(typeof body.document_id!=="string") return json(400,{error:"document_id_required"});
 const docs=await db(`documents?select=id,user_id,file_path,name&id=eq.${encodeURIComponent(body.document_id)}&user_id=eq.${encodeURIComponent(user.id)}&limit=1`);
 if(!docs.length) return json(404,{error:"document_not_found"});
 const jobs=await db("document_processing_jobs?select=id",{method:"POST",headers:{Prefer:"return=representation"},body:JSON.stringify({
  document_id:docs[0].id,user_id:user.id,status:"running",attempt_count:1,started_at:new Date().toISOString()
 })});
 const jobId=jobs[0].id;
 const runtime=await db("rpc/get_document_processor_runtime",{method:"POST",body:"{}"});
 if(!runtime.length){
  await db(`document_processing_jobs?id=eq.${jobId}`,{method:"PATCH",body:JSON.stringify({status:"failed",safe_error_code:"no_ocr_provider_configured",finished_at:new Date().toISOString()})});
  return json(503,{error:"document_intelligence_unavailable",code:"no_ocr_provider_configured",job_id:jobId});
 }
 const config=runtime[0];
 try{
  if(!docs[0].file_path) throw new Error("document_file_missing");
  const file=await fetch(`${URL}/storage/v1/object/documents/${docs[0].file_path}`,{headers:{apikey:SERVICE,Authorization:`Bearer ${SERVICE}`}});
  if(!file.ok) throw new Error(`storage_${file.status}`);
  const bytes=await file.arrayBuffer();
  if(bytes.byteLength>config.max_file_bytes) throw new Error("file_too_large");
  const result=await fetch(config.endpoint_url,{method:"POST",signal:AbortSignal.timeout(config.timeout_ms),headers:{
   Authorization:`Bearer ${config.api_key}`,"Content-Type":file.headers.get("content-type")??"application/octet-stream",
   "X-Document-Name":encodeURIComponent(String(docs[0].name).slice(0,200))
  },body:bytes});
  if(!result.ok) throw new Error(`provider_http_${result.status}`);
  const parsed=await result.json();
  const extractions=await db("document_extractions?select=id",{method:"POST",headers:{Prefer:"return=representation"},body:JSON.stringify({
   job_id:jobId,document_id:docs[0].id,user_id:user.id,engine:String(config.provider_slug),engine_version:String(parsed.version??"unknown").slice(0,100),
   extracted_text:String(parsed.text??"").slice(0,200000),language_code:String(parsed.language_code??"").slice(0,10)||null,
   overall_confidence:Number.isFinite(parsed.confidence)?Math.max(0,Math.min(1,parsed.confidence)):null,
   page_count:Number.isInteger(parsed.page_count)&&parsed.page_count>0?parsed.page_count:null
  })});
  const extractionId=extractions[0].id;
  const fields=Array.isArray(parsed.fields)?parsed.fields.slice(0,200).map((field:Record<string,unknown>)=>({
   extraction_id:extractionId,field_key:String(field.key??"").replace(/[^a-zA-Z0-9_.-]/g,"_").slice(0,100),
   field_value:String(field.value??"").slice(0,4000),confidence:Number.isFinite(field.confidence)?Math.max(0,Math.min(1,Number(field.confidence))):null,
   page_number:Number.isInteger(field.page_number)&&Number(field.page_number)>0?field.page_number:null,
   bounding_box:typeof field.bounding_box==="object"?field.bounding_box:null
  })).filter((field:{field_key:string})=>field.field_key):[];
  if(fields.length) await db("document_fields",{method:"POST",headers:{Prefer:"return=minimal"},body:JSON.stringify(fields)});
  await db(`document_processing_jobs?id=eq.${jobId}`,{method:"PATCH",body:JSON.stringify({status:"review_required",finished_at:new Date().toISOString()})});
  return json(200,{job_id:jobId,extraction_id:extractionId,status:"review_required",field_count:fields.length});
 }catch(error){
  const code=error instanceof DOMException&&error.name==="TimeoutError"?"provider_timeout":String(error instanceof Error?error.message:error).replace(/[^a-zA-Z0-9_]/g,"_").slice(0,80);
  await db(`document_processing_jobs?id=eq.${jobId}`,{method:"PATCH",body:JSON.stringify({status:"failed",safe_error_code:code,finished_at:new Date().toISOString()})});
  return json(422,{error:"document_processing_failed",code,job_id:jobId});
 }
});

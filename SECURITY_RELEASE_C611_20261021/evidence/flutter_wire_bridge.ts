import { contractValid } from "../../supabase/functions/_shared/rad_contract.ts";
import { createCopilotHandler } from "../../supabase/functions/ai-orchestrator/copilot.ts";
const bodies=JSON.parse(await Deno.readTextFile(new URL('./flutter_ai_request_bodies.json',import.meta.url)));
let authenticated=0;
const copilot=createCopilotHandler({
  authenticate:()=>{ authenticated++; return Promise.resolve(null); },
  database:()=>{throw new Error('No database calls authorized in wire bridge');},
  actorDatabase:()=>()=>{throw new Error('No private data authorized in wire bridge');},
  generate:()=>{throw new Error('No provider calls authorized in wire bridge');},
});
for(const body of bodies) {
  if(!contractValid('ai_orchestrator_request',body)) throw new Error('Flutter body rejected by actual backend validator');
  const response=await copilot(new Request('http://localhost/ai-orchestrator',{method:'POST',body:JSON.stringify(body)}));
  if(response.status!==401 || (await response.json()).error!=='authentication_required') throw new Error('Valid body did not reach authentication boundary');
}
if(authenticated!==21) throw new Error('Unexpected synthetic request count');
console.log(JSON.stringify({status:'PASS',synthetic_sdk_requests:authenticated,backend_schema:'actual contractValid',reaches_authentication_boundary:true,network_or_provider_calls:false}));

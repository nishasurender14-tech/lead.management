import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
const cors={"Access-Control-Allow-Origin":"*","Access-Control-Allow-Headers":"authorization, x-client-info, apikey, content-type","Access-Control-Allow-Methods":"POST, OPTIONS"};
const SYSTEM=`You are KIP Consultancy's Meeting Intelligence Agent. Analyse the transcript accurately. Never invent a deadline, owner, decision, commitment, customer requirement or fact. If something is not explicit, return "Not specified" or an empty list. Understand Hindi, English, Hinglish and mixed-language business conversations. Return ONLY valid JSON:
{"meeting_title":"","language":"","summary":"","key_discussions":[],"customer_requirements":[],"decisions":[],"action_items":[{"task":"","owner":"","deadline":"","priority":"High|Medium|Low"}],"risks":[],"meeting_closure":"","next_follow_up":""}`;
Deno.serve(async(req)=>{
 if(req.method==="OPTIONS") return new Response("ok",{headers:cors});
 try{
  const auth=req.headers.get("Authorization"); if(!auth) throw new Error("Authentication required");
  const url=Deno.env.get("SUPABASE_URL")!,service=Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,anon=Deno.env.get("SUPABASE_ANON_KEY")!,key=Deno.env.get("OPENAI_API_KEY")!;
  const admin=createClient(url,service), userClient=createClient(url,anon,{global:{headers:{Authorization:auth}}});
  const {data:{user}}=await userClient.auth.getUser(); if(!user) throw new Error("Invalid session");
  const body=await req.json(),title=body.title||"Untitled Meeting",path=body.recording_path;
  if(!path||!path.startsWith(user.id+"/")) throw new Error("Invalid recording path");
  const {data:file,error:fileError}=await admin.storage.from("meeting-recordings").download(path); if(fileError||!file) throw new Error("Could not read recording");
  const form=new FormData(); form.append("file",file,path.split("/").pop()||"meeting.mp4"); form.append("model","gpt-4o-mini-transcribe");
  const tr=await fetch("https://api.openai.com/v1/audio/transcriptions",{method:"POST",headers:{Authorization:"Bearer "+key},body:form});
  if(!tr.ok) throw new Error("Transcription failed: "+await tr.text());
  const transcript=await tr.json();
  const ai=await fetch("https://api.openai.com/v1/chat/completions",{method:"POST",headers:{"Authorization":"Bearer "+key,"Content-Type":"application/json"},body:JSON.stringify({model:"gpt-4o-mini",temperature:0.1,response_format:{type:"json_object"},messages:[{role:"system",content:SYSTEM},{role:"user",content:"Meeting title: "+title+"\n\nTranscript:\n"+transcript.text}]})});
  if(!ai.ok) throw new Error("AI analysis failed: "+await ai.text());
  const j=await ai.json(),analysis=JSON.parse(j.choices[0].message.content);
  const {data:meeting,error:ins}=await admin.from("meetings").insert({user_id:user.id,title,recording_path:path,transcript:transcript.text,language:analysis.language,summary:analysis.summary,closure:analysis.meeting_closure,decisions:analysis.decisions||[],customer_requirements:analysis.customer_requirements||[],risks:analysis.risks||[]}).select("id").single();
  if(ins) throw ins;
  const actions=(analysis.action_items||[]).map((x:any)=>({meeting_id:meeting.id,task:x.task,owner:x.owner||null,deadline:x.deadline||null,priority:x.priority||"Medium"}));
  if(actions.length) await admin.from("meeting_action_items").insert(actions);
  return new Response(JSON.stringify({meeting_id:meeting.id,analysis}),{headers:{...cors,"Content-Type":"application/json"}});
 }catch(e){return new Response(JSON.stringify({error:e?.message||"Unknown error"}),{status:400,headers:{...cors,"Content-Type":"application/json"}})}
});
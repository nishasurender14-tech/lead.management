// KIP Financial CRM V4 - public Supabase configuration
// Only the public anon key belongs here. Never place a service_role key in this file.
window.SUPABASE_CONFIG = {
  url: 'https://kgpmyxkrtkjqkqxedxsu.supabase.co',
  key: 'sb_publishable_ajmJjeVZ9vC5-JVGWnONnQ_E2aUXY08};

// KIP Financial CRM V4 authentication enhancement.
window.addEventListener('load', () => setTimeout(() => {
  const auth = document.getElementById('auth');
  if (!auth || document.getElementById('kip-auth-v4')) return;
  const box = auth.querySelector('.authbox');
  if (!box) return;
  box.innerHTML = `
    <div class="brand">KIP FINANCIAL</div>
    <h1 id="kip-auth-v4">Welcome to KIP Financial CRM</h1>
    <p class="muted">Secure online CRM for your team.</p>
    <div id="authmsg"></div>
    <div style="display:flex;gap:8px;margin:16px 0 12px"><button id="loginTab" class="btn primary" style="flex:1">Sign in</button><button id="signupTab" class="btn" style="flex:1">Create account</button></div>
    <label class="muted" style="display:block;margin-top:8px">Email address</label>
    <input id="email" class="field" type="email" autocomplete="email" placeholder="you@company.com">
    <label class="muted" style="display:block;margin-top:8px">Password</label>
    <div style="position:relative"><input id="password" class="field" type="password" autocomplete="current-password" placeholder="Enter password" style="padding-right:80px"><button id="showPass" type="button" class="btn" style="position:absolute;right:6px;top:6px;padding:6px 9px">Show</button></div>
    <div id="signupExtra" class="hidden"><label class="muted" style="display:block;margin-top:8px">Confirm password</label><input id="password2" class="field" type="password" autocomplete="new-password" placeholder="Confirm password"><label class="muted" style="display:block;margin-top:8px">Full name</label><input id="fullName" class="field" type="text" autocomplete="name" placeholder="Your full name"><label class="muted" style="display:block;margin-top:8px">Organization</label><input id="orgName" class="field" type="text" autocomplete="organization" value="KIP Financial" placeholder="Organization name"></div>
    <button id="authSubmit" class="btn primary" style="width:100%;margin-top:12px">Sign in</button><button id="forgotBtn" class="btn" style="width:100%;margin-top:8px">Forgot password?</button>
    <p class="muted" style="font-size:12px;margin-top:16px">Your password is handled securely by Supabase Auth and is never stored in the CRM tables.</p>`;
  const $ = id => document.getElementById(id); let mode='login';
  const msg=t=>$('authmsg').innerHTML=`<div style="color:#b42318;background:#fff5f4;border:1px solid #fecdca;border-radius:8px;padding:9px;margin:8px 0">${String(t).replace(/[&<>"']/g,m=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#039;'}[m]))}</div>`;
  const ok=t=>$('authmsg').innerHTML=`<div style="color:#067647;background:#ecfdf3;border:1px solid #abefc6;border-radius:8px;padding:9px;margin:8px 0">${String(t)}</div>`;
  $('showPass').onclick=()=>{const type=$('password').type==='password'?'text':'password';$('password').type=type;$('showPass').textContent=type==='password'?'Show':'Hide'};
  function setMode(next){mode=next;const signup=next==='signup';$('signupExtra').classList.toggle('hidden',!signup);$('authSubmit').textContent=signup?'Create account':'Sign in';$('forgotBtn').classList.toggle('hidden',signup);$('loginTab').className='btn'+(signup?'':' primary');$('signupTab').className='btn'+(signup?' primary':'');$('password').autocomplete=signup?'new-password':'current-password';$('authmsg').innerHTML=''}
  $('loginTab').onclick=()=>setMode('login'); $('signupTab').onclick=()=>setMode('signup');
  $('authSubmit').onclick=async()=>{const email=$('email').value.trim(),pass=$('password').value;if(!email)return msg('Please enter your email address.');if(!pass||pass.length<6)return msg('Password must be at least 6 characters.');$('authSubmit').disabled=true;try{if(mode==='login'){const r=await sb.auth.signInWithPassword({email,password:pass});if(r.error)return msg(r.error.message);if(typeof boot==='function')await boot(r.data.user)}else{const pass2=$('password2').value;if(pass!==pass2)return msg('Passwords do not match.');const fullName=$('fullName').value.trim(),orgName=$('orgName').value.trim()||'KIP Financial';const r=await sb.auth.signUp({email,password:pass,options:{data:{full_name:fullName,organization_name:orgName}}});if(r.error)return msg(r.error.message);if(!r.data.session){ok('Account created successfully. Please confirm your email, then return here and sign in.');setMode('login');return}if(typeof boot==='function')await boot(r.data.user)}}catch(e){msg(e.message||'Authentication failed.')}finally{$('authSubmit').disabled=false}};
  $('forgotBtn').onclick=async()=>{const email=$('email').value.trim();if(!email)return msg('Enter your email address first.');const redirect=window.location.origin+window.location.pathname;const r=await sb.auth.resetPasswordForEmail(email,{redirectTo:redirect});if(r.error)return msg(r.error.message);ok('Password reset email sent. Check your inbox.')};
  $('password').addEventListener('keydown',e=>{if(e.key==='Enter')$('authSubmit').click()});$('email').addEventListener('keydown',e=>{if(e.key==='Enter')$('authSubmit').click()});
},0));

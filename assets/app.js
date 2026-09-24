(function(){
"use strict";
var menuBtn=document.querySelector('.menu-toggle'),mobileNav=document.getElementById('mobileNav');
if(menuBtn&&mobileNav){menuBtn.addEventListener('click',function(){
  var open=mobileNav.classList.toggle('open');
  menuBtn.setAttribute('aria-expanded',open?'true':'false');
});}
var dlg=document.getElementById('betaDialog');
document.querySelectorAll('[data-beta]').forEach(function(el){
  el.addEventListener('click',function(e){e.preventDefault();if(dlg&&dlg.showModal){dlg.showModal();}});
});
var closeBtn=document.getElementById('betaClose');
if(closeBtn&&dlg){closeBtn.addEventListener('click',function(){dlg.close();});}
var form=document.getElementById('betaForm');
if(form){form.addEventListener('submit',function(e){
  e.preventDefault();
  var ok=document.getElementById('betaOk');
  var err=document.getElementById('betaErr');
  if(ok){ok.style.display='none';}
  if(err){err.style.display='none';}
  var btn=form.querySelector('button[type="submit"]');
  var restore=function(){if(btn){btn.disabled=false;}};
  if(btn){btn.disabled=true;}
  var action=form.getAttribute('action')||'';
  if(action.indexOf('YOUR_FORM_ID')!==-1){
    // Form backend not configured yet (hosting move in progress).
    var paused=document.documentElement.lang==='ar'
      ? 'التسجيل متوقف مؤقتاً أثناء نقل الاستضافة — عُد قريباً.'
      : 'Beta signup is paused while we move hosting — please check back soon.';
    if(err){err.textContent=paused;err.style.display='block';}
    restore();return;
  }
  fetch(action||window.location.pathname,{
    method:'POST',
    headers:{'Content-Type':'application/x-www-form-urlencoded','Accept':'application/json'},
    body:new URLSearchParams(new FormData(form)).toString()
  }).then(function(res){
    if(!res.ok){throw new Error('bad status '+res.status);}
    if(ok){ok.style.display='block';}
    form.reset();
    restore();
  }).catch(function(){
    if(err){err.style.display='block';}
    restore();
  });
});}
var y=document.getElementById('year');if(y){y.textContent=new Date().getFullYear();}
})();

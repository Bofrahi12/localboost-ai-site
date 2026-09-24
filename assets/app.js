(function(){
"use strict";
var menuBtn=document.querySelector('.menu-toggle'),mobileNav=document.getElementById('mobileNav');
if(menuBtn&&mobileNav){menuBtn.addEventListener('click',function(){
  var open=mobileNav.classList.toggle('open');
  menuBtn.setAttribute('aria-expanded',open?'true':'false');
});}
var y=document.getElementById('year');if(y){y.textContent=new Date().getFullYear();}
})();

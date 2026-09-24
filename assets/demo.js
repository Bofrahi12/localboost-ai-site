/* LocalBoost AI — interactive demo (sample data only, runs fully in the browser). */
(function(){
"use strict";
var D = window.LBAI_DEMO;
if(!D || !D.businesses) return;

var bizWrap   = document.getElementById('demoBusinesses');
var runBtn    = document.getElementById('demoRun');
var scanBox   = document.getElementById('demoScan');
var scanSteps = document.getElementById('demoScanSteps');
var scanBar   = document.getElementById('demoScanBar');
var resultsBox= document.getElementById('demoResults');
var issuesBox = document.getElementById('demoIssues');
var resetBtn  = document.getElementById('demoReset');
var scoreNum  = document.getElementById('demoScoreNum');
var scoreRing = document.getElementById('demoScoreRing');
var issuesCount = document.getElementById('demoIssuesCount');
var monScore  = document.getElementById('demoMonScore');
var monApplied= document.getElementById('demoMonApplied');
if(!bizWrap || !runBtn) return;

var selected = null, applied = {}, currentScore = 0, scoreTimer = null;
var CIRC = 351.86;

function el(tag, cls, text){
  var e = document.createElement(tag);
  if(cls) e.className = cls;
  if(text !== undefined && text !== null) e.textContent = text;
  return e;
}
function ringColor(s){ return s < 50 ? '#dc2626' : (s < 75 ? '#d97706' : '#059669'); }

function setScore(s, animate){
  s = Math.max(0, Math.min(100, Math.round(s)));
  if(scoreTimer){ clearInterval(scoreTimer); scoreTimer = null; }
  var from = currentScore;
  currentScore = s;
  scoreRing.style.stroke = ringColor(s);
  function paint(v){
    scoreNum.textContent = v;
    scoreRing.style.strokeDashoffset = (CIRC * (1 - v/100)).toFixed(2);
  }
  if(!animate || from === s){ paint(s); return; }
  var step = (s - from) / 24, i = 0;
  scoreTimer = setInterval(function(){
    i++;
    paint(Math.round(from + step * i));
    if(i >= 24){ clearInterval(scoreTimer); scoreTimer = null; paint(s); }
  }, 40);
}

function appliedCount(){ return Object.keys(applied).length; }
function updateMonitor(){
  if(monScore) monScore.textContent = currentScore;
  if(monApplied) monApplied.textContent = appliedCount();
}

function issueCard(iss){
  var card = el('div', 'demo-issue sev-' + iss.sev);
  var head = el('div', 'demo-issue-head');
  head.appendChild(el('span', 'demo-sev', D.ui[iss.sev] || iss.sev));
  var t = el('strong'); t.textContent = iss.title; head.appendChild(t);
  card.appendChild(head);
  card.appendChild(el('p', 'demo-problem', iss.problem));
  if(iss.fixable){
    var btn = el('button', 'btn btn-emerald btn-sm', D.ui.fix); btn.type = 'button';
    var panel = el('div', 'demo-fix'); panel.hidden = true;
    var ba = el('div', 'demo-ba');
    var bcol = el('div', 'demo-col');
    bcol.appendChild(el('span', 'demo-col-label', D.ui.before));
    var bpre = el('pre', 'demo-code'); bpre.textContent = iss.before; bcol.appendChild(bpre);
    var acol = el('div', 'demo-col');
    acol.appendChild(el('span', 'demo-col-label', D.ui.after));
    var apre = el('pre', 'demo-code after'); apre.textContent = iss.after; acol.appendChild(apre);
    ba.appendChild(bcol); ba.appendChild(acol); panel.appendChild(ba);
    var apply = el('button', 'btn btn-primary btn-sm', D.ui.apply); apply.type = 'button';
    var msg = el('p', 'demo-applied-msg', D.ui.appliedMsg); msg.hidden = true;
    panel.appendChild(apply); panel.appendChild(msg);
    btn.addEventListener('click', function(){
      panel.hidden = !panel.hidden;
      btn.textContent = panel.hidden ? D.ui.fix : D.ui.hide;
    });
    apply.addEventListener('click', function(){
      if(applied[iss.id]) return;
      applied[iss.id] = true;
      apply.disabled = true; apply.textContent = D.ui.applied;
      card.classList.add('fixed'); msg.hidden = false;
      setScore(currentScore + (iss.points || 0), true);
      updateMonitor();
    });
    card.appendChild(btn); card.appendChild(panel);
  } else {
    card.appendChild(el('p', 'demo-advisory', (D.ui.advisory || 'Advisory') + ': ' + iss.note));
  }
  return card;
}

function showResults(){
  scanBox.hidden = true;
  resultsBox.hidden = false;
  issuesBox.innerHTML = '';
  applied = {};
  selected.issues.forEach(function(iss){ issuesBox.appendChild(issueCard(iss)); });
  issuesCount.textContent = D.ui.issuesFound(selected.issues.length);
  setScore(0, false);
  setScore(selected.baseScore, true);
  updateMonitor();
  resultsBox.scrollIntoView({behavior:'smooth', block:'start'});
}

D.businesses.forEach(function(b){
  var card = el('button', 'demo-biz'); card.type = 'button';
  card.setAttribute('aria-pressed', 'false');
  var nm = el('span', 'demo-biz-name', b.name);
  var mt = el('span', 'demo-biz-meta', b.type + ' · ' + b.city);
  var ur = el('span', 'demo-biz-url', b.url);
  card.appendChild(nm); card.appendChild(mt); card.appendChild(ur);
  if(b.real){ card.appendChild(el('span', 'demo-real-badge', D.ui.realAudit || 'Real audit')); }
  card.addEventListener('click', function(){
    selected = b; applied = {};
    Array.prototype.forEach.call(bizWrap.querySelectorAll('.demo-biz'), function(c){
      c.classList.remove('sel'); c.setAttribute('aria-pressed', 'false');
    });
    card.classList.add('sel'); card.setAttribute('aria-pressed', 'true');
    runBtn.disabled = false;
    resultsBox.hidden = true; scanBox.hidden = true;
  });
  bizWrap.appendChild(card);
});

runBtn.addEventListener('click', function(){
  if(!selected || runBtn.disabled) return;
  resultsBox.hidden = true; scanBox.hidden = false;
  runBtn.disabled = true;
  scanSteps.innerHTML = '';
  scanBar.style.width = '0%';
  var steps = D.ui.scanSteps || [], i = 0;
  (function next(){
    if(i < steps.length){
      scanSteps.appendChild(el('li', '', steps[i]));
      scanBar.style.width = Math.round(((i + 1) / steps.length) * 100) + '%';
      i++;
      setTimeout(next, 360);
    } else {
      setTimeout(showResults, 400);
    }
  })();
});

if(resetBtn){ resetBtn.addEventListener('click', function(){
  applied = {}; selected = null;
  resultsBox.hidden = true; scanBox.hidden = true;
  runBtn.disabled = true;
  Array.prototype.forEach.call(bizWrap.querySelectorAll('.demo-biz'), function(c){
    c.classList.remove('sel'); c.setAttribute('aria-pressed', 'false');
  });
  setScore(0, false);
  if(monScore) monScore.textContent = '–';
  if(monApplied) monApplied.textContent = '0';
  bizWrap.scrollIntoView({behavior:'smooth', block:'center'});
});}
})();

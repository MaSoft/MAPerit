#region ============================================================
# MaPeriT.SW - PLANTILLAS HTML/CSS DEL INFORME
# ============================================================

function Get-ReportCSS {
    return @'
:root {
  --sw: 230px;
  --c-bg: #f1f5f9;
  --c-surface: #ffffff;
  --c-border: #e2e8f0;
  --c-text: #1e293b;
  --c-muted: #64748b;
  --c-accent: #1d4ed8;
  --c-accent-bg: #dbeafe;
  --c-nav: #0f172a;
  --c-nav-t: #94a3b8;
  --c-critical: #dc2626;
  --c-critical-bg: #fef2f2;
  --c-high: #ea580c;
  --c-high-bg: #fff7ed;
  --c-medium: #ca8a04;
  --c-medium-bg: #fefce8;
  --c-low: #2563eb;
  --c-low-bg: #eff6ff;
  --c-ok: #16a34a;
  --c-ok-bg: #f0fdf4;
  --r: 6px;
  --sh: 0 1px 3px rgba(0,0,0,.1),0 1px 2px rgba(0,0,0,.06);
}
*{box-sizing:border-box;margin:0;padding:0}
html{scroll-behavior:smooth}
body{
  font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',system-ui,sans-serif;
  font-size:14px;line-height:1.6;color:var(--c-text);
  background:var(--c-bg);display:flex;min-height:100vh;
}

/* ── SIDEBAR ── */
.sidebar{
  width:var(--sw);min-height:100vh;background:var(--c-nav);
  position:fixed;top:0;left:0;overflow-y:auto;z-index:100;
  display:flex;flex-direction:column;
  border-right:1px solid rgba(255,255,255,.05);
}
.sb-brand{
  padding:20px 18px 16px;border-bottom:1px solid rgba(255,255,255,.08);
}
.sb-brand-name{font-size:17px;font-weight:700;color:#fff;letter-spacing:.3px}
.sb-brand-sub{font-size:11px;color:#64748b;margin-top:3px}
.sb-case{
  padding:10px 18px;border-bottom:1px solid rgba(255,255,255,.06);
  font-size:11px;color:#64748b;
}
.sb-case strong{color:#94a3b8;display:block;font-size:10px;text-transform:uppercase;letter-spacing:.8px;margin-bottom:2px}
nav{padding:10px 0}
.sb-label{
  padding:8px 18px 3px;font-size:10px;font-weight:600;
  text-transform:uppercase;letter-spacing:1px;color:#334155;
}
nav a{
  display:block;padding:6px 18px;color:var(--c-nav-t);
  text-decoration:none;font-size:12.5px;
  border-left:3px solid transparent;transition:all .12s;
}
nav a:hover,nav a.active{color:#fff;border-left-color:#3b82f6;background:rgba(255,255,255,.04)}
.sb-footer{
  margin-top:auto;padding:14px 18px;border-top:1px solid rgba(255,255,255,.06);
  font-size:10px;color:#334155;line-height:1.6;
}

/* ── MAIN ── */
.main{margin-left:var(--sw);flex:1;min-width:0}

/* ── COVER ── */
.cover{
  background:linear-gradient(135deg,#0f172a 0%,#1e3a5f 50%,#0f172a 100%);
  color:#fff;padding:72px 64px;min-height:620px;
  display:flex;flex-direction:column;justify-content:center;
}
.cover-badge{
  display:inline-block;background:rgba(59,130,246,.2);
  border:1px solid rgba(59,130,246,.4);color:#93c5fd;
  padding:4px 14px;border-radius:20px;font-size:11px;
  font-weight:600;letter-spacing:1.2px;text-transform:uppercase;margin-bottom:28px;
}
.cover h1{font-size:44px;font-weight:800;letter-spacing:-1px;line-height:1.1}
.cover h2{font-size:17px;font-weight:400;color:#94a3b8;margin-top:10px}
.cover-grid{
  display:grid;grid-template-columns:1fr 1fr;gap:10px 48px;
  margin-top:52px;padding-top:36px;
  border-top:1px solid rgba(255,255,255,.12);
}
.cover-item label{font-size:10px;text-transform:uppercase;letter-spacing:1px;color:#64748b}
.cover-item span{display:block;font-size:15px;font-weight:600;color:#e2e8f0;margin-top:2px}
.cover-hash{
  margin-top:36px;font-family:'Cascadia Code','Fira Code','Courier New',monospace;
  font-size:10px;color:#334155;word-break:break-all;line-height:1.8;
}
.confidential{
  display:inline-block;background:rgba(220,38,38,.2);
  border:1px solid rgba(220,38,38,.4);color:#fca5a5;
  padding:4px 14px;border-radius:4px;font-size:11px;
  font-weight:700;letter-spacing:1px;text-transform:uppercase;margin-top:24px;
}

/* ── CONTENT ── */
.content{padding:48px 56px;max-width:1060px}

/* ── SECTION HEADERS ── */
.section-hdr{
  display:flex;align-items:center;gap:14px;
  padding-bottom:14px;border-bottom:2px solid var(--c-border);
  margin:48px 0 28px;
}
.sec-num{
  background:var(--c-accent);color:#fff;
  width:34px;height:34px;border-radius:50%;
  display:flex;align-items:center;justify-content:center;
  font-size:14px;font-weight:700;flex-shrink:0;
}
.section-hdr h2{font-size:22px;font-weight:700}
.sub-hdr{
  font-size:13px;font-weight:600;color:var(--c-text);
  padding:9px 14px;margin:24px 0 10px;
  background:var(--c-surface);border-left:3px solid var(--c-accent);
  border-radius:0 var(--r) var(--r) 0;box-shadow:var(--sh);
}

/* ── STAT GRID ── */
.stat-grid{
  display:grid;grid-template-columns:repeat(auto-fit,minmax(175px,1fr));
  gap:14px;margin:24px 0;
}
.stat-card{
  background:var(--c-surface);border:1px solid var(--c-border);
  border-radius:var(--r);padding:20px 18px;box-shadow:var(--sh);
  border-top:3px solid var(--c-accent);
}
.stat-card.crit{border-top-color:var(--c-critical)}
.stat-card.ok{border-top-color:var(--c-ok)}
.stat-card.warn{border-top-color:var(--c-medium)}
.sv{font-size:34px;font-weight:800;line-height:1;color:var(--c-accent)}
.stat-card.crit .sv{color:var(--c-critical)}
.stat-card.ok .sv{color:var(--c-ok)}
.stat-card.warn .sv{color:var(--c-medium)}
.sl{font-size:12px;color:var(--c-muted);margin-top:6px}

/* ── INFO TABLE ── */
.info-table{width:100%;border-collapse:collapse;background:var(--c-surface);border-radius:var(--r);box-shadow:var(--sh);overflow:hidden}
.info-table tr{border-bottom:1px solid var(--c-border)}
.info-table tr:last-child{border-bottom:none}
.info-table td:first-child{
  background:#f8fafc;font-weight:600;font-size:11.5px;
  color:var(--c-muted);width:210px;padding:10px 14px;
  text-transform:uppercase;letter-spacing:.3px;white-space:nowrap;
}
.info-table td{padding:10px 14px;font-size:13px;word-break:break-word}

/* ── DATA TABLES ── */
.tcard{
  background:var(--c-surface);border-radius:var(--r);
  box-shadow:var(--sh);border:1px solid var(--c-border);
  overflow:hidden;margin:10px 0 20px;
}
.ttoolbar{
  padding:10px 14px;background:#f8fafc;
  border-bottom:1px solid var(--c-border);
  display:flex;align-items:center;justify-content:space-between;
  flex-wrap:wrap;gap:8px;
}
.ttoolbar-label{font-size:11px;font-weight:600;color:var(--c-muted);text-transform:uppercase;letter-spacing:.5px}
.tsearch{
  padding:5px 10px;border:1px solid var(--c-border);border-radius:4px;
  font-size:12px;width:190px;background:#fff;color:var(--c-text);
}
.tsearch:focus{outline:none;border-color:var(--c-accent);box-shadow:0 0 0 2px rgba(29,78,216,.15)}
.twrap{overflow-x:auto;-webkit-overflow-scrolling:touch}
.dtable{width:100%;border-collapse:collapse;font-size:12.5px;min-width:400px}
.dtable thead{background:#1e293b;position:sticky;top:0;z-index:2}
.dtable th{
  padding:9px 12px;text-align:left;font-weight:600;
  color:#e2e8f0;font-size:11px;letter-spacing:.3px;
  white-space:nowrap;border-right:1px solid rgba(255,255,255,.06);
}
.dtable th:last-child{border-right:none}
.dtable td{
  padding:7px 12px;border-bottom:1px solid #f1f5f9;
  vertical-align:top;max-width:280px;
  overflow:hidden;text-overflow:ellipsis;white-space:nowrap;
}
.dtable tbody tr:hover{background:#f0f7ff}
.dtable tbody tr:last-child td{border-bottom:none}
.dtable td.w{white-space:normal;word-break:break-word;max-width:none}
.dtable td.mono{font-family:'Cascadia Code','Fira Code','Courier New',monospace;font-size:11px;color:#475569}
.tnote{
  padding:7px 14px;background:#fffbeb;border-top:1px solid #fef3c7;
  font-size:11px;color:#92400e;
}

/* ── PHASES TABLE ── */
.phases-table{width:100%;border-collapse:collapse;background:var(--c-surface);border-radius:var(--r);box-shadow:var(--sh);overflow:hidden}
.phases-table th{background:#1e293b;color:#e2e8f0;padding:10px 14px;font-size:12px;font-weight:600;text-align:left}
.phases-table td{padding:9px 14px;border-bottom:1px solid var(--c-border);font-size:13px}
.phases-table tr:last-child td{border-bottom:none}
.phases-table tr:hover td{background:#f8fafc}

/* ── BADGES ── */
.badge{display:inline-flex;align-items:center;padding:2px 9px;border-radius:4px;font-size:11px;font-weight:600;white-space:nowrap}
.b-ok{background:#dcfce7;color:#15803d}
.b-warn{background:#fef9c3;color:#a16207}
.b-err{background:#fee2e2;color:#b91c1c}
.b-info{background:#dbeafe;color:#1d4ed8}
.b-skip{background:#f3f4f6;color:#6b7280}

/* ── ANOMALIES ── */
.anom-card{
  background:var(--c-surface);border:1px solid var(--c-border);
  border-radius:var(--r);margin:10px 0;box-shadow:var(--sh);overflow:hidden;
}
.anom-hdr{
  display:flex;align-items:flex-start;gap:12px;
  padding:12px 16px;border-bottom:1px solid var(--c-border);
}
.anom-card.sc .anom-hdr{background:var(--c-critical-bg);border-bottom-color:#fecaca}
.anom-card.sh .anom-hdr{background:var(--c-high-bg);border-bottom-color:#fed7aa}
.anom-card.sm .anom-hdr{background:var(--c-medium-bg);border-bottom-color:#fef08a}
.anom-card.sl .anom-hdr{background:var(--c-low-bg);border-bottom-color:#bfdbfe}
.anom-body{padding:14px 16px}
.anom-body p{margin:5px 0;font-size:13px}
.anom-title{font-size:13.5px;font-weight:600;flex:1;line-height:1.4}
.anom-id{font-family:monospace;font-size:11px;color:var(--c-muted);white-space:nowrap}
.sev{
  display:inline-flex;align-items:center;padding:3px 10px;
  border-radius:20px;font-size:11px;font-weight:700;white-space:nowrap;flex-shrink:0;
}
.sev.CRITICA{background:var(--c-critical);color:#fff}
.sev.ALTA{background:var(--c-high);color:#fff}
.sev.MEDIA{background:var(--c-medium);color:#fff}
.sev.BAJA{background:var(--c-low);color:#fff}
.sev.INFORMATIVA{background:#94a3b8;color:#fff}

/* ── COLLAPSIBLE ── */
details{margin:6px 0}
summary{
  display:flex;align-items:center;gap:8px;
  padding:10px 14px;background:#f8fafc;border:1px solid var(--c-border);
  border-radius:var(--r);cursor:pointer;font-weight:600;font-size:13px;
  list-style:none;user-select:none;transition:background .12s;
}
summary::before{content:'▶';font-size:10px;transition:transform .15s;flex-shrink:0}
details[open]>summary::before{transform:rotate(90deg)}
details[open]>summary{border-radius:var(--r) var(--r) 0 0;border-bottom-color:transparent}
details[open]>.det-body{
  border:1px solid var(--c-border);border-top:none;
  border-radius:0 0 var(--r) var(--r);padding:14px;background:var(--c-surface);
}

/* ── SIGNATURE ── */
.sig-grid{display:grid;grid-template-columns:1fr 1fr;gap:48px;margin-top:60px;padding-top:36px;border-top:2px solid var(--c-border)}
.sig-item{text-align:center}
.sig-line{border-top:1px solid #94a3b8;margin-top:70px;padding-top:8px;font-size:13px}

/* ── TEXT ── */
p{margin:8px 0;text-align:justify}
.alert{padding:10px 14px;border-radius:var(--r);margin:10px 0;font-size:13px}
.alert-warn{background:#fffbeb;border:1px solid #fef3c7;color:#92400e}
.alert-info{background:#eff6ff;border:1px solid #dbeafe;color:#1d4ed8}
.alert-ok{background:#f0fdf4;border:1px solid #dcfce7;color:#15803d}
.alert-crit{background:var(--c-critical-bg);border:1px solid #fecaca;color:var(--c-critical);font-weight:600}

/* ── FOOTER ── */
.report-footer{
  text-align:center;font-size:11px;color:var(--c-muted);
  border-top:1px solid var(--c-border);padding:20px 56px;margin-top:0;
}

/* ── PRINT ── */
@media print{
  .sidebar{display:none}
  .main{margin-left:0}
  .content{padding:20px}
  .cover{background:#0f172a!important;-webkit-print-color-adjust:exact;print-color-adjust:exact;padding:40px}
  .cover h1{font-size:32px}
  .tcard,.info-table,.phases-table{box-shadow:none}
  .page-break{page-break-before:always}
  .dtable thead{background:#1e293b!important;-webkit-print-color-adjust:exact;print-color-adjust:exact}
  nav a,.sb-brand,.sb-footer,.ttoolbar .tsearch{display:none}
  details>summary::before{display:none}
  details>.det-body{display:block!important}
}
@page{size:A4;margin:1.5cm}
'@
}

function Get-ReportJS {
    return @'
(function(){
  // Search filter
  window.filterTable = function(inputId, tableId) {
    var f = document.getElementById(inputId).value.toUpperCase();
    var trs = document.getElementById(tableId).querySelectorAll('tbody tr');
    trs.forEach(function(tr){
      var txt = tr.textContent.toUpperCase();
      tr.style.display = txt.indexOf(f) > -1 ? '' : 'none';
    });
  };

  // Sidebar active link on scroll
  document.addEventListener('DOMContentLoaded', function(){
    var sections = document.querySelectorAll('[data-sec]');
    var links = document.querySelectorAll('nav a[href^="#"]');
    if(!sections.length || !links.length) return;
    var io = new IntersectionObserver(function(entries){
      entries.forEach(function(e){
        if(e.isIntersecting){
          var id = e.target.id;
          links.forEach(function(a){
            a.classList.toggle('active', a.getAttribute('href') === '#'+id);
          });
        }
      });
    },{rootMargin:'-20% 0px -70% 0px'});
    sections.forEach(function(s){ io.observe(s); });
  });
})();
'@
}

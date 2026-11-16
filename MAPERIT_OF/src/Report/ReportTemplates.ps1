#region ============================================================
# MaPeriT.OF - PLANTILLAS HTML/CSS DEL INFORME
# Mismo diseño que MaPeriT.SW para coherencia visual.
# ============================================================

function Get-OFCss {
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
.sb-brand{padding:20px 18px 16px;border-bottom:1px solid rgba(255,255,255,.08)}
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
  color:#fff;padding:72px 64px;min-height:580px;
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
.stat-card.ok{border-top-color:var(--c-ok)}
.stat-card.warn{border-top-color:var(--c-medium)}
.stat-card.err{border-top-color:var(--c-critical)}
.sv{font-size:34px;font-weight:800;line-height:1;color:var(--c-accent)}
.stat-card.ok .sv{color:var(--c-ok)}
.stat-card.warn .sv{color:var(--c-medium)}
.stat-card.err .sv{color:var(--c-critical)}
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

/* ── PHASES TABLE ── */
.phases-table{width:100%;border-collapse:collapse;background:var(--c-surface);border-radius:var(--r);box-shadow:var(--sh);overflow:hidden}
.phases-table th{background:#1e293b;color:#e2e8f0;padding:10px 14px;font-size:12px;font-weight:600;text-align:left}
.phases-table td{padding:9px 14px;border-bottom:1px solid var(--c-border);font-size:13px}
.phases-table tr:last-child td{border-bottom:none}
.phases-table tr:hover td{background:#f8fafc}

/* ── BADGES ── */
.badge{display:inline-flex;align-items:center;padding:2px 9px;border-radius:4px;font-size:11px;font-weight:600;white-space:nowrap}
.b-ok{background:#dcfce7;color:#15803d}
.b-na{background:#f3f4f6;color:#6b7280}
.b-info{background:#dbeafe;color:#1d4ed8}
.b-err{background:#fee2e2;color:#b91c1c}

/* ── DIR TREE ── */
.dir-tree{
  font-family:'Cascadia Code','Fira Code','Courier New',monospace;
  font-size:12px;background:#f8fafc;
  border:1px solid var(--c-border);border-radius:var(--r);
  padding:16px 20px;line-height:1.9;color:var(--c-text);
  overflow-x:auto;white-space:pre;margin:10px 0 20px;
}
.dir-tree .folder{color:var(--c-accent);font-weight:600}
.dir-tree .file{color:var(--c-muted)}
.dir-tree .highlight-file{color:var(--c-critical);font-weight:600}

/* ── ALERTS ── */
p{margin:8px 0;text-align:justify}
.alert{padding:10px 14px;border-radius:var(--r);margin:10px 0;font-size:13px}
.alert-warn{background:#fffbeb;border:1px solid #fef3c7;color:#92400e}
.alert-info{background:#eff6ff;border:1px solid #dbeafe;color:#1d4ed8}
.alert-ok{background:#f0fdf4;border:1px solid #dcfce7;color:#15803d}
.alert-danger{background:#fef2f2;border:1px solid #fecaca;color:#991b1b}

/* ── SIGNATURE ── */
.sig-grid{display:grid;grid-template-columns:1fr 1fr;gap:48px;margin-top:60px;padding-top:36px;border-top:2px solid var(--c-border)}
.sig-item{text-align:center}
.sig-line{border-top:1px solid #94a3b8;margin-top:70px;padding-top:8px;font-size:13px}

/* ── FOOTER ── */
.report-footer{
  text-align:center;font-size:11px;color:var(--c-muted);
  border-top:1px solid var(--c-border);padding:20px 56px;
}

/* ── PRINT ── */
@media print{
  .sidebar{display:none}
  .main{margin-left:0}
  .content{padding:20px}
  .cover{background:#0f172a!important;-webkit-print-color-adjust:exact;print-color-adjust:exact;padding:40px}
  .cover h1{font-size:32px}
  .page-break{page-break-before:always}
  .info-table,.phases-table{box-shadow:none}
}
@page{size:A4;margin:1.5cm}
'@
}

function Get-OFJs {
    return @'
(function(){
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

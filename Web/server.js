// Dashboard local del proyecto Loteria Nacional.
// Sirve el dashboard HTML (Documentación) con una franja de estado EN VIVO
// consultada al cluster rqlite. Sin dependencias (Node >= 18).
// Puerto 3020 - registrado en pm2 como "loteria-dashboard".

const http = require("http");
const fs = require("fs");
const path = require("path");

const PORT = Number(process.env.LOTERIA_PORT) || 3020;
const RAIZ = path.resolve(__dirname, "..");
const DOCS = path.join(RAIZ, "Documentación");
const HTML = path.join(DOCS, "Dashboard Estado de Datos.html");
const MAPA = path.join(DOCS, "Mapa Premios.html");
// IPs semilla del cluster rqlite. Cambialas con LOTERIA_SEMILLAS=ip1,ip2,...
const SEMILLAS = (process.env.LOTERIA_SEMILLAS ||
  "192.168.1.190,192.168.1.124,192.168.1.69,192.168.1.250").split(",");
let liderCache = null;

async function lider() {
  if (liderCache) return liderCache;
  for (const ip of SEMILLAS) {
    try {
      const r = await fetch(`http://${ip}:4001/status`, { signal: AbortSignal.timeout(4000) });
      const j = await r.json();
      const l = (j.store && j.store.leader && j.store.leader.addr || "").split(":")[0];
      if (l) { liderCache = l; return l; }
    } catch (e) { /* siguiente semilla */ }
  }
  return null;
}

async function consulta(sql) {
  const l = await lider();
  if (!l) throw new Error("cluster sin lider");
  const u = `http://${l}:4001/db/query?level=none&q=${encodeURIComponent(sql)}`;
  const r = await fetch(u, { signal: AbortSignal.timeout(8000) });
  const j = await r.json();
  if (j.results[0].error) throw new Error(j.results[0].error);
  return j.results[0].values || [];
}

async function estado() {
  const [premios, corrida, scores, pred] = await Promise.all([
    consulta("SELECT metodo, COUNT(*) FROM premio GROUP BY metodo"),
    consulta("SELECT fin, ok, filas_procesadas, comando FROM corrida ORDER BY id DESC LIMIT 1"),
    consulta("SELECT SUM(score>=90), SUM(score>=60 AND score<90), SUM(score<60) FROM calidad_sorteo"),
    consulta("SELECT para_sorteo, valor, ROUND(probabilidad*100,1) FROM prediccion WHERE ambito='ultimo-digito' ORDER BY probabilidad DESC LIMIT 1"),
  ]);
  return {
    hora: new Date().toISOString(),
    lider: liderCache,
    premios: Object.fromEntries(premios.map(v => [v[0], v[1]])),
    ultima_corrida: corrida[0] || null,
    scores: { verde: scores[0][0], ambar: scores[0][1], rojo: scores[0][2] },
    prediccion: pred[0] ? { sorteo: pred[0][0], digito: pred[0][1], pct: pred[0][2] } : null,
  };
}

const FRANJA = `
<div id="vivo" style="position:sticky;top:0;z-index:50;background:#0d2b4e;color:#fff;
  font:13px system-ui,sans-serif;padding:7px 16px;display:flex;gap:18px;flex-wrap:wrap">
  <b>EN VIVO desde rqlite</b><span id="vivo-txt">consultando el cl&uacute;ster&hellip;</span>
</div>
<script>
fetch("/api/estado").then(r=>r.json()).then(e=>{
  const t=document.getElementById("vivo-txt");
  if(e.error){t.textContent="cluster no disponible: "+e.error;return;}
  const c=e.ultima_corrida?(e.ultima_corrida[1]?"OK":"CON ERRORES")+" "+e.ultima_corrida[0]:"sin corridas";
  t.innerHTML="premios py-coord: <b>"+(e.premios["py-coord"]||0).toLocaleString()+"</b>"
    +" &middot; calidad: <b style='color:#7fe08c'>"+e.scores.verde+"</b>/<b style='color:#ffd479'>"+e.scores.ambar+"</b>/<b style='color:#ff9b9b'>"+e.scores.rojo+"</b>"
    +" &middot; &uacute;ltima corrida: "+c
    +(e.prediccion?" &middot; sorteo "+e.prediccion.sorteo+": d&iacute;gito <b>"+e.prediccion.digito+"</b> ("+e.prediccion.pct+"%)":"")
    +" &middot; l&iacute;der "+e.lider;
}).catch(err=>{document.getElementById("vivo-txt").textContent="API sin respuesta";});
</script>
`;

const server = http.createServer(async (req, res) => {
  try {
    // El dashboard enlaza el mapa con una ruta RELATIVA ("Mapa%20Premios.html") para que
    // el mismo fichero sirva desde GitHub Pages, desde disco y desde aqui. Normalizamos
    // la URL una sola vez para reconocer tanto /mapa como /Mapa%20Premios.html.
    let ruta = req.url;
    try { ruta = decodeURIComponent(req.url); } catch (e) { /* URL malformada: se usa tal cual */ }
    const rutaBaja = ruta.toLowerCase();

    if (req.url.startsWith("/api/estado")) {
      let cuerpo;
      try {
        cuerpo = await estado();
      } catch (e) {
        liderCache = null;
        cuerpo = { error: e.message };
      }
      res.writeHead(200, { "Content-Type": "application/json; charset=utf-8" });
      res.end(JSON.stringify(cuerpo));
      return;
    }
    if (ruta === "/" || rutaBaja.startsWith("/index") || rutaBaja.startsWith("/dashboard")) {
      const html = fs.readFileSync(HTML, "utf-8");
      res.writeHead(200, { "Content-Type": "text/html; charset=utf-8" });
      res.end(FRANJA + html);
      return;
    }
    if (rutaBaja.startsWith("/mapa")) {
      const html = fs.readFileSync(MAPA, "utf-8");
      res.writeHead(200, { "Content-Type": "text/html; charset=utf-8" });
      res.end(html);
      return;
    }
    res.writeHead(404, { "Content-Type": "text/plain" });
    res.end("no encontrado");
  } catch (e) {
    res.writeHead(500, { "Content-Type": "text/plain; charset=utf-8" });
    res.end("error: " + e.message);
  }
});

server.listen(PORT, "0.0.0.0", () => {
  console.log(`loteria-dashboard escuchando en http://localhost:${PORT}`);
});

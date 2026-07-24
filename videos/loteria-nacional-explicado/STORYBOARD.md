---
format: 1920x1080
duration: 80s
message: "Un pipeline artesanal preservó 24 años de sorteos y respondió con estadística honesta si la lotería está arreglada"
arc: concept-explainer with process
audience: "Lectores del README en GitHub: curiosos técnicos y estudiantes de datos"
mode: autonomous
music: none
language: es
---

## Video direction

- palette system: `frame.md` (cobalt-grid) — papel crema cálido como campo, tinta cobalto eléctrico como ÚNICA tinta de acento (barras, sellos, fichas, subrayados), la cuadrícula de papel milimetrado permanente como fondo ambiental, serif Newsreader para display, Hanken Grotesk para cuerpo, DM Mono para cifras/chrome. Nada de gradientes morados ni bokeh.
- motion grammar: video SILENCIOSO — cada revelado se marca al ritmo del beat (no hay VO): nada se vuelca a t=0; cada pieza entra cuando su idea "se dice" en pantalla, con la mitad trasera de cada cuadro cargando los remates. Eases long-tail suaves (`power3`), sin rebotes. Durante los holds: quietud; a lo sumo subtle jitter (`sine-wave-loop` de baja amplitud) o internals vivos de SVG.
- rhythm / held frames: los cuadros 4 (principios) y 10 (cierre) son los respiros — resuelven temprano y sostienen la lectura en quietud. El clímax es el cuadro 8; llega tras la siembra del 7.
- negative list: sin slideshow (volcar-y-congelar), sin screensaver (todo flotando), sin breathing perezoso, sin pan/push en la mitad trasera, sin `repeat`/`yoyo`/`Math.random`, sin chrome de navegador ni cursores reales, sin overshoot elástico.

## Frame 1 — El gancho

- scene: Cold open de datos — la pregunta "¿ESTÁ ARREGLADA LA LOTERÍA?" explota en el centro sobre papel cuadriculado cobalto mientras contadores suben: 24 AÑOS · 800+ SORTEOS · 500,000+ PREMIOS
- voiceover:
- duration: 7s
- transition_in: cut
- status: animated
- src: compositions/frames/01-gancho.html
- type: hook
- persuasion: Rhetorical question + Statistical proof
- beat: intrigue
- blueprint: dataviz-countup (Adapt)
- focal: la pregunta "¿ESTÁ ARREGLADA LA LOTERÍA?" en serif display casi full-bleed
- roles: pregunta = foreground subject · cuadrícula milimetrada + esquinas de hairlines cobalto = background (dim ~40%) · tres contadores mono = supporting

Adapt: mantengo la firma del cold-open counter burst (la estadística explota y los satélites se lanzan a sus marcas); el "icono que estalla" se vuelve la pregunta en serif, y los tres contadores son los satélites que aterrizan después.
Scene 1 (0.0–2.0s): solo el campo crema con la cuadrícula y los hairlines superior/inferior; la pregunta entra por **per-word staggered reveal** (`dynamic-content-sequencing`) con settle long-tail, centrada, ~55% del frame, y el signo "?" final llega con **spring-pop entrance** (`spring-pop-entrance`, settle suave).
Scene 2 (2.0–4.8s): bajo la pregunta, tres cápsulas mono se revelan en secuencia (izq→der) y sus cifras suben por **value-scaled counter** (`counting-dynamic-scale`): 24 AÑOS · 800+ SORTEOS · 500,000+ PREMIOS — franja full-width, 3 capas de profundidad (cuadrícula / pregunta / cápsulas).
Scene 3 (4.8–7.0s): un **highlight sweep** de marcador cobalto (`css-marker-patterns`) subraya "ARREGLADA"; todo sostiene quieto — a lo sumo subtle jitter (`sine-wave-loop` bajo) en el subrayado.

narrativeRole: Abre la brecha cognitiva con la pregunta que todo nicaragüense se ha hecho, y establece de inmediato que la respuesta viene respaldada por una montaña de datos, no por opinión.
keyMessage: Este video responde con datos una pregunta popular: ¿está arreglada la Lotería Nacional?

## Frame 2 — El problema

- scene: Beats de tipografía dura, uno por vez sobre el papel cuadriculado: "Cada semana: un PDF oficial." → "Los enlaces mueren." → "Las descargas fallan en silencio." → "Y los reclamos populares… nadie los verifica."
- voiceover:
- duration: 8s
- transition_in: crossfade
- status: animated
- src: compositions/frames/02-problema.html
- type: pain_point
- persuasion: Pain validation + Signposting
- beat: tension
- blueprint: kinetic-type-beats (Reproduce)
- focal: cada frase de dolor, una a la vez, en display grande centrado
- roles: frases = foreground subject (relevo) · cuadrícula + una ficha de PDF esquinada que se "degrada" = supporting · campo crema = background

Scene 1 (0.0–1.8s): campo limpio; "Cada semana: un PDF oficial." entra por **per-word staggered reveal** (`dynamic-content-sequencing`), centrado ~50%; a su lado una mini-ficha "Lista-2287.pdf" en mono con **SVG self-draw** (`svg-path-draw`) del contorno.
Scene 2 (1.8–3.6s): **waterfall cut** (`cut-catalog.md`) al segundo beat: "Los enlaces mueren." — la mini-ficha pierde opacidad y su contorno se tacha con **scribble** de marcador (`css-marker-patterns`).
Scene 3 (3.6–5.6s): **hard-cut word-swap** (`discrete-text-sequence`) al tercer beat: "Las descargas fallan en silencio." con un badge mono "0 bytes" que aparece en su cue.
Scene 4 (5.6–8.0s): último beat en peso máximo: "Y los reclamos populares… nadie los verifica." — "nadie" recibe **keyword glow** cobalto (`asr-keyword-glow`); hold quieto al final.

narrativeRole: Justifica la existencia del proyecto: los datos oficiales son frágiles y las sospechas populares nunca se contrastan con evidencia.
keyMessage: Sin un archivo cuidado, ni los datos sobreviven ni los reclamos se pueden verificar.

## Frame 3 — La arquitectura

- scene: Una cámara virtual recorre lateralmente 5 estaciones de un diagrama de flujo dibujado a tinta cobalto: SITIO WEB → ARCHIVO (append-only, SHA-256) → EXTRACCIÓN DUAL (Python ⇆ AWK) → CLÚSTER RQLITE (9 teléfonos reciclados) → SALIDAS (análisis · dashboard · WhatsApp)
- voiceover:
- duration: 12s
- transition_in: push-slide LEFT
- status: animated
- src: compositions/frames/03-arquitectura.html
- type: product_intro
- persuasion: Frame-then-fill + Causal chain (A → B → C)
- beat: orientation
- blueprint: spatial-pan-stations (Reproduce)
- focal: la estación activa bajo la cámara (una por leg del pan)
- roles: 5 estaciones (tarjetas hairline con icono de línea + rótulo serif + sub-rótulo mono) = foreground por turnos · flechas conectoras que se auto-dibujan = supporting · lienzo sobredimensionado con cuadrícula = background

Scene 1 (0.0–2.2s): la cámara abre sobre la estación 1 "SITIO WEB" (un monitor de trazo con la lista de premios), rótulo por **per-word staggered reveal**; el título de cinta "LA MÁQUINA" en mono arriba. Estación ocupa ~45% del frame.
Scene 2 (2.2–4.6s): **pan lateral** (`viewport-change`) a la estación 2 "ARCHIVO" — un archivador de trazo; la flecha conectora se **auto-dibuja** (`svg-path-draw`) durante el viaje; callout mono revela en llegada: "append-only · SHA-256 · nada se borra".
Scene 3 (4.6–7.0s): pan a la estación 3 "EXTRACCIÓN DUAL" — dos engranajes de trazo enfrentados; callout: "Python (pdfplumber) ⇆ AWK (20 años)"; los engranajes giran como **live SVG internals** (`svg-icon-enrichment`) mientras la cámara está posada.
Scene 4 (7.0–9.6s): pan a la estación 4 "CLÚSTER RQLITE" — 9 teléfonos de trazo en anillo 3×3; callout con **count-up** corto (`counting-dynamic-scale`): "9 nodos · Raft · teléfonos reciclados".
Scene 5 (9.6–12.0s): pan final a la estación 5 "SALIDAS" — tres ramas (gráfico, dashboard, globo de chat) que revelan en cascada (`dynamic-content-sequencing`); la cámara aterriza y sostiene el plano con las 5 estaciones sugeridas al fondo por parallax.

narrativeRole: Presenta al protagonista — el pipeline — como una cadena causal de 5 estaciones que el ojo recorre en orden; el detalle pintoresco (9 teléfonos Android reciclados como base de datos distribuida) ancla la memoria.
keyMessage: Los datos fluyen del sitio oficial a un archivo intocable, se extraen por partida doble y terminan en una base de datos distribuida consultable.

## Frame 4 — Los principios

- scene: Tres tarjetas de tinta cobalto se autoensamblan en cascada: "① El archivo es SAGRADO — nada se borra, todo con SHA-256" · "② NINGUNA etapa falla en silencio — 0 filas = alerta" · "③ Toda la BD es RE-DERIVABLE desde el archivo"
- voiceover:
- duration: 8s
- transition_in: push-slide LEFT
- status: animated
- src: compositions/frames/04-principios.html
- type: feature_showcase
- persuasion: Rule of three + Distillation
- beat: confidence
- blueprint: grid-card-assemble (Reproduce)
- focal: el tríptico de tarjetas de principios
- roles: 3 tarjetas hairline = foreground subject · titular "TRES REGLAS" serif = supporting (upper-third) · cuadrícula = background

Scene 1 (0.0–1.4s): titular "TRES REGLAS PROTEGEN LOS DATOS" entra por per-word reveal en el tercio superior; campo limpio abajo.
Scene 2 (1.4–5.4s): las tres tarjetas se autoensamblan en **staggered cascade** (`dynamic-content-sequencing` + `spring-pop-entrance` con settle suave), una por beat (~1.3s cada una), tríptico full-width ~50% del frame; el número ① ② ③ de cada tarjeta se dibuja con **SVG self-draw** y la palabra clave (SAGRADO / silencio / RE-DERIVABLE) lleva **highlight sweep** cobalto en su cue.
Scene 3 (5.4–8.0s): cuadro RESPIRO — todo resuelto, hold quieto; solo subtle jitter mínimo en los subrayados.

narrativeRole: Condensa la filosofía de ingeniería en tres reglas memorables que explican por qué el sistema es confiable.
keyMessage: Tres reglas protegen los datos: nunca borrar, nunca fallar en silencio, y poder reconstruir todo desde el archivo.

## Frame 5 — El pipeline diario

- scene: Teatro de progreso: una lista "TareaDiaria.ps1" ejecuta sus 7 pasos y cada fila se marca ✓ en secuencia — 1 Sincronizar · 2 Extraer · 3 Cargar (lotes de 1000) · 4 Calidad · 5 Predicción · 6 Espejo · 7 Registro — cerrando con el sello "Fin OK · corrida registrada"
- voiceover:
- duration: 10s
- transition_in: push-slide LEFT
- status: animated
- src: compositions/frames/05-pipeline-diario.html
- type: feature_showcase
- persuasion: Numbered enumeration + Demonstration (show the mechanism running)
- beat: momentum
- blueprint: agent-progress-theater (Adapt)
- focal: la fila activa del checklist (una por beat) y el sello final
- roles: panel-recibo "TareaDiaria.ps1" con 7 filas = foreground subject · cabecera mono con hora "03:00 AM" = supporting · cuadrícula = background

Adapt: mantengo la firma del working-state theater (el recibo cuyas filas llegan y SE MARCAN); el "trigger" es la cabecera del script apareciendo, sin cursor ni modal.
Scene 1 (0.0–1.6s): un panel de recibo hairline entra centrado 60% del frame (asimétrico 60/40 con margen izquierdo para el título vertical "CADA DÍA"); la cabecera "▶ TareaDiaria.ps1 — 03:00" se escribe por **type-on con caret** (`discrete-text-sequence` + `context-sensitive-cursor`).
Scene 2 (1.6–8.2s): las 7 filas llegan UNA POR BEAT (~0.9s cada una) por **staggered reveal**, y cada una se marca con ✓ cobalto por **SVG self-draw** + su badge flip (`stat-bars-and-fills` para la barra de progreso fina que avanza 1/7 → 7/7); la fila 3 muestra el sub-texto mono "lotes de 1000 · reintentos de líder Raft" en su cue.
Scene 3 (8.2–10.0s): el sello "Fin OK · corrida registrada" aterriza con **spring-pop** de settle suave y **ambient glow bloom** cobalto tenue (`ambient-glow-bloom`); hold.

narrativeRole: Muestra el mecanismo vivo: cada día la máquina corre sola de punta a punta y deja auditoría de la corrida — la operación continua es lo que mantiene el archivo al día.
keyMessage: Una tarea diaria de 7 pasos sincroniza, extrae, controla calidad y respalda — y registra cada corrida.

## Frame 6 — Extracción dual

- scene: Dos paneles gemelos entran de alas opuestas con tilt de libro: "PYTHON · pdfplumber (coordenadas)" vs "AWK · 20 años de servicio (contraste)"; al centro cae el árbitro: la NOTA al pie del PDF — "LOS BILLETES TERMINADOS EN ···· GANAN" — que publica los 4 dígitos del mayor en texto plano
- voiceover:
- duration: 9s
- transition_in: crossfade
- status: animated
- src: compositions/frames/06-extraccion-dual.html
- type: feature_showcase
- persuasion: Comparison of two options + Concretization
- beat: fascination
- blueprint: comparison-split (Adapt)
- focal: primero el par de paneles; luego la tira de la NOTA como árbitro
- roles: 2 paneles (Python / AWK) = foreground subject en split-screen · tira de papel "LA NOTA" = foreground del acto 2 · cuadrícula = background

Adapt: mantengo la firma de los mirrored book-open tilts y los badges de borde interno; extiendo el remate — en vez de solo badges, una tercera pieza (la tira de la NOTA) cae al centro como árbitro.
Scene 1 (0.0–2.6s): titular "CADA NÚMERO SE LEE DOS VECES" por per-word reveal, tercio superior. Los dos paneles entran de alas opuestas con **split-tilt cards** (`split-tilt-cards`): izquierda "PYTHON · pdfplumber · coordenadas", derecha "AWK · el veterano de 20 años"; split-screen 50/50, ~45% del frame.
Scene 2 (2.6–4.8s): en cada borde interno un badge pill hace **spring-pop** suave en su beat: "método 1" / "método 2"; entre ambos un signo "⇆" se dibuja (`svg-path-draw`) y las filas coincidentes de cada panel se iluminan en pares alternos (**keyword glow**).
Scene 3 (4.8–7.2s): una tira de papel horizontal cae al centro por **scale-swap** (`scale-swap-transition`, los paneles retroceden en profundidad ~30%): "LOS BILLETES TERMINADOS EN 0595 GANAN…" en mono; el rótulo "EL ÁRBITRO: la nota al pie" revela debajo.
Scene 4 (7.2–9.0s): los 4 dígitos "0595" reciben **hand-drawn circle** de marcador (`css-marker-patterns`); hold quieto.

narrativeRole: Explica cómo se garantiza que los números extraídos son correctos: dos métodos independientes que deben coincidir, más un canal árbitro escondido en la letra pequeña del propio PDF.
keyMessage: Cada número se extrae dos veces por métodos independientes, y la nota al pie del PDF actúa de árbitro.

## Frame 7 — El veredicto de equidad

- scene: Una cuadrícula de 10 fichas de test se autoensambla (KS · rachas · autocorrelación · repeticiones · deriva temporal · millares · centenas · decenas · últimos-dos · último dígito); 9 se sellan ✓ en cobalto, una queda vibrando marcada ⚠ — y el contador remata: "9 / 10 COMPATIBLE CON UN SORTEO JUSTO"
- voiceover:
- duration: 9s
- transition_in: push-slide LEFT
- status: animated
- src: compositions/frames/07-equidad.html
- type: social_proof
- persuasion: Statistical proof + Frame-then-fill
- beat: comprehension
- blueprint: grid-card-assemble (Reproduce)
- focal: la cuadrícula de 10 fichas; al final, la ficha ⚠ "último dígito"
- roles: 10 fichas de test (rótulo + p-value en mono) = foreground subject · titular "LA BATERÍA DE EQUIDAD · 779 mayores · corrección FDR" = supporting · marcador "9/10" con count-up = supporting · cuadrícula = background

Scene 1 (0.0–1.6s): titular por per-word reveal, tercio superior: "10 PRUEBAS · 779 PREMIOS MAYORES · 24 AÑOS".
Scene 2 (1.6–6.0s): la cuadrícula 5×2 se autoensambla en **staggered cascade** (~0.45s por ficha); cada ficha llega con su p-value mono, e inmediatamente 9 se sellan ✓ por **SVG self-draw** en oleadas; el marcador "N/10" sube por **value-scaled counter** con cada sello. Grid full-width ~55% del frame, 3 capas.
Scene 3 (6.0–7.6s): la décima ficha "ÚLTIMO DÍGITO · p=0.0008" NO se sella: recibe ⚠ y un **subtle jitter** perceptible (`sine-wave-loop` bajo) + borde cobalto pleno — la anomalía queda sembrada.
Scene 4 (7.6–9.0s): remate inferior por hard-cut: "9 / 10 · COMPATIBLE CON UN SORTEO JUSTO"; hold con la ficha ⚠ aún viva.

narrativeRole: Entrega la primera mitad del veredicto con evidencia visual: la batería completa (con corrección FDR) exonera al sorteo en 9 de 10 frentes — y deja sembrada la ficha anómala que pivota al siguiente cuadro.
keyMessage: Nueve de diez pruebas estadísticas rigurosas son compatibles con un sorteo justo.

## Frame 8 — El hallazgo real

- scene: La ficha ⚠ se expande a un gráfico de barras del último dígito del premio mayor (0–9): las barras del 9 y del 5 crecen por encima de la línea esperada con conteos +36% y +27%; sello de rigor: "χ² = 28.4 · p = 0.0008 · estable 24 años"; remate en tinta: "SESGO FÍSICO DE LA TÓMBOLA — NO FRAUDE"
- voiceover:
- duration: 10s
- transition_in: zoom-through
- status: animated
- src: compositions/frames/08-hallazgo.html
- type: social_proof
- persuasion: Statistical proof + Common-belief vs reality
- beat: aha
- blueprint: dataviz-countup (Adapt)
- focal: las barras del 9 y del 5 del histograma
- roles: histograma de 10 barras (0–9) = foreground subject (~55% del frame) · línea punteada "esperado: 78" = supporting · sellos mono (χ², p, estable) = supporting · veredicto final serif = foreground del cierre · cuadrícula = background

Adapt: mantengo la firma del push-THROUGH hacia la métrica héroe; el "tilted stat grid" se vuelve un histograma limpio y el aterrizaje es sobre las dos barras culpables.
Scene 1 (0.0–2.2s): llegando del zoom-through, el marco del gráfico y el eje 0–9 se **auto-dibujan** (`svg-path-draw`); titular "EL ÚLTIMO DÍGITO DEL MAYOR" por per-word reveal, tercio superior.
Scene 2 (2.2–5.0s): las 10 barras suben en **bar-height stagger** (`stat-bars-and-fills`) hasta sus conteos reales (81·61·82·78·80·100·62·82·62·109); la línea punteada del esperado (~78) se dibuja cruzando; las barras 9 y 5 se tiñen de cobalto pleno mientras las demás quedan al 40%.
Scene 3 (5.0–7.4s): **zoom-to-target** (`coordinate-target-zoom`) suave hacia las barras 9 y 5; sus etiquetas "+36%" y "+27%" hacen **count-up** (`counting-dynamic-scale`); los sellos mono aparecen en fila en sus beats: "χ² = 28.4" · "p = 0.0008" · "estable 24 años".
Scene 4 (7.4–10.0s): el veredicto sella en serif con **kinetic beat-slam** contenido (`kinetic-beat-slam`, settle suave): "SESGO FÍSICO DE LA TÓMBOLA —" / "NO FRAUDE." con highlight sweep en "NO FRAUDE"; hold quieto.

narrativeRole: El clímax: hay un sesgo real y medible, pero la interpretación honesta lo atribuye a la física de la tómbola (sin deriva ni correlaciones), no a manipulación.
keyMessage: El último dígito del mayor favorece al 9 y al 5 — un sesgo físico estable durante 24 años, no un fraude.

## Frame 9 — ¿Se puede aprovechar?

- scene: Dos beats de datos: primero "PREDECIR EL NÚMERO COMPLETO: IMPOSIBLE — ningún modelo supera al azar (y este sistema lo admite)"; luego el contador del EV de la terminación 9 sube de C$120 a C$162.7 y sella "+35.6% — la única ventaja respaldada por datos"
- voiceover:
- duration: 9s
- transition_in: crossfade
- status: animated
- src: compositions/frames/09-ev-honesto.html
- type: benefit_highlight
- persuasion: Counterexample + Worked example with real numbers
- beat: conviction
- blueprint: dataviz-countup (Adapt)
- focal: el contador C$120 → C$162.7
- roles: beat 1 tipográfico ("IMPOSIBLE") = foreground del acto 1 · contador EV + boleto de trazo terminado en 9 = foreground del acto 2 · sello "+35.6%" = supporting · cuadrícula = background

Adapt: mantengo la firma del count-up como instrumento héroe (variante "gauge invitado dentro de un relevo tipográfico"): acto 1 es tipo, acto 2 es el contador.
Scene 1 (0.0–3.2s): beat tipográfico por per-word reveal: "¿PREDECIR EL NÚMERO COMPLETO?" y debajo, en peso máximo, "IMPOSIBLE." con **hard-cut**; sub-línea mono en su cue: "ningún modelo supera al azar — y este sistema lo admite". Centrado, ~50%.
Scene 2 (3.2–4.2s): **scale-swap** (`scale-swap-transition`): el bloque tipográfico retrocede y entra un boleto de lotería de trazo cuya terminación "···9" se circula con marcador (`css-marker-patterns`).
Scene 3 (4.2–7.0s): el contador héroe sube por **value-scaled counter**: "C$120" → "C$162.7" (crece con el valor); rótulo mono: "valor esperado del premio por terminación 9".
Scene 4 (7.0–9.0s): el sello "+35.6% · LA ÚNICA VENTAJA RESPALDADA POR DATOS" aterriza con spring-pop suave + **ambient glow bloom** tenue; hold.

narrativeRole: Aterriza el "y entonces qué": la honestidad del sistema (admite que no puede predecir) y el único hallazgo accionable, cuantificado en córdobas.
keyMessage: No se puede predecir el número ganador; la única ventaja real es el valor esperado de la terminación 9.

## Frame 10 — El cierre

- scene: Carta de título serena: "ESTADÍSTICA HONESTA SOBRE DATOS PÚBLICOS" → línea de descargo "Jugar es entretenimiento, no inversión — payout mediano: 51%" → lockup final "PRC LOTERÍA NACIONAL · el código y los datos, en GitHub"
- voiceover:
- duration: 7s
- transition_in: crossfade
- status: animated
- src: compositions/frames/10-cierre.html
- type: branding
- persuasion: Distillation + Callback (return to the hook's image)
- beat: resolve
- blueprint: titlecard-reveal (Reproduce)
- focal: la tesis "ESTADÍSTICA HONESTA SOBRE DATOS PÚBLICOS"
- roles: tesis serif = foreground subject · eco tenue de la pregunta del gancho (tachada con marcador) = supporting del callback · descargo + lockup mono = supporting · cuadrícula = background

Scene 1 (0.0–2.4s): la pregunta del gancho reaparece pequeña y tenue arriba ("¿está arreglada?") y se **tacha** con scribble de marcador (`css-marker-patterns`) — callback; debajo, la tesis entra con UN solo movimiento contenido (slide-up + crossfade): "ESTADÍSTICA HONESTA SOBRE DATOS PÚBLICOS", centrada ~50%.
Scene 2 (2.4–4.6s): la línea de descargo revela en su beat, en mono: "jugar es entretenimiento, no inversión · payout mediano: 51%".
Scene 3 (4.6–7.0s): cuadro RESPIRO final — el lockup "PRC LOTERÍA NACIONAL" con el bloque QR-block signature del pack y "el código y los datos, en GitHub" aparecen con crossfade sereno; HOLD absoluto hasta el último frame (este es el único cuadro con exit real: fade a campo crema en los últimos 0.4s).

narrativeRole: Cierra el arco respondiendo la pregunta del gancho con la tesis destilada, deja el descargo ético explícito y apunta al repositorio.
keyMessage: La respuesta a la pregunta inicial es honesta y verificable — y todo el código y los datos son públicos.

---
workflow: faceless-explainer
flow: automation
storyboard: no
message: "Un pipeline artesanal preservó 24 años de sorteos de la Lotería Nacional de Nicaragua y respondió con estadística honesta si está arreglada: 9 de 10 pruebas limpias, un sesgo físico real en el último dígito."
destination: github-readme
aspect: "16:9"
language: es
audience: "Lectores del README en GitHub: curiosos técnicos y estudiantes de datos"
length: 80s
angle: concept
music: none
narration: none
---

## Intent

Video explicativo educacional en español, silencioso (tipografía cinética — sin narración ni música: sin credenciales HeyGen ni motores locales disponibles), para acompañar el README del proyecto "PRC Lotería Nacional" en GitHub.

Debe explicar tres cosas, en este orden:

1. **La arquitectura**: sitio web oficial → archivo append-only (PDFs sagrados, SHA-256) → extracción dual (pdfplumber + AWK de contraste) → clúster rqlite de 9 teléfonos Android reciclados → análisis / dashboard / chatbot WhatsApp.
2. **El pipeline diario de 7 pasos**: sincronizar, extraer, cargar, calidad, predicción, espejo, registro — y que ninguna etapa falla en silencio.
3. **Los hallazgos**: 9/10 tests de equidad limpios (con corrección FDR); el hallazgo real: el último dígito del mayor favorece al 9 (+36%) y al 5 (+27%), sesgo físico de tómbola estable 24 años, no fraude; EV de la terminación 9 = +35.6% — y la honestidad: ningún modelo predice el número completo.

Tono: educacional, riguroso pero con personalidad; cierre con el descargo (jugar es entretenimiento, no inversión).

## Customizations

- Sin audio (silencioso). Sin captions (no hay narración que subtitular).
- Cifras clave con tratamiento de conteo/destaque (count-up / stat hits).

## Notes

- Decisiones tomadas de forma autónoma (usuario pidió "créate un video con hyperframes… todo explicado y fácil de entender"); dirección elegida: explicador conceptual con diagramas y data-viz; camino descartado: promo de producto con capturas del sitio.

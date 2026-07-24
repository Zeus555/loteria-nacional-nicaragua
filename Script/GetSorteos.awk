# Parsea el HTML de /lista-sorteos/ y emite una fila CSV por sorteo:
#   NumSorteo@UrlPDF@Fecha@UrlImagen@0
# Campos sin dato se emiten como "-" para que el .bat mantenga las posiciones.
#
# Regla de oro (corrige el corrimiento detectado el 2026-07-19): cada PDF e
# imagen se asigna al sorteo por el numero que lleva SU PROPIA URL
# (Lista-2286.pdf => sorteo 2286), nunca por su posicion en la pagina.
# La fecha se asigna al ultimo <h1>Sorteo N</h1> visto (la fecha siempre
# aparece despues del h1 dentro del mismo bloque).

BEGIN{
	OFS="@"
	Dominio="https://www\\.loterianacional\\.com\\.ni"
}
{
	# PDFs de listas: pueden venir varios en una misma linea.
	tmp=$0
	while (match(tmp, "href=\042(" Dominio "/wp-content/uploads/[0-9]{4}/[0-9]{2}/Lista-([0-9]{4})\\.pdf)\042", m)){
		if (!(m[2] in PDF)){ PDF[m[2]]=m[1] }
		tmp=substr(tmp, RSTART+RLENGTH)
	}

	# Imagenes del sorteo: el nombre del fichero empieza con el numero de sorteo.
	tmp=$0
	while (match(tmp, "src=\042(" Dominio "/wp-content/uploads/[0-9]{4}/[0-9]{2}/([0-9]{4})[^\042/]*\\.jpg)\042", m)){
		if (!(m[2] in IMG)){ IMG[m[2]]=m[1] }
		tmp=substr(tmp, RSTART+RLENGTH)
	}

	# Encabezados de sorteo.
	tmp=$0
	while (match(tmp, "<h1>Sorteo ([0-9]{4})</h1>", m)){
		SORTEO[m[1]]=1
		UltimoSorteo=m[1]
		tmp=substr(tmp, RSTART+RLENGTH)
	}

	# Fecha: pertenece al ultimo sorteo encabezado.
	if (UltimoSorteo!="" && match($0, "Fecha: ([0-9]{2} de [A-Za-z]+ [0-9]{4})", m)){
		if (!(UltimoSorteo in FECHA)){ FECHA[UltimoSorteo]=m[1] }
	}
}
END{
	# Union de todos los numeros de sorteo vistos por cualquier via.
	for (n in PDF)   { TODOS[n]=1 }
	for (n in IMG)   { TODOS[n]=1 }
	for (n in SORTEO){ TODOS[n]=1 }

	cnt=0
	for (n in TODOS){
		print n, (n in PDF ? PDF[n] : "-"), (n in FECHA ? FECHA[n] : "-"), (n in IMG ? IMG[n] : "-"), 0
		cnt++
	}

	# Si no se extrajo ninguna fila el sitio cambio de estructura: fallar ruidosamente.
	if (cnt==0){ exit 1 }
}

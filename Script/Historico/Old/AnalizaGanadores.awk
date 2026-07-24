BEGIN{
	FS="|"
	RS="\n"
	OFS="|"
	
	# Valores iniciales.
	MinSorteo=100000
	MaxSorteo=0
	
	# Directorios del proyecto.
	DirRaiz="C:\\Users\\Ariel Mairena\\Google Drive\\Casa\\Loteria Nacional\\"
	DirScript= DirRaiz "Script\\"
	DirTemporal= DirRaiz "Temporal\\"
	DirDatos= DirRaiz "Datos\\"
	DirResultados= DirRaiz "Resultados\\"
	DirLog= DirRaiz "Log\\"
	
	# Ficheros con vista de eventos a monitorear
	PorSortePorTipoPremio=DirResultados "PorSortePorTipoPremio.txt"
	PorSorteoPorPrefijo=DirResultados "PorSorteoPorPrefijo.txt"
	PorOcurrenciaNumeracion=DirResultados "PorOcurrenciaNumeracion.txt"
	PorOcurrenciaEntreSorteos=DirResultados "PorOcurrenciaEntreSorteos.txt"

	# Fichero de entrada donde se registran manualmente las fechas de los sorteos y el precio del billete.
	FchDatosSorteo= DirDatos "Datos Generales x Sorteo.dat"
	
	# Subimos a memoria listado de datos adicionales por sorteo.
	while (getline < FchDatosSorteo){
		# Calculamos segun la fecha actual los dias transcurridos desde la fecha del sorteo.
		DiasTranscurridos=(systime()-mktime(substr($2,0,4) " " substr($2,5,2) " " substr($2,7,2) " 0 0 0"))/(60*60*24)
	
		# Guardamos en memoria FechaSorteo, PrecioBillete y DiasTranscurridos del sorteo.
		DatosAddSorteo[$1]=$2"|"$3"|"DiasTranscurridos
	}	
}
{
	# Saltamos el encabezado.
	if(NR==1){next}
	
	# Separación de la numeración.
	Prefijo=substr($4,1,2)
	TNUno=substr($4,3,1)
	TNDos=substr($4,4,1)
	TNTres=substr($4,5,1)
	
	#Del nombre del directorio tomamos el numero del sorteo.
	n=split($1,NombFch,"\\")
	gsub(/.txt/,"",NombFch[n])
	gsub(/Ordinaria_/,"",NombFch[n])
	Sorteo=NombFch[n]+0

	# Obtenemos informacion general del sorteo, FechaSorteo, PrecioBillete y DiasTranscurridos del sorteo.
	split(DatosAddSorteo[Sorteo],ArrDatosSorteo,"|")
	
	# Corresponde a un premio Alto.
	if ($5>=10000){
		NumGanadorPremioAlto[Sorteo"|"$4]+=$5
	}
	
	#if ($4=="03019"){
	#	print "Inicio ", $4, ArrDatosSorteo[1], NumGanadorFecha[$4], NumGanadorFecha[$4], Sorteo
	#}
	
	# Analitica de los cambios de dias de antiguedad de un numero segun sus apariciones en los sorteos.
	if (NumGanadorFecha[$4]){
		# Obtenemos la fecha de la ultima aparicion en un sorteo.
		FechaAntiguedadAparicionAnterior=NumGanadorFecha[$4]

		# Actualizamos fecha de aparicion en Ultimo Sorteo segun el sorteo evaluado.
		NumGanadorFecha[$4]=ArrDatosSorteo[1]
		
		# Obtenemos los dias transcurridos desde la ultima vez que salio en un sorteo hasta que volvio aparecer.
		NumGanadorDiasAntiguedad=(mktime(substr(ArrDatosSorteo[1],0,4) " " substr(ArrDatosSorteo[1],5,2) " " substr(ArrDatosSorteo[1],7,2) " 0 0 0")-mktime(substr(FechaAntiguedadAparicionAnterior,0,4) " " substr(FechaAntiguedadAparicionAnterior,5,2) " " substr(FechaAntiguedadAparicionAnterior,7,2) " 0 0 0"))/(60*60*24)

	} else {
		# Ponemos fecha del sorteo.
		NumGanadorFecha[$4]=ArrDatosSorteo[1]
		# Seteamos el sorteo procesado como el ultimo sorteo que aparecio.
		NumGanadorSorteoAnterior[$4]=Sorteo
		# Seteamos los dias de antiguedad del numero ganador a cero dado que es primera vez que se juega.
		NumGanadorDiasAntiguedad=0
	}
	
	# Conteo de los dias de antiguedad de las apariciones por cada numero en los distintos sorteos.
	AntiguedadApariciones[Sorteo"|"$4"|"NumGanadorDiasAntiguedad]++
	AparicionesCambioSorteo[Sorteo"|"$4"|"NumGanadorDiasAntiguedad]=NumGanadorSorteoAnterior[$4]"|"NumGanadorSorteoAnterior[$4] "-->" Sorteo

	#if ($4=="03019"){
	#	print "Final ", $4, NumGanadorSorteoAnterior[$4], NumGanadorDiasAntiguedad,AparicionesCambioSorteo[Sorteo"|"$4"|"NumGanadorDiasAntiguedad]
	#}
	
	# Seteamos como el sorteo anterior el sorteo actual.
	NumGanadorSorteoAnterior[$4]=Sorteo
	
	# Registramos cada numero y contamos en los sorteos el numero de apariciones,
	# contando la primera aparicion la ultima y el numero de veces que aparecio.
	NumerosGanadores[$4]++
	NumerosGanadoresMonto[$4]+=$5
	NumerosGanadoresMax= $4 > NumerosGanadoresMax ? $4 : NumerosGanadoresMax
	NumerosGanadoresMin= $4 < (NumerosGanadoresMin>0?NumerosGanadoresMin:100000) ? $4 : NumerosGanadoresMin
	NumerosGanadoresSorteoMax[$4]= Sorteo > NumerosGanadoresSorteoMax[$4] ? Sorteo : NumerosGanadoresSorteoMax[$4]
	NumerosGanadoresSorteoMin[$4]= Sorteo < (NumerosGanadoresSorteoMin[$4]?NumerosGanadoresSorteoMin[$4]:100000) ? Sorteo : NumerosGanadoresSorteoMin[$4]
	if (!NumerosGanadoresSorteo[Sorteo"|"$4]){		
		NumerosGanadoresSorteosDistintos[$4]++
	}
	NumerosGanadoresSorteo[Sorteo"|"$4]++
	
	# Conteo de ganadores por sorteo.
	MinSorteo= Sorteo+0 < MinSorteo ? Sorteo+0 : MinSorteo+0
	MaxSorteo= Sorteo+0 > MaxSorteo ? Sorteo+0 : MaxSorteo+0
	CntNumerosXSorteo[Sorteo]++
	MontoXSorteo[Sorteo]+=$5

	# Conteo de ganadores por sorteo.
	CntTipoPremioXSorteo[Sorteo"|"$3]++
	MontoTipoPremioXSorteo[Sorteo"|"$3]+=$5
	
	# Conteos para Prefijos
	MaxPrefijo= Prefijo+0 > MaxPrefijo+0 ? Prefijo+0 : MaxPrefijo+0
	CntSorteoPrefijo[Sorteo"|"Prefijo]++
	MontoSorteoPrefijo[Sorteo"|"Prefijo]+=$5
	CntSorteoPrefijoTipoPremio[Sorteo"|"Prefijo"|"$3]++
	MontoSorteoPrefijoTipoPremio[Sorteo"|"Prefijo"|"$3]+=$5
	
	# Tombolas individuales.
	{
	# Conteos para tombola uno.
	CntTNUno[TNUno]++
	MontoTNUno[TNUno]+=$5
	CntSorteoTNUno[Sorteo"|"TNUno]++
	MontoSorteoTNUno[Sorteo"|"TNUno]+=$5
	
	# Conteos para tombola dos.
	CntTNDos[TNDos]++
	MontoTNDos[TNDos]+=$5
	CntSorteoTNDos[Sorteo"|"TNDos]++
	MontoSorteoTNDos[Sorteo"|"TNDos]+=$5
	
	# Conteos para tombola tres.
	CntTNTres[TNTres]++
	MontoTNTres[TNTres]+=$5
	CntSorteoTNTres[Sorteo"|"TNTres]++
	MontoSorteoTNTres[Sorteo"|"TNTres]+=$5
	}
}
END{
	# Conteos Generales
	## Por Ocurrencia de numeración.
	print "Ocurrencia por numeracion ganadora."
	print "NumeroGanador|CntApariciones|CntAparicionesDistintas|MontoSorteos|OcurrenciaApariciones|PrimerSorteoAparecio|UltimoSorteoAparecio|OcurrAparPor1erUltimoSorteo|FechaUltimoSorteo|PrecioBilleteUltSorteo|DiasTransUltimoSorteo" > PorOcurrenciaNumeracion
	for (NumGanador in NumerosGanadores){
		print (	NumGanador,
				NumerosGanadores[NumGanador],
				NumerosGanadoresSorteosDistintos[NumGanador],
				NumerosGanadoresMonto[NumGanador],				
				NumerosGanadores[NumGanador] > NumerosGanadoresSorteosDistintos[NumGanador] ? ">" : "=",
				NumerosGanadoresSorteoMin[NumGanador],
				NumerosGanadoresSorteoMax[NumGanador],
				NumerosGanadoresSorteoMin[NumGanador] == NumerosGanadoresSorteoMax[NumGanador] ? "=" : "<",
				DatosAddSorteo[NumerosGanadoresSorteoMax[NumGanador]]) >> PorOcurrenciaNumeracion
	}
	
	## Por Sorteo.
	print "Regla de consistencia para Prefijos"
	print "... en caso que un prefijo no tenga premios asociados, lo agregamos y ponemos cero en conteo y $."
	print "Conteo por Sorteo y Prefijo"
	print "Sorteo|CntNumerosXSorteo|CntPrefijosXSorteo|MontoXSorteo|FechaSorteo|PrecioBillete|DiasTransSorteo|CntPremiosOrdinarios|CntPremioMayor|CntPremioSegundo|CntPremioTercero|CntPremioCuarto|CntPremioQuinto|CntPremioSexto|ConsistenciaMontos|MontoPremiosOrdinarios|MontoPremioMayor|MontoPremioSegundo|MontoPremioTercero|MontoPremioCuarto|MontoPremioQuinto|MontoPremioSexto" > PorSortePorTipoPremio
	print "Sorteo|CntNumerosXSorteo|MontoXSorteo|Prefijo|CntSorteoPrefijo|MontoSorteoPrefijo|AlgunMayor|CntOrd|CntMay|CntSeg|CntTer|CntCua|CntQui|CntSex" > PorSorteoPorPrefijo
	
	# Para que salgan ordenados de menos a mayor por numero de sorteo.
	{
	for (i=MinSorteo;i<=MaxSorteo;i++){
		# Solo se implime en caso que exista.
		if (CntNumerosXSorteo[i]){
			# ******Prefijos*******
			{
			# Valor Inicial.
			CntPrefijosXSorteo=0
			# Para saber cuantos prefijos se estan jugando por sorteo.
			for (k=1;k<=MaxPrefijo;k++){
				# Para aquellos prefijos con un solo digito se le agrega el cero.
				Aa=k<10?"0"k:k
				
				# En caso que exista el sorteo.
				if (CntSorteoPrefijo[i"|"Aa]){
					# Llevamos en conteo de los prefijos evaluados por cada sorteo.
					CntPrefijosXSorteo++
				} else {
					CntSorteoPrefijo[i"|"Aa]=0
					MontoSorteoPrefijo[i"|"Aa]=0
				}

				# Llevamos conteo de los premios mayores por sorteo y prefijo.
				vCntSPTP_May=CntSorteoPrefijoTipoPremio[i"|"Aa"|MAYOR"] ? CntSorteoPrefijoTipoPremio[i"|"Aa"|MAYOR"] : 0
				vCntSPTP_Seg=CntSorteoPrefijoTipoPremio[i"|"Aa"|SEGUNDO"] ? CntSorteoPrefijoTipoPremio[i"|"Aa"|SEGUNDO"] : 0
				vCntSPTP_Ter=CntSorteoPrefijoTipoPremio[i"|"Aa"|TERCER"] ? CntSorteoPrefijoTipoPremio[i"|"Aa"|TERCER"] : 0
				vCntSPTP_Cua=CntSorteoPrefijoTipoPremio[i"|"Aa"|CUARTO"] ? CntSorteoPrefijoTipoPremio[i"|"Aa"|CUARTO"] : 0
				vCntSPTP_Qui=CntSorteoPrefijoTipoPremio[i"|"Aa"|QUINTO"] ? CntSorteoPrefijoTipoPremio[i"|"Aa"|QUINTO"] : 0
				vCntSPTP_Sex=CntSorteoPrefijoTipoPremio[i"|"Aa"|SEXTO"] ? CntSorteoPrefijoTipoPremio[i"|"Aa"|SEXTO"] : 0
				
				# Validamos si el prefijo tiene uno de los premios mayores.
				vCntAlgunoDeLosPremiosMayores=vCntSPTP_May >0 ? "Si" : vCntSPTP_Seg >0 ? "Si" : vCntSPTP_Ter >0 ? "Si" : vCntSPTP_Cua >0 ? "Si"  : vCntSPTP_Qui >0 ? "Si"  : vCntSPTP_Sex >0 ? "Si" : "No"
				
				# Cantidad y Montos de premios por Prefijo.
				print (	i,
					CntNumerosXSorteo[i], 
					MontoXSorteo[i], 
					Aa,
					CntSorteoPrefijo[i"|"Aa],
					MontoSorteoPrefijo[i"|"Aa],
					vCntAlgunoDeLosPremiosMayores,
					CntSorteoPrefijoTipoPremio[i"|"Aa"|Ordinario"] ? CntSorteoPrefijoTipoPremio[i"|"Aa"|Ordinario"] : 0,
					vCntSPTP_May,
					vCntSPTP_Seg,
					vCntSPTP_Ter,
					vCntSPTP_Cua,
					vCntSPTP_Qui,
					vCntSPTP_Sex) >> PorSorteoPorPrefijo
			}}

			# ******Tipo de Premios*******
			{
			# Cantidad y montos de los premios obtenidos, en caso de no encontrarse seteamos cero.
			CntOrd=CntTipoPremioXSorteo[i"|Ordinario"] ? CntTipoPremioXSorteo[i"|Ordinario"] : 0
			CntMay=CntTipoPremioXSorteo[i"|MAYOR"] ? CntTipoPremioXSorteo[i"|MAYOR"] : 0
			CntSeg=CntTipoPremioXSorteo[i"|SEGUNDO"] ? CntTipoPremioXSorteo[i"|SEGUNDO"] : 0
			CntTer=CntTipoPremioXSorteo[i"|TERCER"] ? CntTipoPremioXSorteo[i"|TERCER"] : 0
			CntCua=CntTipoPremioXSorteo[i"|CUARTO"] ? CntTipoPremioXSorteo[i"|CUARTO"] : 0
			CntQui=CntTipoPremioXSorteo[i"|QUINTO"] ? CntTipoPremioXSorteo[i"|QUINTO"] : 0
			CntSex=CntTipoPremioXSorteo[i"|SEXTO"] ? CntTipoPremioXSorteo[i"|SEXTO"] : 0
			MonOrd=MontoTipoPremioXSorteo[i"|Ordinario"] ? MontoTipoPremioXSorteo[i"|Ordinario"] : 0
			MonMay=MontoTipoPremioXSorteo[i"|MAYOR"] ? MontoTipoPremioXSorteo[i"|MAYOR"] : 0
			MonSeg=MontoTipoPremioXSorteo[i"|SEGUNDO"] ? MontoTipoPremioXSorteo[i"|SEGUNDO"] : 0
			MonTer=MontoTipoPremioXSorteo[i"|TERCER"] ? MontoTipoPremioXSorteo[i"|TERCER"] : 0
			MonCua=MontoTipoPremioXSorteo[i"|CUARTO"] ? MontoTipoPremioXSorteo[i"|CUARTO"] : 0
			MonQui=MontoTipoPremioXSorteo[i"|QUINTO"] ? MontoTipoPremioXSorteo[i"|QUINTO"] : 0
			MonSex=MontoTipoPremioXSorteo[i"|SEXTO"] ? MontoTipoPremioXSorteo[i"|SEXTO"] : 0
			
			# Indicador de si el premio mayor es mas grande que el segundo premio, si el segundo tiene un monto mayor que el tercero y asi sucesivamente.
			ConsistenciaMontosXTipoPremio=MonMay/(CntMay==0 ? 1 : CntMay) > MonSeg/(CntSeg==0 ? 1 : CntSeg) ? ">" : "<"
			ConsistenciaMontosXTipoPremio=MonSeg/(CntSeg==0 ? 1 : CntSeg) > MonTer/(CntTer==0 ? 1 : CntTer) ? ConsistenciaMontosXTipoPremio ">" : ConsistenciaMontosXTipoPremio "<"
			ConsistenciaMontosXTipoPremio=MonTer/(CntTer==0 ? 1 : CntTer) > MonCua/(CntCua==0 ? 1 : CntCua) ? ConsistenciaMontosXTipoPremio ">" : ConsistenciaMontosXTipoPremio "<"
			ConsistenciaMontosXTipoPremio=MonCua/(CntCua==0 ? 1 : CntCua) > MonQui/(CntQui==0 ? 1 : CntQui) ? ConsistenciaMontosXTipoPremio ">" : ConsistenciaMontosXTipoPremio "<"
			ConsistenciaMontosXTipoPremio=MonQui/(CntQui==0 ? 1 : CntQui) > MonSex/(CntSex==0 ? 1 : CntSex) ? ConsistenciaMontosXTipoPremio ">" : ConsistenciaMontosXTipoPremio "<"
			
			# Imprimimos cada Sorteo.
			# Sorteo, CntNumerosXSorteo, CntPrefijosXSorteo, MontoXSorteo, FechaSorteo, PrecioBillete, DiasTransSorteo, CntPremiosOrdinarios, CntPremioMayor, CntPremioSegundo, CntPremioTercero, CntPremioCuarto, CntPremioQuinto, CntPremioSexto, MontoPremiosOrdinarios, MontoPremioMayor, MontoPremioSegundo, MontoPremioTercero, MontoPremioCuarto, MontoPremioQuinto, MontoPremioSexto
			print (	i, 
				CntNumerosXSorteo[i], 
				CntPrefijosXSorteo, 
				MontoXSorteo[i], 
				DatosAddSorteo[i],
				CntOrd, 
				CntMay, 
				CntSeg, 
				CntTer, 
				CntCua, 
				CntQui, 
				CntSex, 
				ConsistenciaMontosXTipoPremio,
				MonOrd,
				MonMay, 
				MonSeg, 
				MonTer, 
				MonCua, 
				MonQui, 
				MonSex) >> PorSortePorTipoPremio
			}
		}
	}
	}
	
	# 
	#for (ii=MinSorteo;ii<=MaxSorteo;ii++){
		# Solo se imprime en caso que exista.
	#	if (CntNumerosXSorteo[ii]){
	#		for (l=NumerosGanadoresMin;l<=NumerosGanadoresMax;l++){
				
	#		}
	#	}
	#}
	
	# Verificamos los cambios entre las apariciones por sorteo.
	print "SorteActual|NumeroGanador|DiasAntiguedadSorteoAnterior|CntAparicionesXSorteo|SorteoAnterior|CambioEntreSorteos|PremioAlto|MontoPremioAlto" > PorOcurrenciaEntreSorteos
	for (aa in AntiguedadApariciones){
		split(aa,arrAntigApar,"|")
		print aa, AntiguedadApariciones[aa], AparicionesCambioSorteo[aa], (NumGanadorPremioAlto[arrAntigApar[1]"|"arrAntigApar[2]]? "Si" : "No"), (NumGanadorPremioAlto[arrAntigApar[1]"|"arrAntigApar[2]]?NumGanadorPremioAlto[arrAntigApar[1]"|"arrAntigApar[2]]:0 ) >> PorOcurrenciaEntreSorteos
	}
	
	# > FchPorSorteoTipoPremio
	
	## Por Prefijo.
	#print "Conteo por Prefijo"
	#for (b in CntPrefijo){
	#	print b, CntPrefijo[b]
	#}

	## Por TNUno.
	#print "Conteo por TNUno"
	#for (c in CntTNUno){
	#	print c, CntTNUno[c]
	#}

	## Por TNDos.
	#print "Conteo por TNDos"
	#for (d in CntTNDos){
	#	print d, CntTNDos[d]
	#}

	## Por TNTres.
	#print "Conteo por TNTres"
	#for (e in CntTNTres){
	#	print e, CntTNTres[e]
	#}	
}
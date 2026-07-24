function NivelConfianza(Txt1,Txt2){
	# Obtenemos la longitud y separamos cada una de las posiciones de la cadena.
	vNCLongitudTxt1=split(Txt1,arrTxt1,"c")
	vNCLongitudTxt2=split(Txt2,arrTxt2,"c")
	
	# Contador de coincidencias por posición.
	Coincidentes=0
	
	# Obtenemos la longitud de la cadena menor. 
	if (vNCLongitudTxt1==vNCLongitudTxt2){
		vNCLongMin=vNCLongitudTxt1
	} else {
		if (vNCLongitudTxt1>vNCLongitudTxt2){
			vNCLongMin=vNCLongitudTxt2
		} else {
			vNCLongMin=vNCLongitudTxt1
		}
	}
	
	# Recorremos la longitud de la primera cadena, comparandola con la coincidencia en la segunda cadena.
	for (a=1;a<=vNCLongMin;a++){
		# Contadores.
		vConteoNum++
		vConteoMon++
	
		# Comparamos ambas cadenas.
		if (arrTxt1[vConteoNum]!=arrTxt2[vConteoMon]){
			if (arrTxt2[vConteoMon]==(arrTxt1[vConteoNum]+arrTxt1[vConteoNum+1])){
				# Contamos la cantidad de lineas coincidentes
				Coincidentes++
				vConteoNum++
			} else if (arrTxt1[vConteoNum]==(arrTxt2[vConteoMon]+arrTxt2[vConteoMon+1])){
				# Contamos la cantidad de lineas coincidentes
				Coincidentes++
				vConteoMon++
			} else if ((arrTxt1[vConteoNum]+arrTxt1[vConteoNum+1])==(arrTxt2[vConteoMon]+arrTxt2[vConteoMon+1])){
				# Contamos la cantidad de lineas coincidentes
				Coincidentes++
				vConteoNum++
				vConteoMon++
			} else if ((arrTxt1[vConteoNum]+arrTxt1[vConteoNum+1]+arrTxt1[vConteoNum+2])==(arrTxt2[vConteoMon]+arrTxt2[vConteoMon+1])){
				# Contamos la cantidad de lineas coincidentes
				Coincidentes++
				vConteoNum+=2
				vConteoMon++
			} else {
				# Detenemos busqueda.
				break
			}
		} else {
			# Contamos la cantidad de lineas coincidentes
			Coincidentes++
		}
	}
	
	# Obtenemos un porcentaje de confianza de los datos.
	Confianza=(Coincidentes/vNCLongMin)*100
	
	# Devolvemos el nivel de confianza.
	return Confianza
}

BEGIN{
	FS="|"
	RS="\n"
	OFS="|"

	# Palabras distintivas de un premio a buscar.
	TipoPremios["MAYOR"]=1
	TipoPremios["SEGUNDO"]=2
	TipoPremios["TERCER"]=3
	TipoPremios["CUARTO"]=4
	TipoPremios["QUINTO"]=5
	TipoPremios["SEXTO"]=6
	
	# Indicadore de tipo depuración.
	TipoDepuracion=0
	# ==0 --> Por defecto, ningún tipo depuración.
	# ==1 --> Depuración a detalle.
	# ==2 --> Imprime solo las primeras 40 filas.
	# ==3 --> Solo imprime resultados pero no los guarda en fichero de salida.
	
	# Fichero donde se encuentran listado de numeros que no son encontrados.
	FicheroNumNoFound="C:\\Users\\Ariel Mairena\\Google Drive\\Casa\\Loteria Nacional\\Datos\\Listado No Encontrados.txt"
	
	# Subimos a memoria listado de numeros que no son encontrados automaticamente y son subidos manualmente.
	while (getline < FicheroNumNoFound){
		# Solo cargamos datos del sorteo evaluado.
		if (Sorteo==$1){
			# Guardamos en memoria lista con numeros de loteria no encontrados automaticamente.
			NumNoFound[$2]=$3"|"$4
		}
	}
	
	# Restauramos separador de campos.
	FS=" "
}
{	# if ($0=="26302"){print $0}
	#if (TipoDepuracion==1){print NR,$0}
	
	# Obtenemos la longitud de la linea.
	LongitudLinea=length($0)
	
	# Identifica si es un numero de cinco digitos.
	EsNumero5Digitos=$1~/^([0-9]{5})$/ ? 1 : 0
	
	# Reemplazamos palabra de millones por la cantidad numerica.
	gsub(/MILLONES/,",000,000.00")
	
	# Verificamos si la palabra corresponde a un monto ordinario o de premios mayores.
	ValorEnNumero= $1
	gsub(/,/,"",ValorEnNumero)
	EsMontoRegular=($1~/^([0-9])+(,[0-9]{3})?+\.([0-9]{2})$/) && ValorEnNumero>100 ? 1 : 0
	EsMontoMayores=$1~/^(c\$|C\$)+([0-9])+(,[0-9]{3})?+\.([0-9]{2})$/ ? 1 : 0
	EsMonto=EsMontoRegular==1 || EsMontoMayores==1 ? 1 : 0
	
	# Se identifican los comentarios de nota por premios de terminación.
	FlagEsFinNotaTerminacion=$0~/(SE EXCEPTUA AL PREMIO MAYOR EN TODAS LAS TERMINACIONES.)$/ ? 1 : 0
	FlagEsAcumulacion=$0~/(EL BILLETE Y)+[(C\$|c\$) ]?+([0-9]{2}\.00 EL VIGESIMO)+/ ? 1 : 0
	EsFinNotaTerminacion=(EsFinNotaTerminacion==0 && FlagEsFinNotaTerminacion==1) ? 1 : EsFinNotaTerminacion
	EsAcumulacion=(EsAcumulacion==0 && FlagEsAcumulacion==1) ? 1 : EsAcumulacion
	
	if (EsFinNotaTerminacion==1 && LongitudLinea<=25 && BanInicioNumeracion==0){
		BanInicioNumeracion=1
	}
	
	# Huella ID de secuencia para el sorteo.
	if (BanInicioNumeracion==1){
		# ContadorInicio.
		ConteoInicio++
	
		# Contadores de numeros.
		if (EsNumero5Digitos==1){
			ConteoEsNumero++
			ConteoEsNumeroTot++
		}
		
		# Contadores de Montos.
		if (EsMonto==1){
			ConteoEsMonto++
			ConteoEsMontoTot++
		}
		
		# Escenario 12792,13,13013
		if (EsNumero5Digitos==1 && EsNumeroAnterior==0 && EsNumeroAntePenul==1){
			SecuenciaID["N"]=SecuenciaID["N"] "c" ConteoEsNumero-1
			ConteoEsNumero=1
		}

		# Escenario 3000.00,MIL,3000.00
		if (EsMonto==1 && EsMontoAnterior==0 && EsMontoAntePenul==1){
			#print NR, $0, ConteoEsMonto-1
			#print SecuenciaID["M"]
			SecuenciaID["M"]=SecuenciaID["M"] "c" ConteoEsMonto-1
			ConteoEsMonto=1
		}
	}
	
	#if ($0=="26302"){print "... ", BanInicioNumeracion, EsNumero, EsMontoRegular, EsMontoMayores}
	#if (TipoDepuracion==1){print "... ", BanInicioNumeracion, EsNumero5Digitos, EsMontoRegular, EsMontoMayores, EsFinNotaTerminacion, FlagEsFinNotaTerminacion, LongitudLinea}
	
	# Registramos todos los numeros ganadores.
	if (BanInicioNumeracion==1 && EsNumero5Digitos==1 && EsMontoRegular==0){
		ContadorNumero++
		ArrConteoNumPremiado[$1]++
		ArrUltimaAparicionNumPremiado[$1]=ContadorNumero
		# if ($0=="26302"){print "... #:",$1,ContadorNumero}
		#if (TipoDepuracion==1){print "... #:",$1,ContadorNumero}
		NumerosGanadores[ContadorNumero]=$1
	}

	# Registramos todos los numeros ganadores.
	if (BanInicioNumeracion==1 && EsMontoRegular==1){
		ContadorMonto++
		#if ($0=="26302"){print "... $:",$1,ContadorMonto}
		#if (TipoDepuracion==1){print "... $:",$1,ContadorMonto}
		MontoGanadores[ContadorMonto]=$1"|Normal|Ordinario"
	}
	
	# Registramos todos los numeros ganadores.
	if (BanInicioNumeracion==1 && EsMontoMayores==1){
		ContadorMonto++
		ContadorMontoMayores++
		#if ($0=="26302"){print "... $:",$1,"Mayores",ContadorMonto,ContadorMontoMayores}
		#if (TipoDepuracion==1){print "... $:",$1,"Mayores",ContadorMonto,ContadorMontoMayores}
		MontoGanadores[ContadorMonto]=$1"|Normal|"
		MontoGanadoresMayores[ContadorMontoMayores]=ContadorMonto
	}	
	
	# Verificamos si existe coincidencia de la palabra procesada con las buscadas para los premios.
	if (BanInicioNumeracion==1){
		# Recorremos cada una de las palabras de la linea.
		for (a=1;a<=NF;a++){
			# Validamos si palabra corresponde a listas de palabras claves de premios mayores.
			if ($a in TipoPremios){
				ContadorTipoMayores++
				#if (TipoDepuracion==1){print "... ABC:","Mayores",ContadorTipoMayores}
				TipoGanadoresMayores[ContadorTipoMayores]=$a
			}
		}
	}
	
	if (TipoDepuracion==1){
		if (ContadorNumero==ContadorMonto && ContadorNumero>0){
			#print "... Coincidencia Contadores",ContadorNumero,ContadorMonto,ContadorTipoMayores,ContadorMontoMayores
		} else {
			#print "... ",ContadorNumero,ContadorMonto,ContadorTipoMayores,ContadorMontoMayores
		}
		
		# Identificamos los cambios entre contadores de numero y monto.
		if (EsNumeroAnterior!=EsNumero5Digitos && EsMontoRegularAnterior!=EsMontoRegular){
			#print "CambioColumna",ContadorNumero,ContadorMonto,ContadorTipoMayores,ContadorMontoMayores				
		}
	}
	
	if (TipoDepuracion==2 && NR>=40){exit}

	EsNumeroAntePenul=EsNumeroAnterior
	EsMontoAntePenul=EsMontoAnterior	
	EsNumeroAnterior=EsNumero5Digitos
	EsMontoAnterior=EsMonto
	
	# Registramos la linea anterior en caso exista.
	LineaAnterior=$1
}
END {
	# Agregamos ultimo conteo a secuencias.
	SecuenciaID["N"]=SecuenciaID["N"] "c" ConteoEsNumero-1
	SecuenciaID["M"]=SecuenciaID["M"] "c" ConteoEsMonto-1
	
	# Obtenemos el porcentaje de confianza sobre los datos.
	PorcConfianza=NivelConfianza(SecuenciaID["N"],SecuenciaID["M"])

	# Actualizamos para los montos mayores el tipo de premio recibido.
	for (z=1;z<=ContadorMontoMayores;z++){
		MontoGanadores[MontoGanadoresMayores[z]]=MontoGanadores[MontoGanadoresMayores[z]] TipoGanadoresMayores[z]
	}

	# Actualizamos o Agregamos todos los numeros que aparecen en listado de No Encontrados.
	for (a in NumNoFound){
		# Obtenemos el detalle del numero premiado de NoFound.
		split(NumNoFound[a],arrDet,"|")
		
		# Buscamos si el numero premiado de listado NoFound NO se encuentra en listado de numeros premiados.
		if (ArrConteoNumPremiado[a]){
			# Actualizamos listado de numeros del sorteo.
			MontoGanadores[ArrUltimaAparicionNumPremiado[a]]= arrDet[1] "|Actualizado|" arrDet[2] 
		}else {
			# Aumentamos los contadores.
			ContadorNumero++
			ContadorMonto++
		
			# Agregamos a listado de numeros del sorteo.
			MontoGanadores[ContadorMonto]=arrDet[1] "|Agregado|" arrDet[2] 
		}
	}

	# Creamos Indice para Ordenar Ascendentemente el listado por numero de premio.
	for (b in NumerosGanadores){
		split(NumerosGanadores[b],ArrOrden,"|")
		IdxArrFull[b]=ArrOrden[1]+0
	}

	# Establecemos orden segun indice por numero de premio, de forma numerica ascendente.
	PROCINFO["sorted_in"] = "@val_num_asc"
	
	# Imprimimos a
	for (c in IdxArrFull){
		split(MontoGanadores[c],arrMontoGanador,"|")
	
		# Limpiamos monto ganador de simbolos y comas.
		vMontoGan=arrMontoGanador[1]
		gsub(/[(C$|c$),]/,"",vMontoGan)
		
		if (TipoDepuracion==0){
			printf "%s|%s|%s|%s|%s|%3.2f\n", Sorteo, arrMontoGanador[3], NumerosGanadores[c], vMontoGan, arrMontoGanador[2], PorcConfianza >> FchEstadisticas
		} else if (TipoDepuracion==3){
			print Sorteo "|" arrMontoGanador[3] "|" NumerosGanadores[c] "|" vMontoGan "|" arrMontoGanador[2]
		}
	}

	# En caso que contador sean distintos reportamos errores.
	if (ContadorNumero!=ContadorMonto){
		print "... Error: contadores de Numero y Monto Distintos ... ", Sorteo, ContadorNumero, ContadorMonto
		for (i=1;i<=ContadorNumero;i++){
			# En caso que no exista el monto del numero ganador.
			if (NumerosGanadores[i] && MontoGanadores[i]==""){
				print "... ", Sorteo, NumerosGanadores[i], MontoGanadores[i]
			}
			
			# En caso que no exista el numero ganador.
			if (NumerosGanadores[i]=="" && MontoGanadores[i]){
				print "... ", Sorteo, NumerosGanadores[i], MontoGanadores[i]
			}
		}
		exit 1
	} else {
		# Verificamos el nivel de confianza.
		if (PorcConfianza==100){
			printf "%s %3.2f\n", "Ok", PorcConfianza
		} else {
			printf "%s %3.2f\n", "Error:", PorcConfianza
			print SecuenciaID["N"]
			print SecuenciaID["M"]
			exit 2
		}
	}	
}
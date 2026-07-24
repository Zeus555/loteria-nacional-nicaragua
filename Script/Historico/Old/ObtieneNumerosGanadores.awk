  # Función encargada de concatenar un mismo texto n cantidad de veces.
function RepiteTxt(vTxt, vNumRepeticiones){
	# Limpiamos variable de salida.
	vTxtSalida=""
	
	# Ciclo con la cantidad de repeticiones de la concatenación.
	for (j=1;j<=vNumRepeticiones;j++){
		# Concatenamos texto ciclicamente.
		vTxtSalida=vTxtSalida""vTxt
	}
	
	# Devolvemos texto concatenado segun numero de repeticiones.
	return vTxtSalida
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
	
	# Subimos a memoria listado de numeros que no son encontrados automaticamente y son subidos manualmente.
	while (getline < FicheroNumNoFound){
		# Guardamos en memoria lista con numeros de loteria no encontrados automaticamente.
		NumNoFound[$1"|"$2]=$3"|"$4
	}
}
{
	# Obtenemos el numero de sorteo segun el nombre del fichero.
	n=split(FILENAME,NombFch,"\\")
	gsub(/.txt/,"",NombFch[n])
	gsub(/Ordinaria_/,"",NombFch[n])
	Sorteo=NombFch[n]

	# Separamos para cada linea palabra a palabra para su analisis individual.
	CntPalabrasPorLinea=split($0,PalabrasPorLinea," ")
	
	# Obtenemos la longitud de linea.
	LongitudLinea=length($0)
	
	# Guardamos en memoria el numero de linea y la cantidad de palabras que tiene cada linea.
	IdxCntPalabrasPorLinea[NR]=CntPalabrasPorLinea
	
	# En caso sea las ultimas lineas finalizamos procesamiento para evitar errores.	
	vFinal=index($0,"NOTA: LOS BILLETES TERMINADOS EN")
	if (vFinal==1){exit}
	
	# Leemos cada uno de las palabras de cada linea.
	for(i=1;i<=CntPalabrasPorLinea;i++){
		# Valores iniciales.
		vPosicionPalabra=0
		vTieneCordobas=0
		vLongitudPalabra2=0
		
		# Indice de palabra por linea.
		IdxPalabraLinea++
		
		# Variable con palabra de tratada para comparación.
		PalabraDeComparacion=PalabrasPorLinea[i]
		gsub(/^(c\$|C\$)/,"",PalabraDeComparacion) # Omitimos simbolo de cordoba si existe.
		gsub(/,/,"",PalabraDeComparacion) # Omitimos comas en caso sea un premio.
		gsub(/MILLONES/,"000000.00",PalabraDeComparacion) # Reemplazamos palabra de millones por la cantidad numerica.

		# Variable con 2da. palabra tratada de comparación.
		PalabraDeComparacion2=PalabrasPorLinea[i+1]
		gsub(/^(c\$|C\$)/,"",PalabraDeComparacion2) # Omitimos simbolo de cordoba si existe.
		gsub(/,/,"",PalabraDeComparacion2) # Omitimos comas en caso sea un premio.
		gsub(/MILLONES/,"000000.00",PalabraDeComparacion2) # Reemplazamos palabra de millones por la cantidad numerica.
		
		# Validamos que sea un numero.
		isnum=PalabraDeComparacion+0 > 0 ? 1 : 0

		# Verificamos si la palabra lleva un punto.
		existpunto=index(PalabraDeComparacion,".")

		# Obtenemos la cantidad de digitos de la palabra.
		cntdigit=length(PalabraDeComparacion)

		# Obtenemos la posicion de la palabra en la linea.
		vPosicionPalabra=index($0,PalabrasPorLinea[i])

		# Verificamos si la 2da. palabra lleva un punto.
		existpunto2=index(PalabrasPorLinea[i+1],".")
		
		# Obtenemos la longitud de la 2da. palabra.
		vLongitudPalabra2=length(PalabrasPorLinea[i+1])
		
		# Buscamos que si la 2da. palabra tiene un simbolo de cordoba.
		vTieneCordobas2=index(PalabrasPorLinea[i+1],"$")
		
		# Obtenemos un texto de reemplazo con la cantidad de digitos que tenga la palabra procesada.
		TxtReemplazo=RepiteTxt("?",cntdigit)

		# Verificamos si existe coincidencia de la palabra procesada con las buscadas para los premios.
		if (PalabrasPorLinea[i] in TipoPremios){						
			IdxGrandesPremios++
			# Registramos palabra del premio encontrada, Archivo|Numero de Linea|numero de palabra|posicion de la palabra.
			GrandesPremios[IdxPalabraLinea]=PalabrasPorLinea[i]
			GrandesPremiosPendienteID[IdxPalabraLinea]=vPosicionPalabra
			GrandesPremiosPendIdx[IdxGrandesPremios]=IdxPalabraLinea
			GrandesPremiosPendienteMonto[IdxPalabraLinea]=vPosicionPalabra
			GrandesPremiosPendMontoIdx[IdxGrandesPremios]=IdxPalabraLinea
		}

		
		#if (Sorteo==1767 && PalabrasPorLinea[i]~/11540/){print "Entra", cntdigit, isnum, existpunto }
		
		# Verificamos si es un numero valido.
		if(cntdigit==5 && isnum>0 && existpunto==0){
			#if (Sorteo==1767 && PalabrasPorLinea[i]~/11540/){print "Entra", PalabrasPorLinea[i], PalabrasPorLinea[i+1],vLongitudPalabra2, existpunto2 }
			if (vLongitudPalabra2>5 && existpunto2>0 && vTieneCordobas2==0){
				#if (Sorteo==1833 && PalabrasPorLinea[i]==01504){print "Entra Primera"}
				# Guardamos en memoria el numero ganador, Sorteo|Numero de Linea|Tipo de Premio|Numero del billete|monto del sorteo|numero de palabra|posicion de la palabra.
				ListaNumerosPremiados[IdxPalabraLinea]=Sorteo "|Ordinario|" PalabrasPorLinea[i] "|" PalabraDeComparacion2
			} else {
				#if (Sorteo==1833 && PalabrasPorLinea[i]==01504){print "Entra Segunda"}
				# Guardamos en memoria el numero ganador, Archivo|Numero de Linea|Tipo de Premio|Numero del billete|monto del sorteo|numero de palabra|posicion de la palabra.
				split(NumNoFound[Sorteo"|"PalabrasPorLinea[i]],PremioManual,"|")
				ListaNumerosPremiados[IdxPalabraLinea]=Sorteo "|" PremioManual[2] "|" PalabrasPorLinea[i] "|" PremioManual[1]
			}
			
			for (k=1;k<=20;k++){
				if (GrandesPremiosPendienteID[GrandesPremiosPendIdx[k]]==vPosicionPalabra){
					GrandesPremiosIdentificadosID[IdxPalabraLinea]=GrandesPremiosPendIdx[k]
					delete GrandesPremiosPendienteID[GrandesPremiosPendIdx[k]]
					delete GrandesPremiosPendIdx[k]
				}
			}
		}
		
		# Verificamos si la palabra tiene simbolo de cordobas.
		if (isnum>0 && existpunto>0){
			for (m=1;m<=20;m++){
				if (GrandesPremiosPendienteMonto[GrandesPremiosPendMontoIdx[m]]==vPosicionPalabra){
					gsub(/[C\$,]/,"",PalabrasPorLinea[i])
					gsub(/MILLONES/,"000000.00",PalabrasPorLinea[i])
					GrandesPremiosIdentificadosMonto[GrandesPremiosPendMontoIdx[m]]=PalabrasPorLinea[i]
					delete GrandesPremiosPendienteMonto[GrandesPremiosPendMontoIdx[m]]
					delete GrandesPremiosPendMontoIdx[m]
				}
			}			
		}
		
		# Sustituimos la ocurrencia encontrada mas a la izquierda con palabra de reemplazo.
		vTxtPart1=substr($0,1,vPosicionPalabra-1)
		vTxtPart2=substr($0,vPosicionPalabra+cntdigit,LongitudLinea-vPosicionPalabra-cntdigit+1)
		
		# Reemplazamos la linea 
		$0=vTxtPart1""TxtReemplazo""vTxtPart2
	}
}
END{
	for(Premio in ListaNumerosPremiados){
		if (Premio in GrandesPremiosIdentificadosID){
			split(ListaNumerosPremiados[Premio],ArrPremMay,"|")
			if (ArrPremMay[4]>0){
				print ListaNumerosPremiados[Premio]
			} else {
				print ArrPremMay[1],GrandesPremios[GrandesPremiosIdentificadosID[Premio]],ArrPremMay[3],GrandesPremiosIdentificadosMonto[GrandesPremiosIdentificadosID[Premio]]
			}
		} else {
			print ListaNumerosPremiados[Premio]
		}
	}
}
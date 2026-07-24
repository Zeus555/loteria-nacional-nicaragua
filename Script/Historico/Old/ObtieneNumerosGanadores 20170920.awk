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

	# Indicadore de tipo depuración.
	TipoDepuracion=0
	# ==0 --> Por defecto, ningún tipo depuración.
	# ==1 --> Depuración a detalle.
	# ==2 --> Imprime solo las primeras 40 filas.
	
	# Fichero donde se encuentran listado de numeros que no son encontrados.
	FicheroNumNoFound="C:\\Users\\Ariel Mairena\\Google Drive\\Casa\\Loteria Nacional\\Datos\\Listado No Encontrados.txt"
	
	# Subimos a memoria listado de numeros que no son encontrados automaticamente y son subidos manualmente.
	while (getline < FicheroNumNoFound){
		# Solo cargamos datos del sorteo evaluado.
		if (Sorteo==$1){
			# Guardamos en memoria lista con numeros de loteria no encontrados automaticamente.
			NumNoFound[$2""]=$3"|"$4
		}
	}
}
{
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
		
		# En caso que el numero premiado venga concatenado con la palabra PREMIO, eliminamos esta palabra y procesamos normal.
		if (PalabraDeComparacion~/([0-9]{5}(PREMIO))/){
			# Reemplazamos la palabra por vacio.
			gsub(/PREMIO/,"",PalabraDeComparacion)
		}

		# Variable con 2da. palabra tratada de comparación.
		PalabraDeComparacion2=PalabrasPorLinea[i+1]
		gsub(/^(c\$|C\$)/,"",PalabraDeComparacion2) # Omitimos simbolo de cordoba si existe.
		gsub(/,/,"",PalabraDeComparacion2) # Omitimos comas en caso sea un premio.
		gsub(/MILLONES/,"000000.00",PalabraDeComparacion2) # Reemplazamos palabra de millones por la cantidad numerica.
		
		# Equivalencias entre mala extracción del texto por metodo TABLE.
		gsub(/M80IL0.00/,"800.00",PalabraDeComparacion2)
		gsub(/M90IL0.00/,"900.00",PalabraDeComparacion2)
		gsub(/9M0I0L.00/,"900.00",PalabraDeComparacion2)
		gsub(/1M00IL0.00/,"1000.00",PalabraDeComparacion2)
		gsub(/1M20IL0.00/,"1200.00",PalabraDeComparacion2)
		gsub(/1M50IL0.00/,"1500.00",PalabraDeComparacion2)
		gsub(/2M00IL0.00/,"2000.00",PalabraDeComparacion2)
		gsub(/10M00IL0.00/,"10000.00",PalabraDeComparacion2)
		gsub(/15M00IL0.00/,"15000.00",PalabraDeComparacion2)
		gsub(/3M00IL0.00/,"3000.00",PalabraDeComparacion2)
		gsub(/1L0E0O0N00.00/,"100000.00",PalabraDeComparacion2)
		
		# Validamos que sea un numero.
		isnum=PalabraDeComparacion+0 > 0 ? 1 : 0

		# Verificamos si la palabra lleva un punto.
		existpunto=index(PalabraDeComparacion,".")

		# Obtenemos la cantidad de digitos de la palabra.
		cntdigit=length(PalabraDeComparacion)
		cntdigitReal=length(PalabrasPorLinea[i])

		# Obtenemos la posicion de la palabra en la linea.
		vPosicionPalabra=index($0,PalabrasPorLinea[i])

		#if (PalabrasPorLinea[i]=="C$125,000.00"){print vPosicionPalabra;print PalabraDeComparacion}
		
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

		# Verificamos si existe coincidencia de la palabra procesada con las buscadas para los premios.
		if (PalabrasPorLinea[i]~/([0-9]{5}( )?(MAYOR|SEGUNDO|TERCER|CUARTO|QUINTO|SEXTO)( )?(PREMIO)?)/){						
			IdxGrandesPremios++
			
			vRestoLinea=PalabrasPorLinea[i]
			
			#print vRestoLinea
			
			# Reemplamos la palabra PREMIO si existe.
			gsub(/PREMIO/,"",vRestoLinea)
			
			#print "... " vRestoLinea
			
			# Obtenemos el numero ganador.
			vNumConcat=substr(vRestoLinea,0,5) ""
			
			#print "... " vNumConcat
			
			# Creamos una linea nueva omitiendo los primeros 5 caracteres.
			vRestoLinea=substr(vRestoLinea,6,length(vRestoLinea)-5)
			
			# El resto de la linea unicamente debe ser el nombre del premio.
			vTipoConcat=vRestoLinea
			
			#print "... " vTipoConcat
			
			#print "... " IdxPalabraLinea, vPosicionPalabra
			
			# Registramos el numero en listado vigente.
			ListaNumerosPremiados[IdxPalabraLinea]=Sorteo "|"vTipoConcat"|" vNumConcat "|0|Normal"
			
			# Agregamos a listado de premios el tipo de premio identificado.
			GrandesPremios[IdxPalabraLinea]=vTipoConcat
			# Identificamos el premio obtenido en la misma palabra.
			GrandesPremiosIdentificadosID[IdxPalabraLinea]=IdxPalabraLinea
			# Agregamos posicion de la palabra encontrada para que se le busque el monto.
			GrandesPremiosPendienteMonto[IdxPalabraLinea]=vPosicionPalabra
			# Agregamos al indice de busqueda el indice de la palabra buscada.
			GrandesPremiosPendMontoIdx[IdxGrandesPremios]=IdxPalabraLinea
		}		
		
		#if (Sorteo==1767 && PalabrasPorLinea[i]~/11540/){print "Entra", cntdigit, isnum, existpunto }
		
		if(cntdigit==7 && isnum>0 && existpunto==0){
			# Reemplazamos los caracteres invalidos.
			PalabrasPorLinea[i]=substr(PalabrasPorLinea[i],0,3) substr(PalabrasPorLinea[i],5,1) substr(PalabrasPorLinea[i],7,1)
			# Seteamos longitud en 5 digitos a como debio quedar el numero premiado.
			cntdigit=5		
		}
		
		# Verificamos si es un numero valido.
		if(cntdigit==5 && isnum>0 && existpunto==0){
			# Llevamos un conteo de la cantidad de apariciones por premio y el ID de su ultima aparicion.
			ArrConteoNumPremiado[PalabrasPorLinea[i]""]++
			ArrUltimaAparicionNumPremiado[PalabrasPorLinea[i]""]=IdxPalabraLinea
			
			#if (Sorteo==1767 && PalabrasPorLinea[i]~/11540/){print "Entra", PalabrasPorLinea[i], PalabrasPorLinea[i+1],vLongitudPalabra2, existpunto2 }
			if (vLongitudPalabra2>5 && existpunto2>0 && vTieneCordobas2==0){
				#if (Sorteo==1833 && PalabrasPorLinea[i]==01504){print "Entra Primera"}
				# Guardamos en memoria el numero ganador, Sorteo|Numero de Linea|Tipo de Premio|Numero del billete|monto del sorteo|numero de palabra|posicion de la palabra.
				ListaNumerosPremiados[IdxPalabraLinea]=Sorteo "|Ordinario|" PalabrasPorLinea[i] "|" PalabraDeComparacion2"|Normal"
			} else {
				ListaNumerosPremiados[IdxPalabraLinea]=Sorteo "|NI|" PalabrasPorLinea[i] "|0|Normal"
			}
			# Buscamos los en los grandes premios.
			for (k=1;k<=20;k++){
				if (GrandesPremiosPendienteID[GrandesPremiosPendIdx[k]]==vPosicionPalabra){
					GrandesPremiosIdentificadosID[IdxPalabraLinea]=GrandesPremiosPendIdx[k]
					delete GrandesPremiosPendienteID[GrandesPremiosPendIdx[k]]
					delete GrandesPremiosPendIdx[k]
				}
			}
		}
		#if (PalabrasPorLinea[i]=="C$125,000.00"){print "... Buscamos monto de grandes premios.";print "... " PalabrasPorLinea[i],IdxPalabraLinea,vPosicionPalabra,isnum,existpunto}
		# Verificamos si la palabra tiene simbolo de cordobas.
		if (isnum>0 && existpunto>0){			
			#if (PalabrasPorLinea[i]=="C$125,000.00"){print "... Entra en busqueda de monto."}
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
		vTxtPart2=substr($0,vPosicionPalabra+cntdigitReal,LongitudLinea-vPosicionPalabra-cntdigitReal+1)
		
		# Reemplazamos la linea 
		$0=vTxtPart1""TxtReemplazo""vTxtPart2
	}
}
END{
	# Recorremos todos los numeros encontrados.
	for(Premio in ListaNumerosPremiados){
		# Obtenemos el detalle de cada combinacion de palabras encontrada.
		split(ListaNumerosPremiados[Premio],ArrPremMay,"|")

		# En caso que se encuentre el ID de la palabra procesada en dentro de listado de grandes premios.
		if (Premio in GrandesPremiosIdentificadosID){		
			ListaNumerosPremiados[Premio]=ArrPremMay[1]"|"GrandesPremios[GrandesPremiosIdentificadosID[Premio]]"|"ArrPremMay[3]"|"GrandesPremiosIdentificadosMonto[GrandesPremiosIdentificadosID[Premio]]"|Normal"
		}
	}
	
	# Actualizamos o Agregamos todos los numeros que aparecen en listado de No Encontrados.
	for (a in NumNoFound){
		# Obtenemos el detalle del numero premiado de NoFound.
		split(NumNoFound[a],arrDet,"|")

		# Buscamos si el numero premiado de listado NoFound NO se encuentra en listado de numeros premiados.
		if (ArrConteoNumPremiado[a]==1){
			# Actualizamos listado de numeros del sorteo.
			ListaNumerosPremiados[ArrUltimaAparicionNumPremiado[a]]=Sorteo "|" arrDet[2] "|" a "|" arrDet[1]"|Actualizado"
		}else if (ArrConteoNumPremiado[a]>1){
			# Actualizamos listado de numeros del sorteo.
			# ListaNumerosPremiados[ArrUltimaAparicionNumPremiado[a]]=Sorteo "|" arrDet[2] "|" a "|" arrDet[1]"|Actualizado"
		} else {
			# Indice de palabra por linea.
			IdxPalabraLinea++
		
			# Agregamos a listado de numeros del sorteo.
			ListaNumerosPremiados[IdxPalabraLinea]=Sorteo "|" arrDet[2] "|" a "|" arrDet[1]"|Agregado"
		}
	}
	
	# Creamos Indice para Ordenar Ascendentemente el listado por numero de premio.
	for (b in ListaNumerosPremiados){
		split(ListaNumerosPremiados[b],ArrOrden,"|")
		IdxArrFull[b]=ArrOrden[3]+0
	}

	# Establecemos orden segun indice por numero de premio, de forma numerica ascendente.
	PROCINFO["sorted_in"] = "@val_num_asc"
	
	# Imprimimos a
	for (c in IdxArrFull){
		if (TipoDepuracion==0){
			print ListaNumerosPremiados[c] >> FchEstadisticas
		} else {
			#print ListaNumerosPremiados[c]
		}
	}
	
}
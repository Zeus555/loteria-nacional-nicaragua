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
	
	# En caso sea las ultimas lineas finalizamos procesamiento para evitar errores.	
	vFinal=index($0,"NOTA: LOS BILLETES TERMINADOS EN")
	if (vFinal==1){exit}
	
	# Leemos cada uno de las palabras de cada linea.
	for(i=1;i<=CntPalabrasPorLinea;i++){
		# Indice de palabra por linea.
		IdxPalabraLinea++
		
		# Obtenemos la cantidad de digitos de la palabra.
		cntdigitReal=length(PalabrasPorLinea[i])

		# Obtenemos la posicion de la palabra en la linea.
		vPosicionPalabra=index($0,PalabrasPorLinea[i])

		# Obtenemos un texto de reemplazo con la cantidad de digitos que tenga la palabra procesada.
		TxtReemplazo=RepiteTxt("?",cntdigitReal)
		
		# Identifica si es un numero de cinco y siete digitos.
		EsNumero5Digitos=PalabrasPorLinea[i]~/^([0-9]{5})$/ ? 1 : 0
		EsNumero7Digitos=PalabrasPorLinea[i]~/^([0-9]{7})$/ ? 1 : 0

		# Identifica si es un numero de cinco y siete digitos.
		EsNumero5Digitos2=PalabrasPorLinea[i+1]~/^([0-9]{5})$/ ? 1 : 0
		EsNumero7Digitos2=PalabrasPorLinea[i+1]~/^([0-9]{7})$/ ? 1 : 0
		
		# Seteamos la palabra procesada a variable.
		PalabraDeComparacion=PalabrasPorLinea[i]

		# En caso que el numero este mal traducido y aparezca con siete digitos, se omiten los digitos cuarto y el sexto digito, de esta manera queda con cinco digitos.
		if(EsNumero7Digitos==1){
			# Reemplazamos los caracteres invalidos.
			PalabraDeComparacion=substr(PalabraDeComparacion,0,3) substr(PalabraDeComparacion,5,1) substr(PalabraDeComparacion,7,1)
			
			# Seteamos valor que indica es un numero de cinco digitos.
			EsNumero5Digitos=1
		}
		
		# Palabras concatenadas.
		EsConcNum1=PalabraDeComparacion~/([0-9]{5}(PREMIO))/ ? 1 : 0
		EsConcNum2=PalabraDeComparacion~/([0-9]{5}( )?(MAYOR|SEGUNDO|TERCER|CUARTO|QUINTO|SEXTO)( )?(PREMIO)?)/ ? 1 : 0
	
		# Variable con 2da. palabra tratada de comparación,
		# y equivalencias entre mala extracción del texto por metodo TABLE.
		PalabraDeComparacion2=PalabrasPorLinea[i+1]
		gsub(/,/,"",PalabraDeComparacion2)
		gsub(/MILLONES/,"000000.00",PalabraDeComparacion2) # Reemplazamos palabra de millones por la cantidad numerica.
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
		
		# En caso que el numero este mal traducido y aparezca con siete digitos, se omiten los digitos cuarto y el sexto digito, de esta manera queda con cinco digitos.
		if(EsNumero7Digitos2==1){
			# Reemplazamos los caracteres invalidos.
			PalabraDeComparacion2=substr(PalabraDeComparacion2,0,3) substr(PalabraDeComparacion2,5,1) substr(PalabraDeComparacion2,7,1)
			
			# Seteamos valor que indica es un numero de cinco digitos.
			EsNumero5Digitos2=1
		}
		
		# Verificamos si la palabra procesada y la siguiente corresponde a un monto ordinario o de premios mayores.
		EsMontoMayor=PalabraDeComparacion~/^(c\$|C\$)+([0-9])+(,[0-9]{3})?+\.([0-9]{2})$/ ? 1 : 0
		
		# Verificamos si la siguiente palabra corresponde a un monto ordinario.
		ValorEnNumero2= PalabraDeComparacion2+0
		EsMontoRegular2=(PalabraDeComparacion2~/^([0-9])+(,[0-9]{3})?+\.([0-9]{2})$/) && ValorEnNumero2>100 ? 1 : 0
		
		# Verificamos si la palabra actual y siguiente son numero de 5 digitos consecutivos.
		EsNum5DigConsec=(EsNumero5Digitos==1 && PalabrasPorLinea[i+1]=="") ? 2 : (EsNumero5Digitos==1 && EsNumero5Digitos2==1) ? 1 : (EsNumero5Digitos==1 && EsMontoRegular2==0) ? 1 : 0
		
		# En caso que encontremos la palabra procesada y la siguiente sean numeros premiados.
		if (EsNum5DigConsec>=1){
			# Conteo de grandes premios por numero cuando este no puede ser identificado.
			IdxGPPNumero++
						
			# Agregamos el numero 
			GPPNumero[IdxGPPNumero]=IdxPalabraLinea "|" PalabraDeComparacion "|" vPosicionPalabra
		}
		
		# En caso que sea un monto de un premio mayor, osea que contenga el simbolo de cordoba.
		if (EsMontoMayor==1){
			# Reemplazamos simbolo de cordobas.
			gsub(/[(C$|c$),]/,"",PalabraDeComparacion)
			
			# Unicamente premios mayores y no de montos bajos.
			if (PalabraDeComparacion+0>5000){
				# Conteo de grandes premios por Monto.
				IdxGPPMonto++
				
				# Agregamos el monto a grandes premios.
				GPPMonto[IdxGPPMonto]=IdxPalabraLinea "|" PalabraDeComparacion "|" vPosicionPalabra
				
				#print "Monto", IdxGPPMonto, IdxPalabraLinea, PalabraDeComparacion, vPosicionPalabra
			}
		}
		
		# En caso que el numero premiado venga concatenado con la palabra PREMIO, eliminamos esta palabra y procesamos normal.
		if (EsConcNum1==1){
			# Reemplazamos la palabra por vacio.
			gsub(/PREMIO/,"",PalabraDeComparacion)
			
			# Conteo de grandes premios por Numero.
			IdxGPPNumero++
			
			# Agregamos el numero a grandes premios.
			GPPNumero[IdxGPPNumero]=IdxPalabraLinea "|" PalabraDeComparacion "|" vPosicionPalabra
			
			# Seteamos valor que indica es un numero de cinco digitos.
			EsNumero5Digitos=1
		}

		# Verificamos si existe coincidencia de la palabra procesada con las buscadas para los premios.
		if (EsConcNum2==1){						
			# Conteo de grandes premios por palabra y numero.
			IdxGPPalabra++
			IdxGPPNumero++
			
			# Establecemos valor de palabra original a variable temporal.
			vRestoLinea=PalabrasPorLinea[i]
			
			# Reemplamos la palabra PREMIO si existe.
			gsub(/PREMIO/,"",vRestoLinea)
			
			# Obtenemos el numero ganador.
			vNumConcat=substr(vRestoLinea,0,5) ""
			
			# Creamos una linea nueva omitiendo los primeros 5 caracteres.
			vRestoLinea=substr(vRestoLinea,6,length(vRestoLinea)-5)
			
			# El resto de la linea unicamente debe ser el nombre del premio.
			vTipoConcat=vRestoLinea
			
			# Registramos el numero en listado vigente.
			ListaNumerosPremiados[IdxPalabraLinea]=Sorteo "|"vTipoConcat"|" vNumConcat "|0|Normal"
			
			# Agregamos a listado de premios el tipo de premio identificado.
			GPPPalabra[IdxGPPalabra]=IdxPalabraLinea "|" vTipoConcat "|" vPosicionPalabra
			
			# Agregamos el numero 
			GPPNumero[IdxGPPNumero]=IdxPalabraLinea "|" vNumConcat "|" vPosicionPalabra
			
			# Llevamos un conteo de la cantidad de apariciones por premio y el ID de su ultima aparicion.
			ArrConteoNumPremiado[vNumConcat""]++
			ArrUltimaAparicionNumPremiado[vNumConcat""]=IdxPalabraLinea
		}	
		
		# Verificamos si existe coincidencia de la palabra procesada con las buscadas para los premios.
		if (PalabrasPorLinea[i] in TipoPremios){						
			# Conteo de grandes premios por palabra.
			IdxGPPalabra++
			
			# Registramos palabra del premio encontrada, Archivo|Numero de Linea|numero de palabra|posicion de la palabra.
			GPPPalabra[IdxGPPalabra]=IdxPalabraLinea "|" PalabraDeComparacion "|" vPosicionPalabra
			
			#print "TipoPremio", IdxGPPalabra, IdxPalabraLinea, PalabraDeComparacion, vPosicionPalabra
		}
		
		# En caso que la palabra sea un numero de cinco digitos.
		if (EsNumero5Digitos==1){
			# En caso que la segunda palabra corresponda a un monto regular en formato ###.## pero sin simbolo de cordoba.
			if (EsMontoRegular2==1){
				# Guardamos en memoria el numero ganador, Sorteo|Numero de Linea|Tipo de Premio|Numero del billete|monto del sorteo|numero de palabra|posicion de la palabra.
				ListaNumerosPremiados[IdxPalabraLinea]=Sorteo "|Ordinario|" PalabraDeComparacion "|" PalabraDeComparacion2"|Normal"
			} else {
				# Registramos el numero premiado pero sin identificar 
				ListaNumerosPremiados[IdxPalabraLinea]=Sorteo "|NI|" PalabraDeComparacion "|0|Normal"
			}
			
			# Llevamos un conteo de la cantidad de apariciones por premio y el ID de su ultima aparicion.
			ArrConteoNumPremiado[PalabraDeComparacion""]++
			ArrUltimaAparicionNumPremiado[PalabraDeComparacion""]=IdxPalabraLinea
		}
		
		# Sustituimos la ocurrencia encontrada mas a la izquierda con palabra de reemplazo.
		vTxtPart1=substr($0,1,vPosicionPalabra-1)
		vTxtPart2=substr($0,vPosicionPalabra+cntdigitReal,LongitudLinea-vPosicionPalabra-cntdigitReal+1)
		
		# Reemplazamos la linea 
		$0=vTxtPart1""TxtReemplazo""vTxtPart2
	}
}
END{
	# Relacionamos los grandes premios en Numero, TipoPremio y Monto,
	# recorremos las palabras encontradas de los tipos de premios.
	for (aa=1;aa<=IdxGPPalabra;aa++){
		# Obtenemos el detalle de cada uno de las 
		split(GPPPalabra[aa],arrPalabra,"|")
		#print IdxGPPalabra,arrPalabra[1], arrPalabra[2], arrPalabra[3]
		
		# Seteamos valores por defecto.
		keyNumero=0
		keyMonto=0

		# Buscamos en lista de montos mayores.
		for (cc=1;cc<=IdxGPPMonto;cc++){
			# Obtenemos detalle de montos y posiciones de linea.
			split(GPPMonto[cc],arrMonto,"|")
			
			# Para los casos que vienen concatenados y tienen un mismo IdxPalabraLinea.
			if (arrPalabra[1]==arrMonto[1]){
				keyMonto=arrMonto[2]
				#print keyMonto
				delete GPPMonto[cc]
				break
			} else {
				# Para los que ubicamos por posicion de la palabra.
				if (arrPalabra[3]==arrMonto[3]){
					keyMonto=arrMonto[2]
					#print keyMonto
					delete GPPNumero[bb]
					delete GPPMonto[cc]
					break
				}
			}
		}
		
		#print arrMonto[1]
		
		# Buscamos en lista de numeros de premios identificados como posibles grandes premios.
		for (bb=1;bb<=IdxGPPNumero;bb++){
			# Obtenemos el detalle de los numeros premiados y su posición.
			split(GPPNumero[bb],arrNumero,"|")
			
			#print bb, arrNumero[1]
			
			# Para los casos que vienen concatenados y tienen un mismo IdxPalabraLinea.
			if (arrPalabra[1]==arrNumero[1]){
					keyNumero=arrNumero[2]
					#print "... ", arrPalabra[1],arrNumero[1],keyNumero
					delete GPPPalabra[aa]
					delete GPPNumero[bb]
					break
			} else {
				# Para los que ubicamos por posicion de la palabra.
				if (arrPalabra[3]==arrNumero[3] && arrNumero[1] <= arrMonto[1]){
					#print "... ",arrNumero[1],arrNumero[2], arrNumero[3]
					keyNumero=arrNumero[2]
					delete GPPPalabra[aa]
					delete GPPNumero[bb]
					break
				}
			}
		}
		
		# Registramos como grandes premios aquellos que unicamente se encontraron numero de premio aunque NO precisamente el monto.
		if (keyNumero>0){
			#print "... ",arrNumero[1], arrPalabra[2], keyNumero, keyMonto
			# Guardamos los resultados de las busquedas.
			GPP[arrNumero[1]]=arrPalabra[2]"|"keyNumero"|"keyMonto			
		}
	}
	
	# Recorremos todos los numeros encontrados.
	for(Premio in ListaNumerosPremiados){
		# Obtenemos el detalle de cada combinacion de palabras encontrada.
		split(ListaNumerosPremiados[Premio],ArrPremMay,"|")
		
		# En caso que se encuentre el ID de la palabra procesada en dentro de listado de grandes premios.
		if (Premio in GPP){	
			# Obtenemos el detalle de los grandes premios encontrados y por actualizar.
			split(GPP[Premio],arrGPP,"|")

			# Actualizamos lista de todos los premios.
			ListaNumerosPremiados[Premio]=ArrPremMay[1]"|"arrGPP[1]"|"arrGPP[2]"|"arrGPP[3]"|Normal"
		}
	}
	
	# Actualizamos o Agregamos todos los numeros que aparecen en listado de No Encontrados.
	for (a in NumNoFound){
		# Obtenemos el detalle del numero premiado de NoFound.
		split(NumNoFound[a],arrDet,"|")

		#if (Sorteo=1511  && a~/50880/) {print NR, a, arrDet[1], arrDet[2], ArrConteoNumPremiado[a], ArrUltimaAparicionNumPremiado[a]}
		
		# Buscamos si el numero premiado de listado NoFound NO se encuentra en listado de numeros premiados.
		if (ArrConteoNumPremiado[a]==1){
			# Actualizamos listado de numeros del sorteo.
			ListaNumerosPremiados[ArrUltimaAparicionNumPremiado[a]]=Sorteo"|" arrDet[2] "|" a "|" arrDet[1] "|Actualizado"
			#if (Sorteo=1511  && a~/50880/) {print ListaNumerosPremiados[618]}
		}else if (ArrConteoNumPremiado[a]>1){
			# Actualizamos listado de numeros del sorteo.
			#ListaNumerosPremiados[ArrUltimaAparicionNumPremiado[a]]=Sorteo "|" arrDet[2] "|" a "|" arrDet[1]"|Actualizado"
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
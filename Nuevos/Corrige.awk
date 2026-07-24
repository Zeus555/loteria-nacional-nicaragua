BEGIN{
	FS=" "
	RS="\n"
	OFS="|"

	# Palabras distintivas de un premio a buscar.
	TipoPremios["MAYOR"]=1
	TipoPremios["SEGUNDO"]=2
	TipoPremios["TERCER"]=3
	TipoPremios["CUARTO"]=4
	TipoPremios["QUINTO"]=5
	TipoPremios["SEXTO"]=6
	
	# Fichero donde se encuentran listado de numeros que no son encontrados.
	FicheroNumNoFound="C:\\Users\\Ariel Mairena\\Google Drive\\Casa\\Loteria Nacional\\Datos\\Listado No Encontrados.dat"
	
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

	# print $0
	
	# Validamos que sea un numero.
	IsNum=$0+0 > 0 ? 1 : 0
	
	# Longitud del registro actual.
	EsNumero=$1~/^([0-9]{5})$/ ? 1 : 0
	
	# Verificamos si la palabra corresponde a un monto ordinario o de premios mayores.
	EsMontoRegular=$1~/^([0-9])+(,[0-9]{3})?+\.([0-9]{2})$/ ? 1 : 0
	EsMontoMayores=$1~/^(c\$|C\$)+([0-9])+(,[0-9]{3})?+\.([0-9]{2})$/ ? 1 : 0
	
	# print "... ", BanInicioNumeracion, EsNumero, EsMonto, LineaAnterior
	
	# En caso sea el inicio del listado de numeración.
	if (LineaAnterior=="01" && EsNumero==1){
		# Inidicamos es el inicio de listado de numeracion.
		BanInicioNumeracion=1
	}
	
	# Registramos todos los numeros ganadores.
	if (BanInicioNumeracion==1 && EsNumero==1 && EsMontoRegular==0){
		ContadorNumero++
		# print "... #:",$1
		NumerosGanadores[Sorteo"|"ContadorNumero]=$1
	}

	# Registramos todos los numeros ganadores.
	if (BanInicioNumeracion==1 && EsMontoRegular==1){
		ContadorMonto++
		# print "... $:",$1
		MontoGanadores[Sorteo"|"ContadorMonto]=$1"|Ordinarios|Ordinario"
	}
	
	# Registramos todos los numeros ganadores.
	if (BanInicioNumeracion==1 && EsMontoMayores==1){
		ContadorMonto++
		ContadorMontoMayores++
		# print "... $:",$1,"Mayores"
		MontoGanadores[Sorteo"|"ContadorMonto]=$1"|Mayores|"
		MontoGanadoresMayores[ContadorMontoMayores]=Sorteo"|"ContadorMonto
	}	
	
	# Verificamos si existe coincidencia de la palabra procesada con las buscadas para los premios.
	if (BanInicioNumeracion==1){
		# Recorremos cada una de las palabras de la linea.
		for (a=1;a<=NF;a++){
			# Validamos si palabra corresponde a listas de palabras claves de premios mayores.
			if ($a in TipoPremios){
				ContadorTipoMayores++
				TipoGanadoresMayores[ContadorTipoMayores]=$a
			}
		}
	}
	
	# Registramos la linea anterior en caso exista.
	LineaAnterior=$1	
}
END {
	# Actualizamos para los montos mayores el tipo de premio recibido.
	for (b=1;b<=ContadorMontoMayores;b++){
		MontoGanadores[MontoGanadoresMayores[b]]=MontoGanadores[MontoGanadoresMayores[b]] "" TipoGanadoresMayores[b]
	}
	
	# En caso que contador sean distintos reportamos errores.
	if (ContadorNumero!=ContadorMonto){
		print "Contadores de Numero y Monto Distintos ... ", ContadorNumero, ContadorMonto
		for (i=1;i<=ContadorNumero;i++){
			# En caso que no exista el monto del numero ganador.
			if (NumerosGanadores[Sorteo"|"i] && MontoGanadores[Sorteo"|"i]==""){
				print Sorteo, NumerosGanadores[Sorteo"|"i], MontoGanadores[Sorteo"|"i]
			}
			
			# En caso que no exista el numero ganador.
			if (NumerosGanadores[Sorteo"|"i]=="" && MontoGanadores[Sorteo"|"i]){
				print Sorteo, NumerosGanadores[Sorteo"|"i], MontoGanadores[Sorteo"|"i]
			}
		}
		exit 1
	}
	
	# Imprimimos listado de numeros ganadores.
	for (i=1;i<=ContadorNumero;i++){
		split(MontoGanadores[Sorteo"|"i],arrMontoGanador,"|")
	
		# print Sorteo, NumerosGanadores[Sorteo"|"i], MontoGanadores[Sorteo"|"i]
		print Sorteo, arrMontoGanador[3], NumerosGanadores[Sorteo"|"i], arrMontoGanador[1]
	}
}
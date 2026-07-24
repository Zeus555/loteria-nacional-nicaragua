function Mediana(Cnttot,Posicion,ArrValor) { 
   asort(Posicion,ArrValor); 
   if (Cnttot % 2) {
	return ArrValor[(Cnttot+1)/2]
	} else {
		return (ArrValor[Cnttot/2+1]+ArrValor[Cnttot/2])/2.0
	}
} 
BEGIN{
	FS="|"
	RS="\n"
	OFS="|"

	# Fichero donde se encuentran listado de numeros que no son encontrados.
	FchEstat="C:\\Users\\Ariel Mairena\\Google Drive\\Casa\\Loteria Nacional\\Resultados\\EstadisticasLoteria.txt"

	# Valores iniciales.
	MinMay=1000000000
	MinSeg=1000000000
	MinTer=1000000000
	MinCua=1000000000
	MinQui=1000000000
	MinSex=1000000000
	
	# Seteamos el fichero a procesar.
	ARGV[1] = FchEstat
	ARGC = 2
}
{
	# Saltamos los encabezados.
	if (NR==1){next}
	
	# Obtenemos los distintos prefijos de los sorteos, uno cada cien sorteos.
	PrefijoSorteo=substr($1,0,2)

	# Filtramos unicamente los montos grandes con valor.
	if (!($4~/Ordinario/) && ($3>0)){
		
		if ($4~/MAYOR/)  { TendMayor[arrPfjSorteoTipoPremio[PrefijoSorteo,"May"]++]=$3;   SumaTotMay+=$3; SumaCuadradaMay+= $3*$3; if (MaxMay<$3){MaxMay=$3}; if (MinMay>$3){MinMay=$3}} else
		if ($4~/MAYOR/)  { TendMayor[TMay++]=$3;   SumaTotMay+=$3; SumaCuadradaMay+= $3*$3; if (MaxMay<$3){MaxMay=$3}; if (MinMay>$3){MinMay=$3}} else		
		if ($4~/SEGUNDO/){ TendSegundo[TSeg++]=$3; SumaTotSeg+=$3; SumaCuadradaSeg+= $3*$3; if (MaxSeg<$3){MaxSeg=$3}; if (MinSeg>$3){MinSeg=$3}} else
		if ($4~/TERCER/) { TendTercer[TTer++]=$3;  SumaTotTer+=$3; SumaCuadradaTer+= $3*$3; if (MaxTer<$3){MaxTer=$3}; if (MinTer>$3){MinTer=$3}} else
		if ($4~/CUARTO/) { TendCuarto[TCua++]=$3;  SumaTotCua+=$3; SumaCuadradaCua+= $3*$3; if (MaxCua<$3){MaxCua=$3}; if (MinCua>$3){MinCua=$3}} else
		if ($4~/QUINTO/) { TendQuinto[TQui++]=$3;  SumaTotQui+=$3; SumaCuadradaQui+= $3*$3; if (MaxQui<$3){MaxQui=$3}; if (MinQui>$3){MinQui=$3}} else
		if ($4~/SEXTO/)  { TendSexto[TSex++]=$3;   SumaTotSex+=$3; SumaCuadradaSex+= $3*$3; if (MaxSex<$3){MaxSex=$3}; if (MinSex>$3){MinSex=$3}} else
		{ print $0}
	}
}
END{
	for (m in arrPfjSorteoTipoPremio){
		print m, arrPfjSorteoTipoPremio[m]
	}
	exit 0

	# Calculamos la mediana segun el tipo de premio.
	#MedianaMay= Mediana(TMay,TendMayor)
	asort(TendMayor,TendMayOrd);
	MedianaMay= TMay % 2 ? TendMayOrd[(TMay+1)/2] : (TendMayOrd[TMay/2+1]+TendMayOrd[TMay/2])/2.0
	MedianaSeg= Mediana(TSeg,TendSegundo)
	MedianaTer= Mediana(TTer,TendTercer)
	MedianaCua= Mediana(TCua,TendCuarto)
	MedianaQui= Mediana(TQui,TendQuinto)
	MedianaSex= Mediana(TSex,TendSexto)
	
	# Promedio por premio.
	PromedioMay=SumaTotMay/TMay
	PromedioSeg=SumaTotSeg/TSeg
	PromedioTer=SumaTotTer/TTer
	PromedioCua=SumaTotCua/TCua
	PromedioQui=SumaTotQui/TQui
	PromedioSex=SumaTotSex/TSex
	
	# Desviacion Estandar por premio.
	DesvEstandarMay=sqrt(SumaCuadradaMay/TMay - (SumaTotMay/TMay)**2)
	DesvEstandarSeg=sqrt(SumaCuadradaSeg/TSeg - (SumaTotSeg/TSeg)**2)
	DesvEstandarTer=sqrt(SumaCuadradaTer/TTer - (SumaTotTer/TTer)**2)
	DesvEstandarCua=sqrt(SumaCuadradaCua/TCua - (SumaTotCua/TCua)**2)
	DesvEstandarQui=sqrt(SumaCuadradaQui/TQui - (SumaTotQui/TQui)**2)
	DesvEstandarSex=sqrt(SumaCuadradaSex/TSex - (SumaTotSex/TSex)**2)
	
	#numMay = asorti(TendMayor, indices)
    #for (i=1; i<=numMay; i++) {
	#	if (i>(numMay*0.1) && i < (numMay*0.9)){
	#		cntTotMay++
	#		sumTotMay+=TendMayor[indices[i]]
	#		sumCuadMay+=TendMayor[indices[i]]*TendMayor[indices[i]]
	#	}
	#}

	#print cntTotMay, sumTotMay, sumCuadMay
	
	#DsvStdAvgMay=sqrt(sumCuadMay/cntTotMay - (sumTotMay/cntTotMay)**2)
	#DsvStdMedianaMay=sqrt(sumCuadMay/cntTotMay - MedianaMay**2)
	
	#printf "%3.2f %3.2f\n", DsvStdAvgMay, DsvStdMedianaMay
	
	printf "%s %3.2f %3.2f %3.2f %3.2f %3.2f\n", "Mayor:",   MinMay, PromedioMay, MedianaMay, DesvEstandarMay, MaxMay
	printf "%s %3.2f %3.2f %3.2f %3.2f %3.2f\n", "Segundo:", MinSeg, PromedioSeg, MedianaSeg, DesvEstandarSeg, MaxSeg
	printf "%s %3.2f %3.2f %3.2f %3.2f %3.2f\n", "Tercer:",  MinTer, PromedioTer, MedianaTer, DesvEstandarTer, MaxTer
	printf "%s %3.2f %3.2f %3.2f %3.2f %3.2f\n", "Cuarto:",  MinCua, PromedioCua, MedianaCua, DesvEstandarCua, MaxCua
	printf "%s %3.2f %3.2f %3.2f %3.2f %3.2f\n", "Quinto:",  MinQui, PromedioQui, MedianaQui, DesvEstandarQui, MaxQui
	printf "%s %3.2f %3.2f %3.2f %3.2f %3.2f\n", "Sexto:",   MinSex, PromedioSex, MedianaSex, DesvEstandarSex, MaxSex
}
BEGIN{
	FS="|"
	RS="\n"
	OFS="|"

	# Fichero donde se encuentran listado de numeros que no son encontrados.
	FchEstat1="C:\\Users\\Ariel Mairena\\Google Drive\\Casa\\Loteria Nacional\\Resultados\\EstadisticasLoteria1.txt"
	FchEstat2="C:\\Users\\Ariel Mairena\\Google Drive\\Casa\\Loteria Nacional\\Resultados\\EstadisticasLoteria2.txt"
	FchEstat="C:\\Users\\Ariel Mairena\\Google Drive\\Casa\\Loteria Nacional\\Resultados\\EstadisticasLoteria.txt"
	FchDiferencias="C:\\Users\\Ariel Mairena\\Google Drive\\Casa\\Loteria Nacional\\Resultados\\DiferenciasEstadisticas.txt"
	
	# Subimos a memoria listado de numeros que no son encontrados automaticamente y son subidos manualmente.
	while (getline < FchEstat1){
		# Saltamos encabezados.
		Cont1++
		if (Cont1==1){continue}
		
		# Guardamos en memoria lista con numeros ganadores de loteria encontrados con metodo TABLE.
		MetodoTable1[$1"|"$3"|"$4"|"$2]++
		MetodoTable2[$1"|"$3"|"$4]= $2
		MetodoTable2Count[$1"|"$3"|"$4]++
		MetodoTable3[$1"|"$3]= $1"|"$3"|"$2"|"$4
		MetodoTable3Count[$1"|"$3]++
	}
	
	# Seteamos el fichero a procesar.
	ARGV[1] = FchEstat2
	ARGC = 2
}
{
	# Saltamos encabezados.
	if (NR ==1){next}

	# Guardamos en memoria numeros ganadores de loteria encontrados con metodo RAW.
	MetodoRaw1[$1"|"$3"|"$4"|"$2]=$6
	MetodoRaw2[$1"|"$3"|"$4]= $2
	MetodoRaw2_Add[$1"|"$3"|"$4]=$6
	MetodoRaw2Count[$1"|"$3"|"$4]++
	MetodoRaw3[$1"|"$3]= $1"|"$3"|"$2"|"$4"|"$6
	MetodoRaw3Count[$1"|"$3]++
}
END{
	# Imprimimos los encabezados de fichero unificado.
	print "Sorteo|NumeroPremio|Monto|TipoPremio1|TipoCoincidencia|PorcConfianza" > FchEstat

	# Buscamos coincidencia perfecta por metodo TABLE.
	for (Pk1 in MetodoTable1){
		# Obtenemos el detalle de la llave del metodo TABLE.
		split(Pk1,arrTABLE1,"|")
			
		if (Pk1 in MetodoRaw1){
			# Exportamos a fichero todas las coincidencia perfectas.
			print Pk1,"Perfecta",MetodoRaw1[Pk1] >> FchEstat
		
			# Eliminamos la coincidencia perfecta encontrada del arreglo RAW.
			delete MetodoRaw1[Pk1]
			delete MetodoTable1[Pk1]
			MetodoRaw2Count[arrTABLE1[1]"|"arrTABLE1[2]"|"arrTABLE1[3]]--
			MetodoRaw3Count[arrTABLE1[1]"|"arrTABLE1[2]]--
			MetodoTable2Count[arrTABLE1[1]"|"arrTABLE1[2]"|"arrTABLE1[3]]--
			MetodoTable3Count[arrTABLE1[1]"|"arrTABLE1[2]]--
		
			# Coincidencia perfecta, no lo registramos(porque solo marcamos diferencias), y saltamos al proximo registro.
			continue 
		}
	}
		
	# Buscamos coincidencia perfecta por metodo TABLE.
	for (Pk1 in MetodoTable1){
		# Obtenemos el detalle de la llave del metodo TABLE.
		split(Pk1,arrTABLE1,"|")
			
		if (Pk1 in MetodoRaw1){
			# Coincidencia perfecta, no lo registramos(porque solo marcamos diferencias), y saltamos al proximo registro.
			continue 
		} else {
			# Buscamos coincidencia por Sorteo|NumeroPremio|Monto.
			if (MetodoRaw2[arrTABLE1[1]"|"arrTABLE1[2]"|"arrTABLE1[3]]){
				# Contamos la cantidad de ocurrencias en RAW segun la llave.
				if (MetodoRaw2Count[arrTABLE1[1]"|"arrTABLE1[2]"|"arrTABLE1[3]]==1){
					# Exportamos a fichero todas los registros que coinciden en monto y que unicamente difieren en TipoPremio, dejamos el de TABLE porque es mas exacto.
					print arrTABLE1[1], arrTABLE1[2], arrTABLE1[3], MetodoRaw2[arrTABLE1[1]"|"arrTABLE1[2]"|"arrTABLE1[3]], "Monto T=R & Dif TipoPremio", arrRAW3[5] >> FchEstat
					# print Pk1,"Monto T=R & Dif TipoPremio",arrRAW3[5] >> FchEstat
						
					# Registramos la diferencia. Sorteo|NumeroPremio|Cnt1|Cnt2|TipoPremio1|TipoPremio2|Monto1|Monto2.
					#Difiere[Pk1"|TABLE"]="TipoPremio|" arrTABLE1[1]"|"arrTABLE1[2]"|"MetodoTable2Count[arrTABLE1[1]"|"arrTABLE1[2]"|"arrTABLE1[3]]"|1|" arrTABLE1[3] "|" arrTABLE1[3] "|"arrTABLE1[4]"|"MetodoRaw2[arrTABLE1[1]"|"arrTABLE1[2]"|"arrTABLE1[3]]"|"MetodoRaw2_Add[arrTABLE1[1]"|"arrTABLE1[2]"|"arrTABLE1[3]]
				} else {
					# Registramos duplicidad de llave Sorteo|NumeroPremio|Monto con distinto TipoPremio.
					Difiere[Pk1"|TABLE"]="TipoPremioDuplicado1|" arrTABLE1[1] "|" arrTABLE1[2] "|" MetodoTable2Count[arrTABLE1[1]"|"arrTABLE1[2]"|"arrTABLE1[3]] "|" MetodoRaw2Count[arrTABLE1[1]"|"arrTABLE1[2]"|"arrTABLE1[3]] "|0|0|||"
				}
			# Buscamos coincidencia por Sorteo|NumeroPremio.
			} else if (MetodoRaw3[arrTABLE1[1]"|"arrTABLE1[2]]){
				# Obtenemos el detalle.
				split(MetodoRaw3[arrTABLE1[1]"|"arrTABLE1[2]],arrRAW3,"|")
				# Contamos la cantidad de veces que aparece en RAW.
				if (MetodoRaw3Count[arrTABLE1[1]"|"arrTABLE1[2]]==1){
					# En caso que no este dos veces el mismo numero y que difieran resultados de tipo de premio y monto.
					if (arrTABLE1[4]!=arrRAW3[3] && arrTABLE1[3]!=arrRAW3[4]){
						# En caso que tengamos un nivel de confianza del 100% en metodo RAW y no se haya podido determinar en TABLE, ponemos datos de RAW, dado que se tiene una confianza muy alta de que este correcto minimizando el porcentaje de error.
						if (arrTABLE1[4]=="NI" && arrRAW3[5]=="100.00" && arrRAW3[3]!=""){
							# Exportamos a fichero todas las coincidencia donde este No Informado en TABLE pero en RAW tenga confianza del 100%.
							print arrRAW3[1],arrRAW3[2],arrRAW3[4],arrRAW3[3],"TableNI RAWConf.100",arrRAW3[5] >> FchEstat
						} else {
							# Registramos la diferencia. Diferencia|Sorteo|NumeroPremio|Cnt1|Cnt2|TipoPremio1|TipoPremio2|Monto1|Monto2.
							Difiere[Pk1"|TABLE"]="TipoPremioMonto|" arrTABLE1[1]"|"arrTABLE1[2]"|"MetodoRaw3Count[arrTABLE1[1]"|"arrTABLE1[2]]"|"MetodoTable3Count[arrTABLE1[1]"|"arrTABLE1[2]]"|"arrTABLE1[3]"|"arrRAW3[4]"|"arrTABLE1[4]"|"arrRAW3[3]"|"arrRAW3[5]
						}
					# Si difiere unicamente en TipoPremio.
					} else if ((arrTABLE1[4]!=arrRAW3[3]) && (arrRAW3[3]!="")){
						# Exportamos a fichero todas los registros que coinciden en monto y que unicamente difieren en TipoPremio, dejamos el de TABLE porque es mas exacto.
						print arrTABLE1[1], arrTABLE1[2], arrTABLE1[3], arrRAW3[3], "Monto T=R & Dif TipoPremio2", arrRAW3[5] >> FchEstat
					# Si difiere unicamente en TipoPremio.
					} else if ((arrTABLE1[4]!=arrRAW3[3]) && (arrTABLE1[4]!="")){
						# Exportamos a fichero todas los registros que coinciden en monto y que unicamente difieren en TipoPremio, dejamos el de TABLE porque es mas exacto.
						print Pk1,"Monto T=R & Dif TipoPremio3",arrRAW3[5] >> FchEstat						
					} else if (arrTABLE1[3]!=arrRAW3[4]){
						# En caso que exista diferencias en Monto unicamente y esta no sea mayor que C$2,000.00, siendo el Monto de TABLE mayor que el de RAW.
						if ((arrTABLE1[3] > arrRAW3[4]) && ((arrTABLE1[3] - arrRAW3[4])<=2000)){
							# Exportamos a fichero todas las coincidencia donde la diferencias en Monto no sean mayor a C$2,000.00.
							print arrRAW3[1],arrRAW3[2],arrRAW3[4],arrRAW3[3],"Monto T>R & Dif<2000",arrRAW3[5] >> FchEstat
						# En caso que el Monto en RAW sea mayor que en TABLE y su diferencia NO sobrepase los C$2,000.00.
						} else if ((arrRAW3[4] > arrTABLE1[3]) && ((arrRAW3[4] - arrTABLE1[3])<=2000)){
							# Exportamos a fichero todas las coincidencia perfectas.
							print Pk1,"Monto T<R & Dif<2000",arrRAW3[5] >> FchEstat
						} else {
							# Registramos la diferencia. Diferencia|Sorteo|NumeroPremio|Cnt1|Cnt2|TipoPremio1|TipoPremio2|Monto1|Monto2.
							Difiere[Pk1"|TABLE"]="Monto|" arrTABLE1[1]"|"arrTABLE1[2]"|"MetodoRaw3Count[arrTABLE1[1]"|"arrTABLE1[2]]"|"MetodoTable3Count[arrTABLE1[1]"|"arrTABLE1[2]]"|"arrTABLE1[3]"|"arrRAW3[4]"|"arrTABLE1[4]"|"arrRAW3[3]"|"arrRAW3[5]
						}
					} else {
						# Registramos la diferencia. Diferencia|Sorteo|NumeroPremio|Cnt1|Cnt2|TipoPremio1|TipoPremio2|Monto1|Monto2.
						Difiere[Pk1"|TABLE"]="Otro|" arrTABLE1[1]"|"arrTABLE1[2]"|"MetodoRaw3Count[arrTABLE1[1]"|"arrTABLE1[2]]"|"MetodoTable3Count[arrTABLE1[1]"|"arrTABLE1[2]]"|"arrTABLE1[3]"|"arrRAW3[4]"|"arrTABLE1[4]"|"arrRAW3[3]"|"arrRAW3[5]
					}
				} else {
					# Registramos duplicidad de llave Sorteo|NumeroPremio|Monto con distinto TipoPremio.
					Difiere[Pk1"|TABLE"]="TipoPremioMontoDuplicado2|" arrTABLE1[1] "|" arrTABLE1[2] "|" MetodoTable3Count[arrTABLE1[1]"|"arrTABLE1[2]] "|" MetodoRaw3Count[arrTABLE1[1]"|"arrTABLE1[2]] "|0|0|||0"
				}
			} else {
				# Registramos la diferencia.
				Difiere[Pk1"|TABLE"]= "NoExisteEnRAW|" arrTABLE1[1] "|" arrTABLE1[2] "|1|0|" arrTABLE1[3] "|0|" arrTABLE1[4] "||0"
			}
		}
	}

	# Buscamos coincidencia perfecta por metodo TABLE.
	for (Pk1 in MetodoRaw1){
		if (Pk1 in MetodoTable1){
			# Coincidencia perfecta, no lo registramos(porque solo marcamos diferencias), y saltamos al proximo registro.
			continue
		} else {
			# Obtenemos el detalle de la llave del metodo TABLE.
			split(Pk1,arrRAW1,"|")
			
			if (MetodoTable2[arrRAW1[1]"|"arrRAW1[2]"|"arrRAW1[3]]){
				
			} else if (MetodoTable3[arrRAW1[1]"|"arrRAW1[2]]){
				
			} else {
				Difiere[Pk1"|RAW"]= "NoExisteEnTABLE|" arrRAW1[1] "|" arrRAW1[2] "|0|1|0|" arrRAW1[3] "||" arrRAW1[4] "|" MetodoRaw1[Pk1]
			}
		}
	}

	#print "Sorteo|NumeroPremio|Diferencia|TipoPremio1|TipoPremio2|Monto1|Monto2" > FchDiferencias
	print "Diferencia|Sorteo|NumeroPremio|Cnt1|Cnt2|Monto1|Monto2|TipoPremio1|TipoPremio2|PorcConfianza2" > FchDiferencias
	for (a in Difiere){
		split(Difiere[a],arrDif,"|")
		ResumenDif[arrDif[1]]++
		print Difiere[a] >> FchDiferencias
	}
	
	print "Resumen General de Diferencias:"
	for (b in ResumenDif){
		print b, ResumenDif[b]
	}
}
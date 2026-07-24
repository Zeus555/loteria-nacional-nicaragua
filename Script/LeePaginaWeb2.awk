BEGIN {
	FchHosts="/home/anonimo/Documentos/PRC JOB/Hosts"
	
	while((getline < FchHosts) > 0){
		arrHosts[$1]=$2
	}

	for (i=1;i<=900000;i++){
		for (b in arrHosts){
			# Separadores de registros para entradas y salidas.
			RS=ORS="\r\n"
			# Servidor Destino.
			#IP_Destino="10.108.99.247"
			IP_Destino=b
			# Puerto Destino.
			Puerto_Destino="4040"
			#Puerto_Destino="8080"
			# Pagina a Leer.
			PaginaWeb=""	
			# Servicio web a consumir.
			http = "/inet4/tcp/0/" IP_Destino "/" Puerto_Destino
			# Tiempo maximo de espera por una respuesta.
			PROCINFO[http, "READ_TIMEOUT"] = 100
			# Solicitud de lectura de pagina web.
			print "GET http://" IP_Destino ":" Puerto_Destino "/" PaginaWeb |& http
			
			#Imprimimos el IP_Destino
			print "IP Destino:" IP_Destino " Nombre:"  arrHosts[b]
			
			# Leemos la respuesta linea a linea.
			while ((http |& getline) > 0){
				NR++
				# Imprimimos toda la linea de respuesta.
				arrRespuesta[1]=$0
			}
			
			# Cerramos la conexion del servicio leido.
			close(http)
			
			for (a in arrRespuesta){
				aa=match(arrRespuesta[a],/[0-9]+/,arr)
				if (aa>0){print " ... " arr[0]}
			}			
		}
	}
}
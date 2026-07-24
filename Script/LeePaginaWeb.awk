BEGIN {
	# Separadores de registros para entradas y salidas.
	RS=ORS="\r\n"
	# Servidor Destino.
	#IP_Destino="10.108.99.247"
	IP_Destino="DESKTOP-MQFIJB5"
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
	
	# Leemos la respuesta linea a linea.
	while ((http |& getline) > 0){
		NR++
		# Imprimimos toda la linea de respuesta.
		arrRespuesta[1]=$0
	}
	
	# Cerramos la conexion del servicio leido.
	close(http)
	
	for (a in arrRespuesta){
		print a, arrRespuesta[a]
	}
}
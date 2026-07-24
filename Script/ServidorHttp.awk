BEGIN {
	OFS="	"
	RS = ORS = "\r\n"
	if (MyPort ==  0) MyPort = 80
	HttpService = "/inet4/tcp/" MyPort "/0/0"
	while ("awk" != "complex") {
		contar++

		# Detenemos el servicio a las n-transacciones.
		if (contar>=100000){break}
		
		# Formamos el HTML de respuesta dinamica.
		Hello = "<HTML><HEAD><TITLE>Out Of Service</TITLE>" \
		 "</HEAD><BODY>" \
		 "<div>" contar ".</div>" \
		 "</BODY></HTML>"	 
		
		# Obtenemos la longitud del HTML enviado.
		Len = length(Hello) + length(ORS)

		# Enviamos respuesta a la solicitud.
		print "HTTP/1.0 200 OK"          |& HttpService
		print "Content-Length: " Len ORS |& HttpService
		print Hello                      |& HttpService
		
		# Contador de numero de linea de respuesta a cero.
		NumLineaRecibida=0
		
		# Obteneos respuesta.
		while ((HttpService |& getline) > 0){
			# Contador de numero de linea.
			NumLineaRecibida++
			# Evalua si en la linea recibida viene la palabra clave STOP para detener el servicio.
			HttpSTOP=index($0,"STOP")
			# Registramos en arreglo en memoria cada una de las lineas recibidas con su numero de linea.
			arrResp[NumLineaRecibida]=$0
		}
		
		# Cerramos conexion.
		close(HttpService)
		
		# Detenemos ejecucion en caso que se encuentre palabra clave para detener servicio.
		# if (HttpSTOP>0){exit 0}
		
		# Imprimimos contador cada n-cantidad de registros.
		Commit=contar/100
		if ((contar/100)==int(contar/100)){print contar}
		
		# Imprimimos respuestas.
		for (a=1;a<=NumLineaRecibida;a++){
			print a,arrResp[a]
		}
	}
}
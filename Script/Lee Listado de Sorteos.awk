BEGIN {
	# Separadores de registros para entradas y salidas.
	RS=ORS="\r\n"
	IP_Destino="www.loterianacional.com.ni"

	# Servicio web a consumir.
	http = "/inet4/tcp/0/" IP_Destino "/80"

	# Tiempo maximo de espera por una respuesta.
	PROCINFO[http, "READ_TIMEOUT"] = 1000

	# Creamos el request.
	Request="GET /loteria/busqueda/ HTTP/1.1\r\n" \
			"Host: www.loterianacional.com.ni\r\n" \
			"Connection: keep-alive\r\n" \
			"Cache-Control: max-age=0\r\n" \
			"Upgrade-Insecure-Requests: 1\r\n" \
			"User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/74.0.3729.169 Safari/537.36\r\n" \
			"Accept: text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3\r\n" \
			"Referer: http://www.loterianacional.com.ni/loteria/\r\n" \
			"Accept-Encoding: gzip, deflate\r\n" \
			"Accept-Language: es-NI,es-419;q=0.9,es;q=0.8,en;q=0.7,und;q=0.6\r\n" \
			"Cookie: cookiesession1=PON_AQUI_TU_COOKIE; _ga=GA1.3.0.0; _gid=GA1.3.0.0; _gat_gtag_UA_134618138_1=1\r\n" \
			"\r\n"
	
	# print Request
	
	# Solicitud de lectura de pagina web.
	print Request |& http
	
	# Leemos la respuesta linea a linea.
	while ((http |& getline) > 0){
		Contador++
		# Guardamos en memoria toda la pagina web.
		arrRespuesta[Contador]=$0
	}
	
	# Cerramos la conexion del servicio leido.
	close(http)
	
	for (a in arrRespuesta){
		#vLinea=arrRespuesta[a]
		#if (match(vLinea,/pdf/)>0){
			print arrRespuesta[a]
		#}
	}
}
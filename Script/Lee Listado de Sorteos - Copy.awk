BEGIN {
	# Separadores de registros para entradas y salidas.
	RS=ORS="\r\n"
	# Dominio del sitio web a leer.
	Dominio="www.loterianacional.com.ni"
	IP_Destino="165.98.133.116"
	IP_Destino="10.0.0.21"
	# Puerto Destino.
	Puerto_Destino="80"
	# Pagina a Leer.
	PaginaWeb="/loteria/busqueda/"	
	# Usuario Agente.
	UserAgent="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/74.0.3729.157 Safari/537.3"
	
	# Servicio web a consumir.
	http = "/inet4/tcp/0/" IP_Destino "/" Puerto_Destino
	# Tiempo maximo de espera por una respuesta.
	PROCINFO[http, "READ_TIMEOUT"] = 1000
	# Pagina web destino.
	URL="http://" IP_Destino ":" Puerto_Destino PaginaWeb
	
	# Creamos el request.
	Request="GET " PaginaWeb " HTTP/1.1\n" \
			"Host: www.loterianacional.com.ni\n" \
			"Connection: keep-alive\n" \
			"Cache-Control: max-age=0\n" \
			"Upgrade-Insecure-Requests: 1\n" \
			"User-Agent: " UserAgent "\n" \
			"Accept: text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3\n" \
			"Accept-Encoding: gzip, deflate\n" \
			"Accept-Language: es-NI,es-419;q=0.9,es;q=0.8,en;q=0.7,und;q=0.6\n" \
			"Cookie: cookiesession1=PON_AQUI_TU_COOKIE; _ga=GA1.3.0.0; _gid=GA1.3.0.0"
	
	# GET /loteria/busqueda/ HTTP/1.1
	# Host: www.loterianacional.com.ni
	# Connection: keep-alive
	# Upgrade-Insecure-Requests: 1
	# User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/74.0.3729.157 Safari/537.36
	# Accept: text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3
	# Accept-Encoding: gzip, deflate
	# Accept-Language: es-NI,es-419;q=0.9,es;q=0.8,en;q=0.7,und;q=0.6
	# Cookie: cookiesession1=PON_AQUI_TU_COOKIE; _ga=GA1.3.0.0; _gid=GA1.3.0.0
	
	# print Request
	
	# Solicitud de lectura de pagina web.
	# print Request |& http
	
print "GET " URL " HTTP/1.1" |& http
#print "Host: www.loterianacional.com.ni" |& http
#print "Connection: keep-alive" |& http
#print "Cache-Control: max-age=0" |& http
#print "Upgrade-Insecure-Requests: 1" |& http
#print "User-Agent: " UserAgent |& http
#print "Accept: text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3" |& http
#print "Accept-Encoding: gzip, deflate" |& http
#print "Accept-Language: es-NI,es-419;q=0.9,es;q=0.8,en;q=0.7,und;q=0.6" |& http
#print "Cookie: cookiesession1=PON_AQUI_TU_COOKIE; _ga=GA1.3.0.0; _gid=GA1.3.0.0" |& http
	
	# Leemos la respuesta linea a linea.
	while ((http |& getline) > 0){
		Contador++
		# Guardamos en memoria toda la pagina web.
		arrRespuesta[Contador]=$0
	}
	
	# Cerramos la conexion del servicio leido.
	close(http)
	
	for (a in arrRespuesta){
		print "   ",a, arrRespuesta[a]
	}
}
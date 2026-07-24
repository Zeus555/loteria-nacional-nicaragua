BEGIN {
  RS = ORS = "\r\n"
  HttpService = "/inet4/tcp/0/proxy/80"
  url="http://www.loterianacional.com.ni/sorteos"
  var = "GET " url " HTTP/1.1" ORS ORS
  
  print var |& HttpService
  while ((HttpService |& getline Line) > 0)
    print Line
  close(HttpService)
}
BEGIN {
	OFS="@"
	
	arrListSearch["PDF"]="<a href=\042(https://www.loterianacional.com.ni/wp-content/uploads/[0-9]{4}/[0-9]{2}/Lista-[0-9]{4}.pdf)\042.+/></span></a>"
	arrListSearch["NumSorteo"]="<div class=\042et_pb_text_inner\042><h1>Sorteo (.+)</h1>"
	arrListSearch["FechaSorteo"]="Fecha: ([0-9]{2} de [a-zA-Z]+ [0-9]{4})</p>"
	arrListSearch["ImgSorteo"]="src=\042(https://www.loterianacional.com.ni/wp-content/uploads/[0-9]{4}/[0-9]{2}/[0-9]{4}.*.jpg)\042 alt=\042\042 title"
	#arrListSearch["PrecioSorteo"]=""
}
{
	for (a in arrListSearch){
		regexp=arrListSearch[a]
		n=match($0,regexp,aField)
		if (n>0){
			Name=a
			Value=aField[1]
			arrField[Name]=Value

			if (arrField["NumSorteo"] && arrField["PDF"] && arrField["FechaSorteo"] && arrField["ImgSorteo"]){
				arrSorteos[arrField["NumSorteo"]]=arrField["NumSorteo"] OFS arrField["PDF"] OFS arrField["FechaSorteo"] OFS arrField["ImgSorteo"] OFS 0
				for (b in arrField){delete arrField[b]} # Borramos todo el listado de campos con valores.
			}
		}
	}
}
END {
	for (c in arrSorteos){
		print arrSorteos[c]
	}
}
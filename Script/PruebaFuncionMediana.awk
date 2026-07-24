function mediana(c,v,j) { 
   asort(v,j); 
   if (c % 2) return j[(c+1)/2]; 
   else return (j[c/2+1]+j[c/2])/2.0; 
} 
{
	if ($1!=0){
		count++
		values[count]=$NF
	} 
} 
END { 
         print  mediana(count,values); 
}
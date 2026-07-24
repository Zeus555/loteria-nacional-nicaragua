BEGIN {
    myArray["peter"] = 32
    myArray["bob"] = 5
    myArray["john"] = 463
    myArray["jack"] = 11

    PROCINFO["sorted_in"] = "@val_num_asc"

    for (i in myArray) {
        print i, myArray[i]
    }

 }
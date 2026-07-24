BEGIN {
    myArray["peter"] = 32
    myArray["bob"] = 5
    myArray["john"] = 463
    myArray["jack"] = 11

    num = asorti(myArray, indices)
    for (i=1; i<=num; i++) print indices[i], myArray[indices[i]]
}
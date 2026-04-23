

def flops(E, k):
    return 2*E*k

def mem_good(V, E, k, datasize):
    return (E+V*k*2)*datasize

def mem_bad(V,E,k,datasize, CL):
    if k*datasize < CL:
        return (E+V*k)*datasize+E*CL
    else:
        return (E+V*k)*datasize+E*k*datasize


flopsrating = 10*1000*1000*1000 #10TFlop/s
memBW = 2*1000*1000*1000 #2TB/s

edgefactor=16

V=23

E = V*edgefactor

datasize=8 #double/int64

CL=1024/8

for k in [2**i for i in range(0,12)]:

    floptime = flops(E,k)/flopsrating

    goodmemtime = mem_good(V,E,k,datasize)/memBW
    badmemtime = mem_bad(V,E,k,datasize, CL)/memBW

    goodtime=max(floptime,goodmemtime)
    badtime=max(floptime,badmemtime)
    print (k, flops(E,k)/goodtime, flops(E,k)/badtime)



CXXFLAGS += -I ~/local/poski-1.0.0/include/poski/ -I ~/prgs/poski-v1.0.0/oski/build_oski/include/

POSKI_LDFLAGS += -L  ~/local/poski-1.0.0/lib/ -lposki
MKL_LDFLAGS += -Wl,--start-group -lmkl_intel_lp64 -lmkl_intel_thread -lmkl_core -liomp5 -Wl,--end-group

INCLUDES   = -I./

TARGET     =  cuda-spmm-repeated # omp-spmv-tc omp-spmv-tc-store seq-spmv omp-spmv omp-spmv-pref64 omp-spmv-pref128 omp-spmv-pref256 omp-spmv-pref512 omp-spmv-pref1024 omp-spmv-vect-row-88 omp-spmv-vect-row-48 omp-spmv-vect-row-28 omp-spmv-vect-row-18 omp-spmv-vect-row2-88 omp-spmv-vect-row2-48 omp-spmv-vect-row2-28 omp-spmv-vect-row2-18 omp-spmv-vect-col-88 omp-spmv-vect-col-84 omp-spmv-vect-col-82 omp-spmv-vect-col-81 omp-spmv-vect-swi-88 omp-spmv-vect  omp-spmv-pref omp-spmm mkl-spmv mkl-spmm mkl-tspmv omp-spmm-vect seq-tspmv omp-tspmv-part omp-tspmv-part-static omp-tspmv-privatemem omp-tspmv-coloring omp-tspmv-atomics omp-tspmv-blockcoloring omp-tspmv-blockcutoffcoloring # poski-spmv poski-spmv-tuned poski-tspmv poski-tspmv-tuned # cuda-spmv cuda-tspmv cuda-spmm cuda-tspmm 

CFILES       = ulib 

CXXFILES   = seq-spmv omp-spmv omp-spmv-tc  omp-spmv-tc-store omp-spmv-vect  omp-spmv-pref omp-spmm mkl-spmv mkl-spmm mkl-tspmv omp-spmm-vect seq-tspmv omp-tspmv-part omp-tspmv-part-static omp-tspmv-privatemem omp-tspmv-atomics omp-tspmv-coloring omp-tspmv-blockcoloring omp-tspmv-blockcutoffcoloring # poski-spmv poski-spmv-tuned poski-tspmv poski-tspmv-tuned # cuda-spmv cuda-tspmv cuda-spmm cuda-tspmm

SRCS	= $(CFILES:%=%.c) $(CXXFILES:%=%.cpp)

TBBLDFLAGS= -L /opt/intel/composerxe/tbb/lib/mic -ltbb 


all: $(TARGET)

installCPU: $(TARGET)
	cp $(TARGET) ../../CPU/

installKNC: $(TARGET)
	cp $(TARGET) ../../KNC/


seq-spmv: seq-spmv.o ulib.o mmio.o
	$(LD) $(LDFLAGS) -o $@ mmio.c ulib.o seq-spmv.o $(LIBS) 

seq-tspmv: seq-tspmv.o ulib.o mmio.o
	$(LD) $(LDFLAGS) -o $@ mmio.c ulib.o seq-tspmv.o $(LIBS) 

omp-tspmv-part: omp-tspmv-part.o ulib.o mmio.o
	$(LD) $(LDFLAGS) -o $@ mmio.c ulib.o omp-tspmv-part.o $(LIBS) 

omp-tspmv-coloring: omp-tspmv-coloring.o ulib.o mmio.o
	$(LD) $(LDFLAGS) -o $@ mmio.c ulib.o omp-tspmv-coloring.o $(LIBS) 

omp-tspmv-blockcoloring: omp-tspmv-blockcoloring.o ulib.o mmio.o
	$(LD) $(LDFLAGS) -o $@ mmio.c ulib.o omp-tspmv-blockcoloring.o $(LIBS) 

omp-tspmv-blockcutoffcoloring: omp-tspmv-blockcutoffcoloring.o ulib.o mmio.o
	$(LD) $(LDFLAGS) -o $@ mmio.c ulib.o omp-tspmv-blockcutoffcoloring.o $(LIBS) 

omp-tspmv-atomics: omp-tspmv-atomics.o ulib.o mmio.o
	$(LD) $(LDFLAGS) -o $@ mmio.c ulib.o omp-tspmv-atomics.o $(LIBS) 

omp-tspmv-part-static: omp-tspmv-part-static.o ulib.o mmio.o
	$(LD) $(LDFLAGS) -o $@ mmio.c ulib.o omp-tspmv-part-static.o $(LIBS) 

omp-tspmv-privatemem: omp-tspmv-privatemem.o ulib.o mmio.o
	$(LD) $(LDFLAGS) -o $@ mmio.c ulib.o omp-tspmv-privatemem.o $(LIBS) 

omp-spmv: omp-spmv.o ulib.o mmio.o logged_array.o
	$(LD) $(LDFLAGS) -o $@ mmio.c ulib.o omp-spmv.o logged_array.o $(LIBS) 

omp-spmv-tc: omp-spmv-tc.o ulib.o mmio.o
	$(LD) $(LDFLAGS) -o $@ mmio.c ulib.o omp-spmv-tc.o $(LIBS) 

omp-spmv-tc-store: omp-spmv-tc-store.o ulib.o mmio.o
	$(LD) $(LDFLAGS) -o $@ mmio.c ulib.o omp-spmv-tc-store.o $(LIBS) 

omp-spmv-pref64.o: omp-spmv.cpp main-spmv.hpp
	$(CXX) $(CXXFLAGS) $(INCLUDES) -DPREFETCHDISTANCE=64 -c omp-spmv.cpp -o $@

omp-spmv-pref64: omp-spmv-pref64.o ulib.o mmio.o
	$(LD) $(LDFLAGS) -o $@ mmio.c ulib.o omp-spmv-pref64.o $(LIBS) 


omp-spmv-pref128.o: omp-spmv.cpp main-spmv.hpp
	$(CXX) $(CXXFLAGS) $(INCLUDES) -DPREFETCHDISTANCE=128 -c omp-spmv.cpp -o $@

omp-spmv-pref128: omp-spmv-pref128.o ulib.o mmio.o
	$(LD) $(LDFLAGS) -o $@ mmio.c ulib.o omp-spmv-pref128.o $(LIBS) 

omp-spmv-pref256.o: omp-spmv.cpp main-spmv.hpp
	$(CXX) $(CXXFLAGS) $(INCLUDES) -DPREFETCHDISTANCE=256 -c omp-spmv.cpp -o $@

omp-spmv-pref256: omp-spmv-pref256.o ulib.o mmio.o
	$(LD) $(LDFLAGS) -o $@ mmio.c ulib.o omp-spmv-pref256.o $(LIBS) 

omp-spmv-pref512.o: omp-spmv.cpp main-spmv.hpp
	$(CXX) $(CXXFLAGS) $(INCLUDES) -DPREFETCHDISTANCE=512 -c omp-spmv.cpp -o $@

omp-spmv-pref512: omp-spmv-pref512.o ulib.o mmio.o
	$(LD) $(LDFLAGS) -o $@ mmio.c ulib.o omp-spmv-pref512.o $(LIBS) 

omp-spmv-pref1024.o: omp-spmv.cpp main-spmv.hpp
	$(CXX) $(CXXFLAGS) $(INCLUDES) -DPREFETCHDISTANCE=1024 -c omp-spmv.cpp -o $@

omp-spmv-pref1024: omp-spmv-pref1024.o ulib.o mmio.o
	$(LD) $(LDFLAGS) -o $@ mmio.c ulib.o omp-spmv-pref1024.o $(LIBS) 


omp-spmv-vect-row-88.o: omp-spmv-vect-bcsr.cpp main-spmv.hpp
	$(CXX) $(CXXFLAGS) $(INCLUDES) -DRMJR -DBR=8 -DBC=8  -c omp-spmv-vect-bcsr.cpp -o $@

omp-spmv-vect-row-88: omp-spmv-vect-row-88.o ulib.o mmio.o
	$(LD) $(LDFLAGS) -o $@ mmio.c ulib.o omp-spmv-vect-row-88.o $(LIBS) 

omp-spmv-vect-row-48.o: omp-spmv-vect-bcsr.cpp main-spmv.hpp
	$(CXX) $(CXXFLAGS) $(INCLUDES) -DRMJR -DBR=4 -DBC=8  -c omp-spmv-vect-bcsr.cpp -o $@

omp-spmv-vect-row-48: omp-spmv-vect-row-48.o ulib.o mmio.o
	$(LD) $(LDFLAGS) -o $@ mmio.c ulib.o omp-spmv-vect-row-48.o $(LIBS) 


omp-spmv-vect-row-28.o: omp-spmv-vect-bcsr.cpp main-spmv.hpp
	$(CXX) $(CXXFLAGS) $(INCLUDES) -DRMJR -DBR=2 -DBC=8  -c omp-spmv-vect-bcsr.cpp -o $@

omp-spmv-vect-row-28: omp-spmv-vect-row-28.o ulib.o mmio.o
	$(LD) $(LDFLAGS) -o $@ mmio.c ulib.o omp-spmv-vect-row-28.o $(LIBS) 


omp-spmv-vect-row-18.o: omp-spmv-vect-bcsr.cpp main-spmv.hpp
	$(CXX) $(CXXFLAGS) $(INCLUDES) -DRMJR -DBR=1 -DBC=8  -c omp-spmv-vect-bcsr.cpp -o $@

omp-spmv-vect-row-18: omp-spmv-vect-row-18.o ulib.o mmio.o
	$(LD) $(LDFLAGS) -o $@ mmio.c ulib.o omp-spmv-vect-row-18.o $(LIBS) 


omp-spmv-vect-row2-88.o: omp-spmv-vect-bcsr.cpp main-spmv.hpp
	$(CXX) $(CXXFLAGS) $(INCLUDES) -DRMJR2 -DBR=8 -DBC=8  -c omp-spmv-vect-bcsr.cpp -o $@

omp-spmv-vect-row2-88: omp-spmv-vect-row2-88.o ulib.o mmio.o
	$(LD) $(LDFLAGS) -o $@ mmio.c ulib.o omp-spmv-vect-row2-88.o $(LIBS) 


omp-spmv-vect-row2-48.o: omp-spmv-vect-bcsr.cpp main-spmv.hpp
	$(CXX) $(CXXFLAGS) $(INCLUDES) -DRMJR2 -DBR=4 -DBC=8  -c omp-spmv-vect-bcsr.cpp -o $@

omp-spmv-vect-row2-48: omp-spmv-vect-row2-48.o ulib.o mmio.o
	$(LD) $(LDFLAGS) -o $@ mmio.c ulib.o omp-spmv-vect-row2-48.o $(LIBS) 

omp-spmv-vect-row2-28.o: omp-spmv-vect-bcsr.cpp main-spmv.hpp
	$(CXX) $(CXXFLAGS) $(INCLUDES) -DRMJR2 -DBR=2 -DBC=8  -c omp-spmv-vect-bcsr.cpp -o $@

omp-spmv-vect-row2-28: omp-spmv-vect-row2-28.o ulib.o mmio.o
	$(LD) $(LDFLAGS) -o $@ mmio.c ulib.o omp-spmv-vect-row2-28.o $(LIBS) 


omp-spmv-vect-row2-18.o: omp-spmv-vect-bcsr.cpp main-spmv.hpp
	$(CXX) $(CXXFLAGS) $(INCLUDES) -DRMJR2 -DBR=1 -DBC=8  -c omp-spmv-vect-bcsr.cpp -o $@

omp-spmv-vect-row2-18: omp-spmv-vect-row2-18.o ulib.o mmio.o
	$(LD) $(LDFLAGS) -o $@ mmio.c ulib.o omp-spmv-vect-row2-18.o $(LIBS) 


omp-spmv-vect-col-88.o: omp-spmv-vect-bcsr.cpp main-spmv.hpp
	$(CXX) $(CXXFLAGS) $(INCLUDES) -DCMJR -DBR=8 -DBC=8  -c omp-spmv-vect-bcsr.cpp -o $@

omp-spmv-vect-col-88: omp-spmv-vect-col-88.o ulib.o mmio.o
	$(LD) $(LDFLAGS) -o $@ mmio.c ulib.o omp-spmv-vect-col-88.o $(LIBS) 

omp-spmv-vect-col-84.o: omp-spmv-vect-bcsr.cpp main-spmv.hpp
	$(CXX) $(CXXFLAGS) $(INCLUDES) -DCMJR -DBR=8 -DBC=4  -c omp-spmv-vect-bcsr.cpp -o $@

omp-spmv-vect-col-84: omp-spmv-vect-col-84.o ulib.o mmio.o
	$(LD) $(LDFLAGS) -o $@ mmio.c ulib.o omp-spmv-vect-col-84.o $(LIBS) 

omp-spmv-vect-col-82.o: omp-spmv-vect-bcsr.cpp main-spmv.hpp
	$(CXX) $(CXXFLAGS) $(INCLUDES) -DCMJR -DBR=8 -DBC=2  -c omp-spmv-vect-bcsr.cpp -o $@

omp-spmv-vect-col-82: omp-spmv-vect-col-82.o ulib.o mmio.o
	$(LD) $(LDFLAGS) -o $@ mmio.c ulib.o omp-spmv-vect-col-82.o $(LIBS) 


omp-spmv-vect-col-81.o: omp-spmv-vect-bcsr.cpp main-spmv.hpp
	$(CXX) $(CXXFLAGS) $(INCLUDES) -DCMJR -DBR=8 -DBC=1  -c omp-spmv-vect-bcsr.cpp -o $@

omp-spmv-vect-col-81: omp-spmv-vect-col-81.o ulib.o mmio.o
	$(LD) $(LDFLAGS) -o $@ mmio.c ulib.o omp-spmv-vect-col-81.o $(LIBS) 


omp-spmv-vect-swi-88.o: omp-spmv-vect-bcsr.cpp main-spmv.hpp
	$(CXX) $(CXXFLAGS) $(INCLUDES) -DSWI -DBR=8 -DBC=8  -c omp-spmv-vect-bcsr.cpp -o $@

omp-spmv-vect-swi-88: omp-spmv-vect-swi-88.o ulib.o mmio.o
	$(LD) $(LDFLAGS) -o $@ mmio.c ulib.o omp-spmv-vect-swi-88.o $(LIBS) 



omp-spmv-cut: omp-spmv-cut.o ulib.o mmio.o
	$(LD) $(LDFLAGS) -o $@ mmio.c ulib.o omp-spmv-cut.o $(LIBS) 

omp-tspmv-cut: omp-tspmv-cut.o ulib.o mmio.o
	$(LD) $(LDFLAGS) -o $@ mmio.c ulib.o omp-tspmv-cut.o $(LIBS) 

omp-tspmv-cut-privmem: omp-tspmv-cut-privmem.o ulib.o mmio.o
	$(LD) $(LDFLAGS) -o $@ mmio.c ulib.o omp-tspmv-cut-privmem.o $(LIBS) 

omp-tspmv-cut-privmem-sched: omp-tspmv-cut-privmem-sched.o ulib.o mmio.o
	$(LD) $(LDFLAGS) -o $@ mmio.c ulib.o omp-tspmv-cut-privmem-sched.o $(LIBS) 

cuda-spmv: cuda-spmv.o ulib.o mmio.o
	$(LD) $(LDFLAGS) -o $@ mmio.c ulib.o cuda-spmv.o $(LIBS) $(CUDALDFLAGS)

cuda-tspmv: cuda-tspmv.o ulib.o mmio.o
	$(LD) $(LDFLAGS) -o $@ mmio.c ulib.o cuda-tspmv.o $(LIBS) $(CUDALDFLAGS)

cuda-spmm: cuda-spmm.o ulib.o mmio.o
	$(LD) $(LDFLAGS) -o $@ mmio.c ulib.o cuda-spmm.o $(LIBS) $(CUDALDFLAGS)

cuda-spmm-repeated: cuda-spmm-repeated.o ulib.o mmio.o
	$(LD) $(LDFLAGS) -o $@ mmio.c ulib.o cuda-spmm-repeated.o $(LIBS) $(CUDALDFLAGS)


cuda-tspmm: cuda-tspmm.o ulib.o mmio.o
	$(LD) $(LDFLAGS) -o $@ mmio.c ulib.o cuda-tspmm.o $(LIBS) $(CUDALDFLAGS)

mkl-spmv: mkl-spmv.o ulib.o mmio.o
	$(LD) $(LDFLAGS) -o $@ mmio.c ulib.o mkl-spmv.o $(LIBS) $(MKL_LDFLAGS)

mkl-tspmv: mkl-tspmv.o ulib.o mmio.o
	$(LD) $(LDFLAGS) -o $@ mmio.c ulib.o mkl-tspmv.o $(LIBS) $(MKL_LDFLAGS)

mkl-spmm: mkl-spmm.o ulib.o mmio.o
	$(LD) $(LDFLAGS) -o $@ mmio.c ulib.o mkl-spmm.o $(LIBS) $(MKL_LDFLAGS)

dense-mkl: dense-mkl.o
	$(LD) $(LDFLAGS) -o $@ dense-mkl.o $(LIBS) $(MKL_LDFLAGS)

omp-spmm: omp-spmm.o ulib.o mmio.o
	$(LD) $(LDFLAGS) -o $@ mmio.c ulib.o omp-spmm.o $(LIBS)

omp-spmm-vect-reg.o: omp-spmm-vect.cpp main-spmm.hpp
	$(CXX) $(CXXFLAGS) $(INCLUDES) -DREGULAR_STORE  -c omp-spmm-vect.cpp -o $@

omp-spmm-vect-reg: omp-spmm-vect-reg.o ulib.o mmio.o
	$(LD) $(LDFLAGS) -o $@ mmio.c ulib.o omp-spmm-vect-reg.o $(LIBS)

omp-spmm-vect-nr.o: omp-spmm-vect.cpp main-spmm.hpp
	$(CXX) $(CXXFLAGS) $(INCLUDES) -DNR_STORE  -c omp-spmm-vect.cpp -o $@

omp-spmm-vect-nr: omp-spmm-vect-nr.o ulib.o mmio.o
	$(LD) $(LDFLAGS) -o $@ mmio.c ulib.o omp-spmm-vect-nr.o $(LIBS)

omp-spmm-vect-nrngo.o: omp-spmm-vect.cpp main-spmm.hpp
	$(CXX) $(CXXFLAGS) $(INCLUDES) -DNRNGO_STORE  -c omp-spmm-vect.cpp -o $@


omp-spmm-vect-nrngo: omp-spmm-vect-nrngo.o ulib.o mmio.o
	$(LD) $(LDFLAGS) -o $@ mmio.c ulib.o omp-spmm-vect-nrngo.o $(LIBS)

omp-spmm-vect: omp-spmm-vect.o ulib.o mmio.o
	$(LD) $(LDFLAGS) -o $@ mmio.c ulib.o omp-spmm-vect.o $(LIBS)

poski-spmv: poski-spmv.o ulib.o mmio.o
	$(LD) $(LDFLAGS) -o $@ mmio.c ulib.o poski-spmv.o $(LIBS) $(POSKI_LDFLAGS)

poski-spmv-tuned: poski-spmv-tuned.o ulib.o mmio.o
	$(LD) $(LDFLAGS) -o $@ mmio.c ulib.o poski-spmv-tuned.o $(LIBS) $(POSKI_LDFLAGS)

poski-tspmv: poski-tspmv.o ulib.o mmio.o
	$(LD) $(LDFLAGS) -o $@ mmio.c ulib.o poski-tspmv.o $(LIBS) $(POSKI_LDFLAGS)

poski-tspmv-tuned: poski-tspmv-tuned.o ulib.o mmio.o
	$(LD) $(LDFLAGS) -o $@ mmio.c ulib.o poski-tspmv-tuned.o $(LIBS) $(POSKI_LDFLAGS)

omp-spmv-vect: omp-spmv-vect.o ulib.o mmio.o
	$(LD) $(LDFLAGS) -o $@ mmio.c ulib.o omp-spmv-vect.o $(LIBS) 


omp-spmv-pref: omp-spmv-pref.o ulib.o mmio.o
	$(LD) $(LDFLAGS) -o $@ mmio.c ulib.o omp-spmv-pref.o $(LIBS) 


include makefile.in
# DO NOT DELETE

ulib.o: ulib.h
seq-spmv.o: main-spmv.hpp timestamp.hpp graph.hpp graph_impl.hpp ulib.h
seq-spmv.o: mmio.h
omp-spmv.o: main-spmv.hpp timestamp.hpp graph.hpp graph_impl.hpp ulib.h
omp-spmv.o: mmio.h
omp-spmv-vect.o: main-spmv.hpp timestamp.hpp graph.hpp graph_impl.hpp ulib.h
omp-spmv-vect.o: mmio.h
omp-spmv-pref.o: main-spmv.hpp timestamp.hpp graph.hpp graph_impl.hpp ulib.h
omp-spmv-pref.o: mmio.h
omp-spmm.o: main-spmm.hpp timestamp.hpp graph.hpp graph_impl.hpp ulib.h
omp-spmm.o: mmio.h
mkl-spmv.o: main-spmv.hpp timestamp.hpp graph.hpp graph_impl.hpp ulib.h
mkl-spmv.o: mmio.h
mkl-spmm.o: main-spmm.hpp timestamp.hpp graph.hpp graph_impl.hpp ulib.h
mkl-spmm.o: mmio.h
mkl-tspmv.o: main-tspmv.hpp timestamp.hpp graph.hpp graph_impl.hpp ulib.h
mkl-tspmv.o: mmio.h
omp-spmm-vect.o: main-spmm.hpp timestamp.hpp graph.hpp graph_impl.hpp ulib.h
omp-spmm-vect.o: mmio.h
seq-tspmv.o: main-spmv.hpp timestamp.hpp graph.hpp graph_impl.hpp ulib.h
seq-tspmv.o: mmio.h
omp-tspmv-part.o: main-tspmv.hpp timestamp.hpp graph.hpp graph_impl.hpp
omp-tspmv-part.o: ulib.h mmio.h
omp-tspmv-part-static.o: main-tspmv.hpp timestamp.hpp graph.hpp
omp-tspmv-part-static.o: graph_impl.hpp ulib.h mmio.h
omp-tspmv-privatemem.o: main-tspmv.hpp timestamp.hpp graph.hpp graph_impl.hpp
omp-tspmv-privatemem.o: ulib.h mmio.h
omp-tspmv-atomics.o: main-tspmv.hpp timestamp.hpp graph.hpp graph_impl.hpp
omp-tspmv-atomics.o: ulib.h mmio.h
omp-tspmv-coloring.o: main-tspmv.hpp timestamp.hpp graph.hpp graph_impl.hpp
omp-tspmv-coloring.o: ulib.h mmio.h
omp-tspmv-blockcoloring.o: main-tspmv.hpp timestamp.hpp graph.hpp
omp-tspmv-blockcoloring.o: graph_impl.hpp ulib.h mmio.h
omp-tspmv-blockcutoffcoloring.o: main-tspmv.hpp timestamp.hpp graph.hpp
omp-tspmv-blockcutoffcoloring.o: graph_impl.hpp ulib.h mmio.h

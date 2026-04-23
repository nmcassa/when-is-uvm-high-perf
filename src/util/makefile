INCLUDES   = -I./

TARGET     =  graphshuffler plot rowdegree coldegree graphprop cache-friendliness block convertToDot graphGen vector_access spmv_access cacheline_density graph_part temporalize

CFILES       = ulib mmio

CXXFILES   = graphshuffler plot rowdegree coldegree graphprop cache-friendliness block  convertToDot graphGen vector_access spmv_access graph_part cacheline_density temporalize

SRCS	= $(CFILES:%=%.c) $(CXXFILES:%=%.cpp)

TBBLDFLAGS= -L /opt/intel/composerxe/tbb/lib/mic -ltbb 


all: $(TARGET)

temporalize: temporalize.o ulib.o mmio.o 
	$(LD) $(LDFLAGS) -o $@ mmio.o ulib.o temporalize.o $(LIBS) 

graphshuffler: graphshuffler.o ulib.o mmio.o 
	$(LD) $(LDFLAGS) -o $@ mmio.o ulib.o graphshuffler.o $(LIBS) 

graph_part: graph_part.o ulib.o mmio.o 
	$(LD) $(LDFLAGS) -o $@ mmio.o graph_part.o $(LIBS) 	

cacheline_density: cacheline_density.o ulib.o mmio.o 
	$(LD) $(LDFLAGS) -o $@ mmio.o cacheline_density.o $(LIBS) 	

graphGen: graphGen.o ulib.o mmio.o 
	$(LD) $(LDFLAGS) -o $@ mmio.o ulib.o graphGen.o $(LIBS) 

convertToBinary: convertToBinary.o ulib.o mmio.o 
	$(LD) $(LDFLAGS) -o $@ mmio.o ulib.o convertToBinary.o $(LIBS) 

convertToDot: convertToDot.o ulib.o mmio.o 
	$(LD) $(LDFLAGS) -o $@ mmio.o ulib.o convertToDot.o $(LIBS) 

rowdegree: rowdegree.o ulib.o mmio.o 
	$(LD) $(LDFLAGS) -o $@ mmio.o ulib.o rowdegree.o $(LIBS) 

graphprop: graphprop.o ulib.o mmio.o 
	$(LD) $(LDFLAGS) -o $@ mmio.o ulib.o graphprop.o $(LIBS) 

cache-friendliness: cache-friendliness.o ulib.o mmio.o 
	$(LD) $(LDFLAGS) -o $@ mmio.o ulib.o cache-friendliness.o $(LIBS) 

cache-block: cache-block.o ulib.o mmio.o 
	$(LD) $(LDFLAGS) -o $@ mmio.o ulib.o cache-block.o $(LIBS) 


vector_access: vector_access.o ulib.o 
	$(LD) $(LDFLAGS) -o $@ mmio.c ulib.o vector_access.o $(LIBS) 

spmv_access: spmv_access.o ulib.o 
	$(LD) $(LDFLAGS) -o $@ mmio.c ulib.o spmv_access.o $(LIBS) 

coldegree: coldegree.o ulib.o mmio.o 
	$(LD) $(LDFLAGS) -o $@ mmio.o ulib.o coldegree.o $(LIBS) 

block: block.o ulib.o mmio.o 
	$(LD) $(LDFLAGS) -o $@ mmio.o ulib.o block.o $(LIBS) 



plot: plot.o ulib.o mmio.o 
	$(LD) $(LDFLAGS) -o $@ mmio.o ulib.o plot.o $(LIBS) 



include makefile.in

PATOHDIR = $(HOME)/prgs/patoh-Linux-x86_64/Linux-x86_64/
CXXFLAGS += -I $(PATOHDIR)
#LIBS += $(PATOHDIR)/libpatoh.a

# DO NOT DELETE

ulib.o: ulib.h
mmio.o: mmio.h
graphshuffler.o: ulib.h graph.hpp graph_impl.hpp mmio.h graphshuffler.hpp
plot.o: graph.hpp graph_impl.hpp ulib.h mmio.h plot.hpp
rowdegree.o: graph.hpp graph_impl.hpp ulib.h mmio.h plot.hpp
coldegree.o: graph.hpp graph_impl.hpp ulib.h mmio.h plot.hpp
graphprop.o: graph.hpp graph_impl.hpp ulib.h mmio.h plot.hpp
cache-friendliness.o: timestamp.hpp graph.hpp graph_impl.hpp ulib.h mmio.h
block.o: graph.hpp graph_impl.hpp ulib.h mmio.h
convertToDot.o: ulib.h graph.hpp graph_impl.hpp mmio.h graphshuffler.hpp
graphGen.o: timestamp.hpp graph.hpp graph_impl.hpp ulib.h mmio.h
graph_part.o: ulib.h graph.hpp graph_impl.hpp mmio.h graph_part.hpp

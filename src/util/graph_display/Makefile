include Makefile.local

GTK_INCLUDE = `pkg-config --cflags gtk+-2.0` `pkg-config --cflags cairo`
GTK_LIB = `pkg-config --libs gtk+-2.0``pkg-config --libs cairo`


CC = gcc -g -Wall
CFLAGS += $(GTK_INCLUDE)
CXXFLAGS += $(GTK_INCLUDE) -std=gnu++0x
LDFLAGS += $(GTK_LIB) $(X11_LIB)

OBJS = main_gtk.o mmio.o ulib.o

CC=g++
LD=g++

CXXFLAGS+=-O3

all: main_gtk

main_gtk: $(OBJS)
	$(LD) $(GTK_LIB) $(X11_LIB) $(OBJS) -o main_gtk $(LDFLAGS)

clean:
	rm *.o *~


depend:
	makedepend *.cpp *.hpp -Y

# DO NOT DELETE

main_gtk.o: GraphDisplay.hpp taskinfo.hpp
GraphDisplay.o: taskinfo.hpp

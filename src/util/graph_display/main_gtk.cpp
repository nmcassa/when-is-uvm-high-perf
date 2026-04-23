#include <gtk/gtk.h>
#include <list>
#include "GraphDisplay.hpp"
#include <vector>
#include <iostream>
#include <fstream>
#include "graph.hpp"

void
destroy (void)
{
  gtk_main_quit ();
}


int
main (int argc, char *argv[])
{

  int nVtx;
  int nCol;

  int nEdge;
  int* xadj;
  int* adj;  

  double *elements;

  ReadGraph<int, int, double>(argv[1], &nVtx, &nCol, &xadj, &adj, &elements, NULL);

  Position<double>* pos = new Position<double>[nVtx];


  {
    std::ifstream posin (argv[2]);
    if (!posin.is_open()) {
      std::cerr<<"can not open position file: "<<argv[2]<<std::endl;
      return -1;
    }
    for (int u=0; u<nVtx; ++u) {
      posin>>pos[u].x>>pos[u].y;      
    }

    //normalize in [0:1]
    double minX = pos[0].x;
    double maxX = pos[0].x;
    double minY = pos[0].y;
    double maxY = pos[0].y;
    
    for (int u=0; u<nVtx; ++u) {
      minX = std::min(minX, pos[u].x);
      maxX = std::max(maxX, pos[u].x);

      minY = std::min(minY, pos[u].y);
      maxY = std::max(maxY, pos[u].y);
    }

    std::cout<<"minmax "<<minX<<" "<<maxX<<" "<<minY<<" "<<maxY<<std::endl;

    for (int u=0; u<nVtx; ++u) {
      pos[u].x -= minX;
      pos[u].x /= maxX-minX;

      pos[u].y -= minY;
      pos[u].y /= maxY-minY;
      //std::cout<<pos[u].x<<" "<<pos[u].y<<std::endl;
    }
  }
  
  int *partvec = NULL;

  if (getenv("PARTVEC"))
  {
    partvec = new int[nVtx];
    std::ifstream in (getenv("PARTVEC"));
    
    for (int i = 0; i<nVtx; ++i)
      in>>partvec[i];
    in.close();
  }
  

  int samp = 1;
  if (argc > 3)
    samp = atoi(argv[3]);

  gtk_init (&argc, &argv);
  GtkWidget *window;

  window = gtk_window_new (GTK_WINDOW_TOPLEVEL);

  g_set_application_name("gantt chart");

  gtk_signal_connect (GTK_OBJECT (window), "destroy",
		      GTK_SIGNAL_FUNC (destroy), NULL);
  gtk_container_border_width (GTK_CONTAINER (window), 10);


  GraphDisplay g (nVtx, xadj, adj, pos, samp, partvec);

  g_signal_connect (G_OBJECT (window), "key-press-event",
		    G_CALLBACK (GraphDisplay::key_press), &g);
  
  g_signal_connect (G_OBJECT (window), "button-press-event",
		    G_CALLBACK (GraphDisplay::button_press), &g);
  
  
  
  GTK_WIDGET_SET_FLAGS(window, GTK_CAN_FOCUS);
  gtk_widget_add_events (window, GDK_KEY_PRESS_MASK);
  gtk_widget_add_events (window, GDK_BUTTON_PRESS_MASK);



  g.show();

  gtk_container_add(GTK_CONTAINER(window), g.getWidget());
  gtk_widget_show (window);

  gtk_main ();

  return 0;
}


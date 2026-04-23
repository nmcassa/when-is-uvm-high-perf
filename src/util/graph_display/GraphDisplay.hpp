#ifndef __GRAPH_DISPLAY_H__
#define __GRAPH_DISPLAY_H__

#include <string>
#include <vector>
#include <iostream>
#include <sstream>
#include <cmath>
#include <gdk/gdkkeysyms.h>

#include "cairo.h"

#include <gtk/gtk.h>

template<typename Coord>
struct Position {
  Coord x;
  Coord y;
};


class GraphDisplay
{
private:
  GdkImage *im;
  GtkWidget *imWind;

  //window size
  int sizeX, sizeY;

  //position of the frame
  double frameXl, frameXh, frameYl, frameYh;

  //position of the pdfs' labels
  double nameFontsize, nameXoffset, nameXspacing, nameYoffset, nameYspacing;

  //colors
  cairo_pattern_t * bgcolor;
  cairo_pattern_t * fgcolor;

  cairo_pattern_t * colors[4];


  double xoffset;
  double yoffset;

  double interTaskSpace;
  double scale;

  //data
  int nVtx;
  int* xadj;
  int* adj;
  Position<double>* pos;
  int sampling;

  bool showedge;

  int* partvec;

  bool showlabel;
  int samplingoffset;

public:
  GtkWidget* getWidget()
  {
    return imWind;
  }

  GraphDisplay(int n, int* x, int* a, Position<double>* p, int sampl, int* pv)
    :nVtx(n), xadj(x), adj(a), pos(p), sampling(sampl), showedge(false), partvec(pv)
  {
    imWind = gtk_label_new("You should not see this message!");

    g_signal_connect (G_OBJECT (imWind), "expose_event",
		      G_CALLBACK (GraphDisplay::expose), this);

    scale = 1.;

    showlabel = false;
    xoffset = 0;
    yoffset = 0;

    interTaskSpace = 20;

    frameXl=.07;
    frameYl=.05;
    frameXh=.95;
    frameYh=.9;

    nameFontsize = 20;
    nameXoffset = .07;
    nameYoffset = 0.1;
    nameXspacing = 0;
    nameYspacing = .05; 
      
    bgcolor = cairo_pattern_create_rgb(1,1,1);
    fgcolor = cairo_pattern_create_rgb(0,0,0);

    colors[0]=cairo_pattern_create_rgb(0,0,0);
    colors[1]=cairo_pattern_create_rgb(1,0,0);
    colors[2]=cairo_pattern_create_rgb(0,1,0);
    colors[3]=cairo_pattern_create_rgb(0,0,1);

    samplingoffset = 0;
  }

  ~GraphDisplay()
  {
    cairo_pattern_destroy(bgcolor);
    cairo_pattern_destroy(fgcolor);

    cairo_pattern_destroy(colors[0]);   
    cairo_pattern_destroy(colors[1]);
    cairo_pattern_destroy(colors[2]);
    cairo_pattern_destroy(colors[3]);
  }

  void show()
  {
    gtk_widget_show (imWind);
    //    gtk_widget_show (drawing);
  }


  static gboolean
  key_press (GtkWidget *widget, GdkEventKey *event, gpointer data)
  {
    GraphDisplay* g = (GraphDisplay*)data;

    std::cout << event->keyval<<std::endl;

    switch(event->keyval)
      {
      case GDK_Up://top
	g->yoffset -= 1/(20*g->scale);
	break;
      case GDK_Left://left
	g->xoffset -= 1/(20*g->scale);
	break;
      case GDK_Right://right
	g->xoffset += 1/(20*g->scale);
	break;
      case GDK_Down://down
	g->yoffset += 1/(20*g->scale);
	break;
      case GDK_e://e 
      case GDK_E://e 
	g->showedge = ! g->showedge;
	break;

      case GDK_l://l 
      case GDK_L://l
	g->showlabel = ! g->showlabel;
	break;


      case GDK_S:
	g->sampling --;
	if (g->sampling<= 0)
	  {
	    g->sampling = 0;
	    g->samplingoffset = 0;
	  }
	else
	  g->samplingoffset %= g->sampling;
	std::cout<<"Sampling: "<<g->sampling<<std::endl;
	break;

      case GDK_Tab:
	if (g->sampling > 0)
	  g->samplingoffset = g->samplingoffset + 1 % g->sampling;
	break;

      case GDK_s:
	g->sampling ++;
	std::cout<<"Sampling: "<<g->sampling<<std::endl;
	break;
	
      case GDK_KP_Subtract:
	g->scale /= 1.1;
	g->xoffset /= 1.1;
	g->yoffset /= 1.1;
	break;
      case GDK_KP_Add:
	g->scale *= 1.1;	
	g->xoffset *= 1.1;
	g->yoffset *= 1.1;
	break;
      default:
	break;
      }

    std::cout<<g->xoffset<<" "<<g->yoffset<<" "<<g->scale<<std::endl;

    gtk_widget_queue_draw (g->getWidget());

    return TRUE;

  }

  static gboolean
  button_press (GtkWidget *widget, GdkEventButton *event, gpointer data)
  {
    GraphDisplay* g = (GraphDisplay*)data;

    std::cout<<"button press event"<<std::endl;

    gtk_widget_grab_focus(widget);

    return TRUE;

  }


  static gboolean
  expose (GtkWidget *widget, GdkEventExpose *event, gpointer data)
  {
    GraphDisplay* g = (GraphDisplay*)data;

    cairo_t *cr;
    /* get a cairo_t */  

    cr = gdk_cairo_create (g->imWind->window);
    
    /* set a clip region for the expose event */
    cairo_rectangle (cr,
 		     event->area.x, event->area.y,
 		     event->area.width, event->area.height);
    cairo_clip (cr);
    
    cairo_translate(cr, g->imWind->allocation.x, g->imWind->allocation.y);

    g->sizeX = g->imWind->allocation.width;
    g->sizeY = g->imWind->allocation.height;

    //    cairo_scale (cr, 1./g->sizeX, 1./g->sizeY);
    cairo_scale (cr, g->sizeX, g->sizeY);
    cairo_scale (cr, g->scale, g->scale);

    g->render(cr);
    cairo_destroy (cr);
    return TRUE;
  }

  // void scaled_stroke(cairo_t *cr)
  // {
  //   double xwise = 1;
  //   double ywise = 1;
  //   cairo_save(cr);
  //   cairo_device_to_user_distance (cr,&xwise,&ywise);
    
  //   cairo_scale(cr,xwise,ywise);
  //   cairo_stroke(cr);
  //   cairo_restore(cr);
  // }


  void scaled_show_text (cairo_t *cr, const std::string &s)
  {
    double xwise = 1;
    double ywise = 1;
    cairo_save(cr);
    cairo_device_to_user_distance (cr,&xwise,&ywise);
    
    cairo_scale(cr,xwise,ywise);
    cairo_show_text (cr, s.c_str() );
    cairo_restore(cr);
  }


  void render(cairo_t* cr)
  { 
    //paint background
    cairo_set_source(cr, bgcolor);
    cairo_paint(cr);

    cairo_set_source(cr, fgcolor);
    
    cairo_translate(cr, -xoffset, -yoffset);


    int drawn = 0;

    for (int u=0; u<nVtx; ++u)
      {
	if (pos[u].x < xoffset) continue;
	if (pos[u].y < yoffset) continue;
	if (sampling > 0)
	  if (u % sampling != samplingoffset) continue;
	drawn++;
	//draw vertex
	{
	  cairo_set_line_width(cr, .005/scale);
	  double radius = .00001/scale;
	  // cairo_save(cr);

	  // cairo_translate(cr, pos[u].x, pos[u].y);
	  // cairo_scale(cr, radius, radius);
	  // cairo_arc(cr, 0.0, 0.0, 1.0, 0.0, 2 * M_PI);
	  // //	  cairo_fill(cr);
	  // cairo_stroke(cr);
	  // cairo_restore(cr);
	  cairo_rectangle(cr,
			  pos[u].x-radius, pos[u].y-radius, 
			  2*radius, 2*radius);
	  cairo_stroke (cr);	  
	}

	if (showlabel)
	{
	  std::stringstream ss;
	  ss<<u;
	  if (partvec)
	    ss<<" ("<<partvec[u]<<")";
	  cairo_move_to (cr, pos[u].x, pos[u].y);
	  scaled_show_text (cr, ss.str());
	}

	//draw edges
	if (showedge)
	{
	  cairo_save(cr);
	  cairo_set_line_width(cr, .001);
	  for (int p=xadj[u]; p != xadj[u+1]; ++p) {
	    int v = adj[p];
	    if (sampling > 0)
	      if (v % sampling != samplingoffset) continue;
	    cairo_move_to (cr, pos[u].x, pos[u].y);
	    cairo_line_to (cr, pos[v].x, pos[v].y);
	    cairo_stroke(cr);
	  }
	  cairo_restore(cr);
	}
      }
    std::cout<<"drawn: "<<drawn<<std::endl;
  }

};

#endif

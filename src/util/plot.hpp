#ifndef PLOT_HPP_
#define PLOT_HPP_

#include <iostream>
#include <fstream>

template<typename VertexType, typename EdgeType, typename Scalar>
void plot (int ImgSizeX, int ImgSizeY,
	   VertexType MatSizeX, VertexType MatSizeY, EdgeType*xadj, VertexType *adj,
	   std::string filenamebase) //.pgm added to the filename
{
  //prepare data structure
  int **occur = new int*[ImgSizeX];
  for (int i=0;i<ImgSizeX; ++i) {
    occur[i] = new int[ImgSizeY];
    for (int j=0; j<ImgSizeY; ++j)
      occur[i][j] = 0;
  }

  
  //granularity of the decomposition
  float nbelemperpixelX=(float)MatSizeX/ImgSizeX;
  float nbelemperpixelY=(float)MatSizeY/ImgSizeY;

  for (VertexType x = 0; x< MatSizeX; ++x) {
    int xloc = x/nbelemperpixelX;
    assert (xloc >=0);
    assert (xloc < ImgSizeX);
    
    VertexType* beg = adj+xadj[x];
    VertexType* end = adj+xadj[x+1];
    for (auto p = beg; p < end; ++p)
      {
	VertexType y = *p;

	int yloc = y/nbelemperpixelY;
	assert (yloc >=0);
	assert (yloc < ImgSizeY);
	
	++occur[xloc][yloc];
      }
  }

  //output pgm file
  std::stringstream ss ;
  ss<<filenamebase<<".pgm";
  std::ofstream output(ss.str());
  if (!output) {
    std::cerr<<"can not open output image file : "<<ss.str()<<std::endl;
    return;
  }
  
  output<<"P2\n";
  output<<ImgSizeX<<" "<<ImgSizeY<<"\n";
  output<<"255\n";
  
  for (int i=0;i<ImgSizeX; ++i)
    for (int j=0; j<ImgSizeY; ++j) {
      float density=((float)(occur[i][j]))/((float)nbelemperpixelX*nbelemperpixelY);
      if (density > 1) //because of floating point approximation of the size of a block, the density might be actually over 1.
	density = 1;
      assert (density >= 0);
      assert (density <= 1);
      output<<(int)(128*(1-density))+(density != 0?0:127)<<"\n";
    }
  output<<std::flush;


  for (int i=0; i<ImgSizeX; ++i) {
    delete[] occur[i];
  }
  delete[] occur;

}

#endif

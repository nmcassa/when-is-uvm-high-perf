#ifndef BITARRAY_H__
#define BITARRAY_H__

class bitarrayinbits
{
  int actsize;
  char* data;
public:
  bitarrayinbits(int size)
    :actsize(size/8 + (size%8 !=0)), data( new char[actsize])
  {
    assert (data != NULL);
  }

  ~bitarrayinbits()
  {
    delete[] data;
  }

  inline void clearall()
  {
    memset(data, 0, actsize);
  }

  inline bool get(int i) const
  {
    return data[i/8] & (1<<(i%8));
  }

  inline void set(int i)
  {
    data[i/8] |= (1<<(i%8));
  }

  inline void clear(int i)
  {
    data[i/8] &= ~(1 <<(i%8));
  }

  inline bool operator[] (int i) const
  {
    return get(i);
  }

};

class bitarrayinbytes
{
  int actsize;
  bool* data;
public:
  bitarrayinbytes(int size)
    :actsize(size), data( new bool[actsize])
  {
    assert (data != NULL);
  }

  ~bitarrayinbytes()
  {
    delete[] data;
  }

  inline void clearall()
  {
    for (int i=0 ; i< actsize; i++)
      data[i] = false;
  }

  inline bool get(int i) const
  {
    assert (i < actsize);
    return data[i];
  }

  inline void set(int i)
  {
    assert (i < actsize);
    data[i] = true;
  }

  inline void clear(int i)
  {
    assert (i < actsize);
    data[i] = false;
  }

  inline bool operator[] (int i) const
  {
    return get(i);
  }

};


#endif

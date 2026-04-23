#ifndef CACHE_SIM_HPP
#define CACHE_SIM_HPP

#include <sstream>
#include <algorithm>

#include <list>

class CacheSimulator {
public:
  typedef unsigned long int u64;
private:

  u64 miss;
  u64 access;

  std::list<u64> LRUorder;

  u64 CACHELINE;
  u64 cache_capacity;
  unsigned int cache_capacity_in_lines;

public:
  CacheSimulator (u64 CACHELINE, u64 cache_capacity)
    :CACHELINE(CACHELINE), cache_capacity(cache_capacity)
  {
    miss = 0;
    access = 0;
    cache_capacity_in_lines = cache_capacity / CACHELINE;
    
  }

  u64 getMiss() const{return miss;}
  u64 getAccess() const {return access;}
  double getMissRatio() const {return ((double)(miss))/access;}
  double getHitRatio() const {return 1-getMissRatio();}

  void touch(size_t address) {
    access++;

    u64 block = address / CACHELINE;
    
    auto it = std::find (LRUorder.begin(), LRUorder.end(), block);
    if (it == LRUorder.end())
      {
	//not found
	miss++;
	LRUorder.push_back(block);
	if (LRUorder.size() > cache_capacity_in_lines)
	  {
	    LRUorder.pop_front();
	  }
      }
    else
      {
	//it is there, put it on the front.
	LRUorder.erase(it);
	LRUorder.push_back(block);
      }  
    
  }
};

#include <map>
#include <unordered_map>

class CacheSimulatorFast {
public:
  typedef unsigned long int u64;
private:


  std::list<u64> LRUorder;

  u64 CACHELINE;
  u64 cache_capacity;
  unsigned int cache_capacity_in_lines;

  std::unordered_map<u64, std::list<u64>::iterator> where_in_lru_list;

  u64 miss;
  u64 access;

public:
  //param: CACHELINE: size of a cacheline (in bytes)
  //param cache_capacity: size of the entire cache (in bytes)
  CacheSimulatorFast (u64 CACHELINE, u64 cache_capacity)
    :CACHELINE(CACHELINE), cache_capacity(cache_capacity), cache_capacity_in_lines (cache_capacity / CACHELINE),
     where_in_lru_list(cache_capacity_in_lines),
     miss(0), access(0)
  {
   
  }

  //return: how many miss
  u64 getMiss() const{return miss;}
  //return: how many access
  u64 getAccess() const {return access;}
  //return: missratio
  double getMissRatio() const {return ((double)(miss))/access;}
  //return: hitratio
  double getHitRatio() const {return 1-getMissRatio();}

  void touch(size_t address) {
    access++;

    u64 block = address / CACHELINE;
    
    auto it = where_in_lru_list.find(block);
    if (it == where_in_lru_list.end())
      {
	//not found
	miss++;
	auto it2 = LRUorder.insert(LRUorder.end(), block);
	where_in_lru_list[block] = it2;
	if (LRUorder.size() > cache_capacity_in_lines)
	  {
	    auto it3 = LRUorder.begin();
	    where_in_lru_list.erase(*it3);
	    LRUorder.erase(it3);
	  }
      }
    else
      {
	//it is there, put it on the front.
	LRUorder.erase(it->second);
	auto it2 = LRUorder.insert(LRUorder.end(), block);
	where_in_lru_list[block] = it2;
      }  
    
  }
};


#endif

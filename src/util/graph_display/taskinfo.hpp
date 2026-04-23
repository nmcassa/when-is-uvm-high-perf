#ifndef __TASK_INFO_H__
#define __TASK_INFO_H__

typedef long timetype;

struct taskinfo
{
  int id;
  timetype release;
  timetype completion;
  timetype start;
  int m;
  timetype p1;
};

#endif

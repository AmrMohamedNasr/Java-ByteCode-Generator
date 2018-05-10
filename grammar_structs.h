#ifndef HEADER_GRM_STRCT_FILE
#define HEADER_GRM_STRCT_FILE

#include "types.h"
/** Declare structs needed as types **/
typedef struct {
    vector<string *> *code;
    vector<string *> *next;
  } Basic_nt;
typedef struct {
  TYPE type;
  vector<string *> *code;
} A_exp_nt;
typedef struct {
  TYPE type;
  vector<string *> *code;
  vector<string *> *next;
} B_exp_nt;
typedef struct {
  uint before_block_mem;
  vector<string *> *code;
  vector<string *> *next;
} Block_nt;
/** END OF STRUCTS **/
#endif
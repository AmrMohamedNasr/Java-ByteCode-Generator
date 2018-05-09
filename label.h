#ifndef HEADER_LABEL_FILE
#define HEADER_LABEL_FILE

#include <string>
#include "java.h"

using namespace std;

class label {
  private:
    string label_name;
  public:
  	static uint label_num;
    static char label_char;
    label();
    string get_name();
};

#endif
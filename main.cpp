/* main.cpp */

#include "java.h"

// prototype of bison-generated parser function
extern "C" FILE *yyin;
extern "C" int yyparse();

int main(int, char**) {
  // open a file handle to a particular file:
  FILE *myfile = fopen("test.java", "r");
  // make sure it's valid:
  if (!myfile) {
    cout << "I can't open a java file!" << endl;
    return -1;
  }
  // set lex to read from it instead of defaulting to STDIN:
  yyin = myfile;

  // parse through the input until there is no more:
  
  do {
    yyparse();
  } while (!feof(yyin));
  
}

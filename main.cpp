/* main.cpp */

#include "java.h"

// prototype of bison-generated parser function
extern "C" FILE *yyin;
extern "C" int yyparse();
extern "C++" ofstream *parserOut;

int main(int, char**) {
  // open a file handle to a particular file:
  cout << "Enter your input file : " << endl;
  string in,out;
  cin >> in;
  cout << "Enter your output file : " << endl;
  cin >> out;
  FILE *myfile = fopen(in.c_str(), "r");
  // make sure it's valid:
  if (!myfile) {
    cout << "I can't open the input file!" << endl;
    return -1;
  }
  ofstream myfile2;
  myfile2.open (out);
  if (!myfile2.is_open()) {
  	cout << "I can't open the output file!" << endl;
    return -1;
  }

  // set lex to read from it instead of defaulting to STDIN:
  yyin = myfile;
  parserOut = &myfile2;
  // parse through the input until there is no more:
  
  do {
    yyparse();
  } while (!feof(yyin));
  myfile2.close();
  return 0;
}

/* main.cpp */

#include "java.h"

// prototype of bison-generated parser function
extern "C" FILE *yyin;
extern "C" int yyparse();
extern "C++" ofstream *parserOut;
extern "C++" bool error_flag;

int main(int, char**) {
  // open a file handle to a particular file:
  cout << "Enter your input file name : " << endl;
  string in, out;
  cin >> in;
  cout << "Generate for jasmin (y/n) : " << endl;
  cin >> out;
  bool print_jasmin = out == "y";
  size_t found = in.find_last_of(".");
  string classname = in.substr(0, found);
  out =  classname + ".j";
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
  if (print_jasmin) {
    myfile2 << ".class public " + classname + "\n.super java/lang/Object\n"
    + "; default constructor\n.method public <init>()V\naload_0 ; push this"
    + "\ninvokespecial java/lang/Object/<init>()V ; call super\nreturn\n.end"
    + " method\n.method public static main([Ljava/lang/String;)V\n.limit locals 1000\n.limit stack 1000" << endl;
  }
  // set lex to read from it instead of defaulting to STDIN:
  yyin = myfile;
  parserOut = &myfile2;
  // parse through the input until there is no more:
  
  do {
    yyparse();
  } while (!feof(yyin));
  
  if (print_jasmin) {
    myfile2 << "return\n.end method" << endl;
  }
  myfile2.close();
  if (!error_flag && print_jasmin) {
    system(("java -jar jasmin.jar " + out).c_str());
  } else if (error_flag) {
    remove(out.c_str());
  }
  return 0;
}

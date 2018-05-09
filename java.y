%{
#include "java.h"
// stuff from flex that bison needs to know about:
extern "C" int yylex();
extern "C" int yyparse();

extern int line_num;
 
void yyerror(const string);
%}

// Bison fundamentally works by asking flex to get the next token, which it
// returns as an object of type "yystype".  But tokens could be of any
// arbitrary data type!  So we deal with that in Bison by defining a C union
// holding each of the types of tokens that Flex could return, and have Bison
// use that union instead of "int" for the definition of "yystype":
%union {
  int ival;
  float fval;
  char cval;
  string *sval;
}

// define the constant-string tokens:
%token KIF
%token KELSE
%token KFOR
%token KWHILE
%token VTRUE
%token VFALSE
%token TFLOAT
%token TINT
%token TBOOLEAN
%token BNOT
%token BAND
%token BOR
%token ASSIGN
%token SEMICOL
%token LPAR
%token RPAR
%token LCB
%token RCB

// define the "terminal symbol" token types I'm going to use (in CAPS
// by convention), and associate each with a field of the union:
%token <ival> VINT
%token <fval> VFLOAT
%token <sval> ID
%token <sval> RELOP
%token <cval> ADDOP
%token <cval> MULOP

%%
// the first rule defined is the highest-level rule, which in our
// case is just the concept of a whole "snazzle file":

%%

void yyerror(const string s) {
  cout << "Parse error on line " << line_num << "!  Message: " << s << endl;
  // might as well halt now:
  exit(-1);
}
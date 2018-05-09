%{
#include "java.h"
// stuff from flex that bison needs to know about:
extern "C" int yylex();
extern "C" int yyparse();

extern int line_num;

uint symbol_mem = 1;
uint label::label_num = 0;
char label::label_char = 'a';

unordered_map<string, pair<uint, TYPE>> symbol_table;
unordered_map<uint, string *> memory_table;

void back_patch(vector<string *> *list, string m);
void add_to_list(vector<string *> *dest, initializer_list<vector<string *> *> list);
void clear_scope(uint before_scope_mem, uint after_scope_mem);
void add_entry(string *s, uint mem_place, TYPE type);
bool hasId(string s);
TYPE getType(string s);
uint getMemoryPlace(string s);

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
  struct {
    vector<string *> *code;
    vector<string *> *next;
  } basic_nt;
  struct {
    TYPE type;
  } type_nt;
  struct {
    TYPE type;
    vector<string *> *code;
  } a_exp_nt;
  struct {
    TYPE type;
    vector<string *> *code;
    vector<string *> *next;
  } b_exp_nt;
  struct {
    uint before_block_mem;
    vector<string *> *code;
    vector<string *> *next;
  } block_nt;
  struct {
    bool neg;
  } sign_nt;
}

// define the constant-string terminal tokens:
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

// define the non-terminal tokens.
%type <basic_nt> METHOD_BODY
%type <basic_nt> STATEMENT_LIST
%type <basic_nt> STATEMENT
%type <basic_nt> DECLARTION
%type <basic_nt> IF
%type <basic_nt> WHILE
%type <basic_nt> ASSIGNMENT
%type <basic_nt> FOR
%type <type_nt> PRIMITY_TYPE
%type <block_nt> BLOCK
%type <basic_nt> BOOLEAN_CONDITION
%type <basic_nt> ASSIGNMENT_OPTIONAL
%type <basic_nt> BOOLEAN_CONDITION_OPTIONAL
%type <a_exp_nt> FACTOR
%type <sign_nt> SIGN
%left <a_exp_nt> TERM
%left <a_exp_nt> SIMPLE_EXPRESSION
%left <a_exp_nt> EXPRESSION
%left <a_exp_nt> BTERM
%left <b_exp_nt> BSIMPLE_EXPRESSION
%left <b_exp_nt> BOOLEAN_EXPRESSION

%%
// the first rule defined is the highest-level rule, which in our
// case is just the concept of a whole "snazzle file":
METHOD_BODY:
  VINT
%%

void yyerror(const string s) {
  cout << "Parse error on line " << line_num << "!  Message: " << s << endl;
  // might as well halt now:
  exit(-1);
}
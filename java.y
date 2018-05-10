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
bool need_label(vector<string *> *list);
void add_to_list(vector<string *> *dest, initializer_list<vector<string *> *> list);
void clear_scope(uint before_scope_mem);
void add_entry(string *s, TYPE type);
bool hasId(string s);
TYPE getType(string s);
uint getMemoryPlace(string s);
void print_code(vector<string *> * code);
void perform_label_adding(vector<string *> *code, vector<string *> *next);
void add_label_to_code(vector<string *> *code, label x)

void yyerror(const string);

/** Maps used for quick code generation **/

unordered_map<TYPE, string> type_map = {
  pair<TYPE, string>(TYPE::INT, "i"), pair<TYPE, string>(TYPE::BOOL, "i"), pair<TYPE, string>(TYPE::FLOAT, "f")
};

unordered_map<TYPE, string> type_tostr_map = {
  pair<TYPE, string>(TYPE::INT, "integer"), pair<TYPE, string>(TYPE::BOOL, "boolean"), pair<TYPE, string>(TYPE::FLOAT, "float")
};

/** END OF MAPS **/
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
  TYPE type_nt;
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
  bool neg;
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
%type <neg> SIGN
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
  STATEMENT_LIST
  {
    $$.code = $1.code;
    perform_label_adding($$.code, $1.next);
    clear_scope(1);
    print_code($$.code);
  };

STATEMENT_LIST:
  STATEMENT
  {
    $$.code = $1.code;
    $$.next = $1.next;
  }
  |

  STATEMENT_LIST
  STATEMENT
  {
    $$.next = $2.next;
    $$.code = new vector<string *>();
    add_to_list($$.code, {$1.code});
    perform_label_adding($$.code, $1.next);
    add_to_list($$.code,{$2.code});
  };
BLOCK:
  {$<block_nt>$.before_block_mem = symbol_mem}
  LCB
  STATEMENT_LIST
  RCB
  {
    clear_scope($$.before_block_mem);
    $$.next = $3.next;
    $$.code = $3.code;
  };
STATEMENT:
  DECLARTION {$$.code = $1.code;$$.next = $1.next;}
  |
  IF {$$.code = $1.code;$$.next = $1.next}
  |
  WHILE {$$.code = $1.code;$$.next = $1.next}
  |
  ASSIGNMENT {$$.code = $1.code;$$.next = $1.next}
  |
  FOR {$$.code = $1.code;$$.next = $1.next};
DECLARTION:
  PRIMITY_TYPE
  ID
  SEMICOL
  {
    if (hasId(*($2))) {
      yyerror("Variable " + (*$2) + " is already defined for this scope");
    } else {
      add_entry($2, $1);
      $$.code = new vector<string *>();
      string k = type_map[$1];
      $$.code->push_back(new string(k + "const_0"));
      $$.code->push_back(new string(k + "store " + to_string(getMemoryPlace(*$2))));
    }
  };
PRIMITY_TYPE:
  TINT {$$ = TYPE::INT;}
  |
  TFLOAT {$$ = TYPE::FLOAT;}
  |
  TBOOLEAN {$$ = TYPE::BOOL;};
WHILE:
  KWHILE
  LPAR
  BOOLEAN_CONDITION
  RPAR
  BLOCK
  {
    label begin;
    $$.code = new vector<string *>();
    back_patch($5.next, begin.get_name());
    $$.next = $3.next;
    add_label_to_code($$.code, begin);
    add_to_list($$.code, {$3.code, $5.code});
    $$.code.push_back(new String("goto " + begin.get_name()));
  };
IF:
  KIF
  LPAR
  BOOLEAN_CONDITION
  RPAR
  BLOCK
  KELSE
  BLOCK
  {
    label y;
    back_patch($3.next, y.get_name());
    $$.next = new vector<string *>();
    add_to_list($$.next, {$5.next, $7.next});
    string * s = new string("goto ");
    $$.next->push_back(s);
    $$.code = new vector<string *>();
    add_to_list($$.code, {$3.code, $5.code});
    $$.code->push_back(s);
    add_label_to_code($$.code, y);
    add_to_list($$.code, {$7.code});
  };
ASSIGNMENT:
  ID
  ASSIGN
  BOOLEAN_EXPRESSION
  SEMICOL
  {
    if (hasId(*$1)) {
      if ($3.type != TYPE::ERROR) {
        TYPE idt = getType(*$1);
        uint mem = getMemoryPlace(*$1);
        bool can_assign = false;
        bool need_cast = false;
        if (idt == $3.type) {
          can_assign = true;
        } else {
          if (idt == TYPE::FLOAT && $3.type == TYPE::INT) {
            can_assign =true;
            need_cast = true;
          }
        }
        if (can_assign) {
          $$.code = new vector<string *>();
          add_to_list($$.code, {$3.code});
          perform_label_adding($$.code, $3.next);
          if (need_cast) {
            string * s = new string("i2f");
            $$.code->push_back(s);
          }
          $$.code->push_back(new string(type_map[idt] + "store " + to_string(mem)));
        } else {
          yyerror("Cannot cast from " +   + " to " + );
        }
      }
    } else {
      yyerror("Identifier " + *$1 + " has not been declared");
    }
    delete $1;
  };
BOOLEAN_CONDITION:
  BOOLEAN_EXPRESSION
  {
    if ($1.type != TYPE::ERROR) {
      if ($1.type != TYPE::BOOL) {
        yyerror("Condition doesn't evaluate to boolean");
      } else {
        $$.next = new vector<string*>();
        $$.code = new vector<string*>();
        add_to_list($$.code, {$1.code});
        string * s = new string("ifeq ");
        $$.next->push_back(s);
        add_to_list($$.code, $1.code);
        perform_label_adding($$.code, $1.next);
        $$.code->push_back(s);
      }
    }
  };
ASSIGNMENT_OPTIONAL:
  %empty
  |
  ID
  ASSIGN
  BOOLEAN_EXPRESSION
  {
    if (hasId(*$1)) {
      if ($3.type != TYPE::ERROR) {
        TYPE idt = getType(*$1);
        uint mem = getMemoryPlace(*$1);
        bool can_assign = false;
        bool need_cast = false;
        if (idt == $3.type) {
          can_assign = true;
        } else {
          if (idt == TYPE::FLOAT && $3.type == TYPE::INT) {
            can_assign =true;
            need_cast = true;
          }
        }
        if (can_assign) {
          $$.code = new vector<string *>();
          add_to_list($$.code, {$3.code});
          perform_label_adding($$.code, $3.next);
          if (need_cast) {
            string * s = new string("i2f");
            $$.code->push_back(s);
          }
          $$.code->push_back(new string(type_map[idt] + "store " + to_string(mem)));
        } else {
          yyerror("Cannot cast from " +  type_tostr_map[$3.type] + " to " + type_tostr_map[idt]);
        }
      }
    } else {
      yyerror("Identifier " + *$1 + " has not been declared");
    }
    delete $1;
  };
BOOLEAN_CONDITION_OPTIONAL:
  %empty
  |
  BOOLEAN_CONDITION
  {
    $$.code = $1.code;
    $$.next = $1.next;
  };
FOR:
  KFOR
  LPAR
  ASSIGNMENT_OPTIONAL
  SEMICOL
  BOOLEAN_CONDITION_OPTIONAL
  SEMICOL
  ASSIGNMENT_OPTIONAL
  RPAR
  BLOCK
  {
    label begin;
    $$.code = new vector<string *>();
    $$.next = $5.next;
    add_to_list($$.code, {$3.code});
    add_label_to_code($$.code, begin);
    add_to_list($$.code, {$5.code, $9.code});
    perform_label_adding($$.code, $9.next);
    add_to_list($$.code, {$7.code});
    string *s = new string("goto " + begin.get_name());
    $$.code->push_back(s);
  };
SIGN:
  ADDOP
  {
    $$ = $1 == '-';
  };
FACTOR:
  ID
  {
    if(hasId(*$1)) {
      $$.type = getType(*$1);
      uint mem = getMemoryPlace(*$1);
      $$.code = new vector<string *>();
      string *s = new string(type_map[$$.type] + "load " + to_string(mem));
      $$.code->push_back(s);
    } else {
      $$.type = TYPE::ERROR;
      yyerror("Undeclared Variable " + *$1 + " in this scope");
    }
    delete $1;
  }
  |
  VFLOAT
  {
    $$.code = new vector<string *>();
    $$.type = TYPE::FLOAT;
    string *s = new string("ldc " + to_string($1));
    $$.code->push_back(s);
  }
  |
  VINT
  {
    $$.code = new vector<string *>();
    $$.type = TYPE::INT;
    string *s = new string("ldc " + to_string($1));
    $$.code->push_back(s);
  }
  |
  VTRUE
  {
    $$.code = new vector<string *>();
    $$.type = TYPE::BOOL;
    string *s = new string("iconst_1");
    $$.code->push_back(s);
  }
  |
  VFALSE
  {
    $$.code = new vector<string *>();
    $$.type = TYPE::BOOL;
    string *s = new string("iconst_0");
    $$.code->push_back(s);
  }
  |
  LPAR
  BOOLEAN_EXPRESSION
  RPAR
  {
    $$.type = $2.type;
    $$.code = $2.code;
    perform_label_adding($$.code, $2.next);
  };
TERM:
  FACTOR {$$.code = $1.code;$$.type=$1.type;}
  |
  TERM
  MULOP
  FACTOR
  {

  };
%%

void yyerror(const string s) {
  cout << "Parse error on line " << line_num << "!  Message: " << s << endl;
  // might as well halt now:
  exit(-1);
}

void back_patch(vector<string *> *list, string m) {
  if (list != nullptr) {
    for (unsigned i = 0; i < list->size(); i++) {
      (*((*list)[i])) += m;
    }
    list = nullptr;
  }
}

void add_to_list(vector<string *> *dest, initializer_list<vector<string *> *> list) {
  if (dest == nullptr) {
    return;
  } else {
    for (auto i : list) {
      if (i != nullptr) {
        dest->insert(end(*dest), begin(*i), end(*i));  
      }
    }
  }
}
void clear_scope(uint before_scope_mem) {
  while (symbol_mem > before_scope_mem) {
    symbol_mem--;
    string * s = memory_table[symbol_mem];
    symbol_table.erase(symbol_table.find(*s));
    memory_table.erase(memory_table.find(symbol_mem));
    delete s;
  }
}
void add_entry(string *s,  TYPE type) {
  if (!hasId(*s)) {
    symbol_table[*s] = pair<uint, TYPE>(symbol_mem, type);
    memory_table[symbol_mem] = s;
    symbol_mem++;
  }
}
bool hasId(string s) {
  return symbol_table.find(s) != symbol_table.end();
}
TYPE getType(string s) {
  if (hasId(s)) {
    return symbol_table[s].second;
  } else {
    return TYPE::ERROR;
  }
}
uint getMemoryPlace(string s) {
  if (hasId(s)) {
    return symbol_table[s].first;
  } else {
    return UINT_MAX;
  }
}

void print_code(vector<string *> * code) {
  if (code == nullptr) {
    return;
  } else {
    for (unsigned i = 0; i < code->size(); i++) {
      cout << (*((*code)[i])) << endl;
    }
  }
}

bool need_label(vector<string *> *list) {
  if (list == nullptr || list->empty()) {
    return false;
  } else {
    return true;
  }
}

void perform_label_adding(vector<string *> *code, vector<string *> *next) {
  if (need_label(next)) {
      label x;
      back_patch(next, x.get_name());
      add_label_to_code(code, x);
    }
}

void add_label_to_code(vector<string *> *code, label x) {
  string *s = new string(x.get_name());
  *s += ":";
  code->push_back(s);
}
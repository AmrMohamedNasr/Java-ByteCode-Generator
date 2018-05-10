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

void back_patch(vector<string *> **list, string m);
bool need_label(vector<string *> *list);
void add_to_list(vector<string *> *dest, initializer_list<vector<string *> *> list);
void clear_scope(uint before_scope_mem);
void add_entry(string *s, TYPE type);
bool hasId(string s);
TYPE getType(string s);
uint getMemoryPlace(string s);
void print_code(vector<string *> * code);
void perform_label_adding(vector<string *> *code, vector<string *> **next);
void add_label_to_code(vector<string *> *code, label x);
void process_assignment(string id, Basic_nt * par, B_exp_nt * bexp);
void process_arith_op(A_exp_nt * par, A_exp_nt * a, char op, A_exp_nt *b);

void yyerror(const string);

/** Maps used for quick code generation **/

unordered_map<TYPE, string> type_map = {
  pair<TYPE, string>(TYPE::INT, "i"), pair<TYPE, string>(TYPE::BOOL, "i"), pair<TYPE, string>(TYPE::FLOAT, "f")
};

unordered_map<TYPE, string> type_tostr_map = {
  pair<TYPE, string>(TYPE::INT, "integer"), pair<TYPE, string>(TYPE::BOOL, "boolean"), pair<TYPE, string>(TYPE::FLOAT, "float")
};

unordered_map<char, string> op_map = {
  pair<char,string>('+', "add"),
  pair<char,string>('-', "sub"),
  pair<char,string>('*', "mul"),
  pair<char,string>('/', "div")
};

unordered_map<string, string> real_ops = {
  pair<string,string>("==", "eq"),
  pair<string,string>(">=", "ge"),
  pair<string,string>(">", "gt"),
  pair<string,string>("<=", "le"),
  pair<string,string>("<", "lt"),
  pair<string,string>("!=", "ne")
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
  TYPE type_nt;
  bool neg;
  Basic_nt basic_nt;
  A_exp_nt a_exp_nt;
  B_exp_nt b_exp_nt;
  Block_nt block_nt;
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
%type <a_exp_nt> TERM
%type <a_exp_nt> SIMPLE_EXPRESSION
%type <a_exp_nt> EXPRESSION
%type <a_exp_nt> BTERM
%type <b_exp_nt> BSIMPLE_EXPRESSION
%type <b_exp_nt> BOOLEAN_EXPRESSION

%%
// the first rule defined is the highest-level rule, which in our
// case is just the concept of a whole "snazzle file":
METHOD_BODY:
  STATEMENT_LIST
  {
    $$.code = $1.code;
    perform_label_adding($$.code, &$1.next);
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
    perform_label_adding($$.code, &$1.next);
    add_to_list($$.code,{$2.code});
  };
BLOCK:
  {$<block_nt>$.before_block_mem = symbol_mem;}
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
  IF {$$.code = $1.code;$$.next = $1.next;}
  |
  WHILE {$$.code = $1.code;$$.next = $1.next;}
  |
  ASSIGNMENT {$$.code = $1.code;$$.next = $1.next;}
  |
  FOR {$$.code = $1.code;$$.next = $1.next;};
DECLARTION:
  PRIMITY_TYPE
  ID
  SEMICOL
  {
    if (hasId(*($2))) {
      $$.code = nullptr;
      $$.next = nullptr;
      yyerror("Variable " + (*$2) + " is already defined for this scope");
    } else {
      $$.next = nullptr;
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
    back_patch(&$5.next, begin.get_name());
    $$.next = $3.next;
    add_label_to_code($$.code, begin);
    add_to_list($$.code, {$3.code, $5.code});
    $$.code->push_back(new string("goto " + begin.get_name()));
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
    back_patch(&$3.next, y.get_name());
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
    process_assignment(*$1, &$$, &$3);
    delete $1;
  };
BOOLEAN_CONDITION:
  BOOLEAN_EXPRESSION
  {
    if ($1.type != TYPE::ERROR) {
      if ($1.type != TYPE::BOOL) {
        $$.code = nullptr;
        $$.next = nullptr;
        yyerror("Condition doesn't evaluate to boolean");
      } else {
        $$.next = new vector<string*>();
        $$.code = new vector<string*>();
        add_to_list($$.code, {$1.code});
        string * s = new string("ifeq ");
        $$.next->push_back(s);
        add_to_list($$.code, {$1.code});
        perform_label_adding($$.code, &$1.next);
        $$.code->push_back(s);
      }
    }
  };
ASSIGNMENT_OPTIONAL:
  %empty {
    $$.code = nullptr;
    $$.next = nullptr;
  }
  |
  ID
  ASSIGN
  BOOLEAN_EXPRESSION
  {
    process_assignment(*$1, &$$, &$3);
    delete $1;
  };
BOOLEAN_CONDITION_OPTIONAL:
  %empty {
    $$.code = nullptr;
    $$.next = nullptr;
  }
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
    perform_label_adding($$.code, &$9.next);
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
      $$.code = nullptr;
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
    perform_label_adding($$.code, &$2.next);
  };
TERM:
  FACTOR {$$.code = $1.code;$$.type=$1.type;}
  |
  TERM
  MULOP
  FACTOR
  {
    process_arith_op(&$$, &$1, $2, &$3);
  };
SIMPLE_EXPRESSION:
  TERM {$$.type = $1.type;$$.code=$1.code;}
  |
  SIGN TERM {
    if ($2.type == TYPE::BOOL) {
      $$.type = TYPE::ERROR;
      $$.code = nullptr;
      yyerror("Unary sign is an invalid operation for booleans");
    } else {
      $$.type = $2.type;
      $$.code = $2.code;
      if ($1) {
        $$.code->push_back(new string(type_map[$2.type]+"neg"));
      }
    }
  }
  |
  SIMPLE_EXPRESSION
  ADDOP
  TERM {
    process_arith_op(&$$, &$1, $2, &$3);
  };
EXPRESSION:
  SIMPLE_EXPRESSION {$$.type = $1.type;$$.code = $1.code;}
  |
  SIMPLE_EXPRESSION
  RELOP
  SIMPLE_EXPRESSION {
    if ($1.type == TYPE::BOOL || $3.type == TYPE::BOOL) {
      if ($1.type != TYPE::BOOL || $3.type != TYPE::BOOL) {
        $$.type = TYPE::ERROR;
        $$.code = nullptr;
        yyerror("Invalid comparison between a " + type_tostr_map[$1.type] + " and a " + type_tostr_map[$3.type]);
      } else if ((*$2) == "==" || (*$2) == "!=") {
        $$.type = TYPE::BOOL;
        $$.code = new vector<string *>();
        add_to_list($$.code, {$1.code, $3.code});
        label x,y;
        string * s = new string("if_icmp"+real_ops[*$2]+" "+x.get_name());
        string * k = new string("goto " + y.get_name());
        string * fv = new string("iconst_0");
        string * tv = new string("iconst_1");
        $$.code->push_back(s);
        $$.code->push_back(fv);
        $$.code->push_back(k);
        add_label_to_code($$.code, x);
        $$.code->push_back(tv);
        add_label_to_code($$.code, y);
      } else {
        yyerror("Invalid comparison operation \'" + *$2 + "\'' between booleans");
        $$.type = TYPE::ERROR;
        $$.code = nullptr;
      }
    } else if ($1.type != TYPE::ERROR && $3.type != TYPE::ERROR) {
        if($1.type == $3.type) {
          if ($1.type == TYPE::INT) {
            $$.type = TYPE::BOOL;
            $$.code = new vector<string *>();
            add_to_list($$.code, {$1.code, $3.code});
            label x,y;
            string * s = new string("if_icmp"+real_ops[*$2]+" "+x.get_name());
            string * k = new string("goto " + y.get_name());
            string * fv = new string("iconst_0");
            string * tv = new string("iconst_1");
            $$.code->push_back(s);
            $$.code->push_back(fv);
            $$.code->push_back(k);
            add_label_to_code($$.code, x);
            $$.code->push_back(tv);
            add_label_to_code($$.code, y);
          } else {
            $$.type = TYPE::BOOL;
            $$.code = new vector<string *>();
            add_to_list($$.code, {$1.code, $3.code});
            label x,y;
            string * fcm = new string("fcmpl");
            string * s = new string("if"+real_ops[*$2]+" "+x.get_name());
            string * k = new string("goto " + y.get_name());
            string * fv = new string("iconst_0");
            string * tv = new string("iconst_1");
            $$.code->push_back(fcm);
            $$.code->push_back(s);
            $$.code->push_back(fv);
            $$.code->push_back(k);
            add_label_to_code($$.code, x);
            $$.code->push_back(tv);
            add_label_to_code($$.code, y);
          }
        } else {
          $$.type = TYPE::BOOL;
          $$.code = new vector<string *>();
          string *casts = new string("i2f");
          add_to_list($$.code, {$1.code});
          if ($1.type == TYPE::INT) {
            $$.code->push_back(casts);
          }
          add_to_list($$.code, {$3.code});
          if ($3.type == TYPE::INT) {
            $$.code->push_back(casts);
          }
          label x,y;
          string * fcm = new string("fcmpl");
          string * s = new string("if"+real_ops[*$2]+" "+x.get_name());
          string * k = new string("goto " + y.get_name());
          string * fv = new string("iconst_0");
          string * tv = new string("iconst_1");
          $$.code->push_back(fcm);
          $$.code->push_back(s);
          $$.code->push_back(fv);
          $$.code->push_back(k);
          add_label_to_code($$.code, x);
          $$.code->push_back(tv);
          add_label_to_code($$.code, y);
        }
    } else {
      $$.type = TYPE::ERROR;
      $$.code = nullptr;
    }
    delete $2;
  };
BTERM:
  EXPRESSION {$$.code = $1.code; $$.type = $1.type;}
  |
  BNOT
  BTERM {
    if ($2.type == TYPE::BOOL) {
      $$.type = TYPE::BOOL;
      $$.code = $2.code;
      label x,y;
      string *s1 = new string("ifeq " + x.get_name());
      string *s2 = new string("iconst_0");
      string *s3 = new string("iconst_1");
      string *s4 = new string("goto " + y.get_name());
      $$.code->push_back(s1);
      $$.code->push_back(s2);
      $$.code->push_back(s4);
      add_label_to_code($$.code, x);
      $$.code->push_back(s3);
      add_label_to_code($$.code, y);
    } else if ($2.type != TYPE::ERROR) {
      $$.type = TYPE::ERROR;
      $$.code = nullptr;
      yyerror("Invalid logical not on operand of type " + type_tostr_map[$2.type]);
    } else {
      $$.type = TYPE::ERROR;
      $$.code = nullptr;
    }
  };
BSIMPLE_EXPRESSION:
  BTERM {$$.type = $1.type; $$.code =$1.code;$$.next = nullptr;}
  |
  BSIMPLE_EXPRESSION
  BAND
  BTERM {
    if ($1.type == TYPE::BOOL && $3.type == TYPE::BOOL) {
      $$.type = TYPE::BOOL;
      $$.code = new vector<string *>();
      $$.next = new vector<string *>();
      label x;
      string *s1 = new string("ifne " + x.get_name());
      string *s2 = new string("iconst_0");
      string *s3 = new string ("goto ");
      add_to_list($$.next, {$1.next});
      $$.next->push_back(s3);
      add_to_list($$.code, {$1.code});
      $$.code->push_back(s1);
      $$.code->push_back(s2);
      $$.code->push_back(s3);
      add_label_to_code($$.code, x);
      add_to_list($$.code, {$3.code}); 
    } else if ($1.type != TYPE::ERROR && $3.type != TYPE::ERROR) {
      $$.type = TYPE::ERROR;
      $$.code = nullptr;
      $$.next = nullptr;
      yyerror("Invalid operands types for logical and (" + type_tostr_map[$1.type] + "," + type_tostr_map[$3.type] + "), must have both operands booleans");
    } else {
      $$.type = TYPE::ERROR;
      $$.code = nullptr;
      $$.next = nullptr;
    }
  };
BOOLEAN_EXPRESSION:
  BSIMPLE_EXPRESSION{
    $$.type = $1.type;
    $$.code =$1.code;
    $$.next = nullptr;
    perform_label_adding($$.code, &$1.next);
  }
  |
  BOOLEAN_EXPRESSION
  BOR
  BSIMPLE_EXPRESSION {
    if ($1.type == TYPE::BOOL && $3.type == TYPE::BOOL) {
      $$.type = TYPE::BOOL;
      $$.code = new vector<string *>();
      $$.next = new vector<string *>();
      label x;
      string *s1 = new string("ifeq " + x.get_name());
      string *s2 = new string("iconst_1");
      string *s3 = new string ("goto ");
      add_to_list($$.next, {$1.next});
      $$.next->push_back(s3);
      add_to_list($$.code, {$1.code});
      $$.code->push_back(s1);
      $$.code->push_back(s2);
      $$.code->push_back(s3);
      add_label_to_code($$.code, x);
      add_to_list($$.code, {$3.code});
      perform_label_adding($$.code, &$3.next);
    } else if ($1.type != TYPE::ERROR && $3.type != TYPE::ERROR) {
      $$.type = TYPE::ERROR;
      $$.code = nullptr;
      $$.next = nullptr;
      yyerror("Invalid operands types for logical or (" + type_tostr_map[$1.type] + "," + type_tostr_map[$3.type] + "), must have both operands booleans");
    } else {
      $$.type = TYPE::ERROR;
      $$.code = nullptr;
      $$.next = nullptr;
    }
  };
%%

void yyerror(const string s) {
  cout << "Parse error on line " << line_num << "!  Message: " << s << endl;
  //- might as well halt now:
  //- no
  //exit(-1);
}

void back_patch(vector<string *> **list, string m) {
  if (*list != nullptr) {
    for (unsigned i = 0; i < (*list)->size(); i++) {
      (*((*(*list))[i])) += m;
    }
    delete *list;
    *list = nullptr;
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

void perform_label_adding(vector<string *> *code, vector<string *> **next) {
  if (need_label(*next)) {
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

void process_assignment(string id, Basic_nt * par, B_exp_nt * bexp) {
  if (hasId(id)) {
      if (bexp->type != TYPE::ERROR) {
        TYPE idt = getType(id);
        uint mem = getMemoryPlace(id);
        bool can_assign = false;
        bool need_cast = false;
        if (idt == bexp->type) {
          can_assign = true;
        } else {
          if (idt == TYPE::FLOAT && bexp->type == TYPE::INT) {
            can_assign =true;
            need_cast = true;
          }
        }
        if (can_assign) {
          par->code = new vector<string *>();
          add_to_list(par->code, {bexp->code});
          perform_label_adding(par->code, &bexp->next);
          if (need_cast) {
            string * s = new string("i2f");
            par->code->push_back(s);
          }
          par->code->push_back(new string(type_map[idt] + "store " + to_string(mem)));
          par->next = nullptr;
        } else {
          par->code = nullptr;
          par->next = nullptr;
          yyerror("Cannot cast from " +  type_tostr_map[bexp->type] + " to " + type_tostr_map[idt]);
        }
      }
    } else {
      par->code = nullptr;
      par->next = nullptr;
      yyerror("Identifier " + id + " has not been declared");
    }
}
void process_arith_op(A_exp_nt * par, A_exp_nt * a, char op, A_exp_nt *b) {
  if (a->type == b->type) {
      if (a->type == TYPE::BOOL) {
        par->type = TYPE::ERROR;
        par->code = nullptr;
        yyerror(string("Cannot perform ") + op + " on booleans");
      } else if (a->type != TYPE::ERROR) {
        par->code = new vector<string *>();
        add_to_list(par->code, {a->code, b->code});
        string *s = new string(type_map[a->type] + op_map[op]);
        par->code->push_back(s);
        par->type = a->type;
      } else {
        par->type = TYPE::ERROR;
        par->code = nullptr;
      }
    } else {
      if (a->type == TYPE::BOOL || b->type == TYPE::BOOL) {
        par->type = TYPE::ERROR;
        par->code = nullptr;
        yyerror(string("Cannot perform ") + op + " on " + type_tostr_map[a->type] + " and " +type_tostr_map[b->type]);
      } else if (a->type != TYPE::ERROR && b->type != TYPE::ERROR) {
        par->code = new vector<string *>();
        string *k = new string("i2f");
        add_to_list(par->code, {a->code});
        if (a->type == TYPE::INT) {
          par->code->push_back(k);
        }
        add_to_list(par->code, {b->code});
        if (b->type == TYPE::INT) {
          par->code->push_back(k);
        }
        string *s = new string("f" + op_map[op]);
        par->code->push_back(s);
        par->type = TYPE::FLOAT;
      } else {
        par->type = TYPE::ERROR;
        par->code = nullptr;
      }
    }
}
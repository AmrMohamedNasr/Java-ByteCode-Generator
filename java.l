%{
	#include "java.h"
	#include "java.tab.h"
	#define YY_DECL extern "C" int yylex()
	int yyerror(string s);
	int line_num = 1;
%}
letter		[a-z]|[A-Z]
digit		[0-9]
digits		{digit}+
%%

[ \t]*		;
"if"        { return KIF; }
"else"           { return KELSE; }
"while"            { return KWHILE; }
"for"  			{return KFOR; }
"true"			{return VTRUE;}
"false"			{return VFALSE;}
"boolean"			{return TBOOLEAN;}
"int"			{return TINT;}
"!"				{return BNOT;}
{letter}({letter}|{digit})*		{yylval.sval = new string(yytext); return ID;}
"=="|"!="|">"|"<"|">="|"<="		{yylval.sval = new string(yytext); return RELOP;}
"="								{return ASSIGN;}
"+"|"-"							{return ADDOP;}
"*"|"/"							{return MULOP;}
"&&"							{return BAND;}
"||"							{return BOR;}
{digits}						{yylval.ival = atoi(yytext);return VINT;}
{digits}\.{digits}("E"{digits})?	{yylval.fval = atof(yytext);return VFLOAT;}		
";"								{return SEMICOL;}
"("								{return LPAR;}
")"								{return RPAR;}
"{"								{return LCB;}
"}"								{return RCB;}
\n             { ++line_num;}
.              { yyerror("Found \'" + yytext + "\' on line " + to_str(line_num)); exit(1);	}

%%
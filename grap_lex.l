%{
#include <stdlib.h>
#include <ostream.h>
#include <sys/param.h>
#include "grap.h"
#include "y.tab.h"

//#define LEX_DEBUG
#ifndef LEX_DEBUG
#define DEBUG(a,b) (a,b)
#else
#define DEBUG(a,b) fprintf(stderr,a,b)
#endif

// #define YY_USER_ACTION  if ( !stack_init ) init_stack();
    
int return_macro = 0;
int slashcount = 0;
int macro_end = 0;
String *macrotext;
int in_str = 0;
int braces = 0;
int stack_init =0;
int copystate =0;

int lex_expand_macro =1;

linelist *sl;
String *copy_end, *copy_backstop;

extern macroDictionary macros;
extern lineDictionary lines;
extern coordinateDictionary coordinates;

int include_string(String *, struct for_descriptor *f=0, grap_input i=GMACRO);
void lex_begin_macro_text();
void macro_args(macro*);
void init_stack();
void newline();

%}
%x GRAP
%x MACROTEXT
%x COPYSTATE
%x HUNTMACRO
%x RESTOFLINE
%%
<INITIAL>{
^.G1([ \t].*)? 	{

        if ( strlen(yytext) > 3)
	    yylval.string = new String(yytext+3);
	else
	    yylval.string = 0;
	
	BEGIN(GRAP);
	return START;
	}
.+	ECHO;
\n	{
           newline();
           ECHO;
        }
}
<GRAP>{
\#.*\n                 { newline(); } 
[ \t]+
\\\n                    { newline(); } 
[;\n]			{
                          if ( *yytext == '\n' ) newline();
                          DEBUG("SEP\n",0);
			  return SEP; 
                        }
\(			DEBUG("LPAREN\n",0); return LPAREN;
\)			DEBUG("RPAREN\n",0); return RPAREN;
,			DEBUG("COMMA\n",0); return COMMA;
copy			DEBUG("COPY\n",0); return COPY;
\+			DEBUG("PLUS\n",0); return PLUS;
\-			DEBUG("MINUS\n",0); return MINUS;
\*			DEBUG("TIMES\n",0); return TIMES;
\/			DEBUG("DIV\n",0); return DIV;
\^			DEBUG("CARAT\n",0); return CARAT;
\=			DEBUG("EQUALS\n",0); return EQUALS;
\=\=			DEBUG("EQ\n",0); return EQ;
\!\=			DEBUG("NEQ\n",0); return NEQ;
\<			DEBUG("LT\n",0); return LT;
\>			DEBUG("GT\n",0); return GT;
\<\=			DEBUG("LTE\n",0); return LTE;
\>\=			DEBUG("GTE\n",0); return GTE;
\&\&			DEBUG("AND\n",0); return AND;
\|\|			DEBUG("OR\n",0); return OR;
\!			DEBUG("NOT\n",0); return NOT;
next			DEBUG("NEXT\n",0); return NEXT;
draw|new		DEBUG("DRAW\n",0); return DRAW;
line			DEBUG("LINE\n",0); return LINE;
define			DEBUG("DEFINE\n",0); return DEFINE;
arrow			DEBUG("ARROW\n",0); return ARROW;
circle			DEBUG("CIRCLE\n",0); return CIRCLE;
radius|rad		DEBUG("RADIUS\n",0); return RADIUS;
plot			DEBUG("PLOT\n",0); return PLOT;
frame			DEBUG("FRAME\n",0); return FRAME;
graph			DEBUG("GRAPH\n",0); return GRAPH;
coord			DEBUG("COORD\n",0); return COORD;
for			DEBUG("FOR\n",0); return FOR;
from			DEBUG("FROM\n",0); return FROM;
thru			DEBUG("THRU\n",0); return THRU;
to			DEBUG("TO\n",0); return TO;
at			DEBUG("AT\n",0); return AT;
by			DEBUG("BY\n",0); return BY;
until			DEBUG("UNTIL\n",0); return UNTIL;
do			DEBUG("DO\n",0); return DO;
if			DEBUG("IF\n",0); return IF;
then			DEBUG("THEN\n",0); return THEN;
else			DEBUG("ELSE\n",0); return ELSE;	
print			DEBUG("PRINT\n",0); return PRINT;	
log[ \t]+x			DEBUG("LOG_X\n",0); return LOG_X;
log[ \t]+y			DEBUG("LOG_Y\n",0); return LOG_Y;
log[ \t]+log			DEBUG("LOG_LOG\n",0); return LOG_LOG;
x			DEBUG("X\n",0); return X;
y			DEBUG("Y\n",0); return Y;
ticks|tick			DEBUG("TICKS\n",0); return TICKS;
label			DEBUG("LABEL\n",0); return LABEL;
grid			DEBUG("GRID\n",0); return GRID;
pic			DEBUG("PIC\n",0); return PIC;
top			DEBUG("TOP\n",0); return TOP;
bottom|bot		DEBUG("BOTTOM\n",0); return BOTTOM;
left			DEBUG("LEFT\n",0); return LEFT;
right			DEBUG("RIGHT\n",0); return RIGHT;
up			DEBUG("UP\n",0); return UP;
down			DEBUG("DOWN\n",0); return DOWN;
ljust			DEBUG("LJUST\n",0); return LJUST;
rjust			DEBUG("RJUST\n",0); return RJUST;
above			DEBUG("ABOVE\n",0); return ABOVE;
below			DEBUG("BELOW\n",0); return BELOW;
aligned			DEBUG("ALIGNED\n",0); return ALIGNED;
unaligned		DEBUG("UNALIGNED\n",0); return UNALIGNED;
size			DEBUG("SIZE\n",0); return SIZE;
in			DEBUG("IN\n",0); return IN;
out			DEBUG("OUT\n",0); return OUT;
off			DEBUG("OFF\n",0); return OFF;
ht|wid			{
			DEBUG("FRAMESIZE\n",0);
			if ( !strcmp(yytext,"ht") ) yylval.val = ht;
			else yylval.val =wid;
			return FRAMESIZE;
			}
invis			DEBUG("INVIS\n",0); return INVIS;
solid			DEBUG("SOLID\n",0); return SOLID;
dotted			DEBUG("DOTTED\n",0); return DOTTED;
dashed			DEBUG("DASHED\n",0); return DASHED;
color			DEBUG("color\n",0); return COLOR;
rand			{
			int i;

			DEBUG("FUNC0\n",0);
			for ( i = 0 ; i < NF0; i++ ) 
				if ( !strcmp(yytext,f0names[i]) )
					yylval.val = i;
 			return FUNC0;
			}
log|exp|int|sin|cos|sqrt|rand	{
			int i;

			DEBUG("FUNC1\n",0);
			for ( i = 0 ; i < NF1; i++ ) 
				if ( !strcmp(yytext,f1names[i]) )
					yylval.val = i;
 			return FUNC1;
			}
atan2|min|max		{
			int i;

			DEBUG("FUNC2\n",0);
			for ( i = 0 ; i < NF2; i++ ) 
				if ( !strcmp(yytext,f2names[i]) )
					yylval.val = i;
			return FUNC2;
			}
([0-9]*\.?[0-9]+)|([0-9]*\.?[0-9]+e(\+|\-)?[0-9]+)	{ 
			DEBUG("Number: %s\n",yytext);
			yylval.num = atof(yytext);
			return NUMBER;
			}
^\.[^0-9].*$                  {
                                DEBUG("Troff: %s\n",yytext);
				if ( !strncmp(".G1", yytext, 3) ) {
				    if ( lexstack.empty() ||
					 lexstack.top()->report_start == 1 ) {
					DEBUG("Start: %s\n",yytext); 
					return START;
				    }
				    else YY_BREAK;
				}
				if ( !strncmp(".G2", yytext, 3) ) {
				    if ( lexstack.empty() ||
					 lexstack.top()->report_start == 1) {

					yyinput(); // Gobble up the newline
					DEBUG("End: %s\n",yytext);
					BEGIN(INITIAL);
					return END;
				    }
				    else YY_BREAK;
				}				
                                yylval.string = new String(yytext);
				return TROFF;
                        }
\"([^\"\n]|\\\")*\"	{ 
			DEBUG("String: %s\n",yytext);
			yylval.string = new String(yytext);
			return STRING;
			}
[A-Za-z0-9_]*		{ 
			macro *m;
			coord *c;
			line *l;
			String *id;
			char ch;

			DEBUG("ident: %s\n",yytext);
			id = new String(yytext);
			if ( lex_expand_macro && macros.find(id,m) ) {
				delete id;
				ch = yyinput();
				if ( ch == '(') macro_args(m);
				else unput(ch);
				id = m->invoke();
				include_string(id);
				delete id;
			}
			else {
				if ( coordinates.find(id,c) ) {
					yylval.coordptr = c;
					return COORD_NAME;
				} else {
				    yylval.string = id;
				    return IDENT;
				}
			}
                        }
.			DEBUG("unknown: %s\n",yytext); return 0;
}
<MACROTEXT>{
[ \t]+			{
				slashcount = 0;
				if ( macro_end != 0)
					*macrotext += yytext;
			}
\\			{ 
				*macrotext += *yytext;
				slashcount ++;
			}
\"			{ 
				*macrotext += *yytext;
				if ( in_str ) { 
					if ( slashcount % 2 == 0) in_str=0;
				} 
				else {
					if ( slashcount % 2 == 0) in_str=1;
				}
				slashcount = 0;
			}
\{			{
				if ( macro_end == 0 ) {
					macro_end = '}';
					braces = 1;
				}
				else {
					if ( !in_str ) braces++;
					*macrotext += *yytext;
					slashcount =0;
				}
			}
\}			{
				if ( macro_end == 0 ) return 0;
				else {
					if ( !in_str ) braces--;
					if ( macro_end == '}' && !braces ) {
					    BEGIN(GRAP);
					    if ( !return_macro) {
						yylval.string = macrotext;
						return TEXT;
					    } else {
						macro *m = new macro(macrotext);
						yylval.macro_val = m;
						return MACRO;
					    }
					}
					else {
					    *macrotext += *yytext;
					    slashcount =0;
					}
				}
			}
\n			{ newline(); *macrotext += *yytext; slashcount =0;}
.			{
				if ( macro_end == 0 ) macro_end = *yytext;
				else {
					if ( *yytext == macro_end ) {
					    BEGIN(GRAP);
					    if ( !return_macro ) {
						yylval.string = macrotext;
						return TEXT;
					    } else {
						macro *m = new macro(macrotext);
						yylval.macro_val = m;
						return MACRO;
					    }
					}
					else {
					    *macrotext += *yytext;
					    slashcount =0;
					}
				}
			}
}
<COPYSTATE>{
\n      { newline(); }
.+ 	{
    String *s;
    
    if ( *copy_end != yytext && *copy_backstop != yytext ) {
	s = new String(yytext);
	sl->insert(s);
    }
    else {

	// If we're stopped by an END symbol, we have to put it back
	
	if ( !strncmp(".G2",yytext,3) ) {
	    char *c = strdup(yytext);
	    for ( int i = yyleng-1; i>=0; i-- ) 
		unput(c[i]);
	    unput('\n');
	    free(c);
	}
	BEGIN(GRAP);
	yylval.line_list = sl;
	copystate = 0;
	DEBUG("COPYTEXT",0);
	return COPYTEXT;
    }
    }
}
<HUNTMACRO>{
[ \t]+
[A-Za-z0-9_]* 	{
    macro *m;
    
    String *id = new String(yytext);
    if ( macros.find(id,m)) {
	delete id;
	BEGIN(GRAP);
	yylval.macro_val = m;
	return MACRO;
    }
    else {
	char *c = strdup(yytext);

	delete id;
	lex_begin_macro_text();
	return_macro =1;
	for ( int i = yyleng-1; i>=0; i-- ) 
	    unput(c[i]);
	free(c);
    }
}
. {
    unput(*yytext);
    lex_begin_macro_text();
    return_macro = 1;
   }
}
<RESTOFLINE>{
.*$ 		{
    BEGIN(GRAP);
    DEBUG("REST:%s\n",yytext);
    if ( strcmp("\n",yytext) )
	yylval.string = new String(yytext);
    else
	yylval.string = 0;

    return REST;
    }
}
<<EOF>> 	{
    if ( copystate && !lexstack.empty()) {
	copystate = 0;
	BEGIN(GRAP);
	yylval.line_list = sl;
	return COPYTEXT;
    } else yyterminate();
}
    
%%
void init_stack() {
    grap_buffer_state *g = new grap_buffer_state;

    g->yy = yy_create_buffer(stdin,YY_BUF_SIZE);
    g->f = 0;
    g->name = new String("stdin");
    g->line = 1;
    g->type = GFILE;
    g->report_start =1;
    lexstack.push(g);
}

bool include_file(String *s) {
    FILE *f;
    char file[MAXPATHLEN];
    YY_BUFFER_STATE buf;
    struct grap_buffer_state *g = new (struct grap_buffer_state);

    s->strncpy(file,MAXPATHLEN);
    if ( ( f = fopen(file,"r")) == 0 ) {
	cerr << "Can't open " << file << " ";
	perror(0);
	return 0;
    }
    g->yy = yy_create_buffer(f,YY_BUF_SIZE);
    g->f = 0;
    g->name = new String(s);
    g->line = 1;
    g->type = GFILE;
    g->report_start=0;
    lexstack.push(g);
    yy_switch_to_buffer(g->yy);
    return 1;
}
	
void lex_begin_macro_text() { 
	BEGIN(MACROTEXT);
	lex_expand_macro = 1;
	slashcount = 0;
	macro_end = 0;
	return_macro=0;
	macrotext = new String;
	in_str = 0;
	braces = 0;
}

int include_string(String *s, struct for_descriptor *f=0,
		   grap_input it=GMACRO) {
	char *cbuf;
	int len;
	YY_BUFFER_STATE buf;
	grap_buffer_state *g;

	g = new grap_buffer_state;
	cbuf = new char[len = s->strlen()+1];

	s->strncpy(cbuf,len-1);
	cbuf[len-1] = '\0';
	g->yy = yy_scan_string(cbuf);
	g->f = f;
	g->name = 0;
	g->line = 1;
	g->type = it;
	g->report_start = 1;
	lexstack.push(g);
	delete cbuf;
	return 1;
}

void macro_args(macro *m) {
    String *arg;
    int c;
    int parens = 0;
    int slashcount = 0;
    int in_str = 0;

    arg = new String;
    for ( c = yyinput(); c != EOF && ( c != ')' || parens ); c = yyinput()) {
	if ( c == ',' && !in_str && !parens) {
	    // End of arg
	    if ( m->add_arg(arg)) arg = new String;
	    continue;
	}
	if ( c == '(' ) parens++;
	if ( c == ')' ) parens --;
	if ( c == '"' && (slashcount % 2 ) == 0 ) {
	    if ( in_str ) in_str = 0;
	    else in_str = 1;
	}
	if ( c == '\\' ) slashcount++;
	else slashcount = 0;
	*arg += (char) c;
    }
    if ( c == ')' && arg->strlen() )
	if ( !m->add_arg(arg)) delete arg;
}

void lex_begin_copy(String *s=0) {
    BEGIN(COPYSTATE);
    copystate = 1;
    if ( !copy_backstop ) copy_backstop = new String(".G2");
    if ( copy_end) delete copy_end;
    if ( s ) copy_end = s;
    else copy_end = new String(".G2");
    sl = new linelist;
}

void lex_hunt_macro() {

    BEGIN(HUNTMACRO);
}
void lex_begin_rest_of_line() {

    BEGIN(RESTOFLINE);
}

int yywrap() {
    struct grap_buffer_state *g;

    if ( lexstack.empty() ) yyterminate();
    else g = lexstack.pop();
    
    if ( g->f ) {

	struct for_descriptor *f = g->f;
	// we're processing a for statement


	switch (f->by_op ) {
	    case PLUS:
	    default:
		*f->loop_var += f->by;
		break;
	    case MINUS:
		*f->loop_var -= f->by;
		break;
	    case TIMES:
		*f->loop_var *= f->by;
		break;
	    case DIV:
		*f->loop_var /= f->by;
		break;
	}

	if ( (*f->loop_var - f->limit) * f->dir < EPSILON ) {
	    // still iterating redo this stack frame
	    yy_delete_buffer(g->yy);

	    // *do not delete g->f because include string will attach
	    // it to the new grap_buffer_state that it allocates.
	    
	    if ( g->name ) delete g->name;
	    delete g;
	    include_string(f->anything, f);
	    return 0;
	}
    }
    // If we get here, we need to switch to the previous buffer


    yy_delete_buffer(g->yy);
    if ( g->f ) delete g->f;
    if ( g->name ) delete g->name;
    delete g;

    if ( lexstack.empty() ) return 1;
    else {
	g = lexstack.top();
	yy_switch_to_buffer(g->yy);
    }
    
    if ( copystate ) {
	return 1;
    }
    else return 0;
}

void newline() {
    if ( !lexstack.empty() ) {
	grap_buffer_state *g = lexstack.top();
	g->line++;

    }
}
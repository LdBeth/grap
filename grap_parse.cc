/* -*-c++-*- */
/* This code is (c) 1998 Ted Faber (faber@lunabase.org) see the
   COPYRIGHT file for the full copyright and limitations of
   liabilities. */
#ifdef HAVE_CONFIG_H
#include "config.h"
#endif
#include <stdio.h>
#include <iostream.h>
#include <math.h>
#ifdef STDC_HEADERS
#include <stdlib.h>
#endif

#include "grap.h"
#include "grap_data.h"
#include "grap_draw.h"
#include "grap_pic.h"
#include "y.tab.h"

extern doubleDictionary vars;
extern graph *the_graph;
extern bool unaligned_default;	// Should strings be unaligned by default 

extern line* defline;
extern coord *defcoord;

// defined in grap_lex.l
extern int include_string(String *,struct for_descriptor *f=0,
			  grap_input i=GMACRO);
extern int nlines;

// Classes for various for_each calls

// This collects the modifiers for other strings in
// a string list to construct the modifiers for the next string
class modaccumulator :
    public UnaryFunction <DisplayString *, int > {
public:
	int just;
	double size;
	int rel;
	modaccumulator() : just(0), size(0), rel(0) {};
	int operator()(DisplayString* s) {
	    just = s->j;
	    size = s->size;
	    rel = s->relsz;
	    return 0;
	}
};


// Add a tick to the graph
class add_tick_f : public UnaryFunction<tick*, int> {
    sides side;
    double size;
    shiftlist shift;
public:
    add_tick_f(sides sd, double sz, shiftlist *s) :
	side(sd), size(sz), shift() {
	shiftcpy sc(&shift);

	for_each(s->begin(), s->end(), sc);
    };
    int operator()(tick *t) {
	shiftcpy sc(&t->shift);
	t->side = side;
	t->size = size;

	for_each(shift.begin(), shift.end(), sc);

	the_graph->base->tks.push_back(t);
	if ( t->side == top || t->side == bottom )
	    t->c->newx(t->where);
	else 
	    t->c->newy(t->where);
	return 0;
    }
};


linedesc* combine_linedesc(linedesc *desc, linedesc* elem) {
		if ( elem->ld != def ) {
		    desc->ld = elem->ld;
		    desc->param = elem->param;
		}
		if ( elem->fill ) desc->fill = elem->fill;
		if ( elem->color ) {
		    if ( desc->color ) delete desc->color;
		    desc->color = elem->color;
		    // Don't let the destructor delete the color in desc.
		    elem->color = 0;
		}
		if ( elem->fillcolor ) {
		    if ( desc->fillcolor ) delete desc->fillcolor;
		    desc->fillcolor = elem->fillcolor;
		    // Don't let the destructor delete the fillcolor
		    // in desc.
		    elem->fillcolor = 0;
		}
		delete elem;
		return desc;
	    }
;

// Process a draw statement.  Create a new line description if this is
// a new name, assign the line description to it, and a plot string if
// necessary.
void draw_statement(String *ident, linedesc *ld, String *plot) {
    line *l;
    lineDictionary::iterator li;
    linedesc defld(invis,0,0);
    String s = "\"\\(bu\"";

    if ( ident ) {
	li = the_graph->lines.find(*ident);
	if ( li == the_graph->lines.end() ) {
	    l = new line(&defld,&s);
	    the_graph->lines[*ident] = l;
	}
	else {
	    l = (*li).second;
	}
	// Forgot to delete ident??
	delete ident;
    } else l = defline;

    l->desc = *ld;

    if ( plot ) {
	if ( l->plotstr ) *l->plotstr = *plot;
	else l->plotstr = new String(*plot);
	delete plot;
    }
    else {
	if (l->plotstr) {
	    delete l->plotstr;
	    l->plotstr = 0;
	}
    }
    l->initial = 1;
    delete ld;
}

// Process a line of a number list.  dl is a list of numbers on this
// line.  If if at least an x and y are there, add those points to the
// current line and coords.  If only one number is given, use the
// number of lines processed so far as the x value and the given
// number as the y.
void num_list(doublelist *dl) {
    double x, y;

    if ( dl->empty() )
	exit(20);
    else {
	x = dl->front();
	dl->pop_front();
    }
		
    if ( dl->empty() ) {
	defline->addpoint(nlines,x,defcoord);
	defcoord->newpt(nlines,x);
    }
    else {
	while ( !dl->empty() ) {
	    y = dl->front();
	    dl->pop_front();
	    defline->addpoint(x,y,defcoord);
	    defcoord->newpt(x,y);
	}
    }
    delete dl;
    nlines++;
}

// Assign the double to the variable named by ident.  If no such
// variable exists, create it.
double assignment_statement(String *ident, double val) {
    double *d;
    doubleDictionary::iterator di;
		
    if ( ( di = vars.find(*ident)) != vars.end() ) {
	d = (*di).second;
	*d = val;
    }
    else {
	d = new double(val);
	vars[*ident] = d;
    }
    // XXX: Again, shouldn't this go away?
    delete ident;
    return *d;
}

// Create an new point and return it.  Also note the new point with
// its coordinate system so that automatic coordinates work right.
point *new_point(coord *c, double x, double y) {
    c->newpt(x, y);
    return new point(x, y, c);
}

// This collects the modifiers for other strings in the list to
// construct the modifiers for the current string.
stringlist *combine_strings(stringlist *sl, String *st, strmod &sm)  {
    modaccumulator last;
    DisplayString *s;
			
    last = for_each(sl->begin(), sl->end(), modaccumulator());

    // If unaligned_default is set, then treat unaligned
    // strings as unmodified strings
		
    if ( sm.just != (unaligned_default ? unaligned : 0) )
	last.just = sm.just;
		
    if ( sm.size != 0 ) {
	last.size = sm.size;
	last.rel = sm.rel;
    }

    s = new DisplayString(*st,last.just,last.size,last.rel);
    delete st;
    sl->push_back(s);
    return sl;
}

// Create a new plot, that is a string created from a double, and add
// it to the current graph.
void plot_statement(double val, String *fmt, point *pt) {
    stringlist *seq = new stringlist;
    DisplayString *s;
    plot *p;

    if ( fmt ) {
	unquote(fmt);
	s = new DisplayString(val,fmt);
	delete fmt;
    }
    else s = new DisplayString(val);

    quote(s);
    seq->push_back(s);

    p = new plot(seq,pt);
    the_graph->add_plot(*p);
    delete p;
    // XXX: delete pt?
    delete pt;
}

// Add a point to the current line (or the named line if ident is
// non-0).  It may also include a linedescription, wich should be
// passed on if not a default.
void next_statement(String *ident, point *p, linedesc* ld) {
    line *l;
    lineDictionary::iterator li;
    String s = "\"\\(bu\"";

    if ( ident) {
	li = the_graph->lines.find(*ident);
	if ( li == the_graph->lines.end() ) {
	    l = new line((linedesc *)0, &s );
	    the_graph->lines[*ident] = l;
	}
	else { l = (*li).second; }
    } else l = defline;
    // XXX: delete ident??
    delete ident;
		
    if ( ld->ld != def )
	l->addpoint(p->x,p->y,p->c,0,ld);
    else 
	l->addpoint(p->x,p->y,p->c);
		
    delete p;
    delete ld;
}

// Create a new tick with the given format (if any) and add it to the
// current ticklist (which we're creating as we go).  If no such list
// exists, create it.
ticklist *ticklist_elem(double d, String *fmt, ticklist *tl) {
    tick *t = new tick(d,0,top,0, (shiftlist *) 0, 0);
    String *s;

    if ( fmt ) {
	unquote(fmt);
	s = dblString(d, fmt);
	delete fmt;
    }
    else s = dblString(d);
    t->prt = s;

    if ( !tl ) tl = new ticklist;
    tl->push_back(t);
    return tl;
}

// Convert a for description of a set of ticks into a list of ticks,
// including the coordinate system to put the ticks in, the beginning
// and ending ticks, a general increment descriptor (by) and a string
// to format each tick value.  Return the list.
ticklist *tick_for(coord *c, double from, double to, bydesc by, String *rfmt) {
    tick *t;
    String *s;
    String *fmt;
    double idx;
    int dir;
    ticklist *tl;

    tl = new ticklist;
    if ( rfmt ) {
	unquote(rfmt);
	fmt = new String(*rfmt);
	delete rfmt;
    } else
	fmt = new String("%g");
		
    if ( to - from >= 0 ) dir = 1;
    else dir = -1;
		
    idx = from;
    while ( (idx - to) *dir  < EPSILON ) {
	t = new tick(idx, 0, top, 0, (shiftlist *) 0, 0);
	t->c = c;

	s = dblString(idx,fmt);
	t->prt = s;
	tl->push_back(t);

	switch (by.op ) {
	    case PLUS:
		idx += by.expr;
		break;
	    case MINUS:
		idx -= by.expr;
		break;
	    case TIMES:
		idx *= by.expr;
		break;
	    case DIV:
		idx /= by.expr;
		break;
	}
    }
    delete fmt;
    return tl;
}

// Process the most complicated form of tick description.  Add a list
// of ticks to the current graph.
void ticks_statement(sides side, double dir, shiftlist *sl, ticklist *tl ) {
    shiftdesc *sd;
    shiftcpy sc(&the_graph->base->tickdef[side].shift);
		
    add_tick_f add_tick(side, dir, sl);

    the_graph->base->tickdef[side].side = side;

    for_each(sl->begin(), sl->end(), sc);

    if ( tl && tl->empty() )
	the_graph->base->tickdef[side].size = dir;
    else
	the_graph->base->tickdef[side].size = 0;

    if ( tl ) {
	for_each(tl->begin(), tl->end(), add_tick);
	delete tl;
    }
    while (!sl->empty()) {
	sd = sl->front();
	sl->pop_front();
	delete sd;
    }
    delete sl;
}

// Process a grid statement.  This is similar to, but somewhat more
// complex than the ticks statement above.
void grid_statement(sides side, int ticks_off, linedesc *ld,
		    shiftlist *sl, ticklist *tl) {
    tick *t;
    grid *g;
    linedesc defgrid(dotted, 0, 0);
    shiftcpy *sc;
    shiftdesc *sd;

		// Turning on a grid turns off default ticks on that side
		
    the_graph->base->tickdef[side].size = 0;
		
    if ( ld->ld != def ) 
	the_graph->base->griddef[side].desc = *ld;
    else {
		    
	// This is some dirty sleight of hand.  ld->color
	// is only assigned to defgrid.color long enough
	// to make these copies. XXX
		    
	defgrid.color = ld->color;
	the_graph->base->griddef[side].desc = defgrid;
	defgrid.color = 0;
    }

    sc = new shiftcpy(&the_graph->base->griddef[side].shift);
    for_each(sl->begin(), sl->end(), *sc);
    delete sc;

    if ( ticks_off ) {
	if ( the_graph->base->griddef[side].prt )
	    delete the_graph->base->griddef[side].prt;
	the_graph->base->griddef[side].prt = 0;
    }
    if ( tl ) {
	the_graph->base->griddef[side].desc.ld = def;
	while (!tl->empty() ) {
	    t = tl->front();
	    tl->pop_front();
			
	    g = new grid(t);
	    g->side = side;
	    if ( ld->ld != def )
		g->desc = *ld;
	    else {

		// This is some dirty sleight of hand.
		// ld->color is only assigned to
		// defgrid.color long enough to make these
		// copies. XXX
		    
		defgrid.color = ld->color;
		g->desc = defgrid;
		defgrid.color = 0;
	    }
		    
	    sc = new shiftcpy(&g->shift);
	    for_each(sl->begin(), sl->end(), *sc);
	    delete sc;

	    if ( ticks_off ) {
		if ( g->prt ) delete g->prt;
		g->prt = 0;
	    }
	    the_graph->base->gds.push_back(g);
	    if ( g->side == top || g->side == bottom )
		g->c->newx(g->where);
	    else 
		g->c->newy(g->where);
	    delete t;
	}
	delete tl;
    }
    while ( !sl->empty() ) {
	sd = sl->front();
	sl->pop_front();
	delete sd;
    }
    delete sl;
    delete ld;
}

// Draw a line from p1 to p2.  If is_line is false, draw an arror
// instead.  Either ld1 or ld2 or both may be present.  If only one is
// non-default, it rules, otherwise ld2 counts.
void line_statement(int is_line, linedesc *ld1, point *p1,
		    point *p2, linedesc *ld2 ) {
    line *l;
    lineDictionary::iterator li;
    linedesc des;

    // Basically this should never fail...
    li = the_graph->lines.find("grap.internal");
    if ( li == the_graph->lines.end() ) {
	des.ld = solid;
	l = new line(&des);
	the_graph->lines["grap.internal"] = l;
    }
    else { l = (*li).second; } 

    des = *ld1;
    if ( ld2->ld != def ) {
	des.ld = ld2->ld;
	des.param = ld2->param;
    }

    if ( ld2->color ) des.color = new String(*ld2->color);
		    
    l->initial = 1;

    if ( des.ld != def || des.color) {
	l->addpoint(p1->x,p1->y,p1->c,0,&des);
	if ( is_line )
	    l->addpoint(p2->x,p2->y,p2->c,0,&des);
	else
	    l->addarrow(p2->x,p2->y,p2->c,0,&des);
    } else {
	l->addpoint(p1->x,p1->y,p1->c);
	if (is_line) l->addpoint(p2->x,p2->y,p2->c);
	else l->addarrow(p2->x,p2->y,p2->c);
    }
    delete ld1; delete ld2;
    // XXX: delete points ??
    delete p1; delete p2;
}

// Create an axis description.  That is, tell which axis it is and the
// bounds.
axisdesc axis_description(axis which, double d1, double d2) {
    axisdesc a;
    
    a.which = which;
    if (d1 < d2 ) {
	a.min = d1; a.max = d2;
    } else {
	a.min = d2; a.max = d1;
    }
    return a;
}

// Create or assign to an old coordinate object.  Assign the mins and
// maxes to the axes and tell which if any are logarithmic.
void coord_statement(String *ident, axisdesc& xa, axisdesc& ya, axis log) {
    coord *c;
    coordinateDictionary::iterator ci;

    if (ident) {
	ci = the_graph->coords.find(*ident);
		    
	if (  ci == the_graph->coords.end()) {
	    c = new coord;
	    the_graph->coords[*ident] = c;
	}
	else { c = (*ci).second; }
	delete ident;
    } else {
	c = defcoord;
    }
    if ( xa.which != none ) {
	c->xmin = xa.min;
	c->xmax = xa.max;
	c->xautoscale = 0;
    }
    if ( ya.which != none ) {
	c->ymin = ya.min;
	c->ymax = ya.max;
	c->yautoscale = 0;
    }
    c->logscale = log;
}

// Initiate a for statement by generating a for descriptor and
// including the string.  The body is captured by changing lex state
// in the middle of the for_statement yacc rule.
void for_statement(String *ident, double from, double to,
		   bydesc by, String *body) {
    struct for_descriptor *f;
    doubleDictionary::iterator di;
    double *d;
		
    f = new for_descriptor;

    if ( ( di = vars.find(*ident)) != vars.end() ) {
	d = (*di).second;
	*d = from;
    }
    else {
	d = new double(from);
	vars[*ident] = d;
    }
    // XXX: delete ident?
    if (ident) delete ident;
    
    f->loop_var = d;
    if ( to - from > 0 ) f->dir = 1;
    else f->dir = -1;

    f->limit = to;
    f->by = by.expr;
    f->by_op = by.op;
    // force "anything" to end with a sep
    *body += ';';
    f->anything = body;
    // include_string is responsible for deleting body
    include_string(body,f,GINTERNAL);
}

void process_frame(linedesc* d, frame *f, frame *s) {
    // it's inconvenient to write three forms of the frame statement
    // as one yacc rule, so I wrote the three rules explicitly and
    // extracted the action here.  The three arugments are the default
    // frame linedesc (d), the size of the frame (f), and individual
    // descriptions of the linedescs (s) of the sides.  Note that d,
    // f, and s are freed by this routine.
    
    int i;	// Scratch

    if ( d ) {
	// a default linedesc is possible, but unlikely (only a fill,
	// for example).
	if ( d->ld != def ) {
	    for ( i = 0 ; i < 4; i++ ) {
		the_graph->base->desc[i] = *d;
	    }
	}
	delete d;
    }

    if ( f ) {
	the_graph->base->ht = f->ht;
	the_graph->base->wid = f->wid;
	delete f;
    }
		
    if ( s ) {
	for ( i = 0 ; i < 4; i++ ) {
	    if ( s->desc[i].ld != def )
		the_graph->base->desc[i] = (linedesc) s->desc[i];
	}
	delete s;
    }
}

void init_dict() {
    linedesc defld(invis,0,0);
    String s = "\"\\(bu\"";
    
    defcoord = new coord;
    the_graph->coords["grap.internal.default"] = defcoord;
    for ( int i = 0 ; i < 4; i++) {
	the_graph->base->tickdef[i].c = defcoord;
	the_graph->base->griddef[i].c = defcoord;
    }
    defline = new line(&defld,&s);
    the_graph->lines["grap.internal.default"] = defline;
    nlines = 0;
}
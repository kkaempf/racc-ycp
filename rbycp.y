/*
 * YCP syntax parser
 */

class Ycpparser
  prechigh
/*    nonassoc UMINUS */
    left '['
    left CLOSEBRACKET
    right '}'
    left ':'
    right '~'
    left ELSE
    right '!'
    left '*' '/' '%'
    left '+' '-'
    left LEFT RIGHT
    left '<' '>' RELOP
    right CONST
    left '&'
    left '^'
    left '|'
    left AND
    left OR
    left '?'
    right '='
  preclow

  token IF THEN ELSE
        DO WHILE UNTIL REPEAT
	BREAK CONTINUE RETURN
	DEFINE UNDEFINE
	IMPORT EXPORT INCLUDE FULLNAME
	GLOBAL STATIC EXTERN
	C_VOID C_BOOLEAN C_INTEGER C_CHAR C_STRING C_BYTEBLOCK
	C_PATH C_SYMBOL C_FLOAT
	MAP LIST
	C_TYPE
	RELOP AND OR LEFT RIGHT
	MAPEXPR I18N
	STRUCT BLOCK
	IS ISNIL
	SYMBOL
	TYPEDEF
	MODULE TEXTDOMAIN
	CONST 
	SWITCH CASE DEFAULT
	CLOSEBRACKET
	QUOTED_EXPRESSION QUOTED_BLOCK DCQUOTED_BLOCK
	SYM_NAMESPACE
rule

ycp
        : compact_expression
        | /* empty */
	;

/* Expressions */

  /*
   * EXPRESSION vs BLOCK: type
   * An important difference between a block and an expression is that
   * block's type is determined (!= isUnspec) only if it has an explicit
   * "return".  It is then used for detecting type-mismatched return
   * statements, among other things. As a consequence, all statements
   * except return must have an undetermined type (Type::Unspec).
   * Do not confuse Type::Unspec with Type::Void.
   */
  /* expressions are either 'compact' (with a defined end-token, no lookahead)
     or 'infix' (which might need a lookahead token)  */

expression
        : compact_expression
	| casted_expression
	| infix_expression
	| bracket_expression
	;

bracket_expression
        : compact_expression '[' list_elements CLOSEBRACKET expression
	;

castable_expression
        : compact_expression
	| casted_expression
	| bracket_expression
	;

casted_expression
        : '(' type ')' castable_expression
	;

compact_expression
        : block
	| function_call
	| '(' expression ')'
	| QUOTED_EXPRESSION expression ')'
	| IS '(' expression ',' type ')'
	| TEXTDOMAIN
	| I18N string ',' string ',' expression ')'
	| I18N string ')'
	| identifier
	| list
	| map
	| constant
;

infix_expression
        : expression '+' expression
	| expression '-' expression
	| expression '*' expression
	| expression '/' expression
	| expression '%' expression
	| expression LEFT expression
	| expression RIGHT expression
	| expression '&' expression
	| expression '^' expression
	| expression '|' expression
	| '~' expression
	| expression AND expression
	| expression OR expression
	| expression RELOP expression
	| expression '<' expression
	| expression '>' expression
	| '!' expression
	| '-' expression
	| expression '?' expression ':' expression
	;

block
        : '{' block_end
	| QUOTED_BLOCK block_end
	;

block_end
        : statements '}'
	;

/* -------------------------------------------------------------- */
/* Statements */

statements
        : statements statement
	| /* empty  */
	;

statement
        : ';'
	| SYM_NAMESPACE DCQUOTED_BLOCK block_end
	| MODULE C_STRING ';'
	| INCLUDE C_STRING ';'
	  { open val[1] unless @seen[val[1]] }
	| IMPORT C_STRING ';'
	  { v = val[1]
	    f = v+".ycp"
	    unless( @seen[f] || (v == "SCR") || (v == "UI") )
	      open f, true
	    end
	  }
	| FULLNAME C_STRING ';'
	| TEXTDOMAIN C_STRING ';'
	| EXPORT identifier_list ';'
	| TYPEDEF type SYMBOL ';'
	  { result = val[1]
	    @symbols[val[2]] = :C_TYPE
	    $stderr.puts "typedef #{result}"
	  }
	| definition
	| assignment ';'
	| function_call ';'
	| block
	| control_statement
	| CASE expression ':'
	| DEFAULT  ':'
	;

control_statement
        : IF '(' expression ')' statement opt_else
	| WHILE '(' expression ')' statement
	| DO block WHILE '(' expression ')' ';'
	| REPEAT block UNTIL '(' expression ')' ';'
	| BREAK ';'
	| CONTINUE ';'
	| RETURN ';'
	| RETURN expression ';'
	| SWITCH '(' expression ')' block
	;

opt_else
        : ELSE statement
	| /* empty */
	;

/* -------------------------------------------------------------- */
/* types  */

type
        : C_TYPE
	| LIST
	| LIST '<' type_gt
	| MAP
	| MAP '<' type ',' type_gt
	| BLOCK '<' type_gt
	| CONST type
	| type '&'
	| type '(' ')'
	| type '(' types ')'
	;

/* recognize "type >" vs "type >>" */
type_gt
        : type '>'
	| type RIGHT
	;

types
        : type
	| types ',' type
	;
/* -------------------------------------------------------------- */
/* Macro/Function or variable definition */

definition
        : opt_global DEFINE SYMBOL '('
	| function_start ';'		/* function declaration */
	| function_start block			/* function definition */
	| opt_global_identifier '=' expression ';'		/* variable definition */
	;


/*------------------------------------------------------
  function definition start
  [global] [define] type identifier '(' [type identifier]* ')

  enter function type+identifier to local/global symbol
  table.
  Enter (list of) formal parameters type+symbol to
  private symbol table to have them available when
  parsing the (perhaps following) definition block.

  $$.c = YFunction
  $$.v.tval = TableEntry() (->sentry->code() == YFunction
  $$.t = declared_return_type for current block
  $$.l = symbol definition line
*/

function_start
        : opt_global_identifier '(' tupletypes ')'
	;

/*--------------------------------------------------------------
  identifier, optionally prepended by 'global' or
  'define' or 'global define'
  $$.v.tval == entry
  $$.t = type
  $$.l = line of identifier
*/

opt_global_identifier
        : opt_global opt_define type SYMBOL
	  { result = val[3] }
	;

opt_global
	: /* empty */
        | GLOBAL
	;

opt_define
        : /* empty */
	| DEFINE
	;

/*----------------------------------------------*/
/* zero or more formal parameters		*/
/* $$.c = undef					*/
/* $$.t = Type::Unspec if error, any valid type otherwise	*/
/* $$.v.fpval = pointer to formalparam_t chain	*/

tupletypes
        : /* empty  */
	| tupletype
	;

/*----------------------------------------------*/
/* one or more formal parameters		*/
/* $$.v.fpval = pointer to formalparam_t chain	*/

tupletype
        : formal_param
	| tupletype ',' formal_param
	;

/*----------------------------------------------*/
/* single formal function parameter		*/
/* $$.v.fpval = pointer to formalparam_t	*/

formal_param
        : type SYMBOL
	;

/* -------------------------------------------------------------- */
/* Assignment */

assignment
        : identifier '=' expression
	| identifier '[' list_elements ']' '=' expression
	;

/* ----------------------------------------------------------*/

/* allow multi line strings  */
string
        : C_STRING
	| string C_STRING
	;

constant
        : C_VOID
	| C_BOOLEAN
	| C_INTEGER
	| C_FLOAT
	| C_STRING
	| C_BYTEBLOCK
	| path
	| C_SYMBOL
	;

path
        : path_element
	| path path_element
	  { result = val[0] + val[1] }
	;
	
path_element
        : C_PATH
	| '.' string
	| '.'
	;

/* -------------------------------------------------------------- */
/* List expressions */

list
        : '[' ']'
	| '[' list_elements opt_comma ']'
	;

list_elements
        : expression
	| list_elements ',' expression
	;

	/* optional comma  */
opt_comma
        : ','
	| /* empty */
	;

/* -------------------------------------------------------------- */
/* Map expressions */

map
        : MAPEXPR ']'					/* empty map */
	| MAPEXPR map_elements opt_comma ']'
	;

map_elements
        : expression ':' expression
	| map_elements ',' expression ':' expression
	;

/* -------------------------------------------------------------- */
/*
   Function call

   initial parse of 'term_name (' triggers first type checking
   and lookup of term_name so parameters can be checked against
   prototype.

   function_call: term_name[$1] '('[2] {lookup prototype}[$3] parameters[$4] ')'[$5] {check parameters}

*/

function_call
        : function_name '(' parameters ')'
	;

/*
   function call parameters

   attach parameters directly to function, thereby using the type information
   from the function in deciding how to treat parameters.

   since we're using the $0 feature of bison here, we can't
   split up this BNF further :-(

   $0 refers to $3 of the 'function_call' rule, ie $0.c is the function (one of 4 kinds)

   return $$.t == 0 on error, $$.c == 0 if empty
 */

parameters
        : /* empty  */
	| type identifier
	| expression
	| parameters ',' type identifier
	| parameters ',' expression
	;

/* -------------------------------------------------------------- */
/*
   function name

   might be a known identifier (normal function call)
   or a symbol constant (YCP Term)

/* -> $$.v.tval == TableEntry if symbol already declared ($$.t != Type::Unspec)
      $$.v.nval == charptr if symbol undefined ($$.t == Type::Unspec)
      $$.t = Type::Unspec for SYMBOL, "|" for builtin, else type
 */

function_name
        : identifier
	| C_SYMBOL
	;

/* -------------------------------------------------------------- */
/* Identifiers (KNOWN and UNKNOWN symbols) */
/* -> $$.v.tval == TableEntry if symbol already declared ($$.t != Type::Unspec)
      $$.v.nval == charptr if symbol undefined ($$.t == Type::Unspec)
      $$.t = Type::Unspec for SYMBOL, "|" for builtin, else type
 */

identifier
        : SYMBOL
	;

identifier_list
        : identifier
	| identifier ',' identifier_list
	;

end

---- header ----

# rbycp.rb - generated by racc

require 'strscan'
require 'ycpscanner'
require 'pathname'

---- inner ----

include Ycpscanner

def initialize debug, includes
  @yydebug = debug
  @includes = includes
  @lineno = 1
  @file = nil
  @name = nil
  @sstack = []
  @seen = Hash.new
  @in_comment = false
  @symbols = Hash.new
end

def open name, is_module = false
#  $stderr.puts "\tXopen #{name}"
  if name.kind_of? IO
    file = name
  else
    p = Pathname.new name
    @seen[name] = p
    file = nil
    f = nil
    @includes.each do |incdir|
      f = incdir + p
#      $stderr.puts "Trying #{f}"
      file = File.open( f ) if File.readable?( f )
      break if file
    end
    return unless file || !is_module  # ignore built-in modules
    raise "Cannot open \"#{name}\"" unless file
#    $stderr.puts "\topen #{f}"
  end
  str = file.read
  file.close unless file == $stdin
  raise "Read error #{name}" unless str
  @sstack << [ @scanner, @name, @lineno ] if @scanner
  @scanner = StringScanner.new(str)
  @name = name
  @lineno = 1
#  $stderr.puts "#{@scanner}:#{@name}"
end

---- footer ----

help = false
debug = false
includes = [Pathname.new "."]
ycpfile = nil

while ARGV.size > 0
  opt = ARGV.shift
#  $stderr.puts "opt<#{opt}>"
  case opt
    when "-h":
      $stderr.puts "Ruby YCP compiler"
      $stderr.puts "rbycp [-h] [-d] [-I <dir>] [<ycpfile>]"
      $stderr.puts "Compiles <ycpfile>"
      $stderr.puts "\t-h  this help"
      $stderr.puts "\t-d  debug"
      $stderr.puts "\t-I <dir>  include dir"
      $stderr.puts "\t<ycpfile>  file to read (else use $stdin)"
      exit 0
    when "-d": debug = true
    when "-I"
      includes << Pathname.new(ARGV.shift)
    when /^-.+/
      $stderr.puts "Undefined option #{opt}"
    else
      $stderr.puts "Multiple input files given, discarding previous #{ycpfile}" if ycpfile
      ycpfile = opt
  end
end

parser = Ycpparser.new debug, includes

ycpfile = $stdin unless ycpfile

begin
  val = parser.parse( ycpfile )
  puts "Accept!"
#rescue ParseError
#  puts "Line #{@lineno}:"
#  puts $!
#  exit 1
#rescue Exception => e
#  puts "Exception: #{e}"
#  exit 1
end
#exit 0

module Ycpscanner
  def fill_queue
    if @file.eof?
#      $stderr.puts "eof ! #{@fstack.size}"
      @file.close unless @file == $stdin
      unless @fstack.empty?
	@file, @name, @lineno = @fstack.shift
#	$stderr.puts "fill! #{@fstack.size}, #{@file}@#{@lineno}"
        return fill_queue
      end
      @q.push [false, false]
      return false
    end
    str = @file.gets
    return true unless str
    @lineno += 1

#    $stderr.puts "fill_queue(#{str})"

    scanner = StringScanner.new(str.chomp!)

    until scanner.empty?
#      $stderr.puts "#{@q.size}:\"#{scanner.rest}\""
      if @in_comment
	if scanner.scan(%r{.*\*/})
	  @in_comment = false
	else
	  break
	end
      end

      case
      when scanner.scan(/\s+/)
	next        # ignore space
	
      when m = scanner.scan(%r{^#.*$})
	next
	
      when m = scanner.scan(%r{^//.*$})
	next

      when m = scanner.scan(/\n+/)
	@lineno += m.size
	next        # ignore newlines

      when m = scanner.scan(%r{/\*})
        @in_comment = true
	
      when m = scanner.scan(%r{//.*})
	next        # c++ style comment

      # decimalValue = [ "+" | "-" ] ( positiveDecimalDigit *decimalDigit | "0" )
      # decimalDigit = "0" | positiveDecimalDigit
      when m = scanner.scan(%r{(\+|-)?\d+})
	@q.push [:C_INTEGER, m.to_i]

      # hexValue = [ "+" | "-" ] [ "0x" | "0X"] 1*hexDigit
      #      hexDigit = decimalDigit | "a" | "A" | "b" | "B" | "c" | "C" | "d" | "D" | "e" | "E" | "f" | "F"
      when m = scanner.scan(%r{(\+|-)?(0x|0X)([0123456789]|[abcdef]|[ABCDEF])+})
	@q.push [:C_INTEGER, m.to_i]

      # octalValue = [ "+" | "-" ] "0" 1*octalDigit
      when m = scanner.scan(%r{(\+|-)?0[01234567]+})
	@q.push [:C_INTEGER, m.to_i]

      #	binaryValue = [ "+" | "-" ] 1*binaryDigit ( "b" | "B" )
      when m = scanner.scan(%r{(\+|-)?(0|1)(b|B)})
	@q.push [:C_INTEGER, m.to_i]
	
      #      realValue = [ "+" | "-" ] *decimalDigit "." 1*decimalDigit
      #      [ ( "e" | "E" ) [ "+" | "-" ] 1*decimalDigit ]

      when m = scanner.scan(%r{(\+|-)?\d*\.\d+})
	@q.push [:C_FLOAT, m.to_f]

      #      charValue = // any single-quoted Unicode-character, except single quotes
      
      when m = scanner.scan(%r{\'([^\'])\'})
	@q.push [:C_CHAR, scanner[1]]

      #      stringValue = 1*( """ *ucs2Character """ )
      #      ucs2Character = // any valid UCS-2-character

      when m = scanner.scan(%r{\"([^\\\"]*)\"})
	@q.push [:C_STRING, scanner[1]]

      # string with embedded backslash
      when m = scanner.scan(%r{\"(.*\\.*)\"})
#	$stderr.puts ":string(#{scanner[1]})"
	@q.push [:C_STRING, scanner[1]]

      when m = scanner.scan(%r{#\[(.*)\]})
	@q.push [:C_BYTEBLOCK, scanner[1]]
      
      when m = scanner.scan(%r{(\.\w)+})
	@q.push [:C_PATH, scanner[1]]
      when m = scanner.scan(%r{\`\w})
	@q.push [:C_SYMBOL, scanner[1]]
      when m = scanner.scan(%r{(\w::)+\w})
	@q.push [:C_NAMESPACE, scanner[1]]
      when m = scanner.scan(%r{::\w})
	@q.push [:C_GLOBAL, scanner[1]]
      when m = scanner.scan(%r{_\(})
	@q.push [:I18N, scanner[1]]
      when m = scanner.scan(%r{\$\[})
	@q.push [:MAPEXPR, scanner[1]]
      when m = scanner.scan(%r{==})
	@q.push [:EQUALS, scanner[1]]
      when m = scanner.scan(%r{\<=})
	@q.push [:LE, scanner[1]]
      when m = scanner.scan(%r{\>=})
	@q.push [:GE, scanner[1]]
      when m = scanner.scan(%r{\<\>})
	@q.push [:NEQ, scanner[1]]
      when m = scanner.scan(%r{\<\<})
	@q.push [:LEFT, scanner[1]]
      when m = scanner.scan(%r{\>\>})
	@q.push [:RIGHT, scanner[1]]
      when m = scanner.scan(%r{\&\&})
	@q.push [:AND, scanner[1]]
      when m = scanner.scan(%r{\|\|})
	@q.push [:OR, scanner[1]]
      when m = scanner.scan(%r{\]:})
	@q.push [:CLOSEBRACKET, scanner[1]]
      when m = scanner.scan(%r{::})
	@q.push [:DCOLON, m]
	
      when m = scanner.scan(%r{\w+})
	case m
	when "false": @q.push [:C_BOOLEAN, false]
	when "true": @q.push [:C_BOOLEAN, true]
	when "empty": @q.push [:EMPTY, m]
	  
	when "define": @q.push [:DEFINE, m]
	when "undefine": @q.push [:UNDEFINE, m]
	when "import": @q.push [:IMPORT, m]
	when "export": @q.push [:EXPORT, m]
	when "include": @q.push [:INCLUDE, m]
	when "static": @q.push [:STATIC, m]
	when "extern": @q.push [:EXTERN, m]
	when "module": @q.push [:MODULE, m]
	when "const": @q.push [:CONST, m]
	when "typedef": @q.push [:TYPEDEF, m]
	when "textdomain": @q.push [:TEXTDOMAIN, m]
	  
	when "return": @q.push [:RETURN, m]
  	when "continue": @q.push [:CONTINUE, m]
	when "break": @q.push [:BREAK, m]
	when "if": @q.push [:IF, m]
	when "else": @q.push [:ELSE, m]
	when "is": @q.push [:IS, m]
	when "do": @q.push [:DO, m]
	when "while": @q.push [:WHILE, m]
	when "repeat": @q.push [:REPEAT, m]
	when "until": @q.push [:UNTIL, m]
	when "lookup": @q.push [:LOOKUP, m]
	when "select": @q.push [:SELECT, m]
	when "switch": @q.push [:SWITCH, m]
	when "case": @q.push [:CASE, m]
	when "default": @q.push [:DEFAULT, m]
	when "foreach": @q.push [:FOREACH, m]

	when "list": @q.push [:LIST, m]
	when "map": @q.push [:MAP, m]
	  
	when "any": @q.push [:C_TYPE, m]
	when "void": @q.push [:C_TYPE, m]
	when "boolean": @q.push [:C_TYPE, m]
	when "integer": @q.push [:C_TYPE, m]
	when "string": @q.push [:C_TYPE, m]
	when "byteblock": @q.push [:C_TYPE, m]
	when "locale": @q.push [:C_TYPE, m]
	when "term": @q.push [:C_TYPE, m]
	when "path": @q.push [:C_TYPE, m]
	when "smbol": @q.push [:C_TYPE, m]
	else
	  @q.push( [:IDENTIFIER, m] )
	end # case m
      
      when m = scanner.scan(%r{[<>(){}\[\],;#=\|\&!^~\?\+\-\*\/\%]})
	@q.push [m, m]
	
      else
	raise "**** Unrecognized(#{scanner.rest})" unless scanner.rest.empty?
      end # case
    end # until scanner.empty?
#    $stderr.puts "scan done, @q #{@q.size} entries"
    true
  end

  def parse( file )
    open file
    @q = []
    do_parse
  end

  def next_token
    while @q.empty?
      break unless fill_queue 
    end
#    $stderr.puts "next_token #{@q.first.inspect}"
    @q.shift
  end
  
  def on_error(*args)
    $stderr.puts "Err #{@name}@#{@lineno}: args=#{args.inspect}"
    raise
  end

end # module

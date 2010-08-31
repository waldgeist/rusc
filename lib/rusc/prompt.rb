require "rusc/functions.rb"

class RuscWindowPrompt < RuscWindow
	include RuscFunctions
	attr_accessor :content, :curpos, :w

	def initialize( *args )
		init_colors()
		@args	= *args
		@wrows	= @args[0]
		@wcols	= @args[1]
		@w		= Ncurses::WINDOW.new( *@args )
		@curpos = 0
		@content = @leftstring = @rightstring = ""
		$command_list = [ "e", "w", "open", "write", "wq", "wqall"]
		reset()
		info( "Hello!" )
		@w.wrefresh()
	end

	def add_string( string )
		y = 0;
		mv_print_color( y, @curpos, "%s", string )
		@curpos += string.length
		rewin()
	end

	def do_function( input_line )
		input_parts = input_line.split( " " )
		myfunc = input_parts.shift 
		if method.exists?( myfunc )
			myfunc( input_parts )
		else 
			error( "#{myfunc} does not exist!" )
		end
	end

	def get_user_input( ch )			# Get line input
		@leftstring  = @content[ 1 .. ( @curpos - 1 ) ]
		@rightstring = ( @curpos == @content.length ) ? "" : @content[ @curpos .. -1 ]
		case ch
		when -1
			sleep @@sleep_time
		when 27		# KEY_ESC
			return [ "NEXT WINDOW",	"" ] 
		when KEY_LEFT
			@curpos = ( @curpos == 1 ) ? 1 : @curpos - 1
			@w.move(0, @curpos)
		when KEY_RIGHT
			@curpos = ( @curpos == @content.length ) ? @curpos : @curpos + 1 
			@w.move(0, @curpos)
		when KEY_ENTER, ?\n, ?\r
			case @content[0]
			when "/", ?/, 47 
				@content = @content[ 1 .. -1 ]	# @content is a string, so i use this method instead of shift
				if @content.length == 0
					return [ "NEXT WINDOW", "" ] 
				else 
					regexp  = Regexp.new( @content )
					return [ "DO SEARCH", regexp ] 
				end
			when "?", ??
				@content = @content[ 1 .. -1 ]
				return [ "NEXT WINDOW", "" ] if @content.length == 0
				regexp  = Regexp.new( @content )
				return [ "DO REVERSE SEARCH", regexp ] 
			when ":", ?:, 58
				@content = @content[ 1 .. -1 ]
				if @content.length == 0
					return [ "NEXT WINDOW",  "" ]		
				elsif @content =~ /\A[a-zA-Z]{1,2}\d+\Z/	# matches A1..ZZ9999 or so
					return [ "GO TO CELL",   @content ] 
				elsif @content =~ /\A\d+\Z/					# matches 1...99
					return [ "GO TO BUFFER", @content ] 
				else
					return [ "DO COMMAND",   @content ]		
				end
			end
		when ?\t
			if @content[0].chr == ":"
				@cwords = @leftstring.split()
				if @cwords.length == 1
					do_complete( @cwords[0]   , mode = "command" )
				else
					do_complete( @cwords[ -1 ], mode = "path"    )
				end
			else
				sleep @@sleep_time
			end
		when 127	# DEL
			@rightstring = @rightstring[ 1 .. -1 ] unless @rightstring.length == 0
			@content = @content[0].chr + @leftstring + @rightstring
		when KEY_BACKSPACE, 263
			@leftstring.chop! unless @leftstring.length == 0
			@content = @content[0].chr + @leftstring + @rightstring
			@curpos -= 1
		else
			if ch < 256 and ch > 0
				@leftstring += ch.chr
				@content = @content[0].chr + @leftstring + @rightstring
				@curpos += 1
			end
		end
		mv_print_color( 0, 1, "%#{@content.length}s", " ", "" )
		mv_print_color( 0, @leftstring.length + 1, "%s", "#{ @rightstring }", "" )
		mv_print_color( 0, 0, "%#{@leftstring.length}s", "#{@content[0].chr}#{ @leftstring }", "" )
		@frame.rewin
		rewin()
		return ["LOOP"]
	end

	def do_complete( string, mode )
		case mode
		when "command"
			results = []
			$command_list.each do |cmd|
				results << cmd if cmd.match( /^#{string}/ ) # and cmd != string		# ?
			end
			if results.length == 1
				return results 
			else 
				# TODO : Open a popup / select window ?!
			end
		when "path"
			# TODO
		end
	end

	def info( string )
		reset()
		y = 0; @curpos = 1
		mv_print_color( y, @curpos, "%s", string )
		@curpos += string.length
		rewin()
	end

	def error( msg )
		reset()
		y = 0; x = 0
		mv_print_color( y, x, "ERROR: %s", msg )
		rewin()
	end

	def clear()
		mv_print_color( 0, 0, "%-#{@wcols - 1}s", " " )
		@curpos = 0
	end

	def reset()
		@curpos = 1
		mv_print_color( 0, 1, "%-#{@wcols - 1}s", " " )
	end

end


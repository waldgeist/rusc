require 'functions.rb'

class RuscWindow 
	include Ncurses
	attr_accessor :error_window, :frame
	attr_reader :w
	@@sleep_time = 0.02
	@@encoding = "UTF-8"

	def initialize(*args)
		init_colors()
		@args   = *args
		@wrows  = @args[0]
		@wcols  = @args[1]
		@w = Ncurses::WINDOW.new(*@args)
		@wrows = 0
		@wcols  = 0
		rewin()
	end

	def init_colors()
		@colors = {
		  "none"		=>  0,
		  "white_blue"	=>  1, "red_white"		=>  2, 
		  "white_red"   =>  3, "black_yellow"	=>  4,
		  "black_cyan"	=>  5, "red_cyan"		=>  6,
		  "white_black" =>  7, "red_black"		=>  8,
		  "black_white" =>	9
		}
	end

	def input_loop()
		loop do
			data = get_user_input( @w.getch() )
			rewin()
			unless data[0] == "LOOP"
				return data # something the top loop got to handle
			end
		end
	end

	def mv_print_color( y, x, format, str, color="none" )
		if @@encoding == "UTF-8"	# get rid of control characters
			r = Regexp.new('[[:cntrl:]]', nil, 'U')
		else
			r = Regexp.new('[[:cntrl:]]')
		end
		str.gsub!(r,'?')
		if color == "reverse" || ( not Ncurses::has_colors?() )
			@w.wattron( Ncurses::A_REVERSE )
			@w.mvwprintw(y, x, format, str)
			@w.wattroff(Ncurses::A_REVERSE )
		elsif Ncurses::has_colors?() && color != "none"
			color_n = @colors[color] || 0
			@w.wattron(Ncurses::COLOR_PAIR(color_n));
			@w.mvwprintw(y, x, format, str)
			@w.wattroff(Ncurses::COLOR_PAIR(color_n));
		else
			@w.mvwprintw(y, x, format, str)
		end
	end

	def rewin()
		@w.wrefresh()
	end 

	def delwin()
		@w.delwin()
	end

end



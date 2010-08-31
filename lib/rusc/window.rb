require 'rusc/functions.rb'

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
    @stack = [] # RK added for keys - to get complex keys - is this not called ???
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

  # added RK
  # trap C-c and return 3 so program does not crash
  def getch
    @w.getch
  rescue Interrupt => ex
    3 # is C-c
  end
    # returns control, alt, alt+ctrl, alt+control+shift, F1 .. etc
    # ALT combinations also send a 27 before the actual key
    # Please test with above combinations before using on your terminal
    # added by rkumar 2008-12-12 23:07 
    def getchar 
      while true 
        ch = getch
        #$log.debug "window getchar() GOT: #{ch}" if ch != -1
        if ch == -1
          # the returns escape 27 if no key followed it, so its SLOW if you want only esc
          if @stack.first == 27
            #$log.debug " -1 stack sizze #{@stack.size}: #{@stack.inspect}, ch #{ch}"
            case @stack.size
            when 1
              @stack.clear
              return 27
            when 2 # basically a ALT-O, this will be really slow since it waits for -1
              ch = 128 + @stack.last
              @stack.clear
              return ch
            when 3
              $log.debug " SHOULD NOT COME HERE getchar()"
            end
          end
          @stack.clear
          next
        end
        # this is the ALT combination
        if @stack.first == 27
          # experimental. 2 escapes in quick succession to make exit faster
          if ch == 27
            @stack.clear
            return ch
          end
          # possible F1..F3 on xterm-color
          if ch == 79 or ch == 91
            #$log.debug " got 27, #{ch}, waiting for one more"
            @stack << ch
            next
          end
          #$log.debug "stack SIZE  #{@stack.size}, #{@stack.inspect}, ch: #{ch}"
          if @stack == [27,79]
            # xterm-color
            case ch
            when 80
              ch = KEY_F1
            when 81
              ch = KEY_F2
            when 82
              ch = KEY_F3
            when 83
              ch = KEY_F4
            end
            @stack.clear
            return ch
          elsif @stack == [27, 91]
            if ch == 90
              @stack.clear
              return 353 # backtab
            end
          end
          # the usual Meta combos. (alt)
          ch = 128 + ch
          @stack.clear
          return ch
        end
        # append a 27 to stack, actually one can use a flag too
        if ch == 27
          @stack << 27
          next
        end
        return ch
      end
    end

end



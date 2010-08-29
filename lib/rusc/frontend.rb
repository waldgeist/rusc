require "general.rb"
require "frame.rb"

class RuscFrontend
	include Ncurses
	attr_accessor :colors 
	def initialize()
		$screencols  = 0
		$screenlines = 0
		@buffers = @windows = []
		@open_files = []
	end

	def init_curses()
		Ncurses.initscr
		Ncurses.cbreak                   # provide unbuffered input
		Ncurses.nonl                     # turn off newline translation
		Ncurses.noecho                   # turn off input echoing
		Ncurses.stdscr.intrflush(false)  # turn off flush-on-interrupt
		Ncurses.stdscr.keypad(true)      # turn on keypad mode
		Ncurses.stdscr.scrollok(true)
		Ncurses::nodelay(Ncurses::stdscr, TRUE)
		Ncurses::curs_set(1)			# 0: invisible cursor, 1: visible cursor
		if Ncurses::has_colors?()
			Ncurses::use_default_colors()
			Ncurses::start_color()
			Ncurses::init_pair(1, Ncurses::COLOR_WHITE, Ncurses::COLOR_BLUE)
			Ncurses::init_pair(2, Ncurses::COLOR_RED  , Ncurses::COLOR_WHITE)
			Ncurses::init_pair(3, Ncurses::COLOR_WHITE, Ncurses::COLOR_RED)
			Ncurses::init_pair(4, Ncurses::COLOR_BLACK, Ncurses::COLOR_YELLOW)
			Ncurses::init_pair(5, Ncurses::COLOR_BLACK, Ncurses::COLOR_CYAN)
			Ncurses::init_pair(6, Ncurses::COLOR_RED  , Ncurses::COLOR_CYAN)
			Ncurses::init_pair(7, Ncurses::COLOR_WHITE, Ncurses::COLOR_BLACK)
			Ncurses::init_pair(8, Ncurses::COLOR_RED  , Ncurses::COLOR_BLACK)
			Ncurses::init_pair(9, Ncurses::COLOR_BLACK, Ncurses::COLOR_WHITE)
		end
		$screencols  = Ncurses.COLS
		$screenlines = Ncurses.LINES
	end

	def shutdown()
		Ncurses.echo
		Ncurses.nocbreak
		Ncurses.nl
		Ncurses.endwin
	end

	def error( message )
		$logger.info "INFO: #{message}"
		@error_window.error( message )
	end

	def start()
		@buffers    = Array.new
		@buffers[0] = RuscWindowFrame.new( filename="", [ $screenlines - 1, $screencols, 0, 0 ] )
		$prompt		= RuscWindowPrompt.new( [ 1, $screencols , $screenlines -1 , 0] )
		@open_files << @buffers[ 0 ].filename
		$curbuf = @buffers[ 0 ]
		@error_window = $prompt
		$prompt.frame = $curbuf
		@windows << $curbuf << $prompt 
		@windows.each do |w|
			 w.error_window = @error_window	
			 w.w.keypad(true)
			 w.w.nodelay(true)
		end
	end

	def looping()
		@curwin = 0
		@window_history = []
		loop do													# main loop
			begin
				@w = @windows[ @curwin ]						# pass to current window
				@toggle = @w.input_loop()
				case @toggle[ 0 ]
				when "QUIT"
					break										# ask for saving?
				when "NEXT WINDOW"
					next_window()
					$prompt.content = @toggle[ 1 ]				# receive argument(s)
					@windows[ 1 ].reset
					@windows[ 1 ].rewin
				when "LIST BUFFERS" 
					# TODO ...
				when "SELECT BUFFER" 
					select_buffer( @toggle[ 1 ] )
					# TODO ...
				when "DO SEARCH"
					$curbuf.search_cell( @toggle[ 1 ] )
					next_window()
					$curbuf.search_expr   = @toggle[ 1 ]		# for next/prev. search result
					$curbuf.reverse_search = false 
					$prompt.content = ""						# don't know why, but this is necessary
					# @w.search_cell( @toggle[ 1 ] )
				when "DO REVERSE SEARCH"
					$curbuf.search_cell( @toggle[ 1 ], reverse = true )
					next_window()
					$curbuf.reverse_search = true 
					$curbuf.reverse_search = true 
					$prompt.content = ""	
				when "DO COMMAND" 
					received	= @toggle[ 1 ].split( " " )
					@command	= received.shift
					@attributes	= received
					case @command
					when "e", "open" 
							$curbuf.send( "import_csv",  @attributes[0].to_s )	# TODO: check if opened yet
					when "w", "write"
						$curbuf.send( "export_csv", @attributes.to_s )			# TODO: read only?
					when "pwd"
						$prompt.content = Dir.getwd()
						$prompt.w.wrefresh()
					end
					next_window()
					$prompt.content = ""	# don't know why this is necessary
				when "GO TO CELL"	
					$curbuf.send( "go_to_cell", @toggle[ 1 ] )
					next_window()
					$prompt.content = ""	# don't know why this is necessary
				when "SHELL"
				  Ncurses.def_prog_mode            # save current tty modes
				  Ncurses.endwin                   # restore original tty modes
				  system( "$SHELL" )
				  @windows.each do |w| 
					  w.w.refresh 
				  end
				else
					error( *@toggle[ 1 ] )
				end
				Ncurses.refresh()
			rescue => e		
				$logger.error e.inspect
				error( e.message )
			end
		end
	end

	def select_buffer( num )
		return false if num < 0 or num > ( @buffers.length - 1 )
		# @lastbuffer = @frame
		@frame = @buffers[ num ]
		@lastbuffer = $curbuf
		$curbuf = @buffers[ num ]
	end

	def next_window()
		if @windows.length <= @curwin + 1
			@curwin = 0
		else
			@curwin += 1
		end
		@windows[ 1 ].reset
		@windows.each do |w| 
			w.rewin 
		end
	end

end


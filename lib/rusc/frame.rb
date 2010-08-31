require "rusc/window.rb"
require "rusc/functions.rb"

# 2009-10-04 14:13 added RK after suggestion on http://www.ruby-forum.com/topic/196618#856703
# these are for 1.8 compatibility
class Fixnum
   def ord
     self
   end
## mostly for control and meta characters
   def getbyte(n)
     self
   end
end unless "a"[0] == "a"
   

class RuscWindowFrame < RuscWindow
	include RuscFunctions
	attr_accessor :reverse_search, :search_expr, :c, :curcell, :filename

	def initialize( filename= "", *args)
		init_colors()
		@filename = filename
		@args	= *args
		@wrows	= @args[0]
		@wcols	= @args[1]
		@absmaxcol	= 702								# maximum colum-number: ZZ (base 26) 
		@w		= Ncurses::WINDOW.new(*@args)
		@m = @M = Hash.new()							# Hash of (global) Cell-Markers, vim-like
		@search_expr = Regexp.new("")								  
		@status_info = ""
		@reverse_search = false								  
		init_table()
		write_all_cells()
		update_status_bar()
		# test()
		@w.wrefresh
    @stack = [] # RK added for keys - to get complex keys  - i put here since super not called
    # XXX Have you called super() so that parents initialize can get called - RK
	end

	def currow( cell = @curcell )
		return cellidx_to_rowcol( cell )[ :row ]
	end

	def curcol( cell = @curcell )
		return cellidx_to_rowcol( cell )[ :col ]
	end

	def init_table()
		@maxrow			= 100		# default rows at startup
		@maxcol			= 30		# default cols at startup
		@defwidth		= 10		# default column width
		@navlines		= 2			# rows reserved for infos and column numbers
		@navcols		= 3			# columns reserved for row numbers 
		@cols_on_win	= ( @wcols - @navcols ) / @defwidth 
		@rows_on_win	=   @wrows - @navlines  
		@curfirstrow	= 1
		@curfirstcol	= 1
		@curlastrow		= @wrows - @navlines
		@curlastcol		= ( @wcols - @navcols ) / @defwidth 
		@maxrow			= @curlastrow > @maxrow ? @curlastrow : @maxrow		# can more then 100 lines be displayed on currend window?
		@maxcol			= @curlastcol > @maxcol ? @curlastcol : @maxcol		# can more then  30 cols  be displayed on currend window?
		@c = Hash.new														# @c : Hash with cellidxs as keys and Cell-Instances as 'values'
		0.upto( @maxrow ) do |newrow|
			0.upto( @maxcol ) do |newcol|
				@c[ cellidx( newrow , newcol ) ]			= RuscWindowFrameCell.new( cellidx( newrow, newcol ), @defwidth)
				# @c[ cellidx( newrow	, newcol ) ].content	= "ABC#{newrow}-#{newcol}"		# for testing reasons: auto-fill content
				@c[ cellidx( 0		, newcol ) ].content	= cellidx( nil, newcol ) 	# colname
				@c[ cellidx( 0		, newcol ) ].color		= "black_white"
			end
			@c[ cellidx( newrow, 0 ) ].content	= cellidx( newrow, nil )				# rownum
			@c[ cellidx( newrow, 0 ) ].color	= "black_white"
			@c[ cellidx( newrow, 0 ) ].width	= @navcols
		end
		@c[ cellidx( 0, 0 ) ].content	= ""				
		@selected_cells = Array.new()	# array of selected cells' keys
		@curcell = cellidx( 1, 1 )
		mark_cell( @curcell )
		@last_line_with_content = 0
	end

	def grow_table( newrows=30, newcols=15 )
		if @curlastcol >= @absmaxcol and newcols >= 0 	
			@error_window.error( "no more cols! limit reached!" )
			return false 
		end
		newmaxcol = @maxcol + newcols
		newmaxrow = @maxrow + newrows 
		newmaxcol = @absmaxcol if newmaxcol > @absmaxcol
		if newmaxcol > @maxcol								# adding cols..
			0.upto( @maxrow ) do |row|
				@maxcol.upto( newmaxcol ) do |col|
					@c[ cellidx( row , col ) ]				= RuscWindowFrameCell.new( cellidx( row, col ), @defwidth)
					@c[ cellidx( 0		, col ) ].content	= cellidx( nil, col )		
					@c[ cellidx( 0		, col ) ].color		= "black_white"
				end
			end
			@maxcol = newmaxcol
		elsif newmaxrow > @maxrow							# adding rows..
			@maxrow.upto( newmaxrow ) do |row|
				0.upto( @maxcol ) do |col|
					@c[ cellidx( row , col ) ]				= RuscWindowFrameCell.new( cellidx( row, col ), @defwidth)
				end
				@c[ cellidx( row, 0 ) ].content	= cellidx( row, nil ) 
				@c[ cellidx( row, 0 ) ].color	= "black_white"
				@c[ cellidx( row, 0 ) ].width	= @navcols
			end
			@maxrow = newmaxrow
			if @navcols < ( @maxrow.to_s.length + 1 )
				@navcols = @maxrow.to_s.length + 1
				0.upto( @maxrow ) do |row|
					@c[ cellidx( row, 0 ) ].width	= @navcols
				end
			end
		end
	end

	def insert_cell( num ) 
		unmark_cell()
		if @curlastcol + num > @absmaxcol 
			@error_window.error( "no more cols! limit reached!" ) 
			return false
	    end
		if num > 0
			last_col_with_content( currow() ).downto( curcol() ) do |col| 
				@c.rename( cellidx( currow(), col ), cellidx( currow(), col + num ) )
				@c[ cellidx( row , col ) ] = RuscWindowFrameCell.new( cellidx( row, col ), @defwidth)
			end
		else
			curcol().upto( last_col_with_content( currow() ) ) do |col|
				@c.rename( cellidx( currow(), col ), cellidx( currow(), col + num ) )
			end 
		end
		mark_cell( @curcell )
		write_all_cells()
	end

	def insert_col( num, delta ) 
		# insert col before current col if delta == 0
		unmark_cell()
		if @curlastcol + num > @absmaxcol 
			@error_window.error( "no more cols! limit reached!" ) 
			return false
	    end
		last_row_with_content().downto( 1 ) do |row|
			last_col_with_content( row ).downto( curcol() + delta ) do |col|
				@c.rename( cellidx( row, col ), cellidx( row, col + num ) )
				@c[ cellidx( row , col ) ] = RuscWindowFrameCell.new( cellidx( row, col ), @defwidth)
			end
		end
		motion( 0, delta ) 
		mark_cell( @curcell )
		write_all_cells()
	end

	def insert_row( num, delta ) 
		# insert row before current row if delta == 0
		unmark_cell()
		last_row_with_content().downto( currow() + delta ) do |row|
			last_col_with_content( row ).downto( 1 ) do |col|
				@c.rename( cellidx( row, col ), cellidx( row + num, col ) )
				@c[ cellidx( row , col ) ] = RuscWindowFrameCell.new( cellidx( row, col ), @defwidth)
			end
		end
		motion( delta, 0 ) 
		mark_cell( @curcell )
		write_all_cells()
	end

	def delete_row( rownum )
		( rownum + 1 ).upto( last_row_with_content() ) do |row|
			1.upto( last_col_with_content( row ) ) do |col|
				@c.rename( cellidx( row, col ), cellidx( row - 1, col ) ) 
				@c[ cellidx( row , col ) ] = RuscWindowFrameCell.new( cellidx( row, col ), @defwidth)
			end
		end
		mark_cell( @curcell )
		write_all_cells()
	end

	def get_user_input( ch )				# Normal Mode character input
		case ch								# http://www.torsten-horn.de/techdocs/ascii.htm
		when -1								# no key input ? sleep..
			sleep @@sleep_time
		when ?\t
			return [ "NEXT WINDOW",	"" ] 
		when KEY_LEFT, ?h
			motion( 0, -1 )
		when 8 # ctrl h
			if curcol() > 3
				motion( 0, -3 )
			else
				motion( 0, -curcol() + 1 )
			end
		when KEY_DOWN, ?j
			motion(  1, 0 )
		when 10 # ctrl j 
			motion(  5, 0 )
		when KEY_UP, ?k
			motion( -1, 0 )
		when 11 # ctrl k
			if currow() > 5
				motion( -5, 0 )
			else
				motion( -currow() + 1, 0 )
			end
		when KEY_RIGHT, ?l, 9
			motion( 0,  1 ) 
		when 12 # ctrl l
			motion( 0,  3 ) 
		when ?0
			motion( 0, - curcol() + 1 )
		when ?$
			motion( 0, last_col_with_content( currow() ) - curcol() - 1 )
		when ?(
			motion( 0, - currow() + prev_blank_field_in_row( currow() ) + 1 )
		when ?)
			motion( 0, next_blank_field_in_row( currow() ) - currow()  )
		when ?{
			motion( prev_blank_field_in_col( currow() ) - currow() , 0 )
		when ?}
			motion( next_blank_field_in_col( currow() ) - currow() , 0 )
		when ?], ?[
			chr = Ncurses.wgetch( @w ) 
			case chr
			when 27		# KEY_ESC
				break
			when ?}
				motion( next_empty_row() - currow(), 0 )	
				break
			when ?{
				motion( -1, 0 )	# da sollte prev_empty_line stehen
				break
			when ?)
				motion( 0, 1 )	# da sollte next_empty_col stehen
				break
			when ?(
				motion( 1, 0 )	# da sollte prev_empty_col stehen
				break
			when KEY_ENTER, ?\n, ?\r
				motion( 1, 0 )
				break
			else
				sleep @@sleep_time
			end
		when ?' # TODO not working yet
			chr = Ncurses.wgetch( @w ) 
			case chr
			when -1
				sleep @@sleep_time
			when 27		# KEY_ESC
				break
			else
				sleep @@sleep_time
			end
		# when ?|
			# motion( next_blank_field_in_col( currow() ) - currow() , 0 )
		when ?a
			insert_col( 1, 1 )
			edit_cell( @curcell ) 
			# @c[ @curcell ].edit()
		when ?A
			motion( 0, last_col_with_content( currow() ) - curcol() -1 )
			insert_col( 1, 1 )
			edit_cell( @curcell ) 
		when ?d
			delete_row( currow() ) 
		when ?s
			edit_cell( @curcell ) 
		when ?g
			motion( - currow() + 1, 0 )
		when ?G
			motion( last_row_with_content() - currow() - 1, 0 )
		when ?H
			motion( - ( currow() - @curfirstrow ), 0 )
		when ?i
			insert_col( 1, 0 )
			edit_cell( @curcell ) 
		when ?L
			motion( @curlastrow - currow() , 0 )
		when ?m		# TODO still experimental
			chr = Ncurses.wgetch( @w ) 
			case chr
			when -1
				sleep @@sleep_time
			when ?a .. ?z
				@c[ @curcell ].marker = chr
				@m[ chr ] = @curcell
			when ?A .. ?Z
				@c[ @curcell ].marker = chr
				@M[ chr ] = File.expand_path( @filename ) + "#" + @curcell
			else 
				break
			end
		when ?'
			chr = Ncurses.wgetch( @w )
			case chr
			when -1
				sleep @@sleep_time
			when ?a .. ?z
				@lastcell = @curcell
				@curcell = @m[ chr ] 
				motion( ( - currow( @lastcell ) + currow() ), ( -curcol( @lastcell ) + curcol() ) )
			when ?A..?Z
			else
				break
			end
		when ?n
				search_cell( @search_expr, @reverse_search )
		when ?N
				search_cell( @search_expr, !( @reverse_search ) ) 
		when ?M
				motion( ( @curlastrow - currow() ) - ( ( @curlastrow - @curfirstrow )  / 2 ) - 1 , 0 )
		when ?O
			insert_row( 1, 0 ) 
			edit_cell( @curcell ) 
		when ?o
			insert_row( 1, 1 ) 
			edit_cell( @curcell ) 
		when ?q, 23 # KEY_CTRL_W
			@error_window.info( "Don't do that! .-" )
			# sleep 1
		    return ["QUIT", ""]
		when ?R
			#
		when ?T
			#
		when ?v		# Start Visual Mode 
			do_visual_mode()
		when ?y
			ncell = next_cell( @curcell, ["A15", "B19", "D5", "X41"])
			motion( -currow() + cellidx_to_rowcol( ncell )[:row] , -curcol() + cellidx_to_rowcol( ncell )[:col] )
		when ?Y
			search_cell( /fo/ )
		when ?x
			@c[ @curcell ].content = "" 
			update_status_bar() 
			write_all_cells()
		when ?/
			return [ "NEXT WINDOW",	"/" ] 
		when ??
			return [ "NEXT WINDOW",	"?" ] 
		when ?:
			return [ "NEXT WINDOW",	":" ] 
		else
		  @error_window.info("NOTHING FOR KEY: #{ch.chr}") 
		end
		return ["LOOP"]
	end


	def do_visual_mode()
		# should this rather be implemented as Proc in order to call it
		# multiple times when necessary? (5j etc)
			@lim_up		= @lim_down		= currow()
			@lim_left	= @lim_right	= curcol()
			loop do
				chr = Ncurses.wgetch( @w ) 
				case chr
				when -1
					sleep @@sleep_time
				when 27, ?v		# KEY_ESC
					unmark_range()
					mark_cell()
					write_all_cells()
					break
				when KEY_LEFT, ?h
					if @lim_left == curcol()
						@lim_left -= 1
					elsif @lim_right == curcol() and @lim_left != @lim_right
						@lim_right -= 1
					end
					motion( 0, -1, visual= true )
					mark_range()
				when KEY_DOWN, ?j
					if @lim_down == currow()
						@lim_down += 1
					elsif @lim_up == currow() and @lim_up != @lim_down
						@lim_up += 1
					end
					motion(  1, 0, visual= true )
					mark_range()
				when KEY_UP, ?k
					if @lim_up == currow()
						@lim_up -= 1
					elsif @lim_down == currow() and @lim_down != @lim_up
						@lim_down -= 1
					end
					motion( -1, 0, visual= true )
					mark_range()
				when KEY_RIGHT, ?l, 9
					if @lim_right == curcol()
						@lim_right += 1
					elsif @lim_left == curcol() and @lim_left != @lim_right
						@lim_left += 1
					end
					motion( 0,  1, visual= true ) 
					mark_range()
				when 10 # ctrl j	# 5x KEY_DOWN	# TODO not working in this way
					if @lim_down == currow() 
						@lim_down += 5
					elsif @lim_up == currow() and @lim_down != @lim_up
						@lim_up -= 5 
						@lim_down = @lim_up + ( @lim_down - @lim_up ) if @lim_up > @lim_down
					end
					motion(  5, 0, visual= true )
					mark_range()
				when 11 # ctrl k	# 5x KEY_UP		# TODO to be fixed
					if @lim_up <= currow() +5
						if @lim_up <= currow()
							@lim_up -= 5
						else 
							@lim_up -=  ( @lim_up - currow() )
						end
					else 
						@lim_up += 5
					end
					motion(  5, 0, visual= true )
					mark_range()
				end
			end
	end


	def mark_range()
		unmark_range()
		@lim_up.upto( @lim_down ) do |row|
			@lim_left.upto( @lim_right ) do |col|
				@c[ cellidx( row, col ) ].selected = true
				@c[ cellidx( row, 0 ) ].selected = true
				@c[ cellidx( 0, col ) ].selected = true
				unless @selected_cells.include?( cellidx( row, col ) ) 
					@selected_cells << cellidx( row, col ) 
					@selected_cells << cellidx( row, 0   ) 
					@selected_cells << cellidx( 0  , col ) 
				end
			end
		end
		write_all_cells()
	end

	def unmark_range()
		@selected_cells.each do |cell|
			@c[ cell ].selected = false
			@c[ cellidx( cellidx_to_rowcol( cell )[:row], 0 ) ].selected = false
			@c[ cellidx( 0, cellidx_to_rowcol( cell )[:col] ) ].selected = false
		end
	end
	
	def edit_cell( cell )
		cell_old_content = @c[ cell ].content
#		@c[ cell ].content = ""

#	update_status_bar()
    config = {}
    config[:default] = cell_old_content
		@status_info = @curcell + " [" + currow().to_s + ", " + curcol().to_s + "]: "
    status, str =  rbgetstr(@w, r=0, c=0, prompt=@status_info, maxlen=80, config)

    if str
      # remove = if first char. If we remove at this point, how will we know alignment
      if str[0,1] == "="
        str.slice!(0,1)
        # we should store attributes for this cell somewhere in hash
      end 
    end

    case status
    when 0
      # go down a cell but no longer in edit mode
      @c[ cell ].content = str
      motion( 1, 0 )
    when :TAB
      # go to next cell and keep editing
      @c[ cell ].content = str
				motion( 0, 1 )
				edit_cell( @curcell )
    end

# RK i hope i have not missed anything from below
#		loop do
##			ch = Ncurses.wgetch( @w ) 
#			ch = @w.getch()
#			case ch		# http://www.asciitable.com/
#			when -1
#				sleep @@sleep_time
#			when 27		# KEY_ESC
#				@c[ cell ].content = cell_old_content 
#				update_status_bar()
#				break
#			when KEY_BACKSPACE, 263
#				@c[ cell ].content.chop!
#			when 9 #ctrl i = TAB 
#				motion( 0, 1 )
#				edit_cell( @curcell )
#				break
#			when KEY_ENTER, ?\n, ?\r
#				if @c[ cell ].content[0] == "="
#					@c[ cell ].content.shift
#					@c[ cell ].content
#				end
#				motion( 1, 0 )
#				break
#			else
#				if ch < 256 and ch > 0	
#				@c[ cell ].content += ch.chr
#				end
#			end
#			cell_xpos = @navcols
      #@curfirstcol.upto( curcol() - 1 ) do |i|
        #cell_xpos +=  @c[ cellidx( currow(), i ) ].width
      #end
      #mv_print_color( currow() + 1, cell_xpos, "%-#{@c[ cell ].width}s", "#{@c[ cell ].content}", "#{@c[ cell ].color}" )
      #update_status_bar()
#		end
#		update_status_bar()
#		write_all_cells() # why writing all cells, should only write changed one RK
	end

# complex version of get_string that allows for trappng of control character
# such as C-c and C-h and TAB for completion
  # and handle all editing events on it.
  # @return status_code, string (0 if okay, 7 if help asked for, :TAB if TAB pressed
  def rbgetstr(win, r, c, prompt, maxlen, config={})
    retcode = 0
    #$logger.debug " inside rbgetstr #{win} r:#{r} c:#{c} p:#{prompt} m:#{maxlen} "
    raise "rbgetstr got no window. io.rb" if win.nil?
    ins_mode = false
    default = config[:default] || ""
    prompt = "#{prompt} [#{default}]: " unless default
    len = prompt.length

    # clear the area of len+maxlen
    color = 7 # $datacolor ??? XXX
    str = default
    clear_this win, r, c, color, len+maxlen+1
    print_this(win, prompt+str, color, r, c)
    len = prompt.length + str.length
    begin
      #Ncurses.echo(); # here it is causing Alt-i to be printed
    curpos = str.length
    prevchar = 0
    entries = nil
    while true
      #ch=win.getchar() # i need to copy this in XXX insert mode will only work, also C-c
      ch=getchar()
      case ch
      when 3 # -1 # C-c
        return -1, nil
      when 10, 13
        #retcode = :ENTER
        break
      when ?\C-h.getbyte(0), ?\C-?.getbyte(0), 127 # delete previous character/backspace
        len -= 1 if len > prompt.length
        curpos -= 1 if curpos > 0
        str.slice!(curpos)
        clear_this win, r, c, color, len+maxlen+1
        #print_this(win, prompt+str, color, r, c)
      when 330 # delete character on cursor
        #len -= 1 if len > prompt.length
        #curpos -= 1 if curpos > 0
        str.slice!(curpos) #rescue next
        clear_this win, r, c, color, len+maxlen+1
      when ?\C-g.getbyte(0)
        #x print_footer_help(helptext)
        helptext = config[:helptext] || "No help provided"
        print_help(win, r, c, color, helptext)
        return 7, nil
      when KEY_LEFT
        curpos -= 1 if curpos > 0
        len -= 1 if len > prompt.length
        win.wmove r, c+len # since getchar is not going back on del and bs
        next
      when KEY_RIGHT
        if curpos < str.length
          curpos += 1 #if curpos < str.length
          len += 1 
          win.wmove r, c+len # since getchar is not going back on del and bs
        end
        next
      when ?\M-i.getbyte(0) 
        ins_mode = !ins_mode
        next
      when 9 # TAB
        retcode = :TAB
        break
      # in rusc we go to next cell rather than do any completion
        #if config
          #if prevchar == 9
            #if !entries.nil? and !entries.empty?
              #str = entries.delete_at(0)
            #end
          #else
            #tabc = config[:tab_completion] unless tabc
            #next unless tabc
            #entries = tabc.call(str)
            #$logger.debug " tab got #{entries} "
            #str = entries.delete_at(0) unless entries.nil? or entries.empty?
          #end
        #end
      else
        #if ch < 0 || ch > 255 # RK in rbcurse it is 255
        if ch < 0 || ch > 127
          Ncurses.beep
          next
        end
        # if control char, beep
        if ch.chr =~ /[[:cntrl:]]/
          Ncurses.beep
          next
        end
        if ins_mode
          str[curpos] = ch.chr
        else
          str.insert(curpos, ch.chr)
        end
        len += 1
        curpos += 1
        break if str.length > maxlen
      end
      print_this(win, prompt+str, color, r, c)
      win.wmove r, c+len # more for arrow keys, curpos may not be end
      prevchar = ch
    end
    str = default if str == ""
    ensure
      Ncurses.noecho();
    end
    return retcode, str
  end
  def clear_this win, r, c, color, len
    print_this(win, "%-*s" % [len," "], color, r, c)
  end
    ##
    # prints given text to window, in color at x and y coordinates
    # @param [Window] window to write to
    # @param [String] text to print
    # @param [int] color such as $datacolor or $promptcolor
    # @param [int] x 
    # @param [int] y 
    # @see Window#printstring
    # Consider using Window#printstring
  def print_this(win, text, color, x, y)
    if(win == nil)
      raise "win nil in printthis"
    end
    #$log.debug " printthis #{win} , #{text} , #{x} , #{y} "
    #I am unable to get the colors due to not being familiar, basically i want white on black
    #color=Ncurses.COLOR_PAIR(color);
    #win.attron(color);
    win.mvprintw(x, y, "%s" % text);
    #win.attroff(color);
    win.refresh
  end
  def print_help(win, r, c, color, helptext)
    print_this(win, "%-*s" % [helptext.length+2," "], color, r, c)
    print_this(win, "%s" % helptext, color, r, c)
    sleep(5)
  end

	def mark_cell( idx=@curcell )
		@c[ idx ].selected = true
		if idx == @curcell
			@c[ cellidx( currow(), 0 ) ].selected = true
			@c[ cellidx( 0, curcol() ) ].selected = true
		else
			@c[ cellidx( cellidx_to_rowcol( idx )[ :row ], 0  ) ].selected = true
			@c[ cellidx( 0, cellidx_to_rowcol( idx )[ :col ]  ) ].selected = true
		end
	end

	def unmark_cell( idx=@curcell )
		@c[ idx ].selected = false
		if idx == @curcell
			@c[ cellidx( currow(), 0 ) ].selected = false
			@c[ cellidx( 0, curcol() ) ].selected = false
		else
			@c[ cellidx( cellidx_to_rowcol( idx )[ :row ], 0  ) ].selected = false
			@c[ cellidx( 0, cellidx_to_rowcol( idx )[ :col ]  ) ].selected = false
		end
	end

	def motion( down= 0, right= 0, visual= false )
		@last_visited_cell = @curcell
		if    curcol() == 1 and right < 0 
			@error_window.error( "At column A!" ) 
			return false
		elsif currow() == 1 and  down < 0 
			@error_window.error( "At row one! " ) 
			return false
		end
		unmark_cell() if visual == false
		row = currow() + down
		col = curcol() + right
		if row < @curfirstrow  
			@curfirstrow = row 
			@curlastrow  = row + @rows_on_win - 1
		end
		if  row > @curlastrow
			@curlastrow  = row 
			@curfirstrow = row - @rows_on_win + 1
		end
		if col < @curfirstcol  
			@curfirstcol = col 
			@curlastcol  = col + @cols_on_win - 1
		end
		if col > @curlastcol  
			@curlastcol  = col 
			@curfirstcol = col - @cols_on_win + 1
		end
		@curcell = cellidx( row, col )
		grow_table( newrows = 30, newcols = 0 ) if currow() >= @maxrow
		grow_table( newrows = 0, newcols = 15 ) if curcol() >= @maxcol
		mark_cell(@curcell)
		update_status_bar()
		write_all_cells() unless visual == true
	end

  # this is the top bar used when we edit (press 's' for example)
 def update_status_bar()
		@status_info = @curcell + " [" + currow().to_s + ", " + curcol().to_s + "]:"
		mv_print_color( 0, 0, "%-#{@wcols}s", "#{@status_info} #{@c[ @curcell ].content}", "")
	end

	def write_all_cells()
		y_position = 1															# begin each line on the very left 
		[ 0, ( @curfirstrow .. @curlastrow ).to_a ].flatten.each do |row|		# for row in [0, @curfirstrow .. @curlastrow ] doesn't work.. :/
			x_position = 0														# begin each line on the very left 
			[ 0, ( @curfirstcol .. @curlastcol ).to_a ].flatten.each do |col|	# for col in [0, @curfirstcol .. @curlastcol ] doesn't work.. :/
				cell = @c[ cellidx( row, col ) ]
				color = @c[ cellidx( row, col ) ].check_color()
				mv_print_color( y_position, x_position, "%-#{cell.width}s", "#{cell.content}", "#{color}")
				x_position += cell.width										# store current column position
			end
			y_position += 1										
		end
		@w.move(0,  @status_info.length + @c[ @curcell ].content.length + 1 ) 
	end

	def reset()
		@x = 1
		mv_print_color(0, 0, "%-#{@wcols}s", " ")
	end

	def error( message )
		$logger.info "INFO: #{message}"
		@error_window.error( message )
	end

	def next_empty_row()
		reached = false
		currow().upto( @maxrow ) do |row|
			1.upto( @maxcol ) do |col|
				if @c[ cellidx( row, col ) ].content =~ /\S+/
					break 
				else
					next unless col == @maxcoll
					reached = true
				end
			end
			next if reached == false 
			return row
		end
	end

	def go_to_cell( cell )
		@lastcell = @curcell
		@nextcell = cell
		motion( cellidx_to_rowcol( @nextcell )[:row] - currow(), cellidx_to_rowcol( @nextcell )[:col] - curcol() )
	end

	def out_of_range?( cell )
		if cellidx_to_rowcol( cell )[:row] > @maxrow or cellidx_to_rowcol( cell )[:col] > @maxcol
			return true 	
		else
			return false
		end
	end

	def import_csv( filename, fs=";", comment_char = "#", ignore_comments = true, *args)
		if filename == ""
			return false
		elsif not File.exists?( filename )
			@error_window.error("no such file!")
			return false
		end
		row = 1
		file = File.open( filename ) do |file|
		file.each_line do |line|
		 line.chomp!
		 col = 1
		 next if line =~ /^#{comment_char}.*$/
		 line.split( fs ).each do |item|
			 @c [ cellidx( row, col ) ].content = item.strip!
			 col += 1
		 end 
		 row += 1
		end
		end
		write_all_cells()
	end

	def export_csv( filename, fs=";") 
		File.new( filename, "w" ) unless File.exist?( filename )
		File.open( filename , "w" ) do |file| 
			1.upto( last_row_with_content() ) do |row|
				1.upto( last_col_with_content( row ) ) do |col|
				file.write( "#{@c[ cellidx( row, col ) ].content} ; " ) 
				end
				file.write( "\n" )
			end
		end
	end

end


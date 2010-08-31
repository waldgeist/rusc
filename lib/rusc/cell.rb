require "rusc/window.rb"
require "rusc/frame.rb"

class RuscWindowFrameCell  < RuscWindowFrame
	attr_accessor :idx, :color, :content, :width, :format, :flag, :marker, :note, :error, :selected, :function, :script

	def initialize( idx, width, color="", content="", *args )		
		@idx	 = idx
		@crow  = cellidx_to_rowcol( @idx )[:row]	# really necessary?
		@ccol  = cellidx_to_rowcol( @idx )[:col]	# better using indices instead?
		@color	 = color
		@content = ( content.length == 0 ) ? "" : content
		@width   = width
		@args    = *args
		@defprec = 2								# default column precision 
		@selected = false
		@script = @function = false
	end

	def select()
		@selected = true
	end

	def unselect()
		@selected = false
	end

	def check_color()
		if @selected == true and ( cellidx_to_rowcol( @idx )[:row] == 0 or cellidx_to_rowcol( @idx )[:col] == 0 )
			return "white_black"
		elsif @selected == true and @function == true
			return "blue_white"
		elsif @selected == true and   @script == true
			return "red_white"
		elsif @selected == true 
			return "black_white"
		else
			return @color
		end
	end

	def edit()
		@frame.update_status_bar()
	end
	
	def reset()
		@x = 1
		mv_print_color(0, 0, "%-#{@wcols}s", " ")
	end

	# def self.find( regexp )		# experimental
		# # matched_results = []
		# match = nil
		# ObjectSpace.each_object( self ) do |cell| 
			# break if ( match = /regexp/.match( cell.content ) ) != nil
			# # matched_results << match if match != nil
		# end
		# # matched_results.empty? ? return "no results!" : return matched_results 
		# return match
	# end
end


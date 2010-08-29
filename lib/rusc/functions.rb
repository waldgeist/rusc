
module RuscFunctions
	def cellidx( row, col )
		return row.to_s if ( col == 0 or col == nil )
		error("invalid col!") unless col <= 702			# absmaxcol: ZZ
		if col > 26
			col_a = Array.new()							# colname will consist of more than one letter
			col_a << col / 27							# integer part of division
			col_a << ( col % 26 == 0 ? 26 : col % 26 )	# modulo rest
			col_a.map! {|c| (?A - 1 + c).chr }			# convert ascii-number to letter
			return col_a.to_s + row.to_s				# return string
		else
			col = (col + ?A -1).chr						# convert ascii-number to letter
			return col.to_s + row.to_s					# return string
		end
	end
	def cellidx_to_rowcol( idx_of_a_cell )
		rownum   = /\d+/.match(idx_of_a_cell).to_s.to_i
		colchars = /\D{1,2}/.match(idx_of_a_cell).to_s
		return { :row => rownum, :col => 0 } if colchars == ""
		if colchars.length == 1 
			colchars = colchars.upcase[0] - ?A + 1
			return { :row => rownum, :col => colchars }
		else
			colchars_a = colchars.upcase.split('')
			colchars_a.map! {|c| c[0] - ?A + 1} 
			colchars = colchars_a[0] * colchars_a[1]
			return { :row => rownum, :col => colchars }
		end
	end
	def last_col_with_content ( row )
		@maxcol.downto( 0 ) do |col|
			return col if @c[ cellidx( row, col ) ].content =~ /\S+/ 
		end
	end
	def last_row_with_content()
		@maxrow.downto( currow() ) do |row|
			last_col_with_content( row ).downto( 1 ) do |col|
				return row if @c[ cellidx( row, col ) ].content =~ /\S+/ 
			end
		end
	end
	def prev_blank_field_in_col( row )
		(currow() - 1).downto( 1 ) do |row|	# if forall?
			return row if @c[ cellidx( row, curcol() ) ].content !~ /\S+/ 
		end
	end
	def next_blank_field_in_col( row )
		(currow() + 1).upto( @maxrow ) do |row|	# if forall?
			return row if @c[ cellidx( row, curcol() ) ].content !~ /\S+/ 
		end
	end
	def next_cell( cell, cellarray, reverse = false, wrapsearch = true )
		# compare idx of a cell with array of cellidxs' and return the next
		# cell (in reverse order if reverse == true )
		cellrow = cellidx_to_rowcol( cell )[:row]
		cellcol = cellidx_to_rowcol( cell )[:col]
		case reverse
		when false
			cellarray.each do |c|
				crow = cellidx_to_rowcol( c )[:row]
				ccol = cellidx_to_rowcol( c )[:col]
				next if crow < cellrow  
				next if ccol <= cellcol and crow == cellrow
				# mv_print_color(	9, 55, "%s", "good!","")  # bis hierher alles ok!
				# mv_print_color(	10, 55, "%s", "#{ccol}","")  # bis hierher alles ok!
				# mv_print_color(	11, 55, "%s", "#{crow}","")  # bis hierher alles ok!
				# mv_print_color(	12, 55, "%s", "#{c}","")  # bis hierher alles ok!
				# everything theems to work, but moving to matching cell
				# causes trouble when wrapping
				return c 
			end
		when true
			cellarray.reverse.each do |c|
				crow = cellidx_to_rowcol( c )[:row]
				ccol = cellidx_to_rowcol( c )[:col]
				next if crow  > cellrow
				next if ccol >= cellcol and crow == cellrow
				return c 
			end
		end
		next_cell( "A1", cellarray, reverse = false )											if wrapsearch == true and reverse == false
		next_cell( cellidx( last_row_with_content(), @maxcol ) , cellarray, reverse = true )	if wrapsearch == true and reverse == true
	end
	def search_cell( regexp, reverse = false, wrapsearch = true ) 
		results = []
		ncell = @curcell
		@c.each_pair do |cellidx, cell| 
			next unless cellidx =~ /[A-Z]{1,2}\d+/			
			results << cellidx if cell.content =~ regexp	
		end
		ncell = next_cell( @curcell, results, reverse, wrapsearch ) unless results.length == 0
		motion( ( -currow() + cellidx_to_rowcol( ncell )[:row] ) , ( -curcol() + cellidx_to_rowcol( ncell )[:col] ) ) 
	end
end


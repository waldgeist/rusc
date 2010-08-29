#!/usr/bin/ruby -w

require 'logger'
require 'ncurses'
require "frontend.rb"
require "window.rb"
require "frame.rb"
require "prompt.rb"
require "cell.rb"

unless File.directory?( File.expand_path( "~/.rusc" ) )
  Dir.mkdir( File.join( File.expand_path( "~" ) , ".rusc" ) ) 
end
err_file = "#{ENV['HOME']}/.rusc/errors.log"
$logger = Logger.new(err_file, 5, 1024000)

begin 
	@frontend = RuscFrontend.new 
	@frontend.init_curses()
	@frontend.start()
	@frontend.looping()
	@frontend.shutdown()
rescue
	@frontend.shutdown() if @frontend
	$stderr.puts $!
	exit(1)
end

# vim: ts=2 sw=2 expandtab

#!/usr/bin/ruby -w

require 'logger'
require 'ncurses'
$:.unshift File.expand_path( File.dirname( __FILE__ ) + '/../lib' )
require "rusc/frontend.rb"
require "rusc/window.rb"
require "rusc/frame.rb"
require "rusc/prompt.rb"
require "rusc/cell.rb"

class Rusc

  def initialize( options, argv )
    @options = options
    @argv = argv
    #@file = options[:file]
    #init_vars
  end

  def self.main( args )
    # this is where we would parse command line params
    # http://www.ruby-doc.org/stdlib/libdoc/optparse/rdoc/classes/OptionParser.html
    options = {}
    begin
      c = Rusc.new( options, args )
      ret = c.run
    ensure
    end
    return ret
  end

  def run()
    unless File.directory?( File.expand_path( "~/.rusc" ) )
      Dir.mkdir( File.join( File.expand_path( "~" ) , ".rusc" ) ) 
    end
    err_file = "#{ENV['HOME']}/.rusc/errors.log"
    $logger = Logger.new( err_file, 5, 1024000 )
    begin 
      @frontend = RuscFrontend.new 
      @frontend.init_curses()
      @frontend.start()
      @frontend.looping()
      @frontend.shutdown()
    rescue
      @frontend.shutdown() if @frontend
      $stderr.puts $!
      exit( 1 )
    end
  end # run

end # class

if __FILE__ == $0
  exit Rusc.main( ARGV ) 
end
#
# vim: ts=2 sw=2 expandtab

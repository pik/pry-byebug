require 'pry-byebug/helpers/navigation'
require 'pry-byebug/helpers/multiline'

module PryByebug
  #
  # Run a number of lines and then stop again
  #
  class NextCommand < Pry::ClassCommand
    include Helpers::Navigation
    include Helpers::Multiline

    match 'nxt'
    group 'Byebug'
    description 'Execute the next line within the current stack frame.'

    banner <<-BANNER
      Usage: nxt [LINES]

      Step over within the same frame. By default, moves forward a single
      line.

      Examples:
        nxt   #=> Move a single line forward.
        nxt 4 #=> Execute the next 4 lines.
    BANNER

    def process
      return if check_multiline_context

      PryByebug.check_file_context(target)

      breakout_navigation :next, lines: args.first
    end
  end
end

Pry::Commands.add_command(PryByebug::NextCommand)

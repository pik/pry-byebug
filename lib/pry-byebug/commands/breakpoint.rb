require 'pry/byebug/breakpoints'
require 'pry-byebug/helpers/breakpoints'
require 'pry-byebug/helpers/multiline'

module PryByebug
  #
  # Add, show and remove breakpoints
  #
  class BreakCommand < Pry::ClassCommand
    include Helpers::Breakpoints
    include Helpers::Multiline

    match 'brk'
    group 'Byebug'
    description 'Set or edit a breakpoint.'

    banner <<-BANNER
      Usage:   brk <METHOD | FILE:LINE | LINE> [if CONDITION]
               brk --condition N [CONDITION]
               brk [--show | --delete | --enable | --disable] N
               brk [--delete-all | --disable-all]
               break
      Aliases: breakpoint

      Set a breakpoint. Accepts a line number in the current file, a file and
      line number, or a method, and an optional condition.

      Pass appropriate flags to manipulate existing breakpoints.

      Examples:

        brk SomeClass#run         Break at the start of `SomeClass#run`.
        brk Foo#bar if baz?       Break at `Foo#bar` only if `baz?`.
        brk app/models/user.rb:15 Break at line 15 in user.rb.
        brk 14                    Break at line 14 in the current file.

        brk --condition 4 x > 2   Add/change condition on brk #4.
        brk --condition 3         Remove the condition on brk #3.

        brk --delete 5            Delete brk #5.
        brk --disable-all         Disable all breakpoints.

        brk --show 2              Show details about brk #2.
        brk                       List all breakpoints.
    BANNER

    def options(opt)
      defaults = { argument: true, as: Integer }

      opt.on :c, :condition, 'Change condition of a breakpoint.', defaults
      opt.on :s, :show, 'Show brk details and source.', defaults
      opt.on :D, :delete, 'Delete a breakpoint.', defaults
      opt.on :d, :disable, 'Disable a breakpoint.', defaults
      opt.on :e, :enable, 'Enable a disabled breakpoint.', defaults
      opt.on :'disable-all', 'Disable all breakpoints.'
      opt.on :'delete-all', 'Delete all breakpoints.'
    end

    def process
      return if check_multiline_context

      PryByebug.check_file_context(target)

      option, = opts.to_hash.find { |key, _value| opts.present?(key) }
      return send(option_to_method(option)) if option

      return new_brk unless args.empty?

      print_all
    end

    private

    %w(delete disable enable disable_all delete_all).each do |command|
      define_method(:"process_#{command}") do
        breakpoints.send(*[command, opts[command]].compact)
        print_all
      end
    end

    def process_show
      print_full_breakpoint(breakpoints.find_by_id(opts[:show]))
    end

    def process_condition
      expr = args.empty? ? nil : args.join(' ')
      breakpoints.change(opts[:condition], expr)
    end

    def new_breakpoint
      place = args.shift
      condition = args.join(' ') if 'if' == args.shift

      bp = add_breakpoint(place, condition)

      print_full_breakpoint(bp)
    end

    def option_to_method(option)
      "process_#{option.to_s.gsub('-', '_')}"
    end

    def print_all
      print_breakpoints_header
      breakpoints.each { |b| print_short_breakpoint(b) }
    end

    def add_breakpoint(place, condition)
      case place
      when /^(\d+)$/
        errmsg = 'Line number declaration valid only in a file context.'
        PryByebug.check_file_context(target, errmsg)

        lineno = Regexp.last_match[1].to_i
        breakpoints.add_file(current_file, lineno, condition)
      when /^(.+):(\d+)$/
        file = Regexp.last_match[1]
        lineno = Regexp.last_match[2].to_i
        breakpoints.add_file(file, lineno, condition)
      when /^(.*)[.#].+$/ # Method or class name
        if Regexp.last_match[1].strip.empty?
          errmsg = 'Method name declaration valid only in a file context.'
          PryByebug.check_file_context(target, errmsg)
          place = target.eval('self.class.to_s') + place
        end
        breakpoints.add_method(place, condition)
      else
        fail(ArgumentError, 'Cannot identify arguments as breakpoint')
      end
    end
  end
end

Pry::Commands.add_command(PryByebug::BreakCommand)

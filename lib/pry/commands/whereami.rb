class Pry
  Pry::Commands.create_command "whereami" do
    description "Show code surrounding the current context."
    group 'Context'
    banner <<-BANNER
      Usage: whereami [-q] [N]

      Describe the current location. If you use `binding.pry` inside a
      method then whereami will print out the source for that method.

      If a number is passed, then N lines before and after the current line
      will be shown instead of the method itself.

      The `-q` flag can be used to suppress error messages in the case that
      there's no code to show. This is used by pry in the default
      before_session hook to show you when you arrive at a `binding.pry`.

      When pry was started on an Object and there is no associated method,
      whereami will instead output a brief description of the current
      object.
    BANNER

    def setup
      if internal_binding?(target)
        location = _pry_.backtrace.detect do |x|
                     !x.start_with?(File.expand_path('../../../../lib', __FILE__))
                   end
        @method = nil
        @file = location.split(":").first
        @line = location.split(":")[1].to_i
      else
        @method = Pry::Method.from_binding(target)
        @file = target.eval('__FILE__')
        @line = target.eval('__LINE__')
      end
    end

    def options(opt)
      opt.on :q, :quiet, "Don't display anything in case of an error"
    end

    def code
      @code ||= if show_method?
                  Pry::Code.from_method(@method)
                else
                  Pry::Code.from_file(@file).around(@line, window_size)
                end
    end

    def location
      "#{@file} @ line #{show_method? ? @method.source_line : @line} #{@method && @method.name_with_owner}"
    end

    def process
      if opts.quiet? && (at_top_level? || !code?)
        return
      elsif at_top_level?
        output.puts "At the top level."
        return
      end

      set_file_and_dir_locals(@file)

      output.puts "\n#{text.bold('From:')} #{location}:\n\n"
      output.puts code.with_line_numbers.with_marker(@line)
      output.puts
    end

    private

    def at_top_level?
      @file.end_with?("bin/pry")
    end

    def show_method?
      args.empty? && @method && @method.source? && @method.source_range.count < 20 &&
      # These checks are needed in case of an eval with a binding and file/line
      # numbers set to outside the function. As in rails' use of ERB.
      @method.source_file == @file && @method.source_range.include?(@line)
    end

    def code?
      !!code
    rescue MethodSource::SourceNotFoundError
      false
    end

    def window_size
      if args.empty?
        Pry.config.default_window_size
      else
        args.first.to_i
      end
    end
  end
end

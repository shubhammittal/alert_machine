require 'eventmachine'
require 'action_mailer'

class AlertMachine

  class Watcher
      # == Options:
      #     The below options can also be overridden via config/alert_machine.yml
      #
      # * interval:
      #     Seconds between each run, during the steady state. 5 min default.
      #
      # * interval_error:
      #     How soon to check again, in-case an error occurred. (interval)/5 default.
      #
      # * from, to:
      #     Comma seperated list of emails, to bother when there are alerts. defaults
      #     to whatever was specified in the config file.
      #
      # * retries:
      #     Number of times to try before alerting on error. Defaults to 3.
      #
      def self.watch(opts, &block)
        AlertMachine.tasks << RunTask.new(opts, block, caller)
      end

      def self.assert(conditions, msg = nil)
        AlertMachine.current_task.assert(conditions, msg, caller)
      end
  end

  # A single watch and it's life cycle.
  class RunTask
    def initialize(opts, block, caller)
      @opts, @block, @caller = opts, block, caller
      @errors = []
      @alert_state = false
    end

    def schedule
      @timer = EM::PeriodicTimer.new(interval) do
        with_task do
          start = Time.now
          begin
            # The main call to the user-defined watcher function.
            @block.call(*@opts[:args])
            
            assert(Time.now - start < interval / 5.0,
              "Task ran for too long. Invoked every #{
              interval}s. Ran for #{Time.now - start}s.", @caller)

            # Things finished successfully.
            @timer.interval = interval if !@errors.empty?
            @errors = []
            
            alert_state(false)

          rescue AssertionFailure => af
            
            @timer.interval = interval_error if @errors.empty?
            @errors << af

            alert_state(true) if @errors.length > retries
          end
        end
      end
    end

    def with_task
      AlertMachine.current_task = self
      yield
    ensure
      AlertMachine.current_task = nil
    end

    def assert(condition, msg, caller)
      return if condition
      assert_failed(msg, caller)
    end

    def assert_failed(msg, caller)
      fail = AssertionFailure.new(msg, caller)
      puts fail.log
      raise fail
    end

    # Is the alert firing?
    def alert_state(firing)
      if firing != @alert_state
        mail unless @last_mailed && @last_mailed > Time.now - 60*10
        @last_mailed = Time.now
      end
      @alert_state = firing
    end

    def mail
      last = @errors[-1]
      ActionMailer::Base.mail(
        :from => opts(:from),
        :to => opts(:to),
        :subject => "AlertMachine Failed: #{last.msg || last.parsed_caller.file_line}"
      ) do |format|
        format.text {
          render :text =>
            @errors.collect {|e| e.log}.join("\n=============\n")
        }
      end.deliver
    end

    def opts(key, defaults = nil)
      @opts[key] || config[key.to_s] || defaults || block_given? && yield
    end

    def interval
      opts(:interval, 5 * 60).to_f
    end

    def interval_error
      opts(:interval_error) { interval / 5.0 }.to_f
    end

    def retries
      opts(:retries, 3).to_i
    end

    def config
      self.class.config
    end

    @@config = nil
    def self.config
      @@config ||= YAML::load(File.open('config/alert_machine.yml'))
    rescue
      {}
    end

    # When an assertion fails, this exception is thrown so that
    # we can unwind the stack frame. It's also deliberately throwing
    # something that's not derived from Exception.
    class AssertionFailure < Exception
      attr_reader :msg, :caller, :time
      def initialize(msg, caller)
        @msg, @caller, @time = msg, caller, Time.now
        super(@msg)
      end

      def log
        "[#{Time.now}] #{msg ? msg + "\n" : ""}" +
          "#{Caller.new(caller).log}"
      end
      
      def parsed_caller
        Caller.new(caller)
      end
    end
  end

  def self.disable(disabled = true)
    @@em_invoked = disabled
  end

  # The main entry point called when the ruby is about to finish.
  # Isn't this cool :) Inspiration from Test::Unit.
  def self.at_exit
    unless @@em_invoked
      @@em_invoked = true
      EM::run do
        @@tasks.each do |t|
          t.schedule
        end
        yield if block_given?
      end
    end
  end

  # Figures out how to parse the call stack and pretty print it.
  class Caller
    attr_reader :caller, :file, :line
    
    def initialize(caller, &block)
      @block = block if block_given?
      @caller = caller
      /^(?<fname>[^:]+)\:(?<line>\d+)\:/ =~ caller[0] and
        @file = fname and @line = line
    end

    def file_line
      "#{file}:#{line}"
    end

    def log
      "#{caller[0]}\n" +
        log_source_file.to_s
    end
    
    def log_source_file
      File.open(file) {|fh|
        fh.readlines[line.to_i - 1..line.to_i + 3].collect {|l|
          ">> #{l}"
        }.join + "---\n"
      } if file && File.exists?(file)
    end
  end

  @@tasks = []
  @@em_invoked = false
  @@current_task = nil

  def self.tasks
    @@tasks
  end

  def self.current_task
    @@current_task
  end

  def self.current_task=(task)
    @@current_task = task
  end

  def self.reset
    @@tasks = []
  end
  
end

at_exit do
  AlertMachine.at_exit
end
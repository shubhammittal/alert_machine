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
      #     Number of times to try before alerting on error. Defaults to 1.
      #     
      # * dont_check_long_processes:
      #     Don't assert if my watch took too long to run. [false defaults]
      #
      def self.watch(opts = {}, caller = caller, &block)
        AlertMachine.tasks << RunTask.new(opts, block, caller)
      end

      def self.assert(conditions, msg = nil, caller = caller)
        AlertMachine.current_task.assert(conditions, msg, caller)
      end

      # Make sure the process keeps running. machines can be one or many.
      # 
      # == Options:
      # One or more of the below constraints. Any of the below can either
      # be a single element or an array. (eg. multiple ports)
      #
      # * port: 
      #     Ensure the port is open.
      #     
      # * pid_file:
      #     Make sure the pid file exists and the process corresponding to it,
      #     is alive.
      #
      # * grep:
      #     Executes `ps aux | grep <string>` to ensure process is running.
      #
      # Other usual options of watcher, mentioned above.
      #
      def self.watch_process(machines, opts = {})
        machines = [machines].flatten
        Process.watch(machines, opts, caller)
      end

      # Run a command on a set of machines.
      def self.run_command(machines, cmd)
        machines = [machines].flatten
        @ssh ||= SshConnection.new
        @ssh.run(machines, cmd)
      end

      private
      # To suppress logging in test mode.
      def puts(*args)
        super unless AlertMachine.test_mode?
      end
  end

  # Configure your machine before running it.
  CONFIG_FILE = 'config/alert_machine.yml'
  @@config = nil
  def self.config(config_file = CONFIG_FILE)
    @@config ||= YAML::load(File.open(config_file))
  rescue
    {}
  end

  # Invoke this whenever you are ready to enter the AlertMachine loop.
  def self.run
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

  def self.ssh_config
    res = {}
    config['ssh'].each_pair do |k, v|
      res[k.to_sym] = v
    end
    return res
  end

  def self.disable(disabled = true)
    @@em_invoked = disabled
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
        }.join + "\n---\n"
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

  private
  def puts(*args)
    super unless AlertMachine.test_mode?
  end
  
  def self.test_mode?
    false
  end
end

dname = File.dirname(__FILE__)
require "#{dname}/process.rb"
require "#{dname}/run_task.rb"
require "#{dname}/ssh_connection.rb"
require "#{dname}/rails_environment.rb"

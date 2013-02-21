class AlertMachine

  # Checks if processes are living, and have their ports open.
  class Process < Watcher
    class << self

      def watch(machines, opts, caller)
        raise ArgumentError, "Must mention atleast one of (port, pid_file, grep)" unless
          opts[:port] || opts[:pid_file] || opts[:grep] || opts[:command]
          raise ArgumentError, "Must not be passed a block" if block_given?

        super(opts, caller) do
          check(:port, machines, opts, caller)
          check(:pid_file, machines, opts, caller)
          check(:grep, machines, opts, caller)

          check_command(machines, opts[:command], opts[:check_message].to_s,
            opts[:error_message].to_s, caller) if opts[:command]
        end
      end

      def check_port(machines, port, caller)
        check_command(machines, 
          "netstat -na | grep 'LISTEN' | grep '\\(\\:\\|\\.\\)#{port} ' | grep -v grep",
          "Checking if port #{port} is open on %s",
          "Port #{port} seems down on %s", caller)
      end
      
      def check_pid_file(machines, file, caller)
        check_command(machines, "ps -p `cat #{file}`",
          "Checking if valid pidfile #{file} exists in %s",
          "Pidfile #{file} doesnt seem valid at %s", caller)
      end

      def check_grep(machines, grep, caller)
        check_command(machines, "ps aux | grep '#{grep}' | grep -v grep",
          "Grepping the process list for '#{grep}' in %s",
          "Grepping the process list for '#{grep}' failed at %s", caller)
      end

      def check_command(machines, cmd, check_msg, error_msg, caller)
        puts check_msg % machines.join(", ")
        bad_machines = []
        run_command(machines,
          "#{cmd} || echo BAD"
        ).each { |machine, output|
          bad_machines << machine if output.join(" ").match(/BAD/)
        }
        check_command_failed(bad_machines, error_msg, caller) unless
          bad_machines.empty?
      rescue Exception => e
        puts "Exception: #{e.to_s}"
        puts "#{e.backtrace.join("\n")}"
        unless e.is_a?(RunTask::AssertionFailure)
          check_command_failed(machines, error_msg + " with exception #{e.to_s}" , caller)
        else
          raise e
        end
      end

      def check_command_failed(machines, error_msg, caller)
        assert false, error_msg % machines.join(", "), caller
      end

      def check(entity, machines, opts, caller)
        Array([opts[entity]]).flatten.each { |val|
          Process.send("check_#{entity}".to_sym, machines, val, caller)
        }
      end

      private
      def puts(*args)
        super unless AlertMachine.test_mode?
      end
    end
  end
  
end
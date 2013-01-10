class AlertMachine
  class SshConnection

    def initialize
      require 'rye'
      @connections = {}
    end

    def box(host)
      @connections[host] ||= Rye::Box.new(host,
        AlertMachine.ssh_config.merge(:safe => false))
    end

    def set(hosts)
      set = Rye::Set.new(hosts.join(","), :parallel => true)
      hosts.each { |m| set.add_box(box(m)) }
      set
    end

    def run(hosts, cmd)
      puts "[#{Time.now}] executing on #{hosts}: #{cmd}"
      res = set(hosts).execute(cmd).group_by {|ry| ry.box.hostname }.
        sort_by {|name, op| hosts.index(name) }
      res.each { |machine, op|
        puts "[#{Time.now}] [#{machine}]\n#{op.join("\n")}\n"
      }
    rescue Exception => e
      puts "[#{Time.now}] Executing cmd on machines raised exception."
      puts "#{hosts} => #{cmd}"
      puts "#{e}"
      puts "#{e.backtrace.join("\n")}"
    end
    
  end
end
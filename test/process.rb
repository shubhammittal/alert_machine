require File.expand_path(File.dirname(__FILE__) + '/helper.rb')

class ProcessTest < AlertMachineTestHelper

  def setup
    super
    AlertMachine.expects(:dont_check_long_processes).returns(true).at_least(0)
  end
  
  def test_port_open_failuire
    process_watcher(:port => 3343)
    AlertMachine::RunTask.any_instance.expects(:assert_failed).at_least_once
    run_machine
  end

  def test_port_open_success
    process_watcher(:port => 3343)
    AlertMachine::RunTask.any_instance.expects(:assert_failed).never
    run_machine {
      EM::start_server "localhost", 3343 do
      end
    }
  end

  def test_pid_file_failuire
    `rm -f /tmp/pid_x; touch /tmp/pid_x`
    process_watcher(:pid_file => "/tmp/pid_x")
    AlertMachine::RunTask.any_instance.expects(:assert_failed).at_least_once
    run_machine
  end

  def test_pid_file_success
    `rm -f /tmp/pid_x; touch /tmp/pid_x`
    process_watcher(:pid_file => "/tmp/pid_x")
    AlertMachine::RunTask.any_instance.expects(:assert_failed).never
    File.open("/tmp/pid_x", "w") {|fh| fh.write "#{Process.pid}" }
    run_machine
  end
  
  def test_grep_failuire
    process_watcher(:grep => "test/stupid.rb")
    AlertMachine::RunTask.any_instance.expects(:assert_failed).at_least_once
    run_machine
  end

  def test_grep_success
    process_watcher(:grep => "test/process.rb")
    AlertMachine::RunTask.any_instance.expects(:assert_failed).never
    File.open("/tmp/pid_x", "w") {|fh| fh.write "#{Process.pid}" }
    run_machine
  end

end
require File.expand_path(File.dirname(__FILE__) + '/helper.rb')

class WatcherTest < Test::Unit::TestCase

  def setup
    AlertMachine.reset
  end

  def test_no_alerts_triggerred
    watcher {}
    AlertMachine::RunTask.any_instance.expects(:assert_failed).never
    run_machine
  end

  def test_alerts_for_long_running_processes
    watcher { sleep 0.05 }
    AlertMachine::RunTask.any_instance.expects(:assert_failed).at_least_once
    run_machine
  end

  def test_no_alerts_before_retries
    cnt = 0
    watcher(:retries => 1) { AlertMachine::Watcher.assert false if (cnt += 1) <= 1 }
    AlertMachine::RunTask.any_instance.expects(:mail).never
    run_machine
  end

  def test_alert_fires_after_retries
    cnt = 0
    watcher(:retries => 1) { AlertMachine::Watcher.assert false if (cnt += 1) <= 2 }
    AlertMachine::RunTask.any_instance.expects(:mail)
    run_machine
  end

  def watcher(opts = {})
    Class.new(AlertMachine::Watcher) do
      watch opts.merge(:interval => 0.05) do
        yield
      end
    end
  end
  
  def run_machine
    AlertMachine.disable(false)
    AlertMachine.at_exit {
      EM::Timer.new(0.1) do
        EM::stop_event_loop
      end
    }
  ensure
    AlertMachine.disable
  end
end

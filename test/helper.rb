require 'rubygems'
require 'test/unit'
require 'mocha'
require File.dirname(__FILE__) + '/../lib/alert_machine.rb'

AlertMachine.disable

class AlertMachineTestHelper < Test::Unit::TestCase
  def setup
    AlertMachine.reset
    AlertMachine.expects(:config).returns(
      {
        'ssh' => {
        }
      }
    ).at_least(0)
    AlertMachine.expects(:test_mode?).returns(true).at_least(0)
  end

  def watcher(opts = {})
    Class.new(AlertMachine::Watcher) do
      watch opts.merge(:interval => 0.05) do
        yield
      end
    end
  end

  def process_watcher(opts = {})
    Class.new(AlertMachine::Watcher) do
      watch_process "localhost", {interval: 0.05}.merge(opts)
    end
  end

  def run_machine
    AlertMachine.disable(false)
    AlertMachine.run {
      EM::Timer.new(0.1) do
        EM::stop_event_loop
      end
      yield if block_given?
    }
  ensure
    AlertMachine.disable
  end
end
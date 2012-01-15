class AlertMachine
  class RailsEnvironment

    ENVIRONMENT_PATH = "./config/environment.rb"
    def self.bootup(path = ENVIRONMENT_PATH)
      require path
    rescue Exception => e
      puts "Exception: #{e.to_s}"
      puts e.backtrace.join("\n")
      config = AlertMachine.config
      ActionMailer::Base.mail(
        :from => config['from'],
        :to => config['to'],
        :subject => "AlertMachine Failed: Environment could not load."
      ) do |format|
        format.text {
          render :text => <<TXT
          machine: #{`hostname`}
          exception: #{e.to_s}
          #{e.caller.join('\n')}
TXT
        }
      end.deliver
    end
    
  end
end
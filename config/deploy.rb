# deploy recipes - need to do `sudo gem install thunder_punch`
require 'critical_juncture/thunder_punch'
# thinking sphinx cap tasks
require 'thinking_sphinx/deploy/capistrano'
# hoptoad deploy notifications, etc
require 'hoptoad_notifier/capistrano'

#############################################################
# Set Basics
#############################################################

set :application, "fr2"
set :user, "deploy"
ssh_options[:keys] = [File.join(ENV["HOME"], ".ssh", "fr_staging")]

# use these settings for making AMIs with thunderpunch
# set :user, "ubuntu"
# ssh_options[:keys] = [File.join(ENV["HOME"], ".ssh", "id_rsa_govpulse_prod1")]

#set :port, 5034

set :ec2_config_location, File.join(File.dirname(__FILE__), "ec2_config.yml")

ssh_options[:paranoid] = false
set :use_sudo, true
default_run_options[:pty] = true

set :keep_releases, 2

# this is more important when normalizing multiple servers
# but is implemented in a very simple way (ie poorly)
set :normalize_asset_timestamps, false

#############################################################
# Set Branch
#############################################################

set(:branch) do
  current_branch   = `git branch`.match(/\* (.*)/)[1]
  specified_branch = Capistrano::CLI.ui.ask "Branch [#{current_branch}]: "
  specified_branch == '' ? current_branch : specified_branch
end

#############################################################
# General Settings  
#############################################################

set :rails_env,  "production"                           
set :deploy_to,  "/var/www/apps/#{application}" 
set :domain,     "184.72.250.132" #"184.73.189.26" #fr1_ec2 -- ec2-184-73-5-183.compute-1.amazonaws.com
set :url,        "#{domain}"     
set :server_url, "#{domain}"

role :web, domain                      
role :app, domain                      
role :db , domain, {:primary => true}

#############################################################
# Database Settings
#############################################################

set :remote_db_name, "fr2_production"
set :db_path,        "#{shared_path}/db"
set :sql_file_path,  "#{shared_path}/db/#{remote_db_name}_#{Time.now.utc.strftime("%Y%m%d%H%M%S")}.sql"


#############################################################
# SCM Settings
#############################################################
set :scm,              :git          
set :github_user_repo, 'criticaljuncture'
set :github_project_repo, 'fr2'
set :deploy_via,       :remote_cache 


#############################################################
# If for some reason the server can not resolve github, use
# set :deploy_via, :copy
# 
# This will deploy from your local copy of the repository -
# it may take a while...
#############################################################


#############################################################
# Git
#############################################################

# This will execute the Git revision parsing on the *remote* server rather than locally
set :real_revision, lambda { source.query_revision(revision) { |cmd| capture(cmd) } }
set :git_enable_submodules, true


#############################################################
# Github
#############################################################

if deploy_via == :remote_cache

  set :deploy_via, :remote_cache
  set :repository, "git@github.com:#{github_user_repo}/#{github_project_repo}.git"
  set :github_username, 'criticaljuncture'

elsif deploy_via == :copy

  set :copy_cache, true
  set :repository, '.git'

end

#############################################################
# Run Order
#############################################################

# Do not change below unless you know what you are doing!
after "deploy:update_code",       "deploy:update_config"
after "deploy",                   "deploy:cleanup"
after "deploy:cleanup",           "deploy:set_rake_path"
after "deploy:set_rake_path",     "deploy:fix_bundle"
after "deploy:fix_bundle",        "deploy:migrate"
after "deploy:migrate",           "thinking_sphinx:restart"
after "thinking_sphinx:restart",  "passenger:restart"


#############################################################
#                                                           #
#                                                           #
#                         Recipes                           #
#                                                           #
#                                                           #
#############################################################


#############################################################
# Create Project Directories for Capistrano
#############################################################

namespace :deploy do
  desc "Creates project directories with appropriate permissions"
  task :create_project_directories do
    sudo "mkdir -p #{deploy_to}"
    sudo "mkdir -p #{deploy_to}/releases"
    sudo "mkdir -p #{deploy_to}/shared/log"
    sudo "mkdir -p #{deploy_to}/shared/data"
    sudo "mkdir -p #{deploy_to}/shared/data/html"
    sudo "mkdir -p #{deploy_to}/shared/tmp"
    sudo "mkdir -p #{deploy_to}/shared/db/sphinx/production"
    sudo "chown -R #{user}:#{user} #{deploy_to}"
    sudo "touch #{deploy_to}/shared/log/#{rails_env}.log"
    sudo "chmod 0666 #{deploy_to}/shared/log/#{rails_env}.log"
  end
end


#############################################################
# Set Rake Path
#############################################################

namespace :deploy do
  desc "Set rake path"
  task :set_rake_path, :roles => [:app] do
    run "which rake" do |ch, stream, data|
      if stream == :err
        abort "captured output on STDERR when setting rake path: #{data}"
      elsif stream == :out
        set :rake_path, data.to_s.strip
      end
    end
  end
end


#############################################################
# Symlinks for Static Files
#############################################################

namespace :deploy do
  desc "Set Symlinks for Static Files (like database.yml)"
  task :update_config, :roles => [:app] do
    command = []
    
    %w(database.yml api_keys.yml mail.yml production.sphinx.conf newrelic.yml).each do |file|
      command << "ln -sf #{shared_path}/config/#{file} #{release_path}/config/#{file}"
    end
    
    command << "ln -sf #{shared_path}/config/cloudkicker_config.rb #{release_path}/config/initializers/cloudkicker_config.rb"
    command << "ln -sf #{shared_path}/config/amazon.yml #{release_path}/config/amazon.yml"
    command << "ln -sf #{shared_path}/log #{release_path}/log"
    
    # don't symlink data directory directly!
    
    %w(bulkdata mods regulatory_plans text xml).each do |folder|
      # command << <<-BASH
      #   if [ -d "#{shared_path}/data/#{folder}" ]; then
      #     mkdir -p "#{shared_path}/data/#{folder}"
      #   fi
      # BASH
      
      command << "ln -sf #{shared_path}/data/#{folder} #{release_path}/data/#{folder}"
    end
    
    command << "ln -sf #{shared_path}/db/sphinx #{release_path}/db/sphinx"
    command << "ln -sf #{shared_path}/sitemaps #{release_path}/public/sitemaps"
    command << "ln -sf #{shared_path}/data/html #{release_path}/public/articles"
    
    run command.join(' && ')
  end 
end


#############################################################
# Install Missing Gems
#############################################################

namespace :deploy do
  desc "Install Missing Gems"
  task :install_gems, :roles => [:app] do
    run "cd #{release_path}; #{sudo} #{rake_path} RAILS_ENV=#{rails_env} gems:install --trace"
  end
end


#############################################################
# Load Default Data
#############################################################

namespace :deploy do
  desc "Load Default Data"
  task :load_default_data, :roles => [:app] do
    #run "cd #{release_path}; sudo #{rake_path} RAILS_ENV=#{rails_env} data:load:#{rails_env}:all"
  end
end

#############################################################
# Passenger Restart
#############################################################

namespace :deploy do
  desc "Remove deploy:restart In Favor Of passenger:restart Task"
  task :restart do
  end
  
  desc "Install and lock bundle"
  task :fix_bundle do
    run "cd #{current_path} && bundle install"
  end
end

namespace :passenger do
  desc "Restart Application"
  task :restart do
    run "touch #{current_path}/tmp/restart.txt"
  end
end

#############################################################
# Passenger Status Checks
#############################################################

namespace :passenger do
  desc "Check Passenger Status"
  task :status do
    sudo 'passenger-status'
  end

  desc "Check Apache/Passenger Memory Usage"
  task :memory_stats do
    sudo 'passenger-memory-stats'
  end
end

#############################################################
# Check for Existing Database
#############################################################

namespace :database do
  desc "Check to see if database exists"
  task :check_database_existence do
    db_exists = false
    run "mysql -u root -e \"SELECT COUNT(SCHEMA_NAME) FROM INFORMATION_SCHEMA.SCHEMATA WHERE SCHEMA_NAME = '#{database_to_check}';\" --batch --reconnect --show-warning --silent" do |ch, stream, data|
      if stream == :err
        abort "capured output on STDERR when verifying database #{database_to_check} exists: #{data}"
      elsif stream == :out
        return_value = data.split("\n").first.chomp
    
        if ['0','1'].include?(return_value)
          db_exists = return_value == '0' ? false : true
        else
          abort "Invalid response from db when checking if database exists. Expected 0 or 1, got a count of #{return_value}"
        end
        puts db_exists
      end
    end
    db_exists
  end
end

#############################################################
# Backup Database
#############################################################

namespace :database do
  desc "Dump the current database"
  task :backup do
    set :database_to_check, remote_db_name # used by the check_database_existence task
    db_exists = find_and_execute_task('database:check_database_existence')
  
    if db_exists 
      sudo "sudo mkdir -p #{db_path}"
      run "mysqldump -u root --opt #{remote_db_name} > #{sql_file_path}"
    else
      abort "There is no database named #{remote_db_name} to backup"
    end
  end #end task :backup
end #end namspace 

#############################################################
# Load Remote Staging Database to Local Machine
#############################################################

namespace :database do

  desc "Backup remote database and load locally"
  task :load_remote do
    backup
    copy
    load_copy
  end

  desc "Copy the current database" 
  task :copy do
    `mkdir -p tmp`
    download(sql_file_path, "tmp/", :via=> :scp)
  end

  desc "Load the staging database locally"
  task :load_copy do
    `script/dbconsole -p < tmp/#{remote_db_name}.sql`
  end

end #end namspace

namespace :filesystem do
  task :load_remote do
    run_locally("rsync --verbose  --progress --stats --compress -e 'ssh -p #{port}' --recursive --times --perms --links #{user}@#{domain}:#{deploy_to}/shared/data data")
  end
end

require 'hoptoad_notifier/capistrano'

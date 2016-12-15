# config valid only for current version of Capistrano
lock "3.7.0"

set :application, "openstack-proxy"
set :repo_url, "git@github.com:thebigsofa/openstack-proxy.git"

# Default branch is :master
# ask :branch, `git rev-parse --abbrev-ref HEAD`.chomp

# Default deploy_to directory is /var/www/my_app_name
# set :deploy_to, "/var/www/openstack-proxy"

# Default value for :format is :airbrussh.
# set :format, :airbrussh

# You can configure the Airbrussh format using :format_options.
# These are the defaults.
# set :format_options, command_output: true, log_file: "log/capistrano.log", color: :auto, truncate: :auto

# Default value for :pty is false
# set :pty, true

# Default value for :linked_files is []
# append :linked_files, "config/database.yml", "config/secrets.yml"

# Default value for linked_dirs is []
# append :linked_dirs, "log", "tmp/pids", "tmp/cache", "tmp/sockets", "public/system"

# Default value for default_env is {}
# set :default_env, { path: "/opt/ruby/bin:$PATH" }

# Default value for keep_releases is 5
# set :keep_releases, 5

namespace :deploy do
  task :copy_ssl_and_env do
    on roles(:proxy), in: :parallel do |host|
      within("#{fetch(:deploy_to)}/current") do
        execute :cp, "/home/#{fetch(:user)}/ssl_file.crt", "ssl_file.crt"
        execute :cp, "/home/#{fetch(:user)}/ssl_file.key", "ssl_file.key"
        execute :cp, "/home/#{fetch(:user)}/swift-proxy-env", ".env"
        execute :mkdir, 'logs'
        execute :chmod, '777', 'logs'
      end
    end
  end

  task :finalize do
    invoke 'deploy:copy_ssl_and_env'
    invoke 'docker:build'
    invoke 'docker:restart'
  end

  after :finished, :finalize
end

namespace :docker do
  task :build do
    on roles(:proxy), in: :parallel do |host|
      within("#{fetch(:deploy_to)}/current") do
        # execute :sudo, './bin/docker_build'
        execute :sudo, 'docker build -t swift-proxy .'
      end
    end
  end

  task :restart do
    on roles(:proxy), in: :parallel do |host|
      within("#{fetch(:deploy_to)}/current") do
        # execute :sudo, './bin/docker_run'
        execute <<-EOCMD
          if [[ -n $(sudo docker ps -aq) ]]
            then sudo docker rm -f $(sudo docker ps -aq)
            echo "killed dockers"
          fi
        EOCMD
        execute :sudo, 'docker run -dit --security-opt=no-new-privileges --pids-limit 100 --read-only --tmpfs /run --tmpfs /tmp --tmpfs /home/thebigsofa/.pm2 -v `pwd`:/home/thebigsofa/src/app -p 8080:8080 -p 443:8443 -p 80:8080 --name os-proxy swift-proxy'
      end
    end
  end
end

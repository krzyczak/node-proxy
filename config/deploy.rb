# config valid only for current version of Capistrano
lock "3.7.0"

set :application, "openstack-proxy"
set :repo_url, "git@github.com:thebigsofa/openstack-proxy.git"
set :docker_mount_dir, 'latest'

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
# set :pty, false

# Default value for :linked_files is []
# append :linked_files, "config/database.yml", "config/secrets.yml"

# Default value for linked_dirs is []
# append :linked_dirs, "log", "tmp/pids", "tmp/cache", "tmp/sockets", "public/system"

# Default value for default_env is {}
# set :default_env, { path: "/opt/ruby/bin:$PATH" }

# Default value for keep_releases is 5
# set :keep_releases, 5

namespace :deploy do
  after :finished, :finalize

  task :finalize do
    on roles(:proxy), in: :parallel do |host|
      within("#{fetch(:deploy_to)}/current") do
        if capture('echo $(sudo docker ps -aq)').strip.empty?
          execute :sudo, 'docker build -t swift-proxy .'
          execute :sudo, "docker run -dit --security-opt=no-new-privileges --pids-limit 100 --read-only --tmpfs /run --tmpfs /tmp --tmpfs /home/thebigsofa/.pm2 --tmpfs /home/thebigsofa/.npm -v #{fetch(:deploy_to)}/#{fetch(:docker_mount_dir)}:/home/thebigsofa/src/app -p 8080:8080 -p 443:8443 -p 80:8080 --name os-proxy swift-proxy"
        end
      end

      within("#{fetch(:deploy_to)}") do
        execute :mkdir, "-p #{fetch(:deploy_to)}/#{fetch(:docker_mount_dir)}"
      end

      within("#{fetch(:deploy_to)}/#{fetch(:docker_mount_dir)}") do
        execute :cp, "/home/#{fetch(:user)}/ssl_file.crt", "ssl_file.crt"
        execute :cp, "/home/#{fetch(:user)}/ssl_file.key", "ssl_file.key"
        execute :cp, "/home/#{fetch(:user)}/swift-proxy-env", ".env"

        execute :mkdir, '-p logs'
        execute :mkdir, '-p node_modules'

        execute :chmod, '777', 'logs'
        execute :chmod, '777', 'node_modules'

        execute "mkdir -p #{fetch(:deploy_to)}/#{fetch(:docker_mount_dir)}"
        execute "cp -a #{fetch(:deploy_to)}/current/. #{fetch(:deploy_to)}/#{fetch(:docker_mount_dir)}/."

        # execute :sudo, :docker, 'exec os-proxy npm install --silent'
        execute :sudo, :docker, 'exec os-proxy npm install'
        # execute :sudo, 'docker exec -it os-proxy pm2 reload --env production os-proxy.yml'
        execute :sudo, 'docker exec os-proxy pm2 reload --env production os-proxy.yml'
      end
    end
  end
end

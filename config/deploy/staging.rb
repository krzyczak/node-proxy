# frozen_string_literal: true
set :user, 'proxy_app_staging'
set :deploy_to, "/home/#{fetch(:user)}/#{fetch(:application)}"
set :ssh_options, forward_agent: true, user: fetch(:user)

role :proxy, %w{swift-proxy-staging}, user: fetch(:user)

require 'pp'
require 'puppet/face'
require 'net/http'
require 'uri'
require 'json'
Puppet::Type.type(:jenkins_agent).provide(:json, :parent => Puppet::Provider) do
  desc "Manage jenkins slave agents with the JSON api"

  mk_resource_methods

  def exists?
    unless @property_hash[:ensure].nil?
      return @property_hash[:ensure] == :present
    end
    name     = @resource[:name]
    server   = @resource[:server]
    username = @resource[:username]
    password = @resource[:password]
    api_url = "http://#{server}/computer/#{name}/api/json"
    url = URI.parse(api_url)
    request = Net::HTTP::Get.new(url.path)
    request.basic_auth(username, password) if username
    response = Net::HTTP.start(url.host, url.port) { |http| http.request(request) }
    return response.kind_of?(Net::HTTPSuccess)
  end

  def create
    @property_hash = {
      :name      => @resource[:name],
      :ensure    => :present,
      :server    => @resource[:server],
      :username  => @resource[:username],
      :password  => @resource[:password],
      :executors => @resource[:executors],
      :launcher  => @resource[:launcher],
      :homedir   => @resource[:homedir],
    }
  end

  def destroy
    create if @property_hash[:name].nil?
    @property_hash[:ensure] = :absent
  end

  def self.instances
    instances = []
    catalog_resources = Puppet::Face[:catalog, :current].select('*', 'jenkins_agent')

    # Get all of the unique servers.
    # Only one set of creds will be used for any given server if multiple are available
    servers = {}
    catalog_resources.each do |resource|
      res = resource.to_hash
      servers[res[:server]] = {
        :username => res[:username],
        :password => res[:password]
      }
    end

    servers.each do |server, creds|
      username = creds[:username]
      password = creds[:password]
      api_url = "http://#{server}"
      url = URI.parse(api_url)
      request = Net::HTTP::Get.new('/computer/api/json')
      request.basic_auth(username, password) if username
      response = Net::HTTP.start(url.host, url.port) { |http| http.request(request) }
      data = JSON.parse(response.body)
      data['computer'].each do |computer|
        next if computer["displayName"] == "master"

        properties = {
          :name     => computer["displayName"],
          :ensure   => :present,
          :server   => server,
          :username => username,
          :password => password,
          :provider => :json,
          :launcher => nil
        }
        instances << new(properties)
      end
    end
    return instances
  end

  def flush
    server    = @property_hash[:server]
    username  = @property_hash[:username]
    password  = @property_hash[:password]
    host      = @property_hash[:name]
    executors = @property_hash[:executors]
    homedir   = @property_hash[:homedir]
    launcher  = case @property_hash[:launcher]
                  when :ssh  then {
                    "stapler-class" => "hudson.plugins.sshslaves.SSHLauncher",
                    "host" => host
                  }
                  when :jnlp then {
                    "stapler-class" => "hudson.slaves.JNLPLauncher"
                  }
                end

    if @property_hash[:ensure] == :present
      api_json = JSON.generate({
        "launcher" => launcher,
        "numExecutors" => executors,
        "nodeProperties" => {
          "stapler-class-bag" => "true"
        },
        "name" => host,
        "retentionStrategy" => {
          "stapler-class" => "hudson.slaves.RetentionStrategy$Always"
        },
        "remoteFS" => homedir,
        "type" => "hudson.slaves.DumbSlave$DescriptorImpl",
        "nodeDescription" => host,
        "labelString" => host,
        "mode" => "NORMAL"
      })

      api_url = "http://#{server}/computer/doCreateItem?json=#{api_json}&type=hudson.slaves.DumbSlave$DescriptorImpl&name=#{name}"
      url = URI.parse(URI.escape(api_url))
      request = Net::HTTP::Get.new("#{url.path}?#{url.query}")
      request.basic_auth(username, password) if username
      response = Net::HTTP.start(url.host, url.port) { |http| http.request(request) }
      puts response.body
    else
      api_url = "http://#{server}/computer/#{name}/doDelete"
      url = URI.parse(api_url)
      request = Net::HTTP::Get.new(url.path)
      request.basic_auth(username, password) if username
      response = Net::HTTP.start(url.host, url.port) { |http| http.request(request) }
    end
  end
end

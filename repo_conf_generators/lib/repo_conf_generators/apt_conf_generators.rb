# Copyright (c) 2008 RightScale, Inc, All Rights Reserved Worldwide.
#
# THIS PROGRAM IS CONFIDENTIAL AND PROPRIETARY TO RIGHTSCALE
# AND CONSTITUTES A VALUABLE TRADE SECRET.  Any unauthorized use,
# reproduction, modification, or disclosure of this program is
# strictly prohibited.  Any use of this program by an authorized
# licensee is strictly subject to the terms and conditions,
# including confidentiality obligations, set forth in the applicable
# License Agreement between RightScale.com, Inc. and
# the licensee.

module Apt

  module Ubuntu

    # The different generate classes will always generate an exception ("string") if there's anything that went wrong. If no exception, things went well.
    [ 'Hardy', 'Intrepid', 'Jaunty', 'Karmic' ].each do |c|
      module_eval <<-EOS
        class #{c}
          def self.generate(description, base_urls, frozen_date="latest")
            opts = { :repo_filename => "rightscale",
                     :repo_name     => "default",
                     :description   => description,
                     :base_urls     => base_urls,
                     :frozen_date   => frozen_date,
                     :enabled       => true }
            opts[:frozen_date] = frozen_date || "latest" # Optional frozen date
            Apt::Ubuntu::abstract_generate(opts)
          end
        end
      EOS
    end

    def self.path_to_sources_list
      "/etc/apt/sources.list.d"
    end

    ############## INTERNAL FUNCTIONS #######################################################
    def self.abstract_generate(params)
      platform = RightScale::Platform.new
      return unless platform.linux? && platform.linux.ubuntu?

      opts = { :enabled => true, :frozen_date => "latest"}
      opts.merge!(params)
      raise ArgumentError.new("missing parameters to generate file!") unless opts[:repo_filename] &&
                                                                      opts[:repo_name] &&
                                                                      opts[:base_urls] &&
                                                                      opts[:frozen_date] &&
                                                                      opts[:enabled]

      return unless opts[:enabled]

      codename = platform.linux.codename
      raise RightScale::PlatformError.new("Unsupported ubuntu release #{codename}") unless ['hardy', 'intrepid'].include?(codename)
      FileUtils.mkdir_p(Apt::Ubuntu::path_to_sources_list)

      if opts[:frozen_date] != 'latest'
        x = Date.parse(opts[:frozen_date]).to_s
        x.gsub!(/-/,"/")
        opts[:frozen_date] = x
      end

      mirror_list =  opts[:base_urls].map do |bu|
        bu +='/' unless bu[-1..-1] == '/' # ensure the base url is terminated with a '/'
        bu + opts[:frozen_date]
      end
      config_body = ""
      mirror_list.each do |mirror_url|
        config_body += <<END
deb #{mirror_url} #{codename} main restricted multiverse universe
deb #{mirror_url} #{codename}-updates main restricted multiverse universe
deb #{mirror_url} #{codename}-security main restricted multiverse universe

END
      end

      target_filename = "#{Apt::Ubuntu::path_to_sources_list}/#{opts[:repo_filename]}.sources.list"
      FileUtils.rm_f(target_filename) if File.exists?(target_filename)
      File.open(target_filename,'w') { |f| f.write(config_body) }
      FileUtils.mv("/etc/apt/sources.list", "/etc/apt/sources.list.ORIG") if File.exists?("/etc/apt/sources.list")

      mirror_list
    end
  end
end

# Examples of usage...
#Apt::Ubuntu::Hardy.generate("Hardy", ["http://a.com/ubuntu_daily"], "20081010")
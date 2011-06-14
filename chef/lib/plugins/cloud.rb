#
# Copyright (c) 2011 RightScale Inc
#
# Permission is hereby granted, free of charge, to any person obtaining
# a copy of this software and associated documentation files (the
# "Software"), to deal in the Software without restriction, including
# without limitation the rights to use, copy, modify, merge, publish,
# distribute, sublicense, and/or sell copies of the Software, and to
# permit persons to whom the Software is furnished to do so, subject to
# the following conditions:
#
# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
# LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
# OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
# WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

provides "cloud"

require_plugin "network"

begin
  # create the default cloud using ohai for detection, if necessary.
  cloud Mash.new
  options = {:ohai_node => self}

  # ensure metadata tree(s) are built using Mash.
  options[:metadata_tree_climber] = {:tree_class => Mash}

  # ensure user metadata is returned in raw form for legacy node support.
  options[:user_metadata] = {:metadata_tree_climber => {:create_leaf_override => lambda { |_, value| value }}}

  default_option([:user_metadata, :metadata_tree_climber, :create_leaf_override], method(:create_user_metadata_leaf))
  cloud_instance = ::RightScale::CloudFactory.instance.create(::RightScale::CloudFactory::UNKNOWN_CLOUD_NAME, options)
  cloud[:provider] = cloud_instance.name

  # create node using cloud name.
  provides cloud.name.to_s

  named_cloud_node = nil
  self.instance_eval("#{cloud.name} Mash.new\nnamed_cloud_node = #{cloud.name}")
  named_cloud_node.update(cloud_instance.build_metadata(:cloud))

  # user metadata appears as a node of cloud metadata for legacy support.
  named_cloud_node[:userdata] = cloud_instance.build_metadata(:user)

  # cloud may have specific details to insert into ohai node(s).
  cloud_instance.update_details

  # expecting public/private IPs to come from all clouds.
  cloud[:public_ips] = [ named_cloud_node[:public_ipv4] || named_cloud_node[:public_ip] ]
  cloud[:private_ips] = [ named_cloud_node[:local_ipv4] || named_cloud_node[:private_ip] ]

rescue Exception => e
  # cloud was unresolvable, but not all ohai use cases are cloud instances.
  Ohai::Log.debug("#{e.class}\n#{e.message}: #{e.backtrace.join("\n")}")
  cloud nil
end

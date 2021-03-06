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

# set abbreviation for env var generation to be same as ec2 for scripters.
abbreviation :ec2

# Searches for a file containing dhcp lease information.
def dhcp_lease_provider
  if platform.windows?
    timeout = Time.now + 20 * 60  # 20 minutes
    logger = option(:logger)
    while Time.now < timeout
      ipconfig_data = `ipconfig /all`
      match_result = ipconfig_data.match(/DHCP Server.*\: (\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})/)
      unless match_result.nil? || match_result[1].nil?
        return match_result[1]
      end
      # it may take time to resolve the DHCP Server for this instance, so sleepy wait.
      logger.info("ipconfig /all did not contain any DHCP Servers. Retrying in 10 seconds...")
      sleep 10
    end
  else
    leases_file = %w{/var/lib/dhcp/dhclient.eth0.leases /var/lib/dhcp3/dhclient.eth0.leases /var/lib/dhclient/dhclient-eth0.leases /var/lib/dhclient-eth0.leases /var/lib/dhcpcd/dhcpcd-eth0.info}.find{|dhcpconfig| File.exist?(dhcpconfig)}
    unless leases_file.nil?
      lease_file_content = File.read(leases_file)

      dhcp_lease_provider_ip = lease_file_content[/DHCPSID='(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})'/, 1]
      return dhcp_lease_provider_ip unless dhcp_lease_provider_ip.nil?

      # leases are appended to the lease file, so to get the appropriate dhcp lease provider, we must grab
      # the info from the last lease entry.
      #
      # reverse the content and reverse the regex to find the dhcp lease provider from the last lease entry
      lease_file_content.reverse!
      dhcp_lease_provider_ip = lease_file_content[/(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}) reifitnedi-revres-pchd/, 1]
      return dhcp_lease_provider_ip.reverse unless dhcp_lease_provider_ip.nil?
    end
  end

  # no known defaults so we must fail at this point.
  fail("Cannot determine dhcp lease provider for cloudstack instance")
end

# set default hosts before extending ec2. avoid search for dhcp lease provider
# in case host was given explicitly.
unless option('metadata_source/hosts')
  default_option('metadata_source/hosts', [{:host => dhcp_lease_provider, :port => 80}])
end

# cloud metadata root differs from EC2 (user use the same).
default_option(:cloud_metadata_root_path, "latest")

# cloudstack cloud metadata cannot query the list of values at root but instead
# relies on a predefined list.
default_option('cloud_metadata/metadata_provider/query_override', lambda do |provider, path|
  if path.chomp('/') == provider.metadata_tree_climber.root_path
    leaf_names = %w{service-offering availability-zone local-ipv4 local-hostname public-ipv4 public-hostname instance-id}
    return leaf_names.join("\n")
  end
  return provider.metadata_source.query(path)
end)

# override metadata soures.  Using only HTTP source
metadata_source 'metadata_sources/http_metadata_source'

# extend EC2 cloud definition.
extend_cloud :ec2

# Determines if the current instance is running on cloudstack.
def is_current_cloud?
  # FIX: the following cloud check needs to be strengthened since it the result
  # returned true even when not on a cloud instance. non-distinctive cloud
  # checks make automatic cloud detection impossible (not a critical feature,
  # but it's nice-to-have).
  #
  # it is usually possible to open a connection to the DHCP server (anonymous
  # authentication fails but the connection is established). perhaps
  # successfully retrieving some minimal metadata from the service?. is it
  # possible instead to do a has_mac? check here like some other clouds?
  #
  # anyway, better to return false instead of erroneously detecting cloudstack.
  #
  # source = create_dependency_type(:user_metadata, :metadata_source)
  # return ::RightScale::CloudUtilities.can_contact_metadata_server?(source.host, source.port)
  false
end

# Updates details of cloudstack instance.
def update_details
  details = {}
  hosts = option('metadata_source/hosts')
  # do not resolve the dhcp lease providr again.  just get it from the cloud host option
  details[:dhcp_lease_provider_ip] = hosts.first[:host]
  return details
end

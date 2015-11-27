require 'puppet'
require 'puppet/type'

Puppet::Type.type(:firewalld_zone).provide :firewall_cmd do
  desc "Interact with firewall-cmd"


  commands :firewall_cmd => 'firewall-cmd'


  def exec_firewall(*extra_args)
    args=[]
    args << '--permanent'
    args << extra_args
    args.flatten!
    firewall_cmd(args)
  end

  def zone_exec_firewall(*extra_args)
    args = [ "--zone=#{@resource[:name]}" ]
    exec_firewall(args, extra_args)
  end

  def exists?
    exec_firewall('--get-zones').split(" ").include?(@resource[:name])
  end

  def create
    self.debug("Creating new zone #{@resource[:name]} with target: '#{@resource[:target]}'")
    exec_firewall('--new-zone', @resource[:name])
    self.target=(@resource[:target]) if @resource[:target]
  end

  def destroy
    self.debug("Deleting zone #{@resource[:name]}")
    exec_firewall('--delete-zone', @resource[:name])
  end

  def target
    zone_exec_firewall('--get-target').chomp
  end

  def target=(t)
    self.debug("Setting target for zone #{@resource[:name]} to #{@resource[:target]}")
    zone_exec_firewall('--set-target', @resource[:target])
  end

  def sources
    zone_exec_firewall('--list-sources').chomp.split(" ") || []
  end

  def sources=(new_sources)
    new_sources ||= []
    cur_sources = self.sources
    (new_sources - cur_sources).each do |s|
      self.debug("Adding source '#{s}' to zone #{@resource[:name]}")
      zone_exec_firewall('--add-source', s)
    end
    (cur_sources - new_sources).each do |s|
      self.debug("Removing source '#{s}' from zone #{@resource[:name]}")
      zone_exec_firewall('--remove-source', s)
    end
  end

  def icmp_blocks
    get_icmp_blocks()
  end

  def icmp_blocks=(i)
    set_blocks = Array.new
    remove_blocks = Array.new
    
    case i
    
    when Array then
    
        get_icmp_blocks.each do |remove_block|
                if !i.include?(remove_block)
                    self.debug("removing block #{remove_block} from zone #{@resource[:name]}")
                    remove_blocks.push(remove_block)
                end
        end
    
        i.each do |block|
        
            if block.is_a?(String)
                if get_icmp_types().include?(block)
                    self.debug("adding block #{block} to zone #{@resource[:name]}")
                    set_blocks.push(block)
                else
                    valid_types = get_icmp_types().join(', ')
                    raise Puppet::Error, "#{block} is not a valid icmp type on this system! Valid types are: #{valid_types}"
                end
            else
                raise Puppet::Error, "parameter icmp_blocks must be a string or array of strings!"
            end
        end
    when String then
    
        get_icmp_blocks.reject { |x| x == i }.each do |remove_block|
            self.debug("removing block #{remove_block} from zone #{@resource[:name]}")
            remove_blocks.push(remove_block)
        end
    
        if get_icmp_types().include?(i)
            self.debug("adding block #{i} to zone #{@resource[:name]}")
            set_blocks.push(i)
        else
            valid_types = get_icmp_types().join(', ')
            raise Puppet::Error, "#{i} is not a valid icmp type on this system! Valid types are: #{valid_types}"
        end
    else
        raise Puppet::Error, "parameter icmp_blocks must be a string or array of strings!"
    end
    if !remove_blocks.empty?
        remove_blocks.each do |block|
            zone_exec_firewall('--remove-icmp-block', block)
        end
    end
    if !set_blocks.empty?
        set_blocks.each do |block|
            zone_exec_firewall('--add-icmp-block', block)
        end
    end
  end

  ## TODO: Add Ports and other zone options
  #

  def get_rules
    zone_exec_firewall('--list-rich-rules').split(/\n/)
  end
  
  def get_services
    zone_exec_firewall('--list-services').split(' ')
  end

  def get_ports
    zone_exec_firewall('--list-ports').split(' ').map do |entry|
      port,protocol = entry.split(/\//)
      self.debug("get_ports() Found port #{port} protocol #{protocol}")
      { "port" => port, "protocol" => protocol }
    end
  end
  
  def get_icmp_blocks
    zone_exec_firewall('--list-icmp-blocks').split(' ').sort
  end
  
  def get_icmp_types
    exec_firewall('--get-icmptypes').split(' ')
  end

end


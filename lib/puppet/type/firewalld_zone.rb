require 'puppet'

Puppet::Type.newtype(:firewalld_zone) do

  ensurable
  

  def generate
    if self[:purge_rich_rules] == :true
      return purge_rich_rules
    end
  end

  newparam(:name) do
    desc "Name of the rule resource in Puppet"
  end

  newparam(:zone) do
    desc "Name of the zone"
  end

  newproperty(:target) do
    desc "Specify the target for the zone"
  end

  newparam(:purge_rich_rules) do
    desc "When set to true any rich_rules associated with this zone
          that are not managed by Puppet will be removed.
         "
    defaultto :false
    newvalues(:true, :false)
  end

  def purge_rich_rules
    return unless provider.exists?
    purge_rules = []
    puppet_rules = []
    catalog.resources.select { |r| r.is_a?(Puppet::Type::Firewalld_rich_rule) }.each do |fwr|
      puppet_rules << fwr.provider.build_rich_rule
    end
    provider.get_rules.reject { |p| puppet_rules.include?(p) }.each do |purge|
      purge_rules << Puppet::Type.type(:firewalld_rich_rule).new(
        :name     => purge,
        :raw_rule => purge,
        :ensure   => :absent,
        :zone     => self[:name]
      )
    end
    return purge_rules
  end

end


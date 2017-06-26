def state
  Facter::Util::Resolution.exec('firewall-cmd --state 2> /dev/null')
end

Facter.add(:firewalld_state) do
  confine :kernel => :linux
  setcode do
    if state == "running"
      firewalld_state = "true"
    else 
      nil
    end
  end
end

module PuppetX
  module Firewalld
    module Property
      class RichRuleAction < Puppet::Property
        def _validate_action(value)
          raise Puppet::Error, "Authorized action values are `accept`, `reject`, `drop` or `mark`, got #{value}" unless %w[accept drop reject mark].include? value
        end
        validate do |value|
          if value.is_a?(Hash)
            if value.keys.sort != [:action, :type]
              raise Puppet::Error, "Rule action hash should contain `action` and `type` keys. Use a string if you only want to declare the action to be `accept` or `reject`. Got #{value}"
            end
            _validate_action(value[:action])
          elsif value.is_a?(String)
            _validate_action(value)
          end
        end
      end
    end
  end
end

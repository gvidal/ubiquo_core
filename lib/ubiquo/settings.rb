require 'ostruct'

#Ubiquo::Settings offers a place where store settings.
#
#It stores all the values in a data structure like that:
# settings = {
#  :ubiquo => {
#    :elements_per_page => [
#      :options => {
#        :is_editable => true,
#        :default_value => 10
#      },
#      :value => 10
#    ],
#    :default_locale => [
#      :options => {
#        :is_editable => true,
#        :default_value => :es
#      },
#      :value => :es
#    ]
#   },
#  :media => {
#    :media_storage => [
#      :options => {
#        :is_editable => true,
#        :default_value => :filesystem
#      },
#      :value => :filesystem
#    ],
#    :assets_elements_per_page => [
#      :options => {
#        :is_editable => true,
#        :inherits => ubiquo.elements_per_page',
#        :default_value => :es
#      },
#      :value => :es
#    ]
#   }
# }
#
#See public methods to know how to use.
module Ubiquo
  class Settings

    # Hash were all settings will be loaded
    cattr_accessor :settings

    #New API

    #Check if settings can be overriden by users on the backend
    def self.overridable?
      settings[default_context][default_overridable_key][:value]
    end

    # Returns the options for the setting
    def self.options(name = nil, options = {})
      uhook_options(name.to_sym, options)
    end

    # Returns the allowed values for the setting
    def self.allowed_values(name = nil, options = {})
      uhook_allowed_values(name.to_sym, options)
    end

    # Returns the default value for the setting
    def self.default_value(name = nil, options = {})
      uhook_default_value(name.to_sym, options)
    end

    #Load all user overrides from backend
    def self.load_from_backend!
      uhook_load_from_backend!
    rescue Exception => e
      warn "Could not load settings properly, please check all settings exist on the database and types are correct."
      0
    end

    # Add alias to block assignement in plugin register
    def self.setting(*args)
      add(args)
    end

    #Accesor to a context or a setting
    def self.[](key, options = {})
      #
      # current_context = media
      # key = assets_elements_per_page
      #     -> return value
      return context(self.current_context).get(key, options) if option_exists?(key)
      #
      # current_context = media
      # key = elements_per_page
      # setting at [:ubiquo][key] exists
      #     -> return value of [:ubiquo][key]
      return context(default_context).get(key, options) if option_exists?(key, default_context)
      # current_context = media
      # key = design
      # setting at [:ubiquo][key] don't exists
      #     -> return context ubuquo_design
      return context(key.to_sym) if context_exists?(key)
      raise OptionNotFound
    end

    #Needed to set a value directly with square brackets
    def self.[]=(key, value)
      #
      # current_context = media
      # key = assets_elements_per_page
      #     -> return value
      return set(key, value) if option_exists?(key)
      #
      # current_context = media
      # key = elements_per_page
      # setting at [:ubiquo][key] exists
      #     -> return value of [:ubiquo][key]
      return context(default_context).set(key, value) if option_exists?(key, set.default_context)
      raise OptionNotFound
    end

    def self.regenerate_settings
      settings.each do |context, s|
        s.each do |key, value|
          if value[:options][:original_parameters] && key != default_overridable_key
            original_parameters = value[:options][:original_parameters]
            original_options = value[:options][:original_parameters][:options]
            original_options.merge!(:is_a_connector_reload => true)
            self.context(context).add original_parameters[:name],
                                      original_parameters[:default_value],
                                      original_options
          end
        end
      end
    end

    # Returns a key ordered list of settings that can be overrided by users
    def self.get_editable_settings
      settings[current_context].map{ |s|
        s.first if s.last[:options][:is_editable]
      }.compact.sort{|a,b| a.to_s  <=> b.to_s}
    end

    # Returns a sorted list of available contexts
    def self.get_contexts
      settings.keys.sort{|a,b| a.to_s <=> b.to_s}
    end

    # Check if a value can be nil
    def self.nullable?(name)
      raise OptionNotFound if !self.option_exists?(name)
      settings[current_context][name][:options][:is_nullable]
    end

    # Check if a value can be overrided
    def self.editable?(name)
      raise OptionNotFound if !self.option_exists?(name)
      settings[current_context][name][:options][:is_editable]
    end

    # Reset all values to the status before backend overriding
    def self.reset_overrides
      settings.each do |context, setting_list|
        setting_list.each do |key, setting|
          setting[:value] = setting[:options][:default_value]
        end
      end
    end

    def self.boolean(name = nil, default_value = nil, options = {}, &block)
      options.merge!(:value_type => UbiquoBooleanSetting)
      uhook_add(name, default_value, options, &block)
    end

    def self.integer(name = nil, default_value = nil, options = {}, &block)
      options.merge!(:value_type => UbiquoIntegerSetting)
      uhook_add(name, default_value, options, &block)
    end

    def self.string(name = nil, default_value = nil, options = {}, &block)
      options.merge!(:value_type => UbiquoStringSetting)
      uhook_add(name, default_value, options, &block)
    end

    def self.symbol(name = nil, default_value = nil, options = {}, &block)
      options.merge!(:value_type => UbiquoSymbolSetting)
      uhook_add(name, default_value, options, &block)
    end

    def self.email(name = nil, default_value = nil, options = {}, &block)
      options.merge!(:value_type => UbiquoEmailSetting)
      uhook_add(name, default_value, options, &block)
    end

    def self.password(name = nil, default_value = nil, options = {}, &block)
      options.merge!(:value_type => UbiquoPasswordSetting)
      uhook_add(name, default_value, options, &block)
    end

    def self.list(name = nil, default_value = nil, options = {}, &block)
      options.merge!(:value_type => UbiquoListSetting)
      uhook_add(name, default_value, options, &block)
    end

    def self.check_type(klass, values)
      raise class_eval("Invalid#{klass}Value") if !klass.check_values(Array(values))
      true
    end

    def self.with_options(new_options = {}, &block)
      backup = @with_options
      begin
        @with_options ||= {}
        @with_options.merge!(new_options || {})
        yield(self)
      ensure
        @with_options = backup
      end
    end

    #Old API

    #Adds an option to the current context (default :ubiquo). Default value is optional.
    #options parameter was added to support the new schema
    def self.add(name = nil, default_value = nil, options = {}, &block)
      uhook_add(name, default_value, options, &block)
    end

    # example inherited_value format = 'ubiquo.elements_per_page'
    def self.add_inheritance(name, inherited_value)
      raise InvalidOptionName if !check_valid_name(name)
      raise OptionNotFound if !self.option_exists?(name)
      name = name.to_sym
      settings[self.current_context][name][:options][:inherits] = inherited_value
    end


    #
    # Deprecated: It was not used in any plugin. the default values were always set by
    # the 'add' method
    #
    #Set a default value to an existent option of the current context( default :ubiquo).
    #Example:
    #  >> Ubiquo::Settings.add(:a)
    #  >> Ubiquo::Settings.get(:a)
    #  => nil
    #  >> Ubiquo::Settings.set_default(:a, 1)
    #  >> Ubiquo::Settings.get(:a)
    #  => 1
    #
    #Can ge used with a block.
    #  >> Ubiquo::Settings.add(:a)
    #  >> Ubiquo::Settings.add(:b)
    #  >> Ubiquo::Settings.add(:c)
    #  >> Ubiquo::Settings.set_default do |configurator|
    #       configurator.a = 1
    #       configurator.b = 2
    #       configurator.c = 3
    #     end
    #  >> Ubiquo::Settings.get(:c)
    #  => 3
    def self.set_default(name = nil, default_value = nil, &block)
      settings[current_context][name][:options][:default_value] = default_value
    end

    #Set a value to an existent option of the current context( default :ubiquo).
    #Example:
    #  >> Ubiquo::Settings.add(:a)
    #  >> Ubiquo::Settings.get(:a)
    #  => nil
    #  >> Ubiquo::Settings.set(:a, 1)
    #  >> Ubiquo::Settings.get(:a)
    #  => 1
    #
    #Can ge used with a block.
    #  >> Ubiquo::Settings.add(:a)
    #  >> Ubiquo::Settings.add(:b)
    #  >> Ubiquo::Settings.add(:c)
    #  >> Ubiquo::Settings.set do |configurator|
    #       configurator.a = 1
    #       configurator.b = 2
    #       configurator.c = 3
    #     end
    #  >> Ubiquo::Settings.get(:c)
    #  => 3
    def self.set(name = nil, value = nil, options = {}, &block)
      uhook_set(name, value, options, &block)
    end

    #Get the value of a given option name in the current context(default :ubiquo). Will return the standard value if setted or default value. If no default value or standard value defined, raises Ubiquo::Settings::Ubiquo::Settings::ValueNeverSet
    #Example:
    #  >> Ubiquo::Settings.add(:a, 1)
    #  >> Ubiquo::Settings.get(:a)
    #  => 1
    #  >> Ubiquo::Settings.set(:a, 2)
    #  >> Ubiquo::Settings.get(:a)
    #  => 2
    def self.get(name, options = {})
      uhook_get(name, options)
    end

    def self.call(name, run_in, options = {})
      case option = self.get(name)
      when Proc
        method = option.ubind(run_in)
        option.arity == 0 ? method.call : method.call(options)
      when String, Symbol
        run_in.send option, options
      end
    end

    #Creates a context. Contexts contains an independent structure which stores options.
    #Example:
    #  >> Ubiquo::Settings.add(:a, 1)  # Context :ubiquo
    #  >> Ubiquo::Settings.create_context(:context)
    #  >> Ubiquo::Settings.context(:context).add(:a, 2)
    #  >> Ubiquo::Settings.context(:context).get(:a)
    #  => 2
    def self.create_context(name, &block)
      return settings[name] if settings.include?(name) && name == default_context
      raise Ubiquo::Settings::InvalidContextName if !check_valid_context_name(name)
      raise Ubiquo::Settings::AlreadyExistingContext if settings.include?(name)
      name = name.to_sym
      settings[name] = {}
      context(name, &block)
    end

    #Allow to work in the desired context. Can be used inline or as block.
    #Example:
    #  >> Ubiquo::Settings.add(:a, 1)  # Context :ubiquo
    #  >> Ubiquo::Settings.create_context(:context)
    #  >> Ubiquo::Settings.context(:context).add(:a, 2)
    #  >> Ubiquo::Settings.context(:context).get(:a)
    #  => 2
    #
    #  >> value = nil
    #  => nil
    #  >> Ubiquo::Settings.context(:context) do |config|
    #       config.set(:a), 3
    #       value = config.get(:a)
    #     end
    #  >> value
    #  => 3
    def self.context(name, &block)
      raise ContextNotFound if !self.context_exists?(name)
      if block_given?
        returning_value = nil
        begin
          old_context, @context = @context, name.to_sym
          returning_value = block.call(self)
        rescue
          raise $!
        ensure
          @context = old_context
        end
        returning_value
      else
        #@context = name.to_sym
        #return self
        # raise BlockNeeded
        myself = self
        Proxy.send(:define_method, :my_method_missing){ |method, args, block|
          return_value = nil
          myself.context(name){|contexted|
            return_value = contexted.send(method, *args, &block)
          }
          return_value
        }
        Proxy.new
      end
    end

    # Check if a setting exists
    def self.option_exists?(name, options = {})
      if options.is_a?(Hash) && options.present?
        context = options[:context]
      elsif options.present?
        context = options
      else
        context = current_context
      end
      settings[context].include?(name)
    end

    #Returns true only if the context exists
    def self.context_exists?(name)
      settings.include?(name)
    end

    private

    def self.check_valid_name(name)
      case(name)
      when Symbol, String
        !name.to_s.empty?
      else
        false
      end || !@loaded
    end

    def self.check_valid_context_name(name)
      self.check_valid_name(name) || !@loaded
    end

    def self.block_assignment(&block)
      options = OpenStruct.new()
      block.call(options)
      options.instance_variable_get("@table")
    end

    def self.default_context
      :ubiquo
    end

    def self.default_overridable_key
      :settings_overridable
    end

    def self.current_context
      @context ||= default_context
      @context.to_sym
    end

    #
    # Deprecated: It was not used in any plugin. the default values were always set by
    # the 'add' method
    #
    def self.new_context_options(name = self.current_context)
      ActiveSupport::Deprecation.warn("Ubiquo::Settings 'new_context_options' is deprecated!")
    end

    # Apply the options chosen
    def self.reinitialize options = {}
      uhook_reinitialize options
    end

    # Reset all settings and apply the options
    def self.initialize options = {}
      uhook_initialize options
    end

    # Return a hash with the default options to apply to Settings
    #
    # For example:
    #
    #  {
    #    :is_nullable => false,
    #    :is_editable => false,
    #    :is_translatable => false,
    #    :locale => default_locale
    #  }
    #
    def self.default_options
      uhook_default_options.merge(@with_options || {})
    end

    class InvalidUbiquoBooleanSettingValue < StandardError; end
    class InvalidUbiquoIntegerSettingValue < StandardError; end
    class InvalidUbiquoStringSettingValue < StandardError; end
    class InvalidUbiquoSymbolSettingValue < StandardError; end
    class InvalidUbiquoEmailSettingValue < StandardError; end
    class InvalidUbiquoPasswordSettingValue < StandardError; end
    class InvalidUbiquoListSettingValue < StandardError; end
    class InvalidOptionName < StandardError; end
    class InvalidContextName < StandardError; end
    class InvalidValue < StandardError; end
    class AlreadyExistingOption < StandardError; end
    class AlreadyExistingContext < StandardError; end
    class ContextNotFound < StandardError; end
    class OptionNotFound < StandardError; end
    class ValueNeverSet < StandardError; end
    class BlockNeeded < StandardError; end
    class InvalidSettingOverride < StandardError; end

    class Proxy
      def method_missing(method, *args, &block)
          my_method_missing(method, args, block)
      end
    end

    class << self; attr_accessor :loaded end
    @@loaded = false
  end
end

Settings = Ubiquo::Settings
module Ubiquo
  class Config
    def self.method_missing(method, *args, &block)
      if !defined?@@deprecation
        @@deprecation = true
        ActiveSupport::Deprecation.warn(%{
        -----------------------------------------------------------
        -----------------------------------------------------------
                Ubiquo::Config is deprecated!
                Use instead:
                  * Settings          in your app
                  * Ubiquo::Settings  in the plugins
                Ubiquo::Config will be removed in Ubiquo 0.9
        -----------------------------------------------------------
        -----------------------------------------------------------
        }, caller)
      end
      Ubiquo::Settings.send(method, *args, &block)
    end
    def self.const_missing(sym)
      Ubiquo::Settings.const_get sym
    end
  end
end

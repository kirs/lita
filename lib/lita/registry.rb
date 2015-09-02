require "set"

require "i18n"
require "redis-namespace"

require_relative "../lita"
require_relative "default_configuration"
require_relative "plugin_builder"

module Lita
  # An object to hold various types of data including configuration and plugins.
  # @since 4.0.0
  class Registry
    # A registry of adapters.
    # @return [Hash] A map of adapter keys to adapter classes.
    attr_accessor :adapters

    # The primary configuration object. Provides user settings for the robot.
    # @return [Configuration] The configuration object.
    attr_accessor :config

    # A registry of handlers.
    # @return [Set] The set of handlers.
    attr_accessor :handlers

    # A registry of hook handler objects.
    # @return [Hash] A hash mapping hook names to sets of objects that handle them.
    # @since 3.2.0
    attr_accessor :hooks

    # A +Logger+ object.
    # @return [::Logger] A +Logger+ object.
    attr_accessor :logger

    # The root Redis object.
    # @return [Redis::Namespace] The root Redis object.
    attr_accessor :redis

    def initialize
      reset
    end

    # Creates the default configuration object.
    def initialize_config
      self.config = DefaultConfiguration.new(self).build
      @configuration_blocks.each { |block| block.call(config) }
    end

    # Yields the configuration object. Called by the user in a +lita_config.rb+ file.
    # @yieldparam [Configuration] config The configuration object.
    # @return [void]
    def configure(&block)
      @configuration_blocks << block
    end

    # Creates objects that require user configuration.
    def finalize
      initialize_config unless config
      finalize_logger
      finalize_redis
    end

    # @overload register_adapter(key, adapter)
    #   Adds an adapter to the registry under the provided key.
    #   @param key [String, Symbol] The key that identifies the adapter.
    #   @param adapter [Class] The adapter class.
    #   @return [void]
    # @overload register_adapter(key)
    #   Adds an adapter to the registry under the provided key.
    #   @param key [String, Symbol] The key that identifies the adapter.
    #   @yield The body of the adapter class.
    #   @return [void]
    #   @since 4.0.0
    def register_adapter(key, adapter = nil, &block)
      adapter = PluginBuilder.new(key, &block).build_adapter if block

      unless adapter.is_a?(Class)
        raise ArgumentError, I18n.t("lita.core.register_adapter.block_or_class_required")
      end

      adapters[key.to_sym] = adapter
    end

    # @overload register_handler(handler)
    #   Adds a handler to the registry.
    #   @param handler [Handler] The handler class.
    #   @return [void]
    # @overload register_handler(key)
    #   Adds a handler to the registry.
    #   @param key [String] The namespace of the handler.
    #   @yield The body of the handler class.
    #   @return [void]
    #   @since 4.0.0
    def register_handler(handler_or_key, &block)
      if block
        handler = PluginBuilder.new(handler_or_key, &block).build_handler
      else
        handler = handler_or_key

        unless handler.is_a?(Class)
          raise ArgumentError, I18n.t("lita.core.register_handler.block_or_class_required")
        end
      end

      handlers << handler
    end

    # Adds a hook handler object to the registry for the given hook.
    # @return [void]
    # @since 3.2.0
    def register_hook(name, hook)
      hooks[name.to_s.downcase.strip.to_sym] << hook
    end

    # Clears the configuration object and the adapter, handler, and hook registries.
    # @return [void]
    # @since 3.2.0
    # @deprecated Will be removed in Lita 6. Create a new {Registry} instead of mutating the
    #   current one.
    def reset
      reset_adapters
      reset_handlers
      reset_hooks

      reset_config
    end

    # Resets the adapter registry, removing all registered adapters.
    # @return [void]
    # @since 3.2.0
    # @deprecated Will be removed in Lita 6. Create a new {Registry} instead of mutating the
    #   current one.
    def reset_adapters
      self.adapters = {}
    end

    # Resets the configuration object. It will need to be recreated before it can be used again.
    # @return [void]
    # @deprecated Will be removed in Lita 6. Create a new {Registry} instead of mutating the
    #   current one.
    def reset_config
      @configuration_blocks = []
      self.config = nil
    end
    alias_method :clear_config, :reset_config

    # Resets the handler registry, removing all registered handlers.
    # @return [void]
    # @since 3.2.0
    # @deprecated Will be removed in Lita 6. Create a new {Registry} instead of mutating the
    #   current one.
    def reset_handlers
      self.handlers = Set.new
    end

    # Resets the hooks registry, removing all registered hook handlers.
    # @return [void]
    # @since 3.2.0
    # @deprecated Will be removed in Lita 6. Create a new {Registry} instead of mutating the
    #   current one.
    def reset_hooks
      self.hooks = Hash.new { |h, k| h[k] = Set.new }
    end

    private

    def finalize_logger
      return if Lita.test_mode?

      self.logger = Logger.get_logger(config.robot.log_level, config.robot.log_formatter)
    end

    def finalize_redis
      raw_redis = Redis.new(config.redis)
      self.redis = Redis::Namespace.new(REDIS_NAMESPACE, redis: raw_redis)

      begin
        redis.ping
      rescue Redis::BaseError => e
        if Lita.test_mode?
          raise RedisError, I18n.t("lita.redis.test_mode_exception", message: e.message)
        else
          logger.fatal I18n.t(
            "lita.redis.exception",
            message: e.message,
            backtrace: e.backtrace.join("\n")
          )
          abort
        end
      end

      if Lita.test_mode?
        keys = redis.keys("*")
        redis.del(keys) unless keys.empty?
      end
    end

  end
end

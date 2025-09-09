# frozen_string_literal: true

module LegalSummariser
  # Configuration class for gem settings
  class Configuration
    attr_accessor :logger, :max_file_size, :timeout, :language, :enable_caching, :cache_dir

    def initialize
      @logger = nil
      @max_file_size = 50 * 1024 * 1024 # 50MB default
      @timeout = 30 # 30 seconds default
      @language = 'en'
      @enable_caching = false
      @cache_dir = '/tmp/legal_summariser_cache'
    end

    # Supported languages for analysis
    def supported_languages
      %w[en tr de fr es it]
    end

    # Validate configuration
    def validate!
      raise Error, "Invalid language: #{@language}" unless supported_languages.include?(@language)
      raise Error, "Max file size must be positive" if @max_file_size <= 0
      raise Error, "Timeout must be positive" if @timeout <= 0
    end
  end

  # Global configuration
  def self.configuration
    @configuration ||= Configuration.new
  end

  def self.configure
    yield(configuration)
    configuration.validate!
  end

  def self.reset_configuration!
    @configuration = Configuration.new
  end
end

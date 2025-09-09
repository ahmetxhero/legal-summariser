# frozen_string_literal: true

require 'digest'
require 'json'
require 'fileutils'

module LegalSummariser
  # Caching system for analysis results
  class Cache
    def initialize(cache_dir = nil)
      @cache_dir = cache_dir || LegalSummariser.configuration.cache_dir
      FileUtils.mkdir_p(@cache_dir) if LegalSummariser.configuration.enable_caching
    end

    # Generate cache key for a file
    # @param file_path [String] Path to the file
    # @param options [Hash] Analysis options
    # @return [String] Cache key
    def cache_key(file_path, options = {})
      file_stat = File.stat(file_path)
      content = "#{file_path}:#{file_stat.mtime}:#{file_stat.size}:#{options.to_json}"
      Digest::SHA256.hexdigest(content)
    end

    # Get cached result
    # @param key [String] Cache key
    # @return [Hash, nil] Cached result or nil
    def get(key)
      return nil unless LegalSummariser.configuration.enable_caching
      
      cache_file = File.join(@cache_dir, "#{key}.json")
      return nil unless File.exist?(cache_file)
      
      # Check if cache is expired (24 hours)
      return nil if File.mtime(cache_file) < Time.now - (24 * 60 * 60)
      
      JSON.parse(File.read(cache_file), symbolize_names: true)
    rescue JSON::ParserError, Errno::ENOENT
      nil
    end

    # Store result in cache
    # @param key [String] Cache key
    # @param result [Hash] Result to cache
    def set(key, result)
      return unless LegalSummariser.configuration.enable_caching
      
      cache_file = File.join(@cache_dir, "#{key}.json")
      File.write(cache_file, JSON.pretty_generate(result))
    rescue => e
      # Silently fail caching - don't break the main functionality
      LegalSummariser.configuration.logger&.warn("Cache write failed: #{e.message}")
    end

    # Clear cache
    def clear!
      return unless Dir.exist?(@cache_dir)
      
      Dir.glob(File.join(@cache_dir, "*.json")).each do |file|
        File.delete(file)
      end
    end

    # Get cache statistics
    # @return [Hash] Cache statistics
    def stats
      return { enabled: false } unless LegalSummariser.configuration.enable_caching
      
      cache_files = Dir.glob(File.join(@cache_dir, "*.json"))
      total_size = cache_files.sum { |file| File.size(file) }
      
      {
        enabled: true,
        file_count: cache_files.length,
        total_size_bytes: total_size,
        total_size_mb: (total_size / 1024.0 / 1024.0).round(2),
        cache_dir: @cache_dir
      }
    end
  end
end

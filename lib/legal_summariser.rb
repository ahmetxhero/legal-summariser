# frozen_string_literal: true

require_relative "legal_summariser/version"
require_relative "legal_summariser/configuration"
require_relative "legal_summariser/cache"
require_relative "legal_summariser/performance_monitor"
require_relative "legal_summariser/document_parser"
require_relative "legal_summariser/text_extractor"
require_relative "legal_summariser/summariser"
require_relative "legal_summariser/clause_detector"
require_relative "legal_summariser/risk_analyzer"
require_relative "legal_summariser/formatter"

module LegalSummariser
  class Error < StandardError; end
  class DocumentNotFoundError < Error; end
  class UnsupportedFormatError < Error; end

  # Main entry point for the legal summariser
  # @param file_path [String] Path to the legal document
  # @param options [Hash] Configuration options
  # @return [Hash] Summary results
  def self.summarise(file_path, options = {})
    monitor = performance_monitor
    cache = Cache.new
    
    monitor.start_timer(:total_analysis)
    
    begin
      # Validate file
      raise DocumentNotFoundError, "File not found: #{file_path}" unless File.exist?(file_path)
      
      file_size = File.size(file_path)
      raise Error, "File too large: #{file_size} bytes (max: #{configuration.max_file_size})" if file_size > configuration.max_file_size
      
      # Check cache first
      cache_key = cache.cache_key(file_path, options)
      cached_result = cache.get(cache_key)
      
      if cached_result
        configuration.logger&.info("Using cached result for #{file_path}")
        monitor.end_timer(:total_analysis)
        return cached_result
      end
      
      # Extract text from document
      monitor.start_timer(:text_extraction)
      text = TextExtractor.extract(file_path)
      extraction_time = monitor.end_timer(:text_extraction)
      
      # Record text statistics
      text_stats = TextExtractor.get_statistics(text)
      monitor.record(:document_word_count, text_stats[:word_count])
      monitor.record(:document_character_count, text_stats[:character_count])
      
      # Perform analysis components
      monitor.start_timer(:summarisation)
      summary = Summariser.new(text, options).generate
      monitor.end_timer(:summarisation)
      
      monitor.start_timer(:clause_detection)
      clauses = ClauseDetector.new(text).detect
      monitor.end_timer(:clause_detection)
      
      monitor.start_timer(:risk_analysis)
      risks = RiskAnalyzer.new(text).analyze
      monitor.end_timer(:risk_analysis)
      
      # Format results
      result = {
        plain_text: summary[:plain_text],
        key_points: summary[:key_points],
        clauses: clauses,
        risks: risks,
        metadata: {
          document_type: detect_document_type(text),
          word_count: text_stats[:word_count],
          character_count: text_stats[:character_count],
          sentence_count: text_stats[:sentence_count],
          paragraph_count: text_stats[:paragraph_count],
          file_size_bytes: file_size,
          extraction_time_seconds: extraction_time.round(3),
          processed_at: Time.now.strftime("%Y-%m-%dT%H:%M:%S%z"),
          gem_version: VERSION,
          language: configuration.language
        },
        performance: monitor.stats
      }
      
      # Cache the result
      cache.set(cache_key, result)
      
      total_time = monitor.end_timer(:total_analysis)
      configuration.logger&.info("Analysis completed in #{total_time.round(3)}s")
      
      # Apply formatting if requested
      if options[:format]
        Formatter.format(result, options[:format])
      else
        result
      end
      
    rescue => e
      monitor.end_timer(:total_analysis)
      configuration.logger&.error("Analysis failed: #{e.message}")
      raise
    end
  end

  # Detect the type of legal document
  # @param text [String] Document text
  # @return [String] Document type
  def self.detect_document_type(text)
    text_lower = text.downcase
    
    # Score different document types
    scores = {
      nda: 0,
      service_agreement: 0,
      employment_contract: 0,
      privacy_policy: 0,
      license_agreement: 0,
      terms_of_use: 0,
      purchase_agreement: 0,
      lease_agreement: 0,
      partnership_agreement: 0,
      general_contract: 1 # Base score
    }
    
    # NDA indicators
    scores[:nda] += 3 if text_lower.match?(/non.?disclosure/)
    scores[:nda] += 2 if text_lower.match?(/\bnda\b/)
    scores[:nda] += 2 if text_lower.match?(/confidential/)
    scores[:nda] += 1 if text_lower.match?(/proprietary/)
    
    # Service agreement indicators
    scores[:service_agreement] += 3 if text_lower.match?(/service agreement/)
    scores[:service_agreement] += 2 if text_lower.match?(/terms of service/)
    scores[:service_agreement] += 2 if text_lower.match?(/\btos\b/)
    scores[:service_agreement] += 1 if text_lower.match?(/deliver|provide.*service/)
    
    # Employment indicators
    scores[:employment_contract] += 3 if text_lower.match?(/employment/)
    scores[:employment_contract] += 2 if text_lower.match?(/employee|employer/)
    scores[:employment_contract] += 2 if text_lower.match?(/job|position/)
    scores[:employment_contract] += 1 if text_lower.match?(/salary|wage/)
    
    # Privacy policy indicators
    scores[:privacy_policy] += 3 if text_lower.match?(/privacy policy/)
    scores[:privacy_policy] += 2 if text_lower.match?(/data protection/)
    scores[:privacy_policy] += 2 if text_lower.match?(/gdpr|kvkk/)
    scores[:privacy_policy] += 1 if text_lower.match?(/personal data/)
    
    # License agreement indicators
    scores[:license_agreement] += 3 if text_lower.match?(/license agreement/)
    scores[:license_agreement] += 2 if text_lower.match?(/licensing/)
    scores[:license_agreement] += 1 if text_lower.match?(/intellectual property/)
    
    # Terms of use indicators
    scores[:terms_of_use] += 3 if text_lower.match?(/terms of use/)
    scores[:terms_of_use] += 2 if text_lower.match?(/user agreement/)
    scores[:terms_of_use] += 1 if text_lower.match?(/website|platform/)
    
    # Purchase agreement indicators
    scores[:purchase_agreement] += 3 if text_lower.match?(/purchase agreement/)
    scores[:purchase_agreement] += 2 if text_lower.match?(/buy|sell|purchase/)
    scores[:purchase_agreement] += 1 if text_lower.match?(/price|payment/)
    
    # Lease agreement indicators
    scores[:lease_agreement] += 3 if text_lower.match?(/lease agreement/)
    scores[:lease_agreement] += 2 if text_lower.match?(/rent|tenant|landlord/)
    scores[:lease_agreement] += 1 if text_lower.match?(/property|premises/)
    
    # Partnership agreement indicators
    scores[:partnership_agreement] += 3 if text_lower.match?(/partnership agreement/)
    scores[:partnership_agreement] += 2 if text_lower.match?(/partner|partnership/)
    scores[:partnership_agreement] += 1 if text_lower.match?(/joint venture/)
    
    # Return the type with highest score
    scores.max_by { |_, score| score }[0].to_s
  end
  
  # Get analysis statistics
  # @return [Hash] Analysis statistics
  def self.stats
    {
      performance: performance_monitor.stats,
      cache: Cache.new.stats,
      memory: performance_monitor.memory_usage,
      configuration: {
        language: configuration.language,
        max_file_size: configuration.max_file_size,
        caching_enabled: configuration.enable_caching
      }
    }
  end
  
  # Reset all statistics and cache
  def self.reset!
    performance_monitor.reset!
    Cache.new.clear!
  end

  # Batch process multiple documents
  # @param file_paths [Array<String>] Array of file paths
  # @param options [Hash] Processing options
  # @return [Array<Hash>] Array of analysis results
  def self.batch_summarise(file_paths, options = {})
    results = []
    
    file_paths.each_with_index do |file_path, index|
      begin
        configuration.logger&.info("Processing file #{index + 1}/#{file_paths.length}: #{file_path}")
        result = summarise(file_path, options)
        results << { file_path: file_path, success: true, result: result }
      rescue => e
        configuration.logger&.error("Failed to process #{file_path}: #{e.message}")
        results << { file_path: file_path, success: false, error: e.message }
      end
    end
    
    results
  end
end

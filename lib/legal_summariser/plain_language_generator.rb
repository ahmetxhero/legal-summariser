require 'net/http'
require 'json'
require 'uri'

module LegalSummariser
  # Advanced plain language generator using AI/ML models for legal text simplification
  class PlainLanguageGenerator
    class ModelError < StandardError; end
    class APIError < StandardError; end
    class ConfigurationError < StandardError; end

    # Legal jargon to plain English mappings
    LEGAL_MAPPINGS = {
      'heretofore' => 'until now',
      'hereinafter' => 'from now on',
      'whereas' => 'since',
      'whereby' => 'by which',
      'pursuant to' => 'according to',
      'notwithstanding' => 'despite',
      'aforementioned' => 'mentioned above',
      'aforestated' => 'stated above',
      'therein' => 'in that',
      'thereof' => 'of that',
      'hereunder' => 'under this',
      'thereunder' => 'under that',
      'herewith' => 'with this',
      'therewith' => 'with that',
      'henceforth' => 'from now on',
      'ipso facto' => 'by the fact itself',
      'inter alia' => 'among other things',
      'prima facie' => 'at first sight',
      'quid pro quo' => 'something for something',
      'vis-à-vis' => 'in relation to',
      'force majeure' => 'unforeseeable circumstances',
      'in perpetuity' => 'forever',
      'ab initio' => 'from the beginning',
      'bona fide' => 'genuine',
      'de facto' => 'in reality',
      'de jure' => 'by law',
      'ex parte' => 'one-sided',
      'pro rata' => 'proportionally',
      'sine qua non' => 'essential requirement'
    }.freeze

    # Complex sentence patterns to simplify
    SENTENCE_PATTERNS = [
      {
        pattern: /shall be deemed to be/i,
        replacement: 'is considered'
      },
      {
        pattern: /is hereby authorized to/i,
        replacement: 'can'
      },
      {
        pattern: /for the purpose of/i,
        replacement: 'to'
      },
      {
        pattern: /in the event that/i,
        replacement: 'if'
      },
      {
        pattern: /provided that/i,
        replacement: 'if'
      },
      {
        pattern: /subject to the provisions of/i,
        replacement: 'following the rules in'
      },
      {
        pattern: /without prejudice to/i,
        replacement: 'without affecting'
      },
      {
        pattern: /save and except/i,
        replacement: 'except for'
      },
      {
        pattern: /null and void/i,
        replacement: 'invalid'
      },
      {
        pattern: /cease and desist/i,
        replacement: 'stop'
      }
    ].freeze

    attr_reader :config, :model_config, :logger

    def initialize(config = nil)
      @config = config || LegalSummariser.configuration
      @logger = @config.logger
      @model_config = setup_model_configuration
      validate_configuration
    end

    # Generate plain language version of legal text
    def generate(text, options = {})
      return '' if text.nil? || text.strip.empty?

      @logger&.info("Generating plain language for text of length: #{text.length}")
      
      start_time = Time.now
      
      begin
        # Multi-step processing approach
        simplified_text = process_text_pipeline(text, options)
        
        duration = Time.now - start_time
        @logger&.info("Plain language generation completed in #{duration.round(2)}s")
        
        {
          original_text: text,
          simplified_text: simplified_text,
          processing_time: duration,
          readability_score: calculate_readability_score(simplified_text),
          complexity_reduction: calculate_complexity_reduction(text, simplified_text),
          metadata: {
            word_count_original: text.split.length,
            word_count_simplified: simplified_text.split.length,
            sentence_count: simplified_text.split(/[.!?]+/).length,
            avg_sentence_length: calculate_avg_sentence_length(simplified_text)
          }
        }
      rescue => e
        @logger&.error("Plain language generation failed: #{e.message}")
        raise ModelError, "Failed to generate plain language: #{e.message}"
      end
    end

    # Batch process multiple texts
    def generate_batch(texts, options = {})
      return [] if texts.nil? || texts.empty?

      @logger&.info("Processing batch of #{texts.length} texts")
      
      results = []
      texts.each_with_index do |text, index|
        begin
          result = generate(text, options.merge(batch_index: index))
          results << result
        rescue => e
          @logger&.error("Failed to process text #{index}: #{e.message}")
          results << {
            error: e.message,
            original_text: text,
            batch_index: index
          }
        end
      end
      
      results
    end

    # Get available AI models
    def available_models
      {
        local: ['rule_based', 'pattern_matching'],
        cloud: model_config[:available_models] || [],
        recommended: 'rule_based'
      }
    end

    # Fine-tune model with custom legal text pairs
    def fine_tune_model(training_data, options = {})
      return false unless training_data.is_a?(Array) && !training_data.empty?

      @logger&.info("Fine-tuning model with #{training_data.length} training examples")
      
      # For now, we'll store custom mappings for rule-based improvement
      custom_mappings_file = File.join(@config.cache_dir, 'custom_legal_mappings.json')
      
      begin
        custom_mappings = extract_custom_mappings(training_data)
        File.write(custom_mappings_file, JSON.pretty_generate(custom_mappings))
        
        @logger&.info("Custom mappings saved to #{custom_mappings_file}")
        true
      rescue => e
        @logger&.error("Fine-tuning failed: #{e.message}")
        false
      end
    end

    # Load custom trained mappings
    def load_custom_mappings
      custom_mappings_file = File.join(@config.cache_dir, 'custom_legal_mappings.json')
      
      if File.exist?(custom_mappings_file)
        JSON.parse(File.read(custom_mappings_file))
      else
        {}
      end
    rescue => e
      @logger&.error("Failed to load custom mappings: #{e.message}")
      {}
    end

    private

    def setup_model_configuration
      {
        model_type: 'rule_based', # Default to rule-based for reliability
        api_endpoint: ENV['LEGAL_AI_API_ENDPOINT'],
        api_key: ENV['LEGAL_AI_API_KEY'],
        timeout: 30,
        max_tokens: 2000,
        temperature: 0.3, # Lower temperature for more consistent legal text
        available_models: ['gpt-3.5-turbo', 'claude-3-haiku', 'llama-2-legal']
      }
    end

    def validate_configuration
      raise ConfigurationError, "Configuration is required" unless @config
      raise ConfigurationError, "Logger is required" unless @config.logger
      raise ConfigurationError, "Cache directory is required" unless @config.cache_dir
    end

    def process_text_pipeline(text, options = {})
      # Step 1: Basic legal jargon replacement
      simplified = replace_legal_jargon(text)
      
      # Step 2: Sentence pattern simplification
      simplified = simplify_sentence_patterns(simplified)
      
      # Step 3: Custom mappings from fine-tuning
      simplified = apply_custom_mappings(simplified)
      
      # Step 4: Advanced AI processing (if available and enabled)
      if options[:use_ai_model] && model_available?
        simplified = process_with_ai_model(simplified, options)
      end
      
      # Step 5: Final cleanup and formatting
      cleanup_text(simplified)
    end

    def replace_legal_jargon(text)
      result = text.dup
      
      # Apply all legal mappings
      LEGAL_MAPPINGS.each do |legal_term, plain_term|
        # Case-insensitive replacement while preserving original case
        result.gsub!(/\b#{Regexp.escape(legal_term)}\b/i) do |match|
          if match == match.upcase
            plain_term.upcase
          elsif match == match.capitalize
            plain_term.capitalize
          else
            plain_term
          end
        end
      end
      
      result
    end

    def simplify_sentence_patterns(text)
      result = text.dup
      
      SENTENCE_PATTERNS.each do |pattern_info|
        result.gsub!(pattern_info[:pattern], pattern_info[:replacement])
      end
      
      result
    end

    def apply_custom_mappings(text)
      custom_mappings = load_custom_mappings
      result = text.dup
      
      custom_mappings.each do |legal_term, plain_term|
        result.gsub!(/\b#{Regexp.escape(legal_term)}\b/i, plain_term)
      end
      
      result
    end

    def process_with_ai_model(text, options = {})
      return text unless model_config[:api_endpoint] && model_config[:api_key]

      begin
        response = call_ai_api(text, options)
        response['simplified_text'] || text
      rescue => e
        @logger&.warn("AI model processing failed, falling back to rule-based: #{e.message}")
        text
      end
    end

    def call_ai_api(text, options = {})
      uri = URI(model_config[:api_endpoint])
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true if uri.scheme == 'https'
      http.read_timeout = model_config[:timeout]

      request = Net::HTTP::Post.new(uri)
      request['Authorization'] = "Bearer #{model_config[:api_key]}"
      request['Content-Type'] = 'application/json'
      
      prompt = build_ai_prompt(text, options)
      
      request.body = JSON.generate({
        model: options[:model] || 'gpt-3.5-turbo',
        messages: [
          {
            role: 'system',
            content: 'You are a legal expert specializing in converting complex legal language into plain English while maintaining accuracy and legal meaning.'
          },
          {
            role: 'user',
            content: prompt
          }
        ],
        max_tokens: model_config[:max_tokens],
        temperature: model_config[:temperature]
      })

      response = http.request(request)
      
      unless response.code == '200'
        raise APIError, "API request failed with code #{response.code}: #{response.body}"
      end

      JSON.parse(response.body)
    end

    def build_ai_prompt(text, options = {})
      <<~PROMPT
        Please convert the following legal text into plain English while maintaining its legal accuracy and meaning:

        Legal Text:
        #{text}

        Requirements:
        - Use simple, everyday language
        - Maintain legal accuracy
        - Keep the same meaning and intent
        - Use shorter sentences where possible
        - Replace legal jargon with common terms
        - Ensure readability for general audience

        Please provide only the simplified version without explanations.
      PROMPT
    end

    def cleanup_text(text)
      # Remove excessive whitespace
      cleaned = text.gsub(/\s+/, ' ').strip
      
      # Fix punctuation spacing
      cleaned = cleaned.gsub(/\s+([,.;:!?])/, '\1')
      cleaned = cleaned.gsub(/([.!?])\s*([A-Z])/, '\1 \2')
      
      # Ensure proper sentence endings
      cleaned += '.' unless cleaned.end_with?('.', '!', '?')
      
      cleaned
    end

    def calculate_readability_score(text)
      # Simplified Flesch Reading Ease calculation
      sentences = text.split(/[.!?]+/).length
      words = text.split.length
      syllables = count_syllables(text)
      
      return 0 if sentences == 0 || words == 0
      
      avg_sentence_length = words.to_f / sentences
      avg_syllables_per_word = syllables.to_f / words
      
      score = 206.835 - (1.015 * avg_sentence_length) - (84.6 * avg_syllables_per_word)
      [0, [100, score].min].max.round(1)
    end

    def count_syllables(text)
      # Simple syllable counting heuristic
      text.downcase.gsub(/[^a-z]/, '').scan(/[aeiouy]+/).length
    end

    def calculate_complexity_reduction(original, simplified)
      original_complexity = calculate_text_complexity(original)
      simplified_complexity = calculate_text_complexity(simplified)
      
      return 0 if original_complexity == 0
      
      reduction = ((original_complexity - simplified_complexity) / original_complexity.to_f * 100).round(1)
      [0, reduction].max
    end

    def calculate_text_complexity(text)
      # Complexity based on average word length, sentence length, and jargon count
      words = text.split
      sentences = text.split(/[.!?]+/)
      
      avg_word_length = words.map(&:length).sum.to_f / words.length
      avg_sentence_length = words.length.to_f / sentences.length
      jargon_count = count_legal_jargon(text)
      
      (avg_word_length * 2) + (avg_sentence_length * 0.5) + (jargon_count * 3)
    end

    def count_legal_jargon(text)
      LEGAL_MAPPINGS.keys.count { |term| text.downcase.include?(term.downcase) }
    end

    def calculate_avg_sentence_length(text)
      sentences = text.split(/[.!?]+/).reject(&:empty?)
      return 0 if sentences.empty?
      
      total_words = sentences.map { |s| s.split.length }.sum
      (total_words.to_f / sentences.length).round(1)
    end

    def extract_custom_mappings(training_data)
      mappings = {}
      
      training_data.each do |example|
        next unless example.is_a?(Hash) && example['legal'] && example['plain']
        
        legal_text = example['legal']
        plain_text = example['plain']
        
        # Extract potential mappings using simple pattern matching
        legal_words = legal_text.split
        plain_words = plain_text.split
        
        # This is a simplified extraction - in practice, you'd use more sophisticated NLP
        legal_words.each do |legal_word|
          next if legal_word.length < 4 # Skip short words
          
          # Look for potential plain language equivalents
          plain_words.each do |plain_word|
            if similar_context?(legal_word, plain_word, legal_text, plain_text)
              mappings[legal_word.downcase] = plain_word.downcase
            end
          end
        end
      end
      
      mappings
    end

    def similar_context?(legal_word, plain_word, legal_text, plain_text)
      # Simple heuristic to determine if words might be equivalent
      legal_index = legal_text.downcase.index(legal_word.downcase)
      plain_index = plain_text.downcase.index(plain_word.downcase)
      
      return false unless legal_index && plain_index
      
      # Check if words appear in similar positions (rough heuristic)
      legal_position = legal_index.to_f / legal_text.length
      plain_position = plain_index.to_f / plain_text.length
      
      (legal_position - plain_position).abs < 0.2
    end

    def model_available?
      model_config[:api_endpoint] && model_config[:api_key]
    end
  end
end

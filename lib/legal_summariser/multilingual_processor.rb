require 'json'
require 'net/http'
require 'uri'

module LegalSummariser
  # Advanced multilingual processing for legal documents across different languages
  class MultilingualProcessor
    class LanguageError < StandardError; end
    class TranslationError < StandardError; end
    class UnsupportedLanguageError < StandardError; end

    # Supported languages with their configurations
    SUPPORTED_LANGUAGES = {
      'en' => {
        name: 'English',
        legal_systems: ['common_law', 'statutory'],
        date_formats: ['MM/dd/yyyy', 'dd/MM/yyyy'],
        currency: 'USD',
        legal_terms_db: 'en_legal_terms.json'
      },
      'tr' => {
        name: 'Turkish',
        legal_systems: ['civil_law'],
        date_formats: ['dd.MM.yyyy', 'dd/MM/yyyy'],
        currency: 'TRY',
        legal_terms_db: 'tr_legal_terms.json'
      },
      'de' => {
        name: 'German',
        legal_systems: ['civil_law'],
        date_formats: ['dd.MM.yyyy', 'dd/MM/yyyy'],
        currency: 'EUR',
        legal_terms_db: 'de_legal_terms.json'
      },
      'fr' => {
        name: 'French',
        legal_systems: ['civil_law'],
        date_formats: ['dd/MM/yyyy', 'dd.MM.yyyy'],
        currency: 'EUR',
        legal_terms_db: 'fr_legal_terms.json'
      },
      'es' => {
        name: 'Spanish',
        legal_systems: ['civil_law'],
        date_formats: ['dd/MM/yyyy', 'dd.MM.yyyy'],
        currency: 'EUR',
        legal_terms_db: 'es_legal_terms.json'
      },
      'it' => {
        name: 'Italian',
        legal_systems: ['civil_law'],
        date_formats: ['dd/MM/yyyy', 'dd.MM.yyyy'],
        currency: 'EUR',
        legal_terms_db: 'it_legal_terms.json'
      },
      'pt' => {
        name: 'Portuguese',
        legal_systems: ['civil_law'],
        date_formats: ['dd/MM/yyyy'],
        currency: 'EUR',
        legal_terms_db: 'pt_legal_terms.json'
      },
      'nl' => {
        name: 'Dutch',
        legal_systems: ['civil_law'],
        date_formats: ['dd-MM-yyyy', 'dd/MM/yyyy'],
        currency: 'EUR',
        legal_terms_db: 'nl_legal_terms.json'
      }
    }.freeze

    # Legal term translations for different languages
    LEGAL_TERM_TRANSLATIONS = {
      'contract' => {
        'tr' => 'sözleşme',
        'de' => 'Vertrag',
        'fr' => 'contrat',
        'es' => 'contrato',
        'it' => 'contratto',
        'pt' => 'contrato',
        'nl' => 'contract'
      },
      'agreement' => {
        'tr' => 'anlaşma',
        'de' => 'Vereinbarung',
        'fr' => 'accord',
        'es' => 'acuerdo',
        'it' => 'accordo',
        'pt' => 'acordo',
        'nl' => 'overeenkomst'
      },
      'liability' => {
        'tr' => 'sorumluluk',
        'de' => 'Haftung',
        'fr' => 'responsabilité',
        'es' => 'responsabilidad',
        'it' => 'responsabilità',
        'pt' => 'responsabilidade',
        'nl' => 'aansprakelijkheid'
      },
      'confidentiality' => {
        'tr' => 'gizlilik',
        'de' => 'Vertraulichkeit',
        'fr' => 'confidentialité',
        'es' => 'confidencialidad',
        'it' => 'riservatezza',
        'pt' => 'confidencialidade',
        'nl' => 'vertrouwelijkheid'
      },
      'termination' => {
        'tr' => 'fesih',
        'de' => 'Kündigung',
        'fr' => 'résiliation',
        'es' => 'terminación',
        'it' => 'risoluzione',
        'pt' => 'rescisão',
        'nl' => 'beëindiging'
      },
      'jurisdiction' => {
        'tr' => 'yargı yetkisi',
        'de' => 'Gerichtsbarkeit',
        'fr' => 'juridiction',
        'es' => 'jurisdicción',
        'it' => 'giurisdizione',
        'pt' => 'jurisdição',
        'nl' => 'jurisdictie'
      }
    }.freeze

    attr_reader :config, :logger, :current_language, :translation_cache

    def initialize(config = nil)
      @config = config || LegalSummariser.configuration
      @logger = @config.logger
      @current_language = @config.language || 'en'
      @translation_cache = {}
      
      validate_language(@current_language)
    end

    # Detect the language of a legal document
    def detect_language(text)
      return 'en' if text.nil? || text.strip.empty?

      @logger&.info("Detecting language for text of length: #{text.length}")
      
      language_scores = {}
      
      # Score based on legal terms presence
      SUPPORTED_LANGUAGES.each do |lang_code, lang_config|
        score = calculate_language_score(text, lang_code)
        language_scores[lang_code] = score
      end
      
      # Get the language with highest score
      detected_language = language_scores.max_by { |_, score| score }.first
      confidence = language_scores[detected_language]
      
      @logger&.info("Detected language: #{detected_language} (confidence: #{confidence.round(2)})")
      
      {
        language: detected_language,
        confidence: confidence,
        language_name: SUPPORTED_LANGUAGES[detected_language][:name],
        all_scores: language_scores
      }
    end

    # Process legal document in multiple languages
    def process_multilingual(text, target_languages = nil, options = {})
      target_languages ||= ['en']
      target_languages = [target_languages] unless target_languages.is_a?(Array)
      
      @logger&.info("Processing text for languages: #{target_languages.join(', ')}")
      
      # Detect source language
      detection_result = detect_language(text)
      source_language = detection_result[:language]
      
      results = {
        source_language: source_language,
        detection_confidence: detection_result[:confidence],
        processed_languages: {},
        metadata: {
          original_length: text.length,
          processing_time: 0,
          translations_used: []
        }
      }
      
      start_time = Time.now
      
      target_languages.each do |target_lang|
        begin
          if target_lang == source_language
            # Same language - just process normally
            processed_text = process_in_language(text, target_lang, options)
          else
            # Different language - translate then process
            translated_text = translate_text(text, source_language, target_lang, options)
            processed_text = process_in_language(translated_text, target_lang, options)
            results[:metadata][:translations_used] << "#{source_language} -> #{target_lang}"
          end
          
          results[:processed_languages][target_lang] = processed_text
          
        rescue => e
          @logger&.error("Failed to process in language #{target_lang}: #{e.message}")
          results[:processed_languages][target_lang] = {
            error: e.message,
            fallback_used: true
          }
        end
      end
      
      results[:metadata][:processing_time] = Time.now - start_time
      results
    end

    # Translate legal text between languages
    def translate_text(text, source_lang, target_lang, options = {})
      return text if source_lang == target_lang
      
      cache_key = generate_translation_cache_key(text, source_lang, target_lang)
      
      # Check cache first
      if @translation_cache[cache_key] && !options[:force_retranslate]
        @logger&.info("Using cached translation for #{source_lang} -> #{target_lang}")
        return @translation_cache[cache_key]
      end
      
      @logger&.info("Translating text from #{source_lang} to #{target_lang}")
      
      begin
        # Try different translation methods
        translated_text = nil
        
        if options[:use_ai_translation] && translation_api_available?
          translated_text = translate_with_ai_api(text, source_lang, target_lang, options)
        end
        
        # Fallback to rule-based translation
        translated_text ||= translate_with_rules(text, source_lang, target_lang)
        
        # Post-process translation for legal accuracy
        translated_text = post_process_translation(translated_text, source_lang, target_lang)
        
        # Cache the result
        @translation_cache[cache_key] = translated_text
        
        translated_text
        
      rescue => e
        @logger&.error("Translation failed: #{e.message}")
        raise TranslationError, "Failed to translate from #{source_lang} to #{target_lang}: #{e.message}"
      end
    end

    # Process text in a specific language context
    def process_in_language(text, language, options = {})
      validate_language(language)
      
      @logger&.info("Processing text in #{language} (#{SUPPORTED_LANGUAGES[language][:name]})")
      
      # Set language-specific processing context
      old_language = @current_language
      @current_language = language
      
      begin
        # Apply language-specific legal processing
        processed = {
          language: language,
          language_name: SUPPORTED_LANGUAGES[language][:name],
          legal_system: SUPPORTED_LANGUAGES[language][:legal_systems],
          processed_text: text,
          legal_terms: extract_legal_terms_for_language(text, language),
          cultural_adaptations: apply_cultural_adaptations(text, language),
          formatting: apply_language_formatting(text, language),
          metadata: {
            word_count: text.split.length,
            character_count: text.length,
            legal_term_count: 0
          }
        }
        
        # Extract and translate legal terms
        processed[:legal_terms] = extract_and_process_legal_terms(text, language)
        processed[:metadata][:legal_term_count] = processed[:legal_terms].length
        
        # Apply language-specific summarization if requested
        if options[:summarize]
          processed[:summary] = summarize_in_language(text, language, options)
        end
        
        # Apply language-specific risk analysis if requested
        if options[:analyze_risks]
          processed[:risks] = analyze_risks_in_language(text, language, options)
        end
        
        processed
        
      ensure
        @current_language = old_language
      end
    end

    # Get supported languages information
    def supported_languages
      SUPPORTED_LANGUAGES.map do |code, config|
        {
          code: code,
          name: config[:name],
          legal_systems: config[:legal_systems],
          date_formats: config[:date_formats],
          currency: config[:currency]
        }
      end
    end

    # Validate if a language is supported
    def language_supported?(language_code)
      SUPPORTED_LANGUAGES.key?(language_code)
    end

    # Get language-specific legal term database
    def get_legal_terms_for_language(language)
      return {} unless language_supported?(language)
      
      terms_file = File.join(@config.cache_dir, 'legal_terms', SUPPORTED_LANGUAGES[language][:legal_terms_db])
      
      if File.exist?(terms_file)
        JSON.parse(File.read(terms_file))
      else
        generate_default_legal_terms(language)
      end
    rescue => e
      @logger&.error("Failed to load legal terms for #{language}: #{e.message}")
      {}
    end

    # Cross-language legal term mapping
    def map_legal_terms_across_languages(terms, source_lang, target_lang)
      mapped_terms = {}
      
      terms.each do |term|
        # Check if we have a direct translation
        if LEGAL_TERM_TRANSLATIONS[term.downcase] && LEGAL_TERM_TRANSLATIONS[term.downcase][target_lang]
          mapped_terms[term] = LEGAL_TERM_TRANSLATIONS[term.downcase][target_lang]
        else
          # Use fuzzy matching or keep original
          mapped_terms[term] = find_similar_term(term, target_lang) || term
        end
      end
      
      mapped_terms
    end

    private

    def validate_language(language_code)
      unless language_supported?(language_code)
        raise UnsupportedLanguageError, "Language '#{language_code}' is not supported. Supported languages: #{SUPPORTED_LANGUAGES.keys.join(', ')}"
      end
    end

    def calculate_language_score(text, language_code)
      score = 0.0
      text_lower = text.downcase
      
      # Check for language-specific legal terms
      legal_terms = get_legal_terms_for_language(language_code)
      legal_terms.each do |term, _|
        if text_lower.include?(term.downcase)
          score += 1.0
        end
      end
      
      # Check for language-specific patterns
      case language_code
      when 'en'
        score += text_lower.scan(/\b(shall|hereby|whereas|therefore)\b/).length * 0.5
      when 'tr'
        score += text_lower.scan(/\b(madde|fıkra|sözleşme|taraf)\b/).length * 0.5
      when 'de'
        score += text_lower.scan(/\b(artikel|absatz|vertrag|partei)\b/).length * 0.5
      when 'fr'
        score += text_lower.scan(/\b(article|alinéa|contrat|partie)\b/).length * 0.5
      when 'es'
        score += text_lower.scan(/\b(artículo|párrafo|contrato|parte)\b/).length * 0.5
      when 'it'
        score += text_lower.scan(/\b(articolo|comma|contratto|parte)\b/).length * 0.5
      end
      
      # Normalize score
      word_count = text.split.length
      return 0.0 if word_count == 0
      
      score / word_count
    end

    def generate_translation_cache_key(text, source_lang, target_lang)
      content_hash = Digest::MD5.hexdigest(text)[0..15]
      "#{source_lang}_#{target_lang}_#{content_hash}"
    end

    def translation_api_available?
      ENV['TRANSLATION_API_KEY'] && ENV['TRANSLATION_API_ENDPOINT']
    end

    def translate_with_ai_api(text, source_lang, target_lang, options = {})
      uri = URI(ENV['TRANSLATION_API_ENDPOINT'])
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true if uri.scheme == 'https'
      
      request = Net::HTTP::Post.new(uri)
      request['Authorization'] = "Bearer #{ENV['TRANSLATION_API_KEY']}"
      request['Content-Type'] = 'application/json'
      
      request.body = JSON.generate({
        text: text,
        source_language: source_lang,
        target_language: target_lang,
        domain: 'legal',
        preserve_formatting: true
      })
      
      response = http.request(request)
      
      unless response.code == '200'
        raise TranslationError, "Translation API failed with code #{response.code}"
      end
      
      result = JSON.parse(response.body)
      result['translated_text']
    end

    def translate_with_rules(text, source_lang, target_lang)
      translated = text.dup
      
      # Apply legal term translations
      LEGAL_TERM_TRANSLATIONS.each do |english_term, translations|
        if translations[source_lang] && translations[target_lang]
          source_term = translations[source_lang]
          target_term = translations[target_lang]
          
          # Case-insensitive replacement
          translated.gsub!(/\b#{Regexp.escape(source_term)}\b/i) do |match|
            if match == match.upcase
              target_term.upcase
            elsif match == match.capitalize
              target_term.capitalize
            else
              target_term
            end
          end
        end
      end
      
      translated
    end

    def post_process_translation(text, source_lang, target_lang)
      # Apply language-specific post-processing
      processed = text.dup
      
      # Fix common translation issues
      case target_lang
      when 'tr'
        # Turkish-specific fixes
        processed = processed.gsub(/\s+([,.;:!?])/, '\1')
      when 'de'
        # German-specific fixes (capitalization, compound words)
        processed = capitalize_german_nouns(processed)
      when 'fr'
        # French-specific fixes (accents, spacing)
        processed = fix_french_spacing(processed)
      end
      
      processed
    end

    def capitalize_german_nouns(text)
      # Simplified German noun capitalization
      words = text.split
      words.map do |word|
        # This is a very simplified approach
        if word.length > 4 && !word.match(/^[A-Z]/) && german_noun_indicators(word)
          word.capitalize
        else
          word
        end
      end.join(' ')
    end

    def german_noun_indicators(word)
      # Simple heuristics for German nouns
      word.end_with?('ung', 'heit', 'keit', 'schaft', 'tum')
    end

    def fix_french_spacing(text)
      # Fix French punctuation spacing
      text.gsub(/\s*([;:!?])\s*/, ' \1 ')
          .gsub(/\s*«\s*/, ' « ')
          .gsub(/\s*»\s*/, ' » ')
    end

    def extract_legal_terms_for_language(text, language)
      legal_terms_db = get_legal_terms_for_language(language)
      found_terms = []
      
      text_lower = text.downcase
      legal_terms_db.each do |term, definition|
        if text_lower.include?(term.downcase)
          found_terms << {
            term: term,
            definition: definition,
            language: language
          }
        end
      end
      
      found_terms
    end

    def apply_cultural_adaptations(text, language)
      adaptations = []
      
      case language
      when 'tr'
        # Turkish legal system adaptations
        if text.include?('common law')
          adaptations << "Note: 'Common law' concept adapted for Turkish civil law system"
        end
      when 'de'
        # German legal system adaptations
        if text.include?('jury')
          adaptations << "Note: 'Jury' system adapted for German legal context"
        end
      when 'fr'
        # French legal system adaptations
        if text.include?('discovery')
          adaptations << "Note: 'Discovery' process adapted for French legal procedures"
        end
      end
      
      adaptations
    end

    def apply_language_formatting(text, language)
      formatted = text.dup
      
      case language
      when 'tr'
        # Turkish formatting (date formats, currency)
        formatted = format_turkish_dates_and_currency(formatted)
      when 'de'
        # German formatting
        formatted = format_german_dates_and_currency(formatted)
      when 'fr'
        # French formatting
        formatted = format_french_dates_and_currency(formatted)
      end
      
      formatted
    end

    def format_turkish_dates_and_currency(text)
      # Convert date formats to Turkish standard (dd.MM.yyyy)
      text.gsub(/(\d{1,2})\/(\d{1,2})\/(\d{4})/, '\1.\2.\3')
          .gsub(/\$(\d+)/, '\1 TL') # Convert $ to TL
    end

    def format_german_dates_and_currency(text)
      # Convert to German date format
      text.gsub(/(\d{1,2})\/(\d{1,2})\/(\d{4})/, '\1.\2.\3')
          .gsub(/\$(\d+)/, '\1 €') # Convert $ to €
    end

    def format_french_dates_and_currency(text)
      # Convert to French date format
      text.gsub(/(\d{1,2})\/(\d{1,2})\/(\d{4})/, '\1/\2/\3')
          .gsub(/\$(\d+)/, '\1 €') # Convert $ to €
    end

    def extract_and_process_legal_terms(text, language)
      terms = extract_legal_terms_for_language(text, language)
      
      # Add cross-references to other languages
      terms.each do |term_info|
        term_info[:translations] = {}
        
        SUPPORTED_LANGUAGES.keys.each do |lang_code|
          next if lang_code == language
          
          if LEGAL_TERM_TRANSLATIONS[term_info[:term].downcase]
            translation = LEGAL_TERM_TRANSLATIONS[term_info[:term].downcase][lang_code]
            term_info[:translations][lang_code] = translation if translation
          end
        end
      end
      
      terms
    end

    def summarize_in_language(text, language, options = {})
      # Use the main summarizer but with language-specific context
      summarizer = LegalSummariser::Summariser.new(@config)
      
      # Adjust summarization based on language and legal system
      language_options = options.merge(
        language: language,
        legal_system: SUPPORTED_LANGUAGES[language][:legal_systems].first
      )
      
      summarizer.summarise(text, language_options)
    end

    def analyze_risks_in_language(text, language, options = {})
      # Use the risk analyzer with language-specific patterns
      risk_analyzer = LegalSummariser::RiskAnalyzer.new(@config)
      
      # Apply language-specific risk patterns
      language_options = options.merge(
        language: language,
        legal_system: SUPPORTED_LANGUAGES[language][:legal_systems].first
      )
      
      risk_analyzer.analyze(text, language_options)
    end

    def generate_default_legal_terms(language)
      # Generate basic legal terms for the language
      default_terms = {}
      
      LEGAL_TERM_TRANSLATIONS.each do |english_term, translations|
        if translations[language]
          local_term = translations[language]
          default_terms[local_term] = "Legal term: #{local_term}"
        end
      end
      
      # Save to cache
      terms_dir = File.join(@config.cache_dir, 'legal_terms')
      FileUtils.mkdir_p(terms_dir) unless Dir.exist?(terms_dir)
      
      terms_file = File.join(terms_dir, SUPPORTED_LANGUAGES[language][:legal_terms_db])
      File.write(terms_file, JSON.pretty_generate(default_terms))
      
      default_terms
    end

    def find_similar_term(term, target_language)
      # Simple fuzzy matching for legal terms
      legal_terms = get_legal_terms_for_language(target_language)
      
      best_match = nil
      best_score = 0
      
      legal_terms.keys.each do |candidate|
        score = similarity_score(term.downcase, candidate.downcase)
        if score > best_score && score > 0.6
          best_score = score
          best_match = candidate
        end
      end
      
      best_match
    end

    def similarity_score(str1, str2)
      # Simple Jaccard similarity
      set1 = str1.chars.to_set
      set2 = str2.chars.to_set
      
      intersection = set1 & set2
      union = set1 | set2
      
      return 0 if union.empty?
      
      intersection.size.to_f / union.size
    end
  end
end

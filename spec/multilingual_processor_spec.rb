require 'spec_helper'

RSpec.describe LegalSummariser::MultilingualProcessor do
  let(:config) { LegalSummariser::Configuration.new }
  let(:processor) { described_class.new(config) }

  describe '#initialize' do
    it 'initializes with configuration' do
      expect(processor.config).to eq(config)
      expect(processor.logger).to eq(config.logger)
      expect(processor.current_language).to eq(config.language)
    end

    it 'validates supported language' do
      config.language = 'unsupported'
      expect { described_class.new(config) }.to raise_error(LegalSummariser::MultilingualProcessor::UnsupportedLanguageError)
    end
  end

  describe '#detect_language' do
    it 'detects English legal text' do
      english_text = "The party shall hereby agree to the terms and conditions of this contract."
      result = processor.detect_language(english_text)
      
      expect(result[:language]).to eq('en')
      expect(result[:confidence]).to be_a(Numeric)
      expect(result[:language_name]).to eq('English')
    end

    it 'detects Turkish legal text' do
      turkish_text = "Taraflar bu sözleşme maddeleri uyarınca yükümlülüklerini yerine getireceklerdir."
      result = processor.detect_language(turkish_text)
      
      expect(result[:language]).to be_a(String)
      expect(result[:confidence]).to be_a(Numeric)
    end

    it 'handles empty text' do
      result = processor.detect_language('')
      expect(result[:language]).to eq('en')
    end

    it 'handles nil text' do
      result = processor.detect_language(nil)
      expect(result[:language]).to eq('en')
    end

    it 'returns all language scores' do
      result = processor.detect_language("contract agreement")
      expect(result[:all_scores]).to be_a(Hash)
      expect(result[:all_scores].keys).to include('en', 'tr', 'de', 'fr')
    end
  end

  describe '#process_multilingual' do
    let(:english_text) { "This is a legal contract between the parties." }

    it 'processes text in single target language' do
      result = processor.process_multilingual(english_text, ['en'])
      
      expect(result[:source_language]).to be_a(String)
      expect(result[:processed_languages]).to have_key('en')
      expect(result[:metadata]).to be_a(Hash)
    end

    it 'processes text in multiple target languages' do
      result = processor.process_multilingual(english_text, ['en', 'tr', 'de'])
      
      expect(result[:processed_languages]).to have_key('en')
      expect(result[:processed_languages]).to have_key('tr')
      expect(result[:processed_languages]).to have_key('de')
    end

    it 'handles translation when source differs from target' do
      result = processor.process_multilingual(english_text, ['tr'])
      
      expect(result[:metadata][:translations_used]).to include('en -> tr')
    end

    it 'includes processing metadata' do
      result = processor.process_multilingual(english_text, ['en'])
      metadata = result[:metadata]
      
      expect(metadata[:original_length]).to eq(english_text.length)
      expect(metadata[:processing_time]).to be_a(Numeric)
      expect(metadata[:translations_used]).to be_an(Array)
    end

    it 'handles processing errors gracefully' do
      allow(processor).to receive(:process_in_language).and_raise(StandardError, "Processing failed")
      
      result = processor.process_multilingual(english_text, ['en'])
      expect(result[:processed_languages]['en'][:error]).to eq("Processing failed")
    end
  end

  describe '#translate_text' do
    let(:english_text) { "contract" }

    it 'returns same text for same language' do
      result = processor.translate_text(english_text, 'en', 'en')
      expect(result).to eq(english_text)
    end

    it 'translates legal terms between languages' do
      result = processor.translate_text('contract', 'en', 'tr')
      expect(result).to include('sözleşme')
    end

    it 'uses translation cache' do
      # First call
      result1 = processor.translate_text(english_text, 'en', 'tr')
      
      # Second call should use cache
      allow(processor).to receive(:translate_with_rules).and_return('cached_result')
      result2 = processor.translate_text(english_text, 'en', 'tr')
      
      expect(result2).to eq(result1)
    end

    it 'handles translation errors' do
      allow(processor).to receive(:translate_with_rules).and_raise(StandardError, "Translation failed")
      
      expect { processor.translate_text(english_text, 'en', 'tr') }.to raise_error(LegalSummariser::MultilingualProcessor::TranslationError)
    end
  end

  describe '#process_in_language' do
    let(:text) { "This is a legal document with contract terms." }

    it 'processes text in specified language' do
      result = processor.process_in_language(text, 'en')
      
      expect(result[:language]).to eq('en')
      expect(result[:language_name]).to eq('English')
      expect(result[:legal_system]).to include('common_law')
      expect(result[:processed_text]).to eq(text)
      expect(result[:legal_terms]).to be_an(Array)
      expect(result[:metadata]).to be_a(Hash)
    end

    it 'extracts legal terms for language' do
      result = processor.process_in_language(text, 'en')
      expect(result[:legal_terms]).to be_an(Array)
    end

    it 'applies cultural adaptations' do
      result = processor.process_in_language(text, 'tr')
      expect(result[:cultural_adaptations]).to be_an(Array)
    end

    it 'applies language formatting' do
      date_text = "The contract expires on 12/31/2023."
      result = processor.process_in_language(date_text, 'tr')
      expect(result[:formatting]).to be_a(String)
    end

    it 'includes summarization when requested' do
      result = processor.process_in_language(text, 'en', summarize: true)
      expect(result[:summary]).to be_a(Hash)
    end

    it 'includes risk analysis when requested' do
      result = processor.process_in_language(text, 'en', analyze_risks: true)
      expect(result[:risks]).to be_a(Hash)
    end
  end

  describe '#supported_languages' do
    it 'returns list of supported languages' do
      languages = processor.supported_languages
      
      expect(languages).to be_an(Array)
      expect(languages.length).to be > 0
      
      languages.each do |lang|
        expect(lang[:code]).to be_a(String)
        expect(lang[:name]).to be_a(String)
        expect(lang[:legal_systems]).to be_an(Array)
      end
    end

    it 'includes expected languages' do
      languages = processor.supported_languages
      codes = languages.map { |l| l[:code] }
      
      expect(codes).to include('en', 'tr', 'de', 'fr', 'es', 'it')
    end
  end

  describe '#language_supported?' do
    it 'returns true for supported languages' do
      expect(processor.language_supported?('en')).to be true
      expect(processor.language_supported?('tr')).to be true
      expect(processor.language_supported?('de')).to be true
    end

    it 'returns false for unsupported languages' do
      expect(processor.language_supported?('xx')).to be false
      expect(processor.language_supported?('unsupported')).to be false
    end
  end

  describe '#get_legal_terms_for_language' do
    it 'returns legal terms for supported language' do
      terms = processor.get_legal_terms_for_language('en')
      expect(terms).to be_a(Hash)
    end

    it 'returns empty hash for unsupported language' do
      terms = processor.get_legal_terms_for_language('unsupported')
      expect(terms).to eq({})
    end

    it 'generates default terms when file missing' do
      terms = processor.get_legal_terms_for_language('tr')
      expect(terms).to be_a(Hash)
    end
  end

  describe '#map_legal_terms_across_languages' do
    let(:english_terms) { ['contract', 'liability', 'agreement'] }

    it 'maps terms from English to other languages' do
      mapped = processor.map_legal_terms_across_languages(english_terms, 'en', 'tr')
      
      expect(mapped).to be_a(Hash)
      expect(mapped['contract']).to eq('sözleşme')
      expect(mapped['liability']).to eq('sorumluluk')
      expect(mapped['agreement']).to eq('anlaşma')
    end

    it 'handles unmapped terms' do
      unmapped_terms = ['unknown_term']
      mapped = processor.map_legal_terms_across_languages(unmapped_terms, 'en', 'tr')
      
      expect(mapped['unknown_term']).to eq('unknown_term')
    end
  end

  describe 'legal term translations' do
    it 'has comprehensive legal term mappings' do
      mappings = LegalSummariser::MultilingualProcessor::LEGAL_TERM_TRANSLATIONS
      
      expect(mappings).to be_a(Hash)
      expect(mappings['contract']).to be_a(Hash)
      expect(mappings['contract']['tr']).to eq('sözleşme')
      expect(mappings['liability']['de']).to eq('Haftung')
    end

    it 'covers multiple languages for each term' do
      mappings = LegalSummariser::MultilingualProcessor::LEGAL_TERM_TRANSLATIONS
      
      mappings.each do |english_term, translations|
        expect(translations).to have_key('tr')
        expect(translations).to have_key('de')
        expect(translations).to have_key('fr')
      end
    end
  end

  describe 'language-specific formatting' do
    it 'formats Turkish dates and currency' do
      text = "Payment of $1000 due on 12/31/2023"
      formatted = processor.send(:format_turkish_dates_and_currency, text)
      
      expect(formatted).to include('31.12.2023')
      expect(formatted).to include('1000 TL')
    end

    it 'formats German dates and currency' do
      text = "Payment of $1000 due on 12/31/2023"
      formatted = processor.send(:format_german_dates_and_currency, text)
      
      expect(formatted).to include('31.12.2023')
      expect(formatted).to include('1000 €')
    end

    it 'formats French dates and currency' do
      text = "Payment of $1000 due on 12/31/2023"
      formatted = processor.send(:format_french_dates_and_currency, text)
      
      expect(formatted).to include('31/12/2023')
      expect(formatted).to include('1000 €')
    end
  end

  describe 'language detection scoring' do
    it 'scores English legal text higher for English' do
      english_text = "The party shall hereby agree to the contract terms."
      
      english_score = processor.send(:calculate_language_score, english_text, 'en')
      turkish_score = processor.send(:calculate_language_score, english_text, 'tr')
      
      expect(english_score).to be > turkish_score
    end

    it 'handles empty text gracefully' do
      score = processor.send(:calculate_language_score, '', 'en')
      expect(score).to eq(0.0)
    end
  end

  describe 'AI translation integration' do
    context 'when translation API is available' do
      before do
        ENV['TRANSLATION_API_KEY'] = 'test_key'
        ENV['TRANSLATION_API_ENDPOINT'] = 'https://api.example.com/translate'
      end

      after do
        ENV.delete('TRANSLATION_API_KEY')
        ENV.delete('TRANSLATION_API_ENDPOINT')
      end

      it 'can use AI translation when available' do
        # Mock successful API response
        allow_any_instance_of(Net::HTTP).to receive(:request).and_return(
          double(code: '200', body: '{"translated_text": "sözleşme"}')
        )

        result = processor.translate_text('contract', 'en', 'tr', use_ai_translation: true)
        expect(result).to eq('sözleşme')
      end

      it 'falls back to rule-based on API failure' do
        # Mock API failure
        allow_any_instance_of(Net::HTTP).to receive(:request).and_return(
          double(code: '500', body: 'Server Error')
        )

        result = processor.translate_text('contract', 'en', 'tr', use_ai_translation: true)
        expect(result).to include('sözleşme')
      end
    end

    context 'when translation API is not available' do
      it 'uses rule-based translation' do
        result = processor.translate_text('contract', 'en', 'tr', use_ai_translation: true)
        expect(result).to include('sözleşme')
      end
    end
  end

  describe 'cultural adaptations' do
    it 'provides adaptations for Turkish legal system' do
      text = "This follows common law principles"
      adaptations = processor.send(:apply_cultural_adaptations, text, 'tr')
      
      expect(adaptations).to be_an(Array)
      expect(adaptations.first).to include('Common law')
    end

    it 'provides adaptations for German legal system' do
      text = "The jury will decide the case"
      adaptations = processor.send(:apply_cultural_adaptations, text, 'de')
      
      expect(adaptations).to be_an(Array)
      expect(adaptations.first).to include('Jury')
    end

    it 'provides adaptations for French legal system' do
      text = "Discovery process will begin"
      adaptations = processor.send(:apply_cultural_adaptations, text, 'fr')
      
      expect(adaptations).to be_an(Array)
      expect(adaptations.first).to include('Discovery')
    end
  end

  describe 'similarity scoring' do
    it 'calculates similarity between strings' do
      similarity = processor.send(:similarity_score, 'contract', 'contract')
      expect(similarity).to eq(1.0)
    end

    it 'calculates partial similarity' do
      similarity = processor.send(:similarity_score, 'contract', 'contracts')
      expect(similarity).to be > 0.5
      expect(similarity).to be < 1.0
    end

    it 'handles completely different strings' do
      similarity = processor.send(:similarity_score, 'contract', 'xyz')
      expect(similarity).to be >= 0
    end
  end

  describe 'error handling' do
    it 'handles unsupported language errors' do
      expect { processor.process_in_language("text", 'unsupported') }.to raise_error(LegalSummariser::MultilingualProcessor::UnsupportedLanguageError)
    end

    it 'handles translation errors gracefully' do
      allow(processor).to receive(:translate_with_rules).and_raise(StandardError, "Translation failed")
      
      expect { processor.translate_text("text", 'en', 'tr') }.to raise_error(LegalSummariser::MultilingualProcessor::TranslationError)
    end

    it 'handles file loading errors' do
      allow(File).to receive(:read).and_raise(StandardError, "File error")
      
      terms = processor.get_legal_terms_for_language('en')
      expect(terms).to eq({})
    end
  end

  describe 'caching behavior' do
    it 'caches translation results' do
      text = "contract"
      
      # First translation
      result1 = processor.translate_text(text, 'en', 'tr')
      
      # Mock the rule-based method to return different result
      allow(processor).to receive(:translate_with_rules).and_return('different_result')
      
      # Second translation should use cache
      result2 = processor.translate_text(text, 'en', 'tr')
      
      expect(result2).to eq(result1)
    end

    it 'can force retranslation' do
      text = "contract"
      
      # First translation
      result1 = processor.translate_text(text, 'en', 'tr')
      
      # Force retranslation
      result2 = processor.translate_text(text, 'en', 'tr', force_retranslate: true)
      
      # Results should be the same since we're using the same method
      expect(result2).to eq(result1)
    end
  end
end

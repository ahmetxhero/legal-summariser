require 'spec_helper'

RSpec.describe LegalSummariser::PlainLanguageGenerator do
  let(:config) { LegalSummariser::Configuration.new }
  let(:generator) { described_class.new(config) }

  describe '#initialize' do
    it 'initializes with default configuration' do
      expect(generator.config).to eq(config)
      expect(generator.logger).to eq(config.logger)
    end

    it 'raises error with invalid configuration' do
      expect { described_class.new(nil) }.to raise_error(LegalSummariser::PlainLanguageGenerator::ConfigurationError)
    end
  end

  describe '#generate' do
    let(:legal_text) { "The party shall heretofore be deemed liable pursuant to the aforementioned agreement." }

    it 'generates plain language version' do
      result = generator.generate(legal_text)
      
      expect(result).to be_a(Hash)
      expect(result[:original_text]).to eq(legal_text)
      expect(result[:simplified_text]).to be_a(String)
      expect(result[:processing_time]).to be_a(Numeric)
      expect(result[:readability_score]).to be_a(Numeric)
      expect(result[:complexity_reduction]).to be_a(Numeric)
    end

    it 'replaces legal jargon with plain English' do
      result = generator.generate(legal_text)
      simplified = result[:simplified_text]
      
      expect(simplified).to include('until now')  # heretofore -> until now
      expect(simplified).to include('according to')  # pursuant to -> according to
      expect(simplified).to include('mentioned above')  # aforementioned -> mentioned above
    end

    it 'handles empty text' do
      result = generator.generate('')
      expect(result[:simplified_text]).to eq('')
    end

    it 'handles nil text' do
      result = generator.generate(nil)
      expect(result[:simplified_text]).to eq('')
    end

    it 'includes metadata in result' do
      result = generator.generate(legal_text)
      metadata = result[:metadata]
      
      expect(metadata[:word_count_original]).to be_a(Integer)
      expect(metadata[:word_count_simplified]).to be_a(Integer)
      expect(metadata[:sentence_count]).to be_a(Integer)
      expect(metadata[:avg_sentence_length]).to be_a(Numeric)
    end
  end

  describe '#generate_batch' do
    let(:texts) { [
      "The party shall heretofore be liable.",
      "Whereas the agreement is hereby terminated.",
      "Notwithstanding the aforementioned clause."
    ] }

    it 'processes multiple texts' do
      results = generator.generate_batch(texts)
      
      expect(results).to be_an(Array)
      expect(results.length).to eq(3)
      
      results.each do |result|
        expect(result[:original_text]).to be_a(String)
        expect(result[:simplified_text]).to be_a(String)
      end
    end

    it 'handles empty array' do
      results = generator.generate_batch([])
      expect(results).to eq([])
    end

    it 'handles errors gracefully' do
      allow(generator).to receive(:generate).and_raise(StandardError, "Test error")
      
      results = generator.generate_batch(texts)
      
      results.each do |result|
        expect(result[:error]).to eq("Test error")
      end
    end
  end

  describe '#available_models' do
    it 'returns available models information' do
      models = generator.available_models
      
      expect(models).to be_a(Hash)
      expect(models[:local]).to include('rule_based')
      expect(models[:recommended]).to eq('rule_based')
    end
  end

  describe '#fine_tune_model' do
    let(:training_data) { [
      { 'legal' => 'heretofore', 'plain' => 'from now on' },
      { 'legal' => 'pursuant to', 'plain' => 'according to' }
    ] }

    it 'fine-tunes model with training data' do
      result = generator.fine_tune_model(training_data)
      expect(result).to be true
    end

    it 'handles invalid training data' do
      result = generator.fine_tune_model([])
      expect(result).to be false
    end
  end

  describe '#load_custom_mappings' do
    it 'loads custom mappings from cache' do
      mappings = generator.load_custom_mappings
      expect(mappings).to be_a(Hash)
    end

    it 'handles missing mappings file' do
      allow(File).to receive(:exist?).and_return(false)
      mappings = generator.load_custom_mappings
      expect(mappings).to eq({})
    end
  end

  describe 'legal jargon replacement' do
    it 'replaces common legal terms' do
      test_cases = {
        'heretofore' => 'until now',
        'whereas' => 'since',
        'pursuant to' => 'according to',
        'notwithstanding' => 'despite',
        'aforementioned' => 'mentioned above'
      }

      test_cases.each do |legal_term, plain_term|
        text = "The #{legal_term} provision applies."
        result = generator.generate(text)
        expect(result[:simplified_text]).to include(plain_term)
      end
    end

    it 'preserves case in replacements' do
      text = "HERETOFORE the party shall comply."
      result = generator.generate(text)
      expect(result[:simplified_text]).to include('UNTIL NOW')
    end
  end

  describe 'sentence pattern simplification' do
    it 'simplifies complex sentence patterns' do
      test_cases = {
        'shall be deemed to be' => 'is considered',
        'in the event that' => 'if',
        'provided that' => 'if',
        'for the purpose of' => 'to'
      }

      test_cases.each do |complex_pattern, simple_pattern|
        text = "The party #{complex_pattern} responsible."
        result = generator.generate(text)
        expect(result[:simplified_text]).to include(simple_pattern)
      end
    end
  end

  describe 'readability scoring' do
    it 'calculates readability score' do
      simple_text = "This is easy to read."
      complex_text = "The aforementioned party shall heretofore be deemed liable pursuant to the agreement."
      
      simple_result = generator.generate(simple_text)
      complex_result = generator.generate(complex_text)
      
      expect(simple_result[:readability_score]).to be > complex_result[:readability_score]
    end
  end

  describe 'complexity reduction calculation' do
    it 'calculates complexity reduction percentage' do
      complex_text = "The aforementioned party shall heretofore be deemed liable pursuant to the agreement."
      result = generator.generate(complex_text)
      
      expect(result[:complexity_reduction]).to be >= 0
      expect(result[:complexity_reduction]).to be <= 100
    end
  end

  describe 'AI model integration' do
    context 'when AI API is available' do
      before do
        ENV['LEGAL_AI_API_ENDPOINT'] = 'https://api.example.com/translate'
        ENV['LEGAL_AI_API_KEY'] = 'test_key'
      end

      after do
        ENV.delete('LEGAL_AI_API_ENDPOINT')
        ENV.delete('LEGAL_AI_API_KEY')
      end

      it 'can use AI model when requested' do
        # Mock the API response
        allow_any_instance_of(Net::HTTP).to receive(:request).and_return(
          double(code: '200', body: '{"simplified_text": "This is simplified text"}')
        )

        result = generator.generate("Complex legal text", use_ai_model: true)
        expect(result[:simplified_text]).to be_a(String)
      end
    end

    context 'when AI API is not available' do
      it 'falls back to rule-based processing' do
        result = generator.generate("The party shall heretofore comply.", use_ai_model: true)
        expect(result[:simplified_text]).to include('until now')
      end
    end
  end

  describe 'error handling' do
    it 'handles processing errors gracefully' do
      allow(generator).to receive(:process_text_pipeline).and_raise(StandardError, "Processing failed")
      
      expect { generator.generate("test text") }.to raise_error(LegalSummariser::PlainLanguageGenerator::ModelError)
    end
  end
end

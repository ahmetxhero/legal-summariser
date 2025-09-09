# frozen_string_literal: true

RSpec.describe LegalSummariser::Configuration do
  let(:config) { LegalSummariser::Configuration.new }

  describe "#initialize" do
    it "sets default values" do
      expect(config.logger).to be_nil
      expect(config.max_file_size).to eq(50 * 1024 * 1024)
      expect(config.timeout).to eq(30)
      expect(config.language).to eq('en')
      expect(config.enable_caching).to be false
      expect(config.cache_dir).to eq('/tmp/legal_summariser_cache')
    end
  end

  describe "#supported_languages" do
    it "returns array of supported languages" do
      expect(config.supported_languages).to include('en', 'tr', 'de', 'fr', 'es', 'it')
    end
  end

  describe "#validate!" do
    it "passes with valid configuration" do
      expect { config.validate! }.not_to raise_error
    end

    it "raises error for invalid language" do
      config.language = 'invalid'
      expect { config.validate! }.to raise_error(LegalSummariser::Error, /Invalid language/)
    end

    it "raises error for negative max file size" do
      config.max_file_size = -1
      expect { config.validate! }.to raise_error(LegalSummariser::Error, /Max file size must be positive/)
    end

    it "raises error for negative timeout" do
      config.timeout = -1
      expect { config.validate! }.to raise_error(LegalSummariser::Error, /Timeout must be positive/)
    end
  end
end

RSpec.describe LegalSummariser do
  describe ".configuration" do
    it "returns configuration instance" do
      expect(LegalSummariser.configuration).to be_a(LegalSummariser::Configuration)
    end
  end

  describe ".configure" do
    it "yields configuration for customization" do
      LegalSummariser.configure do |config|
        config.language = 'tr'
        config.enable_caching = true
      end

      expect(LegalSummariser.configuration.language).to eq('tr')
      expect(LegalSummariser.configuration.enable_caching).to be true
    end

    it "validates configuration after setup" do
      expect {
        LegalSummariser.configure do |config|
          config.language = 'invalid'
        end
      }.to raise_error(LegalSummariser::Error)
    end
  end

  describe ".reset_configuration!" do
    it "resets configuration to defaults" do
      LegalSummariser.configure { |c| c.language = 'tr' }
      LegalSummariser.reset_configuration!
      
      expect(LegalSummariser.configuration.language).to eq('en')
    end
  end
end

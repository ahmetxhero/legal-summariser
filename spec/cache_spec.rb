# frozen_string_literal: true

RSpec.describe LegalSummariser::Cache do
  let(:cache_dir) { "/tmp/test_legal_cache" }
  let(:cache) { LegalSummariser::Cache.new(cache_dir) }
  let(:sample_file) { "/tmp/sample.txt" }
  let(:sample_result) { { summary: "Test summary", processed_at: Time.now } }

  before do
    File.write(sample_file, "Sample content")
    FileUtils.rm_rf(cache_dir) if Dir.exist?(cache_dir)
  end

  after do
    File.delete(sample_file) if File.exist?(sample_file)
    FileUtils.rm_rf(cache_dir) if Dir.exist?(cache_dir)
  end

  describe "#cache_key" do
    it "generates consistent cache key for same file and options" do
      key1 = cache.cache_key(sample_file, { format: 'json' })
      key2 = cache.cache_key(sample_file, { format: 'json' })
      
      expect(key1).to eq(key2)
      expect(key1).to be_a(String)
      expect(key1.length).to eq(64) # SHA256 hex length
    end

    it "generates different keys for different options" do
      key1 = cache.cache_key(sample_file, { format: 'json' })
      key2 = cache.cache_key(sample_file, { format: 'markdown' })
      
      expect(key1).not_to eq(key2)
    end
  end

  describe "#get and #set" do
    context "when caching is disabled" do
      before do
        allow(LegalSummariser.configuration).to receive(:enable_caching).and_return(false)
      end

      it "returns nil for get" do
        key = cache.cache_key(sample_file)
        expect(cache.get(key)).to be_nil
      end

      it "does not store anything for set" do
        key = cache.cache_key(sample_file)
        cache.set(key, sample_result)
        expect(cache.get(key)).to be_nil
      end
    end

    context "when caching is enabled" do
      before do
        allow(LegalSummariser.configuration).to receive(:enable_caching).and_return(true)
      end

      it "stores and retrieves cached results" do
        key = cache.cache_key(sample_file)
        cache.set(key, sample_result)
        
        retrieved = cache.get(key)
        expect(retrieved).not_to be_nil
        expect(retrieved[:summary]).to eq("Test summary")
      end

      it "returns nil for non-existent cache" do
        key = "non_existent_key"
        expect(cache.get(key)).to be_nil
      end

      it "handles expired cache (older than 24 hours)" do
        key = cache.cache_key(sample_file)
        cache.set(key, sample_result)
        
        # Simulate old cache file
        cache_file = File.join(cache_dir, "#{key}.json")
        old_time = Time.now - (25 * 60 * 60) # 25 hours ago
        File.utime(old_time, old_time, cache_file)
        
        expect(cache.get(key)).to be_nil
      end
    end
  end

  describe "#clear!" do
    before do
      allow(LegalSummariser.configuration).to receive(:enable_caching).and_return(true)
    end

    it "removes all cache files" do
      key1 = cache.cache_key(sample_file, { format: 'json' })
      key2 = cache.cache_key(sample_file, { format: 'markdown' })
      
      cache.set(key1, sample_result)
      cache.set(key2, sample_result)
      
      expect(Dir.glob(File.join(cache_dir, "*.json")).length).to eq(2)
      
      cache.clear!
      
      expect(Dir.glob(File.join(cache_dir, "*.json")).length).to eq(0)
    end
  end

  describe "#stats" do
    context "when caching is disabled" do
      before do
        allow(LegalSummariser.configuration).to receive(:enable_caching).and_return(false)
      end

      it "returns disabled status" do
        stats = cache.stats
        expect(stats[:enabled]).to be false
      end
    end

    context "when caching is enabled" do
      before do
        allow(LegalSummariser.configuration).to receive(:enable_caching).and_return(true)
      end

      it "returns cache statistics" do
        key = cache.cache_key(sample_file)
        cache.set(key, sample_result)
        
        stats = cache.stats
        expect(stats[:enabled]).to be true
        expect(stats[:file_count]).to eq(1)
        expect(stats[:total_size_bytes]).to be > 0
        expect(stats[:total_size_mb]).to be >= 0
        expect(stats[:cache_dir]).to eq(cache_dir)
      end
    end
  end
end

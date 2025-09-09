# frozen_string_literal: true

RSpec.describe LegalSummariser::ClauseDetector do
  let(:sample_text) do
    <<~TEXT
      This agreement contains confidential information and establishes liability limitations.
      The company processes personal data in accordance with GDPR requirements.
      Either party may terminate this agreement with 30 days notice.
      Payment shall be made within 30 days of invoice.
      All intellectual property rights remain with the original owner.
      Any disputes shall be resolved through arbitration under the laws of England.
    TEXT
  end

  let(:detector) { LegalSummariser::ClauseDetector.new(sample_text) }

  describe "#detect" do
    it "returns a hash of detected clauses" do
      result = detector.detect
      expect(result).to be_a(Hash)
      expect(result.keys).to include(:confidentiality, :liability, :data_processing, :termination, :payment, :intellectual_property, :dispute_resolution)
    end

    it "detects confidentiality clauses" do
      result = detector.detect
      expect(result[:confidentiality]).not_to be_empty
      expect(result[:confidentiality].first[:type]).to eq("Confidentiality")
    end

    it "detects data processing clauses" do
      result = detector.detect
      expect(result[:data_processing]).not_to be_empty
      expect(result[:data_processing].first[:content]).to include("personal data")
    end

    it "detects termination clauses" do
      result = detector.detect
      expect(result[:termination]).not_to be_empty
      expect(result[:termination].first[:content]).to include("terminate")
    end

    it "detects payment clauses" do
      result = detector.detect
      expect(result[:payment]).not_to be_empty
      expect(result[:payment].first[:content]).to include("payment")
    end
  end

  describe "private methods" do
    it "extracts sentences correctly" do
      sentences = detector.send(:extract_sentences)
      expect(sentences).to be_an(Array)
      expect(sentences.length).to be > 0
      expect(sentences.first).to include("confidential information")
    end
  end
end

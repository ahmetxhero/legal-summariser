# frozen_string_literal: true

RSpec.describe LegalSummariser::RiskAnalyzer do
  let(:high_risk_text) do
    <<~TEXT
      The party shall have unlimited liability for all claims and damages.
      The company may modify this agreement at any time without notice.
      Employee agrees to indemnify against all claims, costs, and expenses.
      This agreement automatically renews for successive terms.
      Employee shall not compete with company in any market globally.
    TEXT
  end

  let(:compliance_gap_text) do
    <<~TEXT
      This agreement involves processing of personal data and customer information.
      The company collects and stores user data for business purposes.
      Data will be shared with third parties as needed.
      This agreement is governed by Turkish law and jurisdiction.
    TEXT
  end

  describe "#analyze" do
    context "with high-risk content" do
      let(:analyzer) { LegalSummariser::RiskAnalyzer.new(high_risk_text) }

      it "detects high risks" do
        result = analyzer.analyze
        expect(result[:high_risks]).not_to be_empty
        expect(result[:high_risks].any? { |r| r[:type] == "Unlimited Liability" }).to be true
      end

      it "calculates risk score" do
        result = analyzer.analyze
        expect(result[:risk_score][:level]).to eq("high")
        expect(result[:risk_score][:score]).to be > 25
      end
    end

    context "with compliance gaps" do
      let(:analyzer) { LegalSummariser::RiskAnalyzer.new(compliance_gap_text) }

      it "detects GDPR compliance gaps" do
        result = analyzer.analyze
        expect(result[:compliance_gaps]).not_to be_empty
        gdpr_gap = result[:compliance_gaps].find { |g| g[:regulation] == "GDPR" }
        expect(gdpr_gap).not_to be_nil
      end

      it "detects KVKK compliance needs" do
        result = analyzer.analyze
        kvkk_gap = result[:compliance_gaps].find { |g| g[:regulation] == "KVKK" }
        expect(kvkk_gap).not_to be_nil
      end
    end
  end

  describe "risk detection methods" do
    let(:analyzer) { LegalSummariser::RiskAnalyzer.new(high_risk_text) }

    it "detects unlimited liability" do
      high_risks = analyzer.send(:detect_high_risks)
      unlimited_liability = high_risks.find { |r| r[:type] == "Unlimited Liability" }
      expect(unlimited_liability).not_to be_nil
      expect(unlimited_liability[:severity]).to eq("high")
    end

    it "detects broad indemnification" do
      high_risks = analyzer.send(:detect_high_risks)
      broad_indemnification = high_risks.find { |r| r[:type] == "Broad Indemnification" }
      expect(broad_indemnification).not_to be_nil
    end

    it "detects unfair terms" do
      unfair_terms = analyzer.send(:detect_unfair_terms)
      expect(unfair_terms).not_to be_empty
      expect(unfair_terms.any? { |t| t[:type] == "Unilateral Modification" }).to be true
    end
  end
end

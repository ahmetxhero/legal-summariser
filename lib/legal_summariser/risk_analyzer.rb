# frozen_string_literal: true

module LegalSummariser
  class RiskAnalyzer
    attr_reader :text

    def initialize(text)
      @text = text.downcase
    end

    # Analyze document for potential legal risks
    # @return [Hash] Risk analysis results
    def analyze
      {
        high_risks: detect_high_risks,
        medium_risks: detect_medium_risks,
        compliance_gaps: detect_compliance_gaps,
        unfair_terms: detect_unfair_terms,
        risk_score: calculate_overall_risk_score
      }
    end

    private

    # Detect high-risk clauses and terms
    # @return [Array<Hash>] High-risk items
    def detect_high_risks
      risks = []

      # Unlimited liability
      if text.match?(/unlimited\s+liability|no\s+limit.*liability/i)
        risks << {
          type: "Unlimited Liability",
          description: "Agreement may expose party to unlimited financial liability",
          severity: "high",
          recommendation: "Consider adding liability caps or limitations"
        }
      end

      # Broad indemnification
      if text.match?(/indemnify.*against.*claims|hold\s+harmless.*all.*claims/i)
        risks << {
          type: "Broad Indemnification",
          description: "Very broad indemnification obligations that could be costly",
          severity: "high",
          recommendation: "Narrow the scope of indemnification obligations"
        }
      end

      # Automatic renewal without notice
      if text.match?(/automatic.*renew|automatically.*extend/i) && !text.match?(/notice.*terminat|notice.*cancel/i)
        risks << {
          type: "Automatic Renewal",
          description: "Agreement may auto-renew without adequate termination notice",
          severity: "high",
          recommendation: "Ensure adequate notice periods for termination"
        }
      end

      # Exclusive dealing
      if text.match?(/exclusive|solely|only.*party/i) && text.match?(/deal|contract|agreement/i)
        risks << {
          type: "Exclusive Dealing",
          description: "Agreement may contain exclusive dealing obligations",
          severity: "high",
          recommendation: "Review exclusivity terms carefully"
        }
      end

      risks
    end

    # Detect medium-risk issues
    # @return [Array<Hash>] Medium-risk items
    def detect_medium_risks
      risks = []

      # Vague termination clauses
      if text.match?(/terminat.*convenience|terminat.*reason/i) && !text.match?(/\d+\s+days?\s+notice/i)
        risks << {
          type: "Vague Termination",
          description: "Termination clauses lack specific notice periods",
          severity: "medium",
          recommendation: "Specify clear termination notice requirements"
        }
      end

      # Broad confidentiality
      if text.match?(/all\s+information.*confidential|any\s+information.*confidential/i)
        risks << {
          type: "Overly Broad Confidentiality",
          description: "Confidentiality obligations may be too broad",
          severity: "medium",
          recommendation: "Define confidential information more specifically"
        }
      end

      # Assignment restrictions
      if text.match?(/not.*assign|cannot.*assign|may\s+not.*assign/i)
        risks << {
          type: "Assignment Restrictions",
          description: "Agreement restricts assignment rights",
          severity: "medium",
          recommendation: "Consider if assignment restrictions are necessary"
        }
      end

      # Governing law concerns
      if text.match?(/laws?\s+of.*(?:foreign|international)/i)
        risks << {
          type: "Foreign Governing Law",
          description: "Agreement governed by foreign law",
          severity: "medium",
          recommendation: "Consider implications of foreign law governance"
        }
      end

      risks
    end

    # Detect compliance gaps (GDPR, KVKK, etc.)
    # @return [Array<Hash>] Compliance issues
    def detect_compliance_gaps
      gaps = []

      # GDPR compliance checks
      if text.match?(/personal\s+data|data\s+processing/i)
        unless text.match?(/gdpr|general\s+data\s+protection/i)
          gaps << {
            type: "Missing GDPR Reference",
            description: "Document processes personal data but lacks GDPR compliance language",
            regulation: "GDPR",
            recommendation: "Add GDPR compliance clauses"
          }
        end

        unless text.match?(/data\s+subject\s+rights|right\s+to\s+erasure|right\s+of\s+access/i)
          gaps << {
            type: "Missing Data Subject Rights",
            description: "No mention of data subject rights under GDPR",
            regulation: "GDPR",
            recommendation: "Include data subject rights provisions"
          }
        end
      end

      # KVKK compliance (Turkish data protection)
      if text.match?(/turkey|turkish|kvkk/i) && text.match?(/personal\s+data/i)
        unless text.match?(/kvkk|kişisel\s+verilerin\s+korunması/i)
          gaps << {
            type: "Missing KVKK Compliance",
            description: "Turkish context requires KVKK compliance",
            regulation: "KVKK",
            recommendation: "Add KVKK compliance provisions"
          }
        end
      end

      # Employment law compliance
      if text.match?(/employment|employee|job/i)
        unless text.match?(/equal\s+opportunity|discrimination|harassment/i)
          gaps << {
            type: "Missing Employment Protections",
            description: "Employment agreement lacks standard protection clauses",
            regulation: "Employment Law",
            recommendation: "Add anti-discrimination and harassment policies"
          }
        end
      end

      gaps
    end

    # Detect potentially unfair terms
    # @return [Array<Hash>] Unfair terms
    def detect_unfair_terms
      unfair_terms = []

      # One-sided termination rights
      if text.match?(/company.*may.*terminat/i) && !text.match?(/employee.*may.*terminat|party.*may.*terminat/i)
        unfair_terms << {
          type: "One-sided Termination",
          description: "Only one party has termination rights",
          impact: "Creates imbalanced relationship",
          recommendation: "Consider mutual termination rights"
        }
      end

      # Penalty clauses without reciprocity
      if text.match?(/penalty|fine|liquidated\s+damages/i)
        unfair_terms << {
          type: "Penalty Clauses",
          description: "Agreement contains penalty or liquidated damages clauses",
          impact: "May be unenforceable or unfair",
          recommendation: "Review enforceability of penalty clauses"
        }
      end

      # Broad non-compete
      if text.match?(/non.?compete|not.*compete/i) && !text.match?(/reasonable.*period|limited.*scope/i)
        unfair_terms << {
          type: "Broad Non-Compete",
          description: "Non-compete clause may be overly broad",
          impact: "Could restrict future employment opportunities",
          recommendation: "Ensure non-compete is reasonable in scope and duration"
        }
      end

      # Unilateral modification rights
      if text.match?(/may.*modify.*agreement|reserve.*right.*change/i) && !text.match?(/mutual.*consent|both.*parties/i)
        unfair_terms << {
          type: "Unilateral Modification",
          description: "One party can modify agreement without consent",
          impact: "Creates uncertainty and imbalance",
          recommendation: "Require mutual consent for modifications"
        }
      end

      unfair_terms
    end

    # Calculate overall risk score
    # @return [Hash] Risk score and level
    def calculate_overall_risk_score
      high_risks = detect_high_risks.length
      medium_risks = detect_medium_risks.length
      compliance_gaps = detect_compliance_gaps.length
      unfair_terms = detect_unfair_terms.length

      # Weighted scoring
      score = (high_risks * 10) + (medium_risks * 5) + (compliance_gaps * 7) + (unfair_terms * 6)

      level = case score
              when 0..10
                "low"
              when 11..25
                "medium"
              when 26..50
                "high"
              else
                "critical"
              end

      {
        score: score,
        level: level,
        total_issues: high_risks + medium_risks + compliance_gaps + unfair_terms,
        breakdown: {
          high_risks: high_risks,
          medium_risks: medium_risks,
          compliance_gaps: compliance_gaps,
          unfair_terms: unfair_terms
        }
      }
    end
  end
end

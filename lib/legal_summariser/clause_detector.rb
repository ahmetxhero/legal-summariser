# frozen_string_literal: true

module LegalSummariser
  class ClauseDetector
    attr_reader :text

    def initialize(text)
      @text = text.downcase
    end

    # Detect key legal clauses in the document
    # @return [Hash] Detected clauses with their content
    def detect
      {
        data_processing: detect_data_processing_clauses,
        liability: detect_liability_clauses,
        confidentiality: detect_confidentiality_clauses,
        termination: detect_termination_clauses,
        payment: detect_payment_clauses,
        intellectual_property: detect_ip_clauses,
        dispute_resolution: detect_dispute_resolution_clauses,
        governing_law: detect_governing_law_clauses
      }.compact
    end

    private

    # Detect data processing and privacy clauses
    # @return [Array<Hash>] Data processing clauses
    def detect_data_processing_clauses
      patterns = [
        /data\s+processing/,
        /personal\s+data/,
        /gdpr/,
        /kvkk/,
        /data\s+protection/,
        /privacy\s+policy/,
        /data\s+subject/,
        /data\s+controller/,
        /data\s+processor/
      ]

      find_clauses_by_patterns(patterns, "Data Processing")
    end

    # Detect liability and indemnification clauses
    # @return [Array<Hash>] Liability clauses
    def detect_liability_clauses
      patterns = [
        /liabilit/,
        /liable/,
        /indemnif/,
        /damages/,
        /limitation\s+of\s+liability/,
        /exclude.*liability/,
        /consequential\s+damages/,
        /indirect\s+damages/
      ]

      find_clauses_by_patterns(patterns, "Liability")
    end

    # Detect confidentiality and non-disclosure clauses
    # @return [Array<Hash>] Confidentiality clauses
    def detect_confidentiality_clauses
      patterns = [
        /confidential/,
        /non.?disclosure/,
        /proprietary\s+information/,
        /trade\s+secret/,
        /confidentiality\s+agreement/,
        /nda/
      ]

      find_clauses_by_patterns(patterns, "Confidentiality")
    end

    # Detect termination clauses
    # @return [Array<Hash>] Termination clauses
    def detect_termination_clauses
      patterns = [
        /terminat/,
        /end\s+this\s+agreement/,
        /breach.*agreement/,
        /notice\s+of\s+termination/,
        /expir/,
        /cancel/
      ]

      find_clauses_by_patterns(patterns, "Termination")
    end

    # Detect payment and fee clauses
    # @return [Array<Hash>] Payment clauses
    def detect_payment_clauses
      patterns = [
        /payment/,
        /fee/,
        /\$[\d,]+/,
        /invoice/,
        /billing/,
        /compensation/,
        /remuneration/,
        /salary/,
        /wage/
      ]

      find_clauses_by_patterns(patterns, "Payment")
    end

    # Detect intellectual property clauses
    # @return [Array<Hash>] IP clauses
    def detect_ip_clauses
      patterns = [
        /intellectual\s+property/,
        /copyright/,
        /trademark/,
        /patent/,
        /trade\s+mark/,
        /proprietary\s+rights/,
        /ownership/,
        /license/,
        /licensing/
      ]

      find_clauses_by_patterns(patterns, "Intellectual Property")
    end

    # Detect dispute resolution clauses
    # @return [Array<Hash>] Dispute resolution clauses
    def detect_dispute_resolution_clauses
      patterns = [
        /dispute/,
        /arbitration/,
        /mediation/,
        /litigation/,
        /court/,
        /jurisdiction/,
        /resolution\s+of\s+disputes/,
        /legal\s+proceedings/
      ]

      find_clauses_by_patterns(patterns, "Dispute Resolution")
    end

    # Detect governing law clauses
    # @return [Array<Hash>] Governing law clauses
    def detect_governing_law_clauses
      patterns = [
        /governing\s+law/,
        /applicable\s+law/,
        /laws?\s+of/,
        /jurisdiction/,
        /governed\s+by/,
        /subject\s+to.*law/
      ]

      find_clauses_by_patterns(patterns, "Governing Law")
    end

    # Find clauses matching given patterns
    # @param patterns [Array<Regexp>] Regex patterns to match
    # @param clause_type [String] Type of clause being detected
    # @return [Array<Hash>] Found clauses
    def find_clauses_by_patterns(patterns, clause_type)
      clauses = []
      sentences = extract_sentences

      sentences.each_with_index do |sentence, index|
        patterns.each do |pattern|
          if sentence.match?(pattern)
            clauses << {
              type: clause_type,
              content: sentence.strip,
              position: index + 1,
              keywords: extract_keywords(sentence, pattern)
            }
            break # Don't match multiple patterns for the same sentence
          end
        end
      end

      clauses.uniq { |clause| clause[:content] }
    end

    # Extract sentences from text
    # @return [Array<String>] Array of sentences
    def extract_sentences
      # Split on sentence boundaries
      sentences = text.split(/(?<=[.!?])\s+/)
      
      # Filter out very short sentences
      sentences.select { |s| s.length > 20 }
               .map { |s| s.strip.gsub(/\s+/, ' ') }
    end

    # Extract relevant keywords from a sentence based on pattern
    # @param sentence [String] The sentence
    # @param pattern [Regexp] The matching pattern
    # @return [Array<String>] Extracted keywords
    def extract_keywords(sentence, pattern)
      matches = sentence.scan(pattern).flatten
      matches.map(&:strip).reject(&:empty?)
    end
  end
end

# frozen_string_literal: true

module LegalSummariser
  class Summariser
    attr_reader :text, :options

    def initialize(text, options = {})
      @text = text
      @options = default_options.merge(options)
    end

    # Generate a summary of the legal document
    # @return [Hash] Summary with plain text and key points
    def generate
      sentences = extract_sentences
      key_sentences = identify_key_sentences(sentences)
      
      {
        plain_text: generate_plain_text_summary(key_sentences),
        key_points: extract_key_points(sentences),
        summary_ratio: calculate_summary_ratio(sentences, key_sentences)
      }
    end

    private

    def default_options
      {
        max_sentences: 5,
        min_sentence_length: 20,
        focus_keywords: %w[
          agreement contract party parties obligation liability
          termination confidentiality data protection privacy
          payment fee term condition warranty indemnity
        ]
      }
    end

    # Extract sentences from text
    # @return [Array<String>] Array of sentences
    def extract_sentences
      # Split on sentence boundaries while preserving legal formatting
      sentences = text.split(/(?<=[.!?])\s+(?=[A-Z])/)
      
      # Filter out very short sentences and clean up
      sentences.select { |s| s.length >= options[:min_sentence_length] }
               .map { |s| s.strip.gsub(/\s+/, ' ') }
    end

    # Identify the most important sentences for summary
    # @param sentences [Array<String>] All sentences
    # @return [Array<String>] Key sentences for summary
    def identify_key_sentences(sentences)
      scored_sentences = sentences.map do |sentence|
        {
          sentence: sentence,
          score: calculate_sentence_score(sentence)
        }
      end

      # Sort by score and take top sentences
      scored_sentences.sort_by { |s| -s[:score] }
                     .first(options[:max_sentences])
                     .map { |s| s[:sentence] }
    end

    # Calculate importance score for a sentence
    # @param sentence [String] The sentence to score
    # @return [Float] Importance score
    def calculate_sentence_score(sentence)
      score = 0.0
      sentence_lower = sentence.downcase

      # Keyword matching
      options[:focus_keywords].each do |keyword|
        score += 2.0 if sentence_lower.include?(keyword)
      end

      # Legal action words
      legal_actions = %w[shall must will may agree consent terminate breach]
      legal_actions.each do |action|
        score += 1.5 if sentence_lower.include?(action)
      end

      # Important legal phrases
      important_phrases = [
        'in the event', 'subject to', 'provided that', 'notwithstanding',
        'pursuant to', 'in accordance with', 'for the purpose of'
      ]
      important_phrases.each do |phrase|
        score += 1.0 if sentence_lower.include?(phrase)
      end

      # Penalty for very long sentences (likely boilerplate)
      score -= 0.5 if sentence.length > 200

      # Bonus for sentences with specific terms or dates
      score += 1.0 if sentence.match?(/\d+\s+(days?|months?|years?)/i)
      score += 0.5 if sentence.match?(/\$\d+|\d+%/i)

      score
    end

    # Generate plain English summary
    # @param key_sentences [Array<String>] Important sentences
    # @return [String] Plain text summary
    def generate_plain_text_summary(key_sentences)
      summary_parts = []

      # Identify document type and add context
      doc_type = identify_document_context(key_sentences)
      summary_parts << doc_type if doc_type

      # Process key sentences into plain English
      key_sentences.each do |sentence|
        plain_sentence = simplify_legal_language(sentence)
        summary_parts << plain_sentence if plain_sentence
      end

      summary_parts.join(' ')
    end

    # Identify document context for better summary introduction
    # @param sentences [Array<String>] Key sentences
    # @return [String, nil] Context introduction
    def identify_document_context(sentences)
      combined_text = sentences.join(' ').downcase

      case combined_text
      when /non.?disclosure|confidentiality/
        "This Non-Disclosure Agreement establishes confidentiality obligations between parties."
      when /employment|job|position/
        "This Employment Agreement outlines the terms of employment."
      when /service|provide|deliver/
        "This Service Agreement defines the terms for service delivery."
      when /privacy|data protection|gdpr|kvkv/
        "This Privacy Policy explains how personal data is handled."
      when /license|licensing|intellectual property/
        "This License Agreement grants specific usage rights."
      else
        "This legal agreement establishes terms and conditions between parties."
      end
    end

    # Simplify legal language into plain English
    # @param sentence [String] Legal sentence
    # @return [String] Simplified sentence
    def simplify_legal_language(sentence)
      simplified = sentence.dup

      # Common legal phrase replacements
      replacements = {
        /shall\s+/i => 'will ',
        /pursuant to/i => 'according to',
        /in the event that/i => 'if',
        /provided that/i => 'as long as',
        /notwithstanding/i => 'despite',
        /heretofore/i => 'before this',
        /hereafter/i => 'after this',
        /whereas/i => 'since',
        /whereby/i => 'by which',
        /aforementioned/i => 'mentioned above',
        /party of the first part/i => 'first party',
        /party of the second part/i => 'second party'
      }

      replacements.each do |pattern, replacement|
        simplified.gsub!(pattern, replacement)
      end

      # Remove excessive legal formality
      simplified.gsub!(/\b(said|such|aforesaid)\s+/i, '')
      
      simplified.strip
    end

    # Extract key points as bullet points
    # @param sentences [Array<String>] All sentences
    # @return [Array<String>] Key points
    def extract_key_points(sentences)
      points = []

      # Look for specific types of important information
      sentences.each do |sentence|
        sentence_lower = sentence.downcase

        # Duration/term information
        if sentence.match?(/\d+\s+(days?|months?|years?|weeks?)/i)
          duration = sentence.match(/\d+\s+(?:days?|months?|years?|weeks?)/i)[0]
          points << "Duration: #{duration}"
        end

        # Payment information
        if sentence.match?(/\$[\d,]+|\d+\s*(?:dollars?|pounds?|euros?)/i)
          points << "Contains payment terms"
        end

        # Termination clauses
        if sentence_lower.include?('terminat')
          points << "Includes termination provisions"
        end

        # Liability clauses
        if sentence_lower.include?('liabilit') || sentence_lower.include?('liable')
          points << "Contains liability provisions"
        end

        # Confidentiality
        if sentence_lower.include?('confidential') || sentence_lower.include?('non-disclosure')
          points << "Includes confidentiality requirements"
        end
      end

      points.uniq.first(5) # Limit to 5 key points
    end

    # Calculate summary compression ratio
    # @param original_sentences [Array<String>] Original sentences
    # @param summary_sentences [Array<String>] Summary sentences
    # @return [Float] Compression ratio
    def calculate_summary_ratio(original_sentences, summary_sentences)
      original_length = original_sentences.join(' ').length
      summary_length = summary_sentences.join(' ').length
      
      return 0.0 if original_length == 0
      
      (summary_length.to_f / original_length * 100).round(2)
    end
  end
end

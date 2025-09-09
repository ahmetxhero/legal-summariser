require 'json'
require 'fileutils'
require 'digest'

module LegalSummariser
  # Advanced model training and fine-tuning capabilities for legal text processing
  class ModelTrainer
    class TrainingError < StandardError; end
    class ValidationError < StandardError; end
    class ModelNotFoundError < StandardError; end

    attr_reader :config, :logger, :training_data_dir, :models_dir

    def initialize(config = nil)
      @config = config || LegalSummariser.configuration
      @logger = @config.logger
      @training_data_dir = File.join(@config.cache_dir, 'training_data')
      @models_dir = File.join(@config.cache_dir, 'models')
      
      setup_directories
    end

    # Train a new model with provided training data
    def train_model(training_data, model_name, options = {})
      validate_training_data(training_data)
      
      @logger&.info("Starting model training for '#{model_name}' with #{training_data.length} examples")
      
      start_time = Time.now
      model_id = generate_model_id(model_name)
      
      begin
        # Prepare training data
        prepared_data = prepare_training_data(training_data, options)
        
        # Train different model types
        model_results = {}
        
        if options[:train_pattern_model] != false
          model_results[:pattern_model] = train_pattern_model(prepared_data, model_id)
        end
        
        if options[:train_statistical_model] != false
          model_results[:statistical_model] = train_statistical_model(prepared_data, model_id)
        end
        
        if options[:train_neural_model] && options[:neural_config]
          model_results[:neural_model] = train_neural_model(prepared_data, model_id, options[:neural_config])
        end
        
        # Save model metadata
        model_metadata = {
          model_id: model_id,
          model_name: model_name,
          created_at: Time.now.iso8601,
          training_examples: training_data.length,
          model_types: model_results.keys,
          performance_metrics: calculate_training_metrics(prepared_data, model_results),
          options: options,
          version: '0.3.0'
        }
        
        save_model_metadata(model_id, model_metadata)
        
        duration = Time.now - start_time
        @logger&.info("Model training completed in #{duration.round(2)}s")
        
        {
          model_id: model_id,
          model_name: model_name,
          training_time: duration,
          models: model_results,
          metadata: model_metadata
        }
        
      rescue => e
        @logger&.error("Model training failed: #{e.message}")
        raise TrainingError, "Failed to train model '#{model_name}': #{e.message}"
      end
    end

    # Fine-tune an existing model with additional data
    def fine_tune_model(model_id, additional_data, options = {})
      model_metadata = load_model_metadata(model_id)
      raise ModelNotFoundError, "Model '#{model_id}' not found" unless model_metadata
      
      @logger&.info("Fine-tuning model '#{model_id}' with #{additional_data.length} additional examples")
      
      # Load existing training data
      existing_data = load_training_data(model_id)
      combined_data = existing_data + additional_data
      
      # Retrain with combined data
      train_model(combined_data, model_metadata['model_name'], options.merge(model_id: model_id))
    end

    # Evaluate model performance
    def evaluate_model(model_id, test_data)
      model_metadata = load_model_metadata(model_id)
      raise ModelNotFoundError, "Model '#{model_id}' not found" unless model_metadata
      
      @logger&.info("Evaluating model '#{model_id}' with #{test_data.length} test examples")
      
      results = {
        model_id: model_id,
        test_examples: test_data.length,
        accuracy_scores: {},
        performance_metrics: {}
      }
      
      # Evaluate each model type
      model_metadata['model_types'].each do |model_type|
        model_path = File.join(@models_dir, model_id, "#{model_type}.json")
        next unless File.exist?(model_path)
        
        model_data = JSON.parse(File.read(model_path))
        accuracy = evaluate_model_type(model_data, test_data, model_type)
        
        results[:accuracy_scores][model_type] = accuracy
        results[:performance_metrics][model_type] = calculate_detailed_metrics(model_data, test_data, model_type)
      end
      
      results
    end

    # List all trained models
    def list_models
      return [] unless Dir.exist?(@models_dir)
      
      models = []
      Dir.glob(File.join(@models_dir, '*')).each do |model_dir|
        next unless File.directory?(model_dir)
        
        model_id = File.basename(model_dir)
        metadata_file = File.join(model_dir, 'metadata.json')
        
        if File.exist?(metadata_file)
          metadata = JSON.parse(File.read(metadata_file))
          models << {
            model_id: model_id,
            model_name: metadata['model_name'],
            created_at: metadata['created_at'],
            training_examples: metadata['training_examples'],
            model_types: metadata['model_types']
          }
        end
      end
      
      models.sort_by { |m| m[:created_at] }.reverse
    end

    # Delete a trained model
    def delete_model(model_id)
      model_dir = File.join(@models_dir, model_id)
      
      if Dir.exist?(model_dir)
        FileUtils.rm_rf(model_dir)
        @logger&.info("Deleted model '#{model_id}'")
        true
      else
        false
      end
    end

    # Export model for deployment
    def export_model(model_id, export_path)
      model_dir = File.join(@models_dir, model_id)
      raise ModelNotFoundError, "Model '#{model_id}' not found" unless Dir.exist?(model_dir)
      
      # Create export package
      export_data = {
        model_id: model_id,
        exported_at: Time.now.iso8601,
        metadata: load_model_metadata(model_id),
        models: {}
      }
      
      # Include all model files
      Dir.glob(File.join(model_dir, '*.json')).each do |model_file|
        model_type = File.basename(model_file, '.json')
        next if model_type == 'metadata'
        
        export_data[:models][model_type] = JSON.parse(File.read(model_file))
      end
      
      File.write(export_path, JSON.pretty_generate(export_data))
      @logger&.info("Model '#{model_id}' exported to '#{export_path}'")
      
      export_data
    end

    # Import a previously exported model
    def import_model(import_path)
      raise ValidationError, "Import file not found: #{import_path}" unless File.exist?(import_path)
      
      import_data = JSON.parse(File.read(import_path))
      model_id = import_data['model_id']
      
      # Create model directory
      model_dir = File.join(@models_dir, model_id)
      FileUtils.mkdir_p(model_dir)
      
      # Save metadata
      save_model_metadata(model_id, import_data['metadata'])
      
      # Save model files
      import_data['models'].each do |model_type, model_data|
        model_file = File.join(model_dir, "#{model_type}.json")
        File.write(model_file, JSON.pretty_generate(model_data))
      end
      
      @logger&.info("Model '#{model_id}' imported successfully")
      
      {
        model_id: model_id,
        model_name: import_data['metadata']['model_name'],
        imported_at: Time.now.iso8601
      }
    end

    private

    def setup_directories
      [@training_data_dir, @models_dir].each do |dir|
        FileUtils.mkdir_p(dir) unless Dir.exist?(dir)
      end
    end

    def validate_training_data(training_data)
      raise ValidationError, "Training data must be an array" unless training_data.is_a?(Array)
      raise ValidationError, "Training data cannot be empty" if training_data.empty?
      
      training_data.each_with_index do |example, index|
        unless example.is_a?(Hash) && example['legal'] && example['plain']
          raise ValidationError, "Invalid training example at index #{index}: must have 'legal' and 'plain' keys"
        end
      end
    end

    def generate_model_id(model_name)
      timestamp = Time.now.strftime('%Y%m%d_%H%M%S')
      hash = Digest::MD5.hexdigest("#{model_name}_#{timestamp}")[0..7]
      "#{model_name.downcase.gsub(/[^a-z0-9]/, '_')}_#{timestamp}_#{hash}"
    end

    def prepare_training_data(training_data, options = {})
      prepared = training_data.map do |example|
        {
          legal: example['legal'].strip,
          plain: example['plain'].strip,
          legal_tokens: tokenize_text(example['legal']),
          plain_tokens: tokenize_text(example['plain']),
          legal_length: example['legal'].split.length,
          plain_length: example['plain'].split.length,
          complexity_score: calculate_complexity_score(example['legal'])
        }
      end
      
      # Add data augmentation if requested
      if options[:augment_data]
        prepared += generate_augmented_examples(prepared, options[:augmentation_factor] || 0.2)
      end
      
      prepared
    end

    def train_pattern_model(training_data, model_id)
      @logger&.info("Training pattern-based model")
      
      patterns = {
        word_mappings: {},
        phrase_mappings: {},
        sentence_patterns: [],
        complexity_rules: []
      }
      
      training_data.each do |example|
        # Extract word-level mappings
        legal_words = example[:legal_tokens]
        plain_words = example[:plain_tokens]
        
        # Simple alignment heuristic
        word_mappings = align_words(legal_words, plain_words)
        word_mappings.each do |legal_word, plain_word|
          patterns[:word_mappings][legal_word] ||= Hash.new(0)
          patterns[:word_mappings][legal_word][plain_word] += 1
        end
        
        # Extract phrase patterns
        phrase_mappings = extract_phrase_patterns(example[:legal], example[:plain])
        phrase_mappings.each do |legal_phrase, plain_phrase|
          patterns[:phrase_mappings][legal_phrase] ||= Hash.new(0)
          patterns[:phrase_mappings][legal_phrase][plain_phrase] += 1
        end
      end
      
      # Convert counts to probabilities
      patterns[:word_mappings].each do |legal_word, plain_words|
        total = plain_words.values.sum
        plain_words.each { |word, count| plain_words[word] = count.to_f / total }
      end
      
      patterns[:phrase_mappings].each do |legal_phrase, plain_phrases|
        total = plain_phrases.values.sum
        plain_phrases.each { |phrase, count| plain_phrases[phrase] = count.to_f / total }
      end
      
      # Save pattern model
      model_file = File.join(@models_dir, model_id, 'pattern_model.json')
      FileUtils.mkdir_p(File.dirname(model_file))
      File.write(model_file, JSON.pretty_generate(patterns))
      
      patterns
    end

    def train_statistical_model(training_data, model_id)
      @logger&.info("Training statistical model")
      
      # Build n-gram models for both legal and plain text
      legal_ngrams = build_ngram_model(training_data.map { |ex| ex[:legal_tokens] })
      plain_ngrams = build_ngram_model(training_data.map { |ex| ex[:plain_tokens] })
      
      # Build translation probabilities
      translation_probs = calculate_translation_probabilities(training_data)
      
      statistical_model = {
        legal_ngrams: legal_ngrams,
        plain_ngrams: plain_ngrams,
        translation_probabilities: translation_probs,
        vocabulary: {
          legal: extract_vocabulary(training_data.map { |ex| ex[:legal_tokens] }),
          plain: extract_vocabulary(training_data.map { |ex| ex[:plain_tokens] })
        }
      }
      
      # Save statistical model
      model_file = File.join(@models_dir, model_id, 'statistical_model.json')
      FileUtils.mkdir_p(File.dirname(model_file))
      File.write(model_file, JSON.pretty_generate(statistical_model))
      
      statistical_model
    end

    def train_neural_model(training_data, model_id, neural_config)
      @logger&.info("Training neural model (placeholder implementation)")
      
      # This is a placeholder for neural model training
      # In a real implementation, you would use frameworks like TensorFlow or PyTorch
      neural_model = {
        model_type: 'transformer',
        architecture: neural_config[:architecture] || 'encoder_decoder',
        vocab_size: neural_config[:vocab_size] || 10000,
        embedding_dim: neural_config[:embedding_dim] || 256,
        hidden_dim: neural_config[:hidden_dim] || 512,
        num_layers: neural_config[:num_layers] || 6,
        training_epochs: neural_config[:epochs] || 10,
        learning_rate: neural_config[:learning_rate] || 0.001,
        trained_on: training_data.length,
        placeholder: true # Indicates this is a placeholder implementation
      }
      
      # Save neural model placeholder
      model_file = File.join(@models_dir, model_id, 'neural_model.json')
      FileUtils.mkdir_p(File.dirname(model_file))
      File.write(model_file, JSON.pretty_generate(neural_model))
      
      neural_model
    end

    def tokenize_text(text)
      # Simple tokenization - in practice, use more sophisticated tokenizers
      text.downcase.gsub(/[^\w\s]/, ' ').split
    end

    def calculate_complexity_score(text)
      words = text.split
      avg_word_length = words.map(&:length).sum.to_f / words.length
      sentence_count = text.split(/[.!?]+/).length
      avg_sentence_length = words.length.to_f / sentence_count
      
      (avg_word_length * 2) + (avg_sentence_length * 0.5)
    end

    def align_words(legal_words, plain_words)
      # Simple word alignment using edit distance
      alignments = {}
      
      legal_words.each do |legal_word|
        best_match = nil
        best_score = Float::INFINITY
        
        plain_words.each do |plain_word|
          score = levenshtein_distance(legal_word, plain_word)
          if score < best_score && score < [legal_word.length, plain_word.length].max * 0.6
            best_score = score
            best_match = plain_word
          end
        end
        
        alignments[legal_word] = best_match if best_match
      end
      
      alignments
    end

    def levenshtein_distance(str1, str2)
      matrix = Array.new(str1.length + 1) { Array.new(str2.length + 1) }
      
      (0..str1.length).each { |i| matrix[i][0] = i }
      (0..str2.length).each { |j| matrix[0][j] = j }
      
      (1..str1.length).each do |i|
        (1..str2.length).each do |j|
          cost = str1[i-1] == str2[j-1] ? 0 : 1
          matrix[i][j] = [
            matrix[i-1][j] + 1,     # deletion
            matrix[i][j-1] + 1,     # insertion
            matrix[i-1][j-1] + cost # substitution
          ].min
        end
      end
      
      matrix[str1.length][str2.length]
    end

    def extract_phrase_patterns(legal_text, plain_text)
      # Extract common phrase patterns
      patterns = {}
      
      # Simple phrase extraction using sliding windows
      [2, 3, 4].each do |window_size|
        legal_phrases = extract_phrases(legal_text, window_size)
        plain_phrases = extract_phrases(plain_text, window_size)
        
        # Find potential mappings
        legal_phrases.each do |legal_phrase|
          plain_phrases.each do |plain_phrase|
            if phrases_similar?(legal_phrase, plain_phrase)
              patterns[legal_phrase] = plain_phrase
            end
          end
        end
      end
      
      patterns
    end

    def extract_phrases(text, window_size)
      words = text.downcase.split
      phrases = []
      
      (0..words.length - window_size).each do |i|
        phrase = words[i, window_size].join(' ')
        phrases << phrase
      end
      
      phrases
    end

    def phrases_similar?(phrase1, phrase2)
      # Simple similarity check
      words1 = phrase1.split
      words2 = phrase2.split
      
      return false if (words1.length - words2.length).abs > 1
      
      common_words = words1 & words2
      common_words.length.to_f / [words1.length, words2.length].max > 0.3
    end

    def build_ngram_model(token_sequences, n = 3)
      ngrams = Hash.new(0)
      
      token_sequences.each do |tokens|
        (0..tokens.length - n).each do |i|
          ngram = tokens[i, n].join(' ')
          ngrams[ngram] += 1
        end
      end
      
      # Convert to probabilities
      total = ngrams.values.sum
      ngrams.each { |ngram, count| ngrams[ngram] = count.to_f / total }
      
      ngrams
    end

    def calculate_translation_probabilities(training_data)
      word_pairs = Hash.new(0)
      
      training_data.each do |example|
        legal_words = example[:legal_tokens]
        plain_words = example[:plain_tokens]
        
        # Simple co-occurrence counting
        legal_words.each do |legal_word|
          plain_words.each do |plain_word|
            word_pairs["#{legal_word}|#{plain_word}"] += 1
          end
        end
      end
      
      # Normalize to probabilities
      legal_word_counts = Hash.new(0)
      word_pairs.each do |pair, count|
        legal_word = pair.split('|').first
        legal_word_counts[legal_word] += count
      end
      
      translation_probs = {}
      word_pairs.each do |pair, count|
        legal_word, plain_word = pair.split('|')
        translation_probs[pair] = count.to_f / legal_word_counts[legal_word]
      end
      
      translation_probs
    end

    def extract_vocabulary(token_sequences)
      vocab = Hash.new(0)
      
      token_sequences.each do |tokens|
        tokens.each { |token| vocab[token] += 1 }
      end
      
      vocab.sort_by { |_, count| -count }.to_h
    end

    def calculate_training_metrics(training_data, model_results)
      {
        total_examples: training_data.length,
        avg_legal_length: training_data.map { |ex| ex[:legal_length] }.sum.to_f / training_data.length,
        avg_plain_length: training_data.map { |ex| ex[:plain_length] }.sum.to_f / training_data.length,
        avg_complexity_score: training_data.map { |ex| ex[:complexity_score] }.sum.to_f / training_data.length,
        model_types_trained: model_results.keys.length,
        training_completed_at: Time.now.iso8601
      }
    end

    def save_model_metadata(model_id, metadata)
      model_dir = File.join(@models_dir, model_id)
      FileUtils.mkdir_p(model_dir)
      
      metadata_file = File.join(model_dir, 'metadata.json')
      File.write(metadata_file, JSON.pretty_generate(metadata))
    end

    def load_model_metadata(model_id)
      metadata_file = File.join(@models_dir, model_id, 'metadata.json')
      return nil unless File.exist?(metadata_file)
      
      JSON.parse(File.read(metadata_file))
    end

    def load_training_data(model_id)
      training_file = File.join(@training_data_dir, "#{model_id}.json")
      return [] unless File.exist?(training_file)
      
      JSON.parse(File.read(training_file))
    end

    def evaluate_model_type(model_data, test_data, model_type)
      correct_predictions = 0
      
      test_data.each do |example|
        predicted = predict_with_model(model_data, example['legal'], model_type)
        if similarity_score(predicted, example['plain']) > 0.7
          correct_predictions += 1
        end
      end
      
      (correct_predictions.to_f / test_data.length * 100).round(2)
    end

    def predict_with_model(model_data, legal_text, model_type)
      case model_type
      when 'pattern_model'
        predict_with_pattern_model(model_data, legal_text)
      when 'statistical_model'
        predict_with_statistical_model(model_data, legal_text)
      when 'neural_model'
        predict_with_neural_model(model_data, legal_text)
      else
        legal_text # Fallback
      end
    end

    def predict_with_pattern_model(model_data, legal_text)
      result = legal_text.dup
      
      # Apply word mappings
      model_data['word_mappings'].each do |legal_word, plain_words|
        best_plain_word = plain_words.max_by { |_, prob| prob }.first
        result.gsub!(/\b#{Regexp.escape(legal_word)}\b/i, best_plain_word)
      end
      
      # Apply phrase mappings
      model_data['phrase_mappings'].each do |legal_phrase, plain_phrases|
        best_plain_phrase = plain_phrases.max_by { |_, prob| prob }.first
        result.gsub!(legal_phrase, best_plain_phrase)
      end
      
      result
    end

    def predict_with_statistical_model(model_data, legal_text)
      # Simplified statistical prediction
      tokens = tokenize_text(legal_text)
      
      predicted_tokens = tokens.map do |token|
        # Find best translation based on translation probabilities
        best_translation = token
        best_prob = 0
        
        model_data['translation_probabilities'].each do |pair, prob|
          legal_word, plain_word = pair.split('|')
          if legal_word == token && prob > best_prob
            best_prob = prob
            best_translation = plain_word
          end
        end
        
        best_translation
      end
      
      predicted_tokens.join(' ')
    end

    def predict_with_neural_model(model_data, legal_text)
      # Placeholder for neural model prediction
      # In practice, this would use the trained neural network
      legal_text # Return original text as placeholder
    end

    def similarity_score(text1, text2)
      words1 = text1.downcase.split
      words2 = text2.downcase.split
      
      return 0 if words1.empty? && words2.empty?
      return 0 if words1.empty? || words2.empty?
      
      common_words = words1 & words2
      common_words.length.to_f / [words1.length, words2.length].max
    end

    def calculate_detailed_metrics(model_data, test_data, model_type)
      predictions = test_data.map do |example|
        predicted = predict_with_model(model_data, example['legal'], model_type)
        {
          legal: example['legal'],
          expected: example['plain'],
          predicted: predicted,
          similarity: similarity_score(predicted, example['plain'])
        }
      end
      
      similarities = predictions.map { |p| p[:similarity] }
      
      {
        accuracy: (similarities.count { |s| s > 0.7 }.to_f / similarities.length * 100).round(2),
        avg_similarity: (similarities.sum / similarities.length).round(3),
        min_similarity: similarities.min.round(3),
        max_similarity: similarities.max.round(3),
        predictions_count: predictions.length
      }
    end

    def generate_augmented_examples(training_data, factor)
      augmented = []
      num_to_generate = (training_data.length * factor).to_i
      
      num_to_generate.times do
        original = training_data.sample
        
        # Simple augmentation: synonym replacement, word order changes
        augmented_legal = augment_text(original[:legal])
        augmented_plain = augment_text(original[:plain])
        
        augmented << {
          legal: augmented_legal,
          plain: augmented_plain,
          legal_tokens: tokenize_text(augmented_legal),
          plain_tokens: tokenize_text(augmented_plain),
          legal_length: augmented_legal.split.length,
          plain_length: augmented_plain.split.length,
          complexity_score: calculate_complexity_score(augmented_legal),
          augmented: true
        }
      end
      
      augmented
    end

    def augment_text(text)
      # Simple text augmentation
      words = text.split
      
      # Randomly shuffle some adjacent words (simple augmentation)
      if words.length > 3 && rand < 0.3
        i = rand(words.length - 1)
        words[i], words[i + 1] = words[i + 1], words[i]
      end
      
      words.join(' ')
    end
  end
end

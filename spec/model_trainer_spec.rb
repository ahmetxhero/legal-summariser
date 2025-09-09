require 'spec_helper'

RSpec.describe LegalSummariser::ModelTrainer do
  let(:config) { LegalSummariser::Configuration.new }
  let(:trainer) { described_class.new(config) }
  let(:training_data) { [
    { 'legal' => 'heretofore', 'plain' => 'from now on' },
    { 'legal' => 'pursuant to', 'plain' => 'according to' },
    { 'legal' => 'whereas', 'plain' => 'since' }
  ] }

  before do
    # Clean up any existing test models
    test_models_dir = File.join(config.cache_dir, 'models')
    FileUtils.rm_rf(test_models_dir) if Dir.exist?(test_models_dir)
  end

  describe '#initialize' do
    it 'initializes with configuration' do
      expect(trainer.config).to eq(config)
      expect(trainer.logger).to eq(config.logger)
    end

    it 'creates necessary directories' do
      expect(Dir.exist?(trainer.training_data_dir)).to be true
      expect(Dir.exist?(trainer.models_dir)).to be true
    end
  end

  describe '#train_model' do
    it 'trains a new model successfully' do
      result = trainer.train_model(training_data, 'test_model')
      
      expect(result).to be_a(Hash)
      expect(result[:model_id]).to be_a(String)
      expect(result[:model_name]).to eq('test_model')
      expect(result[:training_time]).to be_a(Numeric)
      expect(result[:models]).to be_a(Hash)
      expect(result[:metadata]).to be_a(Hash)
    end

    it 'creates pattern model by default' do
      result = trainer.train_model(training_data, 'test_model')
      expect(result[:models][:pattern_model]).to be_a(Hash)
    end

    it 'creates statistical model by default' do
      result = trainer.train_model(training_data, 'test_model')
      expect(result[:models][:statistical_model]).to be_a(Hash)
    end

    it 'saves model metadata' do
      result = trainer.train_model(training_data, 'test_model')
      model_id = result[:model_id]
      
      metadata = trainer.send(:load_model_metadata, model_id)
      expect(metadata).to be_a(Hash)
      expect(metadata['model_name']).to eq('test_model')
      expect(metadata['training_examples']).to eq(3)
    end

    it 'validates training data' do
      invalid_data = [{ 'invalid' => 'data' }]
      expect { trainer.train_model(invalid_data, 'test') }.to raise_error(LegalSummariser::ModelTrainer::ValidationError)
    end

    it 'handles empty training data' do
      expect { trainer.train_model([], 'test') }.to raise_error(LegalSummariser::ModelTrainer::ValidationError)
    end
  end

  describe '#fine_tune_model' do
    let(:model_id) { trainer.train_model(training_data, 'base_model')[:model_id] }
    let(:additional_data) { [
      { 'legal' => 'notwithstanding', 'plain' => 'despite' }
    ] }

    it 'fine-tunes existing model' do
      result = trainer.fine_tune_model(model_id, additional_data)
      
      expect(result).to be_a(Hash)
      expect(result[:model_id]).to eq(model_id)
    end

    it 'raises error for non-existent model' do
      expect { trainer.fine_tune_model('non_existent', additional_data) }.to raise_error(LegalSummariser::ModelTrainer::ModelNotFoundError)
    end
  end

  describe '#evaluate_model' do
    let(:model_id) { trainer.train_model(training_data, 'eval_model')[:model_id] }
    let(:test_data) { [
      { 'legal' => 'heretofore', 'plain' => 'from now on' }
    ] }

    it 'evaluates model performance' do
      result = trainer.evaluate_model(model_id, test_data)
      
      expect(result).to be_a(Hash)
      expect(result[:model_id]).to eq(model_id)
      expect(result[:test_examples]).to eq(1)
      expect(result[:accuracy_scores]).to be_a(Hash)
      expect(result[:performance_metrics]).to be_a(Hash)
    end

    it 'raises error for non-existent model' do
      expect { trainer.evaluate_model('non_existent', test_data) }.to raise_error(LegalSummariser::ModelTrainer::ModelNotFoundError)
    end
  end

  describe '#list_models' do
    it 'returns empty list initially' do
      models = trainer.list_models
      expect(models).to be_an(Array)
      expect(models).to be_empty
    end

    it 'lists trained models' do
      trainer.train_model(training_data, 'model1')
      trainer.train_model(training_data, 'model2')
      
      models = trainer.list_models
      expect(models.length).to eq(2)
      
      models.each do |model|
        expect(model[:model_id]).to be_a(String)
        expect(model[:model_name]).to be_a(String)
        expect(model[:created_at]).to be_a(String)
      end
    end
  end

  describe '#delete_model' do
    let(:model_id) { trainer.train_model(training_data, 'delete_test')[:model_id] }

    it 'deletes existing model' do
      result = trainer.delete_model(model_id)
      expect(result).to be true
      
      models = trainer.list_models
      expect(models.find { |m| m[:model_id] == model_id }).to be_nil
    end

    it 'returns false for non-existent model' do
      result = trainer.delete_model('non_existent')
      expect(result).to be false
    end
  end

  describe '#export_model' do
    let(:model_id) { trainer.train_model(training_data, 'export_test')[:model_id] }
    let(:export_path) { File.join(Dir.tmpdir, 'exported_model.json') }

    after do
      File.delete(export_path) if File.exist?(export_path)
    end

    it 'exports model successfully' do
      result = trainer.export_model(model_id, export_path)
      
      expect(result).to be_a(Hash)
      expect(result[:model_id]).to eq(model_id)
      expect(File.exist?(export_path)).to be true
      
      exported_data = JSON.parse(File.read(export_path))
      expect(exported_data['model_id']).to eq(model_id)
      expect(exported_data['models']).to be_a(Hash)
    end

    it 'raises error for non-existent model' do
      expect { trainer.export_model('non_existent', export_path) }.to raise_error(LegalSummariser::ModelTrainer::ModelNotFoundError)
    end
  end

  describe '#import_model' do
    let(:model_id) { trainer.train_model(training_data, 'import_test')[:model_id] }
    let(:export_path) { File.join(Dir.tmpdir, 'import_test.json') }

    before do
      trainer.export_model(model_id, export_path)
      trainer.delete_model(model_id)
    end

    after do
      File.delete(export_path) if File.exist?(export_path)
    end

    it 'imports model successfully' do
      result = trainer.import_model(export_path)
      
      expect(result).to be_a(Hash)
      expect(result[:model_id]).to eq(model_id)
      
      models = trainer.list_models
      imported_model = models.find { |m| m[:model_id] == model_id }
      expect(imported_model).not_to be_nil
    end

    it 'raises error for non-existent file' do
      expect { trainer.import_model('non_existent.json') }.to raise_error(LegalSummariser::ModelTrainer::ValidationError)
    end
  end

  describe 'pattern model training' do
    it 'creates word mappings' do
      result = trainer.train_model(training_data, 'pattern_test')
      pattern_model = result[:models][:pattern_model]
      
      expect(pattern_model['word_mappings']).to be_a(Hash)
      expect(pattern_model['phrase_mappings']).to be_a(Hash)
    end

    it 'calculates mapping probabilities' do
      result = trainer.train_model(training_data, 'pattern_test')
      word_mappings = result[:models][:pattern_model]['word_mappings']
      
      word_mappings.each do |legal_word, plain_words|
        probabilities = plain_words.values
        expect(probabilities.sum).to be_within(0.01).of(1.0)
      end
    end
  end

  describe 'statistical model training' do
    it 'builds n-gram models' do
      result = trainer.train_model(training_data, 'statistical_test')
      statistical_model = result[:models][:statistical_model]
      
      expect(statistical_model['legal_ngrams']).to be_a(Hash)
      expect(statistical_model['plain_ngrams']).to be_a(Hash)
      expect(statistical_model['translation_probabilities']).to be_a(Hash)
    end

    it 'creates vocabulary' do
      result = trainer.train_model(training_data, 'statistical_test')
      vocabulary = result[:models][:statistical_model]['vocabulary']
      
      expect(vocabulary['legal']).to be_a(Hash)
      expect(vocabulary['plain']).to be_a(Hash)
    end
  end

  describe 'neural model training' do
    let(:neural_config) { {
      architecture: 'transformer',
      vocab_size: 5000,
      embedding_dim: 128,
      epochs: 5
    } }

    it 'creates neural model placeholder' do
      result = trainer.train_model(training_data, 'neural_test', train_neural_model: true, neural_config: neural_config)
      neural_model = result[:models][:neural_model]
      
      expect(neural_model['model_type']).to eq('transformer')
      expect(neural_model['architecture']).to eq('transformer')
      expect(neural_model['placeholder']).to be true
    end
  end

  describe 'data augmentation' do
    it 'augments training data when requested' do
      augmented_result = trainer.train_model(training_data, 'augmented_test', augment_data: true, augmentation_factor: 0.5)
      normal_result = trainer.train_model(training_data, 'normal_test', augment_data: false)
      
      expect(augmented_result[:metadata]['training_examples']).to be > normal_result[:metadata]['training_examples']
    end
  end

  describe 'text processing utilities' do
    it 'tokenizes text correctly' do
      text = "Hello, world! This is a test."
      tokens = trainer.send(:tokenize_text, text)
      
      expect(tokens).to be_an(Array)
      expect(tokens).to include('hello', 'world', 'this', 'is', 'a', 'test')
    end

    it 'calculates complexity score' do
      simple_text = "This is simple."
      complex_text = "The aforementioned party shall heretofore be deemed liable."
      
      simple_score = trainer.send(:calculate_complexity_score, simple_text)
      complex_score = trainer.send(:calculate_complexity_score, complex_text)
      
      expect(complex_score).to be > simple_score
    end

    it 'calculates Levenshtein distance' do
      distance = trainer.send(:levenshtein_distance, 'kitten', 'sitting')
      expect(distance).to eq(3)
    end
  end

  describe 'model prediction' do
    let(:model_id) { trainer.train_model(training_data, 'prediction_test')[:model_id] }

    it 'predicts with pattern model' do
      model_data = JSON.parse(File.read(File.join(trainer.models_dir, model_id, 'pattern_model.json')))
      prediction = trainer.send(:predict_with_pattern_model, model_data, 'heretofore the party')
      
      expect(prediction).to be_a(String)
    end

    it 'predicts with statistical model' do
      model_data = JSON.parse(File.read(File.join(trainer.models_dir, model_id, 'statistical_model.json')))
      prediction = trainer.send(:predict_with_statistical_model, model_data, 'heretofore the party')
      
      expect(prediction).to be_a(String)
    end
  end

  describe 'similarity scoring' do
    it 'calculates similarity between texts' do
      text1 = "hello world"
      text2 = "hello earth"
      text3 = "goodbye moon"
      
      similarity1 = trainer.send(:similarity_score, text1, text2)
      similarity2 = trainer.send(:similarity_score, text1, text3)
      
      expect(similarity1).to be > similarity2
    end

    it 'handles identical texts' do
      text = "identical text"
      similarity = trainer.send(:similarity_score, text, text)
      expect(similarity).to eq(1.0)
    end

    it 'handles empty texts' do
      similarity = trainer.send(:similarity_score, "", "")
      expect(similarity).to eq(0)
    end
  end

  describe 'error handling' do
    it 'handles training errors gracefully' do
      allow(trainer).to receive(:prepare_training_data).and_raise(StandardError, "Training failed")
      
      expect { trainer.train_model(training_data, 'error_test') }.to raise_error(LegalSummariser::ModelTrainer::TrainingError)
    end

    it 'validates training data format' do
      invalid_data = "not an array"
      expect { trainer.train_model(invalid_data, 'test') }.to raise_error(LegalSummariser::ModelTrainer::ValidationError)
    end
  end
end

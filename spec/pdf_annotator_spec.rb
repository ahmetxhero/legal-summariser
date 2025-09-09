require 'spec_helper'

RSpec.describe LegalSummariser::PDFAnnotator do
  let(:config) { LegalSummariser::Configuration.new }
  let(:annotator) { described_class.new(config) }
  let(:sample_pdf) { File.join(Dir.tmpdir, 'sample.pdf') }
  let(:output_pdf) { File.join(Dir.tmpdir, 'annotated.pdf') }
  let(:analysis_results) { {
    summary: { key_points: ['Key point 1', 'Key point 2'] },
    risks: { high_risks: [{ text: 'High risk clause', description: 'Potential liability' }] },
    clauses: { privacy: [{ text: 'Privacy clause text' }] }
  } }

  before do
    # Create a dummy PDF file for testing
    File.write(sample_pdf, 'PDF content', mode: 'wb')
  end

  after do
    [sample_pdf, output_pdf].each do |file|
      File.delete(file) if File.exist?(file)
    end
  end

  describe '#initialize' do
    it 'initializes with configuration' do
      expect(annotator.config).to eq(config)
      expect(annotator.logger).to eq(config.logger)
    end

    it 'creates annotations directory' do
      expect(Dir.exist?(annotator.annotations_dir)).to be true
    end
  end

  describe '#create_annotated_pdf' do
    it 'creates annotated PDF from analysis results' do
      result = annotator.create_annotated_pdf(sample_pdf, analysis_results, output_pdf)
      
      expect(result).to be_a(Hash)
      expect(result[:input_pdf]).to eq(sample_pdf)
      expect(result[:output_pdf]).to eq(output_pdf)
      expect(result[:annotations_count]).to be_a(Integer)
      expect(result[:annotation_types]).to be_a(Hash)
      expect(File.exist?(output_pdf)).to be true
    end

    it 'generates annotations from summary data' do
      result = annotator.create_annotated_pdf(sample_pdf, analysis_results, output_pdf)
      expect(result[:annotations_count]).to be > 0
    end

    it 'saves annotation metadata' do
      result = annotator.create_annotated_pdf(sample_pdf, analysis_results, output_pdf)
      metadata_file = result[:metadata_file]
      
      expect(File.exist?(metadata_file)).to be true
      
      metadata = JSON.parse(File.read(metadata_file))
      expect(metadata['annotations']).to be_an(Array)
      expect(metadata['analysis_results']).to be_a(Hash)
    end

    it 'raises error for non-existent PDF' do
      expect { annotator.create_annotated_pdf('non_existent.pdf', analysis_results, output_pdf) }.to raise_error(LegalSummariser::PDFAnnotator::PDFError)
    end

    it 'raises error for non-PDF file' do
      text_file = File.join(Dir.tmpdir, 'test.txt')
      File.write(text_file, 'content')
      
      expect { annotator.create_annotated_pdf(text_file, analysis_results, output_pdf) }.to raise_error(LegalSummariser::PDFAnnotator::PDFError)
      
      File.delete(text_file)
    end
  end

  describe '#add_custom_annotations' do
    let(:custom_annotations) { [
      { type: :highlight, text: 'Important clause', page: 1, note: 'Review this' },
      { type: :warning, text: 'Risk clause', page: 2, note: 'High risk' }
    ] }

    it 'adds custom annotations to PDF' do
      result = annotator.add_custom_annotations(sample_pdf, custom_annotations, output_pdf)
      
      expect(result[:input_pdf]).to eq(sample_pdf)
      expect(result[:output_pdf]).to eq(output_pdf)
      expect(result[:custom_annotations]).to eq(2)
      expect(File.exist?(output_pdf)).to be true
    end

    it 'validates annotation format' do
      invalid_annotations = [{ invalid: 'annotation' }]
      
      expect { annotator.add_custom_annotations(sample_pdf, invalid_annotations, output_pdf) }.to raise_error(LegalSummariser::PDFAnnotator::AnnotationError)
    end

    it 'processes annotation types correctly' do
      result = annotator.add_custom_annotations(sample_pdf, custom_annotations, output_pdf)
      expect(result[:custom_annotations]).to eq(custom_annotations.length)
    end
  end

  describe '#extract_annotations' do
    before do
      # Create annotated PDF first
      annotator.create_annotated_pdf(sample_pdf, analysis_results, output_pdf)
    end

    it 'extracts annotations from annotated PDF' do
      annotations = annotator.extract_annotations(output_pdf)
      
      expect(annotations).to be_an(Array)
      expect(annotations.length).to be > 0
    end

    it 'returns empty array for PDF without metadata' do
      annotations = annotator.extract_annotations(sample_pdf)
      expect(annotations).to eq([])
    end

    it 'raises error for non-existent PDF' do
      expect { annotator.extract_annotations('non_existent.pdf') }.to raise_error(LegalSummariser::PDFAnnotator::PDFError)
    end
  end

  describe '#generate_annotation_report' do
    let(:annotations) { [
      { type: :highlight, text: 'Text 1', page: 1, note: 'Note 1' },
      { type: :warning, text: 'Text 2', page: 2, note: 'Note 2' }
    ] }

    before do
      allow(annotator).to receive(:extract_annotations).and_return(annotations)
    end

    it 'generates JSON report' do
      report = annotator.generate_annotation_report(sample_pdf, :json)
      parsed_report = JSON.parse(report)
      
      expect(parsed_report['report_type']).to eq('annotation_report')
      expect(parsed_report['total_annotations']).to eq(2)
      expect(parsed_report['annotations']).to be_an(Array)
    end

    it 'generates Markdown report' do
      report = annotator.generate_annotation_report(sample_pdf, :markdown)
      
      expect(report).to include('# PDF Annotation Report')
      expect(report).to include('Total Annotations: 2')
      expect(report).to include('## Highlight Annotations')
    end

    it 'generates HTML report' do
      report = annotator.generate_annotation_report(sample_pdf, :html)
      
      expect(report).to include('<!DOCTYPE html>')
      expect(report).to include('<title>PDF Annotation Report</title>')
      expect(report).to include('Total Annotations: 2')
    end

    it 'raises error for unsupported format' do
      expect { annotator.generate_annotation_report(sample_pdf, :unsupported) }.to raise_error(LegalSummariser::PDFAnnotator::UnsupportedFormatError)
    end
  end

  describe '#merge_annotated_pdfs' do
    let(:pdf_paths) { [sample_pdf] }

    it 'merges multiple annotated PDFs' do
      result = annotator.merge_annotated_pdfs(pdf_paths, output_pdf)
      
      expect(result[:merged_pdf]).to eq(output_pdf)
      expect(result[:source_pdfs]).to eq(1)
      expect(result[:total_annotations]).to be_a(Integer)
      expect(File.exist?(output_pdf)).to be true
    end

    it 'handles empty PDF list' do
      result = annotator.merge_annotated_pdfs([], output_pdf)
      expect(result[:source_pdfs]).to eq(0)
    end
  end

  describe '#get_annotation_statistics' do
    let(:annotations) { [
      { type: :highlight, page: 1, risk_level: :low },
      { type: :warning, page: 1, risk_level: :high },
      { type: :note, page: 2, risk_level: :medium }
    ] }

    before do
      allow(annotator).to receive(:extract_annotations).and_return(annotations)
    end

    it 'calculates annotation statistics' do
      stats = annotator.get_annotation_statistics(sample_pdf)
      
      expect(stats[:total_annotations]).to eq(3)
      expect(stats[:by_type]).to be_a(Hash)
      expect(stats[:by_risk_level]).to be_a(Hash)
      expect(stats[:by_page]).to be_a(Hash)
      expect(stats[:coverage]).to be_a(Numeric)
      expect(stats[:summary]).to be_a(Hash)
    end

    it 'groups annotations by type' do
      stats = annotator.get_annotation_statistics(sample_pdf)
      
      expect(stats[:by_type][:highlight]).to eq(1)
      expect(stats[:by_type][:warning]).to eq(1)
      expect(stats[:by_type][:note]).to eq(1)
    end

    it 'groups annotations by risk level' do
      stats = annotator.get_annotation_statistics(sample_pdf)
      
      expect(stats[:by_risk_level][:high]).to eq(1)
      expect(stats[:by_risk_level][:medium]).to eq(1)
      expect(stats[:by_risk_level][:low]).to eq(1)
    end

    it 'calculates coverage percentage' do
      stats = annotator.get_annotation_statistics(sample_pdf)
      expect(stats[:coverage]).to be_between(0, 100)
    end
  end

  describe 'annotation types' do
    it 'defines standard annotation types' do
      types = LegalSummariser::PDFAnnotator::ANNOTATION_TYPES
      
      expect(types).to have_key(:highlight)
      expect(types).to have_key(:note)
      expect(types).to have_key(:warning)
      expect(types).to have_key(:important)
      
      types.each do |type, config|
        expect(config[:color]).to be_a(String)
        expect(config[:opacity]).to be_a(Numeric)
        expect(config[:description]).to be_a(String)
      end
    end

    it 'defines risk level colors' do
      colors = LegalSummariser::PDFAnnotator::RISK_COLORS
      
      expect(colors).to have_key(:high)
      expect(colors).to have_key(:medium)
      expect(colors).to have_key(:low)
      expect(colors).to have_key(:info)
      
      colors.each do |level, color|
        expect(color).to match(/^#[0-9A-F]{6}$/i)
      end
    end
  end

  describe 'annotation generation from analysis' do
    it 'creates summary annotations' do
      annotations = annotator.send(:create_summary_annotations, analysis_results[:summary], {})
      
      expect(annotations).to be_an(Array)
      expect(annotations.length).to eq(2)
      
      annotations.each do |annotation|
        expect(annotation[:type]).to eq(:summary)
        expect(annotation[:text]).to be_a(String)
        expect(annotation[:note]).to include('Key Point')
      end
    end

    it 'creates risk annotations' do
      annotations = annotator.send(:create_risk_annotations, analysis_results[:risks], {})
      
      expect(annotations).to be_an(Array)
      expect(annotations.length).to eq(1)
      
      annotation = annotations.first
      expect(annotation[:type]).to eq(:warning)
      expect(annotation[:risk_level]).to eq(:high)
      expect(annotation[:color]).to eq(LegalSummariser::PDFAnnotator::RISK_COLORS[:high])
    end

    it 'creates clause annotations' do
      annotations = annotator.send(:create_clause_annotations, analysis_results[:clauses], {})
      
      expect(annotations).to be_an(Array)
      expect(annotations.length).to eq(1)
      
      annotation = annotations.first
      expect(annotation[:type]).to eq(:important)
      expect(annotation[:clause_type]).to eq(:privacy)
    end
  end

  describe 'custom annotation processing' do
    let(:custom_annotations) { [
      { type: :highlight, text: 'Important', page: 1 },
      { text: 'Default type', page: 2, note: 'Custom note' }
    ] }

    it 'processes custom annotations with defaults' do
      processed = annotator.send(:process_custom_annotations, custom_annotations, {})
      
      expect(processed.length).to eq(2)
      
      first_annotation = processed.first
      expect(first_annotation[:type]).to eq(:highlight)
      expect(first_annotation[:color]).to eq(LegalSummariser::PDFAnnotator::ANNOTATION_TYPES[:highlight][:color])
      
      second_annotation = processed.last
      expect(second_annotation[:type]).to eq(:note)
      expect(second_annotation[:note]).to eq('Custom note')
    end

    it 'preserves custom colors and positions' do
      custom_with_position = [
        { type: :warning, text: 'Test', page: 1, color: '#FF0000', position: { x: 100, y: 200 } }
      ]
      
      processed = annotator.send(:process_custom_annotations, custom_with_position, {})
      annotation = processed.first
      
      expect(annotation[:color]).to eq('#FF0000')
      expect(annotation[:position]).to eq({ x: 100, y: 200 })
    end
  end

  describe 'PDF validation' do
    it 'validates PDF file exists' do
      expect { annotator.send(:validate_pdf_path, 'non_existent.pdf') }.to raise_error(LegalSummariser::PDFAnnotator::PDFError, /not found/)
    end

    it 'validates PDF file extension' do
      text_file = File.join(Dir.tmpdir, 'test.txt')
      File.write(text_file, 'content')
      
      expect { annotator.send(:validate_pdf_path, text_file) }.to raise_error(LegalSummariser::PDFAnnotator::PDFError, /Invalid PDF/)
      
      File.delete(text_file)
    end
  end

  describe 'annotation validation' do
    it 'validates annotation array format' do
      expect { annotator.send(:validate_annotations, 'not_array') }.to raise_error(LegalSummariser::PDFAnnotator::AnnotationError, /must be an array/)
    end

    it 'validates required annotation keys' do
      invalid_annotation = [{ invalid: 'keys' }]
      expect { annotator.send(:validate_annotations, invalid_annotation) }.to raise_error(LegalSummariser::PDFAnnotator::AnnotationError, /missing keys/)
    end

    it 'validates annotation hash format' do
      invalid_annotation = ['not_a_hash']
      expect { annotator.send(:validate_annotations, invalid_annotation) }.to raise_error(LegalSummariser::PDFAnnotator::AnnotationError, /must be a hash/)
    end
  end

  describe 'metadata management' do
    it 'generates correct metadata path' do
      pdf_path = '/path/to/document.pdf'
      metadata_path = annotator.send(:get_metadata_path, pdf_path)
      
      expect(metadata_path).to include('document_annotations.json')
      expect(metadata_path).to include(annotator.annotations_dir)
    end

    it 'saves and loads annotation metadata' do
      annotations = [{ type: :note, text: 'Test', page: 1 }]
      analysis = { test: 'data' }
      
      annotator.send(:save_annotation_metadata, output_pdf, annotations, analysis)
      
      metadata_path = annotator.send(:get_metadata_path, output_pdf)
      expect(File.exist?(metadata_path)).to be true
      
      metadata = JSON.parse(File.read(metadata_path))
      expect(metadata['annotations']).to eq(annotations)
      expect(metadata['analysis_results']).to eq(analysis.stringify_keys)
    end
  end

  describe 'annotation coverage calculation' do
    it 'calculates coverage for annotations across pages' do
      annotations = [
        { page: 1 }, { page: 1 }, { page: 2 }, { page: 4 }
      ]
      
      coverage = annotator.send(:calculate_annotation_coverage, annotations)
      expect(coverage).to eq(75.0) # 3 pages out of 4 have annotations
    end

    it 'handles empty annotations' do
      coverage = annotator.send(:calculate_annotation_coverage, [])
      expect(coverage).to eq(0)
    end
  end

  describe 'annotation summary generation' do
    let(:test_annotations) { [
      { type: :warning, page: 1, risk_level: :high },
      { type: :warning, page: 1, risk_level: :medium },
      { type: :note, page: 2 },
      { type: :highlight, page: 3 }
    ] }

    it 'generates comprehensive annotation summary' do
      summary = annotator.send(:generate_annotation_summary, test_annotations)
      
      expect(summary[:most_annotated_page]).to eq(1)
      expect(summary[:most_common_type]).to eq(:warning)
      expect(summary[:risk_distribution][:high]).to eq(1)
      expect(summary[:risk_distribution][:medium]).to eq(1)
      expect(summary[:recommendations]).to be_an(Array)
    end

    it 'generates appropriate recommendations' do
      high_risk_annotations = Array.new(3) { { type: :warning, risk_level: :high, page: 1 } }
      summary = annotator.send(:generate_annotation_summary, high_risk_annotations)
      
      expect(summary[:recommendations]).to include('High-risk items require immediate attention')
    end

    it 'recommends legal review for multiple warnings' do
      warning_annotations = Array.new(6) { { type: :warning, page: 1 } }
      summary = annotator.send(:generate_annotation_summary, warning_annotations)
      
      expect(summary[:recommendations]).to include('Multiple warnings detected - consider legal review')
    end
  end

  describe 'error handling' do
    it 'handles annotation creation errors' do
      allow(annotator).to receive(:extract_text_positions).and_raise(StandardError, "Extraction failed")
      
      expect { annotator.create_annotated_pdf(sample_pdf, analysis_results, output_pdf) }.to raise_error(LegalSummariser::PDFAnnotator::AnnotationError)
    end

    it 'handles PDF processing errors gracefully' do
      allow(File).to receive(:write).and_raise(StandardError, "Write failed")
      
      expect { annotator.create_annotated_pdf(sample_pdf, analysis_results, output_pdf) }.to raise_error(LegalSummariser::PDFAnnotator::AnnotationError)
    end
  end
end

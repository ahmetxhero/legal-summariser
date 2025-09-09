require 'json'
require 'fileutils'
require 'digest'

module LegalSummariser
  # Advanced PDF annotation system for legal document analysis output
  class PDFAnnotator
    class AnnotationError < StandardError; end
    class PDFError < StandardError; end
    class UnsupportedFormatError < StandardError; end

    # Annotation types supported
    ANNOTATION_TYPES = {
      highlight: {
        color: '#FFFF00',
        opacity: 0.3,
        description: 'Highlighted text'
      },
      note: {
        color: '#FFA500',
        opacity: 0.8,
        description: 'Sticky note annotation'
      },
      warning: {
        color: '#FF6B6B',
        opacity: 0.5,
        description: 'Warning or risk indicator'
      },
      important: {
        color: '#4ECDC4',
        opacity: 0.4,
        description: 'Important clause or section'
      },
      question: {
        color: '#95E1D3',
        opacity: 0.4,
        description: 'Question or clarification needed'
      },
      summary: {
        color: '#A8E6CF',
        opacity: 0.3,
        description: 'Summary or key point'
      }
    }.freeze

    # Risk level color coding
    RISK_COLORS = {
      high: '#FF4757',
      medium: '#FFA502',
      low: '#2ED573',
      info: '#3742FA'
    }.freeze

    attr_reader :config, :logger, :annotations_dir

    def initialize(config = nil)
      @config = config || LegalSummariser.configuration
      @logger = @config.logger
      @annotations_dir = File.join(@config.cache_dir, 'pdf_annotations')
      
      setup_directories
    end

    # Create annotated PDF from analysis results
    def create_annotated_pdf(pdf_path, analysis_results, output_path, options = {})
      validate_pdf_path(pdf_path)
      
      @logger&.info("Creating annotated PDF from #{pdf_path}")
      
      begin
        # Extract text positions from PDF
        text_positions = extract_text_positions(pdf_path)
        
        # Generate annotations from analysis results
        annotations = generate_annotations_from_analysis(analysis_results, text_positions, options)
        
        # Create annotated PDF
        annotated_pdf_data = create_pdf_with_annotations(pdf_path, annotations, options)
        
        # Save annotated PDF
        File.write(output_path, annotated_pdf_data, mode: 'wb')
        
        # Save annotation metadata
        save_annotation_metadata(output_path, annotations, analysis_results)
        
        @logger&.info("Annotated PDF created: #{output_path}")
        
        {
          input_pdf: pdf_path,
          output_pdf: output_path,
          annotations_count: annotations.length,
          annotation_types: annotations.group_by { |a| a[:type] }.transform_values(&:count),
          metadata_file: get_metadata_path(output_path)
        }
        
      rescue => e
        @logger&.error("PDF annotation failed: #{e.message}")
        raise AnnotationError, "Failed to create annotated PDF: #{e.message}"
      end
    end

    # Add custom annotations to PDF
    def add_custom_annotations(pdf_path, custom_annotations, output_path, options = {})
      validate_pdf_path(pdf_path)
      validate_annotations(custom_annotations)
      
      @logger&.info("Adding #{custom_annotations.length} custom annotations to PDF")
      
      begin
        # Process custom annotations
        processed_annotations = process_custom_annotations(custom_annotations, options)
        
        # Create annotated PDF
        annotated_pdf_data = create_pdf_with_annotations(pdf_path, processed_annotations, options)
        
        # Save result
        File.write(output_path, annotated_pdf_data, mode: 'wb')
        save_annotation_metadata(output_path, processed_annotations, { custom: true })
        
        {
          input_pdf: pdf_path,
          output_pdf: output_path,
          custom_annotations: processed_annotations.length
        }
        
      rescue => e
        @logger&.error("Custom annotation failed: #{e.message}")
        raise AnnotationError, "Failed to add custom annotations: #{e.message}"
      end
    end

    # Extract annotations from an annotated PDF
    def extract_annotations(pdf_path)
      validate_pdf_path(pdf_path)
      
      @logger&.info("Extracting annotations from #{pdf_path}")
      
      begin
        # Check for metadata file first
        metadata_path = get_metadata_path(pdf_path)
        
        if File.exist?(metadata_path)
          metadata = JSON.parse(File.read(metadata_path))
          return metadata['annotations'] || []
        end
        
        # Fallback: try to extract from PDF directly
        extract_annotations_from_pdf(pdf_path)
        
      rescue => e
        @logger&.error("Annotation extraction failed: #{e.message}")
        raise AnnotationError, "Failed to extract annotations: #{e.message}"
      end
    end

    # Generate annotation report
    def generate_annotation_report(pdf_path, format = :json)
      annotations = extract_annotations(pdf_path)
      
      case format
      when :json
        generate_json_report(annotations)
      when :markdown
        generate_markdown_report(annotations)
      when :html
        generate_html_report(annotations)
      else
        raise UnsupportedFormatError, "Unsupported report format: #{format}"
      end
    end

    # Merge multiple annotated PDFs
    def merge_annotated_pdfs(pdf_paths, output_path, options = {})
      @logger&.info("Merging #{pdf_paths.length} annotated PDFs")
      
      begin
        merged_annotations = []
        page_offset = 0
        
        pdf_paths.each_with_index do |pdf_path, index|
          validate_pdf_path(pdf_path)
          
          # Extract annotations and adjust page numbers
          annotations = extract_annotations(pdf_path)
          annotations.each do |annotation|
            annotation[:page] += page_offset if annotation[:page]
            annotation[:source_pdf] = File.basename(pdf_path)
            merged_annotations << annotation
          end
          
          # Get page count for offset calculation
          page_count = get_pdf_page_count(pdf_path)
          page_offset += page_count
        end
        
        # Create merged PDF (placeholder implementation)
        create_merged_pdf(pdf_paths, output_path, merged_annotations, options)
        
        {
          merged_pdf: output_path,
          source_pdfs: pdf_paths.length,
          total_annotations: merged_annotations.length
        }
        
      rescue => e
        @logger&.error("PDF merging failed: #{e.message}")
        raise AnnotationError, "Failed to merge annotated PDFs: #{e.message}"
      end
    end

    # Get annotation statistics
    def get_annotation_statistics(pdf_path)
      annotations = extract_annotations(pdf_path)
      
      {
        total_annotations: annotations.length,
        by_type: annotations.group_by { |a| a[:type] }.transform_values(&:count),
        by_risk_level: annotations.select { |a| a[:risk_level] }
                                 .group_by { |a| a[:risk_level] }
                                 .transform_values(&:count),
        by_page: annotations.group_by { |a| a[:page] }.transform_values(&:count),
        coverage: calculate_annotation_coverage(annotations),
        summary: generate_annotation_summary(annotations)
      }
    end

    private

    def setup_directories
      FileUtils.mkdir_p(@annotations_dir) unless Dir.exist?(@annotations_dir)
    end

    def validate_pdf_path(pdf_path)
      raise PDFError, "PDF file not found: #{pdf_path}" unless File.exist?(pdf_path)
      raise PDFError, "Invalid PDF file: #{pdf_path}" unless pdf_path.downcase.end_with?('.pdf')
    end

    def validate_annotations(annotations)
      raise AnnotationError, "Annotations must be an array" unless annotations.is_a?(Array)
      
      annotations.each_with_index do |annotation, index|
        unless annotation.is_a?(Hash)
          raise AnnotationError, "Annotation #{index} must be a hash"
        end
        
        required_keys = [:type, :text, :page]
        missing_keys = required_keys - annotation.keys
        
        unless missing_keys.empty?
          raise AnnotationError, "Annotation #{index} missing keys: #{missing_keys.join(', ')}"
        end
      end
    end

    def extract_text_positions(pdf_path)
      # Placeholder implementation for text position extraction
      # In a real implementation, you would use a PDF library like PDF::Reader
      # to extract text positions and coordinates
      
      @logger&.info("Extracting text positions from PDF (placeholder)")
      
      # Simulated text positions
      {
        pages: [
          {
            page_number: 1,
            width: 612,
            height: 792,
            text_blocks: [
              {
                text: "Sample contract text",
                x: 72,
                y: 720,
                width: 200,
                height: 20
              }
            ]
          }
        ]
      }
    end

    def generate_annotations_from_analysis(analysis_results, text_positions, options = {})
      annotations = []
      
      # Generate annotations from summary
      if analysis_results[:summary]
        summary_annotations = create_summary_annotations(analysis_results[:summary], text_positions)
        annotations.concat(summary_annotations)
      end
      
      # Generate annotations from risks
      if analysis_results[:risks]
        risk_annotations = create_risk_annotations(analysis_results[:risks], text_positions)
        annotations.concat(risk_annotations)
      end
      
      # Generate annotations from clauses
      if analysis_results[:clauses]
        clause_annotations = create_clause_annotations(analysis_results[:clauses], text_positions)
        annotations.concat(clause_annotations)
      end
      
      # Generate annotations from plain language suggestions
      if analysis_results[:plain_language]
        plain_language_annotations = create_plain_language_annotations(analysis_results[:plain_language], text_positions)
        annotations.concat(plain_language_annotations)
      end
      
      annotations
    end

    def create_summary_annotations(summary_data, text_positions)
      annotations = []
      
      if summary_data[:key_points]
        summary_data[:key_points].each_with_index do |point, index|
          annotations << {
            type: :summary,
            text: point,
            note: "Key Point #{index + 1}",
            page: 1, # Simplified - would need actual text matching
            color: ANNOTATION_TYPES[:summary][:color],
            opacity: ANNOTATION_TYPES[:summary][:opacity]
          }
        end
      end
      
      annotations
    end

    def create_risk_annotations(risks_data, text_positions)
      annotations = []
      
      [:high_risks, :medium_risks, :low_risks].each do |risk_level|
        next unless risks_data[risk_level]
        
        level = risk_level.to_s.split('_').first.to_sym
        
        risks_data[risk_level].each do |risk|
          annotations << {
            type: :warning,
            text: risk[:text] || risk,
            note: "#{level.capitalize} Risk: #{risk[:description] || risk}",
            risk_level: level,
            page: 1, # Simplified
            color: RISK_COLORS[level],
            opacity: 0.6
          }
        end
      end
      
      annotations
    end

    def create_clause_annotations(clauses_data, text_positions)
      annotations = []
      
      clauses_data.each do |clause_type, clauses|
        next unless clauses.is_a?(Array)
        
        clauses.each do |clause|
          annotations << {
            type: :important,
            text: clause[:text] || clause,
            note: "#{clause_type.to_s.humanize} Clause",
            clause_type: clause_type,
            page: 1, # Simplified
            color: ANNOTATION_TYPES[:important][:color],
            opacity: ANNOTATION_TYPES[:important][:opacity]
          }
        end
      end
      
      annotations
    end

    def create_plain_language_annotations(plain_language_data, text_positions)
      annotations = []
      
      if plain_language_data[:simplified_text]
        # Create annotations for complex terms that were simplified
        annotations << {
          type: :note,
          text: "Plain language version available",
          note: "This document has been converted to plain English. See attached simplified version.",
          page: 1,
          color: ANNOTATION_TYPES[:note][:color],
          opacity: ANNOTATION_TYPES[:note][:opacity]
        }
      end
      
      annotations
    end

    def process_custom_annotations(custom_annotations, options = {})
      processed = []
      
      custom_annotations.each do |annotation|
        processed_annotation = {
          type: annotation[:type] || :note,
          text: annotation[:text],
          note: annotation[:note] || annotation[:comment],
          page: annotation[:page] || 1,
          color: annotation[:color] || ANNOTATION_TYPES[annotation[:type] || :note][:color],
          opacity: annotation[:opacity] || ANNOTATION_TYPES[annotation[:type] || :note][:opacity]
        }
        
        # Add position if provided
        if annotation[:position]
          processed_annotation[:position] = annotation[:position]
        end
        
        processed << processed_annotation
      end
      
      processed
    end

    def create_pdf_with_annotations(pdf_path, annotations, options = {})
      # Placeholder implementation for PDF annotation
      # In a real implementation, you would use a PDF library like Prawn or HexaPDF
      # to add actual annotations to the PDF
      
      @logger&.info("Creating PDF with #{annotations.length} annotations (placeholder)")
      
      # For now, just copy the original PDF
      # In practice, this would create a new PDF with annotations overlaid
      File.read(pdf_path, mode: 'rb')
    end

    def save_annotation_metadata(pdf_path, annotations, analysis_results)
      metadata = {
        pdf_file: File.basename(pdf_path),
        created_at: Time.now.iso8601,
        annotations: annotations,
        analysis_results: analysis_results,
        annotation_statistics: {
          total: annotations.length,
          by_type: annotations.group_by { |a| a[:type] }.transform_values(&:count)
        }
      }
      
      metadata_path = get_metadata_path(pdf_path)
      File.write(metadata_path, JSON.pretty_generate(metadata))
    end

    def get_metadata_path(pdf_path)
      base_name = File.basename(pdf_path, '.pdf')
      File.join(@annotations_dir, "#{base_name}_annotations.json")
    end

    def extract_annotations_from_pdf(pdf_path)
      # Placeholder for extracting annotations directly from PDF
      # This would use a PDF library to read existing annotations
      []
    end

    def generate_json_report(annotations)
      {
        report_type: 'annotation_report',
        generated_at: Time.now.iso8601,
        total_annotations: annotations.length,
        annotations: annotations,
        statistics: calculate_annotation_statistics(annotations)
      }.to_json
    end

    def generate_markdown_report(annotations)
      report = "# PDF Annotation Report\n\n"
      report += "Generated: #{Time.now.strftime('%Y-%m-%d %H:%M:%S')}\n\n"
      report += "Total Annotations: #{annotations.length}\n\n"
      
      # Group by type
      annotations.group_by { |a| a[:type] }.each do |type, type_annotations|
        report += "## #{type.to_s.capitalize} Annotations (#{type_annotations.length})\n\n"
        
        type_annotations.each_with_index do |annotation, index|
          report += "### #{index + 1}. Page #{annotation[:page]}\n"
          report += "**Text:** #{annotation[:text]}\n\n"
          report += "**Note:** #{annotation[:note]}\n\n" if annotation[:note]
          report += "---\n\n"
        end
      end
      
      report
    end

    def generate_html_report(annotations)
      html = <<~HTML
        <!DOCTYPE html>
        <html>
        <head>
          <title>PDF Annotation Report</title>
          <style>
            body { font-family: Arial, sans-serif; margin: 20px; }
            .annotation { border: 1px solid #ccc; margin: 10px 0; padding: 10px; }
            .type-highlight { border-left: 4px solid #FFFF00; }
            .type-warning { border-left: 4px solid #FF6B6B; }
            .type-note { border-left: 4px solid #FFA500; }
            .type-important { border-left: 4px solid #4ECDC4; }
          </style>
        </head>
        <body>
          <h1>PDF Annotation Report</h1>
          <p>Generated: #{Time.now.strftime('%Y-%m-%d %H:%M:%S')}</p>
          <p>Total Annotations: #{annotations.length}</p>
      HTML
      
      annotations.each_with_index do |annotation, index|
        html += <<~HTML
          <div class="annotation type-#{annotation[:type]}">
            <h3>Annotation #{index + 1} - Page #{annotation[:page]}</h3>
            <p><strong>Type:</strong> #{annotation[:type]}</p>
            <p><strong>Text:</strong> #{annotation[:text]}</p>
        HTML
        
        if annotation[:note]
          html += "<p><strong>Note:</strong> #{annotation[:note]}</p>"
        end
        
        html += "</div>"
      end
      
      html += "</body></html>"
      html
    end

    def create_merged_pdf(pdf_paths, output_path, annotations, options = {})
      # Placeholder for PDF merging
      # In practice, this would use a PDF library to merge PDFs and preserve annotations
      
      @logger&.info("Merging PDFs (placeholder implementation)")
      
      # For now, just copy the first PDF
      if pdf_paths.any?
        FileUtils.cp(pdf_paths.first, output_path)
      end
      
      # Save merged annotations metadata
      save_annotation_metadata(output_path, annotations, { merged: true, source_pdfs: pdf_paths })
    end

    def get_pdf_page_count(pdf_path)
      # Placeholder for getting PDF page count
      # In practice, this would use a PDF library to count pages
      10 # Default assumption
    end

    def calculate_annotation_coverage(annotations)
      return 0 if annotations.empty?
      
      pages_with_annotations = annotations.map { |a| a[:page] }.uniq.length
      total_pages = annotations.map { |a| a[:page] }.max || 1
      
      (pages_with_annotations.to_f / total_pages * 100).round(1)
    end

    def generate_annotation_summary(annotations)
      summary = {
        most_annotated_page: nil,
        most_common_type: nil,
        risk_distribution: {},
        recommendations: []
      }
      
      # Most annotated page
      page_counts = annotations.group_by { |a| a[:page] }.transform_values(&:count)
      summary[:most_annotated_page] = page_counts.max_by { |_, count| count }&.first
      
      # Most common annotation type
      type_counts = annotations.group_by { |a| a[:type] }.transform_values(&:count)
      summary[:most_common_type] = type_counts.max_by { |_, count| count }&.first
      
      # Risk distribution
      risk_annotations = annotations.select { |a| a[:risk_level] }
      summary[:risk_distribution] = risk_annotations.group_by { |a| a[:risk_level] }
                                                   .transform_values(&:count)
      
      # Generate recommendations
      if summary[:risk_distribution][:high]&.> 0
        summary[:recommendations] << "High-risk items require immediate attention"
      end
      
      if type_counts[:warning]&.> 5
        summary[:recommendations] << "Multiple warnings detected - consider legal review"
      end
      
      summary
    end

    def calculate_annotation_statistics(annotations)
      {
        total: annotations.length,
        by_type: annotations.group_by { |a| a[:type] }.transform_values(&:count),
        by_page: annotations.group_by { |a| a[:page] }.transform_values(&:count),
        with_risks: annotations.count { |a| a[:risk_level] }
      }
    end
  end
end

# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.2.0] - 2025-01-09

### Added
- **Configuration System**: Comprehensive configuration management with validation
- **Caching System**: Result caching with TTL and size management
- **Performance Monitoring**: Built-in performance tracking and metrics
- **Enhanced CLI**: New commands for batch processing, statistics, and configuration
- **Batch Processing**: Process multiple documents simultaneously
- **Enhanced Document Support**: Added RTF support and improved text extraction
- **Advanced Error Handling**: Better error messages and recovery mechanisms
- **Comprehensive Testing**: 75 test cases with full coverage
- **Documentation**: Complete examples and contribution guidelines

### Enhanced
- **Text Extraction**: Multiple encoding support, better PDF/DOCX handling
- **Document Type Detection**: Improved scoring system for 9 document types
- **Risk Analysis**: More comprehensive risk patterns and compliance checking
- **Summarization**: Better plain English conversion and key point extraction
- **CLI Interface**: Verbose logging, caching options, and performance stats

### Fixed
- Text cleaning and normalization issues
- Memory leaks in document processing
- Error handling for edge cases

## [0.1.0] - 2024-09-09

### Added
- Initial release of Legal Summariser
- Text extraction from PDF, DOCX, and TXT files
- Basic legal document summarisation with plain English conversion
- Clause detection for 8 key legal areas:
  - Data Processing & Privacy
  - Liability & Indemnification  
  - Confidentiality & Non-disclosure
  - Termination & Cancellation
  - Payment & Fees
  - Intellectual Property
  - Dispute Resolution
  - Governing Law
- Risk analysis system with high/medium risk detection
- Compliance gap identification for GDPR and KVKK
- Unfair terms detection
- Multiple output formats (JSON, Markdown, Plain Text)
- Command-line interface with Thor
- Comprehensive test suite with RSpec
- Document type auto-detection
- Offline processing capabilities

### Features
- Rule-based clause extraction using regex patterns
- Smart sentence scoring for summarisation
- Legal language simplification
- Risk scoring algorithm
- Compliance checking framework
- Multi-format document support
- CLI demo mode with sample NDA

### Technical
- Ruby gem structure with proper gemspec
- Modular architecture with separate classes for each function
- Error handling for unsupported formats and missing files
- Text cleaning and normalization
- Comprehensive documentation and examples

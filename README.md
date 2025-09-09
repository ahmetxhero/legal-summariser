# Legal Summariser 📋⚖️

> A Ruby-based AI-powered toolkit for legal document analysis that summarises contracts, extracts key clauses, flags risks, and translates legal jargon into plain English while preserving legal accuracy.

**Created by [Ahmet KAHRAMAN](https://ahmetxhero.web.app)** 👨‍💻

[![Ruby](https://img.shields.io/badge/Ruby-2.6+-red.svg)](https://ruby-lang.org)
[![License](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Tests](https://img.shields.io/badge/Tests-26%20passing-green.svg)](#testing)

---

## 👋 About the Author

**Ahmet KAHRAMAN** - Mobile Developer & Cyber Security Expert

- 🌐 **Portfolio**: [ahmetxhero.web.app](https://ahmetxhero.web.app)
- 🎥 **YouTube**: [@ahmetxhero](https://youtube.com/@ahmetxhero)
- 💼 **LinkedIn**: [linkedin.com/in/ahmetxhero](https://linkedin.com/in/ahmetxhero)
- 🐤 **Twitter**: [@ahmetxhero](https://x.com/ahmetxhero)
- 📧 **Email**: ahmetxhero@gmail.com
- 🏠 **Location**: Ankara, Turkey 🇹🇷

*"Security first, innovation always"* - Building secure, innovative solutions for a better digital future 🚀

---

## Features

- **Document Processing**: Supports PDF, DOCX, and plain text files
- **Smart Summarisation**: Converts legal documents into concise plain English
- **Clause Detection**: Automatically identifies key legal clauses including:
  - Data Processing & Privacy (GDPR/KVKK compliance)
  - Liability & Indemnification
  - Confidentiality & Non-disclosure
  - Termination & Cancellation
  - Payment & Fees
  - Intellectual Property
  - Dispute Resolution
  - Governing Law
- **Risk Analysis**: Flags potential legal risks and unfair terms
- **Compliance Checking**: Identifies gaps in GDPR, KVKK, and other regulations
- **Multiple Output Formats**: JSON, Markdown, and plain text
- **CLI Interface**: Command-line tool for batch processing
- **Offline Processing**: Works without internet for sensitive documents

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'legal_summariser'
```

And then execute:

```bash
bundle install
```

Or install it yourself as:

```bash
gem install legal_summariser
```

## Usage

### Ruby API

```ruby
require "legal_summariser"

# Basic usage
summary = LegalSummariser.summarise("contracts/nda.pdf")
puts summary[:plain_text]
# => "This Non-Disclosure Agreement establishes confidentiality, valid for 2 years. The company may terminate at any time..."

# With options
result = LegalSummariser.summarise("contract.pdf", {
  format: 'markdown',
  max_sentences: 3
})

# Access different parts of the analysis
puts result[:key_points]        # Key contract points
puts result[:clauses]           # Detected legal clauses
puts result[:risks]             # Risk analysis
puts result[:metadata]          # Document metadata
```

### Command Line Interface

```bash
# Analyze a document
legal_summariser analyze contract.pdf

# Specify output format
legal_summariser analyze contract.pdf --format markdown

# Save to file
legal_summariser analyze contract.pdf --output summary.md --format markdown

# Run demo
legal_summariser demo

# Show supported formats
legal_summariser supported_formats

# Show version
legal_summariser version
```

## Example Output

### Plain Text Summary
```
This Non-Disclosure Agreement establishes confidentiality obligations between parties. 
The agreement will remain valid for 2 years from the date of signing. Either party may 
terminate with 30 days written notice. The receiving party will be liable for any 
breach of confidentiality obligations.
```

### Risk Analysis
```
High Risks Found:
- Unlimited Liability: Agreement may expose party to unlimited financial liability
- Broad Indemnification: Very broad indemnification obligations that could be costly

Compliance Gaps:
- Missing GDPR Reference: Document processes personal data but lacks GDPR compliance language
- Missing Data Subject Rights: No mention of data subject rights under GDPR
```

### Detected Clauses
- **Confidentiality**: 3 clauses found
- **Liability**: 2 clauses found  
- **Termination**: 1 clause found
- **Data Processing**: 2 clauses found

## Supported Document Types

The system automatically detects and optimizes analysis for:

- **Non-Disclosure Agreements (NDAs)**
- **Service Agreements**
- **Employment Contracts**
- **Privacy Policies**
- **License Agreements**
- **General Contracts**

## Supported File Formats

### Input Formats
- PDF (.pdf)
- Microsoft Word (.docx)
- Plain Text (.txt)

### Output Formats
- JSON (structured data)
- Markdown (formatted report)
- Plain Text (simple summary)

## Target Users

- **Law firms & compliance teams**: Faster contract reviews
- **Startups & SMEs**: Understanding investor or supplier contracts
- **Forensics experts**: Extracting critical legal clauses for reports
- **Academics & NGOs**: Analysing legal policies and regulations

## Technical Architecture

### Hybrid Approach
- **Rule-based extractors**: For structured clause detection
- **NLP processing**: For summarisation and risk detection
- **Pattern matching**: For compliance gap identification

### Key Components
- **TextExtractor**: Multi-format document parsing
- **Summariser**: Plain English conversion engine
- **ClauseDetector**: Legal clause identification
- **RiskAnalyzer**: Risk assessment and flagging
- **Formatter**: Multi-format output generation

## Development

After checking out the repo, run `bundle install` to install dependencies. Then, run `rake spec` to run the tests.

```bash
# Install dependencies
bundle install

# Run tests
bundle exec rspec

# Run linter
bundle exec rubocop

# Build gem
gem build legal_summariser.gemspec

# Install local gem
gem install ./legal_summariser-*.gem
```

## Roadmap

- **v0.1** ✅ Text extraction + basic summarisation
- **v0.2** ✅ Clause detection + risk flagging  
- **v0.3** 🔄 Plain language generator (fine-tuned models)
- **v1.0** 📋 Multi-language support + PDF annotation output

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/legal-summariser/legal_summariser.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Disclaimer

This tool is designed to assist with legal document analysis but should not replace professional legal advice. Always consult with qualified legal professionals for important legal matters.

## 🌍 Global Impact

- **Innovation**: Bridges AI with law and compliance in a developer-friendly way
- **Contribution**: Open-source library for legal NLP in Ruby
- **Public benefit**: Helps both professionals and citizens better understand their rights and obligations
- **Global relevance**: Applicable across jurisdictions (GDPR, KVKK, HIPAA, CCPA)

## 🛠️ Tech Stack

This project leverages my expertise in:

- **Ruby Development**: Gem architecture, modular design patterns
- **AI & NLP**: Rule-based text analysis, pattern recognition
- **Cybersecurity**: Compliance frameworks (GDPR, KVKK), risk assessment
- **Digital Forensics**: Legal document analysis, evidence extraction
- **Software Engineering**: Test-driven development, CLI tools

## 🎓 Professional Background

As a **Mobile Developer & Cyber Security Expert** with 10+ years in Public Sector IT:

- 🎓 **Master's in Forensic Informatics** - Gazi University (2021-2023)
- 🏢 **Mobile Developer** - Gendarmerie General Command (2024-Present)
- 🔒 **Certified Ethical Hacker (CEH)**
- 📱 **iOS & Android Development Expert**

## 🤝 Connect & Collaborate

| Platform | Link | Purpose |
|----------|------|---------|
| 🌐 **Portfolio** | [ahmetxhero.web.app](https://ahmetxhero.web.app) | Professional showcase |
| 🎥 **YouTube** | [@ahmetxhero](https://youtube.com/@ahmetxhero) | Tech tutorials & content |
| 💼 **LinkedIn** | [ahmetxhero](https://linkedin.com/in/ahmetxhero) | Professional network |
| 🐤 **Twitter** | [@ahmetxhero](https://x.com/ahmetxhero) | Tech updates & thoughts |
| 📝 **Medium** | [ahmetxhero.medium.com](https://ahmetxhero.medium.com) | Technical articles |
| 📷 **Instagram** | [@ahmetxhero](https://instagram.com/ahmetxhero) | Behind the scenes |

## ☕ Support My Work

If this project helps you or your organization, consider:

- ⭐ **Star this repository** on GitHub
- 🔄 **Share it** with your network
- ☕ **Buy me a coffee** to support open source development
- 🗣️ **Invite me to speak** at your tech event about legal tech innovation

## 🎯 Current Focus

- 🔒 **Cybersecurity**: Developing secure applications with privacy-first approach
- 📱 **Mobile Development**: Creating innovative iOS and Android solutions
- 🔍 **Digital Forensics**: Advancing forensic investigation techniques
- 📚 **Knowledge Sharing**: Contributing to the tech community through open source
- ⚖️ **Legal Tech**: Building tools that make legal processes more accessible

---

*Building secure, innovative solutions for a better digital future* 🚀

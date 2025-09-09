# Contributing to Legal Summariser

Thank you for your interest in contributing to Legal Summariser! This document provides guidelines for contributing to the project.

## 🚀 Getting Started

### Prerequisites

- Ruby 2.6 or higher
- Bundler gem
- Git

### Development Setup

1. Fork the repository
2. Clone your fork:
   ```bash
   git clone https://github.com/your-username/legal_summariser.git
   cd legal_summariser
   ```

3. Install dependencies:
   ```bash
   bundle install
   ```

4. Run tests to ensure everything works:
   ```bash
   bundle exec rspec
   ```

## 🧪 Testing

We maintain comprehensive test coverage. Please ensure all tests pass before submitting a PR:

```bash
# Run all tests
bundle exec rspec

# Run tests with coverage
bundle exec rspec --format documentation

# Run specific test file
bundle exec rspec spec/text_extractor_spec.rb

# Run linter
bundle exec rubocop
```

### Writing Tests

- Write tests for all new functionality
- Follow existing test patterns and naming conventions
- Use descriptive test names that explain the expected behavior
- Include both positive and negative test cases
- Test edge cases and error conditions

## 📝 Code Style

We follow Ruby community standards:

- Use 2 spaces for indentation
- Keep lines under 120 characters
- Use descriptive variable and method names
- Add comments for complex logic
- Follow RuboCop guidelines

Run the linter before submitting:
```bash
bundle exec rubocop
```

## 🔧 Development Guidelines

### Architecture

The gem follows a modular architecture:

- `TextExtractor`: Document parsing and text extraction
- `Summariser`: Text summarization and key point extraction
- `ClauseDetector`: Legal clause identification
- `RiskAnalyzer`: Risk assessment and compliance checking
- `Formatter`: Output formatting (JSON, Markdown, Text)
- `Cache`: Result caching system
- `PerformanceMonitor`: Performance tracking
- `Configuration`: Gem configuration management

### Adding New Features

1. **Create an issue** describing the feature
2. **Write tests** for the new functionality
3. **Implement the feature** following existing patterns
4. **Update documentation** including README and code comments
5. **Add examples** if applicable
6. **Ensure all tests pass**

### Adding New Document Types

To add support for a new document type:

1. Add detection patterns in `detect_document_type` method
2. Update supported formats documentation
3. Add test cases for the new format
4. Update CLI help text if needed

### Adding New Risk Patterns

To add new risk detection patterns:

1. Add patterns to `RiskAnalyzer` class
2. Include severity levels and recommendations
3. Add corresponding test cases
4. Update documentation

## 📚 Documentation

- Update README.md for user-facing changes
- Add inline documentation for new methods
- Include examples for new features
- Update CHANGELOG.md following semantic versioning

## 🐛 Bug Reports

When reporting bugs, please include:

- Ruby version
- Gem version
- Operating system
- Steps to reproduce
- Expected vs actual behavior
- Sample files (if applicable and not confidential)

## 💡 Feature Requests

Feature requests should include:

- Clear description of the feature
- Use case and motivation
- Proposed implementation approach
- Potential impact on existing functionality

## 🔄 Pull Request Process

1. **Create a feature branch** from `main`:
   ```bash
   git checkout -b feature/your-feature-name
   ```

2. **Make your changes** following the guidelines above

3. **Commit with descriptive messages**:
   ```bash
   git commit -m "Add support for new document format"
   ```

4. **Push to your fork**:
   ```bash
   git push origin feature/your-feature-name
   ```

5. **Create a Pull Request** with:
   - Clear title and description
   - Reference to related issues
   - List of changes made
   - Test results

### PR Requirements

- [ ] All tests pass
- [ ] Code follows style guidelines
- [ ] Documentation is updated
- [ ] CHANGELOG.md is updated
- [ ] No breaking changes (or clearly documented)

## 🏷️ Release Process

Releases follow semantic versioning:

- **MAJOR**: Breaking changes
- **MINOR**: New features (backward compatible)
- **PATCH**: Bug fixes (backward compatible)

## 🤝 Code of Conduct

- Be respectful and inclusive
- Focus on constructive feedback
- Help others learn and grow
- Maintain professionalism

## 📞 Getting Help

- Create an issue for bugs or feature requests
- Join discussions in existing issues
- Contact maintainers for questions

## 🎯 Areas for Contribution

We welcome contributions in these areas:

### High Priority
- Additional document format support (ODT, RTF, HTML)
- Enhanced clause detection patterns
- Multi-language support improvements
- Performance optimizations

### Medium Priority
- Additional risk assessment rules
- Better error handling and recovery
- Enhanced caching strategies
- CLI improvements

### Documentation
- More usage examples
- Video tutorials
- API documentation improvements
- Translation to other languages

## 🙏 Recognition

Contributors will be:
- Listed in the README.md
- Mentioned in release notes
- Given credit in commit messages

## 📄 License

By contributing, you agree that your contributions will be licensed under the MIT License.

---

Thank you for contributing to Legal Summariser! Your efforts help make legal document analysis more accessible to everyone. 🚀

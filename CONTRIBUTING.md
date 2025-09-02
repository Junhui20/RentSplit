# Contributing to RentSplit Malaysia 🤝

Thank you for your interest in contributing to RentSplit Malaysia! This document provides guidelines for contributing to the project.

## 🎯 Project Focus

RentSplit Malaysia is focused on **fair electricity bill distribution** for Malaysian rental properties with TNB 2024 compliance. We welcome contributions that align with this core mission.

## 🚀 How to Contribute

### 1. Reporting Issues
- **Bug Reports**: Use GitHub Issues with the "bug" label
- **Feature Requests**: Use GitHub Issues with the "enhancement" label
- **Documentation**: Use GitHub Issues with the "documentation" label

### 2. Code Contributions
1. **Fork** the repository
2. **Create** a feature branch (`git checkout -b feature/amazing-feature`)
3. **Make** your changes
4. **Test** your changes thoroughly
5. **Commit** your changes (`git commit -m 'Add amazing feature'`)
6. **Push** to the branch (`git push origin feature/amazing-feature`)
7. **Open** a Pull Request

## 📋 Development Guidelines

### Code Style
- Follow [Dart Style Guide](https://dart.dev/guides/language/effective-dart/style)
- Use `flutter analyze` to check for issues
- Maintain consistent formatting with `dart format`

### Testing
- Add unit tests for new services and models
- Add widget tests for new UI components
- Ensure all tests pass before submitting PR

### Documentation
- Update relevant documentation for new features
- Add code comments for complex logic
- Update CHANGELOG.md for significant changes

## 🎯 Priority Areas for Contribution

### High Priority
1. **UI/UX Improvements**
   - Mobile-responsive design enhancements
   - User experience optimization
   - Accessibility improvements

2. **Testing**
   - Unit tests for calculation services
   - Widget tests for screens
   - Integration tests for workflows

3. **Documentation**
   - User guides and tutorials
   - Code documentation
   - Translation to Bahasa Malaysia

### Medium Priority
1. **Performance Optimization**
   - Database query optimization
   - UI rendering improvements
   - Memory usage optimization

2. **Error Handling**
   - Better error messages
   - Graceful failure handling
   - Input validation improvements

### Future Features (v2.0+)
1. **Payment Integration**
   - FPX integration
   - Touch 'n Go eWallet support
   - Payment tracking

2. **Advanced Features**
   - Cloud synchronization
   - Advanced analytics
   - Multi-language support

## 🛠️ Development Setup

### Prerequisites
- Flutter SDK 3.32.0+
- Dart SDK 3.5.0+
- Android Studio or VS Code
- Git

### Setup Steps
```bash
# Clone your fork
git clone https://github.com/yourusername/RentSplit.git
cd RentSplit

# Add upstream remote
git remote add upstream https://github.com/originalowner/RentSplit.git

# Install dependencies
flutter pub get

# Run tests
flutter test

# Run the app
flutter run
```

## 📝 Pull Request Guidelines

### Before Submitting
- [ ] Code follows Dart style guidelines
- [ ] All tests pass (`flutter test`)
- [ ] No analyzer issues (`flutter analyze`)
- [ ] Documentation updated if needed
- [ ] CHANGELOG.md updated for significant changes

### PR Description Template
```markdown
## Description
Brief description of changes

## Type of Change
- [ ] Bug fix
- [ ] New feature
- [ ] Documentation update
- [ ] Performance improvement
- [ ] Other (please describe)

## Testing
- [ ] Unit tests added/updated
- [ ] Widget tests added/updated
- [ ] Manual testing completed

## Screenshots (if applicable)
Add screenshots for UI changes

## Checklist
- [ ] Code follows style guidelines
- [ ] Self-review completed
- [ ] Tests pass
- [ ] Documentation updated
```

## 🎯 Specific Contribution Areas

### TNB Calculation Engine
- Verify calculation accuracy
- Add support for new TNB rate changes
- Improve calculation performance

### User Interface
- Mobile-first design improvements
- Accessibility enhancements
- User experience optimization

### Documentation
- User guides and tutorials
- API documentation
- Code comments and examples

### Testing
- Unit tests for services
- Widget tests for UI components
- Integration tests for user flows

## 🌟 Recognition

Contributors will be recognized in:
- README.md contributors section
- CHANGELOG.md for significant contributions
- GitHub contributors page

## 📞 Getting Help

### Questions?
- **GitHub Discussions**: For general questions
- **GitHub Issues**: For specific problems
- **Documentation**: Check [docs/](docs/) folder first

### Code Review Process
1. Automated checks (analyzer, tests)
2. Manual code review by maintainers
3. Feedback and iteration
4. Approval and merge

## 🎯 Malaysian Context

### Understanding the Market
- TNB billing structure knowledge helpful
- Malaysian rental market familiarity valuable
- Local testing and feedback appreciated

### Language Considerations
- Primary language: English
- Future: Bahasa Malaysia support
- Clear, simple language preferred

## 🚫 What We Don't Accept

- Changes that break TNB calculation accuracy
- Features outside core electricity billing focus
- Code without proper testing
- Breaking changes without discussion
- Contributions that don't follow guidelines

## 📄 License

By contributing, you agree that your contributions will be licensed under the MIT License.

## 🙏 Thank You

Every contribution helps make RentSplit Malaysia better for the Malaysian rental community. Whether it's code, documentation, testing, or feedback - all contributions are valued!

---

**Questions?** Feel free to open an issue or start a discussion. We're here to help! 🚀

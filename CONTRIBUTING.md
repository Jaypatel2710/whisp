# Contributing to Whisp

Thank you for your interest in contributing to Whisp! This document provides guidelines and information for contributors.

## Table of Contents

- [Code of Conduct](#code-of-conduct)
- [Getting Started](#getting-started)
- [Development Setup](#development-setup)
- [Project Structure](#project-structure)
- [Coding Standards](#coding-standards)
- [Security Guidelines](#security-guidelines)
- [Pull Request Process](#pull-request-process)
- [Issue Reporting](#issue-reporting)

## Code of Conduct

This project follows a code of conduct that ensures a welcoming environment for all contributors. Please be respectful, inclusive, and constructive in all interactions.

## Getting Started

### Prerequisites

- Node.js 18+ and npm
- Git
- For mobile development: Android Studio (Android) or Xcode (iOS)
- For WebRTC development: Modern browser with WebRTC support

### Development Setup

1. **Fork and clone the repository**

   ```bash
   git clone https://github.com/your-username/whisp.git
   cd whisp
   ```

2. **Install dependencies**

   ```bash
   # Root dependencies
   npm install
   
   # Server dependencies
   cd server && npm install
   
   # Client dependencies (if applicable)
   cd ../clients/expo && npm install
   ```

3. **Set up environment variables**

   ```bash
   # Copy example environment file
   cp .env.example .env
   
   # Edit with your configuration
   nano .env
   ```

4. **Start development servers**

   ```bash
   # Terminal 1: Start the server
   cd server && npm run dev
   
   # Terminal 2: Start the client (if applicable)
   cd clients/expo && npm start
   ```

## Project Structure

```text
whisp/
├── server/                 # Node.js signaling server
│   ├── server.js          # Main server file
│   ├── db.js              # Database utilities
│   └── package.json       # Server dependencies
├── clients/               # Client applications
│   ├── expo/              # React Native/Expo client
│   ├── android/           # Native Android client
│   └── ios/               # Native iOS client
├── docs/                  # Documentation
├── tests/                 # Test files
└── README.md
```

## Coding Standards

### General Guidelines

- **Privacy First**: Never log or store message content, user data, or sensitive information
- **Memory Safety**: Use secure memory practices, especially for cryptographic operations
- **Ephemeral Design**: All data should be designed to be temporary and easily wiped
- **Clear Documentation**: Comment complex cryptographic and security-related code

### JavaScript/TypeScript

- Use ES6+ features
- Follow the existing code style (check `.prettierrc`)
- Use meaningful variable names, especially for cryptographic operations
- Always handle errors gracefully
- Use `const` and `let` instead of `var`

```javascript
// Good
const sessionKey = generateSessionKey();
const encryptedMessage = await encrypt(message, sessionKey);

// Bad
var key = makeKey();
var msg = encrypt(message, key);
```

### Security-Critical Code

- **Never log sensitive data**: No private keys, session keys, or message content
- **Use secure random generators**: `crypto.randomBytes()` for cryptographic randomness
- **Zero memory after use**: Explicitly clear sensitive data from memory
- **Validate all inputs**: Sanitize and validate all user inputs

```javascript
// Good - secure memory handling
function processSensitiveData(data) {
  try {
    const result = processData(data);
    return result;
  } finally {
    // Zero out sensitive data
    data.fill(0);
  }
}

// Bad - sensitive data remains in memory
function processSensitiveData(data) {
  return processData(data); // data not cleared
}
```

### Database Operations

- **Minimal storage**: Only store what's absolutely necessary
- **No message content**: Never store actual messages
- **Ephemeral data**: Use TTL for temporary data
- **Encrypted tokens**: Store push tokens encrypted

## Security Guidelines

### Cryptographic Operations

- Use established libraries (libsodium, Web Crypto API)
- Never implement custom cryptographic algorithms
- Always use authenticated encryption
- Rotate keys regularly
- Store keys in secure hardware when available

### Memory Management

- Clear sensitive data immediately after use
- Use secure memory allocation where possible
- Implement panic wipe functionality
- Avoid memory leaks in long-running processes

### Network Security

- Use TLS for all communications
- Implement certificate pinning
- Validate all incoming data
- Rate limit all endpoints
- Use secure WebRTC configuration

## Pull Request Process

### Before Submitting

1. **Check existing issues**: Look for similar issues or PRs
2. **Create an issue**: For significant changes, discuss first
3. **Fork and branch**: Create a feature branch from `main`
4. **Write tests**: Add tests for new functionality
5. **Update documentation**: Update relevant docs

### PR Guidelines

1. **Clear title**: Use descriptive, concise titles
2. **Detailed description**: Explain what, why, and how
3. **Security review**: Mark security-related changes
4. **Test coverage**: Ensure adequate test coverage
5. **Documentation**: Update docs for user-facing changes

### PR Template

```markdown
## Description
Brief description of changes

## Type of Change
- [ ] Bug fix
- [ ] New feature
- [ ] Security improvement
- [ ] Documentation update
- [ ] Refactoring

## Security Considerations
- [ ] No sensitive data logged
- [ ] Memory properly cleared
- [ ] Input validation added
- [ ] Cryptographic operations secure

## Testing
- [ ] Unit tests added/updated
- [ ] Integration tests pass
- [ ] Manual testing completed

## Checklist
- [ ] Code follows project style
- [ ] Self-review completed
- [ ] Documentation updated
- [ ] No breaking changes (or documented)
```

## Issue Reporting

### Bug Reports

When reporting bugs, please include:

- **Environment**: OS, Node.js version, browser (if applicable)
- **Steps to reproduce**: Clear, numbered steps
- **Expected behavior**: What should happen
- **Actual behavior**: What actually happens
- **Screenshots**: If applicable
- **Logs**: Relevant error messages (sanitized)

### Security Issues

For security vulnerabilities:

- **DO NOT** create public issues
- Email security concerns to: [security@whisp.app](mailto:security@whisp.app)
- Include detailed reproduction steps
- Allow reasonable time for response

### Feature Requests

When requesting features:

- Check existing issues first
- Provide clear use case
- Explain the privacy/security implications
- Consider the ephemeral nature of the app

## Development Workflow

### Branch Naming

- `feature/description` - New features
- `fix/description` - Bug fixes
- `security/description` - Security improvements
- `docs/description` - Documentation updates

### Commit Messages

Use conventional commits:

```text
feat: add screenshot protection for Android
fix: resolve memory leak in session cleanup
security: implement secure key rotation
docs: update API documentation
```

### Testing

- **Unit tests**: Test individual functions
- **Integration tests**: Test component interactions
- **Security tests**: Test cryptographic operations
- **Memory tests**: Verify data is properly cleared

## Code Review Process

### For Contributors

- Address all review comments
- Be responsive to feedback
- Ask questions if unclear
- Test changes thoroughly

### For Reviewers

- Focus on security and privacy
- Check for memory leaks
- Verify no sensitive data logging
- Ensure code follows standards
- Be constructive and helpful

## Release Process

1. **Version bump**: Update version numbers
2. **Changelog**: Update CHANGELOG.md
3. **Security review**: Final security check
4. **Testing**: Comprehensive testing
5. **Release notes**: Document changes

## Getting Help

- **Documentation**: Check existing docs first
- **Issues**: Search existing issues
- **Discussions**: Use GitHub Discussions for questions
- **Security**: Email [security@whisp.app](mailto:security@whisp.app) for security issues

## License

By contributing to Whisp, you agree that your contributions will be licensed under the same license as the project.

---

Thank you for contributing to Whisp! Your efforts help make secure, ephemeral messaging accessible to everyone.

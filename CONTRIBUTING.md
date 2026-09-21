# Contributing to Infinity Engine Metal Mod

Thank you for contributing to the **Infinity Engine Apple Metal Rendering Backend Mod**!

---

## Code of Conduct

All participants must adhere to our [Code of Conduct](CODE_OF_CONDUCT.md). Please report violations to **xuanlian@mac.com**.

---

## Development Setup

### Prerequisites
- macOS 14.0+
- Apple Clang (Xcode 15.0+ or Command Line Tools)
- Make

### Building the Project
```bash
make clean
make
```

---

## Contribution Guidelines

1. **Target `main`**: Always submit PRs against `main`.
2. **Code Style**:
   - Modern C++17 and Objective-C++ standards.
   - Write optimized Metal Shading Language (MSL) shaders avoiding divergence and excessive register pressure.
3. **Commit Messages**: Use Conventional Commits (`feat: ...`, `fix: ...`, `perf: ...`).

---

## License

Contributions are licensed under the [Mozilla Public License Version 2.0](LICENSE).

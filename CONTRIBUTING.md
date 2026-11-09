# Contributing

Thanks for your interest in cobol-bank. Issues and pull requests are welcome.

## Setup

```
sudo apt install gnucobol python3   # tested with GnuCOBOL 3.1.2
make all
make test                           # must print "TOUS LES TESTS PASSENT" for every suite
```

## Guidelines

- GnuCOBOL **free format**; one module per file in `src/`, record layouts in `copybooks/`.
- Every behavior change comes with a test (`tests/test_*.cob` for modules, `tests/test_*.sh` for the console, the demo and the web API).
- Every module returns a documented two-digit status code; add new codes to the README table.
- Never write to `data/` from a test: tests use environment variables (`CLIENTS_FILE`, `COMPTES_FILE`, …) pointing to temporary files.
- Web server: strict validation of every parameter before it reaches COBOL; never log a PIN.
- Commit messages follow [Conventional Commits](https://www.conventionalcommits.org/) (`feat:`, `fix:`, `docs:`, `test:`).

## Reporting a security issue

This is an educational project (see the warning in the README), but if you find a way to bypass authentication or the role checks of the web API, please open an issue.

# cx
codex multi-accounting zsh wrapper! it's designed to be simple and reuse codex's features instead of reimplementing them.

## install

```zsh
curl -fsSL https://raw.githubusercontent.com/pepsipu/cx/main/cx.zsh -o ~/.codex/cx.zsh
echo 'source ~/.codex/cx.zsh' >> ~/.zshrc
```

## commands

- `cx [codex_arg ...]` - run codex with an auto-picked account.
- `cx @account [codex_arg ...]` - run codex with an account, creating it if it doesn't exist.
- `cx list` - list account quotas and refresh times.
- `cx refresh` - refresh auth tokens for all accounts.

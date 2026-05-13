# cx
codex multi-accounting zsh wrapper!

## install

```zsh
curl -fsSL https://raw.githubusercontent.com/pepsipu/cx/main/cx.zsh -o ~/.codex/cx.zsh
echo 'source ~/.codex/cx.zsh' >> ~/.zshrc
```

## commands

- `cx [account] [codex options...]` - run codex with an account, or auto-pick one.
- `cx list` - list account quotas and refresh times.
- `cx refresh` - refresh auth tokens for all accounts.

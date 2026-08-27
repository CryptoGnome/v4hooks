## What

- [ ] New hook listing (`hooks/{slug}.yml`)
- [ ] First-party Solidity under `contracts/` (+ `forge test`)
- [ ] Edit existing listing
- [ ] Site / worker / docs

## Checklist

- [ ] `npm run validate` passes
- [ ] If `contracts/` or `test/` changed: `forge test` passes
- [ ] Filename matches `slug`
- [ ] Description is unique and ≥ 280 characters
- [ ] `source.url` is a GitHub permalink; `solidity` matches that file
- [ ] No invented addresses or invented Solidity
- [ ] I understand listing is not an audit

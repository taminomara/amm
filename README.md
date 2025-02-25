# AMM Build Action

This github action builds packages for AMM.

Example usage:

```yml
name: Build and publish an AMM package
on:
  pull_request:
    branches:
      - main
  push:
    branches:
      - main
  release:
    types:
      - published
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: taminomara/amm@action
```

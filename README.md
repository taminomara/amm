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
    tags:
      - *
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: taminomara/amm@action
```

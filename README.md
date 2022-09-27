<h3 align="center"><img src="https://img.icons8.com/color/344/tank.png" width="120"/></h3>

<h3 align="center" style="margin-top:-25px">(Super Tank)</h3>

<h5 align="center"> ERC-4626 super tank for all <a href="https://github.com/artgobblers/art-gobblers">Gobblers and Goo Tokens</a> </h5>

![Github Actions](https://github.com/maximebrugel/super-tank/workflows/CI/badge.svg)

## Goal

The *Super Tank* allows Gobblers owner and Goo holders to pool everything in one tank.

The Vault is deployed with a fee on performances (between 1 and 100%) and are sent to a `feeRecipient`.

This could meet several needs :
- Goo holders who cannot afford to buy a Gobblers and want to participate.
- A Gobblers owner who want to share his goo issuance, remaining competitive with the strategy of not sharing.
- A DAO as fee recipient to acquire gobblers, pages,...

## Getting Started

```sh
git clone https://github.com/maximebrugel/super-tank
cd super-tank
forge install
forge build
forge test
```
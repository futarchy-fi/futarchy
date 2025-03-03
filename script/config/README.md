# Futarchy Proposal & Liquidity Configuration

This directory contains configuration files for the Futarchy Proposal & Liquidity script.

## Configuration Files

### `proposal.json`

This file contains the configuration for a single futarchy proposal, including:

- Proposal details (name, question, category, language)
- Collateral token addresses
- Minimum bond amount
- Opening time
- Liquidity parameters

Example:
```json
{
  "name": "Implementation of Feature X",
  "question": "Should we implement Feature X in the next release?",
  "category": "governance",
  "lang": "en",
  "collateralToken1": "0xe91d153e0b41518a2ce8dd3d7944fa863463a97d",
  "collateralToken2": "0x4ECaBa5870353805a9F068101A40E0f32ed605C6",
  "minBond": "1000000000000000000",
  "openingTime": 0,
  "liquidity": {
    "wxdaiAmount": "10000000000000000000",
    "token1Amount": "10000000000000000000",
    "token2Amount": "10000000000000000000"
  }
}
```

### `batch_proposals.json`

This file contains an array of proposal configurations for batch processing:

Example:
```json
[
  {
    "name": "Implementation of Feature X",
    "question": "Should we implement Feature X in the next release?",
    "category": "governance",
    "lang": "en",
    "collateralToken1": "0xe91d153e0b41518a2ce8dd3d7944fa863463a97d",
    "collateralToken2": "0x4ECaBa5870353805a9F068101A40E0f32ed605C6",
    "minBond": "1000000000000000000",
    "openingTime": 0,
    "liquidity": {
      "wxdaiAmount": "10000000000000000000",
      "token1Amount": "10000000000000000000",
      "token2Amount": "10000000000000000000"
    }
  },
  {
    "name": "Implementation of Feature Y",
    "question": "Should we implement Feature Y in the next release?",
    "category": "governance",
    "lang": "en",
    "collateralToken1": "0xe91d153e0b41518a2ce8dd3d7944fa863463a97d",
    "collateralToken2": "0x4ECaBa5870353805a9F068101A40E0f32ed605C6",
    "minBond": "1000000000000000000",
    "openingTime": 0,
    "liquidity": {
      "wxdaiAmount": "15000000000000000000",
      "token1Amount": "15000000000000000000",
      "token2Amount": "15000000000000000000"
    }
  }
]
```

### `.env`

This file contains environment variables required for the script:

- Private key for transaction signing
- RPC URL for Gnosis Chain
- Contract addresses (FutarchyFactory, SushiSwap V2/V3, WXDAI)

Copy `.env.example` to `.env` and fill in your values:

```
PRIVATE_KEY=YourPrivateKeyHere
RPC_URL=https://rpc.gnosischain.com
FUTARCHY_FACTORY=0xa6cb18fcdc17a2b44e5cad2d80a6d5942d30a345
SUSHI_V2_FACTORY=0xc35dadb65012ec5796536bd9864ed8773abc74c4
SUSHI_V2_ROUTER=0x1b02da8cb0d097eb8d57a175b88c7d8b47997506
SUSHI_V3_FACTORY=0x3e1b852f6ad9d52e88fc16d8c8af7825ec2ea4dd
SUSHI_V3_ROUTER=0xb4315e873dbcf96ffd0acd8ea43f689d8c20fb30
WXDAI_ADDRESS=0xe91d153e0b41518a2ce8dd3d7944fa863463a97d
```

## Usage

### Single Proposal

To run the script with a single proposal configuration:

```bash
forge script script/proposal/FutarchyProposalLiquidity.s.sol:FutarchyProposalLiquidity --sig "run(string)" "script/config/proposal.json" --rpc-url $RPC_URL --private-key $PRIVATE_KEY
```

### Batch Processing

To run the script with multiple proposals in batch mode:

```bash
forge script script/proposal/FutarchyProposalLiquidity.s.sol:FutarchyProposalLiquidity --sig "runBatch(string)" "script/config/batch_proposals.json" --rpc-url $RPC_URL --private-key $PRIVATE_KEY
```
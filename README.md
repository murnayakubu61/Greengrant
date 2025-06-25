# 🌱 Greengrant - Environmental DAO Grants

> Fund green innovation through community-driven governance 🌍

## 📋 Overview

Greengrant is a decentralized autonomous organization (DAO) built on Stacks that enables communities to fund environmental projects through democratic voting. Members contribute STX to the treasury and vote on proposals to fund green innovations and sustainability initiatives.

## ✨ Features

- 🏛️ **DAO Membership**: Join the community and gain voting power
- 💰 **Treasury Management**: Contribute STX to fund environmental projects  
- 📝 **Proposal Creation**: Submit funding requests for green initiatives
- 🗳️ **Democratic Voting**: Vote on proposals with weighted voting power
- ⚡ **Automatic Execution**: Approved proposals automatically distribute funds
- 📊 **Transparent Governance**: All votes and proposals are on-chain

## 🚀 Getting Started

### Prerequisites
- Clarinet installed
- Stacks wallet with STX tokens

### Installation

```bash
git clone <repository-url>
cd greengrant
clarinet check
```

## 📖 Usage Guide

### 1. Join the DAO 🤝
```clarity
(contract-call? .greengrant join-dao)
```

### 2. Contribute to Treasury 💵
```clarity
(contract-call? .greengrant contribute-to-treasury u5000000) ;; 5 STX
```

### 3. Create Environmental Proposal 📋
```clarity
(contract-call? .greengrant create-proposal 
  "Solar Panel Installation"
  "Install solar panels for community center to reduce carbon footprint"
  u10000000  ;; 10 STX
  'SP1ABC...  ;; recipient address
)
```

### 4. Vote on Proposals 🗳️
```clarity
(contract-call? .greengrant vote-on-proposal u1 true)  ;; Vote YES on proposal #1
```

### 5. Finalize Completed Votes ✅
```clarity
(contract-call? .greengrant finalize-proposal u1)
```

## 🔍 Read-Only Functions

### Get Proposal Details
```clarity
(contract-call? .greengrant get-proposal u1)
```

### Check Treasury Balance
```clarity
(contract-call? .greengrant get-treasury-balance)
```

### View DAO Statistics
```clarity
(contract-call? .greengrant get-dao-stats)
```

### Check Member Information
```clarity
(contract-call? .greengrant get-member-info 'SP1ABC...)
```

## ⚙️ Configuration

- **Minimum Proposal Amount**: 1 STX (1,000,000 microSTX)
- **Maximum Proposal Amount**: 100 STX (100,000,000 microSTX)
- **Voting Duration**: 1,440 blocks (~10 days)
- **Minimum Votes Required**: 3 votes to finalize

## 🏗️ Contract Architecture

### Key Components:
- **Membership System**: Track DAO members and their voting power
- **Proposal Lifecycle**: Create → Vote → Finalize → Execute
- **Treasury Management**: Secure fund storage and distribution
- **Voting Mechanism**: Weighted voting based on contributions

### Voting Power Calculation:
- Base voting power: 1
- Additional power: +1 per STX contributed
- Formula: `1 + (contribution / 1,000,000)`

## 🛡️ Security Features

- ✅ Owner-only emergency functions
- ✅ Proposal amount limits
- ✅ Voting period enforcement
- ✅ Double-voting prevention
- ✅ Treasury balance validation

## 🧪 Testing

```bash
clarinet test
```

## 🤝 Contributing

1. Fork the repository
2. Create your feature branch
3. Commit your changes
4. Push to the branch
5. Create a Pull Request

## 📄 License

This project is licensed under the MIT License.

## 🌟 Support the Mission

Help us fund the next generation of environmental innovations! Join our DAO and vote for projects that make a positive impact on our planet. 🌍💚



# VetoVault 🏛️⚡

**A Decentralized Multi-Signature Governed Token Protocol on Stacks**

VetoVault is a sophisticated decentralized governance protocol that combines multi-signature security with token-based voting mechanisms. Built on the Stacks blockchain, it enables communities to collectively manage treasuries, make governance decisions, and execute proposals through a secure multi-signature framework.

## 🌟 Overview

VetoVault revolutionizes decentralized governance by implementing a hybrid model that combines:
- **Multi-signature security** for critical operations
- **Token-based voting** for community participation  
- **Timelock mechanisms** for proposal execution safety
- **Flexible governance parameters** adaptable to different use cases
- **Treasury management** with transparent fund allocation

## ✨ Key Features

### 🔐 Multi-Signature Security
- Configurable signature thresholds (M-of-N signatures)
- Role-based access control for different operations
- Emergency pause mechanisms
- Signature verification with replay protection

### 🗳️ Decentralized Governance
- Token-weighted voting system
- Proposal creation and execution framework
- Quorum requirements and voting periods
- Delegation and proxy voting support

### ⏰ Timelock Protection
- Mandatory delay periods for critical changes
- Grace periods for proposal execution
- Emergency override mechanisms for guardians
- Queue-based proposal management

### 💰 Treasury Management
- Multi-asset treasury support (STX, SIP-010 tokens)
- Automated fund allocation based on proposals
- Transparent spending tracking
- Budget allocation and limits

### 🎯 Flexible Configuration
- Adjustable voting parameters
- Dynamic signature requirements
- Upgradeable governance modules
- Custom proposal types

## 🏗️ Architecture

VetoVault follows a modular architecture with interconnected smart contracts:

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Governance    │────│   Multi-Sig     │────│    Treasury     │
│   Controller    │    │     Wallet      │    │    Manager      │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │                       │
         │              ┌─────────────────┐              │
         └──────────────│    Timelock     │──────────────┘
                        │   Controller    │
                        └─────────────────┘
                                 │
         ┌─────────────────┬─────┴─────┬─────────────────┐
         │                 │           │                 │
┌─────────────────┐ ┌─────────────────┐ ┌─────────────────┐
│   VetoVault     │ │   Proposal      │ │   Access        │
│     Token       │ │   Manager       │ │   Control       │
└─────────────────┘ └─────────────────┘ └─────────────────┘
```

## 📋 Smart Contracts

### Core Contracts

1. **VetoVault Token (SIP-010)**
   - Governance token with voting capabilities
   - Delegation and snapshot functionality
   - Burn/mint controls tied to governance

2. **Multi-Signature Wallet**
   - M-of-N signature requirements
   - Transaction proposal and execution
   - Signer management and rotation

3. **Governance Controller**
   - Main governance logic coordinator
   - Proposal lifecycle management
   - Voting mechanism implementation

4. **Timelock Controller**
   - Delayed execution of critical operations
   - Queue management for proposals
   - Emergency override capabilities

### Supporting Contracts

5. **Proposal Manager**
   - Proposal creation and validation
   - Voting period management
   - Result calculation and execution

6. **Treasury Manager**
   - Multi-asset fund management
   - Automated allocation based on proposals
   - Spending limits and budget controls

7. **Access Control**
   - Role-based permission system
   - Guardian and admin role management
   - Emergency pause mechanisms

8. **Voting System**
   - Token-weighted voting implementation
   - Quorum calculation and validation
   - Delegation and proxy voting

## 🚀 Getting Started

### Prerequisites

- Clarinet CLI installed
- Stacks wallet (Hiro Wallet recommended)
- Node.js 16+ for frontend development
- Basic understanding of Clarity smart contracts

### Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/your-org/vetovault.git
   cd vetovault
   ```

2. **Install dependencies**
   ```bash
   npm install
   clarinet install
   ```

3. **Run tests**
   ```bash
   clarinet test
   ```

4. **Deploy to testnet**
   ```bash
   clarinet deploy --testnet
   ```

### Configuration

Edit `Clarinet.toml` to configure:
- Initial token supply and distribution
- Multi-sig threshold requirements
- Governance parameters (voting periods, quorum)
- Timelock delays for different operation types

## 📖 Usage Guide

### For Token Holders

1. **Participate in Governance**
   ```clarity
   ;; Vote on a proposal
   (contract-call? .governance-controller vote u1 true)
   
   ;; Delegate voting power
   (contract-call? .vetovault-token delegate 'SP1234...ABCD)
   ```

2. **Create Proposals**
   ```clarity
   ;; Submit a treasury spending proposal
   (contract-call? .proposal-manager create-proposal
     "Treasury Allocation for Development"
     u1000000 ;; 1 STX
     'SP5678...EFGH) ;; recipient
   ```

### For Multi-Sig Signers

1. **Sign Transactions**
   ```clarity
   ;; Sign a pending transaction
   (contract-call? .multisig-wallet sign-transaction u1)
   
   ;; Execute when threshold reached
   (contract-call? .multisig-wallet execute-transaction u1)
   ```

### For Administrators

1. **Emergency Actions**
   ```clarity
   ;; Pause the system in emergency
   (contract-call? .access-control emergency-pause)
   
   ;; Update governance parameters
   (contract-call? .governance-controller update-voting-period u144) ;; 1 day
   ```

## 🏛️ Governance Model

### Proposal Types

1. **Treasury Proposals**: Fund allocation and spending
2. **Parameter Changes**: Governance parameter updates
3. **Contract Upgrades**: Smart contract improvements
4. **Emergency Actions**: Critical system interventions

### Voting Process

1. **Proposal Creation** (24 hour delay)
2. **Voting Period** (7 days default)
3. **Execution Delay** (48 hours for critical changes)
4. **Implementation** (Automatic or manual execution)

### Quorum Requirements

- **Standard Proposals**: 10% of total token supply
- **Critical Changes**: 25% of total token supply
- **Emergency Actions**: 51% of total token supply

## 🔒 Security Features

### Multi-Layer Security

1. **Smart Contract Audits**: Professional security reviews
2. **Formal Verification**: Mathematical proof of correctness
3. **Bug Bounty Program**: Community-driven security testing
4. **Gradual Rollout**: Phased deployment with monitoring

### Risk Mitigation

- **Timelock Delays**: Prevent rushed decisions
- **Emergency Pause**: Stop operations if needed
- **Signature Verification**: Prevent replay attacks
- **Access Control**: Role-based permissions

## 🧪 Testing

### Unit Tests
```bash
clarinet test tests/unit/
```

### Integration Tests
```bash
clarinet test tests/integration/
```

### Simulation Tests
```bash
clarinet test tests/simulation/
```

## 📊 Monitoring & Analytics

- **Governance Dashboard**: Real-time proposal tracking
- **Treasury Analytics**: Fund flow visualization
- **Voting Participation**: Community engagement metrics
- **Security Monitoring**: Anomaly detection and alerts

## 🤝 Contributing

We welcome contributions! Please see our [Contributing Guide](CONTRIBUTING.md) for details.

### Development Workflow

1. Fork the repository
2. Create a feature branch
3. Write tests for new functionality
4. Submit a pull request with detailed description

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🆘 Support

- **Documentation**: [docs.vetovault.org](https://docs.vetovault.org)
- **Discord**: [Join our community](https://discord.gg/vetovault)
- **GitHub Issues**: Report bugs and request features
- **Email**: support@vetovault.org

## 🗺️ Roadmap

### Phase 1: Core Implementation ✅
- Basic multi-sig functionality
- Token governance system
- Proposal management

### Phase 2: Advanced Features 🚧
- Cross-chain governance
- Advanced voting mechanisms
- Mobile wallet integration

### Phase 3: Ecosystem Growth 📋
- Third-party integrations
- Developer tools and SDKs
- Governance analytics platform

---

**Built with ❤️ on Stacks blockchain**


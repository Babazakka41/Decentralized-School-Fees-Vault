# 🏫 Decentralized School Fees Vault

A secure, automated smart contract system for managing school fee payments on the Stacks blockchain. Parents can lock funds for term fees with automated release dates, ensuring timely payments to schools.

## 🔧 Features

- 💰 **Secure Fee Deposits**: Parents can deposit STX tokens for school fees
- ⏰ **Automated Release**: Funds are automatically released on specified dates
- 🏛️ **School Verification**: Schools can register and be verified by contract owner
- 📊 **Comprehensive Tracking**: Track deposits, releases, and statistics
- 🚨 **Emergency Withdrawal**: Parents can withdraw funds before release date if needed
- 📈 **Batch Operations**: Process multiple vault releases at once

## 🚀 Getting Started

### Prerequisites

- [Clarinet](https://docs.hiro.so/stacks/clarinet) installed
- Node.js and npm (for testing)

### Installation

```bash
git clone <repository-url>
cd Decentralized-School-Fees-Vault
npm install
```

### Running Tests

```bash
npm test
```

### Deployment

```bash
clarinet deploy
```

## 📋 Contract Functions

### 🏛️ School Management

#### `register-school`
Register a new school with the contract.

```clarity
(contract-call? .vault register-school "Springfield Elementary")
```

#### `verify-school`
Verify a school (only contract owner can call this).

```clarity
(contract-call? .vault verify-school 'SP1SCHOOL...)
```

### 💰 Vault Operations

#### `create-vault`
Create a new fee vault for a student.

```clarity
(contract-call? .vault create-vault 
  "John Doe" 
  'SP1SCHOOL... 
  u1000 
  "Fall 2024")
```

Parameters:
- `student-name`: Name of the student
- `school`: School's principal address
- `release-blocks`: Number of blocks until release
- `term`: Academic term identifier

#### `deposit-to-vault`
Add additional funds to an existing vault.

```clarity
(contract-call? .vault deposit-to-vault u1 u1000000)
```

#### `release-funds`
Release funds to the school (can be called by anyone once release date is reached).

```clarity
(contract-call? .vault release-funds u1)
```

#### `emergency-withdraw`
Emergency withdrawal by parent before release date.

```clarity
(contract-call? .vault emergency-withdraw u1)
```

#### `extend-release-date`
Extend the release date of a vault.

```clarity
(contract-call? .vault extend-release-date u1 u500)
```

### 📊 Query Functions

#### `get-vault`
Get vault information by ID.

```clarity
(contract-call? .vault get-vault u1)
```

#### `get-vault-status`
Check if a vault is "locked", "releasable", or "released".

```clarity
(contract-call? .vault get-vault-status u1)
```

#### `get-blocks-until-release`
Get number of blocks until a vault can be released.

```clarity
(contract-call? .vault get-blocks-until-release u1)
```

#### `get-contract-stats`
Get overall contract statistics.

```clarity
(contract-call? .vault get-contract-stats)
```

#### `get-parent-stats`
Get statistics for a specific parent.

```clarity
(contract-call? .vault get-parent-stats 'SP1PARENT...)
```

#### `get-school-info`
Get information about a school.

```clarity
(contract-call? .vault get-school-info 'SP1SCHOOL...)
```

## 🔐 Security Features

- **Access Control**: Only parents can manage their own vaults
- **School Verification**: Schools must be registered and can be verified
- **Emergency Procedures**: Parents can withdraw funds before release if needed
- **Automated Release**: Funds are released automatically based on block height

## 📈 Usage Examples

### Parent Creating a Vault

```clarity
;; 1. Check if school is registered
(contract-call? .vault get-school-info 'SP1SCHOOL...)

;; 2. Create vault for Fall 2024 term (release in 1000 blocks)
(contract-call? .vault create-vault 
  "Alice Smith" 
  'SP1SCHOOL... 
  u1000 
  "Fall 2024")

;; 3. Check vault status
(contract-call? .vault get-vault-status u1)
```

### School Registration

```clarity
;; School registers itself
(contract-call? .vault register-school "Springfield Elementary")

;; Contract owner verifies the school
(contract-call? .vault verify-school 'SP1SCHOOL...)
```

### Automated Fee Release

```clarity
;; Anyone can trigger release once time is reached
(contract-call? .vault release-funds u1)

;; Batch release multiple vaults
(contract-call? .vault batch-release-funds (list u1 u2 u3))
```

## 🔧 Development

### Contract Structure

- **Data Variables**: Track counters and totals
- **Maps**: Store vault, parent, and school information
- **Constants**: Define error codes and contract owner
- **Functions**: Public and private functions for all operations

### Testing

```bash
clarinet test
```

### Checking Contract

```bash
clarinet check
```

## 🎯 Error Codes

- `u1`: Unauthorized access
- `u2`: Invalid amount
- `u3`: Invalid date
- `u4`: Vault not found
- `u5`: Funds locked
- `u6`: Insufficient balance
- `u7`: Already released
- `u8`: Invalid school
- `u9`: Vault exists

## 📝 License

MIT License



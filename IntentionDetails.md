# Intentions

## Overview
The Intention Validator is used for processing multiple user-signed transactions securely through account abstraction. It provides:

- High-throughput transaction processing through intention aggregation
- Transaction conflict prevention with nonce management
- Flexible execution models supporting both sequential and parallel flows
- Robust security via constraint validation and signature verification

## Core Components
- Validation Engine
- Constraint System
- Signature Verification
- Value Management
- Nonce Control

## Implementation Details
### ValidationFlow
The validation process follows these sequential steps:

1. Redeemer Analysis
   - Extracts intention list
   - Processes user counts
   - Establishes validation context
   - Initializes signature verification

2. Per-User Intention Processing
   - Signature validation
   - Nonce verification
   - Value tracking
   - Constraint validation

3. Constraint System Validation
   - Output structure verification
   - Signature requirements
   - Redeemer validation
   - Reference input verification
   - Input validation
   - Minting policy enforcement
   - Time bounds checking

4. Value Management
   - Input value tracking
   - Output value verification
   - Movement validation

5. Final Verification
   - Intention completion check
   - Constraint satisfaction
   - Nonce progression
   - Transaction structure


## Data Structures
### Signed Intentions
```aiken
/// Represents a user-signed intention with authentication data
type SignedIntention {
    // User stake key hash for identification
    user_stake: ScriptHash,

    // Core intention data
    intent: Intent,

    // Signature wrapper data
    prefix: ByteArray,
    postfix: ByteArray,

    // Authentication signatures
    signatures: Data<List<Signature>>
}

/// Core intention structure
type Intent {
    // Runtime validation constraints
    constraints: Data<List<Constraint>>,

    // Value movement specification
    value_leaving: (Lovelace, Data<Pair<PolicyId, OutputAssetMap>>),

    // Uniqueness enforcer
    nonce: IntentNonce
}

/// Nonce types for intention uniqueness
pub type IntentNonce {
    Sequential(Int)
    Parallel(OutputReference)
}
```

### Constraint System
```aiken
/// Defines validation requirements
pub type Constraint {
    OutConNil(Data<OutputConstraint>)
    SignedNil(VerificationKeyHash)
    RedeemerVal(Data<ScriptPurpose>, Data<List<Int>>, Data<Option<Data>>)
    RefConVal(Data<InputConstraint>)
    InpConVal(Data<InputConstraint>)
    MintConNil(PolicyId, AssetName, Int)
    AfterVal(Int)
    BeforeVal(Int)
}

/// Input validation requirements
pub type InputConstraint {
    address: Data<Options<Address, Credential>>,
    value: Data<List<(PolicyId, AssetName, Int)>>,
    datum_field: Data<List<Int>>,
    in_ref: Data<Option<OutputReference>>,
}

/// Output validation requirements
pub type OutputConstraint {
    address: Data<Options<Address, Credential>>,
    value: Data<
        Options<Pairs<ByteArray, Pairs<ByteArray, Int>>, (PolicyId, AssetName)>,
    >,
    datum: Data<Options<Data, (ByteArray, ByteArray)>>,
    ref: Data<Option<ScriptHash>>
}
```

## Usage Examples

### Sequential Execution
```aiken
/// Example: Sequential intention chain
// First intention
SignedIntention {
    nonce: Sequential(n),      // Current sequence number
    constraints: [             // Transaction constraints
        OutConNil(payment),    // Payment requirements
        SignedNil(signer)      // Required signatures
    ],
    value_leaving: (
        100_000_000,          // ADA amount
        tokens                // Token bundle
    )
}

// Next intention
SignedIntention {
    nonce: Sequential(n+1),    // Next sequence number
    constraints: [
        OutConNil(payment),
        SignedNil(signer)
    ],
    value_leaving: (50_000_000, tokens)
}
```

### Parallel Processing
```aiken
/// Example: Parallel intention execution
SignedIntention {
    nonce: Parallel(specific_utxo),  // UTXO-based nonce
    constraints: [
        InpConVal(input_requirement),
        MintConNil(policy_id, asset_name, 1),
        BeforeVal(deadline)
    ],
    value_leaving: (value_details)
}
```
### Combined
```aiken
// User 1 Sequential Intentions
SignedIntention {
  user_stake: user1_stake,
  nonce: Sequential(5),
  constraints: [
    OutConNil(payment_constraint),
    SignedNil(required_signer),
    RedeemerVal(script_purpose, [0], Some(expected_value))
  ],
  value_leaving: (1_000_000, token_bundle_1)
}

// User 2 Parallel Intention
SignedIntention {
  user_stake: user2_stake,
  nonce: Parallel(specific_utxo),
  constraints: [
    InpConVal(input_requirement),
    MintConNil(policy_id, asset_name, 1),
    BeforeVal(deadline)
  ],
  value_leaving: (500_000, token_bundle_2)
}
```

## InputConstraints

### Input Constraint Structure
```aiken
type InputConstraint {
  address: Data<Options<Address, Credential>>,  // Target address or credential
  value: Data<List<(PolicyId, AssetName, Int)>>, // Required assets
  datum_field: Data<List<Int>>, // Path to datum fields
  in_ref: Data<Option<OutputReference>> // Specific UTXO reference
}
```

### Input Constraint Types

a) Address Validation:
```aiken
// Match exact address
address: SomeOne(Address {
  payment_credential: Script(script_hash),
  stake_credential: Some(Inline(stake_key))
})

// Match only payment credential
address: SomeTwo(Script(script_hash))

// No address restriction
address: Nada
```

b) Value Requirements:
```aiken
// Check for specific token quantities
value: [
  // Require exactly 100 TokenA from PolicyA
  (policyA, tokenA, 100),

  // Require exactly 50 TokenB from PolicyB
  (policyB, tokenB, 50),

  // Check for ADA amount
  (ada_policy_id, "", 2_000_000)
]

// No value requirements
value: []
```

c) Datum Field Access:
```aiken
// Access nested datum fields using indices
datum_field: [0, 2, 1] // Goes 3 levels deep into datum structure

// Puts resulting value into temp_val
// Example datum structure:
Datum {
  field0: {
    field1: value1,
    field2: {
      field0: value2,
      field1: target_value // This is accessed
    }
  }
}
```

d) Input Reference:
```aiken
// Match exact output reference
in_ref: Some(output_reference)


// No output reference restriction
in_ref: None
```

### Input Constraint Examples:

```aiken
// Example 1: Specific UTXO with included value
InpConVal(InputConstraint {
  address: SomeOne(specific_address),
  value: [(policy_id, asset_name, 100)],
  datum_field: [], // Access whole datum
  in_ref: Some(specific_utxo)
})

// Example 2: Any script input with datum requirement
InpConVal(InputConstraint {
  address: SomeTwo(script_credential),
  value: [],
  datum_field: [0, 1], // Access specific datum field
  in_ref: None
})

// Example 3: Reference input validation
RefConVal(InputConstraint {
  address: SomeOne(reference_address),
  value: [(policy_id, "", 1)], // Require NFT
  datum_field: [0], // Access first datum field
  in_ref: None
})
```

- Input Constraint Priority:
```aiken
// temp_val from input constraints can be used for:
// - Value comparisons
// - Datum construction
// - Output value specification
// - Subsequent constraint validation
```

- Error Awareness:
```aiken
// For input constraints, need to handle:
// - No matching input found
// - Datum field selection errors
// - Value requirement mismatches
```

## OutputConstraints

### Output Constraint Structure
```aiken
type OutputConstraint {
  address: Data<Options<Address, Credential>>, // Target address/credential
  value: Data<
    Options<
      Pairs<ByteArray, Pairs<ByteArray, Int>>, // Exact value
      (PolicyId, AssetName) // Token specification
    >
  >,
  datum: Data<Options<Data, (ByteArray, ByteArray)>>, // Datum requirements
  ref: Data<Option<ScriptHash>> // Script reference
}
```

### Output Constraint Types

a) Address Requirements:
```aiken
// Exact address match
address: SomeOne(Address {
  payment_credential: Script(policy_id),
  stake_credential: Some(Inline(stake_cred))
})

// Payment credential only
address: SomeTwo(Script(policy_id))

// No address restriction
address: Nada
```

b) Value Specifications:
```aiken
// Exact value match
value: SomeOne([
  (policy1, [(token1, 100), (token2, 50)]),
  (policy2, [(token3, 75)])
])

// Has token with quantity from temp_val
value: SomeTwo((policy_id, asset_name))

// No value requirements
value: Nada
```

c) Datum Requirements:
```aiken
// Exact datum match
datum: SomeOne(specific_datum)

// Datum with prefix/postfix, fills in between
// with serialized temp_val
datum: SomeTwo((prefix_bytes, postfix_bytes))

// No datum requirements
datum: Nada
```

d) Script ref Requirements:
```aiken
// Exact script hash match in reference_script field
ref: Some(script_hash)

// No reference_script requirements
ref: None
```

### Output Constraint Examples:

```aiken
// Example 1: Exact payment with datum
OutConNil(OutputConstraint {
  address: SomeOne(recipient_address),
  value: SomeOne([
    (ada_policy_id, [("", 2_000_000)]),
    (token_policy, [(token_name, 100)])
  ]),
  datum: SomeOne(inline_datum),
  ref: None
})

// Example 2: Token delivery with script reference
// Uses value from temp_val to fill in value and datum
// value expects temp_val to be an Int
OutConNil(OutputConstraint {
  address: SomeTwo(payment_credential),
  value: SomeTwo((policy_id, token_name)),
  datum: SomeTwo((prefix, postfix)), // Dynamic datum
  ref: Some(script_hash)
})

// Example 3: Output with address
OutConNil(OutputConstraint {
  address: SomeOne(change_address),
  value: Nada, // Any remaining value
  datum: Nada, // No datum required
  ref: None
})
```

### Constraint Validation Process:

```aiken
fn handle_out_constraint(
  outputs: List<Output>,
  con: Data<OutputConstraint>,
  temp_val: Data,
) -> Data {
  // 1. Address validation
  let runnable_address = validate_address_requirement(con.address)

  // 2. Value validation
  let runnable_val = validate_value_requirement(con.value, temp_val)

  // 3. Datum validation
  let runnable_datum = validate_datum_requirement(con.datum, temp_val)

  // 4. Script reference validation
  let runnable_ref = validate_reference_requirement(con.ref)

  // 5. Combined validation
  apply_constraint_to_list(outputs, fn(output) {
    and {
      runnable_address(output),
      runnable_val(output),
      runnable_datum(output),
      runnable_ref(output)
    }
  })
}
```

### Common Validation Patterns:

```aiken
// Pattern 1: NFT Transfer
OutConNil(OutputConstraint {
  address: SomeOne(recipient),
  value: SomeOne([
    (policy_id, [(token_name, 1)])
  ]),
  datum: Nada,
  ref: None
})

// Pattern 2: DApp Interaction
OutConNil(OutputConstraint {
  address: SomeOne(script_address),
  value: SomeOne(exact_value_requirement),
  datum: SomeOne(interaction_datum),
  ref: Some(reference_script)
})

// Pattern 3: Token Distribution
OutConNil(OutputConstraint {
  address: SomeTwo(payment_credential),
  value: SomeOne([
    (policy_id, [(token_name, distribution_amount)])
  ]),
  datum: Nada,
  ref: None
})
```


## TempValueSystem

### Overview
```aiken
// temp_val is a Data value that gets passed through constraint validation
// and can be used to carry intermediate results between constraints
fn handle_constraint(constraint: Data<Constraint>, temp_val: Data) -> Data
```

### Key Characteristics
- Acts as a state carrier between constraint validations
- Initially starts as `None`
- Can be modified by certain constraints
- Used by subsequent constraints for value comparisons
- Enables chained validation patterns

### When temp_val Gets Set

a) From Input Constraints:
```aiken
InpConVal(inp_constraints) -> {
  // Returns selected datum fields from matching input
  // This becomes the new temp_val
  handle_inp_constraint(inputs, inp_constraints)
}

RefConVal(ref_constraints) -> {
  // Returns selected datum fields from matching reference input
  // This becomes the new temp_val
  handle_inp_constraint(reference_inputs, ref_constraints)
}
```

b) From RedeemerVal Constraint:
```aiken
RedeemerVal(script_purpose, field_selection, compare_val) -> {
  if compare_val == dataify(None) {
    field // Becomes new temp_val
  } else {
    expect Some(compare) = compare_val
    expect field == compare
    field // Becomes temp_val after comparison
  }
}
```

c) From Time Constraints:
```aiken
AfterVal(time) -> {
  let lower = expect_item(lower_bound_val)
  expect time < builtin.un_i_data(lower)
  dataify(lower) // Becomes new temp_val
}

BeforeVal(time) -> {
  let upper = expect_item(upper_bound_val)
  expect time >= builtin.un_i_data(upper)
  dataify(upper) // Becomes new temp_val
}
```

### Common Input Constraint temp_val Patterns:

a) Reference Input to Output Flow:
```aiken
[
  // Extract value from reference input datum
  RefConVal(InputConstraint {
    address: SomeOne(ref_address),
    value: [],
    datum_field: [0, 1], // Select specific datum field
    in_ref: None
  }),

  // Use extracted value in output
  OutConNil(OutputConstraint {
    value: SomeTwo((policy, asset_name)) // Uses temp_val as amount
  })
]
```

b) Input to Output Value Transfer:
```aiken
[
  // Get value from input datum
  InpConVal(InputConstraint {
    address: SomeTwo(script_credential),
    value: [(policy_id, asset_name, minimum_amount)],
    datum_field: [2], // Extract amount from datum
    in_ref: None
  }),

  // Use in output construction
  OutConNil(OutputConstraint {
    datum: SomeTwo((prefix, postfix)) // Uses temp_val in datum construction
  })
]
```

### Other Example Patterns:

a) Redeemer-Driven Payment:
```aiken
[
  RedeemerVal(
    script_purpose,
    [0], // Pull redeemer value from Oracle script
         // Oracle script must do calculations in advance
         // and include result in the redeemer field
    None,
  ),

  // Create payment output
  OutConNil(OutputConstraint {
    // Uses temp_val as payment amount
    value: SomeTwo((payment_policy, payment_token))
  })
]
```

b) Input-Datum-Driven Protocol:
```aiken
[
  // Extract protocol parameters from input
  InpConVal(InputConstraint {
    address: SomeOne(protocol_address),
    value: [(protocol_policy, protocol_token, 1)],
    datum_field: [1, 0], // Protocol config
    in_ref: None
  }),

  // Create protocol output
  OutConNil(OutputConstraint {
    datum: SomeTwo((prefix, postfix)) // Uses temp_val
  })
]
```

### Important Considerations:

Correct Usage:
```aiken
[
  // Sets temp_val
  RefConVal(InputConstraint {
    datum_field: [0]
  }),

  // Can use temp_val from RefConVal
  OutConNil(OutputConstraint {
    value: SomeTwo((policy, asset_name))
  }),

  // Cannot access temp_val from RefConVal anymore
  // Gets None from previous OutConNil
  RedeemerVal(script_purpose, [0], None)
]
```

Incorrect (Won't Work):
```aiken
[
  // Sets temp_val
  RefConVal(InputConstraint {
    datum_field: [0]
  }),

  // Some other constraint that doesn't use temp_val
  SignedNil(signer),

  // WRONG: Cannot access temp_val from RefConVal anymore
  OutConNil(OutputConstraint {
    value: SomeTwo((policy, asset_name))
  })
]

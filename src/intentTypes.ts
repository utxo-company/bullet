// Import required types from lucid library
import { Data } from "@lucid-evolution/lucid";
import {
  AddressSchema,
  CredentialSchema,
  OptionSchema,
  OptionsSchema,
  OutputRefSchema,
  ScriptPurposeSchema,
} from "./otherTypes";

// Schema for natural numbers (positive integers)
export const NaturalSchema = Data.Integer({ minimum: 1 });
// Schema for asset names/identifiers
export const AssetSchema = Data.Bytes({ maxLength: 32 });

// Map of assets to their quantities
export const OutputAssetMap = Data.Map(AssetSchema, NaturalSchema);

// Schema for sequential nonce generation
export const SequentialSchema = Data.Object({
  Sequential: Data.Tuple([Data.Integer({ minimum: 1 })]),
});

// Schema for parallel nonce generation using output references
export const ParallelSchema = Data.Object({
  Parallel: Data.Tuple([OutputRefSchema]),
});

// Combined nonce schema supporting both sequential and parallel
export const NonceSchema = Data.Enum([SequentialSchema, ParallelSchema]);

// Schema defining constraints on transaction outputs
export const OutputConstraintSchema = Data.Object({
  // Address or credential constraint
  address: OptionsSchema(
    AddressSchema, // Full address
    CredentialSchema, // Just credential
  ),
  // Value constraint specifying assets
  value: OptionsSchema(
    Data.Tuple([
      // Policy ID with asset name and amount
      Data.Bytes({ minLength: 28, maxLength: 28 }),
      Data.Tuple([AssetSchema, Data.Integer({ minimum: 1 })]),
    ]),
    Data.Tuple([
      // Just policy ID and asset name
      Data.Bytes({ minLength: 28, maxLength: 28 }), // PolicyId
      AssetSchema, // AssetName
    ]),
  ),
  // Datum constraint
  datum: OptionsSchema(
    Data.Any(), // Arbitrary datum
    Data.Tuple([
      // Raw bytes datum
      Data.Bytes(),
      Data.Bytes(),
    ]),
  ),
  // Optional reference script
  ref: OptionSchema(
    Data.Bytes({ minLength: 28, maxLength: 28 }), // Script hash
  ),
});

// Output constraint type
export const OutConNilSchema = Data.Object({
  OutConNil: Data.Tuple([OutputConstraintSchema]),
});

// Signature requirement constraint
export const SignedNilSchema = Data.Object({
  SignedNil: Data.Tuple([Data.Bytes({ minLength: 28, maxLength: 28 })]),
});

// Redeemer constraint schema
export const RedeemerValSchema = Data.Object({
  RedeemerVal: Data.Tuple([
    ScriptPurposeSchema,
    Data.Array(Data.Integer({ minimum: 0 })),
    OptionSchema(Data.Any()),
  ]),
});

export const InputConstraintSchema = Data.Object({
  address: OptionsSchema(
    AddressSchema, // Address option
    CredentialSchema, // Credential option
  ),
  value: Data.Array(
    // List maps to Array in TypeScript
    Data.Tuple([
      Data.Bytes({ minLength: 28, maxLength: 28 }), // PolicyId
      AssetSchema, // AssetName
      Data.Integer({ minimum: 1 }), // Int
    ]),
  ),
  datum_field: Data.Array(Data.Integer({ minimum: 0 })), // List of integers
  in_ref: OptionSchema(OutputRefSchema), // Optional OutputReference
});

// Reference input constraint
export const RefConValSchema = Data.Object({
  RefConVal: Data.Tuple([InputConstraintSchema]),
});

// Regular input constraint
export const InpConValSchema = Data.Object({
  InpConVal: Data.Tuple([InputConstraintSchema]),
});

// Minting constraint schema
export const MintConNilSchema = Data.Object({
  MintConNil: Data.Tuple([
    Data.Bytes({ minLength: 28, maxLength: 28 }),
    AssetSchema,
    Data.Integer({ minimum: 1 }),
  ]),
});

// Time validity constraint - after
export const AfterValSchema = Data.Object({
  AfterVal: Data.Tuple([Data.Integer()]),
});

// Time validity constraint - before
export const BeforeValSchema = Data.Object({
  BeforeVal: Data.Tuple([Data.Integer()]),
});

// Combined constraint schema supporting all constraint types
export const ConstraintSchema = Data.Enum([
  OutConNilSchema,
  SignedNilSchema,
  RedeemerValSchema,
  RefConValSchema,
  InpConValSchema,
  MintConNilSchema,
  AfterValSchema,
  BeforeValSchema,
]);

// Schema for transaction intent
export const IntentSchema = Data.Object({
  constraints: Data.Array(ConstraintSchema),
  valueLeaving: Data.Tuple([
    Data.Integer({ minimum: 0 }),
    Data.Map(Data.Bytes({ minLength: 28, maxLength: 28 }), OutputAssetMap),
  ]),
  nonce: NonceSchema,
});

export type IntentType = Data.Static<typeof IntentSchema>;

export const IntentType = IntentSchema as unknown as IntentType;

// Schema for signed intent including signatures
export const SignedIntentSchema = Data.Object({
  userStake: Data.Bytes({ minLength: 28, maxLength: 28 }),
  intent: IntentSchema,
  prefix: Data.Bytes(),
  postfix: Data.Bytes(),
  signatures: Data.Array(Data.Bytes({ minLength: 64, maxLength: 64 })),
});

// Empty redeemer schema for intentions
export const IntentionRedeemerSchema = Data.Object({
  intentions: Data.Array(SignedIntentSchema),
  intentionGroups: Data.Array(Data.Bytes()),
  changeOutput: Data.Integer({ minimum: 0 }),
  constraintOutput: Data.Integer({ minimum: 0 }),
  constraintRedeemer: Data.Integer({ minimum: 0 }),
});

// Type for intention redeemer
export type IntentionRedeemerType = Data.Static<typeof IntentionRedeemerSchema>;

// Export intention redeemer type
export const IntentionRedeemerType =
  IntentionRedeemerSchema as unknown as IntentionRedeemerType;

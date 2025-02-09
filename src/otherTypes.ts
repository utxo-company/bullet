import { Data, TSchema } from "@lucid-evolution/lucid";

export const VerificationKeySchema = Data.Object({
  VerificationKey: Data.Tuple([Data.Bytes({ minLength: 28, maxLength: 28 })]),
});

export const ScriptSchema = Data.Object({
  Script: Data.Tuple([Data.Bytes({ minLength: 28, maxLength: 28 })]),
});

export const CredentialSchema = Data.Enum([
  VerificationKeySchema,
  ScriptSchema,
]);

export const OutputRefSchema = Data.Object({
  txId: Data.Bytes({ minLength: 32, maxLength: 32 }),
  outputIndex: Data.Integer({ minimum: 0 }),
});

export type OutputRefType = Data.Static<typeof OutputRefSchema>;
export const OutputRefType = OutputRefSchema as unknown as OutputRefType;

// pub type ScriptPurpose {
//   /// For scripts executed as minting/burning policies, to insert
//   /// or remove assets from circulation. It's parameterized by the identifier
//   /// of the associated policy.
//   Mint(PolicyId)
//   /// For scripts that are used as payment credentials for addresses in
//   /// transaction outputs. They govern the rule by which the output they
//   /// reference can be spent.
//   Spend(OutputReference)
//   /// For scripts that validate reward withdrawals from a reward account.
//   ///
//   /// The argument identifies the target reward account.
//   Withdraw(Credential)
//   /// Needed when delegating to a pool using stake credentials defined as a
//   /// custom script. This purpose is also triggered when de-registering such
//   /// stake credentials.
//   ///
//   /// The Int is a 0-based index of the given `Certificate` in `certificates`.
//   Publish { at: Index, certificate: Certificate }
//   /// Voting for a type of voter using a governance action id to vote
//   /// yes / no / abstain inside a transaction.
//   ///
//   /// The voter is who is doing the governance action.
//   Vote(Voter)
//   /// Used to propose a governance action.
//   ///
//   /// A 0-based index of the given `ProposalProcedure` in `proposal_procedures`.
//   Propose { at: Index, proposal_procedure: ProposalProcedure }
// }

export const MintSchema = Data.Object({
  Mint: Data.Tuple([Data.Bytes({ minLength: 28, maxLength: 28 })]),
});

export const SpendSchema = Data.Object({
  Spend: Data.Tuple([OutputRefSchema]),
});

export const WithdrawSchema = Data.Object({
  Withdraw: Data.Tuple([CredentialSchema]),
});

export const ScriptPurposeSchema = Data.Enum([
  MintSchema,
  SpendSchema,
  WithdrawSchema,
]);

export const OptionSchema = <T1 extends TSchema>(schema: T1) =>
  Data.Enum([
    Data.Object({
      Some: Data.Tuple([schema]),
    }),
    Data.Literal("Nope"),
  ]);

export const OptionsSchema = <T1 extends TSchema, T2 extends TSchema>(
  schema1: T1,
  schema2: T2,
) =>
  Data.Enum([
    Data.Object({
      SomeOne: Data.Tuple([schema1]),
    }),
    Data.Object({
      SomeTwo: Data.Tuple([schema2]),
    }),
    Data.Literal("Nada"),
  ]);

export const AddressSchema = Data.Object({
  paymentCredential: CredentialSchema,
  stakeCredential: OptionSchema(Data.Object({ inline: CredentialSchema })),
});

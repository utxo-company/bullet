import { Data } from "@lucid-evolution/lucid";

export const BulletRedeemerSchema = Data.Object({});

export type BulletRedeemerType = Data.Static<typeof BulletRedeemerSchema>;
export const BulletRedeemerType =
  BulletRedeemerSchema as unknown as BulletRedeemerType;

export const SecpSchema = Data.Object({
  Secp: Data.Tuple([Data.Bytes({ minLength: 33, maxLength: 33 })]),
});

export const SchnorrSchema = Data.Object({
  Schnorr: Data.Tuple([Data.Bytes({ minLength: 32, maxLength: 32 })]),
});

export const VkSchema = Data.Enum([SecpSchema, SchnorrSchema]);

export const VerificationSchema = Data.Object({
  Verification: Data.Tuple([
    Data.Map(
      Data.Bytes({ minLength: 28, maxLength: 28 }),
      Data.Bytes({ minLength: 32, maxLength: 32 }),
    ),
  ]),
});

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

export const WithdrawalSchema = Data.Object({
  Withdrawal: Data.Tuple([CredentialSchema]),
});

export const BulletCredentialSchema = Data.Enum([
  VerificationSchema,
  WithdrawalSchema,
]);

export const ControlSchema = Data.Object({
  Control: Data.Object({
    quorum: Data.Integer(),
    hotCred: Data.Array(VkSchema),
    hotCredHash: BulletCredentialSchema,
    coldCred: Data.Array(VkSchema),
    coldCredHash: BulletCredentialSchema,
  }),
});

export const ParallelNonceSchema = Data.Literal("ParallelNonce");

export const VaultSchema = Data.Literal("Vault");

export const BulletUtxoStateSchema = Data.Enum([
  ControlSchema,
  ParallelNonceSchema,
  VaultSchema,
]);

export type BulletDatumType = Data.Static<typeof BulletUtxoStateSchema>;

export const BulletDatumType =
  BulletUtxoStateSchema as unknown as BulletDatumType;

export const SetupSchema = Data.Literal("Setup");

export const SignedSchema = Data.Literal("Signed");

export const StakeBulletRedeemerSchema = Data.Enum([SetupSchema, SignedSchema]);

export type StakeBulletRedeemerType = Data.Static<
  typeof StakeBulletRedeemerSchema
>;

export const StakeBulletRedeemerType =
  StakeBulletRedeemerSchema as unknown as StakeBulletRedeemerType;

export const ProxyStateSchema = Data.Object({
  hotAuthContract: CredentialSchema,
  intentAuthContract: CredentialSchema,
  walletAuthContract: CredentialSchema,
  coldAuthContract: CredentialSchema,
  changeAuthContract: CredentialSchema,
  deleteAuthContract: CredentialSchema,
});

export type ProxyStateType = Data.Static<typeof ProxyStateSchema>;

export const ProxyStateType = ProxyStateSchema as unknown as ProxyStateType;

export const ProxyRedeemerSchema = Data.Enum([
  Data.Literal("HotCred"),
  Data.Literal("Intention"),
  Data.Literal("VaultSpend"),
  Data.Literal("ColdCred"),
  Data.Literal("ColdControl"),
  Data.Literal("Delete"),
]);

export type ProxyRedeemerType = Data.Static<typeof ProxyRedeemerSchema>;

export const ProxyRedeemerType =
  ProxyRedeemerSchema as unknown as ProxyRedeemerType;

export const SigsDatumSchema = Data.Tuple([
  Data.Array(Data.Bytes({ minLength: 64, maxLength: 64 })),
  Data.Array(Data.Bytes({ minLength: 64, maxLength: 64 })),
]);

export type SigsDatumType = Data.Static<typeof SigsDatumSchema>;

export const SigsDatumType = SigsDatumSchema as unknown as SigsDatumType;

export const HotAccountSpendSchema = Data.Object({
  user_stake: Data.Bytes({ minLength: 28, maxLength: 28 }),
  sigs: Data.Array(Data.Bytes({ minLength: 64, maxLength: 64 })),
});

export type HotAccountSpendType = Data.Static<typeof HotAccountSpendSchema>;

export const HotAccountSpendType =
  HotAccountSpendSchema as unknown as HotAccountSpendType;

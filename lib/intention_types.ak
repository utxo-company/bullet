use aiken/crypto.{ScriptHash, Signature, VerificationKeyHash}
use cardano/address.{Address, Credential}
use cardano/assets.{AssetName, Lovelace, PolicyId}
use cardano/transaction.{OutputReference, ScriptPurpose}

pub type Options<a, b> {
  SomeOne(a)
  SomeTwo(b)
  Nada
}

pub type Natural =
  Int

pub type OutputAssetMap =
  Pairs<AssetName, Natural>

// The amazing type to handle intention values a little faster
pub type LaceAndValue<a> =
  fn(fn(Lovelace, Pairs<Data<PolicyId>, Data<OutputAssetMap>>) -> a) -> a

pub type InputConstraint {
  address: Data<Options<Address, Credential>>,
  value: Data<List<(PolicyId, AssetName, Int)>>,
  datum_field: Data<List<Int>>,
  in_ref: Data<Option<OutputReference>>,
}

pub type OutputConstraint {
  address: Data<Options<Address, Credential>>,
  value: Data<
    Options<Pairs<ByteArray, Pairs<ByteArray, Int>>, (PolicyId, AssetName)>,
  >,
  datum: Data<Options<Data, (ByteArray, ByteArray)>>,
  // Technically should be Option<Option<ScriptHash>>, but I can't think of
  // a realistic reason to match on None
  // There isn't an attack vector for injecting scripts in outputs other than
  // giving more money to the address
  ref: Data<Option<ScriptHash>>,
}

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

pub type IntentNonce {
  Sequential(Int)
  Parallel(OutputReference)
}

pub type Intent {
  constraints: Data<List<Constraint>>,
  value_leaving: (Lovelace, Data<Pair<PolicyId, OutputAssetMap>>),
  nonce: IntentNonce,
}

pub type SignedIntention {
  user_stake: ScriptHash,
  intent: Intent,
  prefix: ByteArray,
  postfix: ByteArray,
  signatures: Data<List<Signature>>,
}

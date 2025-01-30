use aiken/collection.{Index}
// Same types without the Data interweaved through them simply
// to help generate better plutus.json for offchain blueprint libs
use aiken/crypto.{ScriptHash, Signature, VerificationKey, VerificationKeyHash}
use cardano/address.{Address, Credential}
use cardano/assets.{AssetName, Lovelace, PolicyId}
use cardano/certificate.{Certificate}
use cardano/governance.{Voter}
use cardano/transaction.{OutputReference}
use intention_types.{Options, OutputAssetMap}

pub type ScriptPurposeT {
  /// For scripts executed as minting/burning policies, to insert
  /// or remove assets from circulation. It's parameterized by the identifier
  /// of the associated policy.
  Mint(PolicyId)
  /// For scripts that are used as payment credentials for addresses in
  /// transaction outputs. They govern the rule by which the output they
  /// reference can be spent.
  Spend(OutputReference)
  /// For scripts that validate reward withdrawals from a reward account.
  ///
  /// The argument identifies the target reward account.
  Withdraw(Credential)
  /// Needed when delegating to a pool using stake credentials defined as a
  /// custom script. This purpose is also triggered when de-registering such
  /// stake credentials.
  ///
  /// The Int is a 0-based index of the given `Certificate` in `certificates`.
  Publish { at: Index, certificate: Certificate }
  /// Voting for a type of voter using a governance action id to vote
  /// yes / no / abstain inside a transaction.
  ///
  /// The voter is who is doing the governance action.
  Vote(Voter)
}

/// Used to propose a governance action.
///
pub type HotBulletCredentialT {
  Verification {
    edd25519_keys: Pairs<VerificationKeyHash, VerificationKey>,
    other_keys: List<VkT>,
    hot_quorum: Int,
    wallet_quorum: Int,
  }
  Withdrawal(Credential)
}

pub type ColdBulletCredentialT {
  ColdVerification(Pairs<VerificationKeyHash, VerificationKey>, List<VkT>)
  ColdWithdrawal(Credential)
}

// Optimization:
// Possibly switch from many Vk to single one
// since Schnorr supports k of m signatures anyway
pub type AccountStateT {
  hot_cred: HotBulletCredentialT,
  cold_cred: ColdBulletCredentialT,
}

pub type UtxoStatesT {
  Control { hot_cred: HotBulletCredentialT, cold_cred: ColdBulletCredentialT }
  ParallelNonce
  Vault
}

pub type NonceT =
  Int

pub type ProxyStateT {
  hot_auth_contract: Credential,
  intent_auth_contract: Credential,
  wallet_auth_contract: Credential,
  cold_auth_contract: Credential,
  change_auth_contract: Credential,
  delete_auth_contract: Credential,
}

pub type VkT {
  Schnorr(VerificationKey)
  Secp(VerificationKey)
}

pub type HotAccountSpendT {
  user_stake: ScriptHash,
  sigs: List<Signature>,
}

pub type HotAccountStakeT {
  user_stake: Credential,
  sigs: List<Signature>,
}

pub type AccountSpendT {
  user_stake: ScriptHash,
  sigs: List<Signature>,
  index: Int,
}

pub type LaceAndValueT<a> =
  fn(fn(Lovelace, Pairs<PolicyId, OutputAssetMap>) -> a) -> a

pub type InputConstraintT {
  address: Options<Address, Credential>,
  value: List<(PolicyId, AssetName, Int)>,
  datum_field: List<Int>,
  in_ref: Option<OutputReference>,
}

pub type OutputConstraintT {
  address: Options<Address, Credential>,
  value: Options<Pairs<PolicyId, Pairs<AssetName, Int>>, (PolicyId, AssetName)>,
  datum: Options<Data, (ByteArray, ByteArray)>,
  // Technically should be Option<Option<ScriptHash>>, but I can't think of
  // a realistic reason to match on None
  // There isn't an attack vector for injecting scripts in outputs other than
  // giving more money to the address
  ref: Option<ScriptHash>,
}

pub type ConstraintT {
  OutConNil(OutputConstraintT)
  SignedNil(VerificationKeyHash)
  RedeemerVal(ScriptPurposeT, List<Int>, Option<Data>)
  RefConVal(InputConstraintT)
  InpConVal(InputConstraintT)
  MintConNil(PolicyId, AssetName, Int)
  AfterVal(Int)
  BeforeVal(Int)
}

pub type IntentNonceT {
  Sequential(Int)
  Parallel(OutputReference)
}

pub type IntentT {
  constraints: List<ConstraintT>,
  value_leaving: (Lovelace, Pairs<PolicyId, OutputAssetMap>),
  nonce: IntentNonceT,
}

pub type SignedIntentionT {
  user_stake: ScriptHash,
  intent: IntentT,
  prefix: ByteArray,
  postfix: ByteArray,
  signatures: List<Signature>,
}

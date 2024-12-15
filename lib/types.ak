use aiken/crypto.{
  Blake2b_256, Hash, ScriptHash, Signature, VerificationKey, VerificationKeyHash,
}
use cardano/address.{Credential}

pub type MessageHash =
  Hash<Blake2b_256, ByteArray>

pub type StakeActions {
  Setup
  Signed
}

pub type ProxyAction {
  HotCred
  Intention
  VaultSpend
  ColdCred
  ColdControl
  Delete
}

pub type BulletCredential {
  Verification(Pairs<VerificationKeyHash, VerificationKey>)
  Withdrawal(Credential)
}

pub type AccountState {
  quorum: Int,
  hot_cred: List<Vk>,
  hot_cred_hash: BulletCredential,
  cold_cred: List<Vk>,
  cold_cred_hash: BulletCredential,
}

pub type UtxoStates {
  Control {
    quorum: Data<Int>,
    hot_cred: Data<List<Vk>>,
    hot_cred_hash: Data<BulletCredential>,
    cold_cred: Data<List<Vk>>,
    cold_cred_hash: Data<BulletCredential>,
  }
  ParallelNonce
  Vault
}

pub type Nonce {
  increment: Int,
  account_hash: ScriptHash,
}

pub type ProxyState {
  hot_auth_contract: Credential,
  intent_auth_contract: Credential,
  wallet_auth_contract: Credential,
  cold_auth_contract: Credential,
  change_auth_contract: Credential,
  delete_auth_contract: Credential,
}

pub type Vk {
  Secp(VerificationKey)
  Schnorr(VerificationKey)
}

pub type HotAccountSpend {
  user_stake: ScriptHash,
  sigs: List<Signature>,
}

pub type HotAccountStake {
  user_stake: Credential,
  sigs: List<Signature>,
}

pub type AccountSpend {
  user_stake: ScriptHash,
  sigs: List<Signature>,
  index: Data,
}

pub type ChangeCredentials {
  control_index: Int,
  user_stake: ScriptHash,
  cold_sigs: List<Signature>,
  new_hot_sigs: List<Signature>,
  new_cold_sigs: List<Signature>,
}

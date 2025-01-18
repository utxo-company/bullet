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

pub type HotBulletCredential {
  Verification {
    edd25519_keys: Data<Pairs<VerificationKeyHash, VerificationKey>>,
    other_keys: Data<List<Vk>>,
    hot_quorum: Data<Int>,
    wallet_quorum: Data<Int>,
  }
  Withdrawal(Data<Credential>)
}

pub type ColdBulletCredential {
  ColdVerification(
    Data<Pairs<VerificationKeyHash, VerificationKey>>,
    Data<List<Vk>>,
  )
  ColdWithdrawal(Data<Credential>)
}

// Optimization:
// Possibly switch from many Vk to single one
// since Schnorr supports k of m signatures anyway
pub type AccountState {
  hot_cred: HotBulletCredential,
  cold_cred: ColdBulletCredential,
}

pub type UtxoStates {
  Control {
    hot_cred: Data<HotBulletCredential>,
    cold_cred: Data<ColdBulletCredential>,
  }
  ParallelNonce
  Vault
}

pub type Nonce =
  Int

pub type ProxyState {
  hot_auth_contract: Credential,
  intent_auth_contract: Credential,
  wallet_auth_contract: Credential,
  cold_auth_contract: Credential,
  change_auth_contract: Credential,
  delete_auth_contract: Credential,
}

pub type Vk {
  Schnorr(VerificationKey)
  Secp(VerificationKey)
}

pub type HotAccountSpend {
  user_stake: ScriptHash,
  sigs: Data<List<Signature>>,
}

pub type HotAccountStake {
  user_stake: Credential,
  sigs: Data<List<Signature>>,
}

pub type AccountSpend {
  user_stake: ScriptHash,
  sigs: Data<List<Signature>>,
  index: Data<Int>,
}

pub type ChangeCredentials {
  control_index: Int,
  user_stake: ScriptHash,
  cold_sigs: List<Signature>,
  new_hot_sigs: List<Signature>,
  new_cold_sigs: List<Signature>,
  migration: Bool,
}

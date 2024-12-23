use aiken/crypto.{ScriptHash, Signature}
use cardano/address.{Address}
use cardano/assets.{AssetName, PolicyId}
use cardano/transaction.{OutputReference}

pub type InputConstraint {
  InAddr(Address)
  InVal(PolicyId, AssetName, Int)
  GetDatumField(List<Int>)
  InRef(OutputReference)
}

pub type OutputConstraint {
  OutAddr(Address)
  OutVal(PolicyId, AssetName, Int)
  OutDat(Data)
  OutDatContainsValue(ByteArray, ByteArray)
  OutRef(Option<ScriptHash>)
}

pub type Constraint {
  OutCon(Data<List<OutputConstraint>>)
  RefCon(Data<List<InputConstraint>>)
  InpCon(Data<List<InputConstraint>>)
  MintCon(PolicyId, AssetName, Int)
  After(Int)
  Before(Int)
}

pub type Nil {
  Nil
}

pub type IntentNonce {
  Sequential(Int)
  Parallel(OutputReference)
}

pub type Intent {
  constraints: Data<List<Constraint>>,
  value_leaving: List<(PolicyId, AssetName, Int)>,
  nonce: IntentNonce,
}

pub type SignedIntention {
  user_stake: ScriptHash,
  intent: Intent,
  prefix: ByteArray,
  postfix: ByteArray,
  signatures: Data<List<Signature>>,
}

// // Aggregate multiple user intentions 
// // User contention solved (user signs nonce and intentions)
// // Parallel intentions supported

// use aiken/builtin
// use aiken/crypto.{ScriptHash, Signature, blake2b_256}
// use cardano/address.{Address, Credential, Inline, Script}
// use cardano/assets.{AssetName, PolicyId}
// use cardano/certificate.{RegisterCredential}
// use cardano/script_context.{Publishing, ScriptContext, Withdrawing}
// use cardano/transaction.{Transaction}
// use config
// use types.{Control, Vk}
// use utils.{
//   check_tx_observed, check_valid_vk_sigs, dataify, filter_hot_inputs,
//   ref_control_datum,
// }

// type Constraint {
//   Constraint
// }

// type Intent {
//   constraints: List<Constraint>,
//   value_leaving: List<(PolicyId, AssetName, Int)>,
// }

// type Intention {
//   prefix: ByteArray,
//   intent: Intent,
//   postfix: ByteArray,
//   signatures: List<Signature>,
// }

// type CredentialRefOrder =
//   List<Pair<Credential, List<Int>>>

// type Red {
//   red: List<Intention>,
//   red2: CredentialRefOrder,
// }

// /// Action to spend from your vault using a quorum of hot keys
// validator hot_spend {
//   else(sc: ScriptContext) {
//     let ScriptContext { transaction: tx, info, redeemer } = sc

//     when info is {
//       Withdrawing(_) -> {
//         let Transaction {
//           inputs,
//           reference_inputs,
//           outputs,
//           withdrawals,
//           extra_signatories,
//           ..
//         } = tx

//         expect red: Red = redeemer
//         todo
//       }
//       Publishing(_, RegisterCredential { .. }) -> True
//       _ -> fail
//     }
//   }
// }

// validator hot_spend_types {
//   withdraw(
//     _signatures: (ScriptHash, List<Signature>),
//     _account: Credential,
//     _tx: Transaction,
//   ) {
//     fail
//   }

//   else(_) {
//     fail
//   }
// }

// Aggregate multiple user intentions 
// User contention solved (user signs nonce and intentions)
// Parallel intentions supported

use aiken/builtin
use aiken/collection/list.{all}
use aiken/crypto.{ScriptHash, Signature, blake2b_256}
use cardano/address.{Address, Credential, Inline, Script}
use cardano/assets.{AssetName, PolicyId}
use cardano/certificate.{RegisterCredential}
use cardano/script_context.{Publishing, ScriptContext, Withdrawing}
use cardano/transaction.{Input, Output, OutputReference, Transaction}
use config
use types.{Control, Vk}
use utils.{
  check_tx_observed, check_valid_vk_sigs, dataify, filter_hot_inputs,
  ref_control_datum,
}

type Constraint {
  Constraint
}

type IntentNonce {
  Sequential(Int)
  Parallel(OutputReference)
}

type Intent {
  constraints: List<Constraint>,
  value_leaving: List<(PolicyId, AssetName, Int)>,
  nonce: IntentNonce,
}

type SignedIntention {
  prefix: ByteArray,
  intent: Intent,
  postfix: ByteArray,
  signatures: List<Signature>,
}

type RefCredentialOrder =
  Pairs<ScriptHash, Int>

type Red {
  red: List<SignedIntention>,
  red2: RefCredentialOrder,
}

/// > [!IMPORTANT]
/// > Withdrawals are ordered by ascending [Credential](./credential.html#Credential). Yet, note that [`Script`](./credential.html#Credential) credentials are treated as **lower values** than [`VerificationKey`](./credential.html#Credential) credentials.
/// > [!IMPORTANT]
/// > Redeemers are ordered by ascending [ScriptPurpose](./transaction.html#ScriptPurpose).
/// > [!IMPORTANT]
/// > Votes are ordered by ascending [Voter](./governance.html#Voter) and [GovernanceActionId](./governance.html#GovernanceActionId).<br/>First constructor variants in a type are treated as lower indices; except for [Credential](./credential.html#Credential) where [`Script`](./credential.html#Credential) credentials are treated as **lower values** than [`VerificationKey`](./credential.html#Credential) credentials.
fn fold_over_ref_creds(
  ref_creds: Pairs<Credential, Int>,
  intentions: List<SignedIntention>,
  reference_inputs: List<Input>,
  inputs: List<Input>,
  // We offset to outputs related to change and nonces
  // The earlier outputs would be related to other dApps or intents
  offset_outputs: List<Output>,
  constraint_validator,
) {
  when ref_creds is {
    [] -> True
    [Pair(user_stake, additional_intents), ..rest] -> {
      let expected_nft = [Pair(config.bullet_hash, [Pair(user_stake, 1)])]

      expect Control { quorum, hot_cred, hot_cred_hash, .. } =
        reference_inputs
          |> ref_control_datum(expected_nft)

      expect quorum: Int = quorum

      expect hot_cred_hash: List<Credential> = hot_cred_hash

      expect [
        SignedIntention {
          prefix,
          intent: Intent { constraints, value_leaving, nonce } as intent,
          postfix,
          signatures,
        },
        ..rest_intents
      ] = intentions

      expect constraints |> all(constraint_validator)

      if additional_intents == 0 {
        todo
      } else {
        todo
      }
    }
  }
}

/// Action to spend from your vault using a quorum of hot keys
validator intent_spend {
  else(sc: ScriptContext) {
    let ScriptContext { transaction: tx, info, redeemer } = sc

    when info is {
      Withdrawing(_) -> {
        let Transaction {
          inputs,
          reference_inputs,
          outputs,
          fee,
          mint,
          certificates,
          withdrawals,
          validity_range,
          extra_signatories,
          redeemers,
          datums,
          id,
          votes,
          proposal_procedures,
          ..
        } = tx

        let handle_constraint =
          fn(constraint) {
            // The magic of constraint logic here
            when constraint is {
              _ -> todo
            }
          }

        expect red: Red = redeemer
        todo
      }
      Publishing(_, RegisterCredential { .. }) -> True
      _ -> fail
    }
  }
}
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

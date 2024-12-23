// Aggregate multiple user intentions 
// User contention solved (user signs nonce and intentions)
// Parallel intentions supported

use aiken/builtin
use aiken/collection/list
use aiken/crypto.{
  Blake2b_256, Hash, ScriptHash, Signature, VerificationKey, VerificationKeyHash,
}
use aiken/primitive/bytearray
use cardano/address.{Address, Credential, Inline, Script}
use cardano/assets.{AssetName, PolicyId}
use cardano/certificate.{RegisterCredential}
use cardano/script_context.{Publishing, ScriptContext, Withdrawing}
use cardano/transaction.{
  InlineDatum, Input, Output, OutputReference, Transaction,
}
use config
use intention_types.{Before, Constraint, SignedIntention}
use intention_utils.{fold_intent_counts}
use types.{
  BulletCredential, Control, ParallelNonce, Vault, Verification, Vk, Withdrawal,
}
use utils.{
  check_tx_observed, check_valid_vk_sigs, dataify, must_have_key,
  ref_control_datum, skip_list_mega_fast,
}

type Red {
  intentions: Data<List<SignedIntention>>,
  intent_user_counts: Data<List<ByteArray>>,
  output_offset: Int,
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
          fn(constraint: Data, _temp_val: Data) {
            expect constraint: Constraint = constraint
            // The magic of constraint logic here
            when constraint is {
              Before(_before_time) -> todo
              _ -> todo
            }
          }

        let validate_signature =
          fn(
            quorum: Int,
            hot_cred: Data,
            vks: Pairs<VerificationKeyHash, VerificationKey>,
            sigs: List<Signature>,
            message: Hash<Blake2b_256, Data>,
          ) {
            if hot_cred == dataify([]) {
              (check_tx_observed(vks, extra_signatories) >= quorum)?
            } else {
              expect hot_cred: List<Vk> = hot_cred

              (check_tx_observed(vks, extra_signatories) + check_valid_vk_sigs(
                hot_cred,
                sigs,
                message,
              ) >= quorum)?
            }
          }

        expect Red { intentions, intent_user_counts, output_offset } = redeemer
        let folding_outputs = skip_list_mega_fast(outputs, output_offset)

        fold_intent_counts(
          intent_user_counts |> builtin.un_list_data,
          intentions |> builtin.un_list_data,
          reference_inputs,
          inputs,
          folding_outputs,
          withdrawals,
          validate_signature,
          handle_constraint,
        )
      }
      Publishing(_, RegisterCredential { .. }) -> True
      _ -> fail
    }
  }
}

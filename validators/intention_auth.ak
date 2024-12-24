// Aggregate multiple user intentions 
// User contention solved (user signs nonce and intentions)
// Parallel intentions supported

use aiken/builtin
use aiken/crypto.{
  Blake2b_256, Hash, Signature, VerificationKey, VerificationKeyHash,
}
use cardano/certificate.{RegisterCredential}
use cardano/script_context.{Publishing, ScriptContext, Withdrawing}
use cardano/transaction.{Transaction}
use intention_types.{
  After, Before, Constraint, InpCon, MintCon, OutCon, RefCon, SignedIntention,
}
use intention_utils.{fold_intent_counts}
use types.{Vk}
use utils.{
  check_quorum_valid_sigs, check_valid_edd_sigs, dataify, skip_list_mega_fast,
}

type Red {
  intentions: Data<List<SignedIntention>>,
  intent_user_counts: Data<List<ByteArray>>,
  output_offset: Int,
}

/// Action to hot spend via intent
validator intent_spend {
  else(sc: ScriptContext) {
    let ScriptContext { transaction: tx, info, redeemer } = sc

    when info is {
      Withdrawing(_) -> {
        let Transaction {
          inputs,
          reference_inputs,
          outputs,
          fee: _,
          mint: _,
          certificates: _,
          withdrawals,
          validity_range: _,
          extra_signatories: _,
          redeemers: _,
          datums: _,
          id: _,
          votes: _,
          proposal_procedures: _,
          ..
        } = tx

        // TODO: finish constraint validator
        let handle_constraint =
          fn(constraint: Data, _temp_val: Data) {
            expect constraint: Constraint = constraint
            // The magic of constraint logic here
            when constraint is {
              OutCon(out_constraints) -> todo
              RefCon(ref_constraints) -> todo
              InpCon(inp_constraints) -> todo
              MintCon(p, an, amount) -> todo
              After(time) -> todo
              Before(time) -> todo
            }
          }

        let validate_signature =
          fn(
            quorum: Int,
            hot_cred: Data,
            vks: Pairs<VerificationKeyHash, VerificationKey>,
          ) {
            fn(sigs: List<Signature>, message: Hash<Blake2b_256, Data>) {
              if hot_cred == dataify([]) {
                (check_valid_edd_sigs(vks, sigs, message) >= quorum)?
              } else {
                expect hot_cred: List<Vk> = hot_cred

                (check_quorum_valid_sigs(vks, hot_cred, sigs, message) >= quorum)?
              }
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

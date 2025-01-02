// Aggregate multiple user intentions 
// User contention solved (user signs nonce and intentions)
// Parallel intentions supported

use aiken/builtin
use aiken/crypto.{
  Blake2b_256, Hash, Signature, VerificationKey, VerificationKeyHash,
}
use aiken/interval.{Interval, IntervalBound}
use cardano/certificate.{RegisterCredential}
use cardano/script_context.{Publishing, ScriptContext, Withdrawing}
use cardano/transaction.{Transaction}
use intention_types.{
  AfterVal, BeforeVal, Constraint, InpConMaybeVal, MintConNil, OutConNil,
  RefConMaybeVal, SignedIntention,
}
use intention_utils.{fold_intent_counts, handle_out_constraint}
use types.{Vk}
use utils.{
  check_quorum_valid_sigs, check_valid_edd_sigs, dataify, quantity_of,
  skip_list_mega_fast,
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
          mint,
          certificates: _,
          withdrawals,
          validity_range: Interval {
            lower_bound: IntervalBound { bound_type: lower_bound_val, .. },
            upper_bound: IntervalBound { bound_type: upper_bound_val, .. },
          },
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
          fn(constraint: Data, temp_val: Data) {
            expect constraint: Constraint = constraint
            // The magic of constraint logic here
            when constraint is {
              OutConNil(out_constraints) ->
                handle_out_constraint(outputs, out_constraints, temp_val)
              RefConMaybeVal(_ref_constraints) -> todo
              InpConMaybeVal(_inp_constraints) -> todo
              MintConNil(p, an, amount) -> {
                expect ( mint |> quantity_of(p, an) ) == amount

                dataify(None)
              }
              AfterVal(time) -> {
                expect [lower, ..] =
                  lower_bound_val |> dataify |> builtin.unconstr_fields

                  expect time < builtin.un_i_data(lower)

                dataify(lower)
              }
              BeforeVal(time) -> {
                expect [upper, ..] =
                  upper_bound_val |> dataify |> builtin.unconstr_fields

                  expect time >= builtin.un_i_data(upper)

                dataify(upper)
              }
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

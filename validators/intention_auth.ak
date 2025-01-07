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
use cardano/transaction.{Redeemer, Transaction}
use constraint_utils.{handle_inp_constraint,
  handle_out_constraint, select_field}
use intention_types.{
  AfterVal, BeforeVal, Constraint, InpConVal, MintConNil, OutConNil, RedeemerVal,
  RefConVal, SignedIntention, SignedNil,
}
use intention_utils.{fold_intent_counts}
use types.{Vk}
use utils.{
  check_quorum_valid_sigs, check_valid_edd_sigs, dataify, must_find_key,
  must_have, quantity_of, skip_list_mega_fast,
}

type Red {
  intentions: Data<List<SignedIntention>>,
  intent_user_counts: Data<List<ByteArray>>,
  change_output_offset: Int,
  constraint_output_offset: Int,
  constraint_redeemer_offset: Int,
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
          extra_signatories,
          redeemers,
          datums: _,
          id: _,
          votes: _,
          proposal_procedures: _,
          ..
        } = tx

        expect Red {
          intentions,
          intent_user_counts,
          change_output_offset,
          constraint_output_offset,
          constraint_redeemer_offset,
        } = redeemer

        let constraint_outputs =
          skip_list_mega_fast(outputs, constraint_output_offset)

        let constraint_redeemers =
          skip_list_mega_fast(redeemers, constraint_redeemer_offset)

        // TODO: finish constraint validator
        let handle_constraint =
          fn(constraint: Data, temp_val: Data) {
            expect constraint: Constraint = constraint
            // The magic of constraint logic here
            when constraint is {
              OutConNil(out_constraints) ->
                handle_out_constraint(
                  constraint_outputs,
                  out_constraints,
                  temp_val,
                )
              SignedNil(signer) -> {
                expect must_have(extra_signatories, signer)

                dataify(None)
              }
              RedeemerVal(script_purpose, field_selection) -> {
                let redeemer: Redeemer =
                  constraint_redeemers
                    |> dataify
                    |> builtin.un_map_data
                    |> must_find_key(script_purpose)

                field_selection
                  |> builtin.un_list_data
                  |> select_field(redeemer)
              }
              RefConVal(ref_constraints) ->
                handle_inp_constraint(reference_inputs, ref_constraints)
              InpConVal(inp_constraints) ->
                handle_inp_constraint(inputs, inp_constraints)
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
              MintConNil(p, an, amount) -> {
                expect ( mint |> quantity_of(p, an) ) == amount

                dataify(None)
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

        let folding_outputs = skip_list_mega_fast(outputs, change_output_offset)

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

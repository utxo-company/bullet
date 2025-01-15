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
use cardano/transaction.{Output, Redeemer, ScriptPurpose, Transaction}
use constraint_utils.{handle_inp_constraint,
  handle_out_constraint, select_field}
use intention_types.{
  AfterVal, BeforeVal, InpConVal, MintConNil, OutConNil, RedeemerVal, RefConVal,
  SignedIntention, SignedNil,
}
use intention_utils.{fold_intent_counts}
use macros.{SkipFuncPieces, list_skipper_macro_pieces}
use types.{Vk}
use utils.{
  check_quorum_valid_sigs, check_valid_edd_sigs, dataify, must_find_key,
  must_have, quantity_of,
}



const skip_outputs_8: SkipFuncPieces<Output, List<Output>> =
  list_skipper_macro_pieces(8)

const skip_redeemers_10: SkipFuncPieces<
    Pair<ScriptPurpose, Redeemer>,
    Pairs<ScriptPurpose, Redeemer>,
  > =
  list_skipper_macro_pieces(10)

const skip_redeemers = skip_redeemers_fn

fn skip_outputs(outputs: List<Output>, index: Int) -> List<Output> {
  let iterate_func, skip_func, skip_count <- skip_outputs_8

  if index >= skip_count {
    outputs |> skip_func |> skip_outputs(index - skip_count)
  } else {
    iterate_func(outputs, index)
  }
}

fn skip_redeemers_fn(
  redeemers: Pairs<ScriptPurpose, Redeemer>,
  index: Int,
) -> Pairs<ScriptPurpose, Redeemer> {
  let iterate_func, skip_func, skip_count <- skip_redeemers_10

  if index >= skip_count {
    redeemers |> skip_func |> skip_redeemers_fn(index - skip_count)
  } else {
    iterate_func(redeemers, index)
  }
}

fn expect_item(constr: Data) {
  expect [item, ..] = constr |> builtin.unconstr_fields
  item
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

        let constraint_outputs = skip_outputs(outputs, constraint_output_offset)

        let constraint_redeemers =
          skip_redeemers(redeemers, constraint_redeemer_offset)

        let handle_constraint =
          fn(constraint: Data, temp_val: Data) {
            let constraint_variant = builtin.unconstr_index(constraint)

            // pub type Constraint {
            //   OutConNil(Data<OutputConstraint>)
            //   SignedNil(VerificationKeyHash)
            //   RedeemerVal(Data<ScriptPurpose>, Data<List<Int>>)
            //   RefConVal(Data<InputConstraint>)
            //   InpConVal(Data<InputConstraint>)
            //   MintConNil(PolicyId, AssetName, Int)
            //   AfterVal(Int)
            //   BeforeVal(Int)
            // }
            // The magic of constraint logic here
            when constraint_variant is {
              0 -> {
                expect OutConNil(out_constraints) = constraint
                handle_out_constraint(
                  constraint_outputs,
                  out_constraints,
                  temp_val,
                )
              }
              1 -> {
                expect SignedNil(signer) = constraint
                expect must_have(extra_signatories, signer)
                dataify(None)
              }
              2 -> {
                expect RedeemerVal(script_purpose, field_selection, compare_val) =
                  constraint

                let redeemer: Redeemer =
                  constraint_redeemers
                    |> dataify
                    |> builtin.un_map_data
                    |> must_find_key(script_purpose)

                let field =
                  field_selection
                    |> builtin.un_list_data
                    |> select_field(redeemer)

                if compare_val == dataify(None) {
                  field
                } else {
                  expect Some(compare): Option<Data> = compare_val
                  expect field == compare
                  field
                }
              }

              3 -> {
                expect RefConVal(ref_constraints) = constraint
                handle_inp_constraint(reference_inputs, ref_constraints)
              }
              4 -> {
                expect InpConVal(inp_constraints) = constraint
                handle_inp_constraint(inputs, inp_constraints)
              }
              6 -> {
                expect AfterVal(time) = constraint
                let lower = expect_item(lower_bound_val)
                expect time < builtin.un_i_data(lower)
                dataify(lower)
              }
              7 -> {
                expect BeforeVal(time) = constraint
                let upper = expect_item(upper_bound_val)
                expect time >= builtin.un_i_data(upper)
                dataify(upper)
              }
              5 -> {
                expect MintConNil(p, an, amount) = constraint
                expect quantity_of(mint, p, an) == amount
                dataify(None)
              }
              _ -> fail @"Redeemer index out of range"
            }
          }

        let validate_signature =
          fn(
            quorum: Int,
            hot_cred: Data<List<Vk>>,
            vks: Pairs<VerificationKeyHash, VerificationKey>,
          ) {
            fn(sigs: List<Signature>, message: Hash<Blake2b_256, Data>) -> Bool {
              if hot_cred == dataify([]) {
                (check_valid_edd_sigs(vks, sigs, message) >= quorum)?
              } else {
                expect hot_cred: List<Vk> = hot_cred

                (check_quorum_valid_sigs(vks, hot_cred, sigs, message) >= quorum)?
              }
            }
          }

        let folding_outputs = skip_outputs(outputs, change_output_offset)

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

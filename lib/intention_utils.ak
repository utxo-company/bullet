use aiken/builtin
use aiken/collection/list
use aiken/crypto.{Signature}
use aiken/primitive/bytearray
use cardano/address.{Credential, Script}
use cardano/assets
use cardano/transaction.{InlineDatum, Input, Output}
use config
use intention_types.{
  Constraint, Intent, Nil, Parallel, Sequential, SignedIntention,
}
use types.{
  BulletCredential, Control, ParallelNonce, Vault, Verification, Withdrawal,
}
use utils.{must_have_key, ref_control_datum}

fn combine_values(_value_leaving_left, _value_leaving_right) {
  todo
}

fn fold_inputs(
  user_address,
  nonce_address,
  first_nonce,
  inputs,
  remaining_inputs,
  acc_value,
  parallel_nonce_list,
  callback,
) {
  when inputs is {
    [] -> {
      expect [] = parallel_nonce_list
      callback(acc_value, remaining_inputs)
    }
    [x, ..rest] -> {
      let Input {
        output_reference,
        output: Output { address, value, datum, .. },
      } = x

      if user_address == address {
        if InlineDatum(Vault) == datum {
          fail
        } else if InlineDatum(ParallelNonce) == datum {
          let new_value = acc_value |> assets.merge(value)

          let nonce_list = list.delete(parallel_nonce_list, output_reference)

          fold_inputs(
            user_address,
            nonce_address,
            first_nonce,
            rest,
            remaining_inputs,
            new_value,
            nonce_list,
            callback,
          )
        } else {
          let new_value = acc_value |> assets.merge(value)

          fold_inputs(
            user_address,
            nonce_address,
            first_nonce,
            rest,
            remaining_inputs,
            new_value,
            parallel_nonce_list,
            callback,
          )
        }
      } else if nonce_address == address {
        todo
      } else if or {
        address.payment_credential == Script(config.bullet_hash),
        address.payment_credential == Script(config.nonce_bullet_hash),
      } {
        fold_inputs(
          user_address,
          nonce_address,
          first_nonce,
          rest,
          [x, ..remaining_inputs],
          acc_value,
          parallel_nonce_list,
          callback,
        )
      } else {
        fold_inputs(
          user_address,
          nonce_address,
          first_nonce,
          rest,
          remaining_inputs,
          acc_value,
          parallel_nonce_list,
          callback,
        )
      }
    }
  }
}

fn fold_constraints(
  constraints: List<Data<Constraint>>,
  temp_val: Data,
  constraint_validator,
) -> Bool {
  expect [constraint, ..rest] = constraints

  let new_temp_val = constraint_validator(constraint, temp_val)

  when rest is {
    [] -> True
    _ -> fold_constraints(rest, new_temp_val, constraint_validator)
  }
}

/// Done
fn fold_intents_no_sigs(
  user_stake,
  constraint_validator,
  intents: List<Data<SignedIntention>>,
  remaining_intents: List<Data<SignedIntention>>,
  parallel_nonce_list,
  first_nonce,
  last_nonce,
  additional_intents,
  index,
  callback,
) {
  if index == 0 {
    expect [signed_intent, ..rest] = intents

    // deal with intent here
    expect SignedIntention {
      user_stake,
      intent: Intent { constraints, value_leaving, nonce },
      ..
    } = signed_intent

    expect
      (constraints
        |> builtin.un_list_data
        |> fold_constraints(Nil, constraint_validator))?

    // Deal with nonce
    let last_nonce, parallel_nonce_list <-
      fn(callback) {
        when nonce is {
          Sequential(i) -> {
            expect i > last_nonce
            callback(i, parallel_nonce_list)
          }
          Parallel(p) -> callback(last_nonce, [p, ..parallel_nonce_list])
        }
      }

    let first_nonce =
      if first_nonce == -1 {
        last_nonce
      } else {
        first_nonce
      }

    // continue with rest of intents
    let new_index = builtin.find_first_set_bit(additional_intents)
    let new_intents = builtin.shift_bytearray(additional_intents, -new_index)

    // No more intents to find so break loop
    if new_index == -1 {
      callback(
        first_nonce,
        last_nonce,
        parallel_nonce_list,
        value_leaving,
        remaining_intents,
      )
    } else {
      let
        first_nonce,
        last_nonce,
        parallel_nonce_list,
        total_value_leaving,
        remaining_intents,
      <-
        fold_intents_no_sigs(
          user_stake,
          constraint_validator,
          rest,
          remaining_intents,
          parallel_nonce_list,
          first_nonce,
          last_nonce,
          new_intents,
          new_index,
        )

      // combine value leaving
      let combined_value = combine_values(value_leaving, total_value_leaving)

      callback(
        first_nonce,
        last_nonce,
        parallel_nonce_list,
        combined_value,
        remaining_intents,
      )
    }
  } else {
    expect [temp_intent, ..rest] = intents

    let
      first_nonce,
      last_nonce,
      parallel_nonce_list,
      total_value_leaving,
      remaining_intents,
    <-
      fold_intents_no_sigs(
        user_stake,
        constraint_validator,
        rest,
        remaining_intents,
        parallel_nonce_list,
        first_nonce,
        last_nonce,
        additional_intents,
        index - 1,
      )

    callback(
      first_nonce,
      last_nonce,
      parallel_nonce_list,
      total_value_leaving,
      [temp_intent, ..remaining_intents],
    )
  }
}

pub fn fold_intent_counts(
  intent_counts: List<Data<ByteArray>>,
  intentions: List<Data<SignedIntention>>,
  reference_inputs: List<Input>,
  _inputs: List<Input>,
  // We offset to outputs related to change and nonces
  // The earlier outputs would be related to other dApps or intents
  _offset_outputs: List<Output>,
  withdrawals: Pairs<Credential, Int>,
  validate_signature,
  constraint_validator,
) -> Bool {
  when intent_counts is {
    [] -> True
    [additional_intents, ..] -> {
      expect [signed_intent, ..rest_intents] = intentions

      expect SignedIntention {
        prefix,
        user_stake,
        intent: Intent { constraints, value_leaving, nonce } as intent,
        postfix,
        signatures,
      } = signed_intent

      expect additional_intents: ByteArray = additional_intents

      let expected_nft = [Pair(config.bullet_hash, [Pair(user_stake, 1)])]

      expect Control { quorum, hot_cred, hot_cred_hash, .. } =
        reference_inputs
          |> ref_control_datum(expected_nft)

      expect quorum: Int = quorum

      expect hot_cred_hash: BulletCredential = hot_cred_hash

      expect
        (constraints
          |> builtin.un_list_data
          |> fold_constraints(Nil, constraint_validator))?

      let nonce_numb, parallel_nonce_list <-
        fn(callback) {
          when nonce is {
            Sequential(i) -> callback(i, [])
            Parallel(p) -> callback(-1, [p])
          }
        }

      let
        _first_nonce,
        _last_nonce,
        _parallel_nonce_list,
        _total_value_leaving,
        _remaining_intents,
      <-
        fn(callback) {
          when hot_cred_hash is {
            Withdrawal(sc) -> {
              expect must_have_key(withdrawals, sc)?

              if builtin.find_first_set_bit(additional_intents) == -1 {
                // Deal with only a single value leaving and nonce
                callback(
                  nonce_numb,
                  nonce_numb,
                  parallel_nonce_list,
                  value_leaving,
                  rest_intents,
                )
              } else {
                let index = builtin.find_first_set_bit(additional_intents)
                let additional_intents =
                  builtin.shift_bytearray(additional_intents, -index)

                // Recursive function to get the remaining value leaving and nonces
                fold_intents_no_sigs(
                  user_stake,
                  constraint_validator,
                  rest_intents,
                  [],
                  parallel_nonce_list,
                  nonce_numb,
                  nonce_numb,
                  additional_intents,
                  index,
                  callback,
                )
              }
            }
            Verification(vks) -> {
              let message =
                builtin.serialise_data(intent)
                  |> bytearray.concat(prefix, _)
                  |> bytearray.concat(postfix)
                  |> builtin.blake2b_256

              expect signatures: List<Signature> = signatures

              expect
                validate_signature(quorum, hot_cred, vks, signatures, message)

              if builtin.find_first_set_bit(additional_intents) == 0 {
                todo
              } else {
                todo
              }
            }
          }
        }

      todo
    }
  }
}

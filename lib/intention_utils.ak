use aiken/builtin
use aiken/cbor.{serialise}
use aiken/collection/dict.{to_pairs}
use aiken/collection/list
use aiken/crypto.{Signature}
use aiken/primitive/bytearray
use cardano/address.{Address, Credential, Script}
use cardano/assets.{Value, to_dict}
use cardano/transaction.{InlineDatum, Input, Output}
use config
use intention_types.{
  Constraint, Intent, Nada, Options, OutputConstraint, Parallel, Sequential,
  SignedIntention, SomeOne, SomeTwo,
}
use prefix.{nonce_prefix}
use types.{
  BulletCredential, Control, ParallelNonce, Vault, Verification, Withdrawal,
}
use utils.{dataify, must_have_key, ref_control_address_datum}

fn fast_combine_output_value(_left, _right) {
  todo
}

fn fast_combine_values(_left, _right) {
  todo
}

fn combine_value_leaving(_value_leaving_left, _value_leaving_right) {
  todo
}

fn fold_inputs(
  user_stake,
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
            user_stake,
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
            user_stake,
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
        expect [_, ..nft_value] = value |> to_dict |> to_pairs

        let expected_nft =
          [
            Pair(
              config.bullet_hash,
              [Pair(bytearray.concat(nonce_prefix, user_stake), 1)],
            ),
          ]

        expect dataify(expected_nft) == dataify(nft_value)

        expect datum == InlineDatum(first_nonce)

        fold_inputs(
          user_stake,
          user_address,
          nonce_address,
          first_nonce,
          rest,
          remaining_inputs,
          acc_value,
          parallel_nonce_list,
          callback,
        )
      } else if or {
        address.payment_credential == Script(config.bullet_hash),
        address.payment_credential == Script(config.nonce_bullet_hash),
      } {
        fold_inputs(
          user_stake,
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
          user_stake,
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

/// Done
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
        |> fold_constraints(None, constraint_validator))?

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
      let combined_value =
        combine_value_leaving(value_leaving, total_value_leaving)

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
  inputs: List<Input>,
  // We offset to outputs related to change and nonces
  // The earlier outputs would be related to other dApps or intents
  offset_outputs: List<Output>,
  withdrawals: Pairs<Credential, Int>,
  validate_signature,
  constraint_validator,
) -> Bool {
  when intent_counts is {
    [] -> intentions == [] && inputs == []
    [additional_intent_count, ..rest_count] -> {
      expect [signed_intent, ..rest_intents] = intentions

      expect SignedIntention {
        prefix,
        user_stake,
        intent: Intent { constraints, value_leaving, nonce } as intent,
        postfix,
        signatures,
      } = signed_intent

      expect additional_intents: ByteArray = additional_intent_count

      let expected_nft = [Pair(config.bullet_hash, [Pair(user_stake, 1)])]

      let (user_address, control_datum) =
        reference_inputs
          |> ref_control_address_datum(expected_nft)

      let nonce_address =
        Address(Script(config.nonce_bullet_hash), user_address.stake_credential)

      expect Control { quorum, hot_cred, hot_cred_hash, .. } = control_datum

      expect quorum: Int = quorum

      expect hot_cred_hash: BulletCredential = hot_cred_hash

      expect
        (constraints
          |> builtin.un_list_data
          |> fold_constraints(None, constraint_validator))?

      let nonce_numb, parallel_nonce_list <-
        fn(callback) {
          when nonce is {
            Sequential(i) -> callback(i, [])
            Parallel(p) -> callback(-1, [p])
          }
        }

      let
        first_nonce,
        last_nonce,
        parallel_nonce_list,
        total_value_leaving,
        remaining_intents,
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
              let validate_signature_post =
                validate_signature(quorum, hot_cred, vks)

              let message =
                builtin.serialise_data(intent)
                  |> bytearray.concat(prefix, _)
                  |> bytearray.concat(postfix)
                  |> builtin.blake2b_256

              expect signatures: List<Signature> = signatures

              expect validate_signature_post(signatures, message)

              if builtin.find_first_set_bit(additional_intents) == -1 {
                callback(
                  nonce_numb,
                  nonce_numb,
                  parallel_nonce_list,
                  value_leaving,
                  rest_intents,
                )
              } else {
                todo
              }
            }
          }
        }

      let
        acc_value,
        remaining_inputs,
      <-
        fold_inputs(
          user_stake,
          user_address,
          nonce_address,
          first_nonce,
          inputs,
          [],
          assets.zero,
          parallel_nonce_list,
        )

      // TODO fold outputs
      // Fold other intents
      fold_intent_counts(
        rest_count,
        remaining_intents,
        reference_inputs,
        remaining_inputs,
        offset_outputs,
        withdrawals,
        validate_signature,
        constraint_validator,
      )
    }
  }
}

fn check_val(_vals: List<Data>, _value: Value) {
  todo
}

pub fn handle_out_constraint(
  outputs: List<Output>,
  con: Data,
  temp_val: Data,
) -> Data {
  expect OutputConstraint { address, value, datum, ref } = con
  let runnable_val =
    if dataify([]) == value {
      fn(_output) { True }
    } else {
      fn(output: Output) {
        value |> builtin.un_list_data |> check_val(output.value)
      }
    }

  let runnable_datum =
    if dataify(Nada) == datum {
      runnable_val
    } else {
      expect datum_options: Options<Data, (ByteArray, ByteArray)> = datum

      when datum_options is {
        SomeOne(datum_check) ->
          fn(output: Output) {
            dataify(output.datum) == datum_check && runnable_val(output)
          }

        SomeTwo((pre_bytes, post_bytes)) -> {
          let datum_bytes_check =
            temp_val
              |> serialise
              |> bytearray.concat(pre_bytes, _)
              |> bytearray.concat(post_bytes)

          fn(output: Output) { serialise(output.datum) == datum_bytes_check }
        }

        Nada -> fail
      }
    }

  let runnable_ref =
    if ref == dataify(None) {
      runnable_datum
    } else {
      fn(output: Output) {
        ref == dataify(output.reference_script) && runnable_datum(output)
      }
    }

  let runnable =
    if address == dataify(Nada) {
      runnable_ref
    } else {
      expect address_options: Options<Data, Data> = address

      when address_options is {
        SomeOne(address) ->
          fn(output: Output) {
            dataify(output.address) == address && runnable_ref(output)
          }

        SomeTwo(pay_cred) ->
          fn(output: Output) {
            and {
              dataify(output.address.payment_credential) == pay_cred,
              runnable_ref(output),
            }
          }

        Nada -> fail
      }
    }

  apply_constraint_to_list(outputs, runnable)
}

fn apply_constraint_to_list(list: List<a>, runnable: fn(a) -> Bool) -> Data {
  expect [x, ..rest] = list

  if runnable(x) {
    dataify(None)
  } else {
    apply_constraint_to_list(rest, runnable)
  }
}

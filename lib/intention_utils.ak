use aiken/builtin
use aiken/cbor.{serialise}
use aiken/collection/dict.{to_pairs}
use aiken/collection/list
use aiken/crypto.{
  ScriptHash, Signature, VerificationKey, VerificationKeyHash, blake2b_256,
}
use aiken/primitive/bytearray.{concat}
use cardano/address.{Address, Credential, Inline, Script}
use cardano/assets.{AssetName, PolicyId, Value, to_dict}
use cardano/transaction.{InlineDatum, Input, Output, OutputReference}
use config
use intention_types.{Constraint, Intent, Parallel, Sequential, SignedIntention}
use prefix.{nonce_prefix}
use types.{
  BulletCredential, Control, ParallelNonce, Vault, Verification, Withdrawal,
}
use utils.{dataify, must_have_key, ref_control_datum}

pub fn fast_combine_output_value(_left, _right) {
  todo
}

pub fn fast_combine_values(_left, _right) {
  todo
}

fn combine_value_leaving(_value_leaving_left, _value_leaving_right) {
  todo
}

fn value_compare(
  _input_value: Value,
  _output_value: Value,
  _assets_gone: List<(PolicyId, AssetName, Int)>,
) {
  todo
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
  validate_signature: fn(Int, Data, Pairs<VerificationKeyHash, VerificationKey>) ->
    fn(List<Signature>, ByteArray) -> Bool,
  constraint_validator: fn(Data<Constraint>, Data) -> Data,
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

      let additional_intents = builtin.un_b_data(additional_intent_count)

      let expected_nft = [Pair(config.bullet_hash, [Pair(user_stake, 1)])]

      let address_stake_part = Some(Inline(Script(user_stake)))

      let user_address = Address(Script(config.bullet_hash), address_stake_part)

      let control_datum =
        reference_inputs
          |> ref_control_datum(expected_nft)

      let nonce_address =
        Address(Script(config.nonce_bullet_hash), address_stake_part)

      expect Control { quorum, hot_cred, hot_cred_hash, .. } = control_datum

      let quorum = builtin.un_i_data(quorum)

      // TODO: optimize
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
          let handle_more_intents =
            fn(sig_function) {
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
                fold_intents(
                  sig_function,
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

          when hot_cred_hash is {
            Withdrawal(sc) -> {
              // So you are probably wondering in what case do you use script withdraw
              // trick over simply providing a public key?
              // The answer is as Plutus versions progress and ZK folding schemes improve,
              // I can see a world where most accounts depend on a validator that runs a single ZK-STARK
              // or ZK-SNARK to validate each intention was signed by the owner of the respective account.
              // Basically a user would produce an intention plus a ZK-proof and the sequencer
              // would fold all the ZK-proofs into a single proof that checks all intentions that were
              // included in the tx were properly signed. All without revealing the users signing or verifying key.
              expect must_have_key(withdrawals, sc)?

              handle_more_intents(fn(_a, _b, _c, _d) { True })
            }
            Verification(vks) -> {
              let validate_signature_post =
                validate_signature(quorum, hot_cred, vks)

              let validate_signatures =
                fn(
                  prefix: ByteArray,
                  intent: Data,
                  postfix: ByteArray,
                  signatures: Data,
                ) {
                  expect signatures: List<Signature> = signatures

                  let message =
                    intent
                      |> serialise()
                      |> concat(prefix, _)
                      |> concat(postfix)
                      |> blake2b_256()

                  validate_signature_post(signatures, message)
                }

              expect validate_signatures(prefix, intent, postfix, signatures)

              handle_more_intents(validate_signatures)
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

      let offset_outputs =
        if last_nonce == -1 {
          offset_outputs
        } else {
          expect [output, ..rest_outputs] = offset_outputs
          expect
            validate_out_nonce(user_stake, nonce_address, last_nonce, output)
          rest_outputs
        }

      let
        output_value,
        remaining_outputs,
      <- fold_outputs(user_stake, user_address, offset_outputs, assets.zero)

      expect value_compare(output_value, acc_value, total_value_leaving)

      // Fold other intents
      fold_intent_counts(
        rest_count,
        remaining_intents,
        reference_inputs,
        remaining_inputs,
        remaining_outputs,
        withdrawals,
        validate_signature,
        constraint_validator,
      )
    }
  }
}

fn fold_inputs(
  user_stake: ScriptHash,
  user_address: Address,
  nonce_address: Address,
  first_nonce: Int,
  inputs: List<Input>,
  remaining_inputs: List<Input>,
  acc_value: Value,
  parallel_nonce_list: List<OutputReference>,
  callback: fn(Value, List<Input>) -> Bool,
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
          // TODO: also replace
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
          // TODO: Replace
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

fn fold_constraints(
  constraints: List<Data<Constraint>>,
  temp_val: Data,
  constraint_validator: fn(Data<Constraint>, Data) -> Data,
) -> Bool {
  expect [constraint, ..rest] = constraints

  let new_temp_val = constraint_validator(constraint, temp_val)

  when rest is {
    [] -> True
    _ -> fold_constraints(rest, new_temp_val, constraint_validator)
  }
}

fn fold_intents(
  validate_signatures: fn(ByteArray, Data, ByteArray, Data) -> Bool,
  // Side effect is fail for failed constraint
  constraint_validator: fn(Data<Constraint>, Data) -> Data,
  intents: List<Data<SignedIntention>>,
  remaining_intents: List<Data<SignedIntention>>,
  parallel_nonce_list: List<OutputReference>,
  first_nonce: Int,
  last_nonce: Int,
  additional_intents: ByteArray,
  index: Int,
  callback: fn(
    Int,
    Int,
    List<OutputReference>,
    List<(PolicyId, AssetName, Int)>,
    List<Data<SignedIntention>>,
  ) ->
    Bool,
) {
  if index == 0 {
    expect [signed_intent, ..rest] = intents

    // deal with intent here
    expect SignedIntention {
      prefix,
      intent: Intent { constraints, value_leaving, nonce } as intent,
      postfix,
      signatures,
      ..
    } = signed_intent

    expect
      (constraints
        |> builtin.un_list_data
        |> fold_constraints(None, constraint_validator))?

    expect validate_signatures(prefix, intent, postfix, signatures)

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
        fold_intents(
          validate_signatures,
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
      fold_intents(
        validate_signatures,
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

fn validate_out_nonce(
  user_stake: ScriptHash,
  nonce_address: Address,
  last_nonce: Int,
  output: Output,
) {
  let Output { address, value, datum, .. } = output

  expect [_, ..nft_value] = value |> to_dict |> to_pairs

  let expected_nft =
    [
      Pair(
        config.bullet_hash,
        [Pair(bytearray.concat(nonce_prefix, user_stake), 1)],
      ),
    ]

  and {
    dataify(expected_nft) == dataify(nft_value),
    datum == InlineDatum(last_nonce),
    nonce_address == address,
  }
}

fn fold_outputs(
  _user_stake: ScriptHash,
  _user_address: Address,
  _outputs: List<Output>,
  _acc_value: Value,
  _callback,
) {
  todo
}

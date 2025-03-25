use aiken/builtin
use aiken/cbor.{serialise}
use aiken/collection/dict.{to_pairs}
use aiken/collection/list
use aiken/crypto.{
  ScriptHash, Signature, VerificationKey, VerificationKeyHash, blake2b_256,
}
use aiken/primitive/bytearray.{concat}
use cardano/address.{Address, Credential, Inline, Script}
use cardano/assets.{Lovelace, PolicyId, to_dict}
use cardano/transaction.{InlineDatum, Input, NoDatum, Output, OutputReference}
use config
use intention_types.{
  Constraint, Intent, LaceAndValue, OutputAssetMap, Parallel, Sequential,
  SignedIntention,
}
use prefix.{nonce_prefix}
use types.{Control, ParallelNonce, Vault, Verification, Vk, Withdrawal}
use utils.{dataify, must_have_key, ref_control_datum}

pub fn default_lace_and_value(
  a: fn(Lovelace, Pairs<Data<PolicyId>, Data<OutputAssetMap>>) -> Bool,
) -> Bool {
  a(0, [])
}

/// Optimized for expecting the name values of policy and assets in one output
/// is less than or equal to the next output
///
/// Note this can only be used for output values since
/// it can only handle positive values greater than 0
/// if used improperly then == comparisons will fail!!!
///
/// Also note the first policy for the right must be >= to the last policy in the left
/// This also applies to the asset map as well
pub fn fast_combine_output_value(
  left: Pairs<Data<PolicyId>, Data<OutputAssetMap>>,
  right: Pairs<Data<PolicyId>, Data<OutputAssetMap>>,
) {
  when left is {
    [] -> right
    _ ->
      when right is {
        [] -> left
        [Pair(k, _) as p, ..rest] ->
          do_insert_right_output_val(
            left,
            builtin.un_b_data(k),
            p,
            rest,
            fn(left_asset, right_asset) {
              expect [Pair(right_key, _) as right_pair, ..ys] =
                right_asset |> builtin.un_map_data

              do_insert_right_output_val(
                builtin.un_map_data(left_asset),
                builtin.un_b_data(right_key),
                right_pair,
                ys,
                fn(left_int, right_int) {
                  dataify(
                    builtin.un_i_data(left_int) + builtin.un_i_data(right_int),
                  )
                },
              )
                |> dataify
            },
          )
      }
  }
}

fn do_insert_right_output_val(
  left: Pairs<Data, Data>,
  k: ByteArray,
  p: Pair<Data, Data>,
  rest: Pairs<Data, Data>,
  equals_func,
) -> Pairs<Data, Data> {
  expect [left_pair, ..xs] = left
  when xs is {
    [] -> {
      let Pair(left_key, _) = left_pair

      if builtin.un_b_data(left_key)
        |> builtin.less_than_bytearray(k) {
        [left_pair, p, ..rest]
      } else {
        [Pair(left_key, equals_func(left_pair.2nd, p.2nd)), ..rest]
      }
    }

    _ -> [left_pair, ..do_insert_right_output_val(xs, k, p, rest, equals_func)]
  }
}

/// Fast algorithm for adding on chain values found in inputs
///
/// Note this can only be used for input values since
/// it can only handle positive values greater than 0
/// if used improperly then == comparisons will fail!!!
pub fn fast_combine_natural_values(
  left: Pairs<Data<PolicyId>, Data<OutputAssetMap>>,
  right: Pairs<Data<PolicyId>, Data<OutputAssetMap>>,
) -> Pairs<Data<PolicyId>, Data<OutputAssetMap>> {
  when right is {
    [] -> left
    [Pair(k, _) as p, ..rest] ->
      do_insert_right(
        left,
        builtin.un_b_data(k),
        p,
        rest,
        fn(left_asset, right_asset) {
          expect [Pair(right_key, _) as right_pair, ..ys] =
            right_asset |> builtin.un_map_data

          do_insert_right(
            left_asset |> builtin.un_map_data,
            builtin.un_b_data(right_key),
            right_pair,
            ys,
            fn(left_int, right_int) {
              dataify(
                builtin.un_i_data(left_int) + builtin.un_i_data(right_int),
              )
            },
          )
            |> dataify
        },
      )
  }
}

fn do_insert_right(
  left: Pairs<Data, Data>,
  k: ByteArray,
  p: Pair<Data, Data>,
  rest: Pairs<Data, Data>,
  equals_func,
) -> Pairs<Data, Data> {
  let next =
    fn(left_in) {
      when rest is {
        [] -> left_in
        [Pair(right_key, _) as right_pair, ..rest] ->
          do_insert_right(
            left_in,
            builtin.un_b_data(right_key),
            right_pair,
            rest,
            equals_func,
          )
      }
    }

  when left is {
    [] -> [p, ..rest]
    [Pair(left_key, _) as left_pair, ..xs] ->
      if builtin.un_b_data(left_key)
        |> builtin.less_than_bytearray(k) {
        [left_pair, ..do_insert_right(xs, k, p, rest, equals_func)]
      } else if left_key == dataify(k) {
        [Pair(left_key, equals_func(left_pair.2nd, p.2nd)), ..next(xs)]
      } else {
        [p, ..next(left)]
      }
  }
}

fn value_compare(
  input_value: LaceAndValue<Bool>,
) -> fn(LaceAndValue<Bool>, LaceAndValue<Bool>) -> Bool {
  fn(output_value: LaceAndValue<Bool>, assets_gone: LaceAndValue<Bool>) -> Bool {
    let input_lace, input_val <- input_value
    let output_lace, output_val <- output_value
    let leaving_lace, leaving_val <- assets_gone

    and {
      input_lace <= output_lace + leaving_lace,
      // We use input_val as the anchor to ensure no funny business with outputs or value_leaving
      // What I mean is both output_value and value_leaving must be positive and ordered for it to match
      // inputs which are guaranteed to come in ordered
      input_val == fast_combine_natural_values(output_val, leaving_val),
    }
  }
}

fn sig_checker(
  hot_cred: Data,
  validate_signature: fn(
    Int,
    Data<List<Vk>>,
    Pairs<Data<VerificationKeyHash>, Data<VerificationKey>>,
  ) ->
    fn(List<Data<Signature>>, ByteArray) -> Bool,
  prefix,
  intent,
  postfix,
  signatures,
) {
  expect Verification { edd25519_keys, other_keys, hot_quorum, .. } = hot_cred

  let validate_signature_post =
    validate_signature(
      builtin.un_i_data(hot_quorum),
      other_keys,
      edd25519_keys |> builtin.un_map_data,
    )

  let validate_signatures =
    fn(prefix: ByteArray, intent: Data, postfix: ByteArray, signatures: Data) {
      let message =
        intent
          |> serialise()
          |> concat(prefix, _)
          |> concat(postfix)
          |> blake2b_256()

      validate_signature_post(signatures |> builtin.un_list_data, message)
    }

  expect validate_signatures(prefix, intent, postfix, signatures)

  validate_signatures
}

pub fn fold_intent_counts(
  intent_counts: List<Data<ByteArray>>,
  intentions: List<Data<SignedIntention>>,
  reference_inputs: List<Input>,
  inputs: List<Input>,
  // We offset to outputs related to change and nonces
  // The earlier outputs would be related to other dApps or intents
  offset_outputs: List<Output>,
  withdrawals: Pairs<Data<Credential>, Data<Int>>,
  validate_signature: fn(
    Int,
    Data<List<Vk>>,
    Pairs<Data<VerificationKeyHash>, Data<VerificationKey>>,
  ) ->
    fn(List<Data<Signature>>, ByteArray) -> Bool,
  // Constraint and temp value that can be used with certain constraints
  constraint_validator: fn(Data<Constraint>, Data) -> Data,
) -> Bool {
  when intent_counts is {
    // ensure we have exhausted intentions and inputs
    [] -> {
      expect [] = intentions
      expect [] = inputs
      True
    }

    [additional_intent_count, ..rest_count] -> {
      let additional_intents = builtin.un_b_data(additional_intent_count)

      // first part: pop off an intention and pull it apart
      expect [signed_intent, ..rest_intents] = intentions

      expect SignedIntention {
        prefix,
        intent: Intent { constraints, value_leaving, nonce, user_stake } as intent,
        postfix,
        signatures,
      } = signed_intent

      let nonce_numb: Int, parallel_nonce_list: List<Data<OutputReference>> <-
        fn(callback) {
          when nonce is {
            Sequential(i) -> callback(i, [])
            Parallel(p) -> callback(-1, [p])
          }
        }

      // use intention to generate expected data to match user inputs
      let expected_nft = [Pair(config.bullet_hash, [Pair(user_stake, 1)])]

      let address_stake_part = Some(Inline(Script(user_stake)))

      let user_address = Address(Script(config.bullet_hash), address_stake_part)

      let nonce_address =
        Address(Script(config.nonce_bullet_hash), address_stake_part)

      // second part: Pull out user credentials from reference input
      let control_datum =
        reference_inputs
          |> ref_control_datum(user_address, expected_nft)

      expect Control { hot_cred, .. } = control_datum

      // TODO: optimize
      // third part: validate user constraints for the popped off intention
      expect
        constraints
          |> builtin.un_list_data
          |> fold_constraints(None, constraint_validator)

      // Not worried about negative values since
      // this gets added to outputs instead of subtracted from inputs
      // so negative values only increase the value that the output would
      // need to match the input
      let (lace, val) = value_leaving

      let val = builtin.un_map_data(val)

      // fifth part: deal with remaining intents
      // Fold over one or more remaining intentions
      // for the same user. If tx builder tries to skip over
      // intentions then there will be either some that don't pass
      // the signature check for a different user stake
      // or some remaining in the final empty list check
      let
        first_nonce: Int,
        last_nonce: Int,
        parallel_nonce_list: List<Data<OutputReference>>,
        add_value_leaving: LaceAndValue<Bool>,
        remaining_intents: List<Data<SignedIntention>>,
      <-
        fn(callback) {
          let sig_function =
            if builtin.unconstr_index(hot_cred) == 0 {
              sig_checker(
                hot_cred,
                validate_signature,
                prefix,
                intent,
                postfix,
                signatures,
              )
            } else {
              expect Withdrawal(sc) = hot_cred
              // So you are probably wondering in what case do you use script withdraw
              // trick over simply providing a public key?
              // The answer is as Plutus versions progress and ZK folding schemes improve,
              // I can see a world where most accounts depend on a validator that runs a single ZK-STARK
              // or ZK-SNARK to validate each intention was signed by the owner of the respective account.
              // Basically a user would produce an intention plus a ZK-proof and the sequencer
              // would fold all the ZK-proofs into a single proof that checks all intentions that were
              // included in the tx were properly signed. All without revealing the users signing or verifying key.
              expect must_have_key(withdrawals, sc)

              fn(_a, _b, _c, _d) { True }
            }

          // Deal with only a single value leaving and nonce
          if builtin.find_first_set_bit(additional_intents) == -1 {
            callback(
              nonce_numb,
              nonce_numb,
              parallel_nonce_list,
              default_lace_and_value,
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

      let add_lace, add_val <- add_value_leaving

      let total_value_leaving =
        fn(a) { a(lace + add_lace, fast_combine_natural_values(add_val, val)) }

      // sixth part: fold over inputs. Validate the inputs that belong to user
      // and return the accumulated value for the user
      // and return the other bullet inputs belonging to other users
      let
        acc_inp_value: LaceAndValue<Bool>,
        remaining_inputs: List<Input>,
      <-
        fold_inputs(
          user_stake,
          user_address,
          nonce_address,
          first_nonce,
          inputs,
          [],
          default_lace_and_value,
          parallel_nonce_list,
        )

      // ensure input is first in value_compare
      let value_compare = value_compare(acc_inp_value)

      // seventh part: validate user sequential nonce if it was present in inputs
      let offset_outputs =
        if last_nonce == -1 {
          offset_outputs
        } else {
          // Validate OutputNonce for user if it was used
          expect [output, ..rest_outputs] = offset_outputs
          expect
            validate_out_nonce(user_stake, nonce_address, last_nonce, output)

          rest_outputs
        }

      // eighth part: find change outputs going to the user and combine the value
      // Note: We limit max change outputs per user to 5
      // return unrelated outputs for other users to validate on in the next loop
      let
        output_value: LaceAndValue<Bool>,
        remaining_outputs: List<Output>,
      <- fold_outputs(user_address, offset_outputs, 5)

      // ninth part: validate the value leaving + output value equals input value
      // from this user
      // output_value and total_value_leaving are added together
      expect value_compare(output_value, total_value_leaving)

      // tenth part: Now fold over other user intents
      // Thankfully there is enough Type safety
      // to ensure args are in correct order
      // reference_inputs, withdrawals, validate_signature, constraint_validator are static
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
  acc_value: LaceAndValue<Bool>,
  parallel_nonce_list: List<Data<OutputReference>>,
  callback: fn(LaceAndValue<Bool>, List<Input>) -> Bool,
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
        } else {
          let lace, acc_value <- acc_value

          expect [Pair(_, lovelace_map), ..rest_right] =
            value |> dataify |> builtin.un_map_data

          expect [Pair(_, inp_lace), ..] = lovelace_map |> builtin.un_map_data

          let new_lace = lace + builtin.un_i_data(inp_lace)

          let new_value = fast_combine_natural_values(acc_value, rest_right)

          let nonce_list =
            if InlineDatum(ParallelNonce) == datum {
              list.delete(parallel_nonce_list, dataify(output_reference))
            } else {
              parallel_nonce_list
            }

          fold_inputs(
            user_stake,
            user_address,
            nonce_address,
            first_nonce,
            rest,
            remaining_inputs,
            fn(a) { a(new_lace, new_value) },
            nonce_list,
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
      } else {
        let remaining_inputs =
          if address.payment_credential == Script(config.bullet_hash) {
            [x, ..remaining_inputs]
          } else if address.payment_credential == Script(
            config.nonce_bullet_hash,
          ) {
            [x, ..remaining_inputs]
          } else {
            remaining_inputs
          }

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
  when constraints is {
    [] -> True
    [constraint] -> {
      expect _: Data = constraint_validator(constraint, temp_val)
      True
    }
    [constraint, next] -> {
      let next_temp = constraint_validator(constraint, temp_val)
      expect _: Data = constraint_validator(next, next_temp)
      True
    }
    [constraint, next, next_next, ..rest] -> {
      let next_temp = constraint_validator(constraint, temp_val)
      let next_next_temp = constraint_validator(next, next_temp)
      let rest_temp: Data = constraint_validator(next_next, next_next_temp)
      fold_constraints(rest, rest_temp, constraint_validator)
    }
  }
}

fn fold_intents(
  validate_signatures: fn(ByteArray, Data, ByteArray, Data) -> Bool,
  // Side effect is fail for failed constraint
  constraint_validator: fn(Data<Constraint>, Data) -> Data,
  intents: List<Data<SignedIntention>>,
  remaining_intents: List<Data<SignedIntention>>,
  parallel_nonce_list: List<Data<OutputReference>>,
  first_nonce: Int,
  last_nonce: Int,
  additional_intents: ByteArray,
  index: Int,
  callback: fn(
    Int,
    Int,
    List<Data<OutputReference>>,
    LaceAndValue<Bool>,
    List<Data<SignedIntention>>,
  ) ->
    Bool,
) {
  if index == 0 {
    expect [signed_intent, ..rest] = intents

    // deal with intent here
    expect SignedIntention {
      prefix,
      intent: Intent { constraints, value_leaving, nonce, .. } as intent,
      postfix,
      signatures,
    } = signed_intent

    expect
      constraints
        |> builtin.un_list_data
        |> fold_constraints(None, constraint_validator)

    expect validate_signatures(prefix, intent, postfix, signatures)

    let (lace, val) = value_leaving

    let val = builtin.un_map_data(val)

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
        fn(a) { a(lace, val) },
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
      let total_lace, total_val <- total_value_leaving

      let new_lace = lace + total_lace
      let new_val = fast_combine_natural_values(total_val, val)

      callback(
        first_nonce,
        last_nonce,
        parallel_nonce_list,
        fn(a) { a(new_lace, new_val) },
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
    datum == InlineDatum(last_nonce + 1),
    nonce_address == address,
  }
}

fn fold_outputs(
  user_address: Address,
  outputs: List<Output>,
  output_count: Int,
  callback,
) {
  if output_count == 0 {
    callback(default_lace_and_value, outputs)
  } else {
    when outputs is {
      [] -> callback(default_lace_and_value, outputs)
      [output, ..rest] -> {
        let Output { address, value, datum, .. } = output
        if address == user_address {
          expect datum == NoDatum

          let
            acc_value,
            remaining_outputs,
          <- fold_outputs(user_address, rest, output_count - 1)

          let lace, other_value <- acc_value

          expect [Pair(_, lovelace_map), ..rest_left] =
            value |> dataify |> builtin.un_map_data

          expect [Pair(_, inp_lace), ..] = lovelace_map |> builtin.un_map_data

          let new_value =
            if lace == 0 {
              fn(a) { a(builtin.un_i_data(inp_lace), rest_left) }
            } else {
              let new_lace = lace + builtin.un_i_data(inp_lace)

              let new_value = fast_combine_output_value(rest_left, other_value)

              fn(a) { a(new_lace, new_value) }
            }

          callback(new_value, remaining_outputs)
        } else {
          callback(default_lace_and_value, outputs)
        }
      }
    }
  }
}

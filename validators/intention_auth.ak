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
use types.{
  BulletCredential, Control, ParallelNonce, Vault, Verification, Vk, Withdrawal,
}
use utils.{
  check_tx_observed, check_valid_vk_sigs, dataify, must_have_key,
  ref_control_datum,
}

type InputConstraint {
  InAddr(Address)
  InVal(PolicyId, AssetName, Int)
  GetDatumField(List<Int>)
  InRef(OutputReference)
}

type OutputConstraint {
  OutAddr(Address)
  OutVal(PolicyId, AssetName, Int)
  OutDat(Data)
  OutDatContainsValue(ByteArray, ByteArray)
  OutRef(Option<ScriptHash>)
}

type Constraint {
  OutCon(Data<List<OutputConstraint>>)
  RefCon(Data<List<InputConstraint>>)
  InpCon(Data<List<InputConstraint>>)
  MintCon(PolicyId, AssetName, Int)
  After(Int)
  Before(Int)
}

type Nil {
  Nil
}

type IntentNonce {
  Sequential(Int)
  Parallel(OutputReference)
}

type Intent {
  constraints: Data<List<Constraint>>,
  value_leaving: List<(PolicyId, AssetName, Int)>,
  nonce: IntentNonce,
}

type SignedIntention {
  prefix: ByteArray,
  intent: Intent,
  postfix: ByteArray,
  signatures: Data<List<Signature>>,
}

type RefCredentialOrder =
  Pairs<ScriptHash, Int>

type Red {
  red: Data<List<SignedIntention>>,
  red2: Data<RefCredentialOrder>,
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

fn fold_intents(
  intents: List<Data<SignedIntention>>,
  remaining_intents: List<Data<SignedIntention>>,
  nonce_list,
  first_nonce,
  last_nonce,
  additional_intents,
  index,
  callback,
) {
  todo
}

/// > [!IMPORTANT]
/// > Withdrawals are ordered by ascending [Credential](./credential.html#Credential). Yet, note that [`Script`](./credential.html#Credential) credentials are treated as **lower values** than [`VerificationKey`](./credential.html#Credential) credentials.
/// > [!IMPORTANT]
/// > Redeemers are ordered by ascending [ScriptPurpose](./transaction.html#ScriptPurpose).
/// > [!IMPORTANT]
/// > Votes are ordered by ascending [Voter](./governance.html#Voter) and [GovernanceActionId](./governance.html#GovernanceActionId).<br/>First constructor variants in a type are treated as lower indices; except for [Credential](./credential.html#Credential) where [`Script`](./credential.html#Credential) credentials are treated as **lower values** than [`VerificationKey`](./credential.html#Credential) credentials.
fn fold_ref_creds(
  ref_creds: Pairs<Data<Credential>, Data<Int>>,
  intentions: List<Data<SignedIntention>>,
  reference_inputs: List<Input>,
  inputs: List<Input>,
  // We offset to outputs related to change and nonces
  // The earlier outputs would be related to other dApps or intents
  offset_outputs: List<Output>,
  withdrawals: Pairs<Credential, Int>,
  validate_signature,
  constraint_validator,
) {
  when ref_creds is {
    [] -> True
    [Pair(user_stake, additional_intents), ..rest] -> {
      expect user_stake: ScriptHash = user_stake
      expect additional_intents: ByteArray = additional_intents
      let expected_nft = [Pair(config.bullet_hash, [Pair(user_stake, 1)])]

      expect Control { quorum, hot_cred, hot_cred_hash, .. } =
        reference_inputs
          |> ref_control_datum(expected_nft)

      expect quorum: Int = quorum

      expect hot_cred_hash: BulletCredential = hot_cred_hash

      expect [signed_intent, ..rest_intents] = intentions

      expect SignedIntention {
        prefix,
        intent: Intent { constraints, value_leaving, nonce } as intent,
        postfix,
        signatures,
      } = signed_intent

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
                // Recursive function to get the remaining value leaving and nonces
                todo
              }
            }
            Verification(vks) -> {
              let message =
                builtin.serialise_data(intent)
                  |> bytearray.concat(prefix, _)
                  |> bytearray.concat(postfix)
                  |> builtin.blake2b_256

              expect
                validate_signature(quorum, vks, hot_cred, signatures, message)

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
          fn(constraint: Constraint, temp_val: Data) {
            // The magic of constraint logic here
            when constraint is {
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

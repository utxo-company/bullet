use aiken/builtin
use aiken/collection/dict.{to_pairs}
use aiken/collection/list.{any}
use aiken/crypto.{Signature, blake2b_256}
use aiken/primitive/bytearray.{concat}
use cardano/address.{Address, Credential, Inline, Script}
use cardano/assets.{to_dict}
use cardano/script_context.{
  Minting, Publishing, ScriptContext, Spending, Voting, Withdrawing,
}
use cardano/transaction.{
  InlineDatum, Output, OutputReference, Redeemer, ScriptPurpose, Transaction,
  Withdraw,
}
use config
use offchain_types.{UtxoStatesT}
use prefix.{nonce_prefix}
use types.{
  AccountState, ColdVerification, ColdWithdrawal, Nonce, Setup, StakeActions,
  Verification, Withdrawal,
}
use utils.{
  check_all_tx_observed_and_hashes, check_all_valid_vk_sigs, dataify,
  must_find_item, must_find_key, must_have_key,
}

// UserAccount =
// Address(Script("BULLET"), Some(Inline(Script("USER_SPECIFIC"))))

// UserAccount =
// Address(Script("BULLET"), Some(Inline(Script("TRUE_STAKE_KEY"))))

/// Used as an example of how an always true
/// stake key does not comprimise other user accounts
validator true_stake_bullet {
  else(_) {
    True
  }
}

fn check_for_stake_proxy(
  redeemers: Pairs<ScriptPurpose, Redeemer>,
  credential: Data,
) {
  let proxy_cred = Withdraw(Script(config.stake_proxy_hash))

  let redeemer = must_find_key(redeemers, proxy_cred)

  expect [cred, ..] = builtin.un_list_data(redeemer)

  cred == credential
}

/// Rely on proxy stake validator for all other validation besides setup
/// Handles user stake key actions including delegation, reward, and voting
validator stake_bullet {
  else(sc: ScriptContext) {
    let ScriptContext { transaction: tx, info, redeemer } = sc

    let cred, return_early <-
      fn(callback) {
        when info is {
          Withdrawing(cred) -> callback(dataify(cred), False)
          // The first seven certificates have the certificate credential as the first field
          //  RegisterCredential {
          //   credential: Credential, ..
          // }
          // UnregisterCredential {
          //   credential: Credential, ..
          // }
          // DelegateCredential { credential: Credential, .. }
          // RegisterAndDelegateCredential {
          //   credential: Credential, ..
          // }
          // RegisterDelegateRepresentative {
          //   delegate_representative: Credential, ..
          // }
          // UpdateDelegateRepresentative { delegate_representative: Credential }
          // UnregisterDelegateRepresentative {
          //   delegate_representative: Credential, ..
          // }
          Publishing { certificate, .. } -> {
            expect [cred, ..] = builtin.unconstr_fields(certificate)

            let index = builtin.unconstr_index(certificate)

            expect index < 7

            callback(cred, index == 0)
          }
          // pub type Voter {
          //   ConstitutionalCommitteeMember(Credential)
          //   DelegateRepresentative(Credential)
          //   StakePool(VerificationKeyHash)
          // }
          Voting(voter) -> {
            expect [cred, ..] = builtin.unconstr_fields(voter)

            expect builtin.unconstr_index(voter) < 2

            callback(cred, False)
          }
          _ -> fail
        }
      }

    or {
      return_early,
      {
        let Transaction {
          inputs,
          outputs,
          withdrawals,
          extra_signatories,
          redeemers,
          ..
        } = tx

        let extra_signatories = extra_signatories |> builtin.un_list_data

        let withdrawals =
          withdrawals
            |> builtin.un_map_data

        if redeemer == dataify(Setup) {
          // Check various things if the redeemer is Setup
          let one_shot_ref =
            config.new_user_tx_hash
              |> OutputReference(config.new_user_output_index)

          // We use blake2b_256 since secp256k1 message size is 32 bytes
          let one_shot_message =
            one_shot_ref
              |> builtin.serialise_data()
              |> concat(config.namespace, _)
              |> blake2b_256()

          expect Script(own_hash) as account = cred

          // The reason I store sigs in the next output is to simplify the redeemer
          // And this is only run once per user so impact is minimal
          expect [
            Output { address, value, datum: InlineDatum(datum), .. },
            Output {
              address: nonce_addr,
              value: nonce_value,
              datum: InlineDatum(nonce_datum),
              ..
            },
            Output { datum: InlineDatum(sig_datum), .. },
            ..
          ] = outputs

          let expected_address =
            Address(Script(config.bullet_hash), Some(Inline(account)))

          let expected_nonce_address =
            Address(Script(config.nonce_bullet_hash), Some(Inline(account)))

          let expected_value = [Pair(config.bullet_hash, [Pair(own_hash, 1)])]

          let expected_nonce_value =
            [
              Pair(
                config.bullet_hash,
                [Pair(bytearray.concat(nonce_prefix, own_hash), 1)],
              ),
            ]

          expect (hot_sigs, cold_sigs): (
            List<Data<Signature>>,
            List<Data<Signature>>,
          ) = sig_datum

          expect AccountState { hot_cred, cold_cred } = datum

          expect [_, ..rest] = value |> to_dict |> to_pairs

          expect [_, ..rest_nonce] = nonce_value |> to_dict |> to_pairs

          let check_hot =
            if builtin.unconstr_index(hot_cred) == 0 {
              expect Verification {
                edd25519_keys,
                other_keys,
                hot_quorum,
                wallet_quorum,
              } = hot_cred

              and {
                check_all_valid_vk_sigs(
                  other_keys |> builtin.un_list_data,
                  hot_sigs,
                  one_shot_message,
                )?,
                check_all_tx_observed_and_hashes(
                  edd25519_keys |> builtin.un_map_data,
                  extra_signatories,
                )?,
                (builtin.un_i_data(hot_quorum) >= 1)?,
                (builtin.un_i_data(wallet_quorum) >= 1)?,
              }
            } else {
              expect Withdrawal(sc) = hot_cred
              must_have_key(withdrawals, sc)?
            }

          let check_cold =
            if builtin.unconstr_index(cold_cred) == 0 {
              expect ColdVerification(edd25519_keys, other_keys) = cold_cred

              and {
                check_all_valid_vk_sigs(
                  other_keys |> builtin.un_list_data,
                  cold_sigs,
                  one_shot_message,
                )?,
                check_all_tx_observed_and_hashes(
                  edd25519_keys |> builtin.un_map_data,
                  extra_signatories |> dataify |> builtin.un_list_data,
                )?,
              }
            } else {
              expect ColdWithdrawal(sc) = cold_cred
              must_have_key(withdrawals, sc)?
            }

          and {
            // Can only run this action once.
            any(inputs, fn(input) { input.output_reference == one_shot_ref })?,
            // Check for account state is setup correctly
            (dataify(rest) == dataify(expected_value))?,
            (dataify(rest_nonce) == dataify(expected_nonce_value))?,
            (address == expected_address)?,
            (nonce_addr == expected_nonce_address)?,
            (dataify(1) == nonce_datum)?,
            check_hot,
            check_cold,
          }
        } else {
          check_for_stake_proxy(redeemers, cred)
        }
      },
    }
  }
}

validator stake_bullet_types {
  withdraw(_stake_action: StakeActions, _account, _tx) {
    fail
  }

  publish(_stake_action: StakeActions, _cert, _tx) {
    fail
  }

  vote(_stake_action: StakeActions, _vote, _tx) {
    fail
  }

  else(_) {
    fail
  }
}

fn check_for_proxy(
  withdrawals: Pairs<Credential, Int>,
  proxy_cred: Credential,
) -> Bool {
  expect [Pair(k, _), ..rest] = withdrawals

  or {
    proxy_cred == k,
    check_for_proxy(rest, proxy_cred),
  }
}

validator bullet {
  else(sc: ScriptContext) {
    let ScriptContext { transaction: tx, info, .. } = sc

    when info is {
      // Main usage of bullet to spend utxos in a user account
      Spending { .. } ->
        check_for_proxy(tx.withdrawals, Script(config.proxy_hash))
      // Used to create a new validators acount
      Minting(own_policy) -> {
        let Transaction { mint, redeemers, .. } = tx

        expect [Pair(name, quantity),
          Pair(nonce_name, nonce_quantity)] =
          mint
            |> to_dict
            |> to_pairs
            |> must_find_key(own_policy)
            |> to_pairs
        and {
          (nonce_name == bytearray.concat(nonce_prefix, name))?,
          or {
            quantity == -1 && nonce_quantity == -1,
            and {
              (quantity == 1 && nonce_quantity == 1)?,
              must_find_key(redeemers, Withdraw(Script(name))) == dataify(Setup),
            },
          },
        }
      }
      _ -> fail
    }
  }
}

validator bullet_types {
  spend(_d: Option<UtxoStatesT>, _r: Void, _o, _tx) {
    fail
  }

  mint(_r: Void, _o, _tx) {
    fail
  }

  else(_) {
    fail
  }
}

validator bullet_nonce {
  else(sc: ScriptContext) {
    let ScriptContext { transaction: tx, info, .. } = sc

    let Transaction { inputs, withdrawals, redeemers, .. } = tx

    when info is {
      Spending { datum, output } ->
        if datum == None {
          let input =
            must_find_item(inputs, fn(inp) { inp.output_reference == output })
          expect Some(Inline(cred)) = input.output.address.stake_credential
          check_for_stake_proxy(redeemers, cred)
        } else {
          check_for_proxy(withdrawals, Script(config.proxy_hash))
        }

      _ -> fail
    }
  }
}

/// Types for nonce bullet validator
validator bullet_nonce_types {
  spend(_d: Option<Nonce>, _r: Void, _o, _tx) {
    fail
  }

  else(_) {
    fail
  }
}

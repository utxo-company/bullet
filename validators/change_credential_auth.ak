use aiken/builtin
use aiken/collection/dict.{to_pairs}
use aiken/crypto.{blake2b_256}
use cardano/address.{Address, Credential, Inline, Script}
use cardano/assets.{to_dict}
use cardano/certificate.{RegisterCredential}
use cardano/script_context.{Publishing, ScriptContext, Withdrawing}
use cardano/transaction.{InlineDatum, Output, Transaction}
use config
use types.{
  AccountState, ChangeCredentials, ColdVerification, ColdWithdrawal, Control,
  Verification, Withdrawal,
}
use utils.{
  check_all_tx_observed_and_hashes, check_all_valid_vk_sigs, dataify,
  must_have_key, ref_control_datum, resolve_user_tx,
}

fn pop_to_index(list: List<a>, index: Int) -> List<a> {
  if index == 0 {
    list
  } else {
    pop_to_index(builtin.tail_list(list), index - 1)
  }
}

/// Changes owner credentials, allowing for rotating credentials
validator cold_control {
  else(sc: ScriptContext) {
    let ScriptContext { transaction: tx, info, redeemer } = sc

    when info is {
      Withdrawing(_) -> {
        let Transaction {
          inputs,
          outputs,
          fee,
          withdrawals,
          extra_signatories,
          ..
        } = tx

        let extra_signatories = extra_signatories |> builtin.un_list_data

        let withdrawals =
          withdrawals
            |> builtin.un_map_data

        expect ChangeCredentials {
          control_index,
          user_stake,
          cold_sigs,
          new_hot_sigs,
          new_cold_sigs,
          migration,
        } = redeemer

        let user_stake_cred = Some(Inline(Script(user_stake)))

        let expected_address =
          Address(Script(config.bullet_hash), user_stake_cred)

        let expected_nonce_address =
          Address(Script(config.nonce_bullet_hash), user_stake_cred)

        let
          inputs_spent,
          nonce_state,
        <-
          resolve_user_tx(
            user_stake,
            inputs,
            expected_address,
            expected_nonce_address,
            [],
            -1,
          )

        let expected_nft = [Pair(config.bullet_hash, [Pair(user_stake, 1)])]

        expect Control { cold_cred, .. } =
          inputs
            |> pop_to_index(control_index)
            |> ref_control_datum(expected_address, expected_nft)

        let message =
          (inputs_spent, outputs, fee)
            |> builtin.serialise_data()
            |> blake2b_256()

        expect [
          Output { address, value, datum: InlineDatum(datum), .. },
          ..nonce_output
        ] = outputs

        let expected_nft = [Pair(config.bullet_hash, [Pair(user_stake, 1)])]

        expect [_, ..nft_value] = value |> to_dict |> to_pairs

        expect AccountState { hot_cred, cold_cred: out_cold_cred } = datum

        let address_and_nonce_check =
          if migration {
            let expected_nonce_nft =
              [Pair(config.nonce_bullet_hash, [Pair(user_stake, 1)])]
            expect [
              Output { address: nonce_address, value: nonce_value, .. },
              ..
            ] = nonce_output

            expect [_, ..nonce_value] = nonce_value |> to_dict |> to_pairs

            and {
              user_stake_cred == address.stake_credential,
              nonce_address.stake_credential == user_stake_cred,
              dataify(nonce_value) == dataify(expected_nonce_nft),
            }?
          } else {
            and {
              address == expected_address,
              nonce_state == -1,
            }?
          }

        let check_new_hot =
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
                new_hot_sigs |> builtin.un_list_data,
                message,
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
                cold_sigs |> builtin.un_list_data,
                message,
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

        let check_new_cold =
          if builtin.unconstr_index(out_cold_cred) == 0 {
            expect ColdVerification(edd25519_keys, other_keys) = out_cold_cred

            and {
              check_all_valid_vk_sigs(
                other_keys |> builtin.un_list_data,
                new_cold_sigs |> builtin.un_list_data,
                message,
              )?,
              check_all_tx_observed_and_hashes(
                edd25519_keys |> builtin.un_map_data,
                extra_signatories |> dataify |> builtin.un_list_data,
              )?,
            }
          } else {
            expect ColdWithdrawal(sc) = out_cold_cred
            must_have_key(withdrawals, sc)?
          }

        and {
          (dataify(nft_value) == dataify(expected_nft))?,
          address_and_nonce_check,
          check_new_hot,
          check_cold,
          check_new_cold,
        }
      }

      Publishing(_, RegisterCredential { .. }) -> True
      _ -> fail
    }
  }
}

validator cold_control_types {
  withdraw(
    _signatures: ChangeCredentials,
    _account: Credential,
    _tx: Transaction,
  ) {
    fail
  }

  else(_) {
    fail
  }
}

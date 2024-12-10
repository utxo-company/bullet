use aiken/builtin
use aiken/crypto.{ScriptHash, Signature, blake2b_256}
use cardano/address.{Address, Credential, Inline, Script}
use cardano/certificate.{RegisterCredential}
use cardano/script_context.{Publishing, ScriptContext, Withdrawing}
use cardano/transaction.{InlineDatum, Output, Transaction}
use config
use types.{AccountSpend, Control, Nonce, Vk}
use utils.{
  check_all_tx_observed, check_all_valid_vk_sigs, dataify, ref_control_datum,
  resolve_user_tx, skip_list_mega,
}
use aiken/primitive/bytearray
use prefix.{nonce_prefix}
use cardano/assets.{to_dict}
use aiken/collection/dict.{to_pairs}

validator vault_spend {
  else(sc: ScriptContext) {
    let ScriptContext { transaction: tx, info, redeemer } = sc

    when info is {
      Withdrawing(_) -> {
        let Transaction {
          inputs,
          reference_inputs,
          outputs,
          withdrawals,
          extra_signatories,
          ..
        } = tx

        expect AccountSpend(user_stake, sigs, nonce_output) = redeemer

        let expected_nft = [Pair(config.bullet_hash, [Pair(user_stake, 1)])]

        expect Control { hot_cred, hot_cred_hash, .. } =
          reference_inputs
            |> ref_control_datum(expected_nft)

        expect hot_cred_hash: List<Credential> = hot_cred_hash

        let stake_key = Some(Inline(Script(user_stake)))

        let expected_address = Address(Script(config.bullet_hash), stake_key)

        let expected_nonce_address =
          Address(Script(config.nonce_bullet_hash), stake_key)

        let
          inputs_spent,
          nonce_state,
        <-
          resolve_user_tx(
            inputs,
            expected_address,
            expected_nonce_address,
            [],
            None,
          )

        let cred_check =
          if hot_cred == dataify([]) {
            check_all_tx_observed(hot_cred_hash, extra_signatories, withdrawals)
          } else {
            expect hot_cred: List<Vk> = hot_cred
            let message =
              (inputs_spent, outputs)
                |> builtin.serialise_data()
                |> blake2b_256()

            check_all_tx_observed(hot_cred_hash, extra_signatories, withdrawals) && check_all_valid_vk_sigs(
              hot_cred,
              sigs,
              message,
            )
          }

        let nonce_check =
          when nonce_state is {
            None -> True
            Some(Nonce(old_nonce, account_hash)) -> {
              expect [Output(address, value, InlineDatum(datum), _), ..] =
                skip_list_mega(outputs, builtin.un_i_data(nonce_output))

              expect Nonce(new_nonce, same_hash) = datum

              let expected_value =
                [
                  Pair(
                    config.bullet_hash,
                    [Pair(bytearray.concat(nonce_prefix, user_stake), 1)],
                  ),
                ]

              expect [_, ..nft_value] = value |> to_dict |> to_pairs

              and {
                (new_nonce > old_nonce)?,
                (account_hash == same_hash)?,
                (dataify(expected_value) == dataify(nft_value))?,
                (address == expected_nonce_address)?,
              }
            }
          }

        and {
          cred_check?,
          nonce_check?,
        }
      }
      Publishing(_, RegisterCredential { .. }) -> True
      _ -> fail
    }
  }
}

/// Allows spending from your vault or other utxos using all your hot keys
validator vault_spend_types {
  withdraw(
    _signatures: (ScriptHash, List<Signature>),
    _account: Credential,
    _tx: Transaction,
  ) {
    fail
  }

  else(_) {
    fail
  }
}

use aiken/builtin
use aiken/collection/dict.{to_pairs}
use aiken/crypto.{ScriptHash, Signature, blake2b_256}
use aiken/primitive/bytearray
use cardano/address.{Address, Credential, Inline, Script}
use cardano/assets.{to_dict}
use cardano/certificate.{RegisterCredential}
use cardano/script_context.{Publishing, ScriptContext, Withdrawing}
use cardano/transaction.{InlineDatum, Output, Transaction}
use config
use prefix.{nonce_prefix}
use types.{AccountSpend, Control, Nonce, Vk}
use utils.{
  check_all_tx_observed, check_all_valid_vk_sigs, dataify, ref_control_datum,
  resolve_user_tx, skip_list_mega,
}

/// Action to spend from your utxos using all your cold keys
validator cold_spend {
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

        expect Control { cold_cred, cold_cred_hash, .. } =
          reference_inputs
            |> ref_control_datum(expected_nft)

        expect cold_cred_hash: List<Credential> = cold_cred_hash

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
          if cold_cred == dataify([]) {
            check_all_tx_observed(
              cold_cred_hash,
              extra_signatories,
              withdrawals,
            )
          } else {
            expect cold_cred: List<Vk> = cold_cred
            let message =
              (inputs_spent, outputs)
                |> builtin.serialise_data()
                |> blake2b_256()

            check_all_tx_observed(
              cold_cred_hash,
              extra_signatories,
              withdrawals,
            ) && check_all_valid_vk_sigs(cold_cred, sigs, message)
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

validator cold_spend_types {
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

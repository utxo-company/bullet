use aiken/builtin
use aiken/collection/dict.{to_pairs}
use aiken/crypto.{blake2b_256}
use cardano/address.{Address, Credential, Inline, Script}
use cardano/assets.{to_dict}
use cardano/certificate.{RegisterCredential}
use cardano/script_context.{Publishing, ScriptContext, Withdrawing}
use cardano/transaction.{Transaction}
use config
use offchain_types.{AccountSpendT}
use types.{AccountSpend, ColdVerification, ColdWithdrawal, Control}
use utils.{
  check_all_tx_observed, check_all_valid_vk_sigs, dataify,
  filter_deleting_inputs, must_find_key, must_have_key, ref_control_datum,
}

fn pop_to_index(list: List<a>, index: Int) -> List<a> {
  if index == 0 {
    list
  } else {
    pop_to_index(builtin.tail_list(list), index - 1)
  }
}

/// Allows for deletion of account
validator delete_account {
  else(sc: ScriptContext) {
    let ScriptContext { transaction: tx, info, redeemer } = sc

    when info is {
      Withdrawing(_) -> {
        let Transaction {
          inputs,
          outputs,
          fee,
          mint,
          withdrawals,
          extra_signatories,
          ..
        } = tx

        let extra_signatories = extra_signatories |> builtin.un_list_data

        let withdrawals =
          withdrawals
            |> builtin.un_map_data

        expect AccountSpend { user_stake, sigs, index: control_index } =
          redeemer

        let stake_key = Some(Inline(Script(user_stake)))

        let expected_address = Address(Script(config.bullet_hash), stake_key)

        let expected_nonce_address =
          Address(Script(config.nonce_bullet_hash), stake_key)

        let inputs_spent =
          filter_deleting_inputs(
            inputs,
            expected_address,
            expected_nonce_address,
          )

        let expected_nft = [Pair(config.bullet_hash, [Pair(user_stake, 1)])]

        expect Control { cold_cred, .. } =
          inputs
            |> pop_to_index(control_index |> builtin.un_i_data)
            |> ref_control_datum(expected_address, expected_nft)

        expect [Pair(name, quantity), ..] =
          mint
            |> to_dict
            |> to_pairs
            |> must_find_key(config.bullet_hash)
            |> to_pairs

        let cred_check =
          if builtin.unconstr_index(cold_cred) == 0 {
            expect ColdVerification(edd25519_keys, other_keys) = cold_cred

            if other_keys == dataify([]) {
              check_all_tx_observed(
                edd25519_keys |> builtin.un_map_data,
                extra_signatories,
              )?
            } else {
              let message =
                (inputs_spent, outputs, fee)
                  |> builtin.serialise_data()
                  |> blake2b_256()

              check_all_tx_observed(
                edd25519_keys |> builtin.un_map_data,
                extra_signatories,
              )? && check_all_valid_vk_sigs(
                other_keys |> builtin.un_list_data,
                sigs |> builtin.un_list_data,
                message,
              )?
            }
          } else {
            expect ColdWithdrawal(sc) = cold_cred
            must_have_key(withdrawals, sc)?
          }

        and {
          cred_check,
          (name == user_stake)?,
          (quantity == -1)?,
        }
      }
      Publishing { certificate: RegisterCredential { .. }, .. } -> True
      _ -> fail
    }
  }
}

validator cold_delete_types {
  withdraw(_signatures: AccountSpendT, _account: Credential, _tx: Transaction) {
    fail
  }

  else(_) {
    fail
  }
}

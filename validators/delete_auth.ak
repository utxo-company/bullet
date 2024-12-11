use aiken/builtin
use aiken/collection/dict.{to_pairs}
use aiken/crypto.{blake2b_256}
use cardano/address.{Address, Credential, Inline, Script}
use cardano/assets.{to_dict}
use cardano/certificate.{RegisterCredential}
use cardano/script_context.{Publishing, ScriptContext, Withdrawing}
use cardano/transaction.{Transaction}
use config
use types.{AccountSpend, Control, Vk}
use utils.{
  check_all_tx_observed, check_all_valid_vk_sigs, filter_deleting_inputs,
  must_find_key, ref_control_datum,
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
          mint,
          withdrawals,
          extra_signatories,
          ..
        } = tx

        expect AccountSpend(user_stake, sigs, control_index) = redeemer

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

        expect Control { cold_cred, cold_cred_hash, .. } =
          inputs
            |> pop_to_index(control_index |> builtin.un_i_data)
            |> ref_control_datum(expected_nft)

        expect [Pair(name, quantity), ..] =
          mint
            |> to_dict
            |> to_pairs
            |> must_find_key(config.bullet_hash)
            |> to_pairs

        expect cold_cred: List<Vk> = cold_cred
        expect cold_cred_hash: List<Credential> = cold_cred_hash

        let message =
          (inputs_spent, outputs, mint)
            |> builtin.serialise_data()
            |> blake2b_256()

        and {
          check_all_tx_observed(cold_cred_hash, extra_signatories, withdrawals),
          check_all_valid_vk_sigs(cold_cred, sigs, message),
          name == user_stake,
          quantity == -1,
        }
      }
      Publishing(_, RegisterCredential { .. }) -> True
      _ -> fail
    }
  }
}

validator cold_control_types {
  withdraw(_signatures: AccountSpend, _account: Credential, _tx: Transaction) {
    fail
  }

  else(_) {
    fail
  }
}

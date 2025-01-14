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
  AccountState, BulletCredential, ChangeCredentials, Control, Verification, Vk,
  Withdrawal,
}
use utils.{
  check_all_tx_observed, check_all_tx_observed_and_hashes,
  check_all_valid_vk_sigs, dataify, filter_user_inputs, must_have_key,
  ref_control_datum,
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

        expect ChangeCredentials {
          control_index,
          user_stake,
          cold_sigs,
          new_hot_sigs,
          new_cold_sigs,
        } = redeemer

        let expected_address =
          Address(Script(config.bullet_hash), Some(Inline(Script(user_stake))))

        let expected_nonce_cred = Script(config.nonce_bullet_hash)

        let inputs_spent =
          filter_user_inputs(inputs, expected_address, expected_nonce_cred)

        let expected_nft = [Pair(config.bullet_hash, [Pair(user_stake, 1)])]

        expect Control { cold_cred, cold_cred_hash, .. } =
          inputs
            |> pop_to_index(control_index)
            |> ref_control_datum(expected_address, expected_nft)

        expect cold_cred: List<Vk> = cold_cred
        expect cold_cred_hash: BulletCredential = cold_cred_hash

        let message =
          (inputs_spent, outputs, fee)
            |> builtin.serialise_data()
            |> blake2b_256()

        expect [Output { address, value, datum: InlineDatum(datum), .. }, ..] =
          outputs

        let expected_nft = [Pair(config.bullet_hash, [Pair(user_stake, 1)])]

        expect [_, ..nft_value] = value |> to_dict |> to_pairs

        expect AccountState {
          quorum: out_quorum,
          hot_cred: out_hot_cred,
          hot_cred_hash: out_hot_cred_hash,
          cold_cred: out_cold_cred,
          cold_cred_hash: out_cold_cred_hash,
        } = datum

        let check_keys_and_hashes =
          fn(bullet_credential, creds, sigs, check_hash) {
            when bullet_credential is {
              Verification(vks) -> and {
                  check_all_valid_vk_sigs(creds, sigs, message)?,
                  if check_hash {
                    check_all_tx_observed_and_hashes(vks, extra_signatories)?
                  } else {
                    check_all_tx_observed(vks, extra_signatories)?
                  },
                }
              Withdrawal(sc) -> must_have_key(withdrawals, sc)?
            }
          }

        and {
          check_keys_and_hashes(cold_cred_hash, cold_cred, cold_sigs, False)?,
          dataify(nft_value) == dataify(expected_nft),
          address == expected_address,
          out_quorum > 0,
          check_keys_and_hashes(
            out_hot_cred_hash,
            out_hot_cred,
            new_hot_sigs,
            True,
          )?,
          check_keys_and_hashes(
            out_cold_cred_hash,
            out_cold_cred,
            new_cold_sigs,
            True,
          )?,
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

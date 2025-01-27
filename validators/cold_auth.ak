use aiken/builtin
use aiken/crypto.{blake2b_256}
use cardano/address.{Address, Credential, Inline, Script}
use cardano/certificate.{RegisterCredential}
use cardano/script_context.{Publishing, ScriptContext, Withdrawing}
use cardano/transaction.{Transaction}
use config
use types.{AccountSpend, ColdVerification, ColdWithdrawal, Control}
use utils.{
  check_all_tx_observed, check_all_valid_vk_sigs, dataify, must_have_key,
  ref_control_datum, resolve_user_tx,
}
use validations.{nonce_check}

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
          fee,
          withdrawals,
          extra_signatories,
          ..
        } = tx

        let extra_signatories = extra_signatories |> builtin.un_list_data

        let withdrawals =
          withdrawals
            |> builtin.un_map_data

        expect AccountSpend { user_stake, sigs, index: nonce_output } = redeemer

        let expected_nft = [Pair(config.bullet_hash, [Pair(user_stake, 1)])]

        let stake_key = Some(Inline(Script(user_stake)))

        let expected_address = Address(Script(config.bullet_hash), stake_key)

        expect Control { cold_cred, .. } =
          reference_inputs
            |> ref_control_datum(expected_address, expected_nft)

        let expected_nonce_address =
          Address(Script(config.nonce_bullet_hash), stake_key)

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
          nonce_check(
            outputs,
            nonce_state,
            nonce_output,
            user_stake,
            expected_nonce_address,
          )?,
        }
      }
      Publishing { certificate: RegisterCredential { .. }, .. } -> True
      _ -> fail
    }
  }
}

validator cold_spend_types {
  withdraw(_signatures: AccountSpend, _account: Credential, _tx: Transaction) {
    fail
  }

  else(_) {
    fail
  }
}

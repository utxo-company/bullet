use aiken/builtin
use aiken/crypto.{ScriptHash, Signature, blake2b_256}
use cardano/address.{Address, Credential, Inline, Script}
use cardano/certificate.{RegisterCredential}
use cardano/script_context.{Publishing, ScriptContext, Withdrawing}
use cardano/transaction.{Transaction}
use config
use types.{AccountSpend, Control, Vk}
use utils.{
  check_all_tx_observed, check_all_valid_vk_sigs, dataify, ref_control_datum,
  resolve_user_tx,
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

        and {
          cred_check?,
          nonce_check(
            outputs,
            nonce_state,
            nonce_output,
            user_stake,
            expected_nonce_address,
          )?,
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

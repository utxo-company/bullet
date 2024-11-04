use aiken/builtin
use aiken/crypto.{ScriptHash, Signature, blake2b_256}
use cardano/address.{Address, Credential, Inline, Script}
use cardano/certificate.{RegisterCredential}
use cardano/script_context.{Publishing, ScriptContext, Withdrawing}
use cardano/transaction.{Transaction}
use config
use types.{Control, Vk}
use utils.{
  check_all_tx_observed, check_all_valid_vk_sigs, dataify, filter_user_inputs,
  ref_control_datum,
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

        let outputs = dataify(outputs)

        expect (user_stake, sigs): (ScriptHash, List<Signature>) = redeemer

        let expected_address =
          Address(Script(config.bullet_hash), Some(Inline(Script(user_stake))))

        let expected_nft = [Pair(config.bullet_hash, [Pair(user_stake, 1)])]

        expect Control { cold_cred, cold_cred_hash, .. } =
          reference_inputs
            |> ref_control_datum(expected_nft)

        expect cold_cred_hash: List<Credential> = cold_cred_hash

        let inputs_spent = filter_user_inputs(inputs, expected_address)

        if cold_cred == dataify([]) {
          check_all_tx_observed(cold_cred_hash, extra_signatories, withdrawals)
        } else {
          expect cold_cred: List<Vk> = cold_cred
          let message =
            (inputs_spent, outputs)
              |> builtin.serialise_data()
              |> blake2b_256()

          check_all_tx_observed(cold_cred_hash, extra_signatories, withdrawals) && check_all_valid_vk_sigs(
            cold_cred,
            sigs,
            message,
          )
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

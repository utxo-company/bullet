use aiken/builtin
use aiken/crypto.{ScriptHash, Signature, blake2b_256}
use cardano/address.{Address, Credential, Inline, Script}
use cardano/certificate.{RegisterCredential}
use cardano/script_context.{Publishing, ScriptContext, Withdrawing}
use cardano/transaction.{Transaction}
use config
use types.{Control, HotAccountSpend, Vk}
use utils.{
  check_tx_observed, check_valid_vk_sigs, dataify, filter_hot_inputs,
  ref_control_datum,
}

/// Action to spend from your vault using a quorum of hot keys
validator hot_spend {
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

        expect HotAccountSpend { user_stake, sigs } = redeemer

        let stake_key = Some(Inline(Script(user_stake)))

        let expected_address = Address(Script(config.bullet_hash), stake_key)

        let expected_nonce_address =
          Address(Script(config.nonce_bullet_hash), stake_key)

        let expected_nft = [Pair(config.bullet_hash, [Pair(user_stake, 1)])]

        expect Control { quorum, hot_cred, hot_cred_hash, .. } =
          reference_inputs
            |> ref_control_datum(expected_nft)

        expect quorum: Int = quorum

        expect hot_cred_hash: List<Credential> = hot_cred_hash

        let inputs_spent =
          filter_hot_inputs(inputs, expected_address, expected_nonce_address)

        if hot_cred == dataify([]) {
          check_tx_observed(hot_cred_hash, extra_signatories, withdrawals) >= quorum
        } else {
          expect hot_cred: List<Vk> = hot_cred

          let message =
            (inputs_spent, outputs)
              |> builtin.serialise_data()
              |> blake2b_256()

          check_tx_observed(hot_cred_hash, extra_signatories, withdrawals) + check_valid_vk_sigs(
            hot_cred,
            sigs,
            message,
          ) >= quorum
        }
      }
      Publishing(_, RegisterCredential { .. }) -> True
      _ -> fail
    }
  }
}

validator hot_spend_types {
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

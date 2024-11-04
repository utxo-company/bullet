use aiken/builtin
use aiken/crypto.{Signature, blake2b_256}
use cardano/address.{Credential, Script}
use cardano/certificate.{RegisterCredential}
use cardano/script_context.{Publishing, ScriptContext, Withdrawing}
use cardano/transaction.{Transaction}
use config
use types.{Control, Vk}
use utils.{check_tx_observed, check_valid_vk_sigs, dataify, ref_control_datum}

/// Validates user signed stake actions in the tx
validator proxy_stake {
  else(sc: ScriptContext) {
    let ScriptContext { transaction: tx, info, redeemer } = sc

    when info is {
      Withdrawing(_) -> {
        let Transaction {
          reference_inputs,
          withdrawals,
          extra_signatories,
          certificates,
          votes,
          ..
        } = tx

        expect (Script(user_hash), sigs): (Credential, List<Signature>) =
          redeemer

        let expected_nft = [Pair(config.bullet_hash, [Pair(user_hash, 1)])]

        expect Control { quorum, hot_cred, hot_cred_hash, .. } =
          reference_inputs
            |> ref_control_datum(expected_nft)

        expect quorum: Int = quorum
        expect hot_cred_hash: List<Credential> = hot_cred_hash

        if hot_cred == dataify([]) {
          check_tx_observed(hot_cred_hash, extra_signatories, withdrawals) >= quorum
        } else {
          expect hot_cred: List<Vk> = hot_cred
          let message =
            (withdrawals, certificates, votes)
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

validator proxy_stake_types {
  withdraw(
    _signatures: (Credential, List<Signature>),
    _account: Credential,
    _tx: Transaction,
  ) {
    fail
  }

  else(_) {
    fail
  }
}

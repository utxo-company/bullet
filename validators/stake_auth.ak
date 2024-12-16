use aiken/builtin
use aiken/crypto.{blake2b_256}
use cardano/address.{Credential, Script}
use cardano/certificate.{RegisterCredential}
use cardano/script_context.{Publishing, ScriptContext, Withdrawing}
use cardano/transaction.{Transaction}
use config
use types.{
  BulletCredential, Control, HotAccountStake, Verification, Vk, Withdrawal,
}
use utils.{
  check_tx_observed, check_valid_vk_sigs, dataify, must_have_key,
  ref_control_datum,
}

/// Validates user signed stake actions in the tx
validator wallet_stake {
  else(sc: ScriptContext) {
    let ScriptContext { transaction: tx, info, redeemer } = sc

    when info is {
      Withdrawing(_) -> {
        let Transaction {
          reference_inputs,
          outputs,
          fee,
          withdrawals,
          extra_signatories,
          certificates,
          votes,
          ..
        } = tx

        expect HotAccountStake(Script(user_hash), sigs) = redeemer

        let expected_nft = [Pair(config.bullet_hash, [Pair(user_hash, 1)])]

        expect Control { quorum, hot_cred, hot_cred_hash, .. } =
          reference_inputs
            |> ref_control_datum(expected_nft)

        expect quorum: Int = quorum
        expect hot_cred_hash: BulletCredential = hot_cred_hash

        when hot_cred_hash is {
          Verification(vks) ->
            if hot_cred == dataify([]) {
              (check_tx_observed(vks, extra_signatories) >= quorum)?
            } else {
              expect hot_cred: List<Vk> = hot_cred

              let message =
                (outputs, fee, withdrawals, certificates, votes)
                  |> builtin.serialise_data()
                  |> blake2b_256()

              (check_tx_observed(vks, extra_signatories) + check_valid_vk_sigs(
                hot_cred,
                sigs,
                message,
              ) >= quorum)?
            }
          Withdrawal(sc) -> must_have_key(withdrawals, sc)?
        }
      }
      Publishing(_, RegisterCredential { .. }) -> True
      _ -> fail
    }
  }
}

validator wallet_stake_types {
  withdraw(_signatures: HotAccountStake, _account: Credential, _tx: Transaction) {
    fail
  }

  else(_) {
    fail
  }
}

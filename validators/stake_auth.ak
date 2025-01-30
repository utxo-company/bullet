use aiken/builtin
use aiken/crypto.{blake2b_256}
use cardano/address.{Credential, Script}
use cardano/certificate.{RegisterCredential}
use cardano/script_context.{Publishing, ScriptContext, Withdrawing}
use cardano/transaction.{Transaction}
use config
use offchain_types.{HotAccountStakeT}
use types.{Control, HotAccountStake, Verification, Withdrawal}
use utils.{
  check_tx_observed, check_valid_vk_sigs, dataify, must_have_key,
  ref_control_datum_by_nft,
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

        let extra_signatories =
          extra_signatories |> dataify |> builtin.un_list_data

        let withdrawals =
          withdrawals
            |> dataify
            |> builtin.un_map_data

        expect HotAccountStake { user_stake: Script(user_hash), sigs } =
          redeemer

        let expected_nft = [Pair(config.bullet_hash, [Pair(user_hash, 1)])]

        expect Control { hot_cred, .. } =
          reference_inputs
            |> ref_control_datum_by_nft(expected_nft)

        if builtin.unconstr_index(hot_cred) == 0 {
          expect Verification { edd25519_keys, other_keys, hot_quorum, .. } =
            hot_cred

          if other_keys == dataify([]) {
            (check_tx_observed(
              edd25519_keys |> builtin.un_map_data,
              extra_signatories,
            ) >= builtin.un_i_data(hot_quorum))?
          } else {
            let message =
              (outputs, fee, withdrawals, certificates, votes)
                |> builtin.serialise_data()
                |> blake2b_256()

            (check_tx_observed(
              edd25519_keys |> builtin.un_map_data,
              extra_signatories,
            ) + check_valid_vk_sigs(
              other_keys |> builtin.un_list_data,
              sigs |> builtin.un_list_data,
              message,
            ) >= builtin.un_i_data(hot_quorum))?
          }
        } else {
          expect Withdrawal(sc) = hot_cred
          must_have_key(withdrawals, sc)?
        }
      }

      Publishing { certificate: RegisterCredential { .. }, .. } -> True
      _ -> fail
    }
  }
}

validator wallet_stake_types {
  withdraw(
    _signatures: HotAccountStakeT,
    _account: Credential,
    _tx: Transaction,
  ) {
    fail
  }

  else(_) {
    fail
  }
}

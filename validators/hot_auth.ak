use aiken/builtin
use aiken/crypto.{blake2b_256}
use cardano/address.{Address, Credential, Inline, Script}
use cardano/certificate.{RegisterCredential}
use cardano/script_context.{Publishing, ScriptContext, Withdrawing}
use cardano/transaction.{Transaction}
use config
use types.{Control, HotAccountSpend, Verification, Withdrawal}
use utils.{
  check_tx_observed, check_valid_vk_sigs, dataify, filter_hot_inputs,
  must_have_key, ref_control_datum,
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
          fee,
          withdrawals,
          extra_signatories,
          ..
        } = tx

        let extra_signatories =
          extra_signatories |> dataify |> builtin.un_list_data

        let withdrawals =
          withdrawals
            |> dataify
            |> builtin.un_map_data

        let outputs = dataify(outputs)

        expect HotAccountSpend { user_stake, sigs } = redeemer

        let expected_address =
          Address(Script(config.bullet_hash), Some(Inline(Script(user_stake))))

        let expected_nft = [Pair(config.bullet_hash, [Pair(user_stake, 1)])]

        expect Control { hot_cred, .. } =
          reference_inputs
            |> ref_control_datum(expected_address, expected_nft)

        let inputs_spent = filter_hot_inputs(inputs, expected_address)

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
              (inputs_spent, outputs, fee)
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

validator hot_spend_types {
  withdraw(_signatures: HotAccountSpend, _account: Credential, _tx: Transaction) {
    fail
  }

  else(_) {
    fail
  }
}

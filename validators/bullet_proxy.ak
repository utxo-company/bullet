use aiken/builtin
use cardano/address.{Credential}
use cardano/assets.{Lovelace}
use cardano/certificate.{RegisterCredential}
use cardano/script_context.{Publishing, ScriptContext, Withdrawing}
use cardano/transaction.{Input, OutputReference, Transaction}
use config
use types.{ColdControl, ColdCred, HotCred, Intention, ProxyAction, VaultSpend}
use utils.{dataify, ref_control_datum}

fn must_have_key_data(
  withdrawals: Pairs<Credential, Lovelace>,
  cred: Data,
) -> Bool {
  expect [Pair(key, _), ..rest] = withdrawals

  dataify(key) == cred || must_have_key_data(rest, cred)
}

/// The bread and butter of Bullet
/// The ultimate contract. A simple tiny withdraw validator that orchestrates all the music
validator proxy_spend {
  else(sc: ScriptContext) {
    let ScriptContext { transaction: tx, redeemer, info } = sc

    when info is {
      Withdrawing(_) -> {
        let Transaction { reference_inputs, withdrawals, .. } = tx

        let expected_nft = [Pair(config.one_shot_mint_hash, [Pair("", 1)])]

        // Get control credentials
        expect [
          hot_cred_contract, intention_contract, vault_spend_contract,
          cold_cred_contract, cold_control_contract, delete_contract,
          ..
        ] =
          reference_inputs
            |> ref_control_datum(expected_nft)
            |> builtin.unconstr_fields

        if redeemer == dataify(HotCred) {
          must_have_key_data(withdrawals, hot_cred_contract)
        } else if redeemer == dataify(Intention) {
          must_have_key_data(withdrawals, intention_contract)
        } else if redeemer == dataify(VaultSpend) {
          must_have_key_data(withdrawals, vault_spend_contract)
        } else if redeemer == dataify(ColdCred) {
          must_have_key_data(withdrawals, cold_cred_contract)
        } else if redeemer == dataify(ColdControl) {
          must_have_key_data(withdrawals, cold_control_contract)
        } else {
          must_have_key_data(withdrawals, delete_contract)
        }
      }
      Publishing(_, RegisterCredential { .. }) -> True
      _ -> fail
    }
  }
}

validator proxy_spend_types {
  withdraw(_r: ProxyAction, _acc, _tx) {
    fail
  }

  else(_) {
    fail
  }
}

validator one_shot_proxy_mint {
  mint(_r, _own_policy, tx: Transaction) {
    let Transaction { inputs, .. } = tx

    let one_shot_ref =
      config.one_shot_tx_hash
        |> OutputReference(config.one_shot_output_index)

    expect [Input { output_reference, .. }, ..] = inputs

    output_reference == one_shot_ref
  }

  else(_) {
    fail
  }
}

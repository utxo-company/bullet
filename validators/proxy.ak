use aiken/builtin
use cardano/address.{Credential, Script}
use cardano/assets.{Lovelace}
use cardano/certificate.{RegisterCredential}
use cardano/script_context.{Minting, Publishing, ScriptContext, Withdrawing}
use cardano/transaction.{Input, Output, OutputReference, Transaction}
use config
use types.{ColdCred, HotCred, Intention, VaultSpend}
use utils.{dataify, inputs_inline_datum, must_find_item, quantity_of}

fn must_have_key_data(
  withdrawals: Pairs<Credential, Lovelace>,
  cred: Data,
) -> Bool {
  expect [Pair(key, _), ..rest] = withdrawals

  dataify(key) == cred || must_have_key_data(rest, cred)
}

/// The bread and butter of Bullet
/// The ultimate contract. A simple tiny withdraw validator that orchestrates all the music
/// TODO: simply use the else validator to shrink as much as possible
validator proxy_spend {
  else(sc: ScriptContext) {
    let ScriptContext { transaction: tx, redeemer, info } = sc

    when info is {
      Withdrawing(account) -> {
        expect Script(own_hash) = account

        let Transaction { reference_inputs, withdrawals, .. } = tx

        // Get control credentials
        expect [
          hot_cred_contract, intention_contract, vault_spend_contract,
          cold_cred_contract, cold_control_contract,
          ..
        ] =
          reference_inputs
            |> must_find_item(
                fn(input) {
                  input.output.value
                    |> quantity_of(own_hash, "")
                    |> builtin.equals_integer(1)
                },
              )
            |> inputs_inline_datum()
            |> builtin.un_constr_data()
            |> builtin.snd_pair()

        if redeemer == dataify(HotCred) {
          must_have_key_data(withdrawals, hot_cred_contract)
        } else if redeemer == dataify(Intention) {
          must_have_key_data(withdrawals, intention_contract)
        } else if redeemer == dataify(VaultSpend) {
          must_have_key_data(withdrawals, vault_spend_contract)
        } else if redeemer == dataify(ColdCred) {
          must_have_key_data(withdrawals, cold_cred_contract)
        } else {
          must_have_key_data(withdrawals, cold_control_contract)
        }
      }
      Minting(_) -> {
        let Transaction { inputs, .. } = tx

        let one_shot_ref =
          config.one_shot_tx_hash
            |> OutputReference(config.one_shot_output_index)

        expect [Input { output_reference, .. }, ..] = inputs

        output_reference == one_shot_ref
      }
      Publishing(_, RegisterCredential { .. }) -> True
      _ -> fail
    }
  }
}

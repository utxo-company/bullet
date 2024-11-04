use aiken/builtin
use aiken/crypto.{ScriptHash, Signature, blake2b_256}
use cardano/address.{Address, Credential, Inline, Script}
use cardano/assets.{from_asset, without_lovelace}
use cardano/certificate.{RegisterCredential}
use cardano/script_context.{Publishing, ScriptContext, Withdrawing}
use cardano/transaction.{InlineDatum, Output, Transaction}
use config
use types.{AccountState, Control, Vk}
use utils.{
  check_all_tx_observed, check_all_valid_vk_sigs, filter_user_inputs,
  ref_control_datum,
}

fn pop_to_index(list: List<a>, index: Int) -> List<a> {
  if index == 0 {
    list
  } else {
    pop_to_index(builtin.tail_list(list), index - 1)
  }
}

validator cold_control {
  else(sc: ScriptContext) {
    let ScriptContext { transaction: tx, info, redeemer } = sc

    when info is {
      Withdrawing(_) -> {
        let Transaction { inputs, outputs, withdrawals, extra_signatories, .. } =
          tx

        expect (
          control_index,
          user_stake,
          cold_sigs,
          new_hot_sigs,
          new_cold_sigs,
        ): (Int, ScriptHash, List<Signature>, List<Signature>, List<Signature>) =
          redeemer

        let expected_address =
          Address(Script(config.bullet_hash), Some(Inline(Script(user_stake))))

        let inputs_spent = filter_user_inputs(inputs, expected_address)

        let expected_nft = [Pair(config.bullet_hash, [Pair(user_stake, 1)])]

        expect Control { cold_cred, cold_cred_hash, .. } =
          inputs
            |> pop_to_index(control_index)
            |> ref_control_datum(expected_nft)

        expect cold_cred: List<Vk> = cold_cred
        expect cold_cred_hash: List<Credential> = cold_cred_hash

        let message =
          (inputs_spent, outputs)
            |> builtin.serialise_data()
            |> blake2b_256()

        expect [Output { address, value, datum: InlineDatum(datum), .. }, ..] =
          outputs

        let expected_value = from_asset(config.bullet_hash, user_stake, 1)

        expect AccountState {
          quorum: out_quorum,
          hot_cred: out_hot_cred,
          hot_cred_hash: out_hot_cred_hash,
          cold_cred: out_cold_cred,
          cold_cred_hash: out_cold_cred_hash,
        } = datum

        and {
          check_all_tx_observed(cold_cred_hash, extra_signatories, withdrawals),
          check_all_valid_vk_sigs(cold_cred, cold_sigs, message),
          without_lovelace(value) == expected_value,
          address == expected_address,
          out_quorum > 0,
          check_all_valid_vk_sigs(out_hot_cred, new_hot_sigs, message),
          check_all_valid_vk_sigs(out_cold_cred, new_cold_sigs, message),
          check_all_tx_observed(
            out_hot_cred_hash,
            extra_signatories,
            withdrawals,
          ),
          check_all_tx_observed(
            out_cold_cred_hash,
            extra_signatories,
            withdrawals,
          ),
        }
      }
      Publishing(_, RegisterCredential { .. }) -> True
      _ -> fail
    }
  }
}

validator cold_control_types {
  withdraw(
    _signatures: (
      Int,
      ScriptHash,
      List<Signature>,
      List<Signature>,
      List<Signature>,
    ),
    _account: Credential,
    _tx: Transaction,
  ) {
    fail
  }

  else(_) {
    fail
  }
}

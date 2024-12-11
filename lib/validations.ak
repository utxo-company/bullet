use aiken/builtin
use aiken/collection/dict.{to_pairs}
use aiken/primitive/bytearray
use cardano/assets.{to_dict}
use cardano/transaction.{InlineDatum, Output}
use config
use prefix.{nonce_prefix}
use types.{Nonce}
use utils.{dataify, skip_list_mega}
use aiken/crypto.{ScriptHash}
use cardano/address.{Address}

pub fn nonce_check(
  outputs: List<Output>,
  nonce_state: Option<Nonce>,
  nonce_output_index: Data,
  user_stake: ScriptHash,
  expected_nonce_address: Address,
) -> Bool {
  when nonce_state is {
    None -> True
    Some(Nonce(old_nonce, account_hash)) -> {
      expect [Output(address, value, InlineDatum(datum), _), ..] =
        skip_list_mega(outputs, builtin.un_i_data(nonce_output_index))

      expect Nonce(new_nonce, same_hash) = datum

      let expected_value =
        [
          Pair(
            config.bullet_hash,
            [Pair(bytearray.concat(nonce_prefix, user_stake), 1)],
          ),
        ]

      expect [_, ..nft_value] = value |> to_dict |> to_pairs

      and {
        (new_nonce > old_nonce)?,
        (account_hash == same_hash)?,
        (dataify(expected_value) == dataify(nft_value))?,
        (address == expected_nonce_address)?,
      }
    }
  }
}

use aiken/builtin
use aiken/collection/dict.{to_pairs}
use aiken/crypto.{ScriptHash}
use aiken/primitive/bytearray
use cardano/address.{Address}
use cardano/assets.{to_dict}
use cardano/transaction.{InlineDatum, Output}
use config
use prefix.{nonce_prefix}
use types.{Nonce}
use utils.{dataify, skip_list_mega}

pub fn nonce_check(
  outputs: List<Output>,
  nonce_state: Nonce,
  nonce_output_index: Data,
  user_stake: ScriptHash,
  expected_nonce_address: Address,
) -> Bool {
  if nonce_state == -1 {
    True
  } else {
    expect [Output(address, value, InlineDatum(datum), _), ..] =
      skip_list_mega(outputs, builtin.un_i_data(nonce_output_index))

    expect new_nonce: Nonce = datum

    let expected_value =
      [
        Pair(
          config.bullet_hash,
          [Pair(bytearray.concat(nonce_prefix, user_stake), 1)],
        ),
      ]

    expect [_, ..nft_value] = value |> to_dict |> to_pairs

    and {
      (new_nonce > nonce_state)?,
      (dataify(expected_value) == dataify(nft_value))?,
      (address == expected_nonce_address)?,
    }
  }
}

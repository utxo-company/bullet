use aiken/builtin
use aiken/collection/dict.{to_pairs}
use aiken/crypto.{ScriptHash}
use aiken/primitive/bytearray
use cardano/address.{Address}
use cardano/assets.{to_dict}
use cardano/transaction.{InlineDatum, Output}
use config
use macros.{list_skipper_macro_pieces}
use prefix.{nonce_prefix}
use types.{Nonce}
use utils.{dataify}

const skip_list_5: fn(
    fn(
      fn(List<Output>, Int) -> List<Output>,
      fn(List<Output>) -> List<Output>,
      Int,
    ) ->
      List<Output>,
  ) ->
    List<Output> =
  list_skipper_macro_pieces(5)

const skip_list_macro = skip_list_fn

fn skip_list_fn(outputs: List<Output>, index: Int) -> List<Output> {
  let iterate_func, skip_func, skip_count <- skip_list_5

  if index >= skip_count {
    outputs |> skip_func |> skip_list_fn(index - skip_count)
  } else {
    iterate_func(outputs, index)
  }
}

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
      skip_list_macro(outputs, builtin.un_i_data(nonce_output_index))

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

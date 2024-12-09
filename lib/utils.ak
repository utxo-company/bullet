use aiken/builtin
use aiken/collection/dict.{Dict, to_pairs}
use aiken/crypto.{
  Signature, VerificationKeyHash, verify_ecdsa_signature,
  verify_schnorr_signature,
}
use aiken/primitive/bytearray.{is_empty}
use cardano/address.{Address, Credential, Script, VerificationKey}
use cardano/assets.{AssetName, Lovelace, PolicyId, Value, to_dict}
use cardano/transaction.{InlineDatum, Input, Output, OutputReference}
use config
use prefix.{nonce_prefix}
use types.{MessageHash, Nonce, Schnorr, Secp, Vault, Vk}

pub fn must_find_key(pairs: Pairs<a, b>, key: a) -> b {
  expect [Pair(k2, value), ..rest] = pairs

  if k2 == key {
    value
  } else {
    must_find_key(rest, key)
  }
}

pub fn must_have(list: List<a>, item: a) -> Bool {
  expect [x, ..rest] = list

  x == item || must_have(rest, item)
}

pub fn must_find_item(list: List<a>, predicate: fn(a) -> Bool) -> a {
  expect [item, ..rest] = list

  if predicate(item) {
    item
  } else {
    must_find_item(rest, predicate)
  }
}

pub fn inputs_inline_datum(i: Input) -> Data {
  expect InlineDatum(d) = i.output.datum

  d
}

pub fn at(list: List<a>, index: Int) -> a {
  if index == 0 {
    builtin.head_list(list)
  } else {
    at(builtin.tail_list(list), index - 1)
  }
}

pub fn ref_control_datum(ref_inputs: List<Input>, ref_value: Data) -> Data {
  expect [input, ..rest] = ref_inputs

  let Input { output, .. } = input

  expect [_, ..nft_value] = output.value |> to_dict |> to_pairs

  if dataify(nft_value) == ref_value {
    expect InlineDatum(control_datum) = output.datum
    control_datum
  } else {
    ref_control_datum(rest, ref_value)
  }
}

/// Returns count of non-empty signatures that are valid
/// Fails if any non-empty signature is invalid
pub fn check_valid_vk_sigs(
  vks: List<Vk>,
  signatures: List<Signature>,
  message: MessageHash,
) -> Int {
  when vks is {
    [] -> 0
    [vk, ..rest] -> {
      expect [sig, ..others] = signatures

      if is_empty(sig) {
        check_valid_vk_sigs(rest, others, message)
      } else {
        when vk is {
          // ranked by probable usage
          Schnorr(vk) ->
            if vk |> verify_schnorr_signature(message, sig) {
              1 + check_valid_vk_sigs(rest, others, message)
            } else {
              fail
            }
          Secp(vk) ->
            if vk |> verify_ecdsa_signature(message, sig) {
              1 + check_valid_vk_sigs(rest, others, message)
            } else {
              fail
            }
        }
      }
    }
  }
}

pub fn check_tx_observed(
  vkhs: List<Credential>,
  signatories: List<VerificationKeyHash>,
  withdrawals: Pairs<Credential, Lovelace>,
) -> Int {
  when vkhs is {
    [] -> 0
    [vkh, ..rest] ->
      when vkh is {
        VerificationKey(vkh) ->
          1 + (
            signatories
              |> must_take_until(vkh)
              |> check_tx_observed(rest, _, withdrawals)
          )
        Script(_) as sc ->
          1 + (
            withdrawals
              |> must_take_key_until(sc)
              |> check_tx_observed(rest, signatories, _)
          )
      }
  }
}

/// Returns count of non-empty signatures that are valid
/// Fails if any non-empty signature is invalid
pub fn check_all_valid_vk_sigs(
  vks: List<Vk>,
  signatures: List<Signature>,
  message: MessageHash,
) -> Bool {
  when vks is {
    [] -> True
    [vk, ..rest] -> {
      expect [sig, ..others] = signatures

      when vk is {
        // ranked by probable usage
        Schnorr(vk) ->
          (
            vk
              |> verify_schnorr_signature(message, sig)
          ) && check_all_valid_vk_sigs(rest, others, message)
        Secp(vk) ->
          (
            vk
              |> verify_schnorr_signature(message, sig)
          ) && check_all_valid_vk_sigs(rest, others, message)
      }
    }
  }
}

pub fn check_all_tx_observed(
  vkhs: List<Credential>,
  signatories: List<VerificationKeyHash>,
  withdrawals: Pairs<Credential, Lovelace>,
) -> Bool {
  when vkhs is {
    [] -> True
    [vkh, ..rest] ->
      when vkh is {
        VerificationKey(vkh) ->
          signatories
            |> must_take_until(vkh)
            |> check_all_tx_observed(rest, _, withdrawals)
        Script(_) as sc ->
          withdrawals
            |> must_take_key_until(sc)
            |> check_all_tx_observed(rest, signatories, _)
      }
  }
}

pub fn must_take_until(list: List<a>, item: a) -> List<a> {
  expect [first, ..rest] = list

  if item == first {
    rest
  } else {
    must_take_until(rest, item)
  }
}

pub fn must_take_key_until(list: List<Pair<a, b>>, key: a) -> List<Pair<a, b>> {
  expect [Pair(key2, _), ..rest] = list

  if key == key2 {
    rest
  } else {
    must_take_key_until(rest, key)
  }
}

pub fn dataify(d: Data) -> Data {
  d
}

pub fn filter_hot_inputs(
  list: List<Input>,
  address: Address,
  nonce_address: Address,
) -> List<OutputReference> {
  when list is {
    [] -> []
    [input, ..xs] -> {
      let Input(output_reference, Output { address: in_address, datum, .. }) =
        input

      if in_address == address {
        if datum == InlineDatum(Vault) {
          fail
        } else {
          [output_reference, ..filter_hot_inputs(xs, address, nonce_address)]
        }
      } else if or {
        in_address.payment_credential == address.payment_credential,
        in_address == nonce_address,
      } {
        fail
      } else {
        filter_hot_inputs(xs, address, nonce_address)
      }
    }
  }
}

pub fn filter_user_inputs(
  list: List<Input>,
  address: Address,
  nonce_address: Address,
) -> List<OutputReference> {
  when list is {
    [] -> []
    [input, ..xs] -> {
      let Input(output_reference, Output { address: in_address, .. }) = input

      if in_address == address {
        [output_reference, ..filter_hot_inputs(xs, address, nonce_address)]
      } else if or {
        in_address.payment_credential == address.payment_credential,
        in_address == nonce_address,
      } {
        fail
      } else {
        filter_hot_inputs(xs, address, nonce_address)
      }
    }
  }
}

pub fn resolve_user_tx(
  list: List<Input>,
  address: Address,
  nonce_address: Address,
  filtered_inputs: List<OutputReference>,
  nonce_present: Option<Nonce>,
  callback: fn(List<OutputReference>, Option<Nonce>) -> Bool,
) -> Bool {
  when list is {
    [] -> callback(filtered_inputs, nonce_present)
    [input, ..xs] -> {
      let Input(output_reference, Output { address: in_address, .. } as output) =
        input

      if in_address == address {
        resolve_user_tx(
          xs,
          address,
          nonce_address,
          [output_reference, ..filtered_inputs],
          nonce_present,
          callback,
        )
      } else if in_address == nonce_address {
        expect Output { value, datum: InlineDatum(datum), .. } = output

        expect Nonce { account_hash, .. } as nonce_state = datum

        let expected_value =
          [
            Pair(
              config.bullet_hash,
              [Pair(bytearray.concat(nonce_prefix, account_hash), 1)],
            ),
          ]

        expect [_, ..nft_value] = value |> to_dict |> to_pairs

        expect dataify(expected_value) == dataify(nft_value)

        resolve_user_tx(
          xs,
          address,
          nonce_address,
          [output_reference, ..filtered_inputs],
          Some(nonce_state),
          callback,
        )
      } else if or {
        in_address.payment_credential == address.payment_credential,
        in_address.payment_credential == nonce_address.payment_credential,
      } {
        fail
      } else {
        resolve_user_tx(
          xs,
          address,
          nonce_address,
          filtered_inputs,
          nonce_present,
          callback,
        )
      }
    }
  }
}

pub fn quantity_of(val: Value, policy: PolicyId, asset: AssetName) -> Int {
  val |> to_dict() |> to_pairs() |> do_quantity_of(policy, asset)
}

fn do_quantity_of(
  val: Pairs<ByteArray, Dict<ByteArray, Int>>,
  policy: PolicyId,
  asset: AssetName,
) -> Int {
  when val is {
    [] -> 0
    [Pair(x, y), ..xs] ->
      if x == policy {
        do_asset_of(y |> to_pairs(), asset)
      } else {
        do_quantity_of(xs, policy, asset)
      }
  }
}

fn do_asset_of(val: Pairs<ByteArray, Int>, asset: AssetName) -> Int {
  when val is {
    [] -> 0
    [Pair(x, y), ..xs] ->
      if x == asset {
        y
      } else {
        do_asset_of(xs, asset)
      }
  }
}

pub fn skip_list_mega_fast(l: List<a>, i: Int) -> List<a> {
  if i < 4 {
    skip_list_mega(l, i)
  } else {
    l
      |> builtin.tail_list
      |> builtin.tail_list
      |> builtin.tail_list
      |> builtin.tail_list
      |> skip_list_mega_fast(i - 4)
  }
}

pub fn skip_list_mega(l: List<a>, i: Int) -> List<a> {
  if i == 0 {
    l
  } else {
    let i = i - 1
    let l = builtin.tail_list(l)

    if i == 0 {
      l
    } else {
      let i = i - 1
      let l = builtin.tail_list(l)

      if i == 0 {
        l
      } else {
        builtin.tail_list(l)
      }
    }
  }
}

const x = [1, 2, 3, 5, 7, 8, 0, 10, 11, 212, 23, 25]

test skip_list_speed_3_s() {
  ( skip_list_mega_fast(x, 0) |> builtin.head_list ) == 1
}

test skip_list_speed_4_s() {
  ( skip_list_mega_fast(x, 1) |> builtin.head_list ) == 2
}

test skip_list_speed_5_s() {
  ( skip_list_mega_fast(x, 2) |> builtin.head_list ) == 3
}

test skip_list_speed_6_s() {
  ( skip_list_mega_fast(x, 3) |> builtin.head_list ) == 5
}

test skip_list_speed_7_s() {
  ( skip_list_mega_fast(x, 4) |> builtin.head_list ) == 7
}

test skip_list_speed_8_s() {
  ( skip_list_mega_fast(x, 5) |> builtin.head_list ) == 8
}

test skip_list_speed_9_s() {
  ( skip_list_mega_fast(x, 6) |> builtin.head_list ) == 0
}

test skip_list_speed_1_s() {
  ( skip_list_mega_fast(x, 8) |> builtin.head_list ) == 11
}

test skip_list_speed_11_s() {
  ( skip_list_mega_fast(x, 9) |> builtin.head_list ) == 212
}

test skip_list_speed_2_s() {
  ( skip_list_mega_fast(x, 11) |> builtin.head_list ) == 25
}

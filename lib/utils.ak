use aiken/builtin
use aiken/collection/dict.{Dict, to_pairs}
use aiken/crypto.{
  Signature, VerificationKeyHash, verify_ecdsa_signature,
  verify_schnorr_signature,
}
use aiken/primitive/bytearray.{is_empty}
use cardano/address.{Address, Credential, Script, VerificationKey}
use cardano/assets.{AssetName, Lovelace, PolicyId, Value, to_dict}
use cardano/transaction.{InlineDatum, Input, OutputReference}
use types.{MessageHash, Schnorr, Secp, Vault, Vk}

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
) -> List<OutputReference> {
  when list is {
    [] -> []
    [x, ..xs] -> {
      let y = x.output

      if y.address == address {
        let datum = y.datum

        if datum == InlineDatum(Vault) {
          fail
        } else {
          [x.output_reference, ..filter_hot_inputs(xs, address)]
        }
      } else if y.address.payment_credential == address.payment_credential {
        fail
      } else {
        filter_hot_inputs(xs, address)
      }
    }
  }
}

pub fn filter_user_inputs(
  list: List<Input>,
  address: Address,
) -> List<OutputReference> {
  when list is {
    [] -> []
    [x, ..xs] -> {
      let y = x.output

      if y.address == address {
        [x.output_reference, ..filter_user_inputs(xs, address)]
      } else if y.address.payment_credential == address.payment_credential {
        fail
      } else {
        filter_user_inputs(xs, address)
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

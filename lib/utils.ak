use aiken/builtin
use aiken/collection/dict.{Dict, to_pairs}
use aiken/crypto.{
  Blake2b_224, Hash, ScriptHash, Signature, VerificationKey, VerificationKeyHash,
  verify_ecdsa_signature, verify_ed25519_signature, verify_schnorr_signature,
}
use aiken/primitive/bytearray.{is_empty}
use cardano/address.{Address, Script}
use cardano/assets.{AssetName, PolicyId, Value, to_dict}
use cardano/transaction.{InlineDatum, Input, Output, OutputReference}
use config
use prefix.{nonce_prefix}
use types.{MessageHash, Nonce, Schnorr, Secp, Vault, Vk}

// Must functions
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

pub fn must_have_key(list: Pairs<a, b>, item: a) -> Bool {
  expect [Pair(x, _), ..rest] = list

  x == item || must_have_key(rest, item)
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

pub fn must_find_item(list: List<a>, predicate: fn(a) -> Bool) -> a {
  expect [item, ..rest] = list

  if predicate(item) {
    item
  } else {
    must_find_item(rest, predicate)
  }
}

// Generic Utils
pub fn inputs_inline_datum(i: Input) -> Data {
  expect InlineDatum(d) = i.output.datum

  d
}

pub fn dataify(d: Data) -> Data {
  d
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

pub fn at(list: List<a>, index: Int) -> a {
  if index == 0 {
    builtin.head_list(list)
  } else {
    at(builtin.tail_list(list), index - 1)
  }
}

pub fn ref_control_datum_by_nft(
  ref_inputs: List<Input>,
  ref_value: Data,
) -> Data {
  expect [input, ..rest] = ref_inputs

  let Input { output, .. } = input

  let Output { value, datum, .. } = output

  // This won't error since every input has to at least have ada
  expect [_, ..nft_value] = value |> to_dict |> to_pairs

  if dataify(nft_value) == ref_value {
    expect InlineDatum(control_datum) = datum
    control_datum
  } else {
    ref_control_datum_by_nft(rest, ref_value)
  }
}

pub fn ref_control_datum(
  ref_inputs: List<Input>,
  ref_address: Address,
  ref_value: Data,
) -> Data {
  expect [input, ..rest] = ref_inputs

  let Input { output, .. } = input

  if output.address == ref_address {
    let Output { value, datum, .. } = output

    // This won't error since every input has to at least have ada
    expect [_, ..nft_value] = value |> to_dict |> to_pairs

    if dataify(nft_value) == ref_value {
      expect InlineDatum(control_datum) = datum
      control_datum
    } else {
      ref_control_datum(rest, ref_address, ref_value)
    }
  } else {
    ref_control_datum(rest, ref_address, ref_value)
  }
}

/// Produce a plutusV3 script hash to match the onchain comparison
/// with script ref field in Output
pub fn scriptify_bytes(bytes: Hash<Blake2b_224, Data>) {
  bytearray.concat(#"03582401010048811c", bytes)
    |> bytearray.concat(#"0001")
    |> builtin.blake2b_224
    |> Some
}

// Sig checks
/// Returns count of non-empty signatures that are valid
/// Fails if any non-empty signature is invalid
pub fn check_quorum_valid_sigs(
  vkhs: Pairs<Data<VerificationKeyHash>, Data<VerificationKey>>,
  vks: List<Data<Vk>>,
  signatures: List<Data<Signature>>,
  message: MessageHash,
) -> Int {
  when vks is {
    [] -> check_valid_edd_sigs(vkhs, signatures, message)
    [vk, ..rest] -> {
      expect [sig, ..others] = signatures
      let sig = sig |> builtin.un_b_data

      if is_empty(sig) {
        check_quorum_valid_sigs(vkhs, rest, others, message)
      } else {
        if builtin.unconstr_index(vk) == 0 {
          expect Schnorr(vk) = vk

          expect verify_schnorr_signature(vk, message, sig)

          1 + check_quorum_valid_sigs(vkhs, rest, others, message)
        } else {
          expect Secp(vk) = vk

          expect verify_ecdsa_signature(vk, message, sig)

          1 + check_quorum_valid_sigs(vkhs, rest, others, message)
        }
      }
    }
  }
}

/// Returns count of non-empty signatures that are valid
/// Fails if any non-empty signature is invalid
pub fn check_valid_vk_sigs(
  vks: List<Data<Vk>>,
  signatures: List<Data<Signature>>,
  message: MessageHash,
) -> Int {
  when vks is {
    [] -> 0
    [vk, ..rest] -> {
      expect [sig, ..others] = signatures

      let sig = sig |> builtin.un_b_data

      if is_empty(sig) {
        check_valid_vk_sigs(rest, others, message)
      } else {
        if builtin.unconstr_index(vk) == 0 {
          expect Schnorr(vk) = vk

          expect verify_schnorr_signature(vk, message, sig)

          1 + check_valid_vk_sigs(rest, others, message)
        } else {
          expect Secp(vk) = vk

          expect verify_ecdsa_signature(vk, message, sig)

          1 + check_valid_vk_sigs(rest, others, message)
        }
      }
    }
  }
}

/// Returns count of non-empty signatures that are valid
/// Fails if any non-empty signature is invalid
pub fn check_valid_edd_sigs(
  vkhs: Pairs<Data<VerificationKeyHash>, Data<VerificationKey>>,
  signatures: List<Data<Signature>>,
  message: MessageHash,
) -> Int {
  when vkhs is {
    [] -> 0
    [Pair(_vkh, vk), ..rest] -> {
      expect [sig, ..others] = signatures

      if is_empty(sig |> builtin.un_b_data) {
        check_valid_edd_sigs(rest, others, message)
      } else {
        if vk
          |> builtin.un_b_data
          |> verify_ed25519_signature(message, sig |> builtin.un_b_data) {
          1 + check_valid_edd_sigs(rest, others, message)
        } else {
          fail
        }
      }
    }
  }
}

pub fn check_tx_observed(
  vkhs: Pairs<Data<VerificationKeyHash>, Data<VerificationKey>>,
  signatories: List<Data<VerificationKeyHash>>,
) -> Int {
  when vkhs is {
    [] -> 0
    [Pair(vkh, _vk), ..rest] ->
      1 + (
        signatories
          |> must_take_until(vkh)
          |> check_tx_observed(rest, _)
      )
  }
}

/// Returns count of non-empty signatures that are valid
/// Fails if any non-empty signature is invalid
pub fn check_all_valid_vk_sigs(
  vks: List<Data<Vk>>,
  signatures: List<Data<Signature>>,
  message: MessageHash,
) -> Bool {
  when vks is {
    [] -> True
    [vk, ..rest] -> {
      expect [sig, ..others] = signatures

      if builtin.unconstr_index(vk) == 0 {
        expect Schnorr(vk) = vk
        (vk
          |> verify_schnorr_signature(message, sig |> builtin.un_b_data))? && check_all_valid_vk_sigs(
          rest,
          others,
          message,
        )
      } else {
        expect Secp(vk) = vk
        (vk
          |> verify_ecdsa_signature(message, sig |> builtin.un_b_data))? && check_all_valid_vk_sigs(
          rest,
          others,
          message,
        )
      }
    }
  }
}

pub fn check_all_tx_observed(
  vkhs: Pairs<Data<VerificationKeyHash>, Data<VerificationKey>>,
  signatories: List<Data<VerificationKeyHash>>,
) -> Bool {
  when vkhs is {
    [] -> True
    [Pair(vkh, _), ..rest] ->
      signatories
        |> must_take_until(vkh)
        |> check_all_tx_observed(rest, _)
  }
}

/// Same as above, but also check hashes match vk
pub fn check_all_tx_observed_and_hashes(
  vkhs: Pairs<Data<VerificationKeyHash>, Data<VerificationKey>>,
  signatories: List<Data<VerificationKeyHash>>,
) -> Bool {
  when vkhs is {
    [] -> True
    [Pair(vkh, vk), ..rest] -> {
      expect
        ( vk |> builtin.un_b_data() |> builtin.blake2b_224() ) == builtin.un_b_data(
          vkh,
        )

      signatories
        |> must_take_until(vkh)
        |> check_all_tx_observed_and_hashes(rest, _)
    }
  }
}

// Input filters
pub fn filter_hot_inputs(
  list: List<Input>,
  address: Address,
) -> List<OutputReference> {
  when list is {
    [] -> []
    [input, ..xs] -> {
      let Input(output_reference, Output { address: in_address, datum, .. }) =
        input

      if in_address == address {
        if datum == InlineDatum(Vault) {
          fail @"Can't spend vault inputs"
        } else {
          [output_reference, ..filter_hot_inputs(xs, address)]
        }
      } else if or {
        in_address.payment_credential == address.payment_credential,
        in_address.payment_credential == Script(config.nonce_bullet_hash),
      } {
        fail @"Can't spend other's inputs"
      } else {
        // Allows for an external input to pay the fee
        filter_hot_inputs(xs, address)
      }
    }
  }
}

pub fn filter_deleting_inputs(
  list: List<Input>,
  address: Address,
  nonce_address: Address,
) -> List<OutputReference> {
  when list is {
    [] -> []
    [input, ..xs] -> {
      let Input(output_reference, Output { address: in_address, .. }) = input

      if in_address == address || in_address == nonce_address {
        [output_reference, ..filter_deleting_inputs(xs, address, nonce_address)]
      } else if or {
        in_address.payment_credential == address.payment_credential,
        in_address.payment_credential == nonce_address.payment_credential,
      } {
        fail @"Can't spend other's inputs"
      } else {
        // Allows for an external input to pay the fee
        filter_deleting_inputs(xs, address, nonce_address)
      }
    }
  }
}

// Filter inputs and handle nonce
pub fn resolve_user_tx(
  user_stake: ScriptHash,
  list: List<Input>,
  address: Address,
  nonce_address: Address,
  filtered_inputs: List<OutputReference>,
  nonce_present: Nonce,
  callback: fn(List<OutputReference>, Nonce) -> Bool,
) -> Bool {
  when list is {
    [] -> callback(filtered_inputs, nonce_present)
    [input, ..xs] -> {
      let Input(output_reference, Output { address: in_address, .. } as output) =
        input

      if in_address == address {
        resolve_user_tx(
          user_stake,
          xs,
          address,
          nonce_address,
          [output_reference, ..filtered_inputs],
          nonce_present,
          callback,
        )
      } else if in_address == nonce_address {
        expect Output { value, datum: InlineDatum(datum), .. } = output

        expect nonce_state: Nonce = datum

        let expected_value =
          [
            Pair(
              config.bullet_hash,
              [Pair(bytearray.concat(nonce_prefix, user_stake), 1)],
            ),
          ]

        expect [_, ..nft_value] = value |> to_dict |> to_pairs

        expect dataify(expected_value) == dataify(nft_value)

        resolve_user_tx(
          user_stake,
          xs,
          address,
          nonce_address,
          [output_reference, ..filtered_inputs],
          nonce_state,
          callback,
        )
      } else if or {
        in_address.payment_credential == address.payment_credential,
        in_address.payment_credential == nonce_address.payment_credential,
      } {
        fail
      } else {
        resolve_user_tx(
          user_stake,
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

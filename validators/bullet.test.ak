use aiken/builtin
use aiken/crypto.{blake2b_256}
use aiken/primitive/bytearray.{concat}
use bullet
use cardano/address.{Address, Inline, Script, VerificationKey}
use cardano/assets.{add, from_asset, from_lovelace, merge, zero}
use cardano/certificate.{RegisterCredential}
use cardano/script_context.{
  Minting, Publishing, ScriptContext, Spending, Withdrawing,
}
use cardano/transaction.{
  InlineDatum, Input, Mint, NoDatum, Output, OutputReference, Redeemer,
  Transaction, Withdraw,
}
use config
use prefix.{nonce_prefix}
use types.{AccountState, ColdVerification, Secp, Setup, Signed, Verification}
use utils.{dataify}

test setup_stake_bullet() {
  let account = Script("blargh_uuuug")

  let address = Address(Script("blue"), None)

  let expected_address =
    Address(Script(config.bullet_hash), Some(Inline(account)))

  let expected_nonce_address =
    Address(Script(config.nonce_bullet_hash), Some(Inline(account)))

  let expected_value =
    from_asset(config.bullet_hash, "blargh_uuuug", 1)
      |> merge(from_lovelace(10000))

  let expected_nonce_value =
    from_asset(
      config.bullet_hash,
      bytearray.concat(nonce_prefix, "blargh_uuuug"),
      1,
    )
      |> merge(from_lovelace(10000))

  let account_state =
    AccountState(Verification([], [], 1, 1), ColdVerification([], []))

  let nonce_state = 1

  let input =
    Input(
      config.new_user_tx_hash
        |> OutputReference(config.new_user_output_index),
      Output(address, zero, NoDatum, None),
    )

  let outputs =
    [
      Output(expected_address, expected_value, InlineDatum(account_state), None),
      Output(
        expected_nonce_address,
        expected_nonce_value,
        InlineDatum(nonce_state),
        None,
      ),
      Output(address, zero, InlineDatum([[], []]), None),
    ]

  let tx =
    Transaction { ..transaction.placeholder, inputs: [input], outputs: outputs }

  let sc =
    ScriptContext(tx, Setup, Publishing(0, RegisterCredential(account, Never)))

  bullet.stake_bullet.else(sc)
}

test setup_stake_bullet_ed25519() {
  let account = Script("blargh_uuuug")

  let address = Address(Script("blue"), None)

  let expected_address =
    Address(Script(config.bullet_hash), Some(Inline(account)))

  let expected_nonce_address =
    Address(Script(config.nonce_bullet_hash), Some(Inline(account)))

  let expected_value =
    from_asset(config.bullet_hash, "blargh_uuuug", 1)
      |> merge(from_lovelace(10000))

  let expected_nonce_value =
    from_asset(
      config.bullet_hash,
      bytearray.concat(nonce_prefix, "blargh_uuuug"),
      1,
    )
      |> merge(from_lovelace(10000))
  let public_key_hot =
    #"48b3fbaa5a3bed2a74d7ba688b983647686df8ae3896bb0a6a36fbc9b971a631"

  let public_key_cold =
    #"739a6a87d4df256a9caf84cd3fb5c9ed556a44cf0c10d4990c283176b8a8e1ed"

  let public_key_hot_hash = builtin.blake2b_224(public_key_hot)

  let public_key_cold_hash = builtin.blake2b_224(public_key_cold)

  let account_state =
    AccountState(
      Verification([Pair(public_key_hot_hash, public_key_hot)], [], 1, 1),
      ColdVerification([Pair(public_key_cold_hash, public_key_cold)], []),
    )

  let nonce_state = 1

  let input =
    Input(
      config.new_user_tx_hash
        |> OutputReference(config.new_user_output_index),
      Output(address, zero, NoDatum, None),
    )

  let outputs =
    [
      Output(expected_address, expected_value, InlineDatum(account_state), None),
      Output(
        expected_nonce_address,
        expected_nonce_value,
        InlineDatum(nonce_state),
        None,
      ),
      Output(address, zero, InlineDatum([[], []]), None),
    ]

  let extra_signatories = [public_key_hot_hash, public_key_cold_hash]

  let tx =
    Transaction {
      ..transaction.placeholder,
      inputs: [input],
      outputs: outputs,
      extra_signatories: extra_signatories,
    }

  let sc =
    ScriptContext(tx, Setup, Publishing(0, RegisterCredential(account, Never)))

  bullet.stake_bullet.else(sc)
}

test setup_stake_bullet_ecdsa() {
  let account = Script("blargh_uuuug")

  let address = Address(Script("blue"), None)

  let expected_address =
    Address(Script(config.bullet_hash), Some(Inline(account)))

  let expected_nonce_address =
    Address(Script(config.nonce_bullet_hash), Some(Inline(account)))

  let expected_value =
    from_asset(config.bullet_hash, "blargh_uuuug", 1)
      |> merge(from_lovelace(10000))

  let expected_nonce_value =
    from_asset(
      config.bullet_hash,
      bytearray.concat(nonce_prefix, "blargh_uuuug"),
      1,
    )
      |> merge(from_lovelace(10000))
  let public_key_hot =
    #"033384badff03326853c7140b9bdae0fdc6c46e6b34e8ef9425438da88ca51ec1d"

  let public_key_cold =
    #"03816fd397fa85fe96f2c911ba35de33a5501f25803900d7b378bbab359378c4ce"

  let account_state =
    AccountState(
      Verification([], [Secp(public_key_hot)], 1, 1),
      ColdVerification([], [Secp(public_key_cold)]),
    )

  let nonce_state = 1

  expect _message =
    config.new_user_tx_hash
      |> OutputReference(config.new_user_output_index)
      |> builtin.serialise_data()
      |> concat(config.namespace, _)
      |> blake2b_256()

  // trace @"TEST MESSAGE": message
  let input =
    Input(
      config.new_user_tx_hash
        |> OutputReference(config.new_user_output_index),
      Output(address, zero, NoDatum, None),
    )

  let outputs =
    [
      Output(expected_address, expected_value, InlineDatum(account_state), None),
      Output(
        expected_nonce_address,
        expected_nonce_value,
        InlineDatum(nonce_state),
        None,
      ),
      Output(
        address,
        zero,
        InlineDatum(
          [
            [
              #"28d2a3eb0f17a0e22acf330f1ec5a498bd6358908d7e795b38af403d62fac2b7627d6dc96dbf17dcf2e4fbf01be8d730a8a91020c3ae2f8e10109d7daa0a09cc",
            ],
            [
              #"36c26891f159fd944f50fdb752bea9062ee92c4c30bedeb6602d753d17adccd3503c1f057a9dd7078b457640928b14a36dd647cd953e348d81d258a60e7d1d5a",
            ],
          ],
        ),
        None,
      ),
    ]

  let tx =
    Transaction { ..transaction.placeholder, inputs: [input], outputs: outputs }

  let sc =
    ScriptContext(tx, Setup, Publishing(0, RegisterCredential(account, Never)))

  bullet.stake_bullet.else(sc)
}

test can_proxy_stake() {
  let account = Script("blargh_uuuug")

  let tx =
    Transaction {
      ..transaction.placeholder,
      redeemers: [
        Pair(Withdraw(Script(config.stake_proxy_hash)), dataify((account, []))),
      ],
    }

  let sc = ScriptContext(tx, Signed, Withdrawing(account))

  bullet.stake_bullet.else(sc)
}

test can_mint_bullet() {
  let name = "bleh_blah_bleh"

  let own_policy = "foo_blegghhh"

  let r: Redeemer = Setup
  let other: Redeemer = 0 |> Some
  let other2: Redeemer = 0

  let tx =
    Transaction {
      ..transaction.placeholder,
      mint: from_asset(own_policy, name, 1)
        |> merge(
            from_asset(own_policy, bytearray.concat(nonce_prefix, name), 1),
          ),
      redeemers: [
        Pair(Mint(#"aabbbcccddeeff"), other),
        Pair(Withdraw(Script(#"aabbbccc")), other2),
        Pair(Withdraw(Script(name)), r),
      ],
    }

  let sc = ScriptContext(tx, "555555", Minting(own_policy))

  bullet.bullet.else(sc)
}

test cant_mint_extra_bullet() fail {
  let name = "bleh_blah_bleh"

  let own_policy = "foo_blegghhh"

  let r: Redeemer = Setup
  let other: Redeemer = 0 |> Some
  let other2: Redeemer = 0

  let tx =
    Transaction {
      ..transaction.placeholder,
      mint: from_asset(own_policy, name, 1) |> add(own_policy, own_policy, 1),
      redeemers: [
        Pair(Mint(#"aabbbcccddeeff"), other),
        Pair(Withdraw(Script(#"aabbbccc")), other2),
        Pair(Withdraw(Script(name)), r),
      ],
    }

  let sc = ScriptContext(tx, "555555", Minting(own_policy))

  bullet.bullet.else(sc)
}

const sc = {
    let tx =
      Transaction {
        ..transaction.placeholder,
        withdrawals: [
          Pair(Script(config.proxy_hash), 1000000),
          Pair(Script(#"aabbbccc"), 0),
          Pair(VerificationKey(#"aabbbcccddeeff"), 0),
        ],
      }

    ScriptContext(tx, 0, Spending(OutputReference("ouch", 2), None))
  }

test can_spend_bullet() {
  bullet.bullet.else(sc)
}

test cant_steal_bullet() fail {
  let tx =
    Transaction {
      ..transaction.placeholder,
      withdrawals: [
        Pair(Script(#"aabbbccc"), 0),
        Pair(VerificationKey(#"aabbbcccddeeff"), 0),
      ],
    }

  let sc = ScriptContext(tx, 0, Spending(OutputReference("ouch", 2), None))

  !bullet.bullet.else(sc)
}

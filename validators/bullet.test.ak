use aiken/primitive/bytearray
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
use types.{AccountState, Nonce, Setup, Signed,Verification}
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

  let account_state = AccountState(1, [], Verification([]), [], Verification([]))

  let nonce_state = Nonce(1, "blargh_uuuug")

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
        |> merge(from_asset(own_policy, bytearray.concat(nonce_prefix, name), 1)),
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
          Pair(Script(#"aabbbccc"), 0),
          Pair(Script(config.proxy_hash), 1000000),
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

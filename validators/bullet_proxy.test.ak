use bullet_proxy
use cardano/address.{Address, Script}
use cardano/assets.{zero}
use cardano/transaction.{Input, NoDatum, Output, OutputReference, Transaction}
use config

test can_setup_stake() {
  let one_shot_ref =
    config.one_shot_tx_hash
      |> OutputReference(config.one_shot_output_index)

  let address = Address(Script("blue"), None)

  let input = Input(one_shot_ref, Output(address, zero, NoDatum, None))

  let tx = Transaction { ..transaction.placeholder, inputs: [input] }

  bullet_proxy.one_shot_proxy_mint.mint(0, "POKAMON", tx)
}

test cant_setup_stake_twice() {
  let one_shot_ref =
    config.one_shot_tx_hash
      |> OutputReference(config.one_shot_output_index + 1)

  let address = Address(Script("blue"), None)

  let input = Input(one_shot_ref, Output(address, zero, NoDatum, None))

  let tx = Transaction { ..transaction.placeholder, inputs: [input] }

  !bullet_proxy.one_shot_proxy_mint.mint(0, "POKAMON", tx)
}

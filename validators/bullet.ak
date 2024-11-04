use aiken/builtin
use aiken/collection/dict.{to_pairs}
use aiken/collection/list.{any}
use aiken/crypto.{Signature, blake2b_256}
use aiken/primitive/bytearray.{concat}
use cardano/address.{Address, Credential, Inline, Script}
use cardano/assets.{to_dict}
use cardano/script_context.{
  Minting, Publishing, ScriptContext, Spending, Voting, Withdrawing,
}
use cardano/transaction.{
  InlineDatum, Output, OutputReference, Redeemer, Transaction, Withdraw,
}
use config
use types.{AccountState, Setup, StakeActions}
use utils.{
  check_all_tx_observed, check_all_valid_vk_sigs, dataify, must_find_key,
  must_have,
}

// UserAccount =
// Address(Script("BULLET"), Some(Inline(Script("USER_SPECIFIC"))))

// UserAccount =
// Address(Script("BULLET"), Some(Inline(Script("TRUE_STAKE_KEY"))))

fn check_for_stake_proxy(tx: Transaction, credential: Data) {
  let proxy_cred = Withdraw(Script(config.stake_proxy_hash))

  let redeemer = must_find_key(tx.redeemers, proxy_cred)

  expect [cred, ..] = builtin.un_list_data(redeemer)

  cred == credential
}

/// Used as an example of how an always true 
/// stake key does not comprimise other user accounts
validator true_stake_bullet {
  else(_) {
    True
  }
}

/// Rely on proxy stake validator for all other validation besides setup
/// Handles user stake key actions including delegation, reward, and voting
validator stake_bullet {
  else(sc: ScriptContext) {
    let ScriptContext { transaction: tx, info, redeemer } = sc

    let unconstr = builtin.un_constr_data

    let cred =
      when info is {
        Withdrawing(cred) -> dataify(cred)
        // Seven is my lucky number 
        // Actually the first seven certificates have the certificate credential as the first field
        //  RegisterCredential {
        //   credential: Credential,
        //   deposit: Never,
        // }
        // UnregisterCredential {
        //   credential: Credential,
        //   refund: Never,
        // }
        // DelegateCredential { credential: Credential, delegate: Delegate }
        // RegisterAndDelegateCredential {
        //   credential: Credential,
        //   delegate: Delegate,
        //   deposit: Lovelace,
        // }
        // RegisterDelegateRepresentative {
        //   delegate_representative: Credential,
        //   deposit: Lovelace,
        // }
        // UpdateDelegateRepresentative { delegate_representative: Credential }
        // UnregisterDelegateRepresentative {
        //   delegate_representative: Credential,
        //   refund: Lovelace,
        // }
        Publishing { certificate, .. } -> {
          expect Pair(index, [cred, ..]) = unconstr(certificate)

          expect index < 7

          cred
        }
        // pub type Voter {
        //   ConstitutionalCommitteeMember(Credential)
        //   DelegateRepresentative(Credential)
        //   StakePool(VerificationKeyHash)
        // }
        Voting(voter) -> {
          expect Pair(index, [cred, ..]) = unconstr(voter)

          expect index < 2

          cred
        }
        _ -> fail
      }

    if redeemer == dataify(Setup) {
      let Transaction { inputs, outputs, withdrawals, extra_signatories, .. } =
        tx

      let one_shot_ref =
        config.new_user_tx_hash
          |> OutputReference(config.new_user_output_index)

      // This should come from a pub key anyway 
      // so this is fine to one time validate credentials are
      // valid
      let one_shot_message =
        one_shot_ref
          |> builtin.serialise_data()
          |> concat(config.name_space, _)
          |> blake2b_256()

      expect Script(own_hash) as account = cred

      // The reason I store sigs in the next output is to simplify the redeemer
      // And this is only run once per user so impact is minimal
      expect [
        Output { address, value, datum: InlineDatum(datum), .. },
        Output { datum: InlineDatum(sig_datum), .. },
        ..
      ] = outputs

      let expected_address =
        Address(Script(config.bullet_hash), Some(Inline(account)))

      let expected_value = [Pair(config.bullet_hash, [Pair(own_hash, 1)])]

      expect (hot_sigs, cold_sigs): (List<Signature>, List<Signature>) =
        sig_datum

      expect AccountState {
        quorum,
        hot_cred,
        hot_cred_hash,
        cold_cred,
        cold_cred_hash,
      } = datum

      expect [_, ..rest] = value |> to_dict |> to_pairs

      and {
        any(inputs, fn(input) { input.output_reference == one_shot_ref }),
        // Check for account state is setup correctly
        dataify(rest) == dataify(expected_value),
        address == expected_address,
        quorum > 0,
        check_all_valid_vk_sigs(hot_cred, hot_sigs, one_shot_message),
        check_all_valid_vk_sigs(cold_cred, cold_sigs, one_shot_message),
        check_all_tx_observed(hot_cred_hash, extra_signatories, withdrawals),
        check_all_tx_observed(cold_cred_hash, extra_signatories, withdrawals),
      }
    } else {
      check_for_stake_proxy(tx, cred)
    }
  }
}

validator stake_bullet_types {
  withdraw(_stake_action: StakeActions, _account, _tx) {
    fail
  }

  publish(_stake_action: StakeActions, _cert, _tx) {
    fail
  }

  vote(_stake_action: StakeActions, _vote, _tx) {
    fail
  }

  else(_) {
    fail
  }
}

fn check_for_proxy(
  withdrawals: Pairs<Credential, Int>,
  proxy_cred: Credential,
) -> Bool {
  expect [Pair(k, _), ..rest] = withdrawals

  proxy_cred == k || check_for_proxy(rest, proxy_cred)
}

validator bullet {
  else(sc: ScriptContext) {
    let ScriptContext { transaction: tx, info, .. } = sc

    when info is {
      // Main usage of bullet to spend utxos in a user account
      Spending { .. } ->
        check_for_proxy(tx.withdrawals, Script(config.proxy_hash))
      // Used to create a new validators acount
      Minting(own_policy) -> {
        let Transaction { mint, redeemers, .. } = tx

        expect [Pair(name, quantity)] =
          mint
            |> to_dict
            |> to_pairs
            |> must_find_key(own_policy)
            |> to_pairs

        or {
          quantity == -1,
          and {
            quantity == 1,
            {
              let script_purp = Withdraw(Script(name))
              let expected_action: Redeemer = Setup
              must_have(redeemers, Pair(script_purp, expected_action))
            },
          },
        }
      }
      _ -> fail
    }
  }
}

/// Types for bullet validator
validator bullet_types {
  spend(_d: Option<Data>, _r: Void, _o, _tx) {
    fail
  }

  mint(_r: Void, _o, _tx) {
    fail
  }

  else(_) {
    fail
  }
}

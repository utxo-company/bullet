# account-abstraction
A series of micro-validators for account abstraction that are called via a proxy contract to have the cheapest cost for a user.

## Building

```sh
./compile [Preview|Preprod|Mainnet]
```

## Configuring

To configure as a user, fill in the new user tx hash and output index.
Then follow the build process above.

**aiken.toml**
```toml
[config.preview]
bullet_hash = "<Generated>"
nonce_bullet_hash = "<Generated>"
proxy_hash = "<Generated>"
stake_proxy_hash = "<Generated>"
new_user_tx_hash = "<Fill in User Tx Hash>"
new_user_output_index = "<Fill in User Output Index>"
one_shot_tx_hash = "<Generated via Setup>"
one_shot_output_index = <Generated via Setup>
one_shot_mint_hash = "<Generated>"
namespace = "Bullet"
```

## Testing
To run all tests, simply do:

```sh
aiken check
```

To run only tests matching the string `foo`, do:

```sh
aiken check -m foo
```

## Documentation

The account abstraction validator set called Bullet uses a series of link validators to reduce script ref size costs as well as using efficient coding practices to have low tx cost for each action. The contract offers many levels of safety customized to each users needs. Below is a diagram of the validators and how they link together

![image](./ValidatorDependency.png)

The straight lines represent a validator parameterized by the hash of the other validator it points to.
The dashed lines represents a validator link via a global state held by a datum or token name that is equal to the hash of the validator being pointed to.

### Multisig
Bullet allows for any combination of Schnorr, Ecdsa, and Ed25519 private key/public key to be used. **Note that greater usages of many signatures will cost more mem and cpu units on chain.**

### Vault
Bullet enables users to specify utxos that protected from being used in DeFi. These utxos can only be spent via the wallet interface. This helps protect users against draining attacks or misusage by existing dApps.

As a side note this allows offchain indexers to track how much value Bullet users are utilizing dApps for versus which assets are stored in the vault. Thus this could be an indicator for DeFi health.


### Intentions

The first type you encounter is the outer type contains the user stake key hash, intent, bytearray wrapping, and signatures:
```aiken
pub type SignedIntention {
  user_stake: ScriptHash,
  intent: Intent,
  prefix: ByteArray,
  postfix: ByteArray,
  signatures: Data<List<Signature>>,
}
```

A user would sign the concatenation of prefix, intention, and postfix with their keys and add the signatures to the field

The prefix and postfix are for the wrapper bytes that tend to surround a message being signed by the wallet,
perhaps in the future this won't be needed.

Now peeling back a layer, an intent looks like this:

```aiken
pub type Intent {
  constraints: List<Constraint>
  value_leaving: List<(PolicyId, AssetName, Int)>,
  nonce: IntentNonce,
}
```
Here we have three important fields.

The constraints that are checked at runtime for the intention to be valid (in addition to the signature).

The value that can be spent from the users account when fulfilling the intent.

And finally the nonce to ensure each intent can only be used once.

TODO.


## Resources

Find more on the [Aiken's user manual](https://aiken-lang.org).
Discuss more about Bullet in in the [TxPipe Discord](https://discord.gg/RS77vh9kYJ).

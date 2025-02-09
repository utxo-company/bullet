import {
  CML,
  credentialToAddress,
  Data,
  datumToHash,
  Emulator,
  EmulatorAccount,
  fromText,
  generateEmulatorAccount,
  getAddressDetails,
  Lucid,
  LucidEvolution,
  paymentCredentialOf,
  toHex,
  toPublicKey,
  utxoToTransactionInput,
  utxoToTransactionOutput,
} from "@lucid-evolution/lucid";
import {
  bulletAddress,
  bulletMintPolicy,
  bulletNonceAddress,
  bulletNonceScript,
  bulletRewardAddress,
  bulletScript,
  bulletStakeHash,
  changeAuthHash,
  changeAuthRewardAddress,
  changeAuthScript,
  coldAuthHash,
  coldAuthRewardAddress,
  coldAuthScript,
  deleteHash,
  hotAuthHash,
  hotAuthRewardAddress,
  hotAuthScript,
  intentAuthHash,
  intentAuthRewardAddress,
  intentAuthScript,
  oneShotMintPolicy,
  oneShotMintScript,
  proxyAddress,
  proxyRewardAddress,
  proxyScript,
  stakeBulletScript,
  walletAuthHash,
  walletAuthRewardAddress,
  walletAuthScript,
} from "./bulletConsts";
import {
  AccountSpendType,
  BulletDatumType,
  ChangeCredType,
  HotAccountSpendType,
  ProxyRedeemerType,
  ProxyStateType,
  SigsDatumType,
  StakeBulletRedeemerType,
} from "./bulletTypes";
import { IntentionRedeemerType, IntentType } from "./intentTypes";
import { OutputRefType } from "./otherTypes";
import { CBORArray } from "@emurgo/cardano-message-signing-nodejs";

export async function setupBulletSecp() {
  // Initialize Lucid with Koios provider
  //
  // console.log(
  //   await generateEmulatorAccountFromPrivateKey({ lovelace: 1000000000n }),
  // );

  const initAccount: EmulatorAccount = {
    seedPhrase: "",
    address: "addr_test1vqdmhgdfartfju8f9drgn4cg7ur6qh7rwu4dr2cuk2umd7c3guqqn",
    assets: { lovelace: 1000000000n },
    privateKey:
      "ed25519_sk1dky9l0qac63d7nvaxgjjupze56n6fr9hvz5hzkjq5flznsx4jlmqnxnhw9",
  };

  const lucid = await Lucid(new Emulator([initAccount]), "Preview");

  lucid.selectWallet.fromPrivateKey(initAccount.privateKey);

  console.log("Time for the Global Setup of Bullet.");

  const oneShotDatum: ProxyStateType = {
    hotAuthContract: { Script: [hotAuthHash] },
    intentAuthContract: { Script: [intentAuthHash] },
    walletAuthContract: { Script: [walletAuthHash] },
    coldAuthContract: { Script: [coldAuthHash] },
    changeAuthContract: { Script: [changeAuthHash] },
    deleteAuthContract: { Script: [deleteHash] },
  };

  const globalSetupTx = await lucid
    .newTx()
    .mintAssets({ [oneShotMintPolicy]: 1n }, Data.void())
    .pay.ToContract(
      proxyAddress,
      {
        kind: "inline",
        value: Data.to(oneShotDatum, ProxyStateType),
      },
      { [oneShotMintPolicy]: 1n },
    )
    .pay.ToAddress(initAccount.address, { lovelace: 70000000n })
    .attach.MintingPolicy(oneShotMintScript)
    .complete();

  const globalSetupTxHash = await globalSetupTx.sign
    .withWallet()
    .complete()
    .then((t) => t.submit());

  await lucid.awaitTx(globalSetupTxHash);

  // Needed to parameterize the aiken.toml file
  console.log("Parameterize aiken.toml file with: ", globalSetupTxHash);

  const message: OutputRefType = { txId: globalSetupTxHash, outputIndex: 1n };

  console.log(
    "Message to sign is ",
    fromText("Bullet") + Data.to(message, OutputRefType),
  );

  const registerTx = await lucid
    .newTx()
    .collectFrom([(await lucid.utxosAt(initAccount.address))[1]])
    .register.Stake(bulletRewardAddress)
    .register.Stake(proxyRewardAddress)
    .register.Stake(hotAuthRewardAddress)
    .register.Stake(walletAuthRewardAddress)
    .register.Stake(coldAuthRewardAddress)
    .register.Stake(changeAuthRewardAddress)
    .register.Stake(intentAuthRewardAddress)
    .complete();

  const registerTxHash = await registerTx.sign
    .withWallet()
    .complete()
    .then((t) => t.submit());

  await lucid.awaitTx(registerTxHash);

  const stakeRed: StakeBulletRedeemerType = "Setup";

  const userPublicKey = toHex(
    CML.PublicKey.from_bech32(
      toPublicKey(initAccount.privateKey),
    ).to_raw_bytes(),
  );

  const userPayCred = paymentCredentialOf(initAccount.address);

  const controlDatum: BulletDatumType = {
    Control: {
      hotCred: {
        Verification: {
          ed25519_keys: new Map(),
          other_keys: [
            {
              Secp: [
                "021e060aa4a76b65c6508d79e6d67770ff5126d733a34e00405b11b70d0783c875",
              ],
            },
          ],
          hot_quorum: 1n,
          wallet_quorum: 1n,
        },
      },

      coldCred: {
        ColdVerification: {
          ed25519_keys: new Map([[userPayCred.hash, userPublicKey]]),
          other_keys: [],
        },
      },
    },
  };

  const sigDatum: SigsDatumType = [
    [
      "94638f274a462d413e45ba550d21dfc7b1a3d745c5a2975f09e6985c24d3287112df3630356ce559b4aa4cb09bbe912b24add6496428eb1d911613e99042692c",
    ],
    [],
  ];

  const newUserTx = await lucid
    .newTx()
    .collectFrom(await lucid.utxosAt(initAccount.address))
    .mintAssets(
      {
        [bulletMintPolicy + bulletStakeHash]: 1n,
        [bulletMintPolicy + "ffffffff" + bulletStakeHash]: 1n,
      },
      Data.void(),
    )
    .withdraw(
      bulletRewardAddress,
      0n,
      Data.to(stakeRed, StakeBulletRedeemerType),
    )
    .pay.ToContract(
      bulletAddress,
      { kind: "inline", value: Data.to(controlDatum, BulletDatumType) },
      { [bulletMintPolicy + bulletStakeHash]: 1n },
    )
    .pay.ToContract(
      bulletNonceAddress,
      {
        kind: "inline",
        value: Data.to(1n),
      },
      { [bulletMintPolicy + "ffffffff" + bulletStakeHash]: 1n },
    )
    .pay.ToAddressWithData(initAccount.address, {
      kind: "inline",
      value: Data.to(sigDatum, SigsDatumType),
    })
    // deposit to bullet no datum
    .pay.ToContract(bulletAddress, undefined, { lovelace: 50000000n })
    .pay.ToContract(
      bulletAddress,
      { kind: "inline", value: Data.to("Vault", BulletDatumType) },
      { lovelace: 54000000n },
    )
    .addSigner(initAccount.address)
    .attach.MintingPolicy(bulletScript)
    .attach.WithdrawalValidator(stakeBulletScript)
    .complete();

  const newUserTxHash = await newUserTx.sign
    .withWallet()
    .complete()
    .then((t) => t.submit());

  await lucid.awaitTx(newUserTxHash);

  console.log("Done Setup");

  return lucid;
}

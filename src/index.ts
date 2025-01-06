import {
  Lucid,
  Emulator,
  EmulatorAccount,
  Data,
  generatePrivateKey,
  toPublicKey,
  paymentCredentialOf,
  generateEmulatorAccountFromPrivateKey,
  CML,
  toHex,
  LucidEvolution,
  generateEmulatorAccount,
} from "@lucid-evolution/lucid";

import {
  BulletDatumType,
  ProxyStateType,
  SigsDatumType,
  StakeBulletRedeemerType,
} from "./bulletTypes";
import {
  bulletAddress,
  bulletMintPolicy,
  bulletNonceAddress,
  bulletRewardAddress,
  bulletScript,
  bulletStakeHash,
  changeAuthHash,
  coldAuthHash,
  deleteHash,
  hotAuthHash,
  intentAuthHash,
  oneShotMintPolicy,
  oneShotMintScript,
  proxyAddress,
  proxyRewardAddress,
  stakeBulletScript,
  walletAuthHash,
} from "./bulletConsts";

async function setupBullet() {
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

  console.log(lucid.wallet());

  console.log("Address is ", initAccount);

  console.log(await lucid.utxosAt(initAccount.address));

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
    .pay.ToAddress(initAccount.address, { lovelace: 60000000n })
    .attach.MintingPolicy(oneShotMintScript)
    .complete();

  const globalSetupTxHash = await globalSetupTx.sign
    .withWallet()
    .complete()
    .then((t) => t.submit());

  await lucid.awaitTx(globalSetupTxHash);

  console.log(await lucid.utxosAt(initAccount.address));

  const registerTx = await lucid
    .newTx()
    .collectFrom([(await lucid.utxosAt(initAccount.address))[1]])
    .register.Stake(bulletRewardAddress)
    .register.Stake(proxyRewardAddress)
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
      quorum: 1n,
      hotCred: [],
      hotCredHash: {
        Verification: [new Map([[userPayCred.hash, userPublicKey]])],
      },
      coldCred: [],
      coldCredHash: {
        Verification: [new Map([[userPayCred.hash, userPublicKey]])],
      },
    },
  };

  const sigDatum: SigsDatumType = [[], []];

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
    .pay.ToContract(bulletAddress, undefined, { lovelace: 50000000n })
    .addSigner(initAccount.address)
    .attach.MintingPolicy(bulletScript)
    .attach.WithdrawalValidator(stakeBulletScript)
    .complete();

  const newUserTxHash = await newUserTx.sign
    .withWallet()
    .complete()
    .then((t) => t.submit());

  await lucid.awaitTx(newUserTxHash);

  console.log(await lucid.utxosAt(bulletAddress));

  console.log(await lucid.utxosAt(proxyAddress));

  console.log("Done");

  return lucid;
}

async function spendHot(lucid: LucidEvolution) {
  const randomAccount = generateEmulatorAccount({ lovelace: 20000000n });

  const utxo = await lucid
    .utxosAt(bulletAddress)
    .then((l) => l.filter((u) => u.outputIndex === 3));

  const hotSpendTx = lucid
    .newTx()
    .collectFrom(utxo, Data.void())
    .pay.ToAddress(randomAccount.address, { lovelace: 3000000n })
    .addSigner(await lucid.wallet().address());
}

setupBullet()
  .then((l) => l)
  .catch(console.error);

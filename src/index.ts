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
  AccountSpendType,
  BulletDatumType,
  ChangeCredType,
  HotAccountSpendType,
  ProxyRedeemerType,
  ProxyStateType,
  SigsDatumType,
  StakeBulletRedeemerType,
} from "./bulletTypes";
import {
  bulletAddress,
  bulletMintPolicy,
  bulletNonceAddress,
  bulletNonceScript,
  bulletNonceValidator,
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

  const registerTx = await lucid
    .newTx()
    .collectFrom([(await lucid.utxosAt(initAccount.address))[1]])
    .register.Stake(bulletRewardAddress)
    .register.Stake(proxyRewardAddress)
    .register.Stake(hotAuthRewardAddress)
    .register.Stake(walletAuthRewardAddress)
    .register.Stake(coldAuthRewardAddress)
    .register.Stake(changeAuthRewardAddress)
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

async function hotSpend(lucid: LucidEvolution) {
  const randomAccount = generateEmulatorAccount({ lovelace: 20000000n });

  const utxo = await lucid
    .utxosAt(bulletAddress)
    .then((l) => l.filter((u) => u.outputIndex === 3));

  const utxo2 = await lucid
    .utxosAt(bulletAddress)
    .then((l) => l.filter((u) => u.outputIndex === 4));

  const refUserState = await lucid
    .utxosAt(bulletAddress)
    .then((l) => l.filter((u) => u.outputIndex === 0));

  const refGlobalState = await lucid.utxosAt(proxyAddress);

  const hotSpendRedeemer: HotAccountSpendType = {
    user_stake: bulletStakeHash,
    sigs: [],
  };

  const hotSpendTx = await lucid
    .newTx()
    .readFrom(refUserState)
    .readFrom(refGlobalState)
    .collectFrom(utxo, Data.void())
    // .collectFrom(utxo2, Data.void())
    .withdraw(proxyRewardAddress, 0n, Data.to("HotCred", ProxyRedeemerType))
    .withdraw(
      hotAuthRewardAddress,
      0n,
      Data.to(hotSpendRedeemer, HotAccountSpendType),
    )
    .pay.ToAddress(randomAccount.address, { lovelace: 3000000n })
    .addSigner(await lucid.wallet().address())
    .attach.SpendingValidator(bulletScript)
    .attach.WithdrawalValidator(proxyScript)
    .attach.WithdrawalValidator(hotAuthScript)
    .complete({ changeAddress: bulletAddress });

  const hotSpendTxHash = await hotSpendTx.sign
    .withWallet()
    .complete()
    .then((t) => t.submit());

  await lucid.awaitTx(hotSpendTxHash);

  console.log("Done HotSpend");
}

async function walletSpend(lucid: LucidEvolution) {
  const randomAccount = generateEmulatorAccount({ lovelace: 20000000n });

  const utxo = await lucid
    .utxosAt(bulletAddress)
    .then((l) => l.filter((u) => u.outputIndex === 3));

  const utxo2 = await lucid
    .utxosAt(bulletAddress)
    .then((l) => l.filter((u) => u.outputIndex === 4));

  const utxoNonce = await lucid.utxosAt(bulletNonceAddress);

  const refUserState = await lucid
    .utxosAt(bulletAddress)
    .then((l) => l.filter((u) => u.outputIndex === 0));

  const refGlobalState = await lucid.utxosAt(proxyAddress);

  const walletSpendRedeemer: AccountSpendType = {
    user_stake: bulletStakeHash,
    sigs: [],
    index: 1n,
  };

  const walletSpendTx = await lucid
    .newTx()
    .readFrom(refUserState)
    .readFrom(refGlobalState)
    .collectFrom(utxoNonce, Data.void())
    .collectFrom(utxo, Data.void())
    .collectFrom(utxo2, Data.void())
    .withdraw(proxyRewardAddress, 0n, Data.to("VaultSpend", ProxyRedeemerType))
    .withdraw(
      walletAuthRewardAddress,
      0n,
      Data.to(walletSpendRedeemer, AccountSpendType),
    )
    .pay.ToAddress(randomAccount.address, { lovelace: 3500000n })
    .pay.ToContract(
      bulletNonceAddress,
      { kind: "inline", value: Data.to(2n) },
      {
        [bulletMintPolicy + "ffffffff" + bulletStakeHash]: 1n,
      },
    )
    .addSigner(await lucid.wallet().address())
    .attach.SpendingValidator(bulletScript)
    .attach.WithdrawalValidator(proxyScript)
    .attach.WithdrawalValidator(walletAuthScript)
    .attach.SpendingValidator(bulletNonceScript)
    .complete({ changeAddress: bulletAddress });

  const walletSpendTxHash = await walletSpendTx.sign
    .withWallet()
    .complete()
    .then((t) => t.submit());

  await lucid.awaitTx(walletSpendTxHash);

  console.log("Done WalletSpend");
}

async function coldSpend(lucid: LucidEvolution) {
  const randomAccount = generateEmulatorAccount({ lovelace: 20000000n });

  const utxo = await lucid
    .utxosAt(bulletAddress)
    .then((l) => l.filter((u) => u.outputIndex === 3));

  const utxo2 = await lucid
    .utxosAt(bulletAddress)
    .then((l) => l.filter((u) => u.outputIndex === 4));

  const utxoNonce = await lucid.utxosAt(bulletNonceAddress);

  const refUserState = await lucid
    .utxosAt(bulletAddress)
    .then((l) => l.filter((u) => u.outputIndex === 0));

  const refGlobalState = await lucid.utxosAt(proxyAddress);

  const coldSpendRedeemer: AccountSpendType = {
    user_stake: bulletStakeHash,
    sigs: [],
    index: 1n,
  };

  const coldSpendTx = await lucid
    .newTx()
    .readFrom(refUserState)
    .readFrom(refGlobalState)
    .collectFrom(utxo, Data.void())
    .collectFrom(utxo2, Data.void())
    .collectFrom(utxoNonce, Data.void())
    .withdraw(proxyRewardAddress, 0n, Data.to("ColdCred", ProxyRedeemerType))
    .withdraw(
      coldAuthRewardAddress,
      0n,
      Data.to(coldSpendRedeemer, AccountSpendType),
    )
    .pay.ToAddress(randomAccount.address, { lovelace: 3800000n })
    .pay.ToContract(
      bulletNonceAddress,
      { kind: "inline", value: Data.to(2n) },
      {
        [bulletMintPolicy + "ffffffff" + bulletStakeHash]: 1n,
      },
    )
    .addSigner(await lucid.wallet().address())
    .attach.SpendingValidator(bulletScript)
    .attach.WithdrawalValidator(proxyScript)
    .attach.WithdrawalValidator(coldAuthScript)
    .attach.SpendingValidator(bulletNonceScript)
    .complete({ changeAddress: bulletAddress });

  const coldSpendTxHash = await coldSpendTx.sign
    .withWallet()
    .complete()
    .then((t) => t.submit());

  await lucid.awaitTx(coldSpendTxHash);

  console.log("Done ColdSpend");
}

async function changeAuth(lucid: LucidEvolution) {
  const randomAccount = generateEmulatorAccount({ lovelace: 20000000n });

  const utxo = await lucid
    .utxosAt(bulletAddress)
    .then((l) => l.filter((u) => u.outputIndex === 3));

  const utxo2 = await lucid
    .utxosAt(bulletAddress)
    .then((l) => l.filter((u) => u.outputIndex === 4));

  const utxoUserState = await lucid
    .utxosAt(bulletAddress)
    .then((l) => l.filter((u) => u.outputIndex === 0));

  const refGlobalState = await lucid.utxosAt(proxyAddress);

  const changeCredRedeemer: ChangeCredType = {
    control_index: 0n,
    user_stake: bulletStakeHash,
    cold_sigs: [],
    new_cold_sigs: [],
    new_hot_sigs: [],
    migration: false,
  };

  const changeAuthTx = await lucid
    .newTx()
    .collectFrom(utxoUserState)
    .readFrom(refGlobalState)
    .collectFrom(utxo, Data.void())
    .collectFrom(utxo2, Data.void())
    .withdraw(proxyRewardAddress, 0n, Data.to("ColdControl", ProxyRedeemerType))
    .withdraw(
      changeAuthRewardAddress,
      0n,
      Data.to(changeCredRedeemer, ChangeCredType),
    )
    .addSigner(await lucid.wallet().address())
    .attach.SpendingValidator(bulletScript)
    .attach.WithdrawalValidator(proxyScript)
    .attach.WithdrawalValidator(changeAuthScript)
    .complete({ changeAddress: bulletAddress });

  const changeAuthTxHash = await changeAuthTx.sign
    .withWallet()
    .complete()
    .then((t) => t.submit());

  await lucid.awaitTx(changeAuthTxHash);

  console.log("Done ChangeAuth");
}

setupBullet()
  .then((l) => hotSpend(l))
  .catch(console.error);

setupBullet()
  .then((l) => walletSpend(l))
  .catch(console.error);

setupBullet()
  .then((l) => coldSpend(l))
  .catch(console.error);

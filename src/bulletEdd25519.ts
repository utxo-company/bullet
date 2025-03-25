import {
  CML,
  credentialToAddress,
  Data,
  Emulator,
  EmulatorAccount,
  generateEmulatorAccount,
  getAddressDetails,
  Lucid,
  LucidEvolution,
  paymentCredentialOf,
  toHex,
  toPublicKey,
} from "@lucid-evolution/lucid";
import {
  bulletAddress,
  bulletMintPolicy,
  bulletNonceAddress,
  bulletNonceScript,
  bulletRewardAddress,
  bulletScript,
  bulletStakeHash,
  bulletValidator,
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

export async function setupBullet() {
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
          ed25519_keys: new Map([[userPayCred.hash, userPublicKey]]),
          other_keys: [],
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

export async function hotSpend(lucid: LucidEvolution) {
  const randomAccount = generateEmulatorAccount({ lovelace: 20000000n });

  const utxo = await lucid
    .utxosAt(bulletAddress)
    .then((l) => l.filter((u) => u.outputIndex === 3));

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

export async function walletSpend(lucid: LucidEvolution) {
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

export async function coldSpend(lucid: LucidEvolution) {
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

export async function changeAuth(lucid: LucidEvolution) {
  const newInitAccount: EmulatorAccount = {
    seedPhrase: "",
    address: "addr_test1vrammxt0w7kelznjmc49s73cs27k2lhnumpn40wkyfs58sqfwre47",
    assets: { lovelace: 1000000000n },
    privateKey:
      "ed25519_sk1stphv6l0ls6qs7nu2yve7xxs477ta7uul3z9csqrdz697a0xzsusdam0ap",
  };

  const newUserPayCred = paymentCredentialOf(newInitAccount.address);

  const newUserPk = toHex(
    CML.PublicKey.from_bech32(
      toPublicKey(newInitAccount.privateKey),
    ).to_raw_bytes(),
  );

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

  const controlDatum: BulletDatumType = {
    Control: {
      hotCred: {
        Verification: {
          ed25519_keys: new Map([[newUserPayCred.hash, newUserPk]]),
          other_keys: [],
          hot_quorum: 1n,
          wallet_quorum: 1n,
        },
      },

      coldCred: {
        ColdVerification: {
          ed25519_keys: new Map([[newUserPayCred.hash, newUserPk]]),
          other_keys: [],
        },
      },
    },
  };

  const changeAuthTx = await lucid
    .newTx()
    .readFrom(refGlobalState)
    .collectFrom([...utxo, ...utxo2, ...utxoUserState], Data.void())
    .pay.ToContract(
      bulletAddress,
      {
        kind: "inline",
        value: Data.to(controlDatum, BulletDatumType),
      },
      { [bulletMintPolicy + bulletStakeHash]: 1n },
    )
    .withdraw(proxyRewardAddress, 0n, Data.to("ColdControl", ProxyRedeemerType))
    .withdraw(
      changeAuthRewardAddress,
      0n,
      Data.to(changeCredRedeemer, ChangeCredType),
    )
    .addSigner(await lucid.wallet().address())
    .addSigner(newInitAccount.address)
    .attach.SpendingValidator(bulletScript)
    .attach.WithdrawalValidator(proxyScript)
    .attach.WithdrawalValidator(changeAuthScript)
    .complete({ changeAddress: bulletAddress });

  const changeAuthTxHash = await changeAuthTx.sign
    .withWallet()
    .sign.withPrivateKey(newInitAccount.privateKey)
    .complete()
    .then((t) => t.submit());

  await lucid.awaitTx(changeAuthTxHash);

  console.log("Done ChangeAuth");
}

export async function intentSpend(lucid: LucidEvolution) {
  const randomAccount = generateEmulatorAccount({ lovelace: 20000000n });

  const utxo = await lucid
    .utxosAt(bulletAddress)
    .then((l) => l.filter((u) => u.outputIndex === 3));

  const utxoNonce = await lucid.utxosAt(bulletNonceAddress);

  const refUserState = await lucid
    .utxosAt(bulletAddress)
    .then((l) => l.filter((u) => u.outputIndex === 0));

  const refGlobalState = await lucid.utxosAt(proxyAddress);

  const intent: IntentType = {
    constraints: [
      {
        OutConNil: [
          {
            address: {
              SomeTwo: [
                {
                  VerificationKey: [
                    paymentCredentialOf(randomAccount.address).hash,
                  ],
                },
              ],
            },
            value: "Nada",
            datum: "Nada",
            ref: "Nope",
          },
        ],
      },
    ],
    nonce: { Sequential: [1n] },
    valueLeaving: [5000000n, new Map()],
    userStake: getAddressDetails(bulletAddress).stakeCredential!.hash,
  };

  const intentMessage = Data.to(intent, IntentType);

  const miniTx = await lucid
    .newTx()
    .collectFrom([
      {
        address: randomAccount.address,
        assets: { lovelace: 1800000n },
        txHash:
          "d6ad0a886fa731d0c5571ec673214bd90f1eeabd5d5ed3f5e4c942e32e9ef6b7",
        outputIndex: 0,
      },
    ])
    .pay.ToAddressWithData(
      credentialToAddress(
        "Preview",
        getAddressDetails(randomAccount.address).paymentCredential!,
      ),
      {
        kind: "inline",
        value: intentMessage,
      },
    )
    .complete({ coinSelection: false, includeLeftoverLovelaceAsFee: true });

  const output = miniTx.toTransaction().body().outputs().get(0);

  output.set_amount(CML.Value.from_coin(0n));

  const outputs = CML.TransactionOutputList.new();

  outputs.add(output);

  const miniTxCompress = lucid.fromTx(
    CML.Transaction.new(
      CML.TransactionBody.new(CML.TransactionInputList.new(), outputs, 0n),
      CML.TransactionWitnessSet.new(),
      true,
    ).to_cbor_hex(),
  );

  const miniTxBytes = miniTxCompress.toCBOR();

  // console.log(miniTxBytes);

  const parts = miniTxBytes.split(intentMessage);
  const prefix = parts[0];
  const postfix = parts[1];

  const signature = (await miniTxCompress.sign.withWallet().complete())
    .toTransaction()
    .witness_set()
    .vkeywitnesses()!
    .get(0)
    .ed25519_signature()
    .to_hex();

  const intentSpendRedeemer: IntentionRedeemerType = {
    constraintOutput: 0n,
    changeOutput: 1n,
    constraintRedeemer: 0n,
    intentionGroups: [""],
    intentions: [
      {
        intent,
        prefix,
        postfix,
        signatures: [signature],
      },
    ],
  };

  const intentSpendTx = await lucid
    .newTx()
    .readFrom(refUserState)
    .readFrom(refGlobalState)
    .collectFrom([...utxo, ...utxoNonce], Data.void())
    .withdraw(proxyRewardAddress, 0n, Data.to("Intention", ProxyRedeemerType))
    .withdraw(
      intentAuthRewardAddress,
      0n,
      Data.to(intentSpendRedeemer, IntentionRedeemerType),
    )
    .pay.ToAddress(randomAccount.address, { lovelace: 5000000n - 1000000n })
    .pay.ToContract(
      bulletNonceAddress,
      { kind: "inline", value: Data.to(2n) },
      {
        [bulletMintPolicy + "ffffffff" + bulletStakeHash]: 1n,
      },
    )
    .attach.SpendingValidator(bulletScript)
    .attach.WithdrawalValidator(proxyScript)
    .attach.WithdrawalValidator(intentAuthScript)
    .attach.SpendingValidator(bulletNonceScript)
    .complete({ changeAddress: bulletAddress });

  // console.log(intentSpendTx.toCBOR());

  const intentSpendTxHash = await intentSpendTx.sign
    .withWallet()
    .complete()
    .then((t) => t.submit());

  await lucid.awaitTx(intentSpendTxHash);

  console.log("Done IntentSpend");
}

export async function intentSpend2(lucid: LucidEvolution) {
  const randomAccount = generateEmulatorAccount({ lovelace: 20000000n });

  const utxo = await lucid
    .utxosAt(bulletAddress)
    .then((l) => l.filter((u) => u.outputIndex === 3));

  const utxoNonce = await lucid.utxosAt(bulletNonceAddress);

  const refUserState = await lucid
    .utxosAt(bulletAddress)
    .then((l) => l.filter((u) => u.outputIndex === 0));

  const refGlobalState = await lucid.utxosAt(proxyAddress);

  const intent: IntentType = {
    constraints: [
      {
        OutConNil: [
          {
            address: {
              SomeTwo: [
                {
                  VerificationKey: [
                    paymentCredentialOf(randomAccount.address).hash,
                  ],
                },
              ],
            },
            value: "Nada",
            datum: "Nada",
            ref: "Nope",
          },
        ],
      },
    ],
    nonce: { Sequential: [1n] },
    valueLeaving: [5000000n, new Map()],
    userStake: getAddressDetails(bulletAddress).stakeCredential!.hash,
  };

  const intentMessage = Data.to(intent, IntentType);

  const miniTx = await lucid
    .newTx()
    .collectFrom([
      {
        address: randomAccount.address,
        assets: { lovelace: 1500000n },
        txHash:
          "d6ad0a886fa731d0c5571ec673214bd90f1eeabd5d5ed3f5e4c942e32e9ef6b7",
        outputIndex: 0,
      },
    ])
    .pay.ToAddressWithData(
      credentialToAddress(
        "Preview",
        getAddressDetails(randomAccount.address).paymentCredential!,
      ),
      {
        kind: "inline",
        value: intentMessage,
      },
    )
    .complete({ coinSelection: false, includeLeftoverLovelaceAsFee: true });

  const output = miniTx.toTransaction().body().outputs().get(0);

  output.set_amount(CML.Value.from_coin(0n));

  const outputs = CML.TransactionOutputList.new();

  outputs.add(output);

  const miniTxCompress = lucid.fromTx(
    CML.Transaction.new(
      CML.TransactionBody.new(CML.TransactionInputList.new(), outputs, 0n),
      CML.TransactionWitnessSet.new(),
      true,
    ).to_cbor_hex(),
  );

  const miniTxBytes = miniTxCompress.toCBOR();

  // console.log(miniTxBytes);

  const parts = miniTxBytes.split(intentMessage);
  const prefix = parts[0];
  const postfix = parts[1];

  const signature = (await miniTxCompress.sign.withWallet().complete())
    .toTransaction()
    .witness_set()
    .vkeywitnesses()!
    .get(0)
    .ed25519_signature()
    .to_hex();

  const intentSpendRedeemer: IntentionRedeemerType = {
    constraintOutput: 0n,
    changeOutput: 1n,
    constraintRedeemer: 0n,
    intentionGroups: [""],
    intentions: [
      {
        intent,
        prefix,
        postfix,
        signatures: [signature],
      },
    ],
  };

  const intentSpendTx = await lucid
    .newTx()
    .readFrom(refUserState)
    .readFrom(refGlobalState)
    .collectFrom([...utxo, ...utxoNonce], Data.void())
    .withdraw(proxyRewardAddress, 0n, Data.to("Intention", ProxyRedeemerType))
    .withdraw(
      intentAuthRewardAddress,
      0n,
      Data.to(intentSpendRedeemer, IntentionRedeemerType),
    )
    .pay.ToAddress(randomAccount.address, { lovelace: 5000000n - 1000000n })
    .pay.ToContract(
      bulletNonceAddress,
      { kind: "inline", value: Data.to(2n) },
      {
        [bulletMintPolicy + "ffffffff" + bulletStakeHash]: 1n,
      },
    )
    .attach.SpendingValidator(bulletScript)
    .attach.WithdrawalValidator(proxyScript)
    .attach.WithdrawalValidator(intentAuthScript)
    .attach.SpendingValidator(bulletNonceScript)
    .complete({ changeAddress: bulletAddress });

  // console.log(intentSpendTx.toCBOR());

  const intentSpendTxHash = await intentSpendTx.sign
    .withWallet()
    .complete()
    .then((t) => t.submit());

  await lucid.awaitTx(intentSpendTxHash);

  console.log("Done IntentSpend");
}

export async function setupBulletMainnet() {
  // Initialize Lucid with Koios provider
  //
  // console.log(
  //   await generateEmulatorAccountFromPrivateKey({ lovelace: 1000000000n }),
  // );

  const emulator = new Emulator([]);

  // emulator.ledger = {
  //   ["89618f8648db0e830dd3b5b6631c46b71360ccd9b64b9c9510486284cf44ba7800"]: {
  //     spent: false,
  //     utxo: {
  //       address:
  //         "addr1q9venhxereqm8exzhgphagas8kuguwa9vev4zc086ulg275tacf8lywukau5xvyy2z9dt6ttul4487htpgjruq0rynhslp3xgv",
  //       assets: { ["lovelace"]: 2617582313n },
  //       outputIndex: 0,
  //       txHash:
  //         "89618f8648db0e830dd3b5b6631c46b71360ccd9b64b9c9510486284cf44ba78",
  //     },
  //   },
  // };

  const lucid = await Lucid(emulator, "Mainnet");

  lucid.selectWallet.fromAddress(
    "addr1q9venhxereqm8exzhgphagas8kuguwa9vev4zc086ulg275tacf8lywukau5xvyy2z9dt6ttul4487htpgjruq0rynhslp3xgv",
    [
      {
        address:
          "addr1q9venhxereqm8exzhgphagas8kuguwa9vev4zc086ulg275tacf8lywukau5xvyy2z9dt6ttul4487htpgjruq0rynhslp3xgv",
        assets: { ["lovelace"]: 2545441528n },
        txHash:
          "ba4b9fb110ef328f84f080f277af89e3c40a8bc3aa64eb1605e445f3b7f293b7",
        outputIndex: 2,
      },
    ],
  );

  console.log("Time for the Global Setup of Bullet.");

  // const oneShotDatum: ProxyStateType = {
  //   hotAuthContract: { Script: [hotAuthHash] },
  //   intentAuthContract: { Script: [intentAuthHash] },
  //   walletAuthContract: { Script: [walletAuthHash] },
  //   coldAuthContract: { Script: [coldAuthHash] },
  //   changeAuthContract: { Script: [changeAuthHash] },
  //   deleteAuthContract: { Script: [deleteHash] },
  // };

  // const globalSetupTx = await lucid
  //   .newTx()
  //   .mintAssets({ [oneShotMintPolicy]: 1n }, Data.void())
  //   .pay.ToContract(
  //     proxyAddress,
  //     {
  //       kind: "inline",
  //       value: Data.to(oneShotDatum, ProxyStateType),
  //     },
  //     { [oneShotMintPolicy]: 1n },
  //   )
  //   .pay.ToAddress(await lucid.wallet().address(), { lovelace: 70000000n })
  //   .attach.MintingPolicy(oneShotMintScript)
  //   .complete();

  // const globalSetupTxHash = await globalSetupTx.sign
  //   .withWallet()
  //   .complete()
  //   .then((t) => t.submit());

  // await lucid.awaitTx(globalSetupTxHash);

  // Needed to parameterize the aiken.toml file
  // console.log("Parameterize aiken.toml file with: ", globalSetupTxHash);

  const myAddress = await lucid.wallet().address();

  const registerTx = await lucid
    .newTx()
    .register.Stake(bulletRewardAddress)
    .register.Stake(proxyRewardAddress)
    .register.Stake(hotAuthRewardAddress)
    .register.Stake(walletAuthRewardAddress)
    .register.Stake(coldAuthRewardAddress)
    .register.Stake(changeAuthRewardAddress)
    .register.Stake(intentAuthRewardAddress)
    .pay.ToAddressWithData(myAddress, undefined, undefined, bulletScript)
    .pay.ToAddressWithData(myAddress, undefined, undefined, proxyScript)
    .pay.ToAddressWithData(myAddress, undefined, undefined, hotAuthScript)
    .pay.ToAddressWithData(myAddress, undefined, undefined, walletAuthScript)
    .pay.ToAddressWithData(myAddress, undefined, undefined, coldAuthScript)
    .pay.ToAddressWithData(myAddress, undefined, undefined, changeAuthScript)
    .pay.ToAddressWithData(myAddress, undefined, undefined, intentAuthScript)
    .complete();

  console.log("CBOR IS ", registerTx.toCBOR());

  // const registerTxHash = await registerTx.sign
  //   .withWallet()
  //   .complete()
  //   .then((t) => t.submit());

  // await lucid.awaitTx(registerTxHash);

  // const stakeRed: StakeBulletRedeemerType = "Setup";

  // const userPublicKey = toHex(
  //   CML.PublicKey.from_bech32(
  //     toPublicKey(initAccount.privateKey),
  //   ).to_raw_bytes(),
  // );

  // const userPayCred = paymentCredentialOf(initAccount.address);

  // const controlDatum: BulletDatumType = {
  //   Control: {
  //     hotCred: {
  //       Verification: {
  //         ed25519_keys: new Map([[userPayCred.hash, userPublicKey]]),
  //         other_keys: [],
  //         hot_quorum: 1n,
  //         wallet_quorum: 1n,
  //       },
  //     },

  //     coldCred: {
  //       ColdVerification: {
  //         ed25519_keys: new Map([[userPayCred.hash, userPublicKey]]),
  //         other_keys: [],
  //       },
  //     },
  //   },
  // };

  // const sigDatum: SigsDatumType = [[], []];

  // const newUserTx = await lucid
  //   .newTx()
  //   .collectFrom(await lucid.utxosAt(initAccount.address))
  //   .mintAssets(
  //     {
  //       [bulletMintPolicy + bulletStakeHash]: 1n,
  //       [bulletMintPolicy + "ffffffff" + bulletStakeHash]: 1n,
  //     },
  //     Data.void(),
  //   )
  //   .withdraw(
  //     bulletRewardAddress,
  //     0n,
  //     Data.to(stakeRed, StakeBulletRedeemerType),
  //   )
  //   .pay.ToContract(
  //     bulletAddress,
  //     { kind: "inline", value: Data.to(controlDatum, BulletDatumType) },
  //     { [bulletMintPolicy + bulletStakeHash]: 1n },
  //   )
  //   .pay.ToContract(
  //     bulletNonceAddress,
  //     {
  //       kind: "inline",
  //       value: Data.to(1n),
  //     },
  //     { [bulletMintPolicy + "ffffffff" + bulletStakeHash]: 1n },
  //   )
  //   .pay.ToAddressWithData(initAccount.address, {
  //     kind: "inline",
  //     value: Data.to(sigDatum, SigsDatumType),
  //   })
  //   // deposit to bullet no datum
  //   .pay.ToContract(bulletAddress, undefined, { lovelace: 50000000n })
  //   .pay.ToContract(
  //     bulletAddress,
  //     { kind: "inline", value: Data.to("Vault", BulletDatumType) },
  //     { lovelace: 54000000n },
  //   )
  //   .addSigner(initAccount.address)
  //   .attach.MintingPolicy(bulletScript)
  //   .attach.WithdrawalValidator(stakeBulletScript)
  //   .complete();

  // const newUserTxHash = await newUserTx.sign
  //   .withWallet()
  //   .complete()
  //   .then((t) => t.submit());

  // await lucid.awaitTx(newUserTxHash);

  // console.log("Done Setup");

  // return lucid;
}

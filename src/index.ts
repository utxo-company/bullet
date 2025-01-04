import {
  Lucid,
  Emulator,
  generateEmulatorAccount,
  addressFromHexOrBech32,
  validatorToAddress,
  validatorToScriptHash,
  MintingPolicy,
  Data,
  datumJsonToCbor,
} from "@lucid-evolution/lucid";
import scripts from "../plutus.json";
import { ProxyStateType } from "./bulletTypes";

async function main() {
  // Initialize Lucid with Koios provider
  const initAccount = generateEmulatorAccount({ lovelace: 1_000_000_000n });

  const lucid = await Lucid(new Emulator([initAccount]), "Preview");
  lucid.selectWallet.fromSeed(initAccount.seedPhrase);

  console.log(lucid.wallet());

  const bulletValidator = scripts.validators.find(
    (v) => v.title === "bullet.bullet.else",
  )!.compiledCode;

  const stakeBulletValidator = scripts.validators.find(
    (v) => v.title === "bullet.stake_bullet.else",
  )!.compiledCode;

  const oneShotMintValidator = scripts.validators.find(
    (v) => v.title === "bullet_proxy.one_shot_proxy_mint.mint",
  )!.compiledCode;

  const oneShotMintScript: MintingPolicy = {
    type: "PlutusV3",
    script: oneShotMintValidator,
  };

  const oneShotAddress = validatorToAddress("Preview", oneShotMintScript);

  const oneShotMintPolicy = validatorToScriptHash(oneShotMintScript);

  console.log("Address is ", initAccount);

  console.log(await lucid.utxosAt(initAccount.address));

  console.log("Time for the Global Setup of Bullet.");

  const oneShotDatum: ProxyStateType = {
    hotAuthContract: { Script: [oneShotMintPolicy] },
    intentAuthContract: { Script: [oneShotMintPolicy] },
    walletAuthContract: { Script: [oneShotMintPolicy] },
    coldAuthContract: { Script: [oneShotMintPolicy] },
    changeAuthContract: { Script: [oneShotMintPolicy] },
    deleteAuthContract: { Script: [oneShotMintPolicy] },
  };

  const globalSetupTx = lucid
    .newTx()
    .mintAssets({ [oneShotMintPolicy]: 1n }, Data.void())
    .pay.ToContract(
      oneShotAddress,
      {
        kind: "inline",
        value: Data.to(oneShotDatum, ProxyStateType),
      },
      { [oneShotMintPolicy]: 1n },
    )
    .attach.MintingPolicy(oneShotMintScript)
    .complete();

  const globalSetupTxHash = await (
    await (await globalSetupTx).sign.withWallet().complete()
  ).submit();

  await lucid.awaitTx(globalSetupTxHash);

  console.log("Done");
}

main().catch(console.error);

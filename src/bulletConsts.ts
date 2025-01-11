import {
  CertificateValidator,
  credentialToRewardAddress,
  MintingPolicy,
  scriptHashToCredential,
  SpendingValidator,
  validatorToAddress,
  validatorToRewardAddress,
  validatorToScriptHash,
  VoteValidator,
  WithdrawalValidator,
} from "@lucid-evolution/lucid";
import scripts from "../plutus.json";

export const bulletValidator = scripts.validators.find(
  (v) => v.title === "bullet.bullet.else",
)!.compiledCode;

export const stakeBulletValidator = scripts.validators.find(
  (v) => v.title === "bullet.stake_bullet.else",
)!.compiledCode;

export const oneShotMintValidator = scripts.validators.find(
  (v) => v.title === "bullet_proxy.one_shot_proxy_mint.mint",
)!.compiledCode;

export const proxyValidator = scripts.validators.find(
  (v) => v.title === "bullet_proxy.proxy_spend.else",
)!.compiledCode;

export const walletStakeValidator = scripts.validators.find(
  (v) => v.title === "stake_auth.wallet_stake.else",
)!.compiledCode;

export const hotAuthValidator = scripts.validators.find(
  (v) => v.title === "hot_auth.hot_spend.else",
)!.compiledCode;

export const intentAuthValidator = scripts.validators.find(
  (v) => v.title === "intention_auth.intent_spend.else",
)!.compiledCode;

export const walletAuthValidator = scripts.validators.find(
  (v) => v.title === "wallet_auth.wallet_spend.else",
)!.compiledCode;

export const coldAuthValidator = scripts.validators.find(
  (v) => v.title === "cold_auth.cold_spend.else",
)!.compiledCode;

export const changeAuthValidator = scripts.validators.find(
  (v) => v.title === "change_credential_auth.cold_control.else",
)!.compiledCode;

export const deleteValidator = scripts.validators.find(
  (v) => v.title === "delete_auth.delete_account.else",
)!.compiledCode;

export const bulletNonceValidator = scripts.validators.find(
  (v) => v.title === "bullet.bullet_nonce.else",
)!.compiledCode;

export const oneShotMintScript: MintingPolicy = {
  type: "PlutusV3",
  script: oneShotMintValidator,
};

export const bulletScript: SpendingValidator | MintingPolicy = {
  type: "PlutusV3",
  script: bulletValidator,
};

export const stakeBulletScript:
  | WithdrawalValidator
  | CertificateValidator
  | VoteValidator = {
  type: "PlutusV3",
  script: stakeBulletValidator,
};

export const proxyScript: WithdrawalValidator = {
  type: "PlutusV3",
  script: proxyValidator,
};
export const walletStakeScript: WithdrawalValidator = {
  type: "PlutusV3",
  script: walletStakeValidator,
};

export const hotAuthScript: WithdrawalValidator = {
  type: "PlutusV3",
  script: hotAuthValidator,
};

export const intentAuthScript: WithdrawalValidator = {
  type: "PlutusV3",
  script: intentAuthValidator,
};

export const walletAuthScript: WithdrawalValidator = {
  type: "PlutusV3",
  script: walletAuthValidator,
};

export const coldAuthScript: WithdrawalValidator = {
  type: "PlutusV3",
  script: coldAuthValidator,
};

export const changeAuthScript: WithdrawalValidator = {
  type: "PlutusV3",
  script: changeAuthValidator,
};

export const deleteScript: WithdrawalValidator = {
  type: "PlutusV3",
  script: deleteValidator,
};

export const bulletNonceScript: SpendingValidator = {
  type: "PlutusV3",
  script: bulletNonceValidator,
};

export const proxyAddress = validatorToAddress("Preview", proxyScript);

export const proxyRewardAddress = validatorToRewardAddress(
  "Preview",
  proxyScript,
);

export const proxyHash = validatorToScriptHash(proxyScript);

export const walletStakeHash = validatorToScriptHash(walletStakeScript);

export const oneShotMintPolicy = validatorToScriptHash(oneShotMintScript);

export const bulletStakeHash = validatorToScriptHash(stakeBulletScript);

export const bulletStakeCred = scriptHashToCredential(bulletStakeHash);

export const bulletNonceHash = validatorToScriptHash(bulletNonceScript);

export const bulletNonceCred = scriptHashToCredential(bulletNonceHash);

export const bulletRewardAddress = credentialToRewardAddress(
  "Preview",
  bulletStakeCred,
);

export const bulletAddress = validatorToAddress(
  "Preview",
  bulletScript,
  bulletStakeCred,
);

export const bulletNonceAddress = validatorToAddress(
  "Preview",
  bulletNonceScript,
  bulletStakeCred,
);

export const bulletMintPolicy = validatorToScriptHash(bulletScript);

export const hotAuthHash = validatorToScriptHash(hotAuthScript);

export const intentAuthHash = validatorToScriptHash(intentAuthScript);

export const walletAuthHash = validatorToScriptHash(walletAuthScript);

export const coldAuthHash = validatorToScriptHash(coldAuthScript);

export const changeAuthHash = validatorToScriptHash(changeAuthScript);

export const deleteHash = validatorToScriptHash(deleteScript);

export const hotAuthRewardAddress = validatorToRewardAddress(
  "Preview",
  hotAuthScript,
);

export const walletAuthRewardAddress = validatorToRewardAddress(
  "Preview",
  walletAuthScript,
);

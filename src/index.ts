import {
  changeAuth,
  coldSpend,
  hotSpend,
  intentSpend,
  setupBullet,
  walletSpend,
} from "./bulletEdd25519";

import { setupBulletSecp } from "./bulletSecp256k1";

setupBullet()
  .then((l) => hotSpend(l))
  .catch(console.error);

setupBullet()
  .then((l) => walletSpend(l))
  .catch(console.error);

setupBullet()
  .then((l) => coldSpend(l))
  .catch(console.error);

setupBullet()
  .then((l) => changeAuth(l))
  .catch(console.error);

setupBullet()
  .then((l) => intentSpend(l))
  .catch(console.error);

setupBulletSecp().catch(console.error);

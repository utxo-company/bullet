import {
  Address,
  fromHex,
  getAddressDetails,
  Payload,
  RewardAddress,
  toHex,
} from "@lucid-evolution/lucid";
import * as M from "@emurgo/cardano-message-signing-nodejs";

export function signedDataBytes(
  address: Address | RewardAddress,
  payload: Payload,
): Payload {
  const {
    address: { hex: hexAddress },
  } = getAddressDetails(address);

  const protectedHeaders = M.HeaderMap.new();
  protectedHeaders.set_algorithm_id(
    M.Label.from_algorithm_id(M.AlgorithmId.EdDSA),
  );
  protectedHeaders.set_header(
    M.Label.new_text("address"),
    M.CBORValue.new_bytes(fromHex(hexAddress)),
  );
  const protectedSerialized = M.ProtectedHeaderMap.new(protectedHeaders);
  const unprotectedHeaders = M.HeaderMap.new();
  const headers = M.Headers.new(protectedSerialized, unprotectedHeaders);
  const builder = M.COSESign1Builder.new(headers, fromHex(payload), false);
  const toSign = builder.make_data_to_sign().to_bytes();

  return toHex(toSign);
}

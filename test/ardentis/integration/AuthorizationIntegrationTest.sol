// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "../BaseTest.sol";

contract AuthorizationIntegrationTest is BaseTest {
  function testSetAuthorization(address addressFuzz) public {
    vm.assume(addressFuzz != address(this));

    ardentis.setAuthorization(addressFuzz, true);

    assertTrue(ardentis.isAuthorized(address(this), addressFuzz));

    ardentis.setAuthorization(addressFuzz, false);

    assertFalse(ardentis.isAuthorized(address(this), addressFuzz));
  }

  function testAlreadySet(address addressFuzz) public {
    vm.expectRevert(bytes(ErrorsLib.ALREADY_SET));
    ardentis.setAuthorization(addressFuzz, false);

    ardentis.setAuthorization(addressFuzz, true);

    vm.expectRevert(bytes(ErrorsLib.ALREADY_SET));
    ardentis.setAuthorization(addressFuzz, true);
  }

  function testSetAuthorizationWithSignatureDeadlineOutdated(
    Authorization memory authorization,
    uint256 privateKey,
    uint256 blocks
  ) public {
    authorization.isAuthorized = true;
    blocks = _boundBlocks(blocks);
    authorization.deadline = block.timestamp - 1;

    // Private key must be less than the secp256k1 curve order.
    privateKey = bound(privateKey, 1, type(uint32).max);
    authorization.nonce = 0;
    authorization.authorizer = vm.addr(privateKey);

    Signature memory sig;
    bytes32 digest = SigUtils.getTypedDataHash(ardentis.domainSeparator(), authorization);
    (sig.v, sig.r, sig.s) = vm.sign(privateKey, digest);

    _forward(blocks);

    vm.expectRevert(bytes(ErrorsLib.SIGNATURE_EXPIRED));
    ardentis.setAuthorizationWithSig(authorization, sig);
  }

  function testAuthorizationWithSigWrongPK(Authorization memory authorization, uint256 privateKey) public {
    authorization.isAuthorized = true;
    authorization.deadline = bound(authorization.deadline, block.timestamp, type(uint256).max);

    // Private key must be less than the secp256k1 curve order.
    privateKey = bound(privateKey, 1, type(uint32).max);
    authorization.nonce = 0;

    Signature memory sig;
    bytes32 digest = SigUtils.getTypedDataHash(ardentis.domainSeparator(), authorization);
    (sig.v, sig.r, sig.s) = vm.sign(privateKey, digest);

    vm.expectRevert(bytes(ErrorsLib.INVALID_SIGNATURE));
    ardentis.setAuthorizationWithSig(authorization, sig);
  }

  function testAuthorizationWithSigWrongNonce(Authorization memory authorization, uint256 privateKey) public {
    authorization.isAuthorized = true;
    authorization.deadline = bound(authorization.deadline, block.timestamp, type(uint256).max);
    authorization.nonce = bound(authorization.nonce, 1, type(uint256).max);

    // Private key must be less than the secp256k1 curve order.
    privateKey = bound(privateKey, 1, type(uint32).max);
    authorization.authorizer = vm.addr(privateKey);

    Signature memory sig;
    bytes32 digest = SigUtils.getTypedDataHash(ardentis.domainSeparator(), authorization);
    (sig.v, sig.r, sig.s) = vm.sign(privateKey, digest);

    vm.expectRevert(bytes(ErrorsLib.INVALID_NONCE));
    ardentis.setAuthorizationWithSig(authorization, sig);
  }

  function testAuthorizationWithSig(Authorization memory authorization, uint256 privateKey) public {
    authorization.isAuthorized = true;
    authorization.deadline = bound(authorization.deadline, block.timestamp, type(uint256).max);

    // Private key must be less than the secp256k1 curve order.
    privateKey = bound(privateKey, 1, type(uint32).max);
    authorization.nonce = 0;
    authorization.authorizer = vm.addr(privateKey);

    Signature memory sig;
    bytes32 digest = SigUtils.getTypedDataHash(ardentis.domainSeparator(), authorization);
    (sig.v, sig.r, sig.s) = vm.sign(privateKey, digest);

    ardentis.setAuthorizationWithSig(authorization, sig);

    assertEq(ardentis.isAuthorized(authorization.authorizer, authorization.authorized), true);
    assertEq(ardentis.nonce(authorization.authorizer), 1);
  }

  function testAuthorizationFailsWithReusedSig(Authorization memory authorization, uint256 privateKey) public {
    authorization.isAuthorized = true;
    authorization.deadline = bound(authorization.deadline, block.timestamp, type(uint256).max);

    // Private key must be less than the secp256k1 curve order.
    privateKey = bound(privateKey, 1, type(uint32).max);
    authorization.nonce = 0;
    authorization.authorizer = vm.addr(privateKey);

    Signature memory sig;
    bytes32 digest = SigUtils.getTypedDataHash(ardentis.domainSeparator(), authorization);
    (sig.v, sig.r, sig.s) = vm.sign(privateKey, digest);

    ardentis.setAuthorizationWithSig(authorization, sig);

    authorization.isAuthorized = false;
    vm.expectRevert(bytes(ErrorsLib.INVALID_NONCE));
    ardentis.setAuthorizationWithSig(authorization, sig);
  }
}
